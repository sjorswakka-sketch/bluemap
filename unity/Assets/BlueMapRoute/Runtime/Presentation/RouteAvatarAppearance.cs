using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.Route
{
    // Same native mask order and source palettes as character_layers.gd.
    public sealed class RouteAvatarAppearance : IDisposable
    {
        private readonly Phase6Catalog catalog;
        private readonly Transform parent;
        private readonly SpriteRenderer[] layers=new SpriteRenderer[12];
        private readonly FoundationValue palettes,gear;
        public bool Visible { set{foreach(var renderer in layers)renderer.gameObject.SetActive(value&&renderer.sprite!=null);} }
        public RouteAvatarAppearance(Phase6Catalog catalog,Transform parent)
        {
            this.catalog=catalog;this.parent=parent;
            palettes=FoundationJson.ParsePlain(Resources.Load<TextAsset>(RouteSourcePresentation.ResourcePath).text).Require("palettes");
            gear=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapProgressionOracle").text).Require("catalogs").Require("gear");
            for(int i=0;i<layers.Length;i++){var node=new GameObject("Original appearance layer "+i);node.transform.SetParent(parent,false);layers[i]=node.AddComponent<SpriteRenderer>();}
        }
        private Color Palette(string id,long index)
        {var values=palettes.Require(id).Items;var v=values[Mathf.Clamp((int)index,0,values.Count-1)].Items;return Color.Lerp(new Color((float)v[0].AsDouble(),(float)v[1].AsDouble(),(float)v[2].AsDouble(),(float)v[3].AsDouble()),Color.white,.12f);}
        private static string Text(FoundationValue v,string field,string fallback="")=>v.TryGet(field,out var value)?value.AsString():fallback;
        private static long Int(FoundationValue v,string field,long fallback=0)=>v.TryGet(field,out var value)?value.AsInt64():fallback;
        private static Color GearColor(string item)
        {string value=item.Contains("crystal")||item.Contains("focus")?"91c4ca":item.Contains("iron")||item.Contains("plate")?"a9bbc3":item.Contains("copper")?"ca9b69":item.Contains("cap")||item.Contains("scout")?"87957a":"ac8a63";ColorUtility.TryParseHtmlString("#"+value,out var color);return Color.Lerp(color,Color.white,.12f);}
        public sealed class VisualLayer
        {
            public string Id {get;} public Color Tint {get;} public int Depth {get;}
            public VisualLayer(string id,Color tint,int depth){Id=id;Tint=tint;Depth=depth;}
        }
        // One composition is shared by the world avatar and all read-only menu views.
        public IReadOnlyList<VisualLayer> Compose(FoundationGameState state,string row,string pose="idle",int order=0,float alpha=1)
        {
            var composed=new List<VisualLayer>();int layer=0;var clothes=state.Get("clothing");var appearance=state.Get("appearance");var equipment=state.Get("equipment");
            Action<string,Color,int> show=(id,color,depth)=>{color.a*=alpha;composed.Add(new VisualLayer(id,color,depth));layer++;};
            Func<string,string> equipped=slot=>
            {
                if(!equipment.TryGet(slot,out var selected)||selected.Kind!="string")return "";string item=selected.AsString();
                if(!gear.TryGet(item,out var info)||Text(info,"slot")!=slot||!state.Get("inventory").TryGet(item,out var count)||(count.Kind!="int"&&count.Kind!="float")||count.AsDouble()<1)return "";
                return item;
            };
            Func<string,string> worn=slot=>clothes.TryGet(slot,out var c)?Text(c,"item"):"";
            Func<string,Color> dye=slot=>clothes.TryGet(slot,out var c)?Palette("dye",Int(c,"dye")):Color.white;
            string back=worn("back");if(back=="cloth_cape"||back=="cloth_cloak"||back=="cloth_backpack")show("clothes:"+back+":"+row+":idle",dye("back"),order-1);
            foreach(var slots in new[]{new[]{"chest","top","gear_chest"},new[]{"hands","","gear_gloves"},new[]{"feet","feet","gear_boots"}})
            {string item=equipped(slots[0]);if(item!=""&&(slots[1]==""||worn(slots[1])==""))show("clothes:"+slots[2]+":"+row+":"+pose,GearColor(item),order+1+layer);}
            foreach(string slot in new[]{"back","top","bottom","feet"})
            {string item=worn(slot);if(item!=""&&(slot!="back"||item=="cloth_scarf"||item=="cloth_backpack"))show("clothes:"+item+":"+row+":"+pose,dye(slot),order+1+layer);}
            show("hair:"+Text(appearance,"hair","m_kort")+":"+row,Palette("hair",Int(appearance,"hair_color",2)),order+1+layer);
            show("generated:eyes:"+Text(appearance,"eyes","rond")+":"+Int(appearance,"eye_color")+":"+row,Color.white,order+1+layer);
            string hat=worn("hat"),head=equipped("head");
            if(head!=""&&hat=="")show("clothes:gear_helmet:"+row+":"+pose,GearColor(head),order+1+layer);
            if(hat!="")show("clothes:"+hat+":"+row+":"+pose,dye("hat"),order+1+layer);
            return composed;
        }
        public void Update(FoundationGameState state,string row,string pose,int order,float alpha)
        {
            int index=0;
            foreach(var layer in Compose(state,row,pose,order,alpha))
            {if(index>=layers.Length)break;var renderer=layers[index++];var sprite=catalog.GetSprite(layer.Id);renderer.gameObject.SetActive(sprite!=null);if(sprite!=null)catalog.Apply(renderer,sprite);renderer.color=layer.Tint;renderer.sortingOrder=layer.Depth;}
            while(index<layers.Length)layers[index++].gameObject.SetActive(false);
        }
        public void DrawPreview(FoundationGameState state,Rect bounds,string row)
        {
            if(row!="down"&&row!="up"&&row!="left"&&row!="right")throw new ArgumentException("Original actor direction required",nameof(row));
            var composition=new List<VisualLayer>(Compose(state,row));composition.Add(new VisualLayer("player:"+row+":idle",Color.white,0));
            composition.Sort((a,b)=>a.Depth.CompareTo(b.Depth));float size=Mathf.Floor(Mathf.Min(bounds.width,bounds.height)/32)*32;
            if(size<32)size=32;var rect=new Rect(bounds.center.x-size*.5f,bounds.center.y-size*.5f,size,size);Color previous=GUI.color;
            foreach(var layer in composition)
            {
                var sprite=catalog.GetSprite(layer.Id);if(sprite==null)continue;var pixels=sprite.rect;
                GUI.color=layer.Tint;GUI.DrawTextureWithTexCoords(rect,sprite.texture,new Rect(pixels.x/sprite.texture.width,pixels.y/sprite.texture.height,pixels.width/sprite.texture.width,pixels.height/sprite.texture.height),true);
            }
            GUI.color=previous;
        }
        public void Dispose(){foreach(var renderer in layers)if(renderer!=null)UnityEngine.Object.Destroy(renderer.gameObject);}
    }
}
