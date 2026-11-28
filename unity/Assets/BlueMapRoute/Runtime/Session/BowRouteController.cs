using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Farm;
using BlueMapMigration.Foundation;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// Bow targets, Tessa's timed shooting range, and the services that a conversation can ask for: the ferry
 /// destinations and the overview of the coastal region.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  public sealed class BowTarget
  {
   public string Address,Sets,RangeId;public Vector2 Position;public FoundationValue Do;public bool Hit;public double HitAge;
   public Vector2 Center=>Position+new Vector2(0,-3);
  }
  readonly List<BowTarget> bowTargets=new List<BowTarget>();FoundationWorldSnapshot bowBuiltFor;string rangeId="";double rangeLimit=20,rangeReady,rangeLeft,rangeEnd,rangeElapsed;int rangeHits,rangeCount;
  string pendingService="";
  public IReadOnlyList<BowTarget> BowTargets=>bowTargets;
  /// <summary>idle, ready, run, won or lost.</summary>
  public string RangeState {get;private set;}="idle";public string RangeStatus {get;private set;}="";public int RangeHits=>rangeHits;public double RangeTimeLeft=>rangeLeft;
  public bool RangeLendsArrows=>RangeState=="ready"||RangeState=="run";
  bool BowHit(BowTarget target)=>target.Hit||(target.Sets!=""&&Gameplay.State.Flag(target.Sets));
  IEnumerable<BowTarget> RangeTargets=>bowTargets.Where(t=>t.RangeId==rangeId&&rangeId!="");
  void BuildBowTargets()
  {
   bowTargets.Clear();rangeId="";rangeLimit=20;RangeState="idle";RangeStatus="";rangeHits=0;
   foreach(var node in Session.Current.Root.Require("scene").Items)
   {
    if(!node.TryGet("script",out var script)||script.Kind!="string"||!node.TryGet("fields",out var fields)||!node.TryGet("globalTransform",out var transform))continue;
    string kind=System.IO.Path.GetFileNameWithoutExtension(script.AsString());var obj=StoryModel.G(fields,"obj",fields);
    if(kind=="target")
     bowTargets.Add(new BowTarget{Address=RouteSourcePresentation.Address(node),Position=FoundationCoordinates.Vector(transform.Require("origin")),Sets=StoryModel.G(obj,"sets",StoryModel.S("")).AsString(),RangeId=StoryModel.G(obj,"range",StoryModel.S("")).AsString(),Do=StoryModel.G(obj,"do",FoundationValue.Array(Array.Empty<FoundationValue>()))});
    else if(kind=="shooting_range"){rangeId=StoryModel.G(obj,"id",StoryModel.S("schietbaan")).AsString();rangeLimit=StoryModel.G(obj,"time",FoundationValue.Number(20)).AsDouble();}
   }
  }
  void ArrowHit(BowTarget target)
  {
   if(BowHit(target)){OnSound("hit");return;}
   target.Hit=true;target.HitAge=0;var actions=new List<FoundationValue>();if(target.Sets!="")actions.Add(Action("set_flag",StoryModel.S(target.Sets)));
   actions.AddRange(target.Do.Items);OnSound("boog_target");if(actions.Count>0)StoryActions(actions.ToArray());World.RefreshRouteState();
  }
  public bool StartRange()
  {
   if(rangeId==""||RangeLendsArrows)return false;foreach(var target in RangeTargets){target.Hit=false;target.HitAge=0;}
   RangeState="ready";rangeReady=3;rangeHits=0;return true;
  }
  static string RangeSeconds(double value,string comma)=>value.ToString("0.0",System.Globalization.CultureInfo.InvariantCulture).Replace(".",comma);
  void TickBow(double delta)
  {
   if(Session?.Current==null)return;
   if(!ReferenceEquals(bowBuiltFor,Session.Current)){bowBuiltFor=Session.Current;BuildBowTargets();}
   if(Combat!=null)Combat.LentArrows=()=>RangeLendsArrows;
   var state=Gameplay.State;
   if(pendingService!=""&&!Gameplay.DialogueOpen&&Modal==""&&!state.InputLocked){string service=pendingService;pendingService="";RunService(service);}
   foreach(var target in bowTargets)if(BowHit(target))target.HitAge+=delta;
   // An arrow that reaches a board is spent, exactly as when it reaches a creature.
   if(Encounter!=null&&bowTargets.Count>0)foreach(var arrow in Encounter.Projectiles)
   {
    if(!arrow.PlayerOwned||arrow.Dead)continue;
    var board=bowTargets.Where(t=>Vector2.Distance(t.Center,arrow.Position)<=13+3+5).OrderBy(t=>Vector2.Distance(t.Center,arrow.Position)).FirstOrDefault();
    if(board==null)continue;arrow.Dead=true;ArrowHit(board);
   }
   RangeStatus="";if(rangeId=="")return;rangeCount=RangeTargets.Count();
   switch(RangeState)
   {
    case "idle":foreach(var target in RangeTargets)if(target.Hit&&target.HitAge>1.6){target.Hit=false;target.HitAge=0;}break;
    case "ready":
     rangeReady-=delta;RangeStatus=Math.Max(1,(int)Math.Ceiling(rangeReady)).ToString();
     if(rangeReady<=0){foreach(var target in RangeTargets){target.Hit=false;target.HitAge=0;}RangeState="run";rangeLeft=rangeLimit;rangeElapsed=0;rangeHits=0;OnSound("select");RangeStatus=Translate("Af!");}
     break;
    case "run":
     rangeElapsed+=delta;rangeLeft-=delta;rangeHits=RangeTargets.Count(t=>t.Hit);
     RangeStatus=rangeHits+"/"+rangeCount+" · "+RangeSeconds(Math.Max(0,rangeLeft),Locale=="en"?".":",")+" s";
     if(rangeHits>=rangeCount&&rangeCount>0)
     {
      RangeState="won";rangeEnd=2.5;OnSound("quest");string seconds=RangeSeconds(rangeElapsed,Locale=="en"?".":",");
      if(state.QuestState("boog_schietbaan")=="active"&&!state.Flag("boog_range_won"))StoryActions(Action("set_flag",StoryModel.S("boog_range_won")),Action("toast",StoryModel.S(Farm.Format("Gehaald in %s seconden! Ga naar Tessa voor je beloning.",seconds))),Action("save"));
      else StoryActions(Action("toast",StoryModel.S(Farm.Format("Gehaald in %s seconden!",seconds))));
     }
     else if(rangeLeft<=0)
     {RangeState="lost";rangeEnd=2.5;OnSound("error");StoryActions(Action("toast",StoryModel.S(Farm.Format("Tijd om! Je raakte %d van de %d. Praat met Tessa voor een nieuwe poging.",rangeHits,rangeCount))));}
     break;
    default:rangeEnd-=delta;if(rangeEnd<=0){foreach(var target in RangeTargets){target.Hit=false;target.HitAge=0;}RangeState="idle";}break;
   }
  }
  // --- Services asked for in a conversation ---------------------------------------------------------------
  static readonly string[] CoastRegionIds={"coast","river_mouth","harbor","headland","gull_island","tide_cove"};
  static string CoastHint(string id)
  {
   switch(id)
   {
    case "coast":return "Strand en duinen. West: Zilvermeer. Noord: Zilvermonding. De veer verbindt de eilanden en de haven.";
    case "river_mouth":return "Brede oevers en één hoge rivierbrug. Zuid: Blauwe Kust. Oost: Rietwenk Haven. Geen gereedschap nodig.";
    case "harbor":return "Een kleine werkkade met Ise en Raf. West: riviermonding. Oost: Lichtkaap. Gratis veer naar kust en eilanden.";
    case "headland":return "Hoge graslanden, een vuurtoren en een rustig zeezicht. Het brede westelijke pad brengt je terug naar de haven.";
    case "gull_island":return "Grasrug, strand en uitzichtpunt. De oostelijke loopbrug voert naar de Getijdenbaai; de veer brengt je terug.";
   }
   return "Getijdenbaai: zandbank bij laagwater, hoge loopbrug altijd open. Gratis leenlijn en veer bij de westelijke steiger.";
  }
  string MapTitle(string id){var data=repository.Read(id).MapData;return Translate(data.TryGet("name",out var name)?name.AsString():id);}
  /// <summary>Open the ferry destinations of the nearest dock on this map.</summary>
  public bool OpenNearestVoyage()
  {
   var dock=targets.Where(t=>(t.Kind=="coast_dock"||t.Kind=="tide_station")&&Access.BoatRoutes(t.Fields).Count>0).OrderBy(t=>Vector2.Distance(World.Position,t.Position)).FirstOrDefault();
   if(dock==null||Gameplay.State.InputLocked)return false;boat=dock;boatMap=Gameplay.State.MapId;SetModal("boat");return true;
  }
  public bool OpenCoastAtlas()
  {
   if(!Running||Farm==null||Gameplay.State.InputLocked)return false;string here=Gameplay.State.MapId;var lines=new List<string>{Farm.Format("Je bent hier: %s.",MapTitle(here))};
   for(int i=0;i<CoastRegionIds.Length;i++)lines.Add((i+1)+". "+MapTitle(CoastRegionIds[i])+(CoastRegionIds[i]==here?" ●":"")+" — "+Translate(CoastHint(CoastRegionIds[i])));
   infoTarget=null;infoMap=here;gardenRole="info";gardenStation=null;SetModal("garden_menu");GardenMenu.SetControllerActive(ControllerActive);infoHandler=id=>CloseModal();
   GardenMenu.Open("info:atlas",Translate("Kustregio · kaart en verbindingen"),lines,new[]{new GardenOption("close",Translate("Sluiten"))});GardenMenu.NotifyOpened(storyInput);return true;
  }
  void RunService(string service)
  {
   switch(service)
   {
    case "voyage":if(!OpenNearestVoyage())ShowMessage(T("Er ligt hier geen veerboot klaar.","No ferry is waiting here."));break;
    case "atlas":OpenCoastAtlas();break;
    case "range":if(!StartRange())ShowMessage(T("De schietbaan is nu niet beschikbaar.","The shooting range is not available right now."));break;
   }
  }
  bool HandleServiceExternal(string name)
  {
   switch(name)
   {
    case "ce_sail":case "rg_routes":pendingService="voyage";return true;
    case "rg_atlas":pendingService="atlas";return true;
    case "boog_range_start":pendingService="range";return true;
   }
   return false;
  }
 }
}
