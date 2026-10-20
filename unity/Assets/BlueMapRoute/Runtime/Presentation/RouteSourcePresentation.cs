using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;

namespace BlueMapMigration.Route
{
    // Original source draw commands were rendered in two isolated Godot GPU processes.
    // One source node stays one independently depth-sorted visual; the terrain and actors
    // remain native Unity sprites and collision geometry, never a flattened map picture.
    public sealed class RouteSourcePresentation : IDisposable
    {
        public const string ResourcePath="BlueMapRouteArt/index";
        public int CapturedNodes { get; private set; }
        public int NativeActors { get; private set; }
        public int NativePickups { get; private set; }
        public int FurniturePieces { get; private set; }
        public IReadOnlyDictionary<string,GameObject> Objects=>objects;
        private readonly Phase6Catalog catalog;
        private readonly FoundationWorldSnapshot snapshot;
        private readonly Transform parent;
        private readonly Dictionary<string,GameObject> objects=new Dictionary<string,GameObject>(StringComparer.Ordinal);
        private readonly Dictionary<string,bool> overrides=new Dictionary<string,bool>(StringComparer.Ordinal);
        private readonly List<Sprite> owned=new List<Sprite>();
        private readonly List<MovingArt> moving=new List<MovingArt>();
        private readonly Dictionary<string,FoundationValue> sourceNodes;
        private readonly FoundationValue art,sourceItems,sourceNpcs;
        private readonly Dictionary<string,Sprite> capturedSprites=new Dictionary<string,Sprite>(StringComparer.Ordinal);
        private sealed class MovingArt { public SpriteRenderer Renderer;public string Address,Sheet,Kind; public Vector2 Position;public Vector2Int Cell;public float Scale;public bool Humanoid;public string UniqueKey; }
        public RouteSourcePresentation(Phase6Catalog catalog,FoundationWorldSnapshot snapshot,FoundationGameState state,Transform parent)
        {
            this.catalog=catalog;this.snapshot=snapshot;this.parent=parent;
            var file=Resources.Load<TextAsset>(ResourcePath);
            if(file==null)throw new FormatException("Original route art manifest is missing.");
            art=FoundationJson.ParsePlain(file.text);
            var oracle=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapRouteOracle").text).Require("catalogs");sourceItems=oracle.Require("items");sourceNpcs=oracle.Require("npcs");
            if(art.Require("schemaVersion").AsInt64()!=1||art.Require("tilePixels").AsInt64()!=32||art.Require("alphaMode").AsString()!="premultiplied")throw new FormatException("Original route art contract changed.");
            sourceNodes=snapshot.Root.Require("scene").Items.ToDictionary(Address,StringComparer.Ordinal);
            foreach(var entry in art.Require("nodes").Items)
            {
                if(entry.Require("mapId").AsString()!=snapshot.MapId)continue;
                string address=entry.Require("address").AsString();
                if(!sourceNodes.TryGetValue(address,out var node))throw new FormatException("Captured original route node is absent: "+snapshot.MapId+"/"+address);
                if(Position(node)!=Pair(entry.Require("position")))throw new FormatException("Captured original object moved: "+address);
                if(node.Require("script").AsString()!=entry.Require("script").AsString())throw new FormatException("Captured route node script changed: "+address);
                var fields=node.Require("fields");
                if(node.Require("script").AsString().EndsWith("/chest.gd",StringComparison.Ordinal))continue;
                if(node.Require("script").AsString().EndsWith("/home_station.gd",StringComparison.Ordinal)&&fields.TryGet("obj",out var obj)&&obj.TryGet("role",out var role)&&((snapshot.MapId=="player_home"&&new[]{"bed","table","shelf"}.Contains(role.AsString()))||role.AsString()=="fall"))continue;
                string name=entry.Require("file").AsString();
                if(!capturedSprites.TryGetValue(name,out Sprite sprite))
                {
                    Texture2D texture=Resources.Load<Texture2D>("BlueMapRouteArt/"+name.Substring(0,name.Length-4));
                    if(texture==null||texture.width!=entry.Require("width").AsInt64()||texture.height!=entry.Require("height").AsInt64())throw new FormatException("Original route texture missing or resized: "+name);
                    sprite=Sprite.Create(texture,new Rect(0,0,texture.width,texture.height),new Vector2(0,1),32);owned.Add(sprite);capturedSprites.Add(name,sprite);
                }
                Vector2 at=Pair(entry.Require("position")),offset=Pair(entry.Require("offset"));
                int order=entry.Require("ground").AsBool()?-15000:Mathf.RoundToInt(at.y);
                var renderer=Node(address,sprite,at+offset,order,catalog.premultipliedMaterial);
                CapturedNodes++;
            }
            foreach(var node in snapshot.Root.Require("scene").Items)
            {
                string script=node.Require("script").AsString();string address=Address(node);
                if(script.EndsWith("/npc.gd",StringComparison.Ordinal))AddActor(node,address,false);
                else if(script.EndsWith("/enemy.gd",StringComparison.Ordinal))AddActor(node,address,true);
                else if(script.EndsWith("/pickup.gd",StringComparison.Ordinal))AddPickup(node,address);
                else if(script.EndsWith("/chest.gd",StringComparison.Ordinal))AddChest(node,address);
                else if(script.EndsWith("/home_station.gd",StringComparison.Ordinal))
                {
                    var fields=node.Require("fields");if(fields.TryGet("obj",out var obj)&&obj.TryGet("role",out var role)&&role.AsString()=="fall")
                    {
                        Vector2 at=Position(node);var r=Node(address,catalog.GetSprite("generated:waterfall:0"),at,Mathf.RoundToInt(at.y),null);
                        moving.Add(new MovingArt{Renderer=r,Address=address,Position=at,Kind="waterfall"});
                    }
                }
            }
            if(snapshot.MapId=="player_home")AddHome(state);
            if(snapshot.MapId=="village")AddHomeCat();
            Tick(0,state);
        }
        public static string Address(FoundationValue node)=>String.Join("/",node.Require("address").Items.Select(v=>v.Kind=="string"?v.AsString():v.AsInt64().ToString(System.Globalization.CultureInfo.InvariantCulture)));
        private static Vector2 Pair(FoundationValue value)=>new Vector2((float)value.Items[0].AsDouble(),(float)value.Items[1].AsDouble());
        private static Vector2 Position(FoundationValue node)=>FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));
        private SpriteRenderer Node(string address,Sprite sprite,Vector2 at,int order,Material material)
        {
            if(sprite==null)throw new FormatException("Original route sprite absent: "+address);
            var go=new GameObject("Original route art "+address);go.transform.SetParent(parent,false);go.transform.localPosition=FoundationCoordinates.ToUnity(at);
            var renderer=go.AddComponent<SpriteRenderer>();if(material==null)catalog.Apply(renderer,sprite);else{renderer.sprite=sprite;renderer.sharedMaterial=material;}renderer.sortingOrder=order;
            if(objects.ContainsKey(address))throw new FormatException("Duplicate source visual: "+address);objects.Add(address,go);return renderer;
        }
        private Sprite Sheet(string sheet,int column,int row,Vector2Int cell)
        {
            var full=catalog.GetSprite("image:assets/pixel_"+sheet+".png");int density=2;
            if(full==null){full=catalog.GetSprite("image:assets/"+sheet+".png");density=1;}
            if(full==null)throw new FormatException("Original sheet missing: "+sheet);
            int width=cell.x*density,height=cell.y*density;
            int columns=Mathf.FloorToInt(full.rect.width/width),rows=Mathf.FloorToInt(full.rect.height/height);
            column=Mathf.Clamp(column,0,Mathf.Max(0,columns-1));row=Mathf.Clamp(row,0,Mathf.Max(0,rows-1));
            var sprite=Sprite.Create(full.texture,new Rect(full.rect.x+column*width,full.rect.y+full.rect.height-(row+1)*height,width,height),Vector2.one*.5f,32*density);owned.Add(sprite);return sprite;
        }
        private void AddActor(FoundationValue node,string address,bool enemy)
        {
            var fields=node.Require("fields");var data=fields.Require("data");string sheet=data.Require("sheet").AsString();
            float scale=data.TryGet("scale",out var size)?(float)size.AsDouble():2;Vector2Int cell=new Vector2Int(data.TryGet("cell",out var c)?checked((int)c.AsInt64()):16,16);cell.y=cell.x;
            bool human=catalog.GetSprite(sheet+":down:idle")!=null;
            Sprite sprite=human?catalog.GetSprite(sheet+":down:idle"):Sheet(sheet,0,0,cell);
            Vector2 at=Position(node);float drop=enemy?0:14-7*scale;
            var renderer=Node(address,sprite,at+new Vector2(0,drop),Mathf.RoundToInt(at.y),null);
            // Sheet() uses 32 world pixels per unit, i.e. original legacy scale=1.
            renderer.transform.localScale=Vector3.one*(human?scale*.5f:scale);
            moving.Add(new MovingArt{Renderer=renderer,Address=address,Position=at+new Vector2(0,drop),Kind=enemy?"passive-enemy":"npc",Sheet=sheet,Cell=cell,Scale=scale,Humanoid=human});NativeActors++;
        }
        private void AddPickup(FoundationValue node,string address)
        {
            var fields=node.Require("fields");string item=fields.Require("item").AsString();string sheet=item=="coin"?"coin":item=="heart"?"heart":"items";int frame=0;
            if(item!="coin"&&item!="heart"&&sourceItems.TryGet(item,out var info)){sheet=info.TryGet("sheet",out var value)?value.AsString():"items";frame=checked((int)info.Require("icon").AsInt64());}
            Vector2 at=Position(node);var r=Node(address,Sheet(sheet,frame,0,new Vector2Int(16,16)),at,Mathf.RoundToInt(at.y),null);r.transform.localScale=Vector3.one*2;
            moving.Add(new MovingArt{Renderer=r,Address=address,Position=at,Kind="pickup",Sheet=sheet,Cell=new Vector2Int(16,16),UniqueKey=fields.Require("unique_key").AsString()});NativePickups++;
        }
        private void AddChest(FoundationValue node,string address)
        {
            Vector2 at=Position(node);var r=Node(address,Sheet("chest",0,0,new Vector2Int(16,16)),at,Mathf.RoundToInt(at.y),null);r.transform.localScale=Vector3.one*2;
            moving.Add(new MovingArt{Renderer=r,Address=address,Position=at,Kind="chest",Sheet="chest",Cell=new Vector2Int(16,16),UniqueKey=node.Require("fields").Require("unique_key").AsString()});
        }
        private void AddHomeCat()
        {
            foreach(var obj in snapshot.MapData.Require("objects").Items)
            {
                if(!obj.TryGet("type",out var type)||type.AsString()!="npc"||!obj.TryGet("id",out var id)||id.AsString()!="muis_dorp")continue;
                var data=sourceNpcs.Require("muis_dorp");Vector2 at=Pair(obj.Require("pos"))*32+Vector2.one*16;float scale=(float)data.Require("scale").AsDouble();
                string address="conditional-npc/muis_dorp";var r=Node(address,Sheet(data.Require("sheet").AsString(),0,0,new Vector2Int(16,16)),at+new Vector2(0,14-7*scale),Mathf.RoundToInt(at.y),null);r.transform.localScale=Vector3.one*scale;
                var owner=new GameObject("Original returned cat foot");owner.transform.SetParent(r.transform,false);owner.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(0,-(14-7*scale)))/scale;owner.transform.localScale=Vector3.one/scale;
                FoundationCollision.Box(owner,new Rect(-7,3,14,10),1,3);
                NativeActors++;
            }
        }
        private void AddHome(FoundationGameState state)
        {
            FoundationValue home=state.Get("personal_home");if(!home.TryGet("layout",out var layout)){home=snapshot.StateAfter.Require("personal_home");layout=home.Require("layout");}
            int floor=home.TryGet("floor",out var fv)?checked((int)fv.AsInt64()):0,wall=home.TryGet("wall",out var wv)?checked((int)wv.AsInt64()):0;
            var rows=snapshot.MapData.Require("rows").Items;
            for(int y=0;y<snapshot.Height;y++)for(int x=0;x<snapshot.Width;x++)Node("home-surface/"+x+"/"+y,catalog.GetSprite("house_surface:"+(rows[y].AsString()[x]=='w'?Mathf.Clamp(floor,0,3):4+Mathf.Clamp(wall,0,3))),new Vector2(x*32+16,y*32+16),-19000,null);
            var sizes=new Dictionary<string,Vector2Int>{{"bed",new Vector2Int(1,2)},{"table",new Vector2Int(2,1)},{"shelf",new Vector2Int(2,2)},{"lamp",new Vector2Int(1,2)},{"bench",new Vector2Int(2,1)},{"cabinet",new Vector2Int(2,2)},{"rug",new Vector2Int(4,2)}};
            foreach(var entry in layout.Entries)
            {
                var piece=entry.Value;string kind=piece.Require("kind").AsString();Vector2 cell=Pair(piece.Require("cell"));Vector2Int size=sizes.TryGetValue(kind,out var dims)?dims:Vector2Int.one;
                int tint=checked((int)piece.Require("tint").AsInt64());Vector2 at=cell*32+new Vector2(size.x*16,size.y*32-16);
                Sprite sprite=catalog.GetSprite((kind=="rug"?"rug:":"furniture:"+kind+":")+Mathf.Clamp(tint,0,2));
                var renderer=Node("home-furniture/"+entry.Key.AsString(),sprite,kind=="rug"?cell*32+new Vector2(64,32):at,kind=="rug"?-18000:Mathf.RoundToInt(at.y),null);FurniturePieces++;
                // Furniture collisions use the saved layout too, including non-base pieces.
                if(kind!="rug")
                {
                    var owner=new GameObject("Saved original furniture foot "+entry.Key.AsString());owner.transform.SetParent(parent,false);owner.transform.localPosition=FoundationCoordinates.ToUnity(at);
                    FoundationCollision.Box(owner,new Rect(new Vector2(-size.x*16+2,16-size.y*32+2),new Vector2(size.x*32-4,size.y*32-4)),1,0);
                }
            }
        }
        public void SetPosition(string sourceAddress,Vector2 sourcePosition)
        {
            foreach(var item in moving)if(item.Address==sourceAddress){item.Position=sourcePosition;item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition);return;}
            if(objects.TryGetValue(sourceAddress,out var node))node.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition);
        }
        public void SetVisible(string sourceAddress,bool visible){overrides[sourceAddress]=visible;if(objects.TryGetValue(sourceAddress,out var node))node.SetActive(visible);}
        public void Tick(double clock,FoundationGameState state)
        {
            foreach(var pair in objects)
            {
                bool visible=true;
                if(sourceNodes.TryGetValue(pair.Key,out var node))
                {
                    var f=node.Require("fields");if(!node.Require("script").AsString().EndsWith("/chest.gd",StringComparison.Ordinal)&&f.TryGet("unique_key",out var key)&&key.AsString()!=""&&state.Flag(key.AsString()))visible=false;
                    if(f.TryGet("resource_id",out var resourceId)&&state.Get("professions").TryGet("cooldowns",out var cooldowns)&&cooldowns.TryGet(resourceId.AsString(),out var due))pair.Value.GetComponent<SpriteRenderer>().color=due.AsDouble()>state.PlayTime?new Color(.55f,.55f,.55f,.4f):Color.white;
                    if(f.TryGet("npc_id",out var npc)&&npc.AsString()=="muis_bos"&&state.Flag("cat_found"))visible=false;
                }
                if(pair.Key=="conditional-npc/muis_dorp")visible=state.Flag("cat_home");
                if(overrides.TryGetValue(pair.Key,out var forced))visible=forced;pair.Value.SetActive(visible);
            }
            foreach(var item in moving)
            {
                if(item.Kind=="pickup")item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(item.Position+new Vector2(0,Mathf.Sin((float)clock*3)*2));
                else if(item.Kind=="chest")
                {bool opened=state.Flag(item.UniqueKey);string spriteKey="chest:"+(opened?1:0);if(item.Sheet!=spriteKey){catalog.Apply(item.Renderer,Sheet("chest",opened?1:0,0,item.Cell));item.Sheet=spriteKey;}}
                else if(item.Kind=="waterfall")catalog.Apply(item.Renderer,catalog.GetSprite("generated:waterfall:"+((int)(clock*8)%8)));
            }
        }
        public void Dispose(){foreach(var sprite in owned)UnityEngine.Object.Destroy(sprite);owned.Clear();}
    }
}
