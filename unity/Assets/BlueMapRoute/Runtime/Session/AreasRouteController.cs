using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Combat;
using BlueMapMigration.Farm;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// The special objects of the regions: prism mirrors and core, forest runes, braziers, marsh sluices and the old
 /// winch, the desert spring and waterskin, the windy pass, the reed archive, the resonance trial and the hot spring.
 /// Each object keeps the original rules and saved flags; nothing here invents a parallel save format.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  sealed class AreaWork{public bool Active,Spawned;public double Elapsed,Warning;public readonly List<EncounterActor> Foes=new List<EncounterActor>();}
  /// <summary>One interaction changes several saved values; later reads in the same interaction must see them.</summary>
  sealed class AreaBatch
  {
   readonly RouteWorldController owner;readonly List<FoundationValue> actions=new List<FoundationValue>();
   readonly Dictionary<string,bool> flags=new Dictionary<string,bool>(StringComparer.Ordinal);readonly Dictionary<string,long> items=new Dictionary<string,long>(StringComparer.Ordinal);long coins;
   public AreaBatch(RouteWorldController route){owner=route;coins=route.Gameplay.State.Coins;}
   public bool Flag(string id)=>flags.TryGetValue(id,out bool value)?value:owner.Gameplay.State.Flag(id);
   public long Count(string id)=>items.TryGetValue(id,out long value)?value:owner.Gameplay.State.Count(id);
   public long Coins=>coins;
   public void Set(string id,bool value=true){flags[id]=value;actions.Add(Action(value?"set_flag":"clear_flag",StoryModel.S(id)));}
   /// <summary>Set a milestone once and save; false when it was already reached.</summary>
   public bool Mark(string id){if(Flag(id))return false;Set(id);Save();return true;}
   public void Start(string quest)=>actions.Add(Action("start_quest",StoryModel.S(quest)));
   public void Finish(string quest)=>actions.Add(Action("finish_quest",StoryModel.S(quest)));
   public void Step(string quest,long step)=>actions.Add(Action("quest_step",StoryModel.S(quest),StoryModel.I(step)));
   public void Give(string item,long amount=1){items[item]=Count(item)+amount;actions.Add(Action("give",StoryModel.S(item),StoryModel.I(amount)));}
   public bool Pay(string item,long amount){if(Count(item)<amount)return false;items[item]=Count(item)-amount;actions.Add(Action("take",StoryModel.S(item),StoryModel.I(amount)));return true;}
   public void AddCoins(long amount){coins+=amount;actions.Add(Action("coins",StoryModel.I(amount)));}
   public void Toast(string text)=>actions.Add(Action("toast",StoryModel.S(text)));
   public void Sound(string id)=>actions.Add(Action("sound",StoryModel.S(id)));
   public void Save()=>actions.Add(Action("save"));
   public void Run(){if(actions.Count>0)owner.StoryActions(actions.ToArray());actions.Clear();owner.World.RefreshRouteState();}
  }
  readonly Dictionary<string,AreaWork> areaWork=new Dictionary<string,AreaWork>(StringComparer.Ordinal);
  RouteTarget pendingArea;string pendingAreaMap="";FoundationWorldSnapshot areasBuiltFor;
  // The desert and the windy pass keep their own small loop per visit, exactly like the source director.
  public int RegionWater {get;private set;}=3;public double RegionHeat {get;private set;} public double RegionExposure {get;private set;} public double RegionTime {get;private set;}
  Vector2 regionShelter=new Vector2(4.5f,19.5f)*32;
  public string RegionStatus {get;private set;}="";public float RegionGauge {get;private set;}
  public bool EchoTrialActive {get;private set;} public int EchoWave {get;private set;} public double EchoCountdown {get;private set;}
  readonly List<EncounterActor> echoFoes=new List<EncounterActor>();
  public double HotSpringRest {get;private set;}
  static readonly Vector2[] RegionShelters={new Vector2(4.5f,18.5f)*32,new Vector2(15.5f,5.5f)*32,new Vector2(28.5f,18.5f)*32};
  static readonly Rect RegionWind=new Rect(10*32,5*32,8*32,2*32);
  static readonly string[][] EchoWaves={new[]{"crystal_beetle","crystal_beetle"},new[]{"prism_moth","prism_moth"},new[]{"crystal_beetle","prism_moth","crystal_beetle"}};
  static readonly Vector2[] EchoSpawns={new Vector2(8.5f,7.5f)*32,new Vector2(23.5f,7.5f)*32,new Vector2(16.5f,6.5f)*32};
  static bool AreaKind(string kind)=>kind=="living_object"||kind=="regional_object"||kind=="echo_trial";
  /// <summary>The archive shelves are furniture; every other regional object can be used.</summary>
  static bool AreaScenery(string script,FoundationValue fields)=>script=="regional_object"&&StoryModel.G(StoryModel.G(fields,"obj",fields),"kind",StoryModel.S("")).AsString()=="shelf";
  FoundationValue AreaObj(RouteTarget t)=>StoryModel.G(t.Fields,"obj",t.Fields);
  string AreaText(RouteTarget t,string field)=>StoryModel.G(AreaObj(t),field,StoryModel.S("")).AsString();
  AreaWork Work(RouteTarget t){if(!areaWork.TryGetValue(t.Address,out var work)){work=new AreaWork();areaWork[t.Address]=work;}return work;}
  public bool AreaActive(RouteTarget t)=>t!=null&&areaWork.TryGetValue(t.Address,out var work)&&work.Active;
  public int AreaFoes(RouteTarget t)=>t!=null&&areaWork.TryGetValue(t.Address,out var work)?work.Foes.Count(f=>!f.Dead):0;
  string AreaLabel(RouteTarget t)
  {
   string kind=ObjectKind(t),id=ObjectId(t);
   if(t.Kind=="echo_trial")return Translate("Resonantieproef");
   if(t.Kind=="regional_object")return Translate(AreaText(t,"name"));
   switch(kind)
   {
    case "mirror":return Translate("Prismaspiegel");case "core":return Translate("Prismakern");case "forge":return Translate("Prismabank");case "rune":return Translate("Verborgen bosrune");case "brazier":return Translate("Vuurkorf");
    case "sluice":return Translate(id=="lw_sluice_west"?"Westelijke sluis":"Oostelijke sluis")+" · "+Translate(Gameplay.State.Flag(id)?"open":"dicht");
    case "bridge":return Translate("De oude lier");
   }
   return Translate("Herstelbord");
  }
  void SayArea(RouteTarget target,params string[] texts){Story.RequestLines(AreaLabel(target),texts.Select(Translate).ToArray());SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);}
  void SayAs(string speaker,params string[] texts){Story.RequestLines(speaker,texts.Select(Translate).ToArray());SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);}
  void OpenAreaTalk(RouteTarget target,string talk)
  {pendingArea=target;pendingAreaMap=Gameplay.State.MapId;StoryActions(Action("talk",StoryModel.S(talk)));SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);}
  // --- The living world: mirrors, core, forge, runes, braziers, sluices and the winch -------------------
  public int MirrorDirection(string id){for(int i=1;i<4;i++)if(Gameplay.State.Flag(id+"_turn_"+i))return i;return 0;}
  static int MirrorDirection(AreaBatch b,string id){for(int i=1;i<4;i++)if(b.Flag(id+"_turn_"+i))return i;return 0;}
  static bool BeamsReady(AreaBatch b)=>MirrorDirection(b,"lw_mirror_a")==0&&MirrorDirection(b,"lw_mirror_b")==1&&MirrorDirection(b,"lw_mirror_c")==2;
  public bool BeamsReady()=>MirrorDirection("lw_mirror_a")==0&&MirrorDirection("lw_mirror_b")==1&&MirrorDirection("lw_mirror_c")==2;
  bool InteractAreaObject(RouteTarget target)
  {
   if(Gameplay.State.InputLocked)return false;
   if(target.Kind=="echo_trial")return InteractEchoTrial(target);
   if(target.Kind=="regional_object")return InteractRegional(target);
   var work=Work(target);if(work.Active)return false;string kind=ObjectKind(target),id=ObjectId(target);var b=new AreaBatch(this);
   switch(kind)
   {
    case "board":
     b.Start("prisma_herstel");b.Run();
     SayArea(target,"De drie spiegels horen één lichtpad te vormen: oost, zuid, west. Draai ze naar hun ontvangers en activeer daarna de kern.","Greta zoekt deze kern voor haar oude werkplaats. Aardingspoeder uit de bibliotheek biedt een rustige oplossing; de bewakers verslaan kan ook.");return true;
    case "mirror":
     b.Start("prisma_herstel");if(b.Flag("lw_mine")){b.Run();return true;}
     {int next=(MirrorDirection(b,id)+1)%4;for(int i=1;i<4;i++)b.Set(id+"_turn_"+i,next==i);}
     b.Sound("door");b.Set("lw_beams",BeamsReady(b));b.Save();b.Run();return true;
    case "core":
     b.Start("prisma_herstel");
     if(b.Flag("lw_mine")){b.Toast("De kern is stabiel. Greta wacht bij haar prismabank.");b.Run();}
     else if(!BeamsReady(b)){b.Toast("Volg het lichtpad: richt eerst alle drie de spiegels op de ontvangers.");b.Run();}
     else{b.Set("lw_beams");b.Run();OpenAreaTalk(target,AreaText(target,"talk"));}
     return true;
    case "forge":
     if(!b.Flag("lw_mine")){b.Start("prisma_herstel");b.Run();SayAs("Greta","Mijn prismabank mist zijn kern. Zoek in de Prismamijn, via de Echo-grot. Een ijzeren zwaard opent die zijroute.");return true;}
     if(b.Mark("lw_workshop")){b.Start("prisma_herstel");b.Finish("prisma_herstel");b.Start("lichtwerk");b.Save();}
     b.Run();OpenAreaTalk(target,AreaText(target,"talk"));return true;
    case "rune":InteractRune(target,b);return true;
    case "brazier":
     b.Start("warmte");
     if(b.Flag(id)){b.Toast("Dit huis blijft warm. De bewoners zijn terug.");b.Run();}
     else if(b.Flag(id+"_fuel")){b.Run();BeginArea(target);}
     else{b.Run();OpenAreaTalk(target,AreaText(target,"talk"));}
     return true;
    case "sluice":
     b.Start("wilgentwijgen");
     if(b.Flag("lw_drained")){b.Toast("De waterstand is veilig. De sluizen blijven zo staan.");b.Run();return true;}
     b.Set(id+"_seen");b.Set(id,!b.Flag(id));
     if(b.Flag("lw_sluice_west_seen")&&b.Flag("lw_sluice_east_seen")&&b.Flag("lw_sluice_west")&&!b.Flag("lw_sluice_east")){b.Mark("lw_drained");b.Toast("Het water zakt. De oostelijke oever en het Rietarchief vallen droog.");}
     else b.Toast(b.Flag(id)?"Sluis: open":"Sluis: dicht");
     b.Sound("door");b.Save();b.Run();return true;
    case "bridge":
     b.Start("wilgentwijgen");
     if(b.Flag("lw_bridge")){b.Toast("De oversteek is hersteld. Vertel het aan Mees in het oostelijke rietland.");b.Run();}
     else{b.Run();OpenAreaTalk(target,AreaText(target,"talk"));}
     return true;
   }
   return false;
  }
  void InteractRune(RouteTarget target,AreaBatch b)
  {
   string id=ObjectId(target);
   if(b.Flag("lw_forest")){b.Toast("Het licht stroomt weer door de wortels.");b.Run();return;}
   if(b.Count("lw_lantern")==0){SayArea(target,"Onder de mist zitten tekens. Een prismalantaarn uit Greta’s herstelde werkplaats kan ze onthullen.");return;}
   b.Start("mistsporen");
   if(!b.Flag("lw_clues"))
   {
    b.Set(id+"_read");string clue="Eerst drinkt het WATER het licht. Zoek de andere tekens bij de wortels en de oostelijke steen.";
    if(id=="lw_root")clue="Dan draagt de WORTEL het licht. Zoek de andere tekens bij de vijver en de oostelijke steen.";
    if(id=="lw_star")clue="Ten slotte wijst de STER naar de tuin. De volgorde is water, wortel, ster.";
    if(b.Flag("lw_water_read")&&b.Flag("lw_root_read")&&b.Flag("lw_star_read"))b.Mark("lw_clues");
    b.Run();SayArea(target,clue);return;
   }
   string expected=b.Flag("lw_sequence_2")?"lw_star":b.Flag("lw_sequence_1")?"lw_root":"lw_water";
   if(id!=expected){b.Set("lw_sequence_1",false);b.Set("lw_sequence_2",false);b.Toast("De lichtkring dooft. Probeer opnieuw: water, wortel, ster.");}
   else if(id=="lw_water")b.Mark("lw_sequence_1");
   else if(id=="lw_root")b.Mark("lw_sequence_2");
   else if(b.Mark("lw_forest")){b.Give("gear_scout_coat");b.Finish("mistsporen");b.Toast("De mist wijkt! De Dauwtuin in het zuidoosten is open. Je ontving een verkennersjas.");b.Sound("quest");}
   b.Save();b.Run();
  }
  /// <summary>A choice made in the conversation of a living object; ignored when the player walked away.</summary>
  bool ChooseAreaAction(string action)
  {
   var target=pendingArea;if(target==null||pendingAreaMap!=Gameplay.State.MapId||!targets.Contains(target)||Vector2.Distance(World.Position,target.Position)>72)return false;
   var work=Work(target);if(work.Active)return false;string kind=ObjectKind(target),id=ObjectId(target);var b=new AreaBatch(this);
   switch(action)
   {
    case "core_fight":case "core_powder":
     if(kind!="core"||b.Flag("lw_mine")||!BeamsReady(b))return false;
     if(action=="core_powder"){if(!b.Pay("lw_powder",1))return false;FinishArea(target,b);}else BeginArea(target);
     return true;
    case "buy_lantern":
     if(kind!="forge"||!b.Flag("lw_workshop")||b.Coins<40||b.Count("lw_lens")<1||b.Count("lw_lantern")>0)return false;
     b.Pay("lw_lens",1);b.AddCoins(-40);b.Give("lw_lantern");b.Start("lichtwerk");b.Finish("lichtwerk");b.Start("mistsporen");b.Mark("lw_lantern_made");b.Run();return true;
    case "bridge_kit":case "bridge_resin":case "bridge_fight":
     if(kind!="bridge"||b.Flag("lw_bridge"))return false;
     if(!b.Flag("lw_drained")){b.Toast("Eerst de waterdruk verlagen: west open, oost dicht. Je materialen blijven in je tas.");b.Run();return true;}
     if(action=="bridge_fight")BeginArea(target);else if(b.Pay(action=="bridge_kit"?"lw_bridge_kit":"lw_resin",1))FinishArea(target,b);else return false;
     return true;
    case "heat_wood":case "heat_food":case "heat_prism":
     if(kind!="brazier"||b.Flag(id))return false;
     if(!b.Flag(id+"_fuel"))
     {
      if(action=="heat_prism"&&!b.Flag("lw_workshop"))return false;
      if(action=="heat_wood"&&!b.Pay("prof_branch",3))return false;
      if(action=="heat_food"&&!b.Pay("prof_winter_gloed",1))return false;
      b.Mark(id+"_fuel");b.Run();
     }
     BeginArea(target);return true;
   }
   return false;
  }
  Vector2[] AreaSpawns(RouteTarget target)
  {
   switch(ObjectKind(target))
   {
    case "core":return new[]{new Vector2(27.5f,7.5f)*32,new Vector2(35.5f,8.5f)*32};
    case "bridge":return new[]{new Vector2(14.5f,22.5f)*32,new Vector2(18.5f,23.5f)*32};
   }
   return new[]{target.Position+new Vector2(-3,3)*32,target.Position+new Vector2(3,3)*32};
  }
  void BeginArea(RouteTarget target)
  {
   var work=Work(target);if(work.Active)return;work.Active=true;work.Elapsed=0;work.Warning=2;work.Spawned=false;work.Foes.Clear();
   StoryActions(Action("toast",StoryModel.S("Een beweging in de verte… let op de gemarkeerde plekken.")));
  }
  void FinishArea(RouteTarget target,AreaBatch b=null)
  {
   var work=Work(target);work.Active=false;b=b??new AreaBatch(this);string kind=ObjectKind(target),id=ObjectId(target);
   switch(kind)
   {
    case "core":if(!b.Mark("lw_mine")){b.Run();return;}b.Give("lw_lens");b.Toast("De mijn is stabiel. Neem de lens naar de prismabank in Greta’s smederij.");break;
    case "bridge":if(!b.Mark("lw_bridge")){b.Run();return;}b.Toast("De brug ligt weer! Handelaren gebruiken de korte route. Mees wacht op het goede nieuws.");break;
    case "brazier":
     if(!b.Mark(id)){b.Run();return;}
     if(b.Flag("lw_heat_west")&&b.Flag("lw_heat_east"))b.Mark("lw_heat");
     b.Toast("Het huis is warm. De bewoners keren terug.");break;
   }
   b.Sound("quest");b.Save();b.Run();
  }
  void TickAreaWork(double delta)
  {
   foreach(var target in targets.Where(t=>t.Kind=="living_object"))
   {
    if(ObjectKind(target)=="sluice")target.Label=AreaLabel(target);
    if(!areaWork.TryGetValue(target.Address,out var work)||!work.Active||Gameplay.State.InputLocked||Gameplay.State.Hp<=0)continue;string kind=ObjectKind(target);
    if(!work.Spawned)
    {
     work.Warning=Math.Max(work.Warning-delta,0);if(work.Warning>0)continue;var spawns=AreaSpawns(target);
     if(spawns.Any(at=>Vector2.Distance(at,World.Position)<64))continue;
     string[] types=kind=="core"?new[]{"lw_warden","lw_singer"}:kind=="brazier"?new[]{"lw_warden","lw_stalker"}:new[]{"lw_stalker","lw_singer"};
     for(int i=0;i<types.Length;i++){var foe=Encounter?.Spawn(types[i],spawns[i]);if(foe!=null)work.Foes.Add(foe);}
     work.Spawned=true;
    }
    work.Foes.RemoveAll(foe=>foe.Dead||!Encounter.Actors.Contains(foe));
    if(kind=="brazier")
    {
     bool clear=Vector2.Distance(World.Position,target.Position)<180&&!work.Foes.Any(foe=>Vector2.Distance(foe.Position,target.Position)<52);
     if(clear)work.Elapsed=Math.Min(20,work.Elapsed+delta);if(work.Elapsed<20)continue;
    }
    if(work.Foes.Count==0)FinishArea(target);
   }
  }
  // --- Regional adventures: desert spring, windy pass and reed archive ------------------------------
  bool RegionSheltered(Vector2 at)=>RegionShelters.Any(s=>Vector2.Distance(at,s)<62)||(Vector2.Distance(at,new Vector2(34.5f,5.5f)*32)<70&&Gameplay.State.Flag("ra_spring"));
  public int WindPhase{get{double phase=RegionTime%10.0;return phase>=8?2:phase>=6?1:0;}}
  void RefillWater(Vector2 safe){RegionWater=3;RegionHeat=0;regionShelter=safe;StoryActions(Action("toast",StoryModel.S("Waterzak gevuld: 3 slokken. Schaduw houdt je koel; de blauwe luifels hebben water.")));}
  bool InteractRegional(RouteTarget target)
  {
   string kind=ObjectKind(target);var b=new AreaBatch(this);
   switch(kind)
   {
    case "water":
     b.Start("cactusvijgen");if(b.Count("ra_waterskin")==0)b.Give("ra_waterskin");b.Mark("ra_prepared");b.Run();
     SayArea(target,"Een volle waterzak, gratis van Nour. In de Zonnekloof drink je automatisch. Onder blauwe luifels kun je bijvullen. De ingang ligt in de noordelijke zandsteenwand, rechts van de oase.");return true;
    case "refill":RefillWater(target.Position+new Vector2(0,36));OnSound("ra_water");return true;
    case "spring":OpenAreaTalk(target,"ra_spring");return true;
    case "camp":
     b.Start("ra_ridge");
     if(b.Flag("ra_chart")&&b.Flag("ra_rope")&&!b.Flag("ra_ridge_done"))
     {
      b.Set("ra_ridge_done");b.Finish("ra_ridge");b.Give("gear_ra_grip");b.Save();b.Sound("quest");b.Run();
      SayArea(target,"De weerkaart hangt weer in het kamp. De bewoners weten nu wanneer de pas rustig is. Neem deze klimhandschoenen mee; de gespannen lijn blijft bruikbaar.");
     }
     else
     {
      b.Mark("ra_rope_kit");b.Run();
      SayArea(target,"Neem het klimtouw mee. De verloren weerkaart ligt bij de zuidoostelijke schuilhut. Steek bovenlangs over: slappe wimpels betekenen rust, gele wimpels waarschuwen, witte sneeuwstrepen betekenen wind.","Een windstoot brengt je terug naar de veilige kant. Zet het touw vast aan de oostelijke paal om voortaan beschermd over te steken. Je verliest geen hartjes of spullen.");
     }
     return true;
    case "anchor":
     if(!b.Flag("ra_rope_kit")){SayArea(target,"Haal eerst het klimtouw bij het kamp naast de ingang.");return true;}
     b.Mark("ra_rope");b.Sound("ra_rope");b.Toast("De lijn zit vast. Windvlagen houden je hier niet meer tegen.");b.Run();return true;
    case "chart":
     b.Start("ra_ridge");b.Mark("ra_chart");b.Run();
     SayArea(target,"Tussen de sneeuw ligt de weerkaart. Breng hem naar het kamp bij de ingang; de markeringen helpen reizigers de wind te lezen.");return true;
    case "folio":
     b.Start("ra_archive");b.Mark(ObjectId(target));b.Run();SayArea(target,AreaText(target,"clue"));return true;
    case "desk":
     b.Start("ra_archive");b.Run();
     if(!b.Flag("ra_folio_reed")||!b.Flag("ra_folio_port")||!b.Flag("ra_folio_flood"))
      SayArea(target,"Drie reliëfs vertellen hoe het moeras veranderde. Onderzoek de rietvelden in het zuidwesten, de aanlegplaats in het noordwesten en de hoogwatersteen in het noordoosten. Lees daarna hier hun volgorde.");
     else OpenAreaTalk(target,b.Flag("ra_archive_done")?"ra_exhibit":"ra_order");
     return true;
    case "exhibit":
     if(b.Flag("ra_archive_done"))OpenAreaTalk(target,"ra_exhibit");
     else SayArea(target,"Mees heeft ruimte vrijgemaakt voor een tentoonstelling. In het Rietarchief onder het eiland wachten de oude reliëfs.");
     return true;
   }
   return false;
  }
  bool ChooseRegional(string choice)
  {
   var target=pendingArea;if(target==null||target.Kind!="regional_object"||pendingAreaMap!=Gameplay.State.MapId||!targets.Contains(target)||Vector2.Distance(World.Position,target.Position)>64)return false;
   string kind=ObjectKind(target);var b=new AreaBatch(this);
   if(kind=="spring"&&(choice=="wild"||choice=="caravan"))
   {
    if(!b.Flag("ra_prepared")&&!b.Flag("ra_spring"))return false;
    b.Set("ra_spring");b.Set("ra_water_wild",choice=="wild");b.Set("ra_water_caravan",choice=="caravan");b.Start("cactusvijgen");b.Save();b.Sound("ra_water");
    b.Toast("De bron stroomt weer. Vertel Sana bij de oase waar het water naartoe gaat.");b.Run();return true;
   }
   if(kind=="desk"&&(choice=="correct"||choice=="wrong")&&!b.Flag("ra_archive_done"))
   {
    if(!b.Flag("ra_folio_reed")||!b.Flag("ra_folio_port")||!b.Flag("ra_folio_flood"))return false;
    if(choice=="wrong"){b.Toast("Kijk naar wat er bijkomt: eerst riet zonder huizen, dan de aanlegplaats, pas daarna het hoge water boven diezelfde palen.");b.Run();return true;}
    b.Set("ra_archive_done");b.Set("ra_exhibit_routes");b.Finish("ra_archive");b.Give("gear_ra_compass");b.Save();b.Sound("ra_pages");b.Run();return true;
   }
   if((kind=="desk"||kind=="exhibit")&&b.Flag("ra_archive_done")&&(choice=="routes"||choice=="stories"))
   {
    b.Set("ra_exhibit_routes",choice=="routes");b.Save();b.Toast("De tentoonstelling bij Mees is bijgewerkt. Je kunt je keuze hier later veranderen.");b.Run();return true;
   }
   return false;
  }
  void TickRegion(double delta)
  {
   RegionStatus="";RegionGauge=0;string map=Gameplay.State.MapId;if(map!="sunwell"&&map!="ridgepass")return;var state=Gameplay.State;
   if(!state.InputLocked&&!state.Ended)
   {
    RegionTime+=delta;var at=World.Position;
    if(map=="sunwell"&&!state.Flag("ra_spring"))
    {
     if(RegionSheltered(at))RegionHeat=Math.Max(RegionHeat-delta*3,0);
     else
     {
      RegionHeat+=delta;
      if(RegionHeat>=6)
      {
       RegionHeat=0;
       if(RegionWater>0){RegionWater--;OnSound("ra_water");}
       else
       {
        World.Teleport(regionShelter);World.Motor.StopForTransition();RefillWater(regionShelter);
        StoryActions(Action("toast",StoryModel.S("De hitte wordt te veel. Je rust bij de laatste luifel; je spullen en hartjes blijven behouden.")));
       }
      }
     }
    }
    else if(map=="ridgepass")
    {
     if(RegionWind.Contains(at)&&WindPhase==2&&!state.Flag("ra_rope"))
     {
      RegionExposure+=delta;
      if(RegionExposure>=0.65)
      {
       World.Teleport(new Vector2(at.x<14*32?9.5f:18.5f,6.5f)*32);World.Motor.StopForTransition();RegionExposure=0;
       StoryActions(Action("toast",StoryModel.S("Een windstoot! Wacht naast de wimpel tot hij weer slap hangt, of gebruik het vastgezette touw.")));
      }
     }
     else RegionExposure=0;
    }
   }
   if(state.InputLocked||state.Ended)return;
   if(map=="sunwell")
   {
    RegionStatus=state.Flag("ra_spring")?Translate("De bron stroomt — de kloof is koel"):Farm.Format("Water: %d/3 • %s",RegionWater,Translate(RegionSheltered(World.Position)?"In de schaduw":"Zoek de volgende blauwe luifel"));
    RegionGauge=state.Flag("ra_spring")?0:(float)(RegionHeat/6);
   }
   else
   {
    RegionStatus=state.Flag("ra_rope")?Translate("Touw vast — veilige oversteek"):Translate(new[]{"Windstil — steek nu over","Wimpels spannen — zoek dekking","Windstoot — wacht naast de pas"}[WindPhase]);
    RegionGauge=(float)((RegionTime%10)/10);
   }
  }
  // --- The resonance trial ----------------------------------------------------------------------------
  bool InteractEchoTrial(RouteTarget target)
  {
   if(EchoTrialActive)return false;
   if(Gameplay.State.Flag("echo_trial_won")){SayArea(target,"De kristallen zingen jouw naam. Je hebt deze proef al voltooid.");return true;}
   EchoTrialActive=true;EchoWave=0;EchoCountdown=3;echoFoes.Clear();
   StoryActions(Action("toast",StoryModel.S("Drie golven. Volg de lichtstralen. De uitgang blijft open als je wilt terugtrekken.")),Action("sound",StoryModel.S("quest")));return true;
  }
  void TickEchoTrial(double delta)
  {
   if(!EchoTrialActive||Gameplay.State.InputLocked||Gameplay.State.Hp<=0||Encounter==null)return;
   echoFoes.RemoveAll(foe=>foe.Dead||!Encounter.Actors.Contains(foe));if(echoFoes.Count>0)return;
   if(EchoCountdown<=0)
   {
    if(EchoWave>=EchoWaves.Length)
    {
     EchoTrialActive=false;if(Gameplay.State.Flag("echo_trial_won"))return;var b=new AreaBatch(this);
     b.Set("echo_trial_won");b.Give("gear_crystal_amulet");b.AddCoins(120);b.Toast("Proef voltooid! Kristallen amulet + 120 munten. Trek het aan via Uitrusting.");b.Sound("quest");b.Save();b.Run();return;
    }
    EchoCountdown=3;
   }
   EchoCountdown=Math.Max(EchoCountdown-delta,0);if(EchoCountdown>0)return;
   var wave=EchoWaves[EchoWave];
   // Someone standing on a spawn point first gets room to walk away.
   for(int i=0;i<wave.Length;i++)if(Vector2.Distance(World.Position,EchoSpawns[i])<70){EchoCountdown=1;return;}
   for(int i=0;i<wave.Length;i++){var foe=Encounter.Spawn(wave[i],EchoSpawns[i]);if(foe!=null){foe.StateTime=0;echoFoes.Add(foe);}}
   EchoWave++;StoryActions(Action("toast",StoryModel.S(Farm.Format("Resonantieproef: golf %d / 3",EchoWave))));
  }
  // --- The hot spring -----------------------------------------------------------------------------------
  /// <summary>Standing still beside a hot spring, with no hostile creature nearby, slowly restores one heart.</summary>
  void TickHotSpring(double delta)
  {
   var state=Gameplay.State;if(state.InputLocked)return;var near=WaterModel.Nearest(state.MapId,World.Position,76);
   if(!near.Found||near.Kind!="hot_spring"||World.Motor.Velocity.magnitude>2){HotSpringRest=0;return;}
   if(Encounter!=null&&Encounter.Actors.Any(e=>!e.Dead&&e.Behavior!="animal"&&Vector2.Distance(e.Position,World.Position)<200)){HotSpringRest=0;return;}
   HotSpringRest+=delta;if(HotSpringRest<15)return;HotSpringRest=0;
   if(state.Hp<state.MaxHp){state.Hp=state.Hp+1;OnSaveRequested();}
  }
  void ResetAreas(){areaWork.Clear();pendingArea=null;pendingAreaMap="";RegionWater=3;RegionHeat=0;RegionExposure=0;RegionTime=0;regionShelter=new Vector2(4.5f,19.5f)*32;RegionStatus="";RegionGauge=0;EchoTrialActive=false;EchoWave=0;EchoCountdown=0;echoFoes.Clear();HotSpringRest=0;}
  void TickAreas(double delta)
  {
   if(Session?.Current==null)return;
   if(!ReferenceEquals(areasBuiltFor,Session.Current)){areasBuiltFor=Session.Current;ResetAreas();}
   TickAreaWork(delta);TickRegion(delta);TickEchoTrial(delta);TickHotSpring(delta);
  }
  /// <summary>External dialogue actions that belong to an object in the world.</summary>
  bool HandleAreaExternal(string name,FoundationValue action)
  {
   string choice=action.Items.Count>1&&action.Items[1].Kind=="string"?action.Items[1].AsString():"";
   if(name=="living"){ChooseAreaAction(choice);return true;}
   if(name=="regional"){ChooseRegional(choice);return true;}
   return false;
  }
 }
}
