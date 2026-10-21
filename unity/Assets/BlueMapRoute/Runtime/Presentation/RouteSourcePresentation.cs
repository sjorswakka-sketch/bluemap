using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.WorldAccess;
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
        public bool HomeStorageOpen { get; private set; }
        public int HomeStorageVisualCount => homeStorage.Count;
        public bool HomeStorageVisualOpen => homeStorage.Count > 0 && HomeStorageOpen && homeStorage.All(item => item.Renderer != null && item.Renderer.sprite == openHomeStorageSprite);
        public IReadOnlyDictionary<string,GameObject> Objects=>objects;
        private readonly Phase6Catalog catalog;
        private readonly FoundationWorldSnapshot snapshot;
        private readonly Transform parent;
        private readonly Dictionary<string,GameObject> objects=new Dictionary<string,GameObject>(StringComparer.Ordinal);
        private readonly Dictionary<string,bool> overrides=new Dictionary<string,bool>(StringComparer.Ordinal);
        private readonly List<Sprite> owned=new List<Sprite>();
        private readonly List<MovingArt> moving=new List<MovingArt>();
        private readonly List<HomeStorageArt> homeStorage=new List<HomeStorageArt>();
        private Sprite openHomeStorageSprite;
        private readonly Dictionary<string,FoundationValue> sourceNodes;
        private readonly FoundationValue art,sourceItems,sourceNpcs;
        public WorldAccessModel Access { get; set; }
        private readonly List<PortalArt> portals=new List<PortalArt>();
        private Sprite whitePixel,circlePixel;
        private Texture2D circleTexture;
        private readonly WorldHeatWindows heatWindows;
        private sealed class PortalArt {public FoundationValue Fields;public SpriteRenderer Fill;public SpriteRenderer[] Border,Sparkles;public Vector2 Origin,Size;}
        private readonly Dictionary<string,Sprite> capturedSprites=new Dictionary<string,Sprite>(StringComparer.Ordinal);
        private sealed class MovingArt { public SpriteRenderer Renderer;public string Address,Sheet,Kind; public Vector2 Position;public Vector2Int Cell;public float Scale;public bool Humanoid;public string UniqueKey; }
        private sealed class HomeStorageArt
        {
            public SpriteRenderer Renderer;
            public Sprite ClosedSprite;
            public Material ClosedMaterial;
            public Vector3 ClosedPosition,ClosedScale;
            public Vector2 SourcePosition;
            public int ClosedOrder;
        }
        public RouteSourcePresentation(Phase6Catalog catalog,FoundationWorldSnapshot snapshot,FoundationGameState state,Transform parent,WorldAccessModel access=null)
        {
            this.catalog=catalog;this.snapshot=snapshot;this.parent=parent;Access=access;
            var file=Resources.Load<TextAsset>(ResourcePath);
            if(file==null)throw new FormatException("Original route art manifest is missing.");
            art=FoundationJson.ParsePlain(file.text);
            var oracle=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapRouteOracle").text).Require("catalogs");sourceItems=oracle.Require("items");sourceNpcs=oracle.Require("npcs");
            if(art.Require("schemaVersion").AsInt64()!=1||art.Require("tilePixels").AsInt64()!=32||art.Require("alphaMode").AsString()!="premultiplied")throw new FormatException("Original route art contract changed.");
            sourceNodes=snapshot.Root.Require("scene").Items.ToDictionary(Address,StringComparer.Ordinal);
            var worldArt=WorldArtCatalog.For(snapshot);var selectedArt=worldArt??art;
            string artFolder=worldArt==null?"BlueMapRouteArt/":"BlueMapWorldArt/";
            foreach(var entry in selectedArt.Require("nodes").Items)
            {
                if(entry.Require("mapId").AsString()!=snapshot.MapId||(entry.TryGet("scenarioId",out var scenario)&&scenario.AsString()!=snapshot.ScenarioId))continue;
                string address=entry.Require("address").AsString();
                if(!sourceNodes.TryGetValue(address,out var node))throw new FormatException("Captured original route node is absent: "+snapshot.MapId+"/"+address);
                if(Position(node)!=Pair(entry.Require("position")))throw new FormatException("Captured original object moved: "+address);
                if(node.Require("script").AsString()!=entry.Require("script").AsString())throw new FormatException("Captured route node script changed: "+address);
                var fields=node.Require("fields");
                if(node.Require("script").AsString().EndsWith("/chest.gd",StringComparison.Ordinal)||fields.TryGet("block_if",out _))continue;
                if(node.Require("script").AsString().EndsWith("/home_station.gd",StringComparison.Ordinal)&&fields.TryGet("obj",out var obj)&&obj.TryGet("role",out var role)&&((snapshot.MapId=="player_home"&&new[]{"bed","table","shelf"}.Contains(role.AsString()))||role.AsString()=="fall"))continue;
                string name=entry.Require("file").AsString();
                if(!capturedSprites.TryGetValue(name,out Sprite sprite))
                {
                    Texture2D texture=Resources.Load<Texture2D>(artFolder+name.Substring(0,name.Length-4));
                    if(texture==null||texture.width!=entry.Require("width").AsInt64()||texture.height!=entry.Require("height").AsInt64())throw new FormatException("Original route texture missing or resized: "+name);
                    sprite=Sprite.Create(texture,new Rect(0,0,texture.width,texture.height),new Vector2(0,1),32,0,SpriteMeshType.FullRect);owned.Add(sprite);capturedSprites.Add(name,sprite);
                }
                Vector2 at=Pair(entry.Require("position")),offset=Pair(entry.Require("offset"));
                int order=entry.Require("ground").AsBool()?-15000+checked((int)node.Require("address").Items[1].AsInt64()):Mathf.RoundToInt(at.y);
                var renderer=Node(address,sprite,at+offset,order,catalog.premultipliedMaterial);
                if(node.Require("script").AsString().EndsWith("/stock_chest.gd",StringComparison.Ordinal))
                    homeStorage.Add(new HomeStorageArt{Renderer=renderer,ClosedSprite=renderer.sprite,ClosedMaterial=renderer.sharedMaterial,ClosedPosition=renderer.transform.localPosition,ClosedScale=renderer.transform.localScale,ClosedOrder=renderer.sortingOrder,SourcePosition=at});
                CapturedNodes++;
            }
            foreach(var node in snapshot.Root.Require("scene").Items)
            {
                string script=node.Require("script").AsString();string address=Address(node);
                if(node.Require("fields").TryGet("block_if",out _))AddGate(node,address);
                else if(script.EndsWith("/portal.gd",StringComparison.Ordinal))AddPortal(node,address);
                else if(script.EndsWith("/npc.gd",StringComparison.Ordinal))AddActor(node,address,false);
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
            heatWindows=new WorldHeatWindows(catalog,snapshot.MapId,parent);
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
            if(sheet=="items_equipment"){full=catalog.GetSprite("image:generated:equipment-icons");density=1;}
            if(full==null){full=catalog.GetSprite("image:assets/"+sheet+".png");density=1;}
            if(full==null)throw new FormatException("Original sheet missing: "+sheet);
            int width=cell.x*density,height=cell.y*density;
            int columns=Mathf.FloorToInt(full.rect.width/width),rows=Mathf.FloorToInt(full.rect.height/height);
            column=Mathf.Clamp(column,0,Mathf.Max(0,columns-1));row=Mathf.Clamp(row,0,Mathf.Max(0,rows-1));
            var sprite=Sprite.Create(full.texture,new Rect(full.rect.x+column*width,full.rect.y+full.rect.height-(row+1)*height,width,height),Vector2.one*.5f,32*density);owned.Add(sprite);return sprite;
        }
        private void AddGate(FoundationValue node,string address)
        {
            var fields=node.Require("fields");Vector2 size=FoundationCoordinates.Vector(fields.Require("size_tiles"));Vector2 at=Position(node);
            string sheet=node.Require("script").AsString().EndsWith("/diepte_gate.gd",StringComparison.Ordinal)?"depths_objects":"gate";int frame=sheet=="gate"?0:2;
            var renderer=Node(address,Sheet(sheet,frame,0,new Vector2Int(16,16)),at,Mathf.RoundToInt(at.y),null);renderer.transform.localScale=Vector3.one*2;
            for(int y=0;y<(int)size.y;y++)for(int x=0;x<(int)size.x;x++)
            {
                if(x==0&&y==0)continue;
                var piece=new GameObject("Original gate leaf");piece.transform.SetParent(renderer.transform,false);piece.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(x*16,y*16));
                var part=piece.AddComponent<SpriteRenderer>();catalog.Apply(part,renderer.sprite);part.sortingOrder=renderer.sortingOrder;
            }
        }
        private SpriteRenderer Rectangle(Transform owner,Rect rect,int depth)
        {
            if(whitePixel==null){whitePixel=Sprite.Create(Texture2D.whiteTexture,new Rect(0,0,Texture2D.whiteTexture.width,Texture2D.whiteTexture.height),Vector2.one*.5f,Texture2D.whiteTexture.width);owned.Add(whitePixel);}
            var child=new GameObject("Original doorway light");child.transform.SetParent(owner,false);child.transform.localPosition=FoundationCoordinates.ToUnity(rect.center);child.transform.localScale=new Vector3(rect.width/32,rect.height/32,1);
            var renderer=child.AddComponent<SpriteRenderer>();renderer.sprite=whitePixel;renderer.sharedMaterial=catalog.straightMaterial;renderer.sortingOrder=depth;return renderer;
        }
        private void AddPortal(FoundationValue node,string address)
        {
            var fields=node.Require("fields");var rect=fields.Require("rect");Vector2 origin=FoundationCoordinates.Vector(rect.Require("position")),size=FoundationCoordinates.Vector(rect.Require("size"));
            var root=new GameObject("Original portal light "+address);root.transform.SetParent(parent,false);root.transform.localPosition=FoundationCoordinates.ToUnity(origin);objects.Add(address,root);
            int depth=-14000;var fill=Rectangle(root.transform,new Rect(Vector2.zero,size),depth);
            var border=new[]{Rectangle(root.transform,new Rect(0,0,size.x,2),depth),Rectangle(root.transform,new Rect(0,size.y-2,size.x,2),depth),Rectangle(root.transform,new Rect(0,0,2,size.y),depth),Rectangle(root.transform,new Rect(size.x-2,0,2,size.y),depth)};
            var sparks=new SpriteRenderer[3];
            if(circlePixel==null)
            {
                circleTexture=new Texture2D(4,4,TextureFormat.RGBA32,false,true);circleTexture.filterMode=FilterMode.Point;
                var pixels=new Color32[16];for(int y=0;y<4;y++)for(int x=0;x<4;x++)pixels[y*4+x]=new Color32(255,255,255,(byte)(((x-1.5f)*(x-1.5f)+(y-1.5f)*(y-1.5f)<=4)?255:0));
                circleTexture.SetPixels32(pixels);circleTexture.Apply(false,false);circlePixel=Sprite.Create(circleTexture,new Rect(0,0,4,4),Vector2.one*.5f,32);owned.Add(circlePixel);
            }
            for(int i=0;i<3;i++){var sparkle=new GameObject("Original portal spark");sparkle.transform.SetParent(root.transform,false);sparks[i]=sparkle.AddComponent<SpriteRenderer>();sparks[i].sprite=circlePixel;sparks[i].sharedMaterial=catalog.straightMaterial;sparks[i].sortingOrder=depth+1;}
            portals.Add(new PortalArt{Fields=fields,Fill=fill,Border=border,Sparkles=sparks,Origin=origin,Size=size});
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
            var fields=node.Require("fields");SpawnPickup(address,fields.Require("item").AsString(),Position(node),fields.Require("unique_key").AsString());
        }
        /// <summary>A runtime drop uses the same retained source item atlas and motion path as an authored pickup.</summary>
        public void SpawnPickup(string address,string item,Vector2 sourcePosition,string uniqueKey="")
        {
            if(string.IsNullOrWhiteSpace(address))throw new ArgumentException("A pickup source address is required.",nameof(address));
            if(string.IsNullOrEmpty(item))throw new ArgumentException("A pickup item is required.",nameof(item));
            if(!float.IsFinite(sourcePosition.x)||!float.IsFinite(sourcePosition.y))throw new ArgumentOutOfRangeException(nameof(sourcePosition));
            string sheet=item=="coin"?"coin":item=="heart"?"heart":"items";int frame=0;
            if(item!="coin"&&item!="heart"&&sourceItems.TryGet(item,out var info)){sheet=info.TryGet("sheet",out var value)?value.AsString():"items";frame=checked((int)info.Require("icon").AsInt64());}
            var r=Node(address,Sheet(sheet,frame,0,new Vector2Int(16,16)),sourcePosition,Mathf.RoundToInt(sourcePosition.y),null);r.transform.localScale=Vector3.one*2;
            moving.Add(new MovingArt{Renderer=r,Address=address,Position=sourcePosition,Kind="pickup",Sheet=sheet,Cell=new Vector2Int(16,16),UniqueKey=uniqueKey??""});NativePickups++;
        }
        private void AddChest(FoundationValue node,string address)
        {
            Vector2 at=Position(node);var r=Node(address,Sheet("chest",0,0,new Vector2Int(16,16)),at,Mathf.RoundToInt(at.y),null);r.transform.localScale=Vector3.one*2;
            moving.Add(new MovingArt{Renderer=r,Address=address,Position=at,Kind="chest",Sheet="chest",Cell=new Vector2Int(16,16),UniqueKey=node.Require("fields").Require("unique_key").AsString()});
        }
        private void AddHomeCat()
        {
            if(sourceNodes.Values.Any(node=>node.Require("fields").TryGet("npc_id",out var id)&&id.AsString()=="muis_dorp"))return;
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
            foreach(var item in moving)if(item.Address==sourceAddress){item.Position=sourcePosition;item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition);if(item.Kind=="pickup")item.Renderer.sortingOrder=Mathf.RoundToInt(sourcePosition.y);return;}
            if(objects.TryGetValue(sourceAddress,out var node))node.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition);
        }
        public void SetVisible(string sourceAddress,bool visible){overrides[sourceAddress]=visible;if(objects.TryGetValue(sourceAddress,out var node))node.SetActive(visible);}
        /// <summary>The original stock chest opens whenever an active home ledger is visible, including a remote view.</summary>
        public void SetHomeStorageOpen(bool opened)
        {
            if(HomeStorageOpen==opened)return;
            HomeStorageOpen=opened;
            if(opened&&homeStorage.Count>0&&openHomeStorageSprite==null)openHomeStorageSprite=Sheet("stock_chest",1,0,new Vector2Int(32,32));
            foreach(var item in homeStorage)
            {
                if(item.Renderer==null)continue;
                if(opened)
                {
                    catalog.Apply(item.Renderer,openHomeStorageSprite);
                    item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(item.SourcePosition+new Vector2(0,-3));
                    item.Renderer.transform.localScale=Vector3.one;
                    item.Renderer.sortingOrder=item.ClosedOrder;
                }
                else
                {
                    // Restore the retained Godot capture, including its transparent margins and alpha material.
                    item.Renderer.sprite=item.ClosedSprite;item.Renderer.sharedMaterial=item.ClosedMaterial;
                    item.Renderer.transform.localPosition=item.ClosedPosition;item.Renderer.transform.localScale=item.ClosedScale;
                    item.Renderer.sortingOrder=item.ClosedOrder;
                }
            }
        }
        public void Tick(double clock,FoundationGameState state)
        {
            heatWindows?.Tick(state);
            foreach(var pair in objects)
            {
                bool visible=true;
                if(sourceNodes.TryGetValue(pair.Key,out var node))
                {
                    var f=node.Require("fields");if(!node.Require("script").AsString().EndsWith("/chest.gd",StringComparison.Ordinal)&&f.TryGet("unique_key",out var key)&&key.AsString()!=""&&state.Flag(key.AsString()))visible=false;
                    if(f.TryGet("resource_id",out var resourceId)&&state.Get("professions").TryGet("cooldowns",out var cooldowns)&&cooldowns.TryGet(resourceId.AsString(),out var due))pair.Value.GetComponent<SpriteRenderer>().color=due.AsDouble()>state.PlayTime?new Color(.55f,.55f,.55f,.4f):Color.white;
                    if(Access!=null)visible&=Access.NodeVisible(node);
                    if(f.TryGet("block_if",out var block))visible&=Access!=null?Access.GateBlocked(f):new FoundationConditionRegistry(state).CheckAll(block).Value;
                    if(f.TryGet("npc_id",out var npc)&&npc.AsString()=="muis_bos"&&state.Flag("cat_found"))visible=false;
                }
                if(pair.Key=="conditional-npc/muis_dorp")visible=state.Flag("cat_home");
                if(overrides.TryGetValue(pair.Key,out var forced))visible=forced;pair.Value.SetActive(visible);
            }
            foreach(var portal in portals)
            {
                var tests=portal.Fields.TryGet("conditions",out var conditions)?conditions:FoundationValue.Array(Array.Empty<FoundationValue>());
                bool available=Access!=null?Access.Conditions.CheckAll(tests).Value:new FoundationConditionRegistry(state).CheckAll(tests).Value;
                Color color=available?new Color(.55f,.8f,1):new Color(214/255f,173/255f,104/255f);float pulse=.5f+.5f*Mathf.Sin((float)clock*2.2f);
                portal.Fill.color=new Color(color.r,color.g,color.b,.07f+.06f*pulse);foreach(var border in portal.Border)border.color=new Color(color.r,color.g,color.b,.3f+.25f*pulse);
                float span=Mathf.Max(portal.Size.y,16);
                for(int i=0;i<3;i++){float cycle=((float)clock*14+i*span/3)%span;portal.Sparkles[i].transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(portal.Size.x*(.2f+.3f*i),portal.Size.y-cycle));portal.Sparkles[i].color=new Color(1,1,1,.55f*Mathf.Sin(Mathf.PI*cycle/span));}
            }
            foreach(var item in moving)
            {
                if(item.Kind=="pickup")item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(item.Position+new Vector2(0,Mathf.Sin((float)clock*3)*2));
                else if(item.Kind=="chest")
                {bool opened=state.Flag(item.UniqueKey);string spriteKey="chest:"+(opened?1:0);if(item.Sheet!=spriteKey){catalog.Apply(item.Renderer,Sheet("chest",opened?1:0,0,item.Cell));item.Sheet=spriteKey;}}
                else if(item.Kind=="waterfall")catalog.Apply(item.Renderer,catalog.GetSprite("generated:waterfall:"+((int)(clock*8)%8)));
            }
        }
        public void Dispose(){foreach(var sprite in owned)UnityEngine.Object.Destroy(sprite);owned.Clear();if(circleTexture!=null)UnityEngine.Object.Destroy(circleTexture);heatWindows?.Dispose();}
    }
}
