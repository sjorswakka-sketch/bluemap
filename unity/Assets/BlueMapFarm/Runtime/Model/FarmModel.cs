using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Inventory;
using BlueMapMigration.Professions;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>
 /// The original garden: tilled soil, irrigation channels, crops, the orchard, compost, wine and honey.
 /// Growth runs on active play time only; nothing withers, decays or catches up while the game is closed.
 /// The world's collision answer, the stations within reach and the player's position are explicit inputs.
 /// </summary>
 public sealed class FarmModel
 {
  static FoundationValue catalogs,orders,newGame;static HashSet<HomeCell> sources;
  bool busy,orchardBusy;
  FoundationValue wetFor;readonly List<HomeCell> wetOrder=new List<HomeCell>();readonly Dictionary<HomeCell,HomeCell> flow=new Dictionary<HomeCell,HomeCell>();
  FoundationValue indexFor;readonly Dictionary<string,FoundationValue> index=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);
  public FoundationGameState State {get;} public InventoryModel Inventory {get;} public ProfessionsModel Professions {get;} public HomeModel Home {get;}
  public static FoundationValue Catalogs=>LoadCatalog();public static FoundationValue NewGame{get{LoadCatalog();return newGame;}}
  public Func<string,string> Translator {get;set;}=text=>text;
  /// <summary>True when a visible station with this role (and unit, when given) is within reach of the player.</summary>
  public Func<string,string,bool> Near {get;set;}=(role,unit)=>false;
  /// <summary>The world's own answer to "can a body stand on this tile".</summary>
  public Func<HomeCell,bool> SpawnFits {get;set;}=cell=>true;
  public Func<Vector2> PlayerPosition {get;set;}=()=>Vector2.zero;
  /// <summary>The chosen garden tool; an empty text means the hoe is put away.</summary>
  public string Mode {get;set;}="";
  public bool ShowWater {get;set;}
  public event Action Changed;public event Action SaveRequested;public event Action TreesChanged;
  public static FoundationValue LoadCatalog()
  {
   if(catalogs!=null)return catalogs;
   var asset=Resources.Load<TextAsset>("BlueMapFarmCatalog");if(asset==null)throw new FormatException("Missing original farm catalog");
   var document=FoundationJson.ParsePlain(asset.text);
   if(document.Require("schema").AsString()!="bluemap.farm.runtime-catalog.v1"||document.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid farm source reference");
   orders=document.Require("orders");newGame=document.Require("newGame");var decoded=InventoryModelChecks.DecodeOrdered(document.Require("catalogsOrdered"));
   sources=new HashSet<HomeCell>(decoded.Require("farm").Require("sources").Items.Select(v=>new HomeCell((int)v.Items[0].AsInt64(),(int)v.Items[1].AsInt64())));
   catalogs=decoded;return catalogs;
  }
  public FarmModel(FoundationWorldRepository repository,FoundationGameState state,InventoryModel inventory=null,ProfessionsModel professions=null,HomeModel home=null)
  {
   State=state??throw new ArgumentNullException(nameof(state));Inventory=inventory??new InventoryModel(repository,state);
   Professions=professions??new ProfessionsModel(repository,state,Inventory);Home=home??new HomeModel(repository,state,Inventory);
   if(!ReferenceEquals(State,Inventory.State)||!ReferenceEquals(State,Home.State)||!ReferenceEquals(State,Professions.State))throw new ArgumentException("Farm must share one game state");LoadCatalog();
  }
  static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue D(double v)=>FoundationValue.Number(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);
  static FoundationValue E()=>InventoryModel.Empty();static FoundationValue A(IEnumerable<FoundationValue> v)=>FoundationValue.Array(v);
  static FoundationValue G(FoundationValue d,string k,FoundationValue f)=>InventoryModel.Get(d,k,f);static FoundationValue R(FoundationValue d,string k,FoundationValue v,bool remove=false)=>InventoryModel.Replace(d,k,v,remove);
  static bool Obj(FoundationValue v)=>v!=null&&(v.Kind=="object"||v.Kind=="dictionary");static bool Arr(FoundationValue v)=>v!=null&&v.Kind=="array";static bool Str(FoundationValue v)=>v!=null&&v.Kind=="string";
  static bool Num(FoundationValue v)=>v!=null&&(v.Kind=="int"||v.Kind=="float")&&!Double.IsNaN(v.AsDouble())&&!Double.IsInfinity(v.AsDouble());
  static bool True(FoundationValue d,string k)=>Obj(d)&&d.TryGet(k,out var v)&&v.Kind=="bool"&&v.AsBool();
  static string Text(FoundationValue d,string k)=>Obj(d)&&d.TryGet(k,out var v)&&Str(v)?v.AsString():"";
  static double F(FoundationValue v)=>v!=null&&(v.Kind=="int"||v.Kind=="float")?v.AsDouble():0;
  static long N(FoundationValue v)=>v==null?0:v.Kind=="int"?v.AsInt64():v.Kind=="float"?(long)v.AsDouble():0;
  static FoundationValue Make(params (string key,FoundationValue value)[] rows)=>FoundationValue.Object(rows.Select(r=>new KeyValuePair<FoundationValue,FoundationValue>(S(r.key),r.value)));
  public string Tr(string value)=>Translator==null?value:Translator(value);
  /// <summary>Source-style text fill: every %d, %s and %.0f takes the next value.</summary>
  static string Fill(string text,params object[] values)
  {
   foreach(object value in values)
   {
    int best=-1,width=0;foreach(string token in new[]{"%d","%s","%.0f"}){int at=text.IndexOf(token,StringComparison.Ordinal);if(at>=0&&(best<0||at<best)){best=at;width=token.Length;}}
    if(best<0)break;string shown=value is double number?Math.Round(number,MidpointRounding.AwayFromZero).ToString("0",CultureInfo.InvariantCulture):Convert.ToString(value,CultureInfo.InvariantCulture);
    text=text.Substring(0,best)+shown+text.Substring(best+width);
   }
   return text;
  }
  public string Format(string template,params object[] values)=>Fill(Tr(template),values);
  // --- Catalog --------------------------------------------------------------------------------
  public static FoundationValue Farm=>LoadCatalog().Require("farm");public static FoundationValue Crops=>Farm.Require("crops");public static FoundationValue Jobs=>Farm.Require("jobs");
  public static FoundationValue Prices=>Farm.Require("prices");public static FoundationValue Starter=>Farm.Require("starter");public static FoundationValue Names=>Farm.Require("names");
  public static IReadOnlyList<string> CropIds=>Crops.Entries.Select(v=>v.Key.AsString()).ToArray();public static IReadOnlyList<string> JobIds=>Jobs.Entries.Select(v=>v.Key.AsString()).ToArray();
  public static IReadOnlyList<string> ToolModes=>Farm.Require("toolModes").Items.Select(v=>v.AsString()).ToArray();public static IReadOnlyList<string> SeedBook=>Farm.Require("seedBook").Items.Select(v=>v.AsString()).ToArray();
  public static bool IsCrop(string id)=>id!=null&&Crops.TryGet(id,out _);public static bool Named(string id)=>id!=null&&Names.TryGet(id,out _);
  public static FoundationValue Crop(string id)=>Crops.Require(id);public static string SeedOf(string crop)=>Crop(crop).Require("seed").AsString();public static string OutputOf(string crop)=>Crop(crop).Require("output").AsString();
  public static bool IsSource(HomeCell at){LoadCatalog();return sources.Contains(at);}
  public static IReadOnlyCollection<HomeCell> Sources{get{LoadCatalog();return sources;}}
  public string CropName(string id)=>Named(id)?Tr(Names.Require(id).AsString()):id=="grape"?Tr("Druivenstok"):Tr("Bloemen");
  public string ModeName(string mode)=>Tr(G(Farm.Require("modeNames"),mode??"",S("Gereedschap opbergen")).AsString());
  public string StationName(string role)=>Tr(G(Farm.Require("stationNames"),role??"",S("Woning en tuin")).AsString());
  public string GroupName(string crop)=>Crop(crop).TryGet("group",out var group)?Tr(Farm.Require("groups").Items[(int)group.AsInt64()].AsString()):"";
  public string Note(string crop)=>Farm.Require("notes").TryGet(crop,out var note)?Tr(note.AsString()):Tr(Inventory.ItemDescription(SeedOf(crop)));
  public static string Key(HomeCell at)=>at.Key;
  /// <summary>The source engine's lenient text-to-integer rule: digits before the first dot count, other characters are skipped.</summary>
  public static long LenientInt(string text)
  {
   if(String.IsNullOrEmpty(text))return 0;int to=text.IndexOf('.');if(to<0)to=text.Length;long integer=0,sign=1;
   for(int i=0;i<to;i++){char c=text[i];if(c>='0'&&c<='9'){if(integer>(Int64.MaxValue-(c-'0'))/10)return sign==1?Int64.MaxValue:Int64.MinValue;integer=integer*10+(c-'0');}else if(integer==0&&c=='-')sign=-sign;}
   return integer*sign;
  }
  public static HomeCell Cell(string value){var parts=(value??"").Split(',');return parts.Length==2?new HomeCell((int)LenientInt(parts[0]),(int)LenientInt(parts[1])):new HomeCell(-1,-1);}
  public static bool Garden(HomeCell at)=>new HomeRect(4,29,31,12).Has(at)&&at.X!=20&&at.X!=21;
  public static double Duration(FoundationValue entry){var info=Crop(Text(entry,"crop"));return True(entry,"established")?F(G(info,"regrow",info.Require("seconds"))):F(info.Require("seconds"));}
  public static long Amount(FoundationValue entry){var info=Crop(Text(entry,"crop"));return N(info.Require("yield"))+(True(entry,"fertilized")?N(G(info,"bonus",I(0))):0);}
  /// <summary>The trunk of the apple tree whose three-by-three crown covers this tile, or (-99,-99).</summary>
  public static HomeCell TreeCover(HomeCell at,FoundationValue cells)
  {
   foreach(var row in cells.Entries)
   {
    if(Text(row.Value,"crop")!="apple")continue;var pair=row.Key.AsString().Split(',');if(pair.Length!=2)continue;
    var center=new HomeCell((int)LenientInt(pair[0]),(int)LenientInt(pair[1]));if(new HomeRect(center.X-1,center.Y-1,3,3).Has(at))return center;
   }
   return new HomeCell(-99,-99);
  }
  // --- Saved state ----------------------------------------------------------------------------
  static double Clamp(FoundationValue value,double low,double high)=>Num(value)?Math.Min(Math.Max(value.AsDouble(),low),high):low;
  static int CodePoints(string text){int n=0;for(int i=0;i<text.Length;i++){if(Char.IsHighSurrogate(text[i])&&i+1<text.Length&&Char.IsLowSurrogate(text[i+1]))i++;n++;}return n;}
  public FoundationValue Normalize(FoundationValue raw)
  {
   var cells=new List<KeyValuePair<FoundationValue,FoundationValue>>();var jobs=new List<KeyValuePair<FoundationValue,FoundationValue>>();
   var due=new List<KeyValuePair<FoundationValue,FoundationValue>>();var drops=new List<KeyValuePair<FoundationValue,FoundationValue>>();double wild=0,honeyTime=0;long honey=0;
   if(Obj(raw))
   {
    if(Obj(G(raw,"cells",null)))foreach(var row in raw.Require("cells").Entries)
    {
     if(!Str(row.Key)||!Garden(Cell(row.Key.AsString()))||!Obj(row.Value))continue;string kind=Text(row.Value,"kind");if(kind!="soil"&&kind!="channel")continue;
     var clean=Make(("kind",S(kind)));string crop=Text(row.Value,"crop");
     if(kind=="soil"&&IsCrop(crop))
     {
      clean=R(clean,"crop",S(crop));if(True(row.Value,"established")&&Crop(crop).TryGet("regrow",out _))clean=R(clean,"established",B(true));
      clean=R(clean,"growth",D(Clamp(G(row.Value,"growth",null),0,Duration(clean))));clean=R(clean,"fertilized",B(True(row.Value,"fertilized")));
     }
     cells.RemoveAll(e=>e.Key.AsString()==row.Key.AsString());cells.Add(new KeyValuePair<FoundationValue,FoundationValue>(row.Key,clean));
    }
    if(Obj(G(raw,"jobs",null)))foreach(string id in JobIds)
    {
     var job=G(raw.Require("jobs"),id,null);if(!Obj(job))continue;
     jobs.Add(new KeyValuePair<FoundationValue,FoundationValue>(S(id),Make(("batches",I((long)Clamp(G(job,"batches",null),1,20))),("time",D(Clamp(G(job,"time",null),0,F(Jobs.Require(id).Require("seconds"))))))));
    }
    foreach(string field in new[]{"animal_due","drops"})
    {
     if(!Obj(G(raw,field,null)))continue;var target=field=="animal_due"?due:drops;
     foreach(var row in raw.Require(field).Entries)
     {
      if(target.Count>=128)break;if(!Str(row.Key)||CodePoints(row.Key.AsString())>140)continue;
      FoundationValue clean=null;
      if(field=="animal_due")clean=D(Clamp(row.Value,0,State.PlayTime+90));
      else if(Obj(row.Value)&&Str(G(row.Value,"map",null))&&Arr(G(row.Value,"pos",null))&&row.Value.Require("pos").Items.Count==2)
      {
       var pos=row.Value.Require("pos").Items;bool numeric=(pos[0].Kind=="int"||pos[0].Kind=="float")&&(pos[1].Kind=="int"||pos[1].Kind=="float");
       if(numeric)clean=Make(("map",row.Value.Require("map")),("pos",A(new[]{D(Clamp(pos[0],0,10000)),D(Clamp(pos[1],0,10000))})));
      }
      if(clean==null)continue;target.RemoveAll(e=>e.Key.AsString()==row.Key.AsString());target.Add(new KeyValuePair<FoundationValue,FoundationValue>(row.Key,clean));
     }
    }
    wild=Clamp(G(raw,"wild_due",null),0,State.PlayTime+120);honey=(long)Clamp(G(raw,"honey",null),0,8);honeyTime=Clamp(G(raw,"honey_time",null),0,120);
   }
   return Make(("cells",FoundationValue.Object(cells)),("jobs",FoundationValue.Object(jobs)),("animal_due",FoundationValue.Object(due)),("drops",FoundationValue.Object(drops)),("wild_due",D(wild)),("honey",I(honey)),("honey_time",D(honeyTime)));
  }
  /// <summary>The saved garden; a save from before the garden existed receives the empty layout once.</summary>
  public FoundationValue FarmState(){var raw=State.Get("homestead");if(Obj(raw)&&raw.TryGet("cells",out _))return raw;var clean=Normalize(E());State.Set("homestead",clean);return clean;}
  /// <summary>Reading for display never writes the save.</summary>
  public FoundationValue FarmView{get{var raw=State.Get("homestead");return Obj(raw)&&raw.TryGet("cells",out _)?raw:Normalize(E());}}
  public FoundationValue Cells=>FarmState().Require("cells");
  FoundationValue Entry(FoundationValue cells,string key)
  {
   if(!ReferenceEquals(indexFor,cells)){index.Clear();foreach(var row in cells.Entries)index[row.Key.AsString()]=row.Value;indexFor=cells;}
   return index.TryGetValue(key,out var entry)?entry:E();
  }
  public FoundationValue EntryAt(HomeCell at)=>Entry(Cells,at.Key);
  static bool Empty(FoundationValue entry)=>!Obj(entry)||entry.Entries.Count==0;
  void SetCells(FoundationValue cells){State.Set("homestead",R(FarmState(),"cells",cells));}
  void Notify(){Changed?.Invoke();SaveRequested?.Invoke();}
  // --- Irrigation -----------------------------------------------------------------------------
  static readonly (int x,int y)[] Steps={(-1,0),(1,0),(0,-1),(0,1)};
  /// <summary>Water spreads from the brook through every connected channel; the result follows the saved channels.</summary>
  public void Irrigate()
  {
   var cells=Cells;if(ReferenceEquals(wetFor,cells))return;wetFor=cells;wetOrder.Clear();flow.Clear();
   var channels=new List<HomeCell>();var set=new HashSet<HomeCell>();
   foreach(var row in cells.Entries)if(Text(row.Value,"kind")=="channel"){var at=Cell(row.Key.AsString());if(set.Add(at))channels.Add(at);}
   var queue=new List<HomeCell>();
   foreach(var at in channels)foreach(var step in Steps){var next=at.Offset(step.x,step.y);if(sources.Contains(next)){flow[at]=next;wetOrder.Add(at);queue.Add(at);break;}}
   for(int head=0;head<queue.Count;head++)
   {
    var at=queue[head];
    foreach(var step in Steps){var next=at.Offset(step.x,step.y);if(set.Contains(next)&&!flow.ContainsKey(next)){flow[next]=at;wetOrder.Add(next);queue.Add(next);}}
   }
  }
  public IReadOnlyList<HomeCell> WetCells{get{Irrigate();return wetOrder;}}
  public bool IsWet(HomeCell at){Irrigate();return flow.ContainsKey(at);}
  public HomeCell FlowFrom(HomeCell at){Irrigate();return flow.TryGetValue(at,out var from)?from:new HomeCell(-99,-99);}
  public bool Watered(HomeCell at)
  {
   Irrigate();if(flow.ContainsKey(at)||sources.Contains(at))return true;
   foreach(var step in Steps){var next=at.Offset(step.x,step.y);if(flow.ContainsKey(next)||sources.Contains(next))return true;}
   return false;
  }
  /// <summary>An apple tree drinks from water within two tiles of its trunk; every other crop needs it next door.</summary>
  public bool CropWatered(HomeCell at,FoundationValue entry)
  {
   if(Text(entry,"crop")!="apple")return Watered(at);Irrigate();
   for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){if(Math.Abs(x)+Math.Abs(y)>2)continue;var next=at.Offset(x,y);if(flow.ContainsKey(next)||sources.Contains(next))return true;}
   return false;
  }
  // --- Bees -----------------------------------------------------------------------------------
  /// <summary>Wild flowers and ripe bee plants within five tiles of the hive.</summary>
  public long FlowerCountAt(HomeCell at,FoundationValue farm)
  {
   if(at.X<0)return 0;long n=0;
   foreach(var flower in Home.Yard.Require("wildFlowers").Items){var c=new HomeCell((int)flower.Items[0].AsInt64(),(int)flower.Items[1].AsInt64());if(Within(c,at)&&!farm.TryGet(c.Key,out _))n++;}
   foreach(var row in farm.Entries)
   {
    string crop=Text(row.Value,"crop");if(!IsCrop(crop)||!True(Crop(crop),"bees"))continue;
    if(F(G(row.Value,"growth",I(0)))>=Duration(row.Value)&&Within(HomeModel.ParseCell(row.Key.AsString()),at))n++;
   }
   return n;
  }
  static bool Within(HomeCell a,HomeCell b){long dx=a.X-b.X,dy=a.Y-b.Y;return dx*dx+dy*dy<=25;}
  public long Flowers()=>FlowerCountAt(Home.Anchor("hive",Home.YardState()),Cells);
  // --- Active time ----------------------------------------------------------------------------
  /// <summary>Advance crops, compost, wine and honey by active play time.</summary>
  public void Advance(double delta)
  {
   if(!(delta>0))return;var data=FarmState();Irrigate();var cells=data.Require("cells");List<KeyValuePair<FoundationValue,FoundationValue>> grown=null;int at=0;
   foreach(var row in cells.Entries)
   {
    string crop=Text(row.Value,"crop");
    if(IsCrop(crop)&&CropWatered(Cell(row.Key.AsString()),row.Value))
    {
     double before=F(row.Value.Require("growth")),after=Math.Min(Duration(row.Value),before+delta);
     if(grown==null)grown=new List<KeyValuePair<FoundationValue,FoundationValue>>(cells.Entries);
     grown[at]=new KeyValuePair<FoundationValue,FoundationValue>(row.Key,R(row.Value,"growth",D(after)));
    }
    at++;
   }
   if(grown!=null){var next=FoundationValue.Object(grown);if(ReferenceEquals(wetFor,cells))wetFor=next;data=R(data,"cells",next);}
   var jobs=data.Require("jobs");if(jobs.Entries.Count>0)
   {
    var timed=jobs;foreach(var job in jobs.Entries)timed=R(timed,job.Key.AsString(),R(job.Value,"time",D(Math.Min(F(Jobs.Require(job.Key.AsString()).Require("seconds")),F(job.Value.Require("time"))+delta))));
    data=R(data,"jobs",timed);
   }
   State.Set("homestead",data);
   long honey=N(data.Require("honey"));double honeyTime=F(data.Require("honey_time"));
   if(Flowers()>=3&&honey<8){honeyTime+=delta;while(honeyTime>=120&&honey<8){honey++;honeyTime-=120;}data=R(R(data,"honey",I(honey)),"honey_time",D(honeyTime));State.Set("homestead",data);}
   else if(honey>=8){data=R(data,"honey_time",D(0.0));State.Set("homestead",data);}
   // A collected manure pile leaves the garden's memory; the pickup flag is no longer needed afterwards.
   bool collected=false;
   foreach(var drop in data.Require("drops").Entries.ToArray())
   {
    string flag="hs_drop:"+drop.Key.AsString();if(!State.Flag(flag))continue;
    data=R(data,"drops",R(data.Require("drops"),drop.Key.AsString(),null,true));State.Set("homestead",data);State.SetFlag(flag,false);collected=true;
   }
   if(collected)SaveRequested?.Invoke();
  }
  // --- Supplies -------------------------------------------------------------------------------
  public bool HasSupplies=>State.Flag("hs_supplies");
  /// <summary>The one-time free hoe and seeds from the garden guide.</summary>
  public bool TakeSupplies()
  {
   if(busy||State.Flag("hs_supplies")||!(Near("supplies","")||Near("guide","")))return false;var pack=Farm.Require("pack");
   foreach(var row in pack.Entries)if(Inventory.Room(row.Key.AsString())<N(row.Value))return false;
   busy=true;try{State.SetFlag("hs_supplies",true);foreach(var row in pack.Entries)Inventory.Give(row.Key.AsString(),N(row.Value),true);}finally{busy=false;}
   Notify();return true;
  }
  // --- Working a tile -------------------------------------------------------------------------
  public string HarvestReason(FoundationValue entry)
  {
   string crop=Text(entry,"crop");if(!IsCrop(crop)||crop=="flower")return Tr("Richt op een oogstbaar gewas.");
   if(F(G(entry,"growth",I(0)))<Duration(entry))return Tr("Dit gewas is nog niet rijp.");
   var info=Crop(crop);if(Inventory.Room(OutputOf(crop))<Amount(entry))return Tr("Maak ruimte in je tas voor de volledige oogst.");
   if(True(info,"annual")&&Inventory.Room(SeedOf(crop))<1)return Tr("Maak ook ruimte voor het zaad dat je terugkrijgt.");
   return "";
  }
  bool HarvestCell(string key)
  {
   var entry=Entry(Cells,key);if(HarvestReason(entry)!="")return false;string crop=Text(entry,"crop");var info=Crop(crop);long count=Amount(entry);bool annual=True(info,"annual");
   FoundationValue next=entry;
   if(annual)foreach(string field in new[]{"crop","growth","fertilized","established"})next=R(next,field,null,true);
   else{next=R(R(next,"growth",D(0.0)),"fertilized",B(false));if(info.TryGet("regrow",out _))next=R(next,"established",B(true));}
   // The plant is committed before any item listener runs; a full harvest is never given twice.
   SetCells(R(Cells,key,next));Inventory.Give(OutputOf(crop),count,true);if(annual)Inventory.Give(SeedOf(crop),1,true);
   if(crop=="grape")State.SetFlag("hs_intro_harvest",true);Professions.AddXp("foraging",crop=="grape"?4:3);return true;
  }
  public string CanopyReason(HomeCell at,FoundationValue cells)
  {
   int trees=cells.Entries.Count(row=>Text(row.Value,"crop")=="apple");if(trees>=12)return Tr("Laat ruimte over: maximaal twaalf appelbomen in je tuin.");
   var yard=Home.YardState();
   for(int y=at.Y-1;y<=at.Y+1;y++)for(int x=at.X-1;x<=at.X+1;x++)
   {
    var c=new HomeCell(x,y);
    if(!Garden(c)||Home.Terrain(c)!="."||HomeModel.YardReserved(c)||HomeModel.YardFixedCell(c))return Tr("Een appelboom heeft drie bij drie tegels vrije kroonruimte buiten de looproutes nodig.");
    if(TreeCover(c,cells).X>=0)return Tr("Laat de kronen van appelbomen vrij van elkaar.");
    if(!c.Equals(at)&&cells.TryGet(c.Key,out _))return Tr("Houd de kroonruimte vrij van gewassen en kanalen; leg water op twee tegels van de stam.");
    if(Home.BlocksWork(c))return Tr("Houd paden en erfwerk vrij van de boomkroon.");
    foreach(string unit in Home.UnitIds){var anchor=Home.Anchor(unit,yard);if(anchor.X>=0&&HomeModel.Bounds(anchor).Has(c))return Tr("Houd paden en erfwerk vrij van de boomkroon.");}
    if(!SpawnFits(c)&&!c.Equals(at))return Tr("Houd paden en erfwerk vrij van de boomkroon.");
   }
   return "";
  }
  public string PatchReason(HomeCell at)
  {
   var yard=Home.YardState();
   foreach(string unit in Home.UnitIds){var anchor=Home.Anchor(unit,yard);if(anchor.X>=0&&HomeModel.Bounds(anchor).Has(at))return Tr("Plant nieuwe gewassen buiten de zichtbare ruimte rond je werkplekken.");}
   return "";
  }
  /// <summary>Why this tool cannot be used on this tile right now; an empty text means it can.</summary>
  public string WorkReason(HomeCell at,string action)
  {
   var cells=Cells;var e=Entry(cells,at.Key);string crop=Text(e,"crop");
   if(State.MapId!="village"||!Garden(at))return Tr("Werk binnen je eigen tuin.");
   if(State.Count("hs_hoe")==0)return Tr("Haal eerst je gratis tuinhak bij het tuinbord.");
   if(Vector2.Distance(PlayerPosition(),new Vector2(at.X*32+16,at.Y*32+16))>68)return Tr("Kom iets dichterbij.");
   if(Home.BlocksWork(at))return Tr("Hier ligt je erfinrichting; berg die eerst op via Erf inrichten.");
   var cover=TreeCover(at,cells);if(cover.X>=0&&!cover.Equals(at))return Tr("Laat de kroonruimte rond de appelboom vrij; water kan buiten de kroon aansluiten.");
   if(crop=="apple"&&(action=="harvest"||action=="fertilize"||action=="fill"))
   {
    if(action=="harvest")return HarvestReason(e);
    if(action=="fertilize")return True(e,"fertilized")?Tr("Deze boom is al bemest."):State.Count("hs_fertilizer")<1?Tr("Maak eerst meststof op de mesthoop."):"";
    return Inventory.Room("or_apple_seed")<1?Tr("Maak ruimte in je tas voor het boompje."):"";
   }
   string terrain=Home.Terrain(at);
   if((terrain!="."&&!(terrain==","&&(action=="channel"||!Empty(e))))||!SpawnFits(at))return Tr("Houd deze plek vrij voor water, paden en voorwerpen.");
   if(action=="soil"||action=="channel")return Empty(e)?"":Tr("Deze tegel is al bewerkt.");
   if(IsCrop(action))
   {
    if(Text(e,"kind")!="soil")return Tr("Bewerk eerst de grond.");
    if(e.TryGet("crop",out _))return Tr("Hier groeit al iets.");
    if(State.Count(SeedOf(action))<1)return Tr("Je hebt geen passend zaad bij je.");
    if(action=="apple")return CanopyReason(at,cells);
    return Named(action)?PatchReason(at):"";
   }
   if(action=="fertilize")
   {
    if(!IsCrop(crop)||!Crop(crop).TryGet("bonus",out _))return Tr("Kies een oogstbaar gewas om te bemesten.");
    if(True(e,"fertilized"))return Tr("Deze stok is al bemest.");
    return State.Count("hs_fertilizer")<1?Tr("Maak eerst meststof op de mesthoop."):"";
   }
   if(action=="harvest")return HarvestReason(e);
   if(action=="fill")
   {
    if(Empty(e))return Tr("Deze grond is al hersteld.");
    return e.TryGet("crop",out _)&&Inventory.Room(SeedOf(crop))<1?Tr("Maak ruimte in je tas voor het zaad."):"";
   }
   return Tr("Kies een tuinhandeling.");
  }
  /// <summary>Use the chosen tool on one tile.</summary>
  public bool Act(HomeCell at,string action)
  {
   if(busy||State.InputLocked||WorkReason(at,action)!="")return false;
   var cells=Cells;string id=at.Key;var e=Entry(cells,id);string crop=Text(e,"crop");bool treeChanged=action=="apple"||(action=="fill"&&crop=="apple");bool ok=false;
   busy=true;
   try
   {
    if(action=="soil"&&Empty(e)){SetCells(R(cells,id,Make(("kind",S("soil")))));ok=true;}
    else if(action=="channel"&&Empty(e)){SetCells(R(cells,id,Make(("kind",S("channel")))));ok=true;}
    else if(IsCrop(action)&&Text(e,"kind")=="soil"&&!e.TryGet("crop",out _)&&State.Count(SeedOf(action))>0)
    {SetCells(R(cells,id,R(R(R(e,"crop",S(action)),"growth",D(0.0)),"fertilized",B(false))));Inventory.Take(SeedOf(action));ok=true;}
    else if(action=="fertilize"&&IsCrop(crop)&&Crop(crop).TryGet("bonus",out _)&&!True(e,"fertilized")&&State.Count("hs_fertilizer")>0)
    {SetCells(R(cells,id,R(e,"fertilized",B(true))));Inventory.Take("hs_fertilizer");ok=true;}
    else if(action=="harvest")ok=HarvestCell(id);
    else if(action=="fill"&&!Empty(e))
    {
     string seed=e.TryGet("crop",out _)?SeedOf(crop):"";
     if(seed==""||Inventory.Room(seed)>0){SetCells(R(cells,id,null,true));if(seed!="")Inventory.Give(seed,1,true);ok=true;}
    }
   }
   finally{busy=false;}
   if(ok){Notify();if(treeChanged)TreesChanged?.Invoke();}
   return ok;
  }
  /// <summary>Harvest every ripe crop at once beside the garden guide.</summary>
  public long HarvestAll()
  {
   if(busy||(State.MapId!="village"&&State.MapId!="player_home")||!Near("guide",""))return 0;long n=0;
   busy=true;try{foreach(string key in Cells.Entries.Select(row=>row.Key.AsString()).ToArray())if(HarvestCell(key))n++;}finally{busy=false;}
   if(n>0)Notify();return n;
  }
  // --- Compost, wine and honey ------------------------------------------------------------------
  static string StationFor(string id)=>id=="hive"?"hive":id=="compost"?"compost":"wine";
  static string UnitFor(string id)=>id=="hive"||id=="compost"?"":id;
  public FoundationValue Job(string id)=>G(FarmState().Require("jobs"),id,null);
  public long Honey=>N(FarmState().Require("honey"));public double HoneyTime=>F(FarmState().Require("honey_time"));
  public bool StartJob(string id,long batches)
  {
   if(busy||id==null||!Jobs.TryGet(id,out var recipe)||batches<1||batches>20||FarmState().Require("jobs").TryGet(id,out _))return false;
   if(State.MapId!="village"||!Near(StationFor(id),UnitFor(id)))return false;
   string input=recipe.Require("input").AsString();long cost=N(recipe.Require("cost"))*batches;if(Inventory.Available(input)<cost)return false;
   busy=true;
   try
   {
    if(!Inventory.Consume(Make((input,I(cost)))))return false;
    var data=FarmState();State.Set("homestead",R(data,"jobs",R(data.Require("jobs"),id,Make(("batches",I(batches)),("time",D(0.0))))));
   }
   finally{busy=false;}
   Notify();return true;
  }
  public bool Collect(string id)
  {
   if(busy||id==null||State.MapId!="village"||!Near(StationFor(id),UnitFor(id)))return false;var data=FarmState();
   if(id=="hive")
   {
    long honey=N(data.Require("honey"));if(honey==0||Inventory.Room("hs_honey")<honey)return false;
    busy=true;try{State.Set("homestead",R(data,"honey",I(0)));Inventory.Give("hs_honey",honey,true);}finally{busy=false;}
    Notify();return true;
   }
   if(!data.Require("jobs").TryGet(id,out var active)||!Jobs.TryGet(id,out var recipe))return false;
   long batches=N(active.Require("batches")),count=batches*N(recipe.Require("yield"));string output=recipe.Require("output").AsString();
   if(F(active.Require("time"))<F(recipe.Require("seconds"))||Inventory.Room(output)<count)return false;
   busy=true;try{State.Set("homestead",R(data,"jobs",R(data.Require("jobs"),id,null,true)));Inventory.Give(output,count,true);Professions.AddXp("cooking",batches*3);}finally{busy=false;}
   Notify();return true;
  }
  /// <summary>A calm animal leaves manure at most once every ninety seconds of play.</summary>
  public void AnimalDrop(string kind,Vector2 home,Vector2 position,bool dead,bool practice)
  {
   if(dead||practice||kind=="trail_moth"||kind=="trail_gull")return;
   string id=State.MapId+":"+kind+":"+new HomeCell((int)(home.x/32f),(int)(home.y/32f)).Key;var data=FarmState();
   if(data.Require("drops").Entries.Count>=64||State.PlayTime<F(G(data.Require("animal_due"),id,I(0))))return;
   string drop=id+":"+((long)(State.PlayTime*1000)).ToString(CultureInfo.InvariantCulture);
   data=R(data,"animal_due",R(data.Require("animal_due"),id,D(State.PlayTime+90)));
   data=R(data,"drops",R(data.Require("drops"),drop,Make(("map",S(State.MapId)),("pos",A(new[]{D(position.x),D(position.y)})))));
   State.Set("homestead",data);Notify();
  }
  public bool WildGrapesReady=>State.PlayTime>=F(FarmState().Require("wild_due"));
  public bool WildGrapes()
  {
   if(busy||State.MapId!="forest"||!Near("wild_grape","")||State.PlayTime<F(FarmState().Require("wild_due"))||Inventory.Room("hs_grape")<3)return false;
   busy=true;try{State.Set("homestead",R(FarmState(),"wild_due",D(State.PlayTime+120)));Inventory.Give("hs_grape",3,true);Professions.AddXp("foraging",4);}finally{busy=false;}
   Notify();return true;
  }
  // --- Seeds and orchard ------------------------------------------------------------------------
  public string SupplyReason()
  {
   if(State.Ended||State.Transitioning||(State.MapId!="village"&&State.MapId!="player_home")||!(Near("guide","")||Near("supplies","")))return Tr("Haal zaden en stekken bij je tuingids of de voorraad in je huis.");
   return "";
  }
  public bool HasOrchardStarter=>State.Flag("or_starter");
  public bool OrchardStarterFits=>Starter.Entries.All(row=>Inventory.Room(row.Key.AsString())>=N(row.Value));
  public bool OrchardStarter()
  {
   if(orchardBusy||State.Flag("or_starter")||SupplyReason()!=""||!OrchardStarterFits)return false;
   orchardBusy=true;try{State.SetFlag("or_starter",true);foreach(var row in Starter.Entries)Inventory.Give(row.Key.AsString(),N(row.Value),true);}finally{orchardBusy=false;}
   SaveRequested?.Invoke();return true;
  }
  public long Price(string crop)=>N(Prices.Require(crop));
  public string BuyReason(string crop,long n)
  {
   if(crop==null||!Prices.TryGet(crop,out var price)||(n!=1&&n!=5))return Tr("Kies een beschikbare teelt.");
   string reason=SupplyReason();if(reason!="")return reason;
   if(State.Coins<N(price)*n)return Tr("Je hebt te weinig munten voor dit zaad.");
   return Inventory.Room(SeedOf(crop))<n?Tr("Maak ruimte in je tas voor de zaden of stekken."):"";
  }
  public bool Buy(string crop,long n)
  {
   if(orchardBusy||BuyReason(crop,n)!="")return false;
   orchardBusy=true;try{Inventory.AddCoins(-Price(crop)*n);Inventory.Give(SeedOf(crop),n,true);}finally{orchardBusy=false;}
   SaveRequested?.Invoke();return true;
  }
  // --- Readable field feedback ----------------------------------------------------------------
  public string CellText(HomeCell at)
  {
   var e=EntryAt(at);string kind=Text(e,"kind");
   if(kind=="channel")return IsWet(at)?Tr("Kanaal aangesloten · water stroomt door."):Tr("Droog kanaal · verbind met de beek of een gevuld kanaal.");
   if(e.TryGet("crop",out _))
   {
    string crop=Text(e,"crop");bool watered=CropWatered(at,e);double growth=F(e.Require("growth")),duration=Duration(e);bool ready=growth>=duration;
    string stage=ready&&crop!="flower"?Tr("Rijp om te oogsten"):ready?Tr("In bloei"):watered?Format("Groeit · nog %.0f s actieve speeltijd",Math.Ceiling((double)(float)(duration-growth))):Tr("Wacht op water · verdort niet");
    string detail=crop=="grape"?Format("Opbrengst: %d druiven",True(e,"fertilized")?5:3):Tr("Voedt bijen binnen vijf tegels");
    if(Named(crop))
    {
     detail=Format("Opbrengst: %d × %s",Amount(e),Inventory.ItemName(OutputOf(crop)));
     detail+=" · "+(True(Crop(crop),"annual")?Tr("Zaad komt terug; daarna opnieuw planten"):Tr("Groeit na oogsten opnieuw aan"));
     if(True(Crop(crop),"bees")&&ready)detail+=" · "+Tr("Voedt bijen binnen vijf tegels");
    }
    return CropName(crop)+" · "+stage+"\n"+detail;
   }
   if(kind=="soil")return Watered(at)?Tr("Landbouwgrond · water aangesloten"):Tr("Landbouwgrond · leid water naar een aangrenzende tegel");
   return Tr("Vrije tuingrond");
  }
  public int GuideStep()
  {
   if(State.Flag("hs_intro_harvest"))return 4;bool soil=false,water=false,planted=false;
   foreach(var row in Cells.Entries)
   {
    if(Text(row.Value,"kind")!="soil")continue;soil=true;
    if(Watered(Cell(row.Key.AsString()))){water=true;if(Text(row.Value,"crop")=="grape")planted=true;}
   }
   return planted?3:water?2:soil?1:0;
  }
  public string GuideText()
  {
   if(State.Count("hs_hoe")==0)return Tr("Tuinhulp · Haal eerst je gratis hak en zaden bij het tuinbord.");
   switch(GuideStep())
   {
    case 0:return Tr("Tuinhulp 1/4 · Bewerk één vak grond bij de beek.");
    case 1:return Tr("Tuinhulp 2/4 · Graaf vanaf de beek een kanaal tot naast je grond.");
    case 2:return Tr("Tuinhulp 3/4 · Plant druiven op je bewaterde grond.");
    case 3:return Tr("Tuinhulp 4/4 · Ga gerust op pad en oogst zodra je druiven rijp zijn.");
   }
   return Tr("Eerste oogst gelukt · je kunt je tuin op eigen tempo uitbreiden.");
  }
  /// <summary>Every saved apple tree; the world draws one trunk and crown for each.</summary>
  public IReadOnlyList<HomeCell> AppleTrees()=>FarmView.Require("cells").Entries.Where(row=>Text(row.Value,"crop")=="apple").Select(row=>Cell(row.Key.AsString())).ToArray();
 }
}
