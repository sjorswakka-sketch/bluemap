using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Farm;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Player;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>Connects the original garden, orchard, production stations and water types to the playable world.</summary>
 public sealed partial class RouteWorldController
 {
  sealed class OrchardTree{public HomeCell Cell;public SpriteRenderer Crown;public float Alpha=1;}
  public FarmModel Farm {get;private set;}
  public GardenMenu GardenMenu {get;private set;}
  public SeedBookPanel SeedBook {get;private set;}
  /// <summary>The field text shown while the hoe is out or the garden guide is on.</summary>
  public string GardenHint {get;private set;}="";
  /// <summary>Name and explanation of the water the player stands beside.</summary>
  public string WaterInfo {get;private set;}="";
  public int GardenSoilNodes {get;private set;} public int GardenChannelNodes {get;private set;} public int GardenWetChannels {get;private set;} public int GardenCropNodes {get;private set;}
  public int GardenTreeNodes=>orchardTrees.Count;public long GardenWorldVersion {get;private set;} public bool GardenPreviewVisible=>gardenPreview!=null&&gardenPreview.enabled;
  public double PendingFarmTime=>pendingFarmTime;
  IDisposable farmClock;double pendingFarmTime,farmCooldown=.3,gardenCheck;bool farmWaitRelease,gardenDirty;string gardenSignature="",strokeMode="",gardenRole="";
  readonly HashSet<HomeCell> stroke=new HashSet<HomeCell>();HomeCell lastStrokeCell=new HomeCell(-100,-100);RouteTarget gardenStation;
  GameObject gardenRoot;SpriteRenderer gardenPreview;FoundationWorldSnapshot gardenBuiltFor;readonly List<OrchardTree> orchardTrees=new List<OrchardTree>();
  static bool FarmModal(string mode)=>mode=="garden_menu"||mode=="seed_book";
  /// <summary>The waterfall and the fixed house furniture are scenery; only the working stations can be used.</summary>
  static bool SceneryStation(string role)=>role=="fall"||role=="shelf"||role=="table";
  string StationLabel(string role)=>role=="bed"?T("Rusten en opslaan","Rest and save"):Translate(BlueMapMigration.Inventory.InventoryModel.Get(FarmModel.Farm.Require("stationNames"),role??"",FoundationValue.StringValue("Woning en tuin")).AsString());
  void InitializeFarm()
  {
   Farm=new FarmModel(repository,Gameplay.State,Inventory,Professions,Home){Translator=Translate};
   Farm.Near=StationNear;Farm.SpawnFits=GardenSpawnFits;Farm.PlayerPosition=()=>World.Position;
   Farm.SaveRequested+=OnSaveRequested;Farm.Changed+=FarmChanged;Farm.TreesChanged+=FarmChanged;
   GardenMenu=new GardenMenu(Catalog,T,BindingLabel);GardenMenu.CloseRequested+=CloseModal;GardenMenu.Chosen+=GardenChosen;
   SeedBook=new SeedBookPanel(Catalog,Farm,T,BindingLabel);SeedBook.CloseRequested+=CloseModal;SeedBook.SoundRequested+=OnSound;SeedBook.ModeChosen+=ChooseGardenMode;
   farmClock=Gameplay.State.Events.Subscribe<FoundationActiveTimeAdvanced>(tick=>pendingFarmTime+=tick.Seconds);
   pendingFarmTime=0;farmCooldown=.3;farmWaitRelease=false;gardenDirty=true;gardenBuiltFor=null;gardenSignature="";GardenHint="";WaterInfo="";ClearStroke();
  }
  void DetachFarm()
  {
   farmClock?.Dispose();farmClock=null;
   if(Farm!=null){Farm.SaveRequested-=OnSaveRequested;Farm.Changed-=FarmChanged;Farm.TreesChanged-=FarmChanged;}
   ClearGardenWorld();Farm=null;GardenMenu=null;SeedBook=null;gardenStation=null;GardenHint="";WaterInfo="";
  }
  void FarmChanged(){gardenDirty=true;}
  void CloseFarmViews(string keep){if(keep!="garden_menu")GardenMenu?.Close();if(keep!="seed_book")SeedBook?.Close();}
  /// <summary>Garden time is active play time; it is applied in small steps and always before the garden is used or saved.</summary>
  public void FlushFarmTime(){if(Farm==null||pendingFarmTime<=0)return;double seconds=pendingFarmTime;pendingFarmTime=0;Farm.Advance(seconds);}
  bool StationNear(string role,string unit)
  {
   foreach(var target in targets)
   {
    if(target.Kind!="home_station"||StationRole(target)!=role||Vector2.Distance(World.Position,target.Position)>68)continue;
    if(unit==""||StationUnit(target)==unit)return true;
   }
   return false;
  }
  /// <summary>The world's answer to "can a body stand here": solid ground and every solid object count, the player does not.</summary>
  bool GardenSpawnFits(HomeCell cell)
  {
   var foot=new Vector2(cell.X*32+16,cell.Y*32+24);
   foreach(var offset in new[]{Vector2.zero,new Vector2(8,0),new Vector2(-8,0),new Vector2(0,8),new Vector2(0,-8),new Vector2(6,6),new Vector2(-6,6),new Vector2(6,-6),new Vector2(-6,-6)})if(World.CombatSolid(foot+offset))return false;
   return World.CombatBodyFits(foot,8);
  }
  public HomeCell GardenAimCell()
  {
   Vector2 d=World.Motor.Facing,p=World.Position;int sx=Mathf.Abs(d.x)>Mathf.Abs(d.y)?Math.Sign(d.x):0,sy=Mathf.Abs(d.x)>Mathf.Abs(d.y)?0:Math.Sign(d.y);
   return new HomeCell(Mathf.FloorToInt(p.x/32)+sx,Mathf.FloorToInt(p.y/32)+sy);
  }
  void ClearStroke(){stroke.Clear();lastStrokeCell=new HomeCell(-100,-100);strokeMode="";}
  /// <summary>The hoe key opens the tool choices; with a tool out, holding the use key works the tile in front of you.</summary>
  bool HandleFarmFrame(InputFrame frame)
  {
   if(Farm==null)return false;
   if(!frame.Held("interact")){ClearStroke();farmWaitRelease=false;}
   if(frame.Pressed("homestead")){if(Gameplay.State.MapId=="player_home")OpenHouseEditor();else OpenGardenMenu("tools",null);return true;}
   if(Farm.Mode==""||Gameplay.State.MapId!="village"||CurrentTarget!=null||!frame.Held("interact")||!FarmModel.Garden(GardenAimCell()))return false;
   if(frame.Pressed("interact")){ClearStroke();farmWaitRelease=false;}
   WorkGarden();return true;
  }
  /// <summary>Work the aimed tile once; a held key walks a row, restoring soil takes one press per tile.</summary>
  public int WorkGarden()
  {
   if(Farm==null||farmCooldown>0||farmWaitRelease||Gameplay.State.InputLocked||CurrentTarget!=null||World.Motor.IsRolling||(Combat!=null&&Combat.Player.Phase!="")||World.Motor.Knockback.magnitude>5)return 0;
   string mode=Farm.Mode;var at=GardenAimCell();if(mode==""||!FarmModel.Garden(at))return 0;
   if(strokeMode!=mode){ClearStroke();strokeMode=mode;}
   if(mode=="fill"&&stroke.Count>0)return 0;
   farmCooldown=.1;var candidates=new List<HomeCell>();int dx=at.X-lastStrokeCell.X,dy=at.Y-lastStrokeCell.Y;
   // Short straight gaps from running are filled; a jump is never worked along.
   if(lastStrokeCell.X!=-100&&(dx==0||dy==0)&&Math.Abs(dx)+Math.Abs(dy)<=3)for(int i=1;i<Math.Abs(dx)+Math.Abs(dy);i++)candidates.Add(lastStrokeCell.Offset(Math.Sign(dx)*i,Math.Sign(dy)*i));
   candidates.Add(at);lastStrokeCell=at;FlushFarmTime();int done=0;bool picked=false,filled=false;string lastCrop="";
   foreach(var cell in candidates)
   {
    if(stroke.Contains(cell))continue;var entry=Farm.EntryAt(cell);string crop=entry.TryGet("crop",out var planted)?planted.AsString():"";
    if(!Farm.Act(cell,mode))continue;stroke.Add(cell);done++;lastCrop=crop;picked|=mode=="harvest";filled|=mode=="channel"&&Farm.IsWet(cell);
   }
   if(done>0){OnSound(picked&&FarmModel.Named(lastCrop)?"orchard_pick":picked?"garden_pick":filled?"garden_water":"hs_soil");gardenDirty=true;RefreshGardenWorld();World.RefreshRouteState();}
   return done;
  }
  public void ChooseGardenMode(string mode)
  {
   if(Farm==null)return;if(mode!=""&&(Gameplay.State.Count("hs_hoe")==0||!FarmModel.ToolModes.Concat(FarmModel.CropIds).Contains(mode)))return;
   Farm.Mode=mode;CloseModal();farmCooldown=.3;farmWaitRelease=storyInput?.Held("interact")==true;ClearStroke();gardenDirty=true;
  }
  // --- Menus ------------------------------------------------------------------------------------
  string GardenShortcut=>BindingLabel("homestead");
  static string ToolInfo(string mode)
  {
   switch(mode)
   {
    case "soil":return "Grond voor druiven en bloemen; paden en vrije doorgangen blijven beschermd.";
    case "channel":return "Begin naast de beek; aangesloten kanalen vullen zich vanzelf en blijven beloopbaar.";
    case "grape":return "Een blijvende druivenstok; water laat hem groeien, meststof verhoogt één oogst.";
    case "flower":return "Bloemen blijven bloeien en voeden bijen binnen vijf tegels van de kast.";
    case "fertilize":return "Eén meststof per plant verbetert de volgende oogst; de veldtekst toont de opbrengst.";
    case "harvest":return "Houd vast en loop langs rijpe gewassen. Blijvende planten blijven staan; groenten geven zaad terug.";
    case "fill":return "Herstel één tegel per druk; je krijgt het zaad terug, maar de plant verdwijnt.";
   }
   return "Berg je hak op; je tuin groeit verder terwijl je op avontuur bent.";
  }
  public bool OpenGardenMenu(string role,RouteTarget station)
  {
   if(!Running||Farm==null)return false;FlushFarmTime();UpdateInventoryContext();gardenRole=role;gardenStation=station;SetModal("garden_menu");GardenMenu.SetControllerActive(ControllerActive);
   BuildGardenMenu();GardenMenu.NotifyOpened(storyInput);return true;
  }
  void BuildGardenMenu(string focus=null)
  {
   var state=Gameplay.State;string map=state.MapId,role=gardenRole;var lines=new List<string>();var options=new List<GardenOption>();string title=Farm.StationName(role);
   string help=Translate(state.Flag("hs_garden_help")?"Tuinhulp stoppen":"Tuinhulp starten · vrijwillig");
   if(role=="tools")
   {
    title=Translate("Tuinhak · kies je werk");lines.Add(Farm.Format("Kies je werk en houd %s vast terwijl je langs een rij loopt; herstellen werkt per druk.",BindingLabel("interact")));
    foreach(string mode in FarmModel.ToolModes)
    {
     string item=mode=="grape"?"hs_seed":mode=="flower"?"hs_flower_seed":mode=="fertilize"?"hs_fertilizer":"";
     string label=item!=""?Farm.Format("%s · bij je: %d",Farm.ModeName(mode),state.Count(item)):Farm.ModeName(mode);
     options.Add(new GardenOption("mode:"+mode,(Farm.Mode==mode?"✓ ":"")+label,mode==""||state.Count("hs_hoe")>0,Translate(ToolInfo(mode))));
    }
    options.Add(new GardenOption("water",Translate(Farm.ShowWater?"Wateroverzicht: aan":"Wateroverzicht: uit")));options.Add(new GardenOption("help",help));
    if(focus==null)focus="mode:"+(Farm.Mode==""&&state.Count("hs_hoe")>0?"soil":Farm.Mode);
   }
   else if(role=="guide"||role=="supplies")
   {
    lines.Add(Translate("Dit huis en de tuin zijn van jou. Buiten: twee wijnvaten, mesthoop achter het dak en een bijenkast. Haal je gratis hak en zaden. Leid met kanaaltjes water uit de dorpsbeek naar de grond; droge gewassen wachten zonder te verdorren. Druiven groeien in 90 s, bloemen in 60 s actieve speeltijd. Menu's pauzeren de tijd."));
    lines.Add(Farm.GuideText());
    options.Add(new GardenOption("supply",Translate("Neem hak en zaden · eenmalig gratis"),!Farm.HasSupplies));options.Add(new GardenOption("tools",Translate("Tuinstanden openen")));
    options.Add(new GardenOption("harvest",Translate("Oogst alle rijpe gewassen in je tuin")));options.Add(new GardenOption("help",help));
   }
   else if(role=="wild_grape")
   {
    lines.Add(Translate("Verzamel drie bosdruiven. Eet ze voor één hartje, maak pitten via Beroepen of vul je wijnvat. De struik herstelt na 120 s actieve speeltijd."));
    options.Add(new GardenOption("grapes",Translate("Pluk drie druiven"),Farm.WildGrapesReady&&Inventory.Room("hs_grape")>=3));
   }
   else if(role=="hive")
   {
    lines.Add(Farm.Format("Bloemen in bereik: %d / 3 nodig. Bloeiende planten binnen vijf tegels geven bijen voedsel. Zonder bloemen pauzeert de productie. Iedere 120 s actieve speeltijd één honing; de kast bewaart maximaal acht.",Farm.Flowers()));
    lines.Add(Farm.Format("Honing klaar: %d · voortgang %.0f / 120 s",Farm.Honey,Farm.HoneyTime));
    options.Add(new GardenOption("collect",Translate("Honing uit de kast halen"),Farm.Honey>0&&Inventory.Room("hs_honey")>=Farm.Honey));
   }
   else
   {
    string id=GardenJobId();var recipe=FarmModel.Jobs.Require(id);string input=recipe.Require("input").AsString(),output=recipe.Require("output").AsString();
    long cost=recipe.Require("cost").AsInt64(),yield=recipe.Require("yield").AsInt64();double seconds=recipe.Require("seconds").AsDouble();
    lines.Add(Translate(role=="compost"?"Composteren · twee dierenpoep worden drie meststof in 30 s.":"Wijn maken · drie druiven worden één fles in 90 s."));
    lines.Add(Farm.Format("Beschikbaar: %d · nodig per portie: %d · maximaal twintig porties tegelijk",Inventory.Available(input),cost));
    if(Inventory.NearbyKind!="")lines.Add(Translate("Ingrediënten uit de bereikbare huisvoorraad tellen mee."));
    var job=Farm.Job(id);
    if(job!=null)
    {
     long batches=job.Require("batches").AsInt64();double time=job.Require("time").AsDouble();
     lines.Add(Farm.Format("Nog %.0f s actieve speeltijd · resultaat: %d",Math.Max(0,seconds-time),batches*yield));
     options.Add(new GardenOption("collect",Translate(role=="compost"?"Meststof uitscheppen":"Wijn bottelen"),time>=seconds&&Inventory.Room(output)>=batches*yield));
    }
    else
    {
     long count=Math.Min(20,Inventory.Available(input)/cost);
     options.Add(new GardenOption("start:1",Translate(role=="compost"?"Meng één portie compost":"Vul vat voor één fles"),count>=1));
     if(count>1)options.Add(new GardenOption("start:"+count,Farm.Format(role=="compost"?"Meng %d porties compost":"Vul vat voor %d flessen",count)));
    }
   }
   if(role=="tools"||role=="guide"||role=="supplies")
   {
    options.Add(new GardenOption("seeds",Translate("Zaden en boomgaard"),map=="village"||map=="player_home"));
    if(map=="village")options.Add(new GardenOption("yard",Translate("Erf inrichten")));
    if(map=="player_home"&&role!="tools")options.Add(new GardenOption("decorate",Translate("Je huis inrichten")));
   }
   options.Add(new GardenOption("close",Translate("Sluiten")));
   GardenMenu.Open(role,title,lines,options,focus);
  }
  string GardenJobId()=>gardenRole=="compost"?"compost":gardenStation!=null?StationUnit(gardenStation):"";
  void GardenChosen(string id)
  {
   if(Farm==null||Modal!="garden_menu")return;FlushFarmTime();UpdateInventoryContext();
   if(id.StartsWith("mode:",StringComparison.Ordinal)){ChooseGardenMode(id.Substring(5));return;}
   if(id.StartsWith("start:",StringComparison.Ordinal)){if(Farm.StartJob(GardenJobId(),Int64.Parse(id.Substring(6),System.Globalization.CultureInfo.InvariantCulture)))OnSound("select");BuildGardenMenu();return;}
   switch(id)
   {
    case "tools":gardenRole="tools";gardenStation=null;BuildGardenMenu();break;
    case "supply":if(Farm.TakeSupplies())OnSound("select");BuildGardenMenu();break;
    case "harvest":{long n=Farm.HarvestAll();if(n>0)OnSound("garden_pick");BuildGardenMenu();break;}
    case "help":Gameplay.State.SetFlag("hs_garden_help",!Gameplay.State.Flag("hs_garden_help"));OnSaveRequested();BuildGardenMenu();break;
    case "water":Farm.ShowWater=!Farm.ShowWater;gardenDirty=true;BuildGardenMenu();break;
    case "grapes":if(Farm.WildGrapes())OnSound("garden_pick");BuildGardenMenu();break;
    case "collect":if(Farm.Collect(gardenRole=="hive"?"hive":GardenJobId()))OnSound("select");BuildGardenMenu();break;
    case "seeds":OpenSeedBook();break;
    case "yard":OpenYardEditor();break;
    case "decorate":OpenHouseEditor();break;
    default:CloseModal();break;
   }
   World.RefreshRouteState();
  }
  public bool OpenSeedBook()
  {
   if(!Running||Farm==null)return false;FlushFarmTime();UpdateInventoryContext();SetModal("seed_book");SeedBook.SetControllerActive(ControllerActive);bool opened=SeedBook.Open();SeedBook.NotifyOpened(storyInput);if(!opened)CloseModal();return opened;
  }
  bool HandleFarmModal(InputFrame frame)
  {
   if(!FarmModal(Modal))return false;UpdateInventoryContext();
   if(Modal=="garden_menu"){GardenMenu.SetControllerActive(ControllerActive);GardenMenu.HandleInput(frame,inventoryFrameDelta);}
   else{SeedBook.SetControllerActive(ControllerActive);SeedBook.HandleInput(frame,inventoryFrameDelta);}
   return true;
  }
  /// <summary>Every garden station opens its own menu; the bed keeps its small rest menu.</summary>
  bool InteractGardenStation(RouteTarget target)
  {
   string role=StationRole(target);if(Farm==null||role=="bed"||SceneryStation(role))return false;
   if(Vector2.Distance(World.Position,target.Position)>68)return false;
   return OpenGardenMenu(role,target);
  }
  // --- World ------------------------------------------------------------------------------------
  void ClearGardenWorld(){if(gardenRoot!=null)UnityEngine.Object.Destroy(gardenRoot);gardenRoot=null;gardenPreview=null;orchardTrees.Clear();GardenSoilNodes=GardenChannelNodes=GardenWetChannels=GardenCropNodes=0;}
  SpriteRenderer GardenNode(string name,HomeCell cell,Sprite sprite,int order,bool catalogSprite=false)
  {
   var node=new GameObject(name);node.transform.SetParent(gardenRoot.transform,false);node.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(cell.X*32+16,cell.Y*32+16));
   var renderer=node.AddComponent<SpriteRenderer>();if(catalogSprite)Catalog.Apply(renderer,sprite);else renderer.sprite=sprite;renderer.sortingOrder=order;return renderer;
  }
  /// <summary>The growth picture of a kitchen crop or apple tree, exactly as the source chooses it.</summary>
  public static int GardenStage(FoundationValue entry)
  {
   double growth=entry.TryGet("growth",out var value)?value.AsDouble():0,ratio=Math.Min(1,Math.Max(0,growth/FarmModel.Duration(entry)));int frame=SeedBookPanel.StageAt(ratio);
   bool established=entry.TryGet("established",out var flag)&&flag.Kind=="bool"&&flag.AsBool();
   if(entry.Require("crop").AsString()=="apple"&&established)return ratio<.55?4:frame;
   return established?Math.Max(1,frame):frame;
  }
  string GardenSignature()
  {
   var text=new System.Text.StringBuilder();text.Append(Farm.ShowWater&&Farm.Mode!=""?"w":"-");
   foreach(var row in Farm.FarmView.Require("cells").Entries)
   {
    var cell=FarmModel.Cell(row.Key.AsString());text.Append(row.Key.AsString()).Append(':');
    if(row.Value.Require("kind").AsString()=="channel"){text.Append(Farm.IsWet(cell)?"C":"c");}
    else
    {
     text.Append(Farm.Watered(cell)?"S":"s");
     if(row.Value.TryGet("crop",out var crop))
     {
      string id=crop.AsString();bool fertilized=row.Value.TryGet("fertilized",out var f)&&f.Kind=="bool"&&f.AsBool();
      if(FarmModel.Named(id))text.Append(id).Append(GardenStage(row.Value));else{double seconds=FarmModel.Crop(id).Require("seconds").AsDouble();float ratio=Mathf.Clamp01((float)(row.Value.Require("growth").AsDouble()/seconds));text.Append(id).Append(Mathf.FloorToInt(ratio*18)).Append(ratio>=1?"r":"");}
      text.Append(fertilized?"f":"");
     }
    }
    text.Append(';');
   }
   return text.ToString();
  }
  /// <summary>Draws the saved garden: soil, channels with their water, crops at their growth and the apple trees.</summary>
  public void RefreshGardenWorld()
  {
   if(Farm==null||World==null||Session?.Current==null)return;gardenBuiltFor=Session.Current;gardenDirty=false;ClearGardenWorld();GardenWorldVersion++;gardenSignature="";
   if(Session.Current.MapId!="village")return;gardenSignature=GardenSignature();
   gardenRoot=new GameObject("Saved garden");gardenRoot.transform.SetParent(World.transform,false);var cells=Farm.FarmView.Require("cells");bool overview=Farm.ShowWater&&Farm.Mode!="";
   foreach(var row in cells.Entries)
   {
    string key=row.Key.AsString();var cell=FarmModel.Cell(key);var entry=row.Value;
    if(entry.Require("kind").AsString()=="channel")
    {
     bool wet=Farm.IsWet(cell);int mask=0,bit=0;
     foreach(var next in new[]{cell.Offset(-1,0),cell.Offset(1,0),cell.Offset(0,-1),cell.Offset(0,1)}){if((cells.TryGet(next.Key,out var other)&&other.Require("kind").AsString()=="channel")||FarmModel.IsSource(next))mask|=1<<bit;bit++;}
     GardenNode("Channel "+key,cell,GardenArt.Channel(wet,mask),-18990);GardenChannelNodes++;if(wet)GardenWetChannels++;
     if(overview)GardenNode("Water overview "+key,cell,GardenArt.WaterOutline(wet,true),-18970);
     continue;
    }
    bool watered=Farm.Watered(cell);GardenNode("Soil "+key,cell,GardenArt.Soil(watered),-18990);GardenSoilNodes++;
    if(overview)GardenNode("Water overview "+key,cell,GardenArt.WaterOutline(watered,false),-18970);
    if(!entry.TryGet("crop",out var planted))continue;string crop=planted.AsString();bool fertilized=entry.TryGet("fertilized",out var mark)&&mark.Kind=="bool"&&mark.AsBool();
    if(crop=="apple")
    {
     int frame=GardenStage(entry);var center=new Vector2(cell.X*32+16,cell.Y*32+16);var trunk=GardenNode("Apple tree "+key,cell,Catalog.GetSprite("orchard:trunks:"+frame),Mathf.RoundToInt(center.y),true);
     var crown=GardenNode("Apple crown "+key,cell,Catalog.GetSprite("orchard:canopies:"+frame),Mathf.RoundToInt(center.y)+1,true);
     trunk.gameObject.layer=FoundationCollision.Layer(1);var collider=trunk.gameObject.AddComponent<BoxCollider2D>();collider.size=new Vector2(10/32f,8/32f);collider.offset=new Vector2(0,-9/32f);
     if(fertilized){var dot=GardenNode("Apple fertilizer "+key,cell,GardenArt.Fertilized,Mathf.RoundToInt(center.y)+2);dot.transform.localPosition+=new Vector3(-2/32f,-1/32f,0);}
     orchardTrees.Add(new OrchardTree{Cell=cell,Crown=crown});continue;
    }
    if(FarmModel.Named(crop)){GardenNode("Crop "+key,cell,Catalog.GetSprite("crop:"+crop+":"+GardenStage(entry)),-18980,true);if(fertilized)GardenNode("Fertilizer "+key,cell,GardenArt.Fertilized,-18975);}
    else{double seconds=FarmModel.Crop(crop).Require("seconds").AsDouble();GardenNode("Crop "+key,cell,GardenArt.Crop(crop,entry.Require("growth").AsDouble(),seconds,fertilized),-18980);}
    GardenCropNodes++;
   }
   foreach(var flower in Home.Yard.Require("wildFlowers").Items){var cell=new HomeCell((int)flower.Items[0].AsInt64(),(int)flower.Items[1].AsInt64());if(!cells.TryGet(cell.Key,out _))GardenNode("Wild flowers "+cell.Key,cell,GardenArt.WildFlowers,-18985);}
   gardenPreview=GardenNode("Garden aim",new HomeCell(0,0),GardenArt.Preview(true,false,false),-18960);gardenPreview.enabled=false;
   Physics2D.SyncTransforms();
  }
  public bool GardenChannelConnected(HomeCell at)=>new[]{at.Offset(-1,0),at.Offset(1,0),at.Offset(0,-1),at.Offset(0,1)}.Any(next=>FarmModel.IsSource(next)||Farm.IsWet(next));
  void UpdateGardenHint()
  {
   GardenHint="";WaterInfo="";if(Farm==null||Modal!=""||Gameplay.DialogueOpen||Gameplay.State.InputLocked)return;string map=Gameplay.State.MapId;
   var near=WaterModel.Nearest(map,World.Position);
   if(near.Found&&CurrentTarget==null){var spec=WaterModel.Properties(near.Kind,map);WaterInfo=Translate(spec.Require("name").AsString())+" · "+Translate(spec.Require("detail").AsString());}
   if(map!="village")return;var at=GardenAimCell();var here=new HomeCell(Mathf.FloorToInt(World.Position.x/32),Mathf.FloorToInt(World.Position.y/32));
   bool active=Farm.Mode!=""||Gameplay.State.Flag("hs_garden_help");
   if(!active||!(FarmModel.Garden(here)||FarmModel.Garden(at))||CurrentTarget!=null||Message!="")return;
   string text=Farm.Mode==""?Farm.Format("Tuinhulp · %s opent de tuinstanden",GardenShortcut):Farm.Format("%s · %s gebruiken · %s standen",Farm.ModeName(Farm.Mode),BindingLabel("interact"),GardenShortcut);
   if(Farm.Mode!="")
   {
    string reason=Farm.WorkReason(at,Farm.Mode);text+="\n"+Farm.CellText(at);
    if(reason!="")text+="\n"+reason;
    else if(Farm.Mode=="fill")text+="\n"+Translate("Eén tegel per druk · een plant wordt vervangen door zijn zaad.");
    else if(Farm.Mode=="channel")text+="\n"+Translate(GardenChannelConnected(at)?"Dit kanaal krijgt meteen water · houd vast en loop verder.":"Dit kanaal blijft droog tot het met water is verbonden.");
    else text+="\n"+Translate("Houd vast en loop langs een rij.");
   }
   if(Gameplay.State.Flag("hs_garden_help"))text+="\n"+Farm.GuideText();
   GardenHint=text;
  }
  void TickFarm(double delta)
  {
   if(Farm==null||Session?.Current==null)return;farmCooldown=Math.Max(0,farmCooldown-delta);
   if(pendingFarmTime>=.2)FlushFarmTime();
   if(Modal=="garden_menu"&&gardenStation!=null&&Vector2.Distance(World.Position,gardenStation.Position)>68)CloseModal();
   if(Modal=="seed_book"&&SeedBook!=null&&!SeedBook.IsOpen)CloseModal();
   bool village=Session.Current.MapId=="village";
   if(!ReferenceEquals(gardenBuiltFor,Session.Current))RefreshGardenWorld();
   else if(village){gardenCheck-=delta;if(gardenDirty||gardenCheck<=0){gardenCheck=.2;gardenDirty=false;if(GardenSignature()!=gardenSignature)RefreshGardenWorld();}}
   foreach(var tree in orchardTrees)
   {
    var offset=World.Position-new Vector2(tree.Cell.X*32+16,tree.Cell.Y*32+16);bool under=new Rect(-34,-50,68,54).Contains(offset);
    tree.Alpha=Mathf.MoveTowards(tree.Alpha,under?.42f:1f,(float)delta*3);if(tree.Crown!=null)tree.Crown.color=new Color(1,1,1,tree.Alpha);
   }
   UpdateGardenHint();
   if(gardenPreview!=null)
   {
    var at=GardenAimCell();bool show=village&&Farm.Mode!=""&&Modal==""&&!Gameplay.State.InputLocked&&CurrentTarget==null&&FarmModel.Garden(at);gardenPreview.enabled=show;
    if(show){bool ok=Farm.WorkReason(at,Farm.Mode)=="";gardenPreview.sprite=GardenArt.Preview(ok,Farm.Mode=="channel",GardenChannelConnected(at));gardenPreview.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(at.X*32+16,at.Y*32+16));}
   }
  }
 }
}
