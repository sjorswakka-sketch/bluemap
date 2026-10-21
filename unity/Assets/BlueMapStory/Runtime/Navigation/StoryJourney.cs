using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
namespace BlueMapMigration.Story
{
 /// <summary>Original journey.gd routing and HUD precedence; one optional focus in existing save flags.</summary>
 public sealed class StoryJourney
 {
  readonly StoryModel model;
  readonly Dictionary<string,List<FoundationValue>> links=new Dictionary<string,List<FoundationValue>>(StringComparer.Ordinal);
  FoundationGameState State=>model.State;FoundationValue Quests=>model.Catalogs.Require("quests");
  public double Stamina {get;set;}=100;public double StaminaCapacity {get;set;}=100;
  public event Action SaveRequested;
  public StoryJourney(FoundationWorldRepository repository,StoryModel model){this.model=model;}
  string Tr(string text)=>model.Translator?.Invoke(text)??text;
  static FoundationValue Get(FoundationValue v,string key,FoundationValue fallback)=>v.TryGet(key,out var x)?x:fallback;
  static FoundationValue Text(string v)=>FoundationValue.StringValue(v);
  static FoundationValue EmptyArray()=>FoundationValue.Array(Array.Empty<FoundationValue>());
  public string FocusedQuest{get{foreach(var q in Quests.Entries){string id=q.Key.AsString();if(State.Flag("jr_focus_"+id)&&State.QuestState(id)=="active")return id;}return "";}}
  public bool ToggleFocus(string id)
  {
   if(!Quests.TryGet(id,out _)||State.QuestState(id)!="active")return false;
   string old=FocusedQuest;var flags=State.Get("flags").Entries.Where(e=>!e.Key.AsString().StartsWith("jr_focus_",StringComparison.Ordinal)).ToList();
   if(old!=id)flags.Add(new KeyValuePair<FoundationValue,FoundationValue>(Text("jr_focus_"+id),FoundationValue.Boolean(true)));
   State.Set("flags",FoundationValue.Object(flags));SaveRequested?.Invoke();return true;
  }
  public IReadOnlyList<string> QuestOrder=>new[]{"active","done"}.SelectMany(status=>Quests.Entries.Where(q=>State.QuestState(q.Key.AsString())==status).Select(q=>q.Key.AsString())).ToArray();
  public string QuestTitle(string id)=>Quests.TryGet(id,out var q)?Tr(q.Require("title").AsString()):"";
  public string QuestStatusText(string id)
  {
   if(!Quests.TryGet(id,out var q))return "";if(State.QuestState(id)=="done")return Tr("Afgerond");
   string status=Sub(Tr("Stap %d / %d"),State.QuestStep(id)+1,q.Require("steps").Items.Count);
   return Get(q,"main",FoundationValue.Boolean(false)).AsBool()?Tr("Hoofdverhaal")+" · "+status:status;
  }
  public string QuestTarget(string id)
  {
   if(!model.Catalogs.Require("journeyTargets").TryGet(id,out var target))return "";
   int step=(int)Math.Max(0,State.QuestStep(id));
   if(id=="main"&&step==0)
   {
    var crystals=new[]{("forest","crystal_bos"),("ruins","crystal_ruine"),("cave","crystal_grot")};
    foreach(var p in crystals)if(p.Item1==State.MapId&&State.Count(p.Item2)==0)return p.Item1;
    foreach(var p in crystals)if(State.Count(p.Item2)==0)return p.Item1;
   }
   if(id=="meer_boeken"&&step==0){if(State.Count("meer_boek_eiland")<1||State.Count("meer_boek_sanne")<1)return "lake";if(State.Count("meer_boek_hut")<1)return "fisher_hut";return "library";}
   if(id=="rf_memory"&&step==1&&State.Count("medallion")>0)return "ruins";
   return target.Items[Math.Min(step,target.Items.Count-1)].AsString();
  }
  bool MapExists(string id)=>model.Catalogs.Require("maps").TryGet(id,out _);
  // Original journey.gd reads immutable Maps.get_map data, never a loaded scene or collision snapshot.
  FoundationValue Map(string id)=>model.Catalogs.Require("maps").Require(id);
  string Title(string id)=>MapExists(id)?Tr(Map(id).Require("name").AsString()):"";
  IReadOnlyList<FoundationValue> Links(string id)
  {
   if(links.TryGetValue(id,out var list))return list;list=new List<FoundationValue>();
   var objects=Map(id).Require("objects").Items;
   foreach(var obj in objects){string kind=obj.Require("type").AsString();if(kind=="portal"||kind=="coast_dock"||Get(obj,"travel_link",FoundationValue.Boolean(false)).AsBool())list.Add(obj);}
   foreach(var obj in objects)if(obj.Require("type").AsString()=="tide_station"&&Get(obj,"role",Text("")).AsString()=="routes")
    foreach(var r in obj.Require("routes").Items)list.Add(FoundationValue.Object(new Dictionary<string,FoundationValue>{{"type",Text("coast_route")},{"pos",obj.Require("pos")},{"to",r.Require("to")},{"spawn",r.Require("spawn")}}));
   links.Add(id,list);return list;
  }
  bool PortalOpen(string from,FoundationValue portal)=>!(from=="forest"&&portal.Require("to").AsString()=="ruins"&&!State.Flag("gate_ruin"))&&model.CheckAll(Get(portal,"requires",EmptyArray()));
  public IReadOnlyList<string> Path(string from,string to,bool openOnly=true)
  {
   var result=new List<string>();if(!MapExists(from)||!MapExists(to))return result;
   var queue=new Queue<string>();queue.Enqueue(from);var previous=new Dictionary<string,string>{{from,""}};
   while(queue.Count>0){string here=queue.Dequeue();if(here==to){while(here!=""){result.Insert(0,here);here=previous[here];}return result;}
    foreach(var portal in Links(here)){string next=portal.Require("to").AsString();if(previous.ContainsKey(next)||(openOnly&&!PortalOpen(here,portal)))continue;previous.Add(next,here);queue.Enqueue(next);}}
   return result;
  }
  public string RouteText(string id)
  {
   string to=QuestTarget(id);if(to=="")return "";if(to==State.MapId)return Sub(Tr("Je bent in het juiste gebied: %s."),Title(to));
   var path=Path(State.MapId,to);if(path.Count==0)
   {
    path=Path(State.MapId,to,false);if(path.Count==0)return Sub(Tr("Doelgebied: %s."),Title(to));
    for(int i=0;i<path.Count-1;i++)foreach(var portal in Links(path[i]))
    {
     if(portal.Require("to").AsString()!=path[i+1]||PortalOpen(path[i],portal))continue;
     string hint=Tr(Get(portal,"locked_text",Text("Onderzoek de gemarkeerde doorgang.")).AsString());
     if(path[i]=="forest"&&portal.Require("to").AsString()=="ruins")hint=Tr("Open het ruïnepoortje met de bossleutel.");
     return Sub(Tr("Route naar %s nog gesloten. %s"),Title(to),hint);
    }
   }
   string next=path.Count>1?path[1]:to;
   foreach(var p in Links(State.MapId))if(p.Require("to").AsString()==next)
   {long x=(long)p.Require("pos").Items[0].AsDouble()+1,y=(long)p.Require("pos").Items[1].AsDouble()+1;
    return p.Require("type").AsString()=="coast_route"?Sub(Tr("Naar %s: kies de veer op het reisbord (%d, %d op de kaart)."),Title(to),x,y):Sub(Tr("Naar %s: neem de doorgang naar %s (%d, %d op de kaart)."),Title(to),Title(next),x,y);}
   return "";
  }
  public string CompactRoute(string id){string to=QuestTarget(id);if(to==""||to==State.MapId)return "";var path=Path(State.MapId,to);return path.Count>2?Sub(Tr("Via %s → %s"),Title(path[1]),Title(to)):Sub(Tr("Doel: %s"),Title(to));}
  static readonly string[] PreparationText={"De brede zuidelijke gang blijft veilig. De korte brug vraagt alleen herstel met gereedschap ter plaatse. Noordelijke poelen en de krachtproef zijn optioneel; je kunt altijd teruglopen.","Greta smeedt ijzer voor 5 slijmgel en 40 munten. Een korter gevecht geeft meer ruimte om te ontwijken.","De mijnpoort vraagt een ijzeren zwaard. Richt spiegels vóór je de kern benadert; aardingspoeder is een alternatief voor het gevecht.","Lopen is stil. Wissel gevechten af met luisteren bij de schalen; sprinten en rollen trekken luisteraars aan.","Voor een zwaar gevecht: Greta smeedt kristal voor 2 scherven, 8 slijmgel en 80 munten. Dit is voorbereiding, geen verplichte levelgrens.","Gebruik het altaar vóór je de arena inloopt. Het herstelt hartjes én stamina. Voorbij de gevechtsdeur kun je pas terug na de baas.","Meer ruimte voor fouten? Pim geeft een extra hartje als Muis thuis is. Wilfred geeft twee scherven voor je kristalzwaard wanneer je zijn medaillon terugbrengt.","De huizen kunnen met hout, wintergloed of de prismatechniek worden verwarmd. Houd aanvallers bij de vuurkorven weg; je hoeft niet alle drie de middelen te verzamelen.","Het kamp geeft klimtouw. Wacht op slappe wimpels vóór de oversteek; de vastgezette lijn maakt latere bezoeken veilig.","De brede stenen trappen verbinden vier hoogten. Rust aan de warmwaterbronnen om hartjes te herstellen. De roodkopapen zijn vreedzaam; geisers en stoom zijn decoratief.","Vul eerst de waterzak bij Sana. De blauwe luifels in de kloof vullen water bij en geven schaduw. Een lege zak brengt je veilig terug naar je laatste waterpunt.","De westelijke sluis open en de oostelijke dicht verlagen het water. Herstel daarna de brug; het archief draait om onderzoeken, geen verzamelquotum.","Hier is ruimte voor een rustiger bezoek: vissen, koken, lezen of kruiden zoeken. Deze route wacht gewoon op je als je eerst ergens anders heen wilt.","De arena is optioneel. Bruno toont iedere rang en inzet vóór je begint; een gewone avonturenroute vraagt geen arenarang.","De lichtkring vraagt een prismalantaarn. Na de mijn kun je die bij Greta maken met een lens en twee takken, of laten monteren voor 40 munten.","Bij je: %d helddrankjes · %d/%d hartjes · %.0f/%.0f stamina.","Gedragen pantser: %.0f. Bonussen komen alleen van je gedragen set."};
  public IReadOnlyList<string> Preparation(string map)
  {
   var lines=new List<string>();Action<int> add=i=>lines.Add(Tr(PreparationText[i]));
   switch(map)
   {
    case "tidal_hollow":add(0);break;
    case "ruins":case "cave":case "prismamine":if(State.Weapon=="wood")add(1);if(map=="prismamine")add(2);else if(map=="cave")add(3);break;
    case "temple":case "depths1":case "depths2":if(State.Weapon=="wood"||State.Weapon=="iron")add(4);add(5);if(5+State.Count("heart_container")<=5)add(6);break;
    case "ijsdal":add(7);break;case "ridgepass":add(8);break;case "steampeak":add(9);break;case "sunwell":add(10);break;
    case "kruipmoeras":case "reedvault":add(11);break;
    case "lake":case "inn":case "library":case "mistgarden":add(12);break;
    case "arena_hall":case "arena":add(13);break;case "dauwbos":add(14);break;
   }
   if(new[]{"ruins","cave","temple","depths1","depths2","prismamine"}.Contains(map))
   {lines.Add(Sub(Tr(PreparationText[15]),State.Count("potion"),State.Hp,5+State.Count("heart_container"),Stamina,StaminaCapacity));double armor=model.Progression.Bonus("armor");if(armor>0)lines.Add(Sub(Tr(PreparationText[16]),armor));}
   return lines;
  }
  public string QuestDetail(string id)
  {
   if(!Quests.TryGet(id,out var q))return "";
   if(State.QuestState(id)=="done")return QuestTitle(id)+"\n\n"+Tr(Get(q,"effect",Text("Voltooid.")).AsString())+"\n\n"+Tr("Deze opdracht is afgerond. Kies een lopende opdracht om op het scherm te volgen.");
   var lines=new List<string>{QuestTitle(id),Tr("Huidige stap"),model.QuestText(id),RouteText(id)};
   var prep=Preparation(QuestTarget(id));if(prep.Count>0){lines.Add(Tr("Voor je verdergaat"));lines.AddRange(prep);}
   lines.Add(Tr("Snel terug? Ontdekte altaren staan op de kaart. Reizen vult niets bij; rusten bij het altaar wel."));return string.Join("\n\n",lines);
  }
  string FocusTracker{get{string id=FocusedQuest;if(id=="")return "";string compact=CompactRoute(id);return Sub(Tr("Volg: %s"),QuestTitle(id))+"\n"+model.QuestText(id)+(compact!=""?"\n"+compact:"");}}
  public string TrackedText
  {get{string focus=FocusTracker;if(focus!="")return focus;if(State.QuestState("main")=="done"){string chosen="";foreach(var q in State.Get("quests").Entries)if(State.QuestState(q.Key.AsString())=="active")chosen=q.Key.AsString();return chosen!=""?model.QuestText(chosen):Tr("De Blauwe Kaart is hersteld!");}return State.QuestState("main")=="active"?model.QuestText("main"):Tr("Praat met Oudste Bram bij de tempel.");}}
  public string HudTrackedText
  {get{
   string text=TrackedText,map=State.MapId;
   if(FocusedQuest=="")
   {
    if(map=="ruins"&&State.QuestState("rf_memory")=="active")text=model.QuestText("rf_memory");
    else if(map=="cave"&&State.QuestState("rf_echo")=="active")text=model.QuestText("rf_echo");
    else if(map=="forest"&&State.QuestState("kat")=="active"&&!State.Flag("cat_found"))text=Tr("Volg de pootafdrukken vanaf het zuidelijke bospad. Bij Muis: stop met rennen, praat met haar en blijf rustig staan.");
    if((map=="lake"||map=="inn")&&State.QuestState("ls_supper")=="active")text=State.Flag("ls_cooked")&&State.Count("ls_chowder")+State.Count("ls_broth")==0?Tr("Alle porties opgegeten? Kook opnieuw met baars en zilverkruid of bessen. Joris' nettenrek levert een reservevangst op."):model.QuestText("ls_supper");
    string quest=map=="dorstvallei"||map=="sunwell"?"cactusvijgen":map=="ridgepass"?"ra_ridge":map=="reedvault"?"ra_archive":"";
    if(quest!=""&&State.QuestState(quest)=="active")text=model.QuestText(quest);
   }
   bool opening=State.Flag("op_new_adventure")&&State.Get("ng_plus").AsInt64()==0;
   if(opening&&State.QuestState("first_water")=="active"&&(map=="village"||map=="smithy"))text=model.QuestText("first_water");
   else if(opening&&!State.Flag("op_greta")&&map=="village"&&State.QuestState("main")=="none")text=Tr("Volg het gesputter naar de fontein. Nelle kan je hulp gebruiken.");
   return text;
  }}
  public static string Sub(string template,params object[] values)
  {int index=0;return System.Text.RegularExpressions.Regex.Replace(template,@"%s|%d|%\.0f",m=>{if(index>=values.Length)return m.Value;object v=values[index++];return m.Value=="%.0f"?Convert.ToDouble(v,CultureInfo.InvariantCulture).ToString("0",CultureInfo.InvariantCulture):Convert.ToString(v,CultureInfo.InvariantCulture);});}
 }
}
