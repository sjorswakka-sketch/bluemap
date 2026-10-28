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
        public BlueMapMigration.Story.StorySourceVisuals StoryVisuals {get;private set;}
        private sealed class PortalArt {public FoundationValue Fields;public SpriteRenderer Fill;public SpriteRenderer[] Border,Sparkles;public Vector2 Origin,Size;}
        private readonly Dictionary<string,Sprite> capturedSprites=new Dictionary<string,Sprite>(StringComparer.Ordinal);
        private readonly Dictionary<string,ResidentArt> residents=new Dictionary<string,ResidentArt>(StringComparer.Ordinal);
        private readonly Dictionary<string,ResidentObjectArt> residentObjects=new Dictionary<string,ResidentObjectArt>(StringComparer.Ordinal);
        private readonly List<Texture2D> residentPrimitiveTextures=new List<Texture2D>();
        private readonly Dictionary<string,Vector2> sourceVisualOffsets=new Dictionary<string,Vector2>(StringComparer.Ordinal);
        private readonly Dictionary<string,Sprite> residentFrames=new Dictionary<string,Sprite>(StringComparer.Ordinal);
        private Sprite residentShadow;
        private Texture2D residentShadowTexture;
        private Sprite residentDot;
        private readonly FoundationGameState residentState;
        private sealed class ResidentArt
        { public GameObject Root;public UnityEngine.Rendering.SortingGroup Group;public SpriteRenderer Body,Shadow,Tool;public SpriteRenderer[] Effects;public Vector2 Position,Velocity;public int Frame,RoleFrame,Direction;public double Time;public float Scale=2;public bool Ghost;public string Sheet; }
        private sealed class ResidentObjectArt
        {public GameObject Root;public UnityEngine.Rendering.SortingGroup Group;public SpriteRenderer Body,Water,Line,Progress;public SpriteRenderer[] Steam;public Sprite FrameSprite;public int Frame;}
        private sealed class MovingArt { public SpriteRenderer Renderer;public string Address,Sheet,Kind; public Vector2 Position,VisualOffset;public Vector2Int Cell;public float Scale;public bool Humanoid;public string UniqueKey; }
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
            this.catalog=catalog;this.snapshot=snapshot;this.parent=parent;Access=access;residentState=state;
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
                sourceVisualOffsets[address]=offset;
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
            StoryVisuals=new BlueMapMigration.Story.StorySourceVisuals(catalog,snapshot,objects);
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
            moving.Add(new MovingArt{Renderer=renderer,Address=address,Position=at+new Vector2(0,drop),VisualOffset=new Vector2(0,drop),Kind=enemy?"passive-enemy":"npc",Sheet=sheet,Cell=cell,Scale=scale,Humanoid=human});NativeActors++;
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
            if(residents.TryGetValue(sourceAddress,out var resident)){resident.Position=sourcePosition;resident.Root.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition);resident.Group.sortingOrder=Mathf.RoundToInt(sourcePosition.y);return;}
            foreach(var item in moving)if(item.Address==sourceAddress){item.Position=sourcePosition+item.VisualOffset;item.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(item.Position);item.Renderer.sortingOrder=Mathf.RoundToInt(sourcePosition.y);return;}
            if(objects.TryGetValue(sourceAddress,out var node))
            {
                // Captured sprites use a top-left transparent-margin offset; retain it while moving their source anchor.
                Vector2 offset=sourceVisualOffsets.TryGetValue(sourceAddress,out var capturedOffset)?capturedOffset:Vector2.zero;
                node.transform.localPosition=FoundationCoordinates.ToUnity(sourcePosition+offset);foreach(var renderer in node.GetComponentsInChildren<SpriteRenderer>())renderer.sortingOrder=Mathf.RoundToInt(sourcePosition.y);
            }
        }
        private Sprite ResidentSheet(string sheet,int column,int row)
        {return ResidentSheet(sheet,column,row,new Vector2Int(16,16));}
        private Sprite ResidentSheet(string sheet,int column,int row,Vector2Int cell)
        {string key=sheet+":"+column+":"+row+":"+cell.x+":"+cell.y;if(!residentFrames.TryGetValue(key,out var sprite)){sprite=Sheet(sheet,column,row,cell);residentFrames.Add(key,sprite);}return sprite;}
        private SpriteRenderer ResidentPart(Transform owner,string name)
        {var node=new GameObject(name);node.transform.SetParent(owner,false);return node.AddComponent<SpriteRenderer>();}
        private Sprite DotSprite()
        {if(residentDot==null){residentDot=Sprite.Create(Texture2D.whiteTexture,new Rect(0,0,Texture2D.whiteTexture.width,Texture2D.whiteTexture.height),Vector2.one*.5f,Texture2D.whiteTexture.width*16);owned.Add(residentDot);}return residentDot;}
        private void ResidentLine(SpriteRenderer renderer,Vector2 start,Vector2 end,float width,Color color)
        {
            if(whitePixel==null){whitePixel=Sprite.Create(Texture2D.whiteTexture,new Rect(0,0,Texture2D.whiteTexture.width,Texture2D.whiteTexture.height),Vector2.one*.5f,Texture2D.whiteTexture.width);owned.Add(whitePixel);}
            var difference=end-start;renderer.enabled=true;renderer.sprite=whitePixel;renderer.sharedMaterial=catalog.straightMaterial;renderer.color=color;renderer.transform.localPosition=FoundationCoordinates.ToUnity((start+end)*.5f);renderer.transform.localScale=new Vector3(difference.magnitude/32,width/32,1);renderer.transform.localRotation=Quaternion.Euler(0,0,-Mathf.Atan2(difference.y,difference.x)*Mathf.Rad2Deg);
        }
        private void ResidentRectangle(SpriteRenderer renderer,Rect rect,Color color)
        {
            if(whitePixel==null){whitePixel=Sprite.Create(Texture2D.whiteTexture,new Rect(0,0,Texture2D.whiteTexture.width,Texture2D.whiteTexture.height),Vector2.one*.5f,Texture2D.whiteTexture.width);owned.Add(whitePixel);}
            renderer.enabled=true;renderer.sprite=whitePixel;renderer.sharedMaterial=catalog.straightMaterial;renderer.color=color;renderer.transform.localPosition=FoundationCoordinates.ToUnity(rect.center);renderer.transform.localScale=new Vector3(rect.width/32,rect.height/32,1);renderer.transform.localRotation=Quaternion.identity;
        }
        private Sprite ShadowSprite()
        {
            if(residentShadow!=null)return residentShadow;
            residentShadowTexture=new Texture2D(20,8,TextureFormat.RGBA32,false,true);residentShadowTexture.filterMode=FilterMode.Point;var pixels=new Color32[160];
            for(int y=0;y<8;y++)for(int x=0;x<20;x++){float dx=(x+.5f-10)/10,dy=(y+.5f-4)/4;pixels[y*20+x]=new Color32(0,0,0,(byte)(dx*dx+dy*dy<=1?64:0));}
            residentShadowTexture.SetPixels32(pixels);residentShadowTexture.Apply(false,false);residentShadow=Sprite.Create(residentShadowTexture,new Rect(0,0,20,8),Vector2.one*.5f,32);owned.Add(residentShadow);return residentShadow;
        }
        private Sprite ResidentEllipse(float radiusX,float radiusY)
        {
            string key="primitive:ellipse:"+radiusX.ToString("R",System.Globalization.CultureInfo.InvariantCulture)+":"+radiusY.ToString("R",System.Globalization.CultureInfo.InvariantCulture);
            if(residentFrames.TryGetValue(key,out var cached))return cached;
            int width=Mathf.CeilToInt(radiusX*2),height=Mathf.CeilToInt(radiusY*2);var texture=new Texture2D(width,height,TextureFormat.RGBA32,false,true);texture.filterMode=FilterMode.Point;texture.wrapMode=TextureWrapMode.Clamp;
            var points=new Vector2[20];for(int i=0;i<20;i++){double angle=Math.PI*2*i/20;points[i]=new Vector2((float)Math.Cos(angle)*radiusX,(float)Math.Sin(angle)*radiusY);}
            var pixels=new Color32[width*height];
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)
            {
                float px=x+.5f-width*.5f,py=y+.5f-height*.5f;bool inside=false;
                for(int i=0,j=19;i<20;j=i++)if((points[i].y>py)!=(points[j].y>py)&&px<(points[j].x-points[i].x)*(py-points[i].y)/(points[j].y-points[i].y)+points[i].x)inside=!inside;
                pixels[y*width+x]=new Color32(255,255,255,(byte)(inside?255:0));
            }
            texture.SetPixels32(pixels);texture.Apply(false,false);residentPrimitiveTextures.Add(texture);var sprite=Sprite.Create(texture,new Rect(0,0,width,height),Vector2.one*.5f,32);owned.Add(sprite);residentFrames.Add(key,sprite);return sprite;
        }
        /// <summary>Original supper_object._draw frames and local primitives; source furniture collision remains untouched.</summary>
        public void UpdateResidentObject(string address,string kind,Vector2 position,double time,bool pulling,double progress,Vector2 playerPosition,bool netDone,bool served,bool favoriteBroth)
        {
            if(!residentObjects.TryGetValue(address,out var r))
            {
                if(!objects.TryGetValue(address,out var root)){root=new GameObject("Original supper object "+address);root.transform.SetParent(parent,false);objects.Add(address,root);}
                var captured=root.GetComponent<SpriteRenderer>();if(captured!=null)captured.enabled=false;
                root.transform.localScale=Vector3.one;root.transform.localRotation=Quaternion.identity;
                r=new ResidentObjectArt{Root=root,Group=root.GetComponent<UnityEngine.Rendering.SortingGroup>()??root.AddComponent<UnityEngine.Rendering.SortingGroup>(),Body=ResidentPart(root.transform,"Original supper object atlas"),Water=ResidentPart(root.transform,"Original basket water ellipse"),Line=ResidentPart(root.transform,"Original basket fishing line"),Progress=ResidentPart(root.transform,"Original basket recovery progress"),Steam=new SpriteRenderer[3]};
                for(int i=0;i<3;i++)r.Steam[i]=ResidentPart(root.transform,"Original stove steam "+i);
                residentObjects.Add(address,r);
            }
            r.Root.transform.localPosition=FoundationCoordinates.ToUnity(position);r.Group.sortingOrder=Mathf.RoundToInt(position.y);
            r.Body.sortingOrder=0;r.Water.sortingOrder=-1;r.Line.sortingOrder=1;r.Progress.sortingOrder=2;foreach(var steam in r.Steam){steam.sortingOrder=1;steam.enabled=false;}
            r.Water.enabled=false;r.Line.enabled=false;r.Progress.enabled=false;r.Body.transform.localScale=Vector3.one*2;r.Body.transform.localRotation=Quaternion.identity;r.Body.color=Color.white;
            string sheet;Vector2Int cell;Vector2 center;
            if(kind=="table"){sheet="ls_table";cell=new Vector2Int(48,32);center=Vector2.zero;r.Frame=served?(favoriteBroth?2:1):0;}
            else if(kind=="net"){sheet="ls_net";cell=new Vector2Int(24,24);center=new Vector2(0,-7);r.Frame=netDone?1:0;}
            else if(kind=="stove")
            {
                sheet="ls_stove";cell=new Vector2Int(24,24);center=new Vector2(0,-4);r.Frame=(int)(time*3)%2;
                for(int i=0;i<3;i++)
                {
                    double rise=(time*9+i*6)%22;var steam=r.Steam[i];steam.enabled=true;catalog.Apply(steam,ResidentEllipse(1.7f,1.7f));steam.color=new Color(.95f,.89f,.73f,(float)((1-rise/22)*.4));steam.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2((float)(-6+i*6+Math.Sin(time*2+i)*2),(float)(-24-rise)));steam.transform.localScale=Vector3.one;steam.transform.localRotation=Quaternion.identity;
                }
            }
            else if(kind=="basket")
            {
                sheet="ls_items";cell=new Vector2Int(16,16);center=new Vector2((float)(Math.Sin(time)*3),(float)(Math.Sin(time*2)*2));r.Frame=0;
                r.Water.enabled=true;catalog.Apply(r.Water,ResidentEllipse(17,5));r.Water.color=new Color(.8f,.94f,1,.5f);r.Water.transform.localPosition=FoundationCoordinates.ToUnity(center+new Vector2(0,9));r.Water.transform.localScale=Vector3.one;r.Water.transform.localRotation=Quaternion.identity;
                if(pulling)
                {ResidentLine(r.Line,playerPosition-position+new Vector2(0,-10),center,1,new Color(230/255f,215/255f,173/255f));ResidentRectangle(r.Progress,new Rect(-19,-27,(float)(38*Math.Min(progress/1.8,1)),3),new Color(195/255f,227/255f,193/255f));}
            }
            else{sheet="ls_notice";cell=new Vector2Int(16,16);center=Vector2.zero;r.Frame=0;}
            r.FrameSprite=ResidentSheet(sheet,r.Frame,0,cell);catalog.Apply(r.Body,r.FrameSprite);r.Body.transform.localPosition=FoundationCoordinates.ToUnity(center);
        }
        public int ResidentObjectFrame(string address)=>residentObjects.TryGetValue(address,out var r)&&r.Body!=null&&r.Body.enabled&&r.Body.sprite==r.FrameSprite?r.Frame:-1;
        /// <summary>Original actor atlas frames, foot anchor, work tools and depth; ephemeral actors share this path.</summary>
        public void UpsertResident(string address,string kind,string sheet,int roleFrame,Vector2 position,Vector2 velocity,double time,int direction,bool resting)
        {
            if(!residents.TryGetValue(address,out var r))
            {
                if(!objects.TryGetValue(address,out var root)){root=new GameObject("Original resident "+address);root.transform.SetParent(parent,false);objects.Add(address,root);}
                var captured=root.GetComponent<SpriteRenderer>();if(captured!=null)captured.enabled=false;
                root.transform.localScale=Vector3.one;root.transform.localRotation=Quaternion.identity;
                r=new ResidentArt{Root=root,Group=root.GetComponent<UnityEngine.Rendering.SortingGroup>()??root.AddComponent<UnityEngine.Rendering.SortingGroup>(),Body=ResidentPart(root.transform,"Original resident body"),Shadow=ResidentPart(root.transform,"Original resident foot shadow"),Tool=ResidentPart(root.transform,"Original resident work tool"),Effects=new SpriteRenderer[3]};
                for(int i=0;i<r.Effects.Length;i++)r.Effects[i]=ResidentPart(root.transform,"Original resident work particle "+i);
                if(sourceNodes.TryGetValue(address,out var source)&&source.Require("fields").TryGet("data",out var data))
                {if(data.TryGet("scale",out var scale))r.Scale=(float)scale.AsDouble();if(data.TryGet("ghost",out var ghost))r.Ghost=ghost.AsBool();}
                catalog.Apply(r.Shadow,ShadowSprite());r.Shadow.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(0,14));residents.Add(address,r);if(!this.moving.Any(m=>m.Address==address&&m.Kind=="npc"))NativeActors++;
            }
            r.Position=position;r.Sheet=sheet;r.Velocity=velocity;r.Time=time;r.Direction=direction;r.RoleFrame=roleFrame;r.Root.transform.localPosition=FoundationCoordinates.ToUnity(position);
            bool moving=BlueMapMigration.Residents.ResidentMotionModel.IsMoving(velocity);bool memory=kind=="memory"||kind=="memory_actor";
            int frame=memory?roleFrame*2+BlueMapMigration.Residents.ResidentMotionModel.MemoryFrame(time,moving):BlueMapMigration.Residents.ResidentMotionModel.CharacterFrame(time,BlueMapMigration.Player.PlayerMotorModel.SourceLengthSquared(velocity)>1);
            bool humanoid=memory||catalog.GetSprite(sheet+":down:idle")!=null;
            if(!humanoid)frame=(int)(time*1.6)%2;
            r.Frame=frame;catalog.Apply(r.Body,ResidentSheet(memory?"wm_people":sheet,frame,humanoid&&moving?Mathf.Clamp(direction,0,3):0));
            r.Body.transform.localScale=Vector3.one*(memory?2:r.Scale);float drop=memory?0:14-7*r.Scale;
            float ghostFloat=r.Ghost?(float)(Math.Sin(time*2)*3-4):0;r.Body.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(0,drop+ghostFloat));
            r.Body.color=new Color(1,1,1,r.Ghost?(float)(.78+Math.Sin(time*3)*.1):1);
            int depth=Mathf.RoundToInt(position.y);r.Group.sortingOrder=depth;r.Body.sortingOrder=0;r.Shadow.sortingOrder=-1;r.Tool.sortingOrder=1;foreach(var effect in r.Effects)effect.sortingOrder=2;
            r.Tool.enabled=false;foreach(var effect in r.Effects)effect.enabled=false;
            if(memory&&!moving)
            {
                catalog.Apply(r.Tool,ResidentSheet("wm_tools",resting&&roleFrame==1?8:roleFrame,0));r.Tool.enabled=true;r.Tool.transform.localScale=Vector3.one;
                r.Tool.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(13,5+(float)Math.Sin(time*3)*(resting?.3f:2)));
                r.Tool.transform.localRotation=Quaternion.Euler(0,0,!resting&&(roleFrame==0||roleFrame==1)?-(float)Math.Sin(time*3)*.25f*Mathf.Rad2Deg:0);
                if(!resting&&(roleFrame==1||roleFrame==2))for(int i=0;i<3;i++)
                {float drift=(float)((time*8+i*6)%18);var e=r.Effects[i];e.enabled=true;e.sprite=DotSprite();e.sharedMaterial=catalog.straightMaterial;e.color=new Color(.8f,.9f,1,.55f*(1-drift/20));e.transform.localPosition=FoundationCoordinates.ToUnity(roleFrame==2?new Vector2(17+i*2,2-drift):new Vector2(19+i*2,7+drift));e.transform.localScale=Vector3.one;e.transform.localRotation=Quaternion.identity;}
            }
            else if((kind=="supper"||kind=="supper_actor")&&snapshot.MapId=="lake"&&!moving&&!resting)
            {
                if(roleFrame==0)
                {float bobber=23+(float)Math.Sin(time*2)*2;ResidentLine(r.Effects[0],new Vector2(9,2),new Vector2(24,-22),2,new Color(198/255f,161/255f,114/255f));ResidentLine(r.Effects[1],new Vector2(24,-22),new Vector2(31,bobber),1,new Color(238/255f,224/255f,179/255f));var e=r.Effects[2];e.enabled=true;e.sprite=DotSprite();e.sharedMaterial=catalog.straightMaterial;e.color=new Color(233/255f,137/255f,100/255f);e.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(31,bobber));e.transform.localScale=Vector3.one*2;e.transform.localRotation=Quaternion.identity;}
                else if(roleFrame==1)ResidentLine(r.Effects[0],new Vector2(6,6),new Vector2(12+(float)Math.Sin(time*4)*5,14),2,new Color(231/255f,202/255f,161/255f));
                else{catalog.Apply(r.Tool,ResidentSheet("ls_items",0,0));r.Tool.enabled=true;r.Tool.transform.localScale=Vector3.one;r.Tool.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(12,9));r.Tool.transform.localRotation=Quaternion.identity;}
            }
            else if((kind=="village"||kind=="village_actor")&&sheet=="op_gardener"&&!moving&&position.x<17*32&&residentState.DayTime<.78&&(!residentState.Flag("op_new_adventure")||residentState.Flag("op_water")||residentState.Get("ng_plus").AsInt64()!=0))
            {for(int i=0;i<3;i++){var e=r.Effects[i];e.enabled=true;e.sprite=DotSprite();e.sharedMaterial=catalog.straightMaterial;e.color=new Color(130/255f,216/255f,241/255f);e.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(9+i*3,10+(float)((time*18+i*3)%12)));e.transform.localScale=Vector3.one;e.transform.localRotation=Quaternion.identity;}}
        }
        public void UpdateResidentWork(string address,string kind,string role,int taskIndex,bool pathEmpty,bool evening,bool resting)
        {
            if(!residents.TryGetValue(address,out var r))return;
            UpsertResident(address,kind,r.Sheet,kind=="supper"||kind=="supper_actor"?taskIndex:r.RoleFrame,r.Position,r.Velocity,r.Time,r.Direction,evening||resting);
            if(!pathEmpty&&(kind=="supper"||kind=="supper_actor"||kind=="village"||kind=="village_actor")){r.Tool.enabled=false;foreach(var effect in r.Effects)effect.enabled=false;}
        }
        public void UpdateResidentCat(string address,double panic,double calm,bool waiting)
        {
            if(!residents.TryGetValue(address,out var r))return;
            if(panic<=0&&!waiting){r.Effects[0].enabled=false;r.Effects[1].enabled=false;return;}
            ResidentRectangle(r.Effects[0],new Rect(-15,-20,30,4),new Color(39/255f,60/255f,67/255f));
            ResidentRectangle(r.Effects[1],new Rect(-14,-19,28*(panic>0?1:(float)(calm/2)),2),panic>0?new Color(234/255f,186/255f,128/255f):new Color(152/255f,220/255f,165/255f));r.Effects[1].sortingOrder=3;
        }
        public void RemoveResident(string address)
        {if(residents.Remove(address,out var r)){objects.Remove(address);overrides.Remove(address);r.Root.SetActive(false);UnityEngine.Object.Destroy(r.Root);NativeActors=Math.Max(0,NativeActors-1);}else if(objects.TryGetValue(address,out var node)){node.SetActive(false);overrides[address]=false;}}
        public Vector2 ResidentVisualPosition(string address)=>residents.TryGetValue(address,out var r)?r.Position:sourceNodes.TryGetValue(address,out var node)?Position(node):Vector2.zero;
        public int ResidentVisualFrame(string address)=>residents.TryGetValue(address,out var r)?r.Frame:0;
        public bool ClearVisibilityOverride(string sourceAddress)=>overrides.Remove(sourceAddress);
        public void SetVisible(string sourceAddress,bool visible){overrides[sourceAddress]=visible;if(objects.TryGetValue(sourceAddress,out var node)&&node!=null)node.SetActive(visible);}
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
            heatWindows?.Tick(state);StoryVisuals?.Tick(state);
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
        public void Dispose(){foreach(var sprite in owned)UnityEngine.Object.Destroy(sprite);owned.Clear();if(circleTexture!=null)UnityEngine.Object.Destroy(circleTexture);if(residentShadowTexture!=null)UnityEngine.Object.Destroy(residentShadowTexture);foreach(var texture in residentPrimitiveTextures)UnityEngine.Object.Destroy(texture);residentPrimitiveTextures.Clear();heatWindows?.Dispose();StoryVisuals?.Dispose();}
    }
}
