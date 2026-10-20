using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.WorldAccess
{
    public static class WorldAccessPresentationChecks
    {
        public static void Verify(Phase6Catalog catalog,FoundationWorldRepository repository,Action<string,bool> check)
        {
            var manifest=WorldArtCatalog.Data;
            var rows=manifest.Require("nodes").Items;
            var snapshots=manifest.Require("snapshots").Items;
            bool coverage=repository.MapIds.Count==37&&rows.Select(row=>row.Require("mapId").AsString()).Distinct().Count()==37;
            bool identities=true;int verified=0;
            foreach(var descriptor in snapshots)
            {
                string map=descriptor.Require("mapId").AsString(),scenario=descriptor.Require("scenarioId").AsString();
                var snapshot=repository.Read(map,scenario);
                var nodes=snapshot.Root.Require("scene").Items.ToDictionary(Route.RouteSourcePresentation.Address,StringComparer.Ordinal);
                int count=0;
                foreach(var row in rows.Where(row=>row.Require("mapId").AsString()==map&&row.Require("scenarioId").AsString()==scenario))
                {
                    string address=row.Require("address").AsString();
                    if(!nodes.TryGetValue(address,out var node)){identities=false;continue;}
                    Vector2 at=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));var expected=row.Require("position").Items;
                    identities&=node.Require("script").AsString()==row.Require("script").AsString()&&at.x==(float)expected[0].AsDouble()&&at.y==(float)expected[1].AsDouble();count++;verified++;
                }
                identities&=count==descriptor.Require("drawNodes").AsInt64();
            }
            int total=4;
            foreach(var descriptor in repository.Index.Require("snapshots").Items)
            {
                string map=descriptor.Require("mapId").AsString(),scenario=descriptor.Require("scenarioId").AsString();
                if(WorldArtCatalog.UsesRouteArt(repository.Read(map,scenario)))continue;
                total++;
            }
            Debug.Log("Original world art: maps="+repository.MapIds.Count+" variants="+snapshots.Count+" verifiedNodes="+verified);
            check("world_art_all_registered_maps",coverage&&identities&&verified==rows.Count);
            check("world_art_snapshot_variants_available",snapshots.Count==158&&total==162&&identities);
        }
        public static void VerifyGpu(Phase6Catalog catalog,Action<string,bool> check)
        {
            var seen=new HashSet<string>(StringComparer.Ordinal);long compared=0,mismatches=0;bool exactImport=true;
            var owner=new GameObject("Original world pixel GPU proof");owner.layer=31;
            var cameraNode=new GameObject("Original world pixel proof camera");var camera=cameraNode.AddComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;camera.cullingMask=1<<31;camera.allowHDR=false;camera.allowMSAA=false;camera.transform.position=new Vector3(0,0,-10);
            var renderer=owner.AddComponent<SpriteRenderer>();renderer.sharedMaterial=catalog.premultipliedMaterial;
            try
            {
                foreach(var entry in WorldArtCatalog.Data.Require("nodes").Items)
                {
                    string name=entry.Require("file").AsString();if(!seen.Add(name))continue;
                    Texture2D source=Resources.Load<Texture2D>("BlueMapWorldArt/"+name.Substring(0,name.Length-4));
                    if(source==null){exactImport=false;Debug.Log("World art texture absent: "+name);continue;}
                    Color32[] pixels=source.GetPixels32();var raw=new byte[pixels.Length*4];int i=0;
                    for(int y=source.height-1;y>=0;y--)for(int x=0;x<source.width;x++){var c=pixels[y*source.width+x];raw[i++]=c.r;raw[i++]=c.g;raw[i++]=c.b;raw[i++]=c.a;}
                    using(var hash=System.Security.Cryptography.SHA256.Create())
                    {
                        string digest=String.Concat(hash.ComputeHash(raw).Select(b=>b.ToString("x2")));
                        bool equal=digest==entry.Require("rgbaSha256").AsString()&&source.filterMode==FilterMode.Point&&source.mipmapCount==1;exactImport&=equal;
                        if(!equal)Debug.Log("World art import differs: "+name+" actual="+digest+" original="+entry.Require("rgbaSha256").AsString());
                    }
                    Sprite sprite=Sprite.Create(source,new Rect(0,0,source.width,source.height),Vector2.one*.5f,32,0,SpriteMeshType.FullRect);renderer.sprite=sprite;
                    var target=new RenderTexture(source.width,source.height,0,RenderTextureFormat.ARGB32);target.antiAliasing=1;target.filterMode=FilterMode.Point;target.Create();
                    var capture=new Texture2D(source.width,source.height,TextureFormat.RGBA32,false);var previous=RenderTexture.active;
                    try
                    {
                        camera.targetTexture=target;camera.aspect=source.width/(float)source.height;camera.orthographicSize=source.height/64f;camera.Render();RenderTexture.active=target;
                        capture.ReadPixels(new Rect(0,0,source.width,source.height),0,0,false);capture.Apply(false,false);Color32[] actual=capture.GetPixels32();
                        for(int j=0;j<pixels.Length;j++){compared++;if(actual[j].r!=pixels[j].r||actual[j].g!=pixels[j].g||actual[j].b!=pixels[j].b){mismatches++;if(mismatches==1)Debug.Log("World GPU first difference "+name+" pixel="+j+" original="+pixels[j]+" actual="+actual[j]);}}
                    }
                    finally{camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.Destroy(target);UnityEngine.Object.Destroy(capture);UnityEngine.Object.Destroy(sprite);}
                }
                Debug.Log("World native source pixels: textures="+seen.Count+" compared="+compared+" differing="+mismatches+" exactImport="+exactImport);
                check("world_art_native_rgba_exact",seen.Count>250&&exactImport);
                check("world_art_gpu_pixels_exact",seen.Count>250&&compared>1000000&&mismatches==0);
            }
            finally{owner.SetActive(false);cameraNode.SetActive(false);UnityEngine.Object.Destroy(owner);UnityEngine.Object.Destroy(cameraNode);}
        }
    }
}
