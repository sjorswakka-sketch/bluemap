using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Residents
{
 public sealed class ResidentSupperObject
 {
  public string Kind; public string MapId="";public Vector2 Position;public bool Alive=true;public double Time,Progress; public bool Pulling,Visible=true,Interactable=true;
  public Vector2 Origin; public long Health; public int Stitch;
 }
 public sealed class ResidentKitchen
 {
  public bool Active,Working;public string Dish="",Result="";public int Stage;public double Elapsed;
  internal ResidentSupperObject Source;
 }
 public sealed class ResidentVillageActivity
 {
  public double Time,Hammer=2,Drip=1,GardenerTime,CourierTime;public bool Flowing;
  public string Gardener="",Courier="";public Vector2 GardenerPosition=new Vector2(560,368);
 }
 /// <summary>Original resident memories and optional village supper. Constructors never grant rewards, normalize a save, or load the large verification oracle.</summary>
 public sealed class ResidentSocialModel
 {
  static FoundationValue catalogs,reference;static string sourceSha;
  readonly FoundationWorldRepository repository;
  public StoryModel Story {get;}public FoundationGameState State=>Story.State;
  public FoundationValue Catalogs=>catalogs;public static bool SourceOracleLoaded=>reference!=null;
  public FoundationValue Oracle {get{if(reference==null){var asset=Resources.Load<TextAsset>("BlueMapResidentSocialOracle");if(asset==null)throw new FormatException("Missing resident social source oracle");string digest;using(var sha=System.Security.Cryptography.SHA256.Create())digest=BitConverter.ToString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(asset.text))).Replace("-","").ToLowerInvariant();if(digest!=sourceSha)throw new FormatException("Resident social oracle does not match its catalog");reference=FoundationJson.ParsePlain(asset.text);if(reference.Require("schema").AsString()!="bluemap.resident-social.source-oracle.v1"||reference.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid resident social source oracle");}return reference;}}
  public ResidentSupperObject Object {get;private set;}public ResidentKitchen Kitchen {get;private set;}public ResidentVillageActivity Village {get;private set;}
  public Vector2 ObjectPosition {get=>Object?.Position??Vector2.zero;set{if(Object!=null)Object.Position=value;}}
  public Vector2 PlayerPosition {get;set;}=new Vector2(0,38);public bool PlayerLoud {get;set;}
  public ResidentSupperObject PendingSource {get;private set;}public bool Pending=>PendingSource!=null;public bool SourceAlive {get=>Object!=null&&Object.Alive;set{if(Object!=null)Object.Alive=value;}}
  public event Action KitchenChanged;public event Action PresentationChanged;
  public ResidentSocialModel(FoundationWorldRepository repository,StoryModel story)
  {
   this.repository=repository??throw new ArgumentNullException(nameof(repository));Story=story??throw new ArgumentNullException(nameof(story));
   if(catalogs==null){var asset=Resources.Load<TextAsset>("BlueMapResidentSocialCatalog");if(asset==null)throw new FormatException("Missing resident social gameplay catalog");var root=FoundationJson.ParsePlain(asset.text);if(root.Require("schema").AsString()!="bluemap.resident-social.catalog.v1"||root.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid resident social gameplay catalog");sourceSha=root.Require("sourceOracleSha256").AsString();if(sourceSha.Length!=64)throw new FormatException("Missing resident social provenance");catalogs=InventoryModelChecks.DecodeOrdered(root.Require("catalogsOrdered"));}
  }
  internal static FoundationValue S(string v)=>StoryModel.S(v);internal static FoundationValue I(long v)=>StoryModel.I(v);internal static FoundationValue B(bool v)=>FoundationValue.Boolean(v);internal static FoundationValue D(double v)=>FoundationValue.Number(v);internal static FoundationValue E()=>StoryModel.E();internal static FoundationValue G(FoundationValue d,string k,FoundationValue f)=>StoryModel.G(d,k,f);internal static FoundationValue R(FoundationValue d,string k,FoundationValue v,bool remove=false)=>StoryModel.R(d,k,v,remove);internal static long N(FoundationValue v)=>StoryModel.N(v);
  public string Tr(string value)=>Story.Tr(value);string F(string text,params object[] args)=>Story.F(text,args);
  public void SetLanguage(string language){bool changed=Story.Inventory.Language!=language;Story.Inventory.Language=language;Story.Translator=t=>G(Catalogs.Require("translations").Require(language),t,S(t)).AsString();Story.Inventory.Translator=Story.Translator;if(changed&&Village!=null){Village.GardenerTime=0;Village.CourierTime=0;}}
  public IReadOnlyList<string> Roles=>Catalogs.Require("roles").Entries.Select(v=>v.Key.AsString()).ToArray();
  public FoundationValue Place(string role)=>Catalogs.Require("roles").Require(role);
  public bool Enabled(string role)=>State.Flag(Place(role).Require("flag").AsString());
  public string Name(string role)=>Tr(Place(role).Require("name").AsString());
  public string Introduction(string role)=>Tr(Place(role).Require("introduction").AsString());
  public string Activity(string role,bool resting)=>Tr(Place(role).Require(resting?"restText":"workText").AsString());
  public string Connection(string role)
  {
   int at=0;switch(role){case "miner":at=State.Flag("lw_workshop")?1:0;break;case "gardener":at=State.Flag("lw_bridge")?1:0;break;case "hearth":case "lamplighter":at=State.Flag("ra_rope")?1:0;break;case "carrier":case "reader":at=State.Flag("ra_exhibit_routes")?2:State.Flag("ra_archive_done")?1:0;break;case "caravan":at=State.Flag("ra_water_wild")?1:0;break;case "courier":at=State.Count("gear_pg_pack_plus")>0?1:0;break;}return Tr(Place(role).Require("connections").Items[at].AsString());
  }
  public static string PhaseAt(double time){time=Wrap(time);return time<.17||time>=.95?"ochtend":time<.52?"dag":time<.72?"avond":"nacht";}
  static double Wrap(double time){double v=time%1;if(v<0)v+=1;return v+0.0;}
  public static bool Raining(string weather,long day,double time){if(weather=="rain")return true;if(weather!="random")return false;long slot=Math.Min((long)(Wrap(time)*6),5);if(day==0&&slot==0)return false;unchecked{long n=day*6+slot,h=n*73856093L^((n+17)*19349663L);h=(h^(h>>13))*1274126177L;return ((h^(h>>16))&0x7fffffffL)%100<33;}}
  public bool Resting(string weather)=>PhaseAt(State.DayTime)=="avond"||PhaseAt(State.DayTime)=="nacht"||Raining(weather,State.DayCount,State.DayTime)||(weather=="heat"&&State.DayTime>=.3&&State.DayTime<.52);
  public static bool VillageDark(double rawTime)=>rawTime>.78||rawTime<.12;
  public IReadOnlyList<string> Lines(string role,string weather)=>new[]{State.Flag("wm_met_"+role)?Tr(Place(role).Require("returnText").AsString()):Introduction(role),Activity(role,Resting(weather)),Connection(role)};
  public bool Meet(string role)=>Story.ApplySourceBatch(stage=>{if(stage.State.Flag("wm_met_"+role))return;stage.SourceFlag("wm_met_"+role);stage.SourceEmit("save_requested");});
  public IReadOnlyList<string> News()
  {
   var result=new List<string>{Tr("Dit boek wordt bijgehouden door reizigers. Herstelde plekken krijgen opnieuw bewoners. Ga gerust overdag of in de avond langs.")};foreach(string role in Roles)if(Enabled(role))result.Add(F("%s — %s. %s",Tr(Place(role).Require("mapName").AsString()),Name(role),Tr(State.Flag("wm_met_"+role)?"Al ontmoet; het werk gaat verder.":"Nieuwe ontmoeting na je herstel.")));if(result.Count==1)result.Add(Tr("De eerste berichten komen wanneer je de lichtkern, de tuin, een huis, een bron, een brug, het archief of de klimlijn herstelt."));return result.AsReadOnly();
  }
  public bool TalkMemory(string role,string weather,double distance){if(State.InputLocked||distance>40)return false;var speech=Lines(role,weather);return Story.ApplySourceBatch(stage=>{if(!stage.State.Flag("wm_met_"+role)){stage.SourceFlag("wm_met_"+role);stage.SourceEmit("save_requested");}Say(stage,Name(role),speech);});}
  public bool ReadBook(double distance){if(State.InputLocked||distance>40)return false;return Story.ApplySourceBatch(stage=>{stage.SourceEmit("sound_requested",S("wm_page"));Say(stage,Tr("Het reizigersboek"),News());});}
  static void Say(StoryModel stage,string name,IEnumerable<string> lines)=>stage.SourceEmit("text_dialogue_requested",FoundationValue.Object(new Dictionary<string,FoundationValue>{{"speaker",S(name)},{"lines",FoundationValue.Array(lines.Select(S))}}));
  public bool OpeningEnabled=>State.Flag("op_new_adventure")&&N(State.Get("ng_plus"))==0;
  public bool Flowing=>!OpeningEnabled||State.Flag("op_water");public bool QuietHud=>OpeningEnabled&&!State.Flag("op_greta")&&State.MapId=="village"&&State.QuestState("main")=="none";
  public void StartVillage(){Village=new ResidentVillageActivity{Flowing=Flowing};}
  public void TickVillage(double delta,bool sprintPressed)
  {
   if(Village==null)return;Village.Time+=delta;Village.Hammer-=delta;bool flowing=Flowing;if(!flowing){Village.Drip-=delta;if(Village.Drip<=0)Village.Drip=3.5;}if(flowing!=Village.Flowing){Village.Flowing=flowing;Village.Gardener=Tr("Daar is het water!");Village.GardenerTime=5;Village.Courier=Tr("Dat scheelt een tocht naar het meer!");Village.CourierTime=5;}if(Village.Hammer<=0)Village.Hammer=3.5;if(QuietHud)Story.ApplySourceBatch(stage=>{if(sprintPressed)stage.SourceFlag("op_sprint_seen");if(Vector2.Distance(PlayerPosition,Village.GardenerPosition)<160&&!stage.State.Flag("op_greeting")){stage.SourceFlag("op_greeting");Village.Gardener=stage.Tr("Even helpen? De fontein zit verstopt.");Village.GardenerTime=6;}});PresentationChanged?.Invoke();
  }
  public void MigrateLegacyWorld()
  {
   var flags=State.Get("flags");var quests=State.Get("quests");if(State.Flag("lw_drained")||State.QuestState("wilgentwijgen")=="done"){flags=R(flags,"lw_sluice_west",B(true));flags=R(flags,"lw_sluice_east",B(false));flags=R(flags,"lw_sluice_west_seen",B(true));flags=R(flags,"lw_sluice_east_seen",B(true));}
   if(!State.Flag("lw_revision_1")){if(State.QuestState("warmte")=="done")foreach(string id in new[]{"lw_heat_west","lw_heat_east","lw_heat"})flags=R(flags,id,B(true));else if(State.QuestState("warmte")=="active")quests=R(quests,"warmte",R(quests.Require("warmte"),"step",I(0)));if(State.QuestState("wilgentwijgen")=="done")foreach(string id in new[]{"lw_drained","lw_bridge","lw_tailoring"})flags=R(flags,id,B(true));else if(State.QuestState("wilgentwijgen")=="active")quests=R(quests,"wilgentwijgen",R(quests.Require("wilgentwijgen"),"step",I(0)));flags=R(flags,"lw_revision_1",B(true));}State.CommitFields(new Dictionary<string,FoundationValue>{{"flags",flags},{"quests",quests}});
  }
  public FoundationValue Inputs(string dish)=>State.Count("ls_crate")>0?FoundationValue.Object(new Dictionary<string,FoundationValue>{{"ls_crate",I(1)}}):dish=="ls_chowder"?FoundationValue.Object(new Dictionary<string,FoundationValue>{{"meer_baars",I(2)},{"prof_herb",I(1)}}):FoundationValue.Object(new Dictionary<string,FoundationValue>{{"meer_baars",I(1)},{"prof_berry",I(2)}});
  public bool ValidDish(string dish)=>dish=="ls_chowder"||dish=="ls_broth";
  public string CookReason(string dish){if(!ValidDish(dish)||State.MapId!="inn")return Tr("Kook bij Mila's fornuis in de herberg.");if(!State.Flag("ls_basket"))return Tr("Haal eerst Joris' maaltijdmand bij de middelste steiger op.");foreach(var row in Inputs(dish).Entries)if(State.Count(row.Key.AsString())<N(row.Value))return F("Nog nodig: %s",Tr(Story.Inventory.ItemInfo(row.Key.AsString()).Require("name").AsString()));return "";}
  public bool Cook(string dish)
  {
   if(CookReason(dish)!="")return false;var ingredients=Inputs(dish);return Story.ApplySourceBatch(stage=>{foreach(var row in ingredients.Entries)stage.SourceTake(row.Key.AsString(),N(row.Value));stage.SourceGive(dish,ingredients.TryGet("ls_crate",out _)?2:1,true);AddProfessionXp(stage,"cooking",12);stage.SourceFlag("ls_cooked");stage.SourceStart("ls_supper");stage.SourceEmit("save_requested");});
  }
  public string Tracker=>((State.MapId=="lake"||State.MapId=="inn")&&State.QuestState("ls_supper")=="active")?(State.Flag("ls_cooked")&&State.Count("ls_chowder")+State.Count("ls_broth")==0?Tr("Alle porties opgegeten? Kook opnieuw met baars en zilverkruid of bessen. Joris' nettenrek levert een reservevangst op."):Story.QuestText("ls_supper")):"";
  public IReadOnlyList<string> Conversation(string role){var lines=new List<string>();var source=Story.Catalogs.Require("supperLines");if(source.TryGet(role,out var text))lines.AddRange(text.Items.Select(v=>Tr(v.AsString())));foreach(string flag in new[]{"op_water","cat_found","rf_memorial"})if(State.Flag(flag))lines.AddRange(source.Require(flag).Items.Select(v=>Tr(v.AsString())));return lines.AsReadOnly();}
  public string ObjectLabel(string kind)=>Tr(kind=="basket"?"Losgeraakte vismand":kind=="net"?"Joris' nettenrek":kind=="stove"?"Mila's fornuis":kind=="table"?"De dorpstafel":"Een plek aan tafel");
  public void BindObject(ResidentSupperObject value){Object=value;if(value!=null)value.Alive=true;}
  public void SetObject(string kind){if(Object!=null)Object.Alive=false;Object=new ResidentSupperObject{Kind=kind};SourceAlive=true;PendingSource=null;Story.PendingSupperStitch=0;if(kind=="basket"&&State.Flag("ls_basket")){Object.Visible=false;Object.Interactable=false;}PresentationChanged?.Invoke();}
  public void SetPending(bool value){PendingSource=value&&Object!=null&&SourceAlive?Object:null;Story.PendingSupperStitch=Pending?PendingSource.Stitch:0;}
  public void RemoveObject(){SourceAlive=false;if(ReferenceEquals(PendingSource,Object))PendingSource=null;Object=null;}
  public bool InteractObject()
  {
   var obj=Object;if(obj==null||!SourceAlive||State.InputLocked||obj.Pulling)return false;
   switch(obj.Kind){case "notice":return Story.ApplySourceBatch(stage=>stage.SourceEmit("dialogue_requested",S("ls_invite")));case "basket":if(State.Flag("ls_basket"))return false;if(State.Count("fishing_rod")==0)return Story.ApplySourceBatch(stage=>Say(stage,ObjectLabel(obj.Kind),new[]{Tr("De mand zit vast tussen de palen. Leen een hengel van Joris en haal hem vanaf de steiger rustig naar je toe.")}));if(!Story.ApplySourceBatch(stage=>{stage.SourceStart("ls_supper");stage.SourceEmit("toast",S(Tr("De lijn zit vast. Blijf even staan om de mand binnen te halen.")));}))return false;obj.Pulling=true;obj.Progress=0;obj.Origin=PlayerPosition;obj.Health=State.Hp;break;
    case "net":if(State.Flag("ls_net"))return Story.ApplySourceBatch(stage=>Say(stage,ObjectLabel(obj.Kind),new[]{Tr("Het net is weer heel. Joris kan zijn vangst nu veilig bewaren.")}));SetPending(true);return Story.ApplySourceBatch(stage=>stage.SourceEmit("dialogue_requested",S("ls_net")));
    case "stove":return OpenKitchen();case "table":if(State.Flag("ls_served"))return Story.ApplySourceBatch(stage=>Say(stage,ObjectLabel(obj.Kind),new[]{Tr("De tafel blijft gedekt. Jouw gerecht staat op Mila's kaart. Met verse baars kun je bij het fornuis opnieuw koken; de recepten staan ook bij Beroepen.")}));if(!State.Flag("ls_cooked")||State.Count("ls_chowder")+State.Count("ls_broth")==0)return Story.ApplySourceBatch(stage=>{stage.SourceStart("ls_supper");Say(stage,ObjectLabel(obj.Kind),new[]{Tr("Hier komt iedereen samen zodra het eten klaar is. Bereid een portie bij het fornuis links van de eetkamer. De maaltijd kan op elk moment beginnen.")});});SetPending(true);return Story.ApplySourceBatch(stage=>stage.SourceEmit("dialogue_requested",S("ls_share")));}
   PresentationChanged?.Invoke();return true;
  }
  public void TickObject(double delta)
  {
   var obj=Object;if(obj==null||!SourceAlive)return;obj.Time+=delta;if(!obj.Pulling)return;if(State.InputLocked||Vector2.Distance(PlayerPosition,obj.Origin)>8||State.Hp<obj.Health||PlayerLoud){obj.Pulling=false;obj.Progress=0;PresentationChanged?.Invoke();return;}obj.Progress+=delta;if(obj.Progress<1.8)return;obj.Pulling=false;if(!State.Flag("ls_basket"))Story.ApplySourceBatch(stage=>{stage.SourceFlag("ls_basket");stage.SourceGive("ls_crate",1);stage.SourceEmit("save_requested");stage.SourceEmit("sound_requested",S("ls_reel"));stage.SourceEmit("toast",S(Tr("De vangst is gered! Breng de maaltijdmand naar Mila's fornuis in de herberg.")));});obj.Interactable=false;obj.Visible=false;PresentationChanged?.Invoke();
  }
  public bool Weave(string side){if(Story.IsExecuting||Object==null||!SourceAlive)return false;Story.PendingSupperStitch=Object.Stitch;bool ok=Story.ApplySourceBatch(stage=>WeaveStaged(stage,side));if(ok){Object.Stitch=Story.PendingSupperStitch;PresentationChanged?.Invoke();}return ok;}
  void WeaveStaged(StoryModel stage,string side)
  {
   if(stage.State.Flag("ls_net"))return;int stitch=stage.PendingSupperStitch;if(stitch<0||stitch>=3)throw new InvalidOperationException("Invalid original net stitch");if(side!=new[]{"over","under","over"}[stitch]){stage.PendingSupperStitch=0;stage.SourceEmit("toast",S(stage.Tr("De draad schiet los. Volg opnieuw: boven, onder, boven.")));return;}stage.PendingSupperStitch=stitch+1;stage.SourceEmit("sound_requested",S("ls_chop"));if(stage.PendingSupperStitch==3){stage.SourceFlag("ls_net");stage.SourceGive("meer_baars",2,true);stage.SourceGive("prof_herb",1,true);AddProfessionXp(stage,"fishing",8);stage.SourceEmit("save_requested");}
  }
  public bool Share(string dish)=>Story.ApplySourceBatch(stage=>ShareStaged(stage,dish));
  void ShareStaged(StoryModel stage,string dish)
  {
   if(stage.State.Flag("ls_served")||!stage.State.Flag("ls_cooked")||!ValidDish(dish)||stage.State.Count(dish)<1)return;stage.SourceFlag("ls_served");stage.SourceFlag("ls_favorite_broth",dish=="ls_broth");stage.SourceTake(dish,1);stage.SourceStart("ls_supper");stage.SourceFinish("ls_supper");stage.SourceEmit("sound_requested",S("ls_serve"));stage.SourceEmit("toast",S(stage.Tr("Er is een plek voor iedereen. Praat met de gasten; beide recepten zijn nu blijvend beschikbaar.")));stage.SourceEmit("save_requested");
  }
  /// <summary>Hook invoked inside the StoryModel stage, before the next dialogue branch is evaluated. Never touches live actors or UI.</summary>
  public bool ResolveStagedAction(StoryModel stage,FoundationValue action)
  {
   string op=action.Items[0].AsString();if(op!="ls_weave"&&op!="ls_share")return false;var source=PendingSource;if(source==null||!source.Alive||Vector2.Distance(PlayerPosition,source.Position)>66)return true;string arg=action.Items[1].AsString();if(op=="ls_weave"&&source.Kind=="net")WeaveStaged(stage,arg);if(op=="ls_share"&&source.Kind=="table")ShareStaged(stage,arg);return true;
  }
  public void SynchronizePendingStitch(){var source=PendingSource??Object;if(source!=null&&source.Alive)source.Stitch=Story.PendingSupperStitch;PresentationChanged?.Invoke();}
  public bool RunContextAction(FoundationValue action){if(Story.IsExecuting)return false;bool result=Story.ApplySourceBatch(stage=>ResolveStagedAction(stage,action));SynchronizePendingStitch();return result;}
  public bool OpenKitchen(){if(Kitchen==null)Kitchen=new ResidentKitchen();if(Kitchen.Active||State.InputLocked||Object==null||!SourceAlive)return false;Kitchen.Source=Object;Kitchen.Active=true;Kitchen.Stage=0;Kitchen.Working=false;Kitchen.Dish="";Kitchen.Result="";State.SetUi("supper_kitchen",true);KitchenChanged?.Invoke();return true;}
  public void SelectDish(string dish){if(Kitchen==null||Kitchen.Working)return;Kitchen.Dish=dish;Kitchen.Stage=0;Kitchen.Result="";KitchenChanged?.Invoke();}
  public bool Prepare(){if(Kitchen==null||!Kitchen.Active||Kitchen.Working||Kitchen.Dish==""||CookReason(Kitchen.Dish)!="")return false;Kitchen.Working=true;Kitchen.Elapsed=0;Story.ApplySourceBatch(stage=>stage.SourceEmit("sound_requested",S(new[]{"ls_chop","ls_simmer","ls_serve"}[Kitchen.Stage])));KitchenChanged?.Invoke();return true;}
  public void TickKitchen(double delta)
  {
   if(Kitchen==null||!Kitchen.Active)return;if(Kitchen.Source==null||!Kitchen.Source.Alive||State.MapId!="inn"||Vector2.Distance(PlayerPosition,Kitchen.Source.Position)>66){CloseKitchen();return;}if(!Kitchen.Working)return;Kitchen.Elapsed+=delta;if(Kitchen.Elapsed<.9)return;Kitchen.Working=false;Kitchen.Stage++;if(Kitchen.Stage==3){Kitchen.Result=Cook(Kitchen.Dish)?Tr("Klaar! Deel één portie aan de dorpstafel of neem je gerecht mee. Je ingrediënten zijn verwerkt."):CookReason(Kitchen.Dish);Kitchen.Dish="";Kitchen.Stage=0;}KitchenChanged?.Invoke();
  }
  public void CloseKitchen(){if(Kitchen==null)return;Kitchen.Active=false;Kitchen.Working=false;State.SetUi("supper_kitchen",false);KitchenChanged?.Invoke();}
  public void AddProfessionXp(string skill,long amount)=>Story.ApplySourceBatch(stage=>AddProfessionXp(stage,skill,amount));
  public void AddProfessionXp(StoryModel stage,string skill,long amount)
  {
   if(!Catalogs.Require("skills").TryGet(skill,out var skillInfo)||amount<=0)return;var professions=stage.State.Get("professions");if(!professions.TryGet("xp",out _)||!professions.TryGet("cooldowns",out _))professions=NormalizeProfessions(professions,stage.State.PlayTime);var xp=professions.Require("xp");long previous=N(G(xp,skill,I(0))),oldLevel=ProfessionLevel(previous),next=previous+Math.Min(amount,1350-previous);xp=R(xp,skill,I(next));stage.SourceSetField("professions",R(professions,"xp",xp));if(next==previous)return;stage.SourceEmit("progression_changed");long level=ProfessionLevel(next);if(level>oldLevel)stage.SourceEmit("toast",S(stage.F("%s: niveau %d!",stage.Tr(skillInfo.Require("name").AsString()),level)));
  }
  static long ProfessionLevel(long xp){long level=1;while(level<10&&xp>=15*level*(level+1))level++;return level;}
  public FoundationValue NormalizeProfessions(FoundationValue raw,double clock)
  {
   var result=FoundationValue.Object(new Dictionary<string,FoundationValue>{{"xp",E()},{"cooldowns",E()}});if(raw.Kind!="object"&&raw.Kind!="dictionary")return result;if(raw.TryGet("goal",out var goal)&&goal.Kind=="string"&&Catalogs.Require("recipes").Items.Any(v=>v.AsString()==goal.AsString()))result=R(result,"goal",goal);var xp=E();var input=G(raw,"xp",E());if(input.Kind=="object"||input.Kind=="dictionary")foreach(var row in Catalogs.Require("skills").Entries){var value=G(input,row.Key.AsString(),I(0));if(value.Kind=="int"||value.Kind=="float")xp=R(xp,row.Key.AsString(),I(Math.Max(0,Math.Min(1350,N(value)))));}var cooldown=E();if(raw.TryGet("cooldowns",out input)&&(input.Kind=="object"||input.Kind=="dictionary")){foreach(var id in Catalogs.Require("legacyCooldowns").Items){string key=id.AsString();if(input.TryGet(key,out var value)&&(value.Kind=="int"||value.Kind=="float")&&value.AsDouble()>clock)cooldown=R(cooldown,key,D(Math.Min(value.AsDouble(),clock+Catalogs.Require("cooldowns").Require(key).AsDouble())));}foreach(var row in input.Entries){string key=row.Key.AsString();if(!(key.StartsWith("trail:",StringComparison.Ordinal)||key.StartsWith("winter:",StringComparison.Ordinal)||key.StartsWith("forestfood:",StringComparison.Ordinal))||!Catalogs.Require("cooldowns").TryGet(key,out var limit))continue;var value=row.Value;if((value.Kind=="int"||value.Kind=="float")&&value.AsDouble()>clock&&limit.AsDouble()>0)cooldown=R(cooldown,key,D(Math.Min(value.AsDouble(),clock+limit.AsDouble())));}}result=R(result,"xp",xp);return R(result,"cooldowns",cooldown);
  }
 }
}
