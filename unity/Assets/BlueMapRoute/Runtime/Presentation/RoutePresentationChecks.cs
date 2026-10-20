using System;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.Route
{
    public static class RoutePresentationChecks
    {
        public static void Verify(Phase6Catalog catalog,FoundationWorldRepository repository,Action<string,bool> check)
        {
            int captured=0,actors=0,pickups=0;
            foreach(string map in new[]{"village","player_home","forest_edge","forest"})
            {
                var owner=new GameObject("Isolated original route presentation proof "+map);
                try
                {
                    var state=RouteGameplay.NewGame(repository).State;
                    using(var presentation=new RouteSourcePresentation(catalog,repository.Read(map),state,owner.transform))
                    {
                        captured+=presentation.CapturedNodes;actors+=presentation.NativeActors;pickups+=presentation.NativePickups;
                        check("route_original_art_"+map+"_loaded",presentation.CapturedNodes>0&&presentation.Objects.Count>presentation.CapturedNodes);
                        if(map=="village")
                        {
                            var cat=presentation.Objects["conditional-npc/muis_dorp"];
                            bool before=!cat.activeSelf;state.SetFlag("cat_home",true);presentation.Tick(0,state);
                            check("route_returned_cat_visual_and_foot_follow_quest",before&&cat.activeSelf&&cat.GetComponentInChildren<BoxCollider2D>()!=null);
                        }
                        if(map=="forest")
                        {
                            string chest=Find(repository.Read(map),"/chest.gd");
                            var renderer=presentation.Objects[chest].GetComponent<SpriteRenderer>();Sprite before=renderer.sprite;
                            var source=repository.Read(map).Root.Require("scene").Items.First(node=>RouteSourcePresentation.Address(node)==chest);
                            state.SetFlag(source.Require("fields").Require("unique_key").AsString(),true);presentation.Tick(0,state);
                            check("route_open_chest_stays_visible_with_original_open_sprite",renderer.gameObject.activeSelf&&renderer.sprite!=before);
                        }
                        if(map=="player_home")
                            check("route_original_home_furniture_and_passable_rug",presentation.FurniturePieces==4&&owner.GetComponentsInChildren<BoxCollider2D>().Length==3&&presentation.Objects.ContainsKey("home-furniture/rug:1"));
                    }
                }
                finally{owner.SetActive(false);UnityEngine.Object.Destroy(owner);}
            }
            check("route_original_art_four_maps_complete",captured>=90&&actors>=30&&pickups>=15);
            var savedOwner=new GameObject("Saved route house and native appearance proof");
            try
            {
                var furnished=repository.Read("player_home","home_furnished");var saved=RouteGameplay.NewGame(repository).State;saved.Set("personal_home",furnished.StateAfter.Require("personal_home"));
                bool homeMatches=false,appearanceMatches=false;
                using(var presentation=new RouteSourcePresentation(catalog,repository.Read("player_home"),saved,savedOwner.transform))
                {
                    var bed=furnished.Root.Require("scene").Items.First(node=>node.Require("script").AsString().EndsWith("/home_station.gd",StringComparison.Ordinal)&&node.Require("fields").Require("obj").Require("role").AsString()=="bed");
                    Vector2 expected=FoundationCoordinates.Vector(bed.Require("globalTransform").Require("origin"));
                    homeMatches=Vector2.Distance(FoundationCoordinates.ToGodot(presentation.Objects["home-furniture/bed"].transform.localPosition),expected)<.001f;
                    saved.Set("appearance",FoundationJson.ParsePlain("{\"gender\":\"v\",\"hair\":\"v_bob\",\"hair_color\":9,\"eyes\":\"groot\",\"eye_color\":3}"));
                    var avatar=new GameObject("Saved native appearance");avatar.transform.SetParent(savedOwner.transform,false);
                    using(var appearance=new RouteAvatarAppearance(catalog,avatar.transform))
                    {
                        appearance.Update(saved,"left","step2",0,1);
                        var layers=avatar.GetComponentsInChildren<SpriteRenderer>();
                        appearanceMatches=layers.Any(r=>r.sprite==catalog.GetSprite("hair:v_bob:left")&&r.sprite.rect.width==32)&&layers.Any(r=>r.sprite==catalog.GetSprite("generated:eyes:groot:3:left"));
                    }
                }
                check("route_saved_home_layout_and_appearance_verified",homeMatches&&appearanceMatches);
            }
            finally{savedOwner.SetActive(false);UnityEngine.Object.Destroy(savedOwner);}

        }
        public static void VerifyGpu(Phase6Catalog catalog,Action<string,bool> check)
        {
            var manifest=FoundationJson.ParsePlain(Resources.Load<TextAsset>(RouteSourcePresentation.ResourcePath).text);
            var seen=new System.Collections.Generic.HashSet<string>(StringComparer.Ordinal);int compared=0,mismatches=0;bool exactImport=true;
            var owner=new GameObject("Original route pixel GPU proof");owner.layer=31;
            var cameraNode=new GameObject("Original route pixel proof camera");var camera=cameraNode.AddComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;camera.cullingMask=1<<31;camera.allowHDR=false;camera.allowMSAA=false;camera.transform.position=new Vector3(0,0,-10);
            var renderer=owner.AddComponent<SpriteRenderer>();renderer.sharedMaterial=catalog.premultipliedMaterial;
            try
            {
                foreach(var entry in manifest.Require("nodes").Items)
                {
                    string name=entry.Require("file").AsString();if(!seen.Add(name))continue;
                    Texture2D source=Resources.Load<Texture2D>("BlueMapRouteArt/"+name.Substring(0,name.Length-4));Color32[] pixels=source.GetPixels32();
                    var raw=new byte[pixels.Length*4];int i=0;for(int y=source.height-1;y>=0;y--)for(int x=0;x<source.width;x++){var c=pixels[y*source.width+x];raw[i++]=c.r;raw[i++]=c.g;raw[i++]=c.b;raw[i++]=c.a;}
                    using(var hash=System.Security.Cryptography.SHA256.Create())
                    {
                        string digest=String.Concat(hash.ComputeHash(raw).Select(b=>b.ToString("x2")));bool equal=digest==entry.Require("rgbaSha256").AsString()&&source.filterMode==FilterMode.Point&&source.mipmapCount==1;exactImport&=equal;
                        if(!equal)Debug.Log("Route art import differs: "+name+" format="+source.format+" actual="+digest+" original="+entry.Require("rgbaSha256").AsString());
                    }
                    Sprite sprite=Sprite.Create(source,new Rect(0,0,source.width,source.height),Vector2.one*.5f,32);renderer.sprite=sprite;
                    var target=new RenderTexture(source.width,source.height,0,RenderTextureFormat.ARGB32);target.antiAliasing=1;target.filterMode=FilterMode.Point;target.Create();
                    var capture=new Texture2D(source.width,source.height,TextureFormat.RGBA32,false);var previous=RenderTexture.active;
                    try
                    {
                        camera.targetTexture=target;camera.aspect=source.width/(float)source.height;camera.orthographicSize=source.height/64f;camera.Render();RenderTexture.active=target;
                        capture.ReadPixels(new Rect(0,0,source.width,source.height),0,0,false);capture.Apply(false,false);Color32[] actual=capture.GetPixels32();
                        int before=mismatches;
                        for(int j=0;j<pixels.Length;j++){compared++;if(actual[j].r!=pixels[j].r||actual[j].g!=pixels[j].g||actual[j].b!=pixels[j].b){mismatches++;if(mismatches==1)Debug.Log("Route GPU first difference "+name+" pixel="+j+" original="+pixels[j]+" actual="+actual[j]);}}
                        if(mismatches>before)Debug.Log("Route GPU differs: "+name+" pixels="+(mismatches-before)+" / "+pixels.Length);
                    }
                    finally{camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.Destroy(target);UnityEngine.Object.Destroy(capture);UnityEngine.Object.Destroy(sprite);}
                }
                Debug.Log("Route native source pixels: textures="+seen.Count+" compared="+compared+" differing="+mismatches+" exactImport="+exactImport);
                check("route_original_art_source_nodes",manifest.Require("nodes").Items.Count==104&&seen.Count==47&&exactImport);
                check("route_original_art_gpu_pixels_exact",compared>700000&&mismatches==0);
            }
            finally{owner.SetActive(false);cameraNode.SetActive(false);UnityEngine.Object.Destroy(owner);UnityEngine.Object.Destroy(cameraNode);}
        }
        private static string Find(FoundationWorldSnapshot snapshot,string suffix)=>RouteSourcePresentation.Address(snapshot.Root.Require("scene").Items.First(node=>node.Require("script").AsString().EndsWith(suffix,StringComparison.Ordinal)));
    }
}
