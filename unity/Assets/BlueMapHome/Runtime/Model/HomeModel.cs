using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using UnityEngine;
namespace BlueMapMigration.Home
{
 /// <summary>A whole tile of the house or the yard.</summary>
 public readonly struct HomeCell : IEquatable<HomeCell>
 {
  public readonly int X,Y;
  public HomeCell(int x,int y){X=x;Y=y;}
  public bool Equals(HomeCell other)=>X==other.X&&Y==other.Y;
  public override bool Equals(object other)=>other is HomeCell cell&&Equals(cell);
  public override int GetHashCode()=>X*397^Y;
  public string Key=>X.ToString(CultureInfo.InvariantCulture)+","+Y.ToString(CultureInfo.InvariantCulture);
  public HomeCell Offset(int dx,int dy)=>new HomeCell(X+dx,Y+dy);
 }
 /// <summary>An integer rectangle with the source's exclusive far edges.</summary>
 public readonly struct HomeRect
 {
  public readonly int X,Y,W,H;
  public HomeRect(int x,int y,int w,int h){X=x;Y=y;W=w;H=h;}
  public int EndX=>X+W;public int EndY=>Y+H;
  public bool Has(HomeCell c)=>c.X>=X&&c.Y>=Y&&c.X<EndX&&c.Y<EndY;
  public bool Encloses(HomeRect r)=>r.X>=X&&r.Y>=Y&&r.EndX<=EndX&&r.EndY<=EndY;
  public bool Intersects(HomeRect r)=>X<r.EndX&&EndX>r.X&&Y<r.EndY&&EndY>r.Y;
  public HomeRect Grow(int n)=>new HomeRect(X-n,Y-n,W+2*n,H+2*n);
  public IEnumerable<HomeCell> Cells(){for(int y=Y;y<EndY;y++)for(int x=X;x<EndX;x++)yield return new HomeCell(x,y);}
 }
 /// <summary>
 /// Original personal home and yard rules. A design is only a draft until it is applied; a refused
 /// design, a blocked route or a missing material changes nothing.
 /// </summary>
 public sealed class HomeModel
 {
  static FoundationValue catalogs,orders,newGame;
  static HashSet<HomeCell> yardFixed;static HashSet<HomeCell> baseReach;
  bool busy;
  public FoundationGameState State {get;} public InventoryModel Inventory {get;}
  public FoundationValue Catalogs=>catalogs;public static FoundationValue NewGame=>newGame;
  public Func<string,string> Translator {get;set;}=text=>text;
  public event Action Changed;public event Action SaveRequested;
  public static FoundationValue LoadCatalog()
  {
   if(catalogs!=null)return catalogs;
   var asset=UnityEngine.Resources.Load<TextAsset>("BlueMapHomeCatalog");if(asset==null)throw new FormatException("Missing original home catalog");
   var document=FoundationJson.ParsePlain(asset.text);
   if(document.Require("schema").AsString()!="bluemap.home.runtime-catalog.v1"||document.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid home source reference");
   orders=document.Require("orders");newGame=document.Require("newGame");catalogs=InventoryModelChecks.DecodeOrdered(document.Require("catalogsOrdered"));
   yardFixed=new HashSet<HomeCell>(catalogs.Require("yard").Require("fixed").Items.Select(v=>new HomeCell((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64())));baseReach=null;
   return catalogs;
  }
  public HomeModel(FoundationWorldRepository repository,FoundationGameState state,InventoryModel inventory=null)
  {
   State=state??throw new ArgumentNullException(nameof(state));Inventory=inventory??new InventoryModel(repository,state);
   if(!ReferenceEquals(State,Inventory.State))throw new ArgumentException("Home must share one game state");LoadCatalog();
  }
  static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue E()=>InventoryModel.Empty();
  static FoundationValue A(IEnumerable<FoundationValue> v)=>FoundationValue.Array(v);
  static FoundationValue G(FoundationValue d,string k,FoundationValue f)=>InventoryModel.Get(d,k,f);static FoundationValue R(FoundationValue d,string k,FoundationValue v,bool remove=false)=>InventoryModel.Replace(d,k,v,remove);
  static bool Obj(FoundationValue v)=>v!=null&&(v.Kind=="object"||v.Kind=="dictionary");static bool Arr(FoundationValue v)=>v!=null&&v.Kind=="array";static bool Str(FoundationValue v)=>v!=null&&v.Kind=="string";
  static bool Num(FoundationValue v)=>v!=null&&(v.Kind=="int"||v.Kind=="float")&&!Double.IsNaN(v.AsDouble())&&!Double.IsInfinity(v.AsDouble());
  static long N(FoundationValue v)=>v==null?0:v.Kind=="int"?v.AsInt64():v.Kind=="float"?(long)v.AsDouble():0;
  static bool Flag(FoundationValue d,string k)=>d.TryGet(k,out var v)&&v.Kind=="bool"&&v.AsBool();
  static FoundationValue Pair(long x,long y)=>A(new[]{I(x),I(y)});
  static HomeRect RectOf(FoundationValue v)=>new HomeRect((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64(),(int)v.Items[2].AsInt64(),(int)v.Items[3].AsInt64());
  public string Tr(string value)=>Translator==null?value:Translator(value);
  /// <summary>The source's integer test: an optional sign followed by digits only.</summary>
  static bool ValidInt(string text){if(String.IsNullOrEmpty(text))return false;int i=text[0]=='+'||text[0]=='-'?1:0;if(i==text.Length)return false;for(;i<text.Length;i++)if(text[i]<'0'||text[i]>'9')return false;return true;}
  // ===== Personal home ============================================================================
  public FoundationValue House=>catalogs.Require("house");public FoundationValue Pieces=>House.Require("pieces");
  public IReadOnlyList<string> PieceIds=>Pieces.Entries.Select(v=>v.Key.AsString()).ToArray();
  public static readonly HomeRect Room=new HomeRect(2,2,10,10);
  public int MaxPieces=>(int)House.Require("maxPieces").AsInt64();public int MaxSolid=>(int)House.Require("maxSolid").AsInt64();
  public FoundationValue Piece(string kind)=>Pieces.Require(kind);
  public bool IsBase(string kind)=>Pieces.TryGet(kind,out var p)&&Flag(p,"base");public bool IsFloor(string kind)=>Pieces.TryGet(kind,out var p)&&Flag(p,"floor");
  public string PieceName(string kind)=>Tr(Piece(kind).Require("name").AsString());public string PieceDescription(string kind)=>Tr(Piece(kind).Require("desc").AsString());
  public long PieceCap(string kind)=>Piece(kind).Require("cap").AsInt64();
  public HomeCell PieceSize(string kind){var size=Piece(kind).Require("size").Items;return new HomeCell((int)size[0].AsInt64(),(int)size[1].AsInt64());}
  public FoundationValue HouseDefaults()
  {
   var owned=E();foreach(string kind in PieceIds)owned=R(owned,kind,I(N(G(House.Require("startOwned"),kind,I(0)))));
   return FoundationValue.Object(new Dictionary<string,FoundationValue>{{"owned",owned},{"layout",House.Require("defaultLayout")},{"floor",I(0)},{"wall",I(0)},{"light",I(0)}});
  }
  static long Number(FoundationValue value,long fallback,long limit)=>Num(value)?(long)Math.Max(0,Math.Min(limit,value.AsDouble())):fallback;
  public FoundationValue NormalizeHouse(FoundationValue raw)
  {
   var result=HouseDefaults();if(!Obj(raw))return result;
   foreach(string key in new[]{"floor","wall","light"})result=R(result,key,I(Number(G(raw,key,I(0)),0,key=="light"?2:3)));
   var owned=G(raw,"owned",E());
   if(Obj(owned)){var clean=result.Require("owned");foreach(string kind in PieceIds)clean=R(clean,kind,I(Math.Max(N(G(clean,kind,I(0))),Number(G(owned,kind,I(0)),0,PieceCap(kind)))));result=R(result,"owned",clean);}
   var layout=G(raw,"layout",FoundationValue.Nil());
   if(Obj(layout)&&HouseLayoutReason(layout,result.Require("owned"))=="")
   {
    var clean=E();
    foreach(var row in layout.Entries)clean=R(clean,row.Key.AsString(),FoundationValue.Object(new Dictionary<string,FoundationValue>{{"kind",S(row.Value.Require("kind").AsString())},{"cell",Pair(N(row.Value.Require("cell").Items[0]),N(row.Value.Require("cell").Items[1]))},{"tint",I(N(G(row.Value,"tint",I(0))))}}));
    result=R(result,"layout",clean);
   }
   return result;
  }
  /// <summary>The source normalizes an older save the first time the home is consulted.</summary>
  public FoundationValue HouseState(){var raw=State.Get("personal_home");if(Obj(raw)&&raw.TryGet("layout",out _))return raw;var clean=NormalizeHouse(raw);State.Set("personal_home",clean);return clean;}
  FoundationValue HousePeek(){var raw=State.Get("personal_home");return Obj(raw)&&raw.TryGet("layout",out _)?raw:NormalizeHouse(raw);}
  public FoundationValue HouseView=>HousePeek();
  public HomeRect PieceRect(FoundationValue entry){var cell=entry.Require("cell").Items;var size=PieceSize(entry.Require("kind").AsString());return new HomeRect((int)N(cell[0]),(int)N(cell[1]),size.X,size.Y);}
  /// <summary>Foot anchor of a piece in source pixels.</summary>
  public Vector2 WorldPosition(FoundationValue entry){var r=PieceRect(entry);return new Vector2(r.X*32+r.W*16,r.Y*32+r.H*32-16);}
  public HashSet<HomeCell> HouseFixedCells(){var cells=new HashSet<HomeCell>();foreach(var r in House.Require("fixed").Items)foreach(var c in RectOf(r).Cells())cells.Add(c);return cells;}
  public static bool HouseReserved(HomeCell at)=>((at.X==6||at.X==7)&&at.Y>=6)||(at.Y==5&&at.X>=6)||(at.X==10&&at.Y==6)||(at.X==9&&at.Y==9);
  public string HouseLayoutReason(FoundationValue layout,FoundationValue owned)
  {
   if(layout.Entries.Count>MaxPieces)return Tr("Er passen maximaal twaalf meubels; berg eerst iets op.");
   var used=HouseFixedCells();var counts=new Dictionary<string,long>(StringComparer.Ordinal);int solid=0;
   foreach(var row in layout.Entries)
   {
    string id=row.Key.AsString();var e=row.Value;if(!Obj(e))return Tr("Ongeldige meubelgegevens.");
    var kindValue=G(e,"kind",S(""));if(!Str(kindValue)||!Pieces.TryGet(kindValue.AsString(),out var info))return Tr("Onbekend meubel.");
    string kind=kindValue.AsString();bool basePiece=Flag(info,"base");
    if(!basePiece)
    {
     string prefix=kind+":";string suffix=id.StartsWith(prefix,StringComparison.Ordinal)?id.Substring(prefix.Length):id;
     if(!id.StartsWith(prefix,StringComparison.Ordinal)||!ValidInt(suffix)||!Int64.TryParse(suffix,NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out long index)||index<1||index>info.Require("cap").AsInt64())return Tr("Ongeldige meubelgegevens.");
    }
    var cell=G(e,"cell",FoundationValue.Nil());if(!Arr(cell)||cell.Items.Count!=2)return Tr("Ongeldige meubelpositie.");
    foreach(var n in cell.Items)if(!Num(n)||n.AsDouble()<2||n.AsDouble()>11||n.AsDouble()!=Math.Floor(n.AsDouble()))return Tr("Plaats binnen de kamer.");
    var tint=G(e,"tint",I(0));if(!Num(tint)||tint.AsDouble()<0||tint.AsDouble()>2||tint.AsDouble()!=Math.Floor(tint.AsDouble()))return Tr("Ongeldige meubelkleur.");
    if(basePiece&&id!=kind)return Tr("Een basismeubel kan maar één keer worden geplaatst.");
    counts[kind]=(counts.TryGetValue(kind,out long seenCount)?seenCount:0)+1;
    if(counts[kind]>N(G(owned,kind,I(0))))return Tr("Dit meubel is nog niet in je meubelvoorraad.");
    var area=PieceRect(e);if(!Room.Encloses(area))return Tr("Plaats binnen de kamer.");
    if(Flag(info,"floor"))continue;
    foreach(var at in area.Cells())
    {
     if(HouseReserved(at))return Tr("Houd de deur en de gemarkeerde looproute vrij.");
     if(used.Contains(at))return Tr("Hier staat al iets; laat meubels naast elkaar passen.");
     used.Add(at);solid++;
    }
   }
   if(solid>MaxSolid)return Tr("Laat meer open vloer over; berg eerst een groot meubel op.");
   foreach(string kind in new[]{"bed","table","shelf"})if(!layout.TryGet(kind,out var basic)||!Obj(basic)||!Str(G(basic,"kind",S("")))||G(basic,"kind",S("")).AsString()!=kind)return Tr("Bed, tafel en boekenkast blijven aanwezig; je kunt ze wel verplaatsen.");
   // A complete flood fill prevents islands and unreachable corners, beyond the marked route.
   var start=new HomeCell(6,10);var seen=new HashSet<HomeCell>{start};var queue=new List<HomeCell>{start};
   for(int i=0;i<queue.Count;i++)foreach(var next in Around(queue[i]))if(Room.Has(next)&&!used.Contains(next)&&seen.Add(next))queue.Add(next);
   if(seen.Count!=Room.W*Room.H-used.Count)return Tr("Er raakt een hoek afgesloten; houd de kamer verbonden met de deur.");
   var bed=PieceRect(layout.Require("bed"));
   if(!seen.Contains(new HomeCell(bed.X-1,bed.EndY-1))&&!seen.Contains(new HomeCell(bed.EndX,bed.EndY-1))&&!seen.Contains(new HomeCell(bed.X,bed.EndY)))return Tr("Laat een bereikbare plek naast of voor het bed vrij.");
   return "";
  }
  static IEnumerable<HomeCell> Around(HomeCell at){yield return at.Offset(-1,0);yield return at.Offset(1,0);yield return at.Offset(0,-1);yield return at.Offset(0,1);}
  public static FoundationValue HouseCandidate(FoundationValue layout,string id,string kind,HomeCell at,long tint)=>R(layout,id,FoundationValue.Object(new Dictionary<string,FoundationValue>{{"kind",S(kind)},{"cell",Pair(at.X,at.Y)},{"tint",I(tint)}}));
  public string NextPieceId(string kind,FoundationValue layout)
  {
   if(IsBase(kind))return kind;long owned=N(G(HouseState().Require("owned"),kind,I(0)));
   for(long i=1;i<=owned;i++){string id=kind+":"+i.ToString(CultureInfo.InvariantCulture);if(!layout.TryGet(id,out _))return id;}
   return "";
  }
  public bool PieceUnlocked(string kind)
  {
   if(!Pieces.TryGet(kind,out var info))return false;string item=G(info,"item",S("")).AsString();
   bool found=!info.TryGet("item",out _)||State.Count(item)>0;
   if(item=="crystal_bos"&&(State.Flag("gate_temple")||State.Flag("game_completed")))found=true;
   return(!info.TryGet("flag",out var flag)||State.Flag(flag.AsString()))&&found;
  }
  public string MakePieceReason(string kind)
  {
   if(State.MapId!="player_home"||State.Transitioning||State.Ended)return Tr("Richt je woning binnen in je eigen huis in.");
   if(!Pieces.TryGet(kind,out var info))return Tr("Onbekend meubel.");
   if(N(G(HouseState().Require("owned"),kind,I(0)))>=info.Require("cap").AsInt64())return Tr("Je hebt al genoeg van dit meubel.");
   if(!PieceUnlocked(kind))return Tr(G(info,"hint",S("Nog niet ontdekt.")).AsString());
   foreach(var cost in info.Require("cost").Entries)if(Inventory.Available(cost.Key.AsString())<N(cost.Value))return Tr("Je mist materialen; je tas en bereikbare kist tellen mee.");
   return "";
  }
  public bool MakePiece(string kind)
  {
   if(busy||MakePieceReason(kind)!="")return false;busy=true;
   try
   {
    var cost=Piece(kind).Require("cost");if(cost.Entries.Count>0&&!Inventory.Consume(cost))return false;
    var house=HouseState();State.Set("personal_home",R(house,"owned",R(house.Require("owned"),kind,I(N(G(house.Require("owned"),kind,I(0)))+1))));
   }
   finally{busy=false;}
   Changed?.Invoke();SaveRequested?.Invoke();return true;
  }
  public string HousePlayerReason(FoundationValue layout,Vector2 player)
  {
   foreach(var row in layout.Entries)
   {
    if(IsFloor(row.Value.Require("kind").AsString()))continue;var r=PieceRect(row.Value);
    double x0=r.X*32-8,y0=r.Y*32-8,x1=r.EndX*32+8,y1=r.EndY*32+8;
    if(player.x>=x0&&player.y>=y0&&player.x<x1&&player.y<y1)return Tr("Je staat te dichtbij; loop eerst naar het vrije middenpad.");
   }
   return "";
  }
  public string HouseDraftReason(FoundationValue draft,Vector2 player)
  {
   var layout=G(draft,"layout",E());if(!Obj(layout))return Tr("Ongeldige meubelgegevens.");
   string reason=HouseLayoutReason(layout,HousePeek().Require("owned"));return reason!=""?reason:HousePlayerReason(layout,player);
  }
  public bool ApplyHouse(FoundationValue draft,Vector2 player)
  {
   if(busy||State.MapId!="player_home"||State.Transitioning||State.Ended)return false;
   foreach(string key in new[]{"layout","floor","wall","light"})if(!draft.TryGet(key,out _))return false;
   if(!Obj(draft.Require("layout")))return false;
   if(HouseLayoutReason(draft.Require("layout"),HouseState().Require("owned"))!=""||HousePlayerReason(draft.Require("layout"),player)!="")return false;
   busy=true;
   try{var next=HouseState();foreach(string key in new[]{"layout","floor","wall","light"})next=R(next,key,draft.Require(key));State.Set("personal_home",NormalizeHouse(next));}
   finally{busy=false;}
   Changed?.Invoke();SaveRequested?.Invoke();return true;
  }
  // ===== Yard =====================================================================================
  public FoundationValue Yard=>catalogs.Require("yard");public FoundationValue Units=>Yard.Require("units");public FoundationValue YardPieces=>Yard.Require("pieces");public FoundationValue Supplies=>Yard.Require("supplies");public FoundationValue Extensions=>Yard.Require("extensions");
  public IReadOnlyList<string> UnitIds=>Units.Entries.Select(v=>v.Key.AsString()).ToArray();public IReadOnlyList<string> YardPieceIds=>YardPieces.Entries.Select(v=>v.Key.AsString()).ToArray();
  public IReadOnlyList<string> SupplyIds=>Supplies.Entries.Select(v=>v.Key.AsString()).ToArray();public IReadOnlyList<string> ExtensionIds=>Extensions.Entries.Select(v=>v.Key.AsString()).ToArray();
  public int MaxPaths=>(int)Yard.Require("maxPaths").AsInt64();public int MaxFences=>(int)Yard.Require("maxFences").AsInt64();
  public const int YardWidth=40,YardHeight=44;
  public bool IsPath(string kind)=>YardPieces.TryGet(kind,out var p)&&Flag(p,"path");public bool IsGate(string kind)=>YardPieces.TryGet(kind,out var p)&&Flag(p,"gate");
  public string GroupOf(string kind)=>YardPieces.Require(kind).Require("group").AsString();
  public string ItemName(string item)=>Inventory.ItemName(item);
  public static HomeCell ParseCell(string value)
  {
   var parts=(value??"").Split(',');if(parts.Length!=2||!ValidInt(parts[0])||!ValidInt(parts[1])||!Int32.TryParse(parts[0],NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out int x)||!Int32.TryParse(parts[1],NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out int y))return new HomeCell(-99,-99);
   return new HomeCell(x,y);
  }
  public FoundationValue YardDefaults()
  {
   var stations=E();foreach(var unit in Units.Entries)stations=R(stations,unit.Key.AsString(),unit.Value.Require("start"));
   return FoundationValue.Object(new Dictionary<string,FoundationValue>{{"stations",stations},{"paths",E()},{"fences",E()},{"owned",Yard.Require("owned")},{"extensions",A(Array.Empty<FoundationValue>())}});
  }
  public string Terrain(HomeCell at){var rows=Yard.Require("rows").Items;if(at.Y<0||at.Y>=rows.Count)return "#";string row=rows[at.Y].AsString();return at.X>=0&&at.X<row.Length?row[at.X].ToString():"#";}
  bool SolidTerrain(HomeCell at){var solid=G(Yard.Require("solidTerrain"),Terrain(at),FoundationValue.Boolean(false));return solid.Kind=="bool"&&solid.AsBool();}
  public HomeCell Anchor(string id,FoundationValue data){var value=G(data.Require("stations"),id,A(Array.Empty<FoundationValue>()));return Arr(value)&&value.Items.Count==2?new HomeCell((int)N(value.Items[0]),(int)N(value.Items[1])):new HomeCell(-999,-999);}
  public static HomeRect Bounds(HomeCell at)=>new HomeRect(at.X-1,at.Y-1,3,3);
  /// <summary>A tile taken by a fixed object of the village map (a door, sign, resident or resource).</summary>
  public static bool YardFixedCell(HomeCell at){LoadCatalog();return yardFixed.Contains(at);}
  public static bool YardReserved(HomeCell at)=>new HomeRect(6,21,4,4).Has(at)||new HomeRect(17,30,9,3).Has(at)||new HomeRect(17,36,9,3).Has(at)||new HomeRect(17,39,6,4).Has(at)||(at.X==9&&at.Y==27)||(at.X==6&&at.Y==24);
  public bool OwnedCell(HomeCell at,FoundationValue extensions)
  {
   foreach(var r in Yard.Require("basePlots").Items)if(RectOf(r).Has(at))return true;
   foreach(var id in extensions.Items)if(Str(id)&&Extensions.TryGet(id.AsString(),out var extension)&&RectOf(extension.Require("rect")).Has(at))return true;
   return false;
  }
  public IEnumerable<HomeRect> Plots(){foreach(var r in Yard.Require("basePlots").Items)yield return RectOf(r);foreach(var e in Extensions.Entries)yield return RectOf(e.Value.Require("rect"));}
  public bool OnPlot(HomeCell at)=>Plots().Any(r=>r.Has(at));
  public FoundationValue FarmCells{get{var cells=G(State.Get("homestead"),"cells",E());return Obj(cells)?cells:E();}}
  static bool TreeCover(HomeCell at,FoundationValue farm)
  {
   foreach(var row in farm.Entries)
   {
    if(!Obj(row.Value)||!Str(G(row.Value,"crop",S("")))||G(row.Value,"crop",S("")).AsString()!="apple")continue;var pair=row.Key.AsString().Split(',');if(pair.Length!=2)continue;
    Int32.TryParse(pair[0],NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out int x);Int32.TryParse(pair[1],NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out int y);
    if(new HomeRect(x-1,y-1,3,3).Has(at))return true;
   }
   return false;
  }
  public string PlaceReason(HomeCell at,FoundationValue data,FoundationValue farm,bool solid)
  {
   if(!OwnedCell(at,data.Require("extensions")))return Tr("Kies je bestaande erf of ontsluit eerst deze bouwruimte.");
   if(Terrain(at)!="."||yardFixed.Contains(at)||(solid&&YardReserved(at)))return Tr("Houd water, gebouwen, bruggen en bestaande doorgangen vrij.");
   if(farm.TryGet(at.Key,out _)||TreeCover(at,farm))return Tr("Hier ligt landbouwgrond of een kanaal; je tuin wordt niet overschreven.");
   return "";
  }
  public long Used(FoundationValue data,string group)
  {
   long n=0;foreach(var row in data.Require("paths").Entries)if(row.Value.AsString()==group)n++;
   foreach(var row in data.Require("fences").Entries)if(GroupOf(row.Value.AsString())==group)n++;
   return n;
  }
  HashSet<HomeCell> WalkBlocked(FoundationValue data)
  {
   var blocked=new HashSet<HomeCell>(yardFixed);
   foreach(string id in UnitIds){var at=Anchor(id,data);if(at.X<0)continue;blocked.Add(at);if(id=="compost")blocked.Add(at.Offset(-1,0));}
   foreach(var row in data.Require("fences").Entries)if(!IsGate(row.Value.AsString()))blocked.Add(ParseCell(row.Key.AsString()));
   return blocked;
  }
  public HashSet<HomeCell> Reachable(FoundationValue data)
  {
   var blocked=WalkBlocked(data);var start=new HomeCell(7,22);blocked.Remove(start);var seen=new HashSet<HomeCell>{start};var queue=new List<HomeCell>{start};
   for(int head=0;head<queue.Count;head++)foreach(var next in Around(queue[head]))
   {
    if(next.X<0||next.X>=YardWidth||next.Y<0||next.Y>=YardHeight||seen.Contains(next)||blocked.Contains(next)||SolidTerrain(next))continue;
    seen.Add(next);queue.Add(next);
   }
   return seen;
  }
  static bool SameCell(FoundationValue a,FoundationValue b)
  {
   if(!Arr(a)||!Arr(b)||a.Items.Count!=b.Items.Count)return false;
   for(int i=0;i<a.Items.Count;i++){if(Num(a.Items[i])&&Num(b.Items[i])){if(a.Items[i].AsDouble()!=b.Items[i].AsDouble())return false;}else if(a.Items[i].CanonicalJson!=b.Items[i].CanonicalJson)return false;}
   return true;
  }
  static readonly HomeCell[] KeyPlaces={new HomeCell(9,27),new HomeCell(6,24),new HomeCell(19,40),new HomeCell(18,31),new HomeCell(23,31),new HomeCell(18,37),new HomeCell(23,37)};
  public string YardLayoutReason(FoundationValue data,FoundationValue farm,FoundationValue baseline)
  {
   var paths=data.Require("paths");var fences=data.Require("fences");var stations=data.Require("stations");
   if(paths.Entries.Count>MaxPaths||fences.Entries.Count>MaxFences)return Tr("Laat ruimte over: maximaal tachtig padtegels en veertig hek- of poortdelen.");
   foreach(string group in SupplyIds)if(Used(data,group)>N(G(data.Require("owned"),group,I(0))))return Tr("Maak eerst meer delen voor deze hele rij.");
   bool noBaseline=baseline==null||!Obj(baseline)||baseline.Entries.Count==0;
   var areas=new List<KeyValuePair<string,HomeRect>>();
   foreach(string id in UnitIds)
   {
    var at=Anchor(id,data);if(at.X<0)continue;var r=Bounds(at);areas.Add(new KeyValuePair<string,HomeRect>(id,r));
    var here=stations.Require(id);bool original=Units.Entries.Any(unit=>SameCell(here,unit.Value.Require("start")));
    bool untouched=original&&((noBaseline&&SameCell(here,Units.Require(id).Require("start")))||(!noBaseline&&SameCell(baseline.Require("stations").Require(id),here)));
    foreach(var c in r.Cells())
    {
     if(!original){string reason=PlaceReason(c,data,farm,true);if(reason!="")return reason;}
     else if(!untouched&&farm.TryGet(c.Key,out _))return Tr("De oude werkplek is inmiddels bewerkt; kies vrije grond.");
    }
   }
   foreach(var a in areas)foreach(var b in areas)if(a.Key!=b.Key&&a.Value.Grow(1).Intersects(b.Value))return Tr("Laat een tegel vrije ruimte tussen de werkplekken.");
   foreach(string field in new[]{"paths","fences"})foreach(var row in data.Require(field).Entries)
   {
    string id=row.Key.AsString();var at=ParseCell(id);string reason=PlaceReason(at,data,farm,field=="fences");if(reason!="")return reason;
    foreach(var area in areas)if(area.Value.Has(at))return Tr("Laat de zichtbare ruimte rond de werkplek vrij.");
    if(field=="paths"&&fences.TryGet(id,out var fence)&&!IsGate(fence.AsString()))return Tr("Leg een poortje op het pad, geen gesloten hek.");
   }
   if(baseReach==null)baseReach=Reachable(YardDefaults());
   var seen=Reachable(data);var blocked=WalkBlocked(data);
   foreach(var at in baseReach)if(OnPlot(at)&&!blocked.Contains(at)&&!seen.Contains(at))return Tr("Dit sluit een stuk erf af; laat een poortje of doorgang open.");
   foreach(var at in KeyPlaces)if(baseReach.Contains(at)&&!seen.Contains(at))return Tr("De woning, opslag, beekbruggen en meerroute moeten bereikbaar blijven.");
   return "";
  }
  public FoundationValue NormalizeYard(FoundationValue raw,FoundationValue farm)
  {
   var result=YardDefaults();if(!Obj(raw))return result;farm=Obj(farm)?farm:E();
   if(Arr(G(raw,"extensions",FoundationValue.Nil())))
   {
    var list=new List<FoundationValue>();foreach(var id in raw.Require("extensions").Items)if(Str(id)&&Extensions.TryGet(id.AsString(),out _)&&!list.Any(v=>v.AsString()==id.AsString()))list.Add(id);
    result=R(result,"extensions",A(list));
   }
   if(Obj(G(raw,"owned",FoundationValue.Nil())))
   {
    var owned=result.Require("owned");
    foreach(string group in SupplyIds){var value=G(raw.Require("owned"),group,I(0));if(Num(value))owned=R(owned,group,I(Math.Max(N(owned.Require(group)),(long)Math.Max(0,Math.Min(Supplies.Require(group).Require("cap").AsDouble(),value.AsDouble())))));}
    result=R(result,"owned",owned);
   }
   if(Obj(G(raw,"stations",FoundationValue.Nil())))
   {
    var stations=result.Require("stations");
    foreach(string id in UnitIds)
    {
     var value=G(raw.Require("stations"),id,Units.Require(id).Require("start"));if(!Arr(value))continue;
     if(value.Items.Count==0){stations=R(stations,id,A(Array.Empty<FoundationValue>()));continue;}
     if(value.Items.Count==2&&Num(value.Items[0])&&Num(value.Items[1])&&value.Items[0].AsDouble()>=0&&value.Items[0].AsDouble()<YardWidth&&value.Items[1].AsDouble()>=0&&value.Items[1].AsDouble()<YardHeight)stations=R(stations,id,Pair(N(value.Items[0]),N(value.Items[1])));
    }
    result=R(result,"stations",stations);
   }
   // Repair optional pieces one by one; malformed data never deletes a crop or work-in-progress job.
   if(YardLayoutReason(result,farm,YardDefaults())!="")
   {
    var stations=result.Require("stations");foreach(string id in UnitIds)if(!SameCell(stations.Require(id),Units.Require(id).Require("start")))stations=R(stations,id,A(Array.Empty<FoundationValue>()));
    result=R(result,"stations",stations);
   }
   foreach(string field in new[]{"paths","fences"})
   {
    var source=G(raw,field,FoundationValue.Nil());if(!Obj(source))continue;int limit=field=="paths"?MaxPaths:MaxFences;
    foreach(var row in source.Entries)
    {
     if(result.Require(field).Entries.Count>=limit)break;if(!Str(row.Value))continue;
     string id=row.Key.AsString(),kind=row.Value.AsString();var at=ParseCell(id);
     if(!YardPieces.TryGet(kind,out _)||IsPath(kind)!=(field=="paths")||at.Key!=id)continue;
     var candidate=R(result,field,R(result.Require(field),id,S(kind)));
     // Connectivity is checked after all fence pieces, so a complete saved gate can reconnect its enclosure.
     if(PlaceReason(at,candidate,farm,field=="fences")=="")result=candidate;
    }
   }
   if(YardLayoutReason(result,farm,result)!="")result=R(R(result,"paths",E()),"fences",E());
   return result;
  }
  /// <summary>An untouched save gains the original yard the first time the yard is consulted.</summary>
  public FoundationValue YardState(){var raw=State.Get("yard");if(Obj(raw)&&raw.TryGet("stations",out _))return raw;var clean=YardDefaults();State.Set("yard",clean);return clean;}
  FoundationValue YardPeek(){var raw=State.Get("yard");return Obj(raw)&&raw.TryGet("stations",out _)?raw:YardDefaults();}
  public FoundationValue YardView=>YardPeek();
  public bool BlocksWork(HomeCell at)
  {
   var data=YardState();if(data.Require("paths").TryGet(at.Key,out _)||data.Require("fences").TryGet(at.Key,out _))return true;
   foreach(string id in UnitIds)if(!SameCell(data.Require("stations").Require(id),Units.Require(id).Require("start"))&&Anchor(id,data).X>=0&&Bounds(Anchor(id,data)).Has(at))return true;
   return false;
  }
  public string Surface(HomeCell at){var kind=G(YardState().Require("paths"),at.Key,S(""));string name=Str(kind)?kind.AsString():"";return name=="boards"?"yard_boards":name!=""?"path":"";}
  public string MaterialReason(FoundationValue cost)
  {
   if(State.MapId!="village"||State.Transitioning||State.Ended)return Tr("Richt je erf buiten bij je woning in.");
   foreach(var row in cost.Entries)if(Inventory.Available(row.Key.AsString())<N(row.Value))return Tr("Je mist materialen; tas en bereikbare huisvoorraad tellen mee.");
   return "";
  }
  public bool MakeParts(string group)
  {
   if(busy||!Supplies.TryGet(group,out var info))return false;
   if(N(YardState().Require("owned").Require(group))+info.Require("amount").AsInt64()>info.Require("cap").AsInt64()||MaterialReason(info.Require("cost"))!="")return false;
   busy=true;
   try
   {
    if(!Inventory.Consume(info.Require("cost")))return false;
    var yard=YardState();State.Set("yard",R(yard,"owned",R(yard.Require("owned"),group,I(N(yard.Require("owned").Require(group))+info.Require("amount").AsInt64()))));
   }
   finally{busy=false;}
   Changed?.Invoke();SaveRequested?.Invoke();return true;
  }
  public bool Expand(string id)
  {
   if(busy||!Extensions.TryGet(id,out var info)||YardState().Require("extensions").Items.Any(v=>Str(v)&&v.AsString()==id)||MaterialReason(info.Require("cost"))!="")return false;
   busy=true;
   try
   {
    if(!Inventory.Consume(info.Require("cost")))return false;
    var yard=YardState();State.Set("yard",R(yard,"extensions",A(yard.Require("extensions").Items.Concat(new[]{S(id)}))));
   }
   finally{busy=false;}
   Changed?.Invoke();SaveRequested?.Invoke();return true;
  }
  static bool Inside(double cx,double cy,double w,double h,double grow,double x,double y)=>x>=cx-w/2-grow&&y>=cy-h/2-grow&&x<cx+w/2+grow&&y<cy+h/2+grow;
  public string ActorReason(FoundationValue data,Vector2 at)
  {
   double fx=at.x,fy=at.y+8;
   foreach(string id in UnitIds)
   {
    var anchor=Anchor(id,data);if(anchor.X<0)continue;bool compost=id=="compost";
    if(Inside(anchor.X*32+16-(compost?12:0),anchor.Y*32+21,compost?60:25,compost?36:14,8,fx,fy))return Tr("Je staat te dichtbij; loop eerst naar het vrije erfpad.");
   }
   foreach(var row in data.Require("fences").Entries)
   {
    string kind=row.Value.AsString();if(IsGate(kind))continue;bool vertical=kind.EndsWith("_v",StringComparison.Ordinal);var cell=ParseCell(row.Key.AsString());
    if(Inside(cell.X*32+(vertical?24:16),cell.Y*32+(vertical?16:24),vertical?6:28,vertical?28:6,9,fx,fy))return Tr("Je staat te dichtbij; loop eerst naar het vrije erfpad.");
   }
   return "";
  }
  public bool SchemaOk(FoundationValue data)
  {
   var stations=data.Require("stations");
   foreach(string id in UnitIds)
   {
    if(!stations.TryGet(id,out var value)||!Arr(value)||(value.Items.Count!=0&&value.Items.Count!=2))return false;
    if(value.Items.Count==2){foreach(var v in value.Items)if(v.Kind!="int"||v.AsInt64()<0||v.AsInt64()>=YardHeight)return false;if(value.Items[0].AsInt64()>=YardWidth)return false;}
   }
   if(stations.Entries.Count!=Units.Entries.Count)return false;
   foreach(string field in new[]{"paths","fences"})foreach(var row in data.Require(field).Entries)
   {
    string id=row.Key.AsString();if(ParseCell(id).Key!=id)return false;
    if(!Str(row.Value)||!YardPieces.TryGet(row.Value.AsString(),out _)||IsPath(row.Value.AsString())!=(field=="paths"))return false;
   }
   return true;
  }
  public string YardDraftReason(FoundationValue draft,Vector2 player)
  {
   string reason=YardLayoutReason(draft,FarmCells,YardPeek());return reason!=""?reason:ActorReason(draft,player);
  }
  public bool ApplyYard(FoundationValue draft,Vector2 player)
  {
   if(busy||State.MapId!="village"||State.Transitioning||State.Ended)return false;
   var next=YardState();
   foreach(string key in new[]{"stations","paths","fences"}){if(!Obj(G(draft,key,FoundationValue.Nil())))return false;next=R(next,key,draft.Require(key));}
   if(!SchemaOk(next))return false;
   if(YardLayoutReason(next,FarmCells,YardState())!=""||ActorReason(next,player)!="")return false;
   busy=true;try{State.Set("yard",next);}finally{busy=false;}
   Changed?.Invoke();SaveRequested?.Invoke();return true;
  }
 }
}
