using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using UnityEngine;
namespace BlueMapMigration.Story
{
 public sealed class StoryEffect
 {
  public string Kind {get;} public FoundationValue Payload {get;}
  public StoryEffect(string kind,FoundationValue payload=null){Kind=kind;Payload=payload??FoundationValue.Nil();}
 }
 public sealed class StoryChoice
 {
  public string Text {get;internal set;} public int SourceIndex {get;internal set;} public FoundationValue Source {get;internal set;}
 }
 public sealed class StoryDialogue
 {
  public string Id {get;internal set;} public string Speaker {get;internal set;} public IReadOnlyList<string> Lines {get;internal set;}
  public IReadOnlyList<StoryChoice> Choices {get;internal set;} public bool ChoicesReady {get;internal set;} public bool FromData {get;internal set;}
  public FoundationValue Source {get;internal set;}
 }
 public sealed class StoryNpcContext {public double CatCalm,CatPanic;public bool CatLoud;}
 /// <summary>Original ordered story rules. Construction/import grants nothing; action batches commit before observers.</summary>
 public sealed partial class StoryModel
 {
  static FoundationValue reference,catalogs;static string oracleSha256;public static bool SourceOracleLoaded=>reference!=null;readonly FoundationWorldRepository repository;
  readonly List<StoryEffect> effects=new List<StoryEffect>();bool busy,staging,dialogueActionsDone;
  public FoundationGameState State {get;} public InventoryModel Inventory {get;} public ProgressionModel Progression {get;}
  public FoundationValue Oracle {get{if(reference==null){var asset=Resources.Load<TextAsset>("BlueMapStoryOracle");if(asset==null)throw new FormatException("Missing original story reference");string digest;using(var sha=System.Security.Cryptography.SHA256.Create())digest=BitConverter.ToString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(asset.text))).Replace("-","").ToLowerInvariant();if(digest!=oracleSha256)throw new FormatException("Original story reference differs from its exact gameplay catalog");var parsed=FoundationJson.ParsePlain(asset.text);if(parsed.Require("schema").AsString()!="bluemap.story.source-oracle.v1"||parsed.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid original story reference");reference=parsed;}return reference;}} public FoundationValue Catalogs=>catalogs;public StoryDialogue Dialogue {get;private set;}
  public StoryDialogue LastPresentedDialogue {get;private set;}
  public bool DialogueOpen=>Dialogue!=null;public bool IsExecuting=>busy;public bool ArenaActive {get;set;}public int PendingSupperStitch {get;set;}
  public string LastMessage {get;private set;}="";public Func<string,string> Translator {get;set;}=value=>value;
  public IReadOnlyList<StoryEffect> LastEffects=>effects.AsReadOnly();public Func<FoundationValue,bool> ExternalActionHandler {get;set;}
  public StoryJourney Journey {get;}
  public event Action<StoryEffect> EffectRequested;public event Action SaveRequested;public event Action Changed;public event Action DialogueChanged;
  public event Action<string> SoundRequested,Toast,ShopRequested;public event Action EndingRequested;public event Action<FoundationValue> WorldActionRequested;public event Action<string,long> ItemObtained;
  public StoryModel(FoundationWorldRepository repository,FoundationGameState state,InventoryModel inventory=null,ProgressionModel progression=null)
  {
   this.repository=repository??throw new ArgumentNullException(nameof(repository));State=state??throw new ArgumentNullException(nameof(state));Inventory=inventory??new InventoryModel(repository,state);Progression=progression??new ProgressionModel(repository,state,Inventory);
   if(!ReferenceEquals(State,Inventory.State)||!ReferenceEquals(State,Progression.State))throw new ArgumentException("Story owners must share source state");
   if(catalogs==null){var asset=Resources.Load<TextAsset>("BlueMapStoryCatalog");if(asset==null)throw new FormatException("Missing original story gameplay catalog");var source=FoundationJson.ParsePlain(asset.text);if(source.Require("schema").AsString()!="bluemap.story.catalog.v1"||source.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid story gameplay catalog");oracleSha256=source.Require("sourceOracleSha256").AsString();if(oracleSha256.Length!=64)throw new FormatException("Missing original story catalog provenance");catalogs=InventoryModelChecks.DecodeOrdered(source.Require("catalogsOrdered"));}
   Journey=new StoryJourney(repository,this);Journey.SaveRequested+=()=>{Emit("quests_changed");Emit("save_requested");};
  }
  public static FoundationValue S(string v)=>FoundationValue.StringValue(v);public static FoundationValue I(long v)=>FoundationValue.Integer(v);public static FoundationValue E()=>InventoryModel.Empty();
  public static FoundationValue G(FoundationValue d,string k,FoundationValue f)=>InventoryModel.Get(d,k,f);public static FoundationValue R(FoundationValue d,string k,FoundationValue v,bool remove=false)=>InventoryModel.Replace(d,k,v,remove);
  public static FoundationValue A(params FoundationValue[] values)=>FoundationValue.Array(values);public static long N(FoundationValue v)=>v.Kind=="int"?v.AsInt64():v.Kind=="float"?(long)v.AsDouble():0;
  public string Tr(string text)=>Translator==null?text:Translator(text);
  public string F(string source,params object[] args){string text=Tr(source);foreach(object arg in args){int a=text.IndexOf("%s",StringComparison.Ordinal),b=text.IndexOf("%d",StringComparison.Ordinal),at=a<0?b:b<0?a:Math.Min(a,b);if(at<0)break;text=text.Substring(0,at)+Convert.ToString(arg,System.Globalization.CultureInfo.InvariantCulture)+text.Substring(at+2);}return text;}
  void Emit(string kind,FoundationValue payload=null){var effect=new StoryEffect(kind,payload);effects.Add(effect);if(!staging)Deliver(effect);}
  void Deliver(StoryEffect effect)
  {
   if(effect.Kind=="dialogue_requested"&&!DialogueOpen)Enter(effect.Payload.AsString());
   if(effect.Kind=="text_dialogue_requested"&&!DialogueOpen)EnterLines("",effect.Payload.Require("speaker").AsString(),effect.Payload.Require("lines").Items.Select(v=>v.AsString()));
   EffectRequested?.Invoke(effect);
   switch(effect.Kind){case "save_requested":SaveRequested?.Invoke();break;case "toast":LastMessage=effect.Payload.AsString();Toast?.Invoke(LastMessage);break;case "sound_requested":SoundRequested?.Invoke(effect.Payload.AsString());break;case "shop_requested":ShopRequested?.Invoke(effect.Payload.AsString());break;case "ending_requested":EndingRequested?.Invoke();break;case "world_action":WorldActionRequested?.Invoke(effect.Payload);break;case "external_action":ExternalActionHandler?.Invoke(effect.Payload);break;case "item_obtained":ItemObtained?.Invoke(effect.Payload.Items[0].AsString(),N(effect.Payload.Items[1]));break;}
  }
  bool Operation(Func<bool> action){if(busy)return false;busy=true;effects.Clear();LastMessage="";try{return action();}finally{busy=false;}}
  public void ClearMessage()=>LastMessage="";
  public string QuestState(string id)=>State.QuestState(id);public long QuestStep(string id)=>State.QuestStep(id);
  public string QuestTitle(string id)=>Catalogs.Require("quests").TryGet(id,out var q)?Tr(q.Require("title").AsString()):id;
  public string QuestText(string id){if(!Catalogs.Require("quests").TryGet(id,out var q))return "";var steps=q.Require("steps").Items;if(steps.Count==0)return "";int step=(int)Math.Max(0,Math.Min(steps.Count-1,QuestStep(id)));return Format(Tr(steps[step].Require("text").AsString()));}
  public IReadOnlyList<string> QuestOrder=>Catalogs.Require("quests").Entries.Where(p=>QuestState(p.Key.AsString())=="active").Concat(Catalogs.Require("quests").Entries.Where(p=>QuestState(p.Key.AsString())=="done")).Select(p=>p.Key.AsString()).ToArray();
  public string FocusedQuest{get{foreach(var row in Catalogs.Require("quests").Entries){string id=row.Key.AsString();if(State.Flag("jr_focus_"+id)&&QuestState(id)=="active")return id;}return "";}}
  public bool ToggleFocus(string id)=>Operation(()=>{if(!Catalogs.Require("quests").TryGet(id,out _)||QuestState(id)!="active")return false;string old=FocusedQuest;var flags=State.Get("flags");foreach(var row in flags.Entries.ToArray())if(row.Key.AsString().StartsWith("jr_focus_",StringComparison.Ordinal))flags=R(flags,row.Key.AsString(),null,true);if(old!=id)flags=R(flags,"jr_focus_"+id,FoundationValue.Boolean(true));State.Set("flags",flags);Emit("quests_changed");Emit("save_requested");return true;});
  public string QuestStatusText(string id)=>Journey.QuestStatusText(id);
  public string QuestDetail(string id)=>Journey.QuestDetail(id);public string QuestTarget(string id)=>Journey.QuestTarget(id);public string RouteText(string id)=>Journey.RouteText(id);public string CompactRoute(string id)=>Journey.CompactRoute(id);public IReadOnlyList<string> Preparation(string map)=>Journey.Preparation(map);public string TrackedText=>Journey.TrackedText;public string HudTrackedText=>Journey.HudTrackedText;
  public void RefreshQuests(){RefreshQuestsCore(false);}
  void RefreshQuestsCore(bool inheritedChange){bool changed=inheritedChange;var quests=State.Get("quests");foreach(var row in quests.Entries){string id=row.Key.AsString();var q=row.Value;if(G(q,"state",S("none")).AsString()!="active"||!Catalogs.Require("quests").TryGet(id,out var info))continue;var steps=info.Require("steps").Items;long step=N(q.Require("step"));while(step>=0&&step<steps.Count-1&&steps[(int)step].TryGet("advance_if",out var tests)&&CheckAll(tests)){step++;changed=true;}if(step!=N(q.Require("step"))){quests=R(quests,id,R(q,"step",I(step)));State.Set("quests",quests);}}if(changed)Emit("quests_changed");}
  void StartDirect(string id){if(State.Get("quests").TryGet(id,out _))return;if(!Catalogs.Require("quests").TryGet(id,out _))return;State.Set("quests",R(State.Get("quests"),id,FoundationValue.Object(new Dictionary<string,FoundationValue>{{"state",S("active")},{"step",I(0)}})));Emit("toast",S(F("Nieuwe opdracht: %s",QuestTitle(id))));Emit("quests_changed");RefreshQuests();}
  void StepDirect(string id,long step){if(!State.Get("quests").TryGet(id,out var q))return;State.Set("quests",R(State.Get("quests"),id,R(q,"step",I(step))));Emit("quests_changed");RefreshQuests();}
  void FinishDirect(string id){if(!State.Get("quests").TryGet(id,out var q)||QuestState(id)=="done")return;State.Set("quests",R(State.Get("quests"),id,R(q,"state",S("done"))));Emit("toast",S(F("Opdracht voltooid: %s",QuestTitle(id))));string previousQuests=FoundationJson.StringifyPlain(State.Get("quests"));long xp=Progression.Progress.XP,coins=State.Coins;Progression.AddHeroXp(Progression.QuestXp(id));if(Progression.Progress.XP!=xp){if(State.Coins!=coins)Emit("items_changed");Emit("progression_changed");if(State.Coins!=coins)Emit("toast",S(F("Heldenlevel %d! +%d munten voor je uitrusting.",Progression.Progress.Level,State.Coins-coins)));}Emit("quests_changed");RefreshQuestsCore(previousQuests!=FoundationJson.StringifyPlain(State.Get("quests")));}
  public bool StartQuest(string id)=>Operation(()=>{StartDirect(id);return true;});public bool SetQuestStep(string id,long step)=>Operation(()=>{StepDirect(id,step);return true;});public bool FinishQuest(string id)=>Operation(()=>{FinishDirect(id);return true;});
  public bool CheckAll(FoundationValue tests){foreach(var test in tests.Items)if(!Check(test))return false;return true;}
  public bool Check(FoundationValue condition)
  {
   var c=condition.Items;if(c.Count==0)return false;string name=c[0].AsString(),id=c.Count>1&&c[1].Kind=="string"?c[1].AsString():"";long number=c.Count>1&&(c[1].Kind=="int"||c[1].Kind=="float")?N(c[1]):0;
   switch(name){case "flag":return State.Flag(id);case "no_flag":return !State.Flag(id);case "quest":return QuestState(id)==c[2].AsString();case "step":return QuestState(id)=="active"&&QuestStep(id)==N(c[2]);case "has":return State.Count(id)>=(c.Count>2?N(c[2]):1);case "lacks":return State.Count(id)<(c.Count>2?N(c[2]):1);case "coins":return State.Coins>=number;case "map":return State.MapId==id;case "weapon":return State.Weapon==id;case "crystals":return State.CrystalCount>=number;case "hurt":return State.Hp<State.MaxHp;
    case "kills":case "rolls":case "potions_drunk":return N(State.Get(name))>=number;case "max_deaths":return N(State.Get("deaths"))<=number;case "max_boss_deaths":return N(State.Get("boss_deaths"))<=number;
    case "kills_of":return N(G(State.Get("kills_by"),id,I(0)))>=N(c[2]);case "kinds_killed":return c[1].Items.All(v=>N(G(State.Get("kills_by"),v.AsString(),I(0)))>0);
    case "talked_to_all":return c[1].Items.All(v=>State.Get("talked").Items.Any(p=>p.AsString()==v.AsString()));
    case "finished_within":return State.Flag("game_completed")&&State.Get("play_time").AsDouble()<=c[1].AsDouble();case "chests_in":return c[1].Items.All(map=>State.Get("flags").Entries.Any(p=>p.Key.AsString().StartsWith("chest:"+map.AsString()+":",StringComparison.Ordinal)));
    case "any":return c.Skip(1).Any(Check);case "phase":double t=State.DayTime-Math.Floor(State.DayTime);return (t<.17||t>=.95?"ochtend":t<.52?"dag":t<.72?"avond":"nacht")==id;
    case "boog_missing":return c.Skip(1).Any(v=>!State.Flag(v.AsString()));case "echo_ready":return new[]{"iron","crystal","star"}.Contains(State.Weapon);
    case "meer_vis":return Catalogs.Require("fishOrder").Items.Any(v=>State.Count(v.AsString())>0);case "meer_vol":return N(G(State.Get("meer"),"verkocht",I(0)))>=N(Catalogs.Require("fishFullPrice"));case "meer_boeken":return BooksFound()>=number;case "meer_gelezen":return Catalogs.Require("bookTexts").Entries.Count(p=>State.Flag("meer_gelezen_"+p.Key.AsString()))>=number;
    case "arena_open":return QuestState("main")!="none"&&N(Catalogs.Require("weapons").Require(State.Weapon).Require("damage"))>=2;case "arena_registered":return RegisteredRank!="";case "arena_fight":return ArenaActive;case "arena_free":return !ArenaActive;default:return false;
   }
  }
  public bool CanRunActions(FoundationValue actions)=>actions.Kind=="array"&&actions.Items.All(a=>a.Kind=="array"&&a.Items.Count>0&&Catalogs.Require("actionNames").Items.Any(n=>n.AsString()==a.Items[0].AsString()));
  public bool RunActions(FoundationValue actions)=>Operation(()=>{RunTransaction(actions);return true;});
  public bool RunTrigger(FoundationValue conditions,string once,FoundationValue actions,bool inside=true)=>Operation(()=>{if(State.InputLocked||!inside||once!=""&&State.Flag(once)||!CheckAll(conditions))return false;var sequence=new List<FoundationValue>();if(once!="")sequence.Add(A(S("set_flag"),S(once)));sequence.AddRange(actions.Items);RunTransaction(FoundationValue.Array(sequence));return true;});
  void RunTransaction(FoundationValue actions)
  { RunSourceTransaction(stage=>{foreach(var action in actions.Items)stage.Execute(action);}); }
  void RunSourceTransaction(Action<StoryModel> mutate)
  {
   var stage=new StoryModel(repository,new FoundationGameState(State.Snapshot())){staging=true,ArenaActive=ArenaActive,Translator=Translator,PendingSupperStitch=PendingSupperStitch,ContextActionResolver=ContextActionResolver};stage.Inventory.Language=Inventory.Language;stage.Inventory.Stamina=Inventory.Stamina;stage.Inventory.StaminaCapacity=Inventory.StaminaCapacity;
   stage.Dialogue=Dialogue;stage.dialogueActionsDone=dialogueActionsDone;
   mutate(stage);
   var updates=new Dictionary<string,FoundationValue>();foreach(var row in stage.State.Fields)if(!State.Fields.TryGetValue(row.Key,out var old)||!ReferenceEquals(old,row.Value))updates[row.Key]=row.Value;
   // All fields, rewards and quest completion precede synchronous listeners; unknown profile fields remain untouched.
   PendingSupperStitch=stage.PendingSupperStitch;
   State.CommitFields(updates);Inventory.Stamina=stage.Inventory.Stamina;Inventory.StaminaCapacity=stage.Inventory.StaminaCapacity;
   foreach(var effect in stage.effects){effects.Add(effect);Deliver(effect);}Changed?.Invoke();
  }
  void SetFlagDirect(string id,bool value){State.Set("flags",R(State.Get("flags"),id,FoundationValue.Boolean(true),!value));RefreshQuests();}
  void GiveDirect(string id,long amount,bool quiet=false)
  {
   string previousQuests=FoundationJson.StringifyPlain(State.Get("quests"));long old=State.Count(id),space=Inventory.Room(id),granted=Math.Min(amount,space);bool cut=space<amount;if(cut&&granted<=0){if(!quiet)Emit("toast",S(Inventory.FullText(id)));return;}
   Inventory.Give(id,amount,true);if(id=="heart_container")Emit("hp_changed");Emit("items_changed");
   if(!quiet){string label=Tr(Inventory.ItemInfo(id).Require("name").AsString());string text=cut?granted==1?F("Gekregen: %s. %s!",label,Inventory.FullText(id)):F("Gekregen: %s x%d. %s!",label,granted,Inventory.FullText(id)):granted==1?F("Gekregen: %s",label):F("Gekregen: %s x%d",label,granted);Emit("toast",S(text));Emit("item_obtained",A(S(id),I(State.Count(id)-old)));}RefreshQuestsCore(previousQuests!=FoundationJson.StringifyPlain(State.Get("quests")));
  }
  void TakeDirect(string id,long amount){string previousQuests=FoundationJson.StringifyPlain(State.Get("quests"));string gear=FoundationJson.StringifyPlain(State.Get("equipment")),clothes=FoundationJson.StringifyPlain(State.Get("clothing"));Inventory.Take(id,amount);if(gear!=FoundationJson.StringifyPlain(State.Get("equipment"))){Emit("equipment_changed");Emit("progression_changed");}if(clothes!=FoundationJson.StringifyPlain(State.Get("clothing")))Emit("appearance_changed");Emit("items_changed");RefreshQuestsCore(previousQuests!=FoundationJson.StringifyPlain(State.Get("quests")));}
  void CoinsDirect(long amount){Inventory.AddCoins(amount);Emit("items_changed");}
  void Execute(FoundationValue action)
  {
   if(ContextActionResolver!=null&&ContextActionResolver(this,action))return;
   var a=action.Items;string name=a[0].AsString(),id=a.Count>1&&a[1].Kind=="string"?a[1].AsString():"";long amount=a.Count>2?N(a[2]):1;
   switch(name){case "start_quest":StartDirect(id);break;case "quest_step":StepDirect(id,N(a[2]));break;case "finish_quest":FinishDirect(id);break;case "set_flag":SetFlagDirect(id,true);break;case "clear_flag":SetFlagDirect(id,false);break;case "give":GiveDirect(id,amount);break;case "take":TakeDirect(id,amount);break;case "coins":CoinsDirect(N(a[1]));break;
    case "heal":State.Hp=State.MaxHp;Emit("hp_changed");Inventory.StaminaCapacity=100+Progression.Bonus("stamina_max");Inventory.Stamina=Inventory.StaminaCapacity;Emit("full_rest");break;
    case "weapon":Progression.SetWeapon(id);Emit("items_changed");Emit("toast",S(F("Nieuw zwaard: %s",Tr(Catalogs.Require("weapons").Require(id).Require("name").AsString()))));break;
    case "toast":Emit("toast",S(Tr(id)));break;case "sound":Emit("sound_requested",S(id));break;case "shop":Emit("shop_requested",S(id));break;case "save":Emit("save_requested");break;case "ending":Emit("ending_requested");break;case "boss_start":case "music":case "lock_arena":Emit("world_action",action);break;
    case "sell_all":long count=State.Count(id);if(count>0){CoinsDirect(count*N(G(Inventory.ItemInfo(id),"sell",I(1))));TakeDirect(id,count);Emit("toast",S(F("Verkocht: %d x %s",count,Tr(Inventory.ItemName(id)))));}break;
    case "talk":Emit("dialogue_requested",S(id));break;case "boog_progress":int done=a.Skip(1).Count(v=>State.Flag(v.AsString()));Emit("toast",S(done>=a.Count-1?Tr("Alle doelwitten geraakt!"):F("Doelwit geraakt! (%d van %d)",done,a.Count-1)));break;
    case "meer_verkoop":SellFish();break;case "arena_enter":RegisterArena(id);break;case "arena_cancel":CancelArena();break;
    default:if(Catalogs.Require("actionNames").Items.Any(n=>n.AsString()==name))Emit("external_action",action);break;
   }
  }
  long BooksFound()=>new[]{"meer_boek_eiland","meer_boek_hut","meer_boek_sanne"}.Count(id=>State.Count(id)>0);
  public long FishSaleValue(){long nth=N(G(State.Get("meer"),"verkocht",I(0))),coins=0;bool cap=State.Count("fishers_cap")>0;foreach(var fish in Catalogs.Require("fishOrder").Items){string id=fish.AsString();for(long i=0;i<State.Count(id);i++){double value=N(Catalogs.Require("fish").Require(id).Require("sell"));if(nth>=N(Catalogs.Require("fishFullPrice")))value*=.5;long price=Math.Max(1,(long)Math.Floor(value+.5));if(cap)price+=Math.Max(1,(long)Math.Floor(price*Catalogs.Require("fishCapBonus").AsDouble()+.5));coins+=price;nth++;}}return coins;}
  void SellFish(){long coins=FishSaleValue(),amount=0;foreach(var fish in Catalogs.Require("fishOrder").Items){string id=fish.AsString();long n=State.Count(id);if(n<=0)continue;amount+=n;TakeDirect(id,n);}if(amount==0)return;CoinsDirect(coins);State.Set("meer",R(State.Get("meer"),"verkocht",I(N(G(State.Get("meer"),"verkocht",I(0)))+amount)));Emit("sound_requested",S("buy"));Emit("toast",S(F("Verkocht: %s voor %s",F(amount==1?"%d vis":"%d vissen",amount),F(coins==1?"%d munt":"%d munten",coins))));}
  public string RegisteredRank=>Catalogs.Require("arenaOrder").Items.Select(v=>v.AsString()).FirstOrDefault(rank=>State.Flag("arena_signed_"+rank))??"";
  void RegisterArena(string rank){if(!Catalogs.Require("arenaRanks").TryGet(rank,out var info)||ArenaActive)return;if(RegisteredRank!=""){Emit("toast",S(Tr("Je staat al ingeschreven. Loop maar naar de arenadeur!")));return;}var order=Catalogs.Require("arenaOrder").Items.Select(v=>v.AsString()).ToList();int index=order.IndexOf(rank);if(index>0&&!State.Flag("arena_"+order[index-1]+"_done")){Emit("toast",S(Tr("Die rang is nog niet open. Win eerst de vorige.")));return;}long fee=N(info.Require("fee"));if(State.Coins<fee){Emit("toast",S(F("Je hebt niet genoeg munten (%d nodig).",fee)));Emit("sound_requested",S("error"));return;}CoinsDirect(-fee);SetFlagDirect("arena_signed_"+rank,true);Emit("sound_requested",S("buy"));Emit("toast",S(F("Ingeschreven voor %s! Loop door de deur naar de arena.",Tr(info.Require("name").AsString()))));}
  void CancelArena(){string rank=RegisteredRank;if(rank==""||ArenaActive)return;CoinsDirect(N(Catalogs.Require("arenaRanks").Require(rank).Require("fee")));SetFlagDirect("arena_signed_"+rank,false);Emit("toast",S(Tr("Je bent uitgeschreven. Je krijgt je munten terug.")));}
  public string Format(string text){text=(text??"").Replace("{crystals}",State.CrystalCount.ToString()).Replace("{gel}",State.Count("gel").ToString()).Replace("{shards}",State.Count("shard").ToString()).Replace("{coins}",State.Coins.ToString()).Replace("{boeken}",BooksFound().ToString()).Replace("{visgeld}",FishSaleValue().ToString());string title=Tr("nieuwkomer");foreach(var rank in Catalogs.Require("arenaOrder").Items.Reverse()){string id=rank.AsString();if(State.Flag("arena_"+id+"_done")){title=Tr(Catalogs.Require("arenaRanks").Require(id).Require("title").AsString());break;}}text=text.Replace("{arena_title}",title);foreach(var rank in Catalogs.Require("arenaOrder").Items){string id=rank.AsString();double value=G(State.Get("arena_records"),id,FoundationValue.Number(0)).AsDouble();long rounded=(long)Math.Floor(value+.5);text=text.Replace("{arena_best_"+id+"}",value>0?(rounded/60)+":"+(rounded%60).ToString("00"):Tr("nog niet gehaald"));}return text.Replace("{ls_stitch}",(PendingSupperStitch+1).ToString());}
 }
}
