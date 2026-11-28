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
 /// The coastal adventures (the washed-up log, the old pilot route, the tide wheel and the Shell Keeper) and
 /// Raf's harbour workshop (bench, furniture and the reusable shore line). Every choice stays visible and a
 /// mistake never costs anything, exactly as in the source.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  Action<string> infoHandler;RouteTarget infoTarget;string infoMap="";
  RouteTarget coastWorkTarget;string coastWorkKind="",coastWorkMap="";double coastWorkTime;Vector2 coastWorkOrigin,coastLanding;EncounterActor coastKeeper;FoundationWorldSnapshot coastBuiltFor;
  public bool CoastWorking=>coastWorkTarget!=null;public double CoastWorkProgress=>coastWorkTarget==null?0:Math.Min(1,coastWorkTime/(coastWorkKind=="repair"?1.8:1.2));
  public bool CoastKeeperPresent=>coastKeeper!=null&&!coastKeeper.Dead;
  string CoastRole(RouteTarget t)=>AreaText(t,"role");
  bool QuestKnown(string id)=>Gameplay.State.QuestState(id)!="none";
  /// <summary>An explanatory menu of an object in the world: a title, its text and a few choices.</summary>
  void OpenInfoMenu(RouteTarget target,string title,IEnumerable<string> lines,IEnumerable<GardenOption> options,Action<string> handler,string focus=null)
  {
   bool reopen=Modal=="garden_menu"&&ReferenceEquals(infoTarget,target);infoTarget=target;infoMap=Gameplay.State.MapId;gardenRole="info";gardenStation=null;
   if(!reopen){SetModal("garden_menu");GardenMenu.SetControllerActive(ControllerActive);}
   infoHandler=handler;GardenMenu.Open("info:"+target.Address,title,lines,options.Concat(new[]{new GardenOption("close",Translate("Sluiten"))}),focus);if(!reopen)GardenMenu.NotifyOpened(storyInput);
  }
  bool InfoValid()=>infoMap==Gameplay.State.MapId&&!Gameplay.State.Transitioning&&!Gameplay.State.Ended&&(infoTarget==null||(targets.Contains(infoTarget)&&Vector2.Distance(World.Position,infoTarget.Position)<=64));
  // --- Coastal adventures -------------------------------------------------------------------------------
  bool CoastEvidence(AreaBatch b)=>b.Flag("ad_splinter")&&b.Flag("ad_silt");
  void CoastBegin(AreaBatch b,string quest){if(!QuestKnown(quest))b.Start(quest);}
  void CoastSync(AreaBatch b){var s=Gameplay.State;if(s.QuestState("ad_message")=="active"&&CoastEvidence(b)&&s.QuestStep("ad_message")<1)b.Step("ad_message",1);}
  void CoastFinish(AreaBatch b,string quest){if(!QuestKnown(quest))b.Start(quest);b.Finish(quest);b.Set(quest+"_done");b.Save();}
  void CoastResolve(bool peace)
  {
   if(Gameplay.State.Flag("ad_keeper_done"))return;var b=new AreaBatch(this);b.Set(peace?"ad_pool":"ad_workwater");b.Set("ad_duel",false);CoastFinish(b,"ad_keeper");b.Run();
  }
  string CoastLabel(RouteTarget t)
  {
   switch(CoastRole(t))
   {
    case "message":return Translate("Aangespoeld logboek");case "splinter":return Translate("Breuksporen in het wrakhout");case "silt":return Translate("Afzetting aan de oever");case "record":return Translate("Werkboek van de haven");
    case "pilot":return Translate("De oude loodsenroute");case "rock":return Translate("Gespleten rots");case "grass":return Translate("Bleek zoutgras");case "shelter":return Translate("Beschutte rustplek");
    case "entrance":return Translate("Zijgrot · Tijholte");case "wheel":return Translate("Vastgelopen tijrad");case "keeper_rest":return Translate("Rustende Schelpenhoeder");
   }
   return Translate("Sluistafel · Schelpenhoeder");
  }
  bool CoastHidden(RouteTarget t){string role=CoastRole(t);return role=="buoy"||role=="harbor_wheel"||(role=="keeper_rest"&&(Gameplay.State.Flag("ad_duel")||Gameplay.State.Flag("ad_workwater")));}
  bool InteractCoastAdventure(RouteTarget target)
  {
   if(Gameplay.State.InputLocked||CoastHidden(target)||Vector2.Distance(World.Position,target.Position)>64)return false;BuildCoastAdventure(target);return true;
  }
  void BuildCoastAdventure(RouteTarget target,string note=null)
  {
   var state=Gameplay.State;string role=CoastRole(target),detail="";var options=new List<GardenOption>();var b=new AreaBatch(this);
   switch(role)
   {
    case "message":
     CoastBegin(b,"ad_message");CoastSync(b);
     detail="Een los logboek: ‘Niet langs de buitenbank. Het hout brak terwijl het water terugliep.’ De afzender ontbreekt. Vergelijk het wrakhout aan het zuidelijke eilandstrand met de afzetting aan de oostelijke rivieroever. Het werkboek op de havenkade wacht op je conclusie.";break;
    case "splinter":
     detail="De breuk is scherp en schoon; er zit wit schelpgruis tussen de vezels. Dit hout heeft tegen een harde buitenbank geschuurd, niet lang op een modderige rivierbodem gelegen.";
     options.Add(new GardenOption("record:ad_splinter",Translate("Noteer het schelpgruis"),!state.Flag("ad_splinter")));break;
    case "silt":
     detail="De rivieroever draagt fijn donker slib en afgerond riet. Het lichte schelpgruis van het wrakhout ontbreekt hier. De rivier heeft het hout aangevoerd, maar de breuk ontstond ergens anders.";
     options.Add(new GardenOption("record:ad_silt",Translate("Noteer het donkere slib"),!state.Flag("ad_silt")));break;
    case "record":
     detail="Het havenboek kan een waarschuwing bij de juiste vaarroute plaatsen. Vergelijk beide waarnemingen voordat je een conclusie trekt. Een vergissing kost niets.";
     if(state.Flag("ad_message_done"))detail="De buitenbank staat gemarkeerd. Bij het einde van de werkkade dobbert de nieuwe waarschuwingsboei.";
     else{bool ready=CoastEvidence(b)&&QuestKnown("ad_message");options.Add(new GardenOption("deduce:yes",Translate("De buitenbank brak het hout; markeer die route"),ready));options.Add(new GardenOption("deduce:no",Translate("Het hout brak op de modderige rivieroever"),ready));}
     break;
    case "pilot":
     detail="De loodsen volgden herkenbare vormen, zonder klok of verzamelopdracht. Begin bij de lage gespleten rots in het noordwestelijke grasland, boven het hoge havenpad. Lees daar het oude richtteken.";
     options.Add(new GardenOption("pilot",Translate("Volg de oude loodsenroute"),!QuestKnown("ad_pilot")));break;
    case "rock":
     detail="In de spleet wijst een oude kerf naar het oosten: zoek de bleke zoutgraspol voorbij het midden van de kaap, ten noorden van het vuurtorenpad.";
     options.Add(new GardenOption("trail:0",Translate("Lees het richtteken"),state.QuestState("ad_pilot")=="active"&&state.QuestStep("ad_pilot")==0));break;
    case "grass":
     detail="Tussen het bleke gras ligt een loodsensteen met een lage golf erin. Volg de kaap naar de bank aan de zuidoostelijke afslag; daar liggen de oude schermlatten klaar.";
     options.Add(new GardenOption("trail:1",Translate("Volg de lage golf naar de rustplek"),state.QuestState("ad_pilot")=="active"&&state.QuestStep("ad_pilot")==1));break;
    case "shelter":
     detail="Een bank boven zee. De oude schermlatten liggen hier al: zet ze langs de windzijde terug. Geen spullen nodig; het uitzicht en de route blijven open.";
     options.Add(new GardenOption("shelter",Translate("Zet het lage windscherm terug"),state.QuestState("ad_pilot")=="active"&&state.QuestStep("ad_pilot")==2));
     if(state.Flag("ad_pilot_done"))detail="Het lage windscherm staat weer. Neem gerust de tijd; de hoge terugweg naar de haven blijft vrij.";break;
    case "entrance":
     detail="Tijholte · optionele zijgrot. Volg de korte noordelijke afslag naar de ingang. Binnen blijft de brede zuidelijke gang veilig; de noordelijke poelen bevatten krabben en lichtkringen. Je kunt altijd omkeren.";
     options.Add(new GardenOption("wheel",Translate("Onderzoek het tijrad in de zijgrot"),!QuestKnown("ad_wheel")));break;
    case "wheel":
     CoastBegin(b,"ad_wheel");if(state.QuestState("ad_wheel")!="done")b.Step("ad_wheel",1);
     detail="Een losgeraakte pen houdt het rad tegen. Het passende gereedschap ligt hier. Maak de pen vrij en stel het rad af; dat duurt even. Annuleer met Terug of een looptoets. Je verliest niets. De zuidelijke omweg blijft open.";
     if(state.Flag("ad_wheel_done"))detail="Het rad draait. De korte brug over de middelste watergeul is droog; de brede zuidelijke route blijft ook open.";
     options.Add(new GardenOption("repair",Translate("Maak het rad vrij · gereedschap ligt hier"),!state.Flag("ad_wheel_done")));break;
    case "keeper_rest":
     detail="De hoeder rust aan de rand van zijn poel. Hij valt je niet zomaar aan. Bij de sluistafel in de zuidelijke gang kun je na herstel van het tijrad kiezen hoe het water stroomt.";break;
    default:
     detail="Het herstelde rad kan het water verdelen. Geef de hoeder zijn rustige poel, of voed het havenrad en neem vrijwillig zijn krachtproef aan. De keuze blijft zichtbaar. De beloning voor het verhaal is gelijk; terugtrekken uit de proef blijft mogelijk.";
     if(state.Flag("ad_keeper_done"))detail=state.Flag("ad_pool")?"Het riet groeit rond de rustige poel. De hoeder heeft zich teruggetrokken.":"Het havenrad draait. De Schelpenhoeder heeft je krachtproef aanvaard; de doorgang blijft vrij.";
     else if(!state.Flag("ad_wheel_done"))detail="Herstel eerst het tijrad in de veilige zuidelijke gang. De hoeder wacht; de terugweg blijft vrij.";
     else{CoastBegin(b,"ad_keeper");options.Add(new GardenOption("choose:peace",Translate("Geef de poel rust · vreedzame afloop")));options.Add(new GardenOption("choose:duel",Translate("Voed het havenrad · vrijwillige krachtproef"),!state.Flag("ad_duel")));}
     break;
   }
   b.Run();OpenInfoMenu(target,CoastLabel(target),new[]{Translate(note??detail)},options,CoastChosen);
  }
  void CoastChosen(string id)
  {
   var target=infoTarget;if(id=="close"||!InfoValid()){CloseModal();return;}var state=Gameplay.State;var b=new AreaBatch(this);
   if(id.StartsWith("record:",StringComparison.Ordinal)){b.Set(id.Substring(7));CoastSync(b);b.Save();b.Run();BuildCoastAdventure(target);return;}
   switch(id)
   {
    case "deduce:yes":case "deduce:no":
     if(!CoastEvidence(b)||!QuestKnown("ad_message"))return;
     if(id=="deduce:yes"){CoastFinish(b,"ad_message");b.Sound("ad_water");b.Run();BuildCoastAdventure(target);}
     else BuildCoastAdventure(target,"Het slib verklaart de breuk niet. Schelpgruis in schoon gebroken hout wijst naar de harde buitenbank. Vergelijk je aantekeningen en probeer gerust opnieuw.");
     return;
    case "pilot":CoastBegin(b,"ad_pilot");b.Save();b.Run();BuildCoastAdventure(target);return;
    case "trail:0":case "trail:1":
     {long step=id=="trail:0"?0:1;if(state.QuestState("ad_pilot")!="active"||state.QuestStep("ad_pilot")!=step)return;b.Step("ad_pilot",step+1);b.Save();b.Run();BuildCoastAdventure(target);return;}
    case "shelter":if(state.QuestStep("ad_pilot")!=2)return;CoastFinish(b,"ad_pilot");b.Sound("ad_work");b.Run();BuildCoastAdventure(target);return;
    case "wheel":CoastBegin(b,"ad_wheel");b.Save();b.Run();BuildCoastAdventure(target);return;
    case "repair":
     if(state.Flag("ad_wheel_done"))return;CloseModal();coastWorkTarget=target;coastWorkKind="repair";coastWorkMap=state.MapId;coastWorkTime=0;coastWorkOrigin=World.Position;OnSound("ad_work");return;
    case "choose:peace":case "choose:duel":
     if(!state.Flag("ad_wheel_done")||state.Flag("ad_keeper_done"))return;
     if(id=="choose:peace"){CoastResolve(true);OnSound("ad_water");}else{b.Set("ad_duel");b.Save();b.Run();}
     CloseModal();return;
   }
  }
  // --- Raf's harbour workshop ---------------------------------------------------------------------------
  string WorkshopLabel(RouteTarget t)
  {
   switch(CoastRole(t))
   {
    case "door":return Translate("Rafs havenwerkplaats");case "bench":return Translate("Werkbank en kustpatronen");case "storage":return Translate("Materiaalkist");
    case "layout":case "shelf":case "lamp":return Translate("Werkplaats inrichten");case "line":return Translate("Oeverlijn · korte rivierroute");case "practice":return Translate("Proefopstelling · kuststijlen");
   }
   return "";
  }
  bool InteractWorkshop(RouteTarget target)
  {
   if(Gameplay.State.InputLocked||Vector2.Distance(World.Position,target.Position)>40)return false;string role=CoastRole(target);
   BuildWorkshop(target,role=="layout"||role=="lamp"||role=="shelf"?"layout":role);return true;
  }
  void BuildWorkshop(RouteTarget target,string page,string focus=null)
  {
   var state=Gameplay.State;string title="",detail="";var options=new List<GardenOption>();
   switch(page)
   {
    case "bench":
     title="Werkbank · zeven bestaande beroepen";detail="Raf helpt met lijn en houtwerk. Greta smeedt ankerbanden; Lena maakt waaierbanden en een lamp. Zoutblad en Joris' baars gaan naar Mila's keuken. De vier kustplekken leveren per oogst genoeg voor de eerste plannen; je hoeft geen dagelijkse ronde te doen.";
     options.Add(new GardenOption("recipe:cw_hook",Translate("Oeverlijn · bekijk echte kosten")));options.Add(new GardenOption("recipe:cw_shelf",Translate("Wandrek · bekijk echte kosten")));
     options.Add(new GardenOption("page:gear",Translate("Gearkeuzes en bestaande werkplekken")));options.Add(new GardenOption("page:layout",Translate("Werkplaats inrichten")));break;
    case "gear":
     title="Twee keuzes voor hetzelfde handvak";detail="Ankerbanden: pantser en een korte frontale wacht met tegenstoot. Waaierbanden: sneller verzamelen en een brede boogwaaier. Bezit geeft geen bonus; draag één paar via Uitrusting. Oude handschoenen en alle gewone aanvallen blijven bruikbaar.";
     options.Add(new GardenOption("recipe:cw_anchor",Translate("Ankerbanden · smeden bij Greta")));options.Add(new GardenOption("recipe:cw_fan",Translate("Waaierbanden · alchemie bij Lena")));
     options.Add(new GardenOption("recipe:cw_lamp",Translate("Zeeagaatlamp · alchemie bij Lena")));options.Add(new GardenOption("recipe:cw_broth",Translate("Kustbouillon · koken bij Mila")));break;
    case "layout":
     title="Vaste meubelplekken";detail="Het wandrek en de lamp hebben ieder een vaste sokkel buiten de looproute. Plaatsen, weghalen en licht wisselen kosten niets en verbruiken geen meubel. Je materiaalkist blijft altijd bruikbaar, ook zonder meubels.";
     options.Add(new GardenOption("shelf",Translate(state.Flag("cw_shelf_placed")?"Wandrek opbergen":"Wandrek plaatsen"),state.Count("cw_shelf")>0));
     options.Add(new GardenOption("lamp:0",Translate("Lamp uit"),state.Count("cw_lamp")>0));options.Add(new GardenOption("lamp:1",Translate("Warm licht"),state.Count("cw_lamp")>0));options.Add(new GardenOption("lamp:2",Translate("Zeelicht"),state.Count("cw_lamp")>0));
     options.Add(new GardenOption("recipe:cw_shelf",Translate("Wandrekrecept · werkbank")));options.Add(new GardenOption("recipe:cw_lamp",Translate("Lamprecept · Lena")));break;
    case "line":
     title="Herbruikbare oeverlijn";detail="Nodig: Rafs oeverlijn, gemaakt in de havenwerkplaats. De lijn wordt niet verbruikt en werkt aan beide palen. Zonder lijn neem je de hoge rivierbrug. De korte oversteek is af te breken; er verdwijnen geen spullen of stamina.";
     options.Add(new GardenOption("cross",Translate("Steek over · lijn blijft bij je"),state.Count("cw_hook")>0));break;
    default:
     title="Kuststijlen · vrije proefopstelling";
     detail=Farm.Format("Draag je eigen banden. Houd %s vast en gebruik %s voor de ankerwacht, of %s voor de boogwaaier. Na een tijdige frontale blokkade: druk gewoon op zwaard voor de tegenstoot. De poppen doen geen schade en geven geen buit of XP. Tijdens de proef leen je pijlen; een eigen boog blijft nodig.",BindingLabel("technique"),BindingLabel("attack"),BindingLabel("bow"));
     OpenInfoMenu(target,Translate(title),new[]{detail,T("De oefenpoppen volgen in een latere migratiefase; je banden werken al in echte gevechten.","The practice dummies follow in a later migration phase; your bands already work in real fights.")},options,id=>CloseModal());return;
   }
   OpenInfoMenu(target,Translate(title),new[]{Translate(detail)},options,id=>WorkshopChosen(id),focus);
  }
  void WorkshopChosen(string id)
  {
   var target=infoTarget;if(id=="close"||!InfoValid()){CloseModal();return;}var state=Gameplay.State;
   if(id.StartsWith("recipe:",StringComparison.Ordinal)){string recipe=id.Substring(7);CloseModal();OpenProfessions(recipe);return;}
   if(id.StartsWith("page:",StringComparison.Ordinal)){BuildWorkshop(target,id.Substring(5));return;}
   if(id=="shelf"||id.StartsWith("lamp:",StringComparison.Ordinal))
   {
    if(state.MapId!="coast_workshop"||state.Ended||state.Transitioning)return;
    // Only true flags are saved: the original loader reads every saved flag as set.
    if(id=="shelf"){if(state.Count("cw_shelf")==0)return;state.SetFlag("cw_shelf_placed",!state.Flag("cw_shelf_placed"));}
    else{if(state.Count("cw_lamp")==0)return;int mode=id[5]-'0';state.SetFlag("cw_lamp_on",mode>0);state.SetFlag("cw_lamp_sea",mode==2);}
    OnSound("cw_thread");OnSaveRequested();BuildWorkshop(target,"layout",id);return;
   }
   if(id=="cross")
   {
    if(state.MapId!="river_mouth"||state.Count("cw_hook")==0||coastWorkTarget!=null)return;var landing=AreaObj(target).Require("landing").Items;
    coastLanding=new Vector2((float)landing[0].AsDouble(),(float)landing[1].AsDouble())*32+new Vector2(16,44);
    if(!GardenSpawnFitsAt(coastLanding)){CloseModal();StoryActions(Action("toast",StoryModel.S("De landingsplek is bezet. De hoge brug blijft open.")));return;}
    CloseModal();coastWorkTarget=target;coastWorkKind="cross";coastWorkMap=state.MapId;coastWorkTime=0;coastWorkOrigin=World.Position;OnSound("cw_thread");
   }
  }
  bool GardenSpawnFitsAt(Vector2 at)
  {
   var foot=at+new Vector2(0,8);
   foreach(var offset in new[]{Vector2.zero,new Vector2(8,0),new Vector2(-8,0),new Vector2(0,8),new Vector2(0,-8)})if(World.CombatSolid(foot+offset))return false;
   return World.CombatBodyFits(foot,8);
  }
  // --- Timed work and the keeper ------------------------------------------------------------------------
  void TickCoast(double delta)
  {
   if(Session?.Current==null)return;var state=Gameplay.State;
   if(!ReferenceEquals(coastBuiltFor,Session.Current)){coastBuiltFor=Session.Current;coastWorkTarget=null;coastKeeper=null;infoTarget=null;infoHandler=null;}
   if(Modal=="garden_menu"&&infoHandler!=null&&!InfoValid())CloseModal();
   if(Modal!="garden_menu")infoHandler=null;
   foreach(var target in targets.Where(t=>t.Kind=="coastal_adventure"))target.Label=CoastLabel(target);
   if(coastWorkTarget!=null)
   {
    // Walking away, a menu or a missing line cancels the work; nothing is lost.
    if(coastWorkMap!=state.MapId||state.InputLocked||Vector2.Distance(World.Position,coastWorkOrigin)>6||(coastWorkKind=="cross"&&state.Count("cw_hook")==0)){coastWorkTarget=null;coastWorkTime=0;}
    else
    {
     coastWorkTime+=delta;
     if(coastWorkKind=="repair"&&coastWorkTime>=1.8)
     {
      coastWorkTarget=null;var b=new AreaBatch(this);CoastFinish(b,"ad_wheel");b.Sound("ad_water");b.Run();state.Position=PositionValue(World.Position);TryTravel("tidal_hollow","start",true);OnSaveRequested();
     }
     else if(coastWorkKind=="cross"&&coastWorkTime>=1.2)
     {
      coastWorkTarget=null;if(GardenSpawnFitsAt(coastLanding)){World.Teleport(coastLanding);World.Motor.StopForTransition();World.FocusCameraOnPlayer();OnSaveRequested();}
     }
    }
   }
   if(state.MapId!="tidal_hollow"||Encounter==null)return;
   if(state.Flag("ad_keeper_done")){if(coastKeeper!=null&&!coastKeeper.Dead){coastKeeper.Dead=true;coastKeeper.Finished=true;}coastKeeper=null;return;}
   if(coastKeeper!=null&&(coastKeeper.Dead||!Encounter.Actors.Contains(coastKeeper))){bool fell=coastKeeper.Dead;coastKeeper=null;if(fell){CoastResolve(false);return;}}
   if(state.Flag("ad_duel")&&coastKeeper==null&&!state.InputLocked)coastKeeper=Encounter.Spawn("ad_keeper",new Vector2(47.5f,13.5f)*32,"ad_keeper_defeated");
  }
 }
}
