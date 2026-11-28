using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Completion;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// The end of the main story and what follows: the epilogue with your numbers and the credits, what the game
 /// remembers of a finished round, and New Game+ with your best gear against stronger enemies.
 /// Rules follow GameState.record_completion, _merge_gear and new_game_plus.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  public const long NgStartCoins=100;
  public EndingPanel Ending {get;private set;}
  /// <summary>The opening pages shown when a new adventure starts.</summary>
  public EndingPanel Intro {get;private set;}
  LegacySaveImporter completionRules;
  LegacySaveImporter CompletionRules=>completionRules??(completionRules=new LegacySaveImporter(repository));
  void InitializeCompletion(){Ending=new EndingPanel(Catalog,Translate,T,BindingLabel);Ending.Finished+=FinishEnding;Intro=new EndingPanel(Catalog,Translate,T,BindingLabel);Intro.Finished+=FinishIntro;}
  void DetachCompletion(){Ending?.Close();Ending=null;Intro?.Close();Intro=null;}
  void TickCompletion(double delta){if(Modal=="victory"&&Ending!=null&&Ending.IsOpen)Ending.Tick(delta);if(Modal=="intro"&&Intro!=null&&Intro.IsOpen)Intro.Tick(delta);}
  void PlayMapMusic(){if(Session?.Current!=null)World.PlayRouteMusic(Session.Current.MapData.TryGet("music",out var music)?music.AsString():"village");}
  void FinishIntro(){CloseModal();PlayMapMusic();}
  /// <summary>The opening pages of a new adventure; the legend of the Blue Map in New Game+.</summary>
  public bool OpenIntro()
  {
   if(!Running||Intro==null)return false;SetModal("intro");Intro.OpenIntro(Gameplay.State.Get("ng_plus").AsInt64());Intro.NotifyOpened(storyInput);World.PlayRouteMusic("temple");return true;
  }
  void FinishEnding(){CloseModal();if(Session?.Current!=null)World.PlayRouteMusic(Session.Current.MapData.TryGet("music",out var music)?music.AsString():"village");ShowMessage(Translate("Je voortgang is bewaard: je kunt verder in het dorp."));}
  static long Whole(FoundationValue source,string key,long fallback=0){return source!=null&&source.TryGet(key,out var value)&&(value.Kind=="int"||value.Kind=="float")?(long)value.AsDouble():fallback;}
  static bool Truth(FoundationValue source,string key){return source!=null&&source.TryGet(key,out var value)&&value.Kind=="bool"&&value.AsBool();}
  static string FormatPlayTime(double seconds){long total=(long)Math.Max(0,seconds);return total/3600+":"+((total/60)%60).ToString("00")+":"+(total%60).ToString("00");}
  /// <summary>Your adventure in numbers, as the ending shows it.</summary>
  public IReadOnlyList<(string label,string value)> AdventureStats()
  {
   var state=Gameplay.State;var weapons=Progression.Catalogs.Require("weapons");string weapon=state.Get("weapon").AsString();
   string weaponName=weapons.TryGet(weapon,out var data)?Translate(StoryModel.G(data,"name",StoryModel.S(weapon)).AsString()):weapon;
   var quests=state.Get("quests");int done=quests.Entries.Count(row=>row.Value.TryGet("state",out var s)&&s.Kind=="string"&&s.AsString()=="done"),all=Progression.Catalogs.Require("quests").Entries.Count;
   return new List<(string,string)>{
    (Translate("Speeltijd"),FormatPlayTime(state.Get("play_time").AsDouble())),(Translate("Verslagen vijanden"),state.Get("kills").AsInt64().ToString()),
    (Translate("Munten"),state.Coins.ToString()),(Translate("Zwaard"),weaponName),(Translate("Hartjes"),Gameplay.MaxHp.ToString()),
    (Translate("Opdrachten voltooid"),Farm.Format(Translate("%d van %d"),done,all))};
  }
  /// <summary>What the game remembers of finished rounds; null without a profile.</summary>
  public static FoundationValue NgMetaOf(PersistenceCoordinator coordinator)=>coordinator?.NgMeta;
  public static bool NgPlusAvailable(PersistenceCoordinator coordinator)=>Truth(coordinator?.NgMeta,"completed");
  /// <summary>Your best sword, hearts, boots, experience and gear: never less than what was already kept.</summary>
  public FoundationValue MergedNgMeta(FoundationValue meta)
  {
   var state=Gameplay.State;var rules=CompletionRules;var weapons=Progression.Catalogs.Require("weapons");var inventory=state.Get("inventory");
   string kept=meta!=null&&meta.TryGet("weapon",out var w)&&w.Kind=="string"&&weapons.TryGet(w.AsString(),out _)?w.AsString():"wood",current=state.Get("weapon").AsString();
   if(weapons.TryGet(current,out var mine)&&mine.Require("damage").AsInt64()>weapons.Require(kept).Require("damage").AsInt64())kept=current;
   var gear=rules.NormalizeOwned(meta!=null&&meta.TryGet("gear_items",out var owned)?owned:InventoryModel.Empty());
   foreach(var row in rules.NormalizeOwned(inventory).Entries)gear=InventoryModel.Replace(gear,row.Key.AsString(),row.Value);
   long xp=Math.Max(LegacySaveImporter.NormalizeHeroXp(meta!=null&&meta.TryGet("hero_xp",out var oldXp)?oldXp:FoundationValue.Integer(0)),LegacySaveImporter.NormalizeHeroXp(state.Get("hero_xp")));
   return RouteGameplay.Object(("completed",FoundationValue.Boolean(true)),("rounds",FoundationValue.Integer(Math.Max(Whole(meta,"rounds"),state.Get("ng_plus").AsInt64()+1))),
    ("weapon",StoryModel.S(kept)),("hearts",FoundationValue.Integer(Math.Max(Whole(meta,"hearts"),state.Count("heart_container")))),
    ("boots",FoundationValue.Boolean(Truth(meta,"boots")||state.Count("boots")>0)),("hero_xp",FoundationValue.Integer(xp)),("gear_items",gear),
    // What you own is kept; the last deliberate selection (also an empty one) stays your choice.
    ("equipment",rules.NormalizeEquipment(state.Get("equipment"),inventory)));
  }
  /// <summary>After the ending every save remembers your best gear for New Game+, also for adventures finished earlier.</summary>
  public bool RecordCompletion()
  {
   if(!Running||Persistence==null||!Persistence.HasProfile||!Gameplay.State.Flag("game_completed"))return false;
   var before=Persistence.NgMeta;var merged=MergedNgMeta(before);
   if(before!=null&&FoundationJson.StringifyPlain(before)==FoundationJson.StringifyPlain(merged))return true;
   return Persistence.SetNgMeta(merged);
  }
  /// <summary>A new story with your best gear: the state GameState.new_game_plus builds.</summary>
  public static FoundationValue NewGamePlusState(FoundationValue fresh,FoundationValue meta,LegacySaveImporter rules)
  {
   if(!Truth(meta,"completed"))throw new InvalidOperationException("New Game+ needs a finished adventure");
   var state=new FoundationGameState(fresh);long hearts=Math.Max(0,Whole(meta,"hearts"));
   state.Set("ng_plus",FoundationValue.Integer(Math.Max(1,Whole(meta,"rounds"))));state.SetFlag("op_new_adventure",false);
   // The opening is only for a first adventure: the flag is removed, not merely switched off.
   state.Set("flags",InventoryModel.Replace(state.Get("flags"),"op_new_adventure",FoundationValue.Boolean(false),true));
   string weapon=meta.TryGet("weapon",out var w)&&w.Kind=="string"&&rules.IsKnownWeapon(w.AsString())?w.AsString():"wood";state.Set("weapon",StoryModel.S(weapon));
   state.Set("hero_xp",FoundationValue.Integer(LegacySaveImporter.NormalizeHeroXp(meta.TryGet("hero_xp",out var xp)?xp:FoundationValue.Integer(0))));
   var inventory=state.Get("inventory");
   if(hearts>0)inventory=InventoryModel.Replace(inventory,"heart_container",FoundationValue.Integer(state.Count("heart_container")+hearts));
   if(Truth(meta,"boots"))inventory=InventoryModel.Replace(inventory,"boots",FoundationValue.Integer(state.Count("boots")+1));
   foreach(var row in rules.NormalizeOwned(meta.TryGet("gear_items",out var gear)?gear:InventoryModel.Empty()).Entries)
   {long had=inventory.TryGet(row.Key.AsString(),out var count)?count.AsInt64():0;inventory=InventoryModel.Replace(inventory,row.Key.AsString(),FoundationValue.Integer(had+1));}
   state.Set("inventory",inventory);
   state.Set("equipment",rules.NormalizeEquipment(meta.TryGet("equipment",out var equipment)?equipment:InventoryModel.Empty(),inventory));
   state.Coins=NgStartCoins;state.Hp=5+state.Count("heart_container");
   return state.Snapshot();
  }
  public bool BeginNewGamePlus(PersistenceCoordinator coordinator)
  {
   if(coordinator==null||!NgPlusAvailable(coordinator)){ShowMessage(T("Nieuw spel+ komt vrij nadat je het hoofdverhaal hebt uitgespeeld.","New Game+ unlocks after you finish the main story."));return false;}
   if(Running&&!Save())return false;
   var game=RouteGameplay.NewGame(repository);
   var initial=repository.Read("village");game.State.Position=PositionValue((initial.Arrivals.FirstOrDefault(v=>v.Name=="start")??initial.Arrivals[0]).Resolved);
   if(coordinator.Current.Snapshot.State.TryGet("achievements",out var achievements))game.State.Set("achievements",achievements);
   var state=NewGamePlusState(game.State.Snapshot(),coordinator.NgMeta,CompletionRules);
   if(!coordinator.CreateRouteCopy(state,false)){ShowMessage(coordinator.Status);return false;}
   if(!Begin(coordinator))return false;if(!Automated)OpenIntro();return true;
  }
  /// <summary>The main story ends here, as when the Slime King falls.</summary>
  public void RequestEnding()=>CompleteKingEnding();
  void OpenEnding()
  {
   SetModal("victory");Ending.Open(AdventureStats());Ending.NotifyOpened(storyInput);World.PlayRouteMusic("ending");
  }
 }
}
