using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.WorldAccess
{
    // Original living_scenery.gd _draw panes. Keep each heating circuit tied to
    // the player's own flag, including the legitimate east-only progression.
    public sealed class WorldHeatWindows:IDisposable
    {
        readonly Sprite pixel;
        readonly List<KeyValuePair<GameObject,string>> groups=new List<KeyValuePair<GameObject,string>>();
        public WorldHeatWindows(Phase6Catalog catalog,string map,Transform parent)
        {
            if(map!="ijsdal")return;
            pixel=Sprite.Create(Texture2D.whiteTexture,new Rect(0,0,Texture2D.whiteTexture.width,Texture2D.whiteTexture.height),Vector2.one*.5f,Texture2D.whiteTexture.width);
            string[] flags={"lw_heat_west","lw_heat_east"};float[][] windows={new[]{9f,12f},new[]{35f,38f}};
            Rect[] panes={new Rect(8,8,6,6),new Rect(16,8,8,6),new Rect(8,16,6,8),new Rect(16,16,8,8)};
            for(int group=0;group<flags.Length;group++)
            {
                var owner=new GameObject("Original heated windows "+flags[group]);owner.transform.SetParent(parent,false);groups.Add(new KeyValuePair<GameObject,string>(owner,flags[group]));
                foreach(float x in windows[group])foreach(var pane in panes)
                {
                    var child=new GameObject("Original warm pane");child.transform.SetParent(owner.transform,false);child.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(x*32,9*32)+pane.center);child.transform.localScale=new Vector3(pane.width/32,pane.height/32,1);
                    var renderer=child.AddComponent<SpriteRenderer>();renderer.sprite=pixel;renderer.sharedMaterial=catalog.straightMaterial;renderer.sortingOrder=-14500;renderer.color=new Color(1,.7f,.3f,.75f);
                }
            }
        }
        public void Tick(FoundationGameState state){foreach(var group in groups)group.Key.SetActive(state.Flag(group.Value));}
        public void Dispose(){if(pixel!=null)UnityEngine.Object.Destroy(pixel);}
    }
}
