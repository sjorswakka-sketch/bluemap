using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using UnityEngine;
namespace BlueMapMigration.Story
{
 public static class StoryProbeRunner
 {
  [Serializable] public sealed class Result{public int schemaVersion=1;public bool success,gameSaveAccessed=false;public BuildIdentity identity;public Phase2Probe.Check[] checks=Array.Empty<Phase2Probe.Check>();}
  public static Result Last {get;private set;}public static PersistenceCoordinator Fixture {get;private set;}public static int ObjectCases {get;private set;}
  static FoundationValue S(string v)=>StoryModel.S(v);static FoundationValue I(long v)=>StoryModel.I(v);static FoundationValue P(string v)=>FoundationJson.ParsePlain(v);static string Json(FoundationValue v)=>FoundationJson.StringifyPlain(v);
  static string Spawn(FoundationWorldSnapshot map)=>map.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name??map.Arrivals[0].Name;
  static string Kind(RouteTarget t)=>StoryModel.G(t.Fields,"kind",StoryModel.G(StoryModel.G(t.Fields,"obj",t.Fields),"kind",S(""))).AsString();
  static string Id(RouteTarget t)=>StoryModel.G(t.Fields,"id",StoryModel.G(StoryModel.G(t.Fields,"obj",t.Fields),"id",S(""))).AsString();
  static readonly HashSet<string> Signals=new HashSet<string>{"hp_changed","items_changed","quests_changed","progression_changed","equipment_changed","appearance_changed","save_requested","ending_requested","toast","dialogue_requested","text_dialogue_requested","shop_requested","world_action"};
  static FoundationValue Obj(params (string,FoundationValue)[] items)=>FoundationValue.Object(items.ToDictionary(p=>p.Item1,p=>p.Item2));
  static void RequireEqual(FoundationValue actual,FoundationValue expected,string path){string difference=StoryModelChecks.Difference(actual,expected,path);if(difference!=null)throw new InvalidOperationException("Original story actor differs: "+difference);}
  static void VerifyObjects(FoundationWorldRepository repository,PlayerWorld world,RouteWorldController route)
  {
   ObjectCases=0;var cases=route.Story.Oracle.Require("objectCases").Items;
   foreach(var row in cases)
   {
    string name=row.Require("id").AsString(),map=row.Require("map").AsString();route.CloseModal();
    // Each original episode constructs a fresh dialogue box; reload creates the corresponding fresh model and UI.
    if(!route.Reload(false))throw new InvalidOperationException("Object case session reset failed: "+name);route.ResetStoryObjectWork();route.RestoreStoryActorState(InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));
    if(!route.TryTravel(map,Spawn(repository.Read(map))))throw new InvalidOperationException("Object case travel failed: "+name);
    route.ResetStoryObjectWork();var spec=row.Require("spec");string type=spec.Require("type").AsString(),kind=spec.Require("kind").AsString(),id=StoryModel.G(spec,"id",S("")).AsString();
    var target=route.Targets.FirstOrDefault(t=>t.Kind==type&&Kind(t)==kind&&(id==""||Id(t)==id));if(target==null)throw new InvalidOperationException("Actual source actor missing: "+name);
    world.Teleport(target.Position+new Vector2(0,38));route.Combat.ResetTransient();route.RestoreStoryActorState(InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));
    var events=new List<FoundationValue>();Action<StoryEffect> listen=e=>{if(Signals.Contains(e.Kind))events.Add(Obj(("kind",S(e.Kind)),("payload",e.Payload)));};route.Story.EffectRequested+=listen;
    try
    {
     var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;
     for(int i=0;i<ops.Count;i++)
     {
      var op=ops[i].Items;switch(op[0].AsString())
      {
       case "interact":route.InteractStoryObject(target);break;
       case "close":route.CloseModal();break;
       case "tick":route.TickStoryObjectWork(op[1].AsDouble());break;
       case "player":world.Teleport(target.Position+new Vector2((float)op[1].AsDouble(),(float)op[2].AsDouble()));route.Combat.Player.AttackTimer=op.Count>3?op[3].AsDouble():0;break;
       case "action":route.Story.RunActions(FoundationValue.Array(new[]{op[1]}));route.FlushStoryObjectActions();break;
       default:throw new InvalidOperationException("Unknown source actor operation: "+op[0].AsString());
      }
      var actor=type=="opening_device"?Obj(("working",FoundationValue.Boolean(route.StoryWorking)),("progress",FoundationValue.Number(route.StoryObjectElapsed))):Obj(("listening",FoundationValue.Boolean(route.StoryWorking)),("progress",FoundationValue.Number(route.StoryObjectElapsed)),("pulse",FoundationValue.Number(route.StoryPulse(target))));
      var actual=Obj(("state",route.Gameplay.State.Snapshot()),("dialogue",StoryModelChecks.View(route.Story)),("events",FoundationValue.Array(events)),("actor",actor));RequireEqual(actual,row.Require("observationsExact").Items[i],name+"["+i+"]");
     }
     RequireEqual(route.Gameplay.State.Snapshot(),row.Require("expectedExact"),name+".final");ObjectCases++;
    }
    finally{route.Story.EffectRequested-=listen;}
   }
   route.CloseModal();route.ResetStoryObjectWork();
  }
  public static IEnumerator Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route,Phase6Catalog catalog)
  {
   Last=new Result{identity=identity};var checks=new List<Phase2Probe.Check>();
   void Check(string name,bool passed){if(checks.Any(c=>c.name==name))throw new InvalidOperationException("Duplicate story proof "+name);checks.Add(new Phase2Probe.Check{name=name,passed=passed});Last.checks=checks.ToArray();if(!passed)Debug.Log("Story native check failed: "+name);}
   var repository=FoundationWorldRepository.LoadRequired();StoryModelChecks.Verify(repository,Check);
   string root=PersistencePaths.Checked(Path.Combine(output,"story-profiles"));if(Directory.Exists(root))throw new IOException("Fresh story profile required");route.CloseModal();Fixture=new PersistenceCoordinator(repository,world.InputSource,root);if(!route.BeginNew(Fixture))throw new IOException(Fixture.Status);route.CombatSimulationEnabled=false;
   Check("story_native_new_profile_isolated",Fixture.Current.Snapshot.CopyOriginals().Count==0&&ReferenceEquals(route.Story.State,route.Gameplay.State)&&ReferenceEquals(route.Story.Inventory,route.Inventory)&&ReferenceEquals(route.Story.Progression,route.Progression));
   VerifyObjects(repository,world,route);Check("story_native_source_object_oracle",ObjectCases==17&&ObjectCases==route.Story.Oracle.Require("objectCases").Items.Count);
   // New real adventure after the exhaustive synthetic object recordings.
   if(!route.BeginNew(Fixture))throw new IOException(Fixture.Status);var state=route.Gameplay.State;
   void Travel(string map){route.CloseModal();if(!route.TryTravel(map,Spawn(repository.Read(map))))throw new InvalidOperationException("Story travel failed: "+map);state=route.Gameplay.State;route.Combat.ResetTransient();}
   void At(RouteTarget target){world.Teleport(target.Position+new Vector2(0,30));world.Step(0,new MotionInput());world.FocusCameraOnPlayer();}
   void Finish(){for(int guard=0;route.Gameplay.DialogueOpen&&!route.Gameplay.Dialogue.ChoicesReady&&guard<80;guard++)route.AdvanceDialogue();}
   var nelle=route.Targets.First(t=>t.Kind=="village_actor"&&t.Id=="gardener");At(nelle);bool loan=route.InteractTarget(nelle.Address);Finish();bool quest=state.Count("op_rake")==1&&state.QuestState("first_water")=="active";
   var grate=route.Targets.First(t=>t.Kind=="opening_device"&&Kind(t)=="grate");At(grate);bool worked=route.InteractTarget(grate.Address);route.Tick(.8);world.Teleport(world.Position+new Vector2(9,0));route.Tick(.8);bool cancelled=!route.StoryWorking&&!state.Flag("op_grate");At(grate);route.InteractTarget(grate.Address);route.Tick(1.6);
   Check("story_native_opening_tool_and_interrupt",loan&&quest&&worked&&cancelled&&state.Flag("op_grate"));
   var wheel=route.Targets.First(t=>t.Kind=="opening_device"&&Kind(t)!="grate");At(wheel);long coins=state.Coins;route.InteractTarget(wheel.Address);long firstCoins=state.Coins;route.InteractTarget(wheel.Address);world.RefreshRouteState();
   Check("story_native_opening_water_once",state.Flag("op_water")&&state.Count("op_rake")==0&&firstCoins==coins+12&&state.Coins==firstCoins&&world.RoutePresentation.StoryVisuals.SourceVisualKey(grate.Address)=="opening_water_restored");
   Travel("smithy");var greta=route.Targets.First(t=>t.Kind=="npc"&&t.Id=="greta");At(greta);route.InteractTarget(greta.Address);Finish();long xp=state.Get("hero_xp").AsInt64();route.InteractTarget(greta.Address);route.CloseModal();Check("story_native_greta_intro_reward_once",state.Flag("op_greta")&&state.QuestState("first_water")=="done"&&state.Get("hero_xp").AsInt64()==xp&&xp>0);
   // Existing saved progress is the legitimate starting context for a late-story test; no synthetic content is added.
   Travel("ruins");route.Story.RunActions(P("[[\"start_quest\",\"medaillon\"],[\"finish_quest\",\"medaillon\"]]"));
   foreach(string kind in new[]{"relief","journal"}){var clue=route.Targets.First(t=>t.Kind=="route_object"&&Kind(t)==kind);At(clue);route.InteractTarget(clue.Address);Finish();}
   var memorial=route.Targets.First(t=>t.Kind=="route_object"&&Kind(t)=="memorial");At(memorial);route.InteractTarget(memorial.Address);Finish();world.Teleport(memorial.Position+new Vector2(65,0));route.Story.RunActions(P("[[\"rf_choose\",\"guide\"]]"));route.FlushStoryObjectActions();Check("story_native_memorial_context_guard",!state.Flag("rf_memorial")&&state.Count("gear_rf_keepsake")==0);
   At(memorial);int choice=route.Gameplay.Dialogue.Choices.ToList().FindIndex(c=>c.Source.TryGet("do",out var a)&&a.Items.Any(v=>v.Items.Count>1&&v.Items[0].AsString()=="rf_choose"&&v.Items[1].AsString()=="guide"));route.ChooseDialogue(choice);long rewardXp=state.Get("hero_xp").AsInt64();route.Story.RunActions(P("[[\"rf_choose\",\"guide\"]]"));route.FlushStoryObjectActions();world.RefreshRouteState();
   Check("story_native_memorial_choice_reward_once",state.Flag("rf_guide")&&state.Flag("rf_memorial")&&state.Count("gear_rf_keepsake")==1&&state.QuestState("rf_memory")=="done"&&state.Get("hero_xp").AsInt64()==rewardXp&&world.RoutePresentation.StoryVisuals.SourceVisualKey(memorial.Address)=="route_memorial_guide");
   Travel("cave");var bowls=route.Targets.Where(t=>t.Kind=="route_object"&&Kind(t)=="bowl").ToArray();var last=bowls.First(t=>Id(t)=="rf_echo_end");At(last);route.InteractTarget(last.Address);bool wrongOrder=!route.StoryWorking&&!state.Flag("rf_echo_end");route.CloseModal();
   foreach(string id in new[]{"rf_echo_begin","rf_echo_mid","rf_echo_end"}){var bowl=bowls.First(t=>Id(t)==id);At(bowl);route.InteractTarget(bowl.Address);route.Tick(1.5);}
   route.InteractTarget(last.Address);route.Tick(1.5);Check("story_native_echo_sequence_and_quiet_guard",wrongOrder&&state.Flag("rf_echo_end")&&state.QuestState("rf_echo")=="done"&&state.Count("gear_rf_cord")==1);
   state.Hp=1;world.Motor.Stamina.Stamina=0;route.Story.RunActions(P("[[\"heal\"]]"));Check("story_native_full_rest_stamina",state.Hp==state.MaxHp&&world.Motor.Stamina.Stamina==world.Motor.Stamina.Capacity);
   route.Story.RunActions(P("[[\"start_quest\",\"main\"]]"));route.Story.ToggleFocus("main");state.Set("future_story",P("{\"exact\":9007199254740993,\"unknown\":[null,true,\"🌿\"]}"));route.Save();long beforeXp=state.Get("hero_xp").AsInt64(),beforeCoins=state.Coins;var bag=Json(state.Get("inventory"));bool reload=route.Reload(false);state=route.Gameplay.State;
   Check("story_native_quest_focus_persists",reload&&route.Story.FocusedQuest=="main");Check("story_native_reload_unknowns_no_rewards",state.Get("future_story").Require("exact").AsInt64()==9007199254740993L&&state.Get("hero_xp").AsInt64()==beforeXp&&state.Coins==beforeCoins&&Json(state.Get("inventory"))==bag);
   Travel("kruipmoeras");route.Story.RunActions(P("[[\"set_flag\",\"lw_drained\"],[\"set_flag\",\"lw_bridge\"]]"));route.Tick(0);Check("story_native_world_consequence_refresh",route.Session.Current.ScenarioId=="marsh_bridge"&&route.Access.SpawnFits(route.Session.Current,world.Position));
   Travel("temple");state.SetFlag("boss_started",false);state.SetFlag("boss_defeated",false);route.CombatSimulationEnabled=true;world.Teleport(new Vector2(10*32+16,12*32+16));route.Tick(0);Check("story_native_trigger_actions_in_order",state.Flag("boss_started")&&route.Gameplay.Dialogue?.Id=="king_intro"&&route.Encounter.Actors.Any(a=>a.Kind=="king"&&a.Active));route.CloseModal();route.CombatSimulationEnabled=false;
   Travel("harbor");var raf=route.Targets.First(t=>t.Kind=="coast_resident"&&t.Id=="rg_raf");At(raf);route.InteractTarget(raf.Address);Check("story_native_full_catalog_npc_visible",state.Flag("cw_raf_notes")&&route.Gameplay.Dialogue?.Id=="rg_raf"&&route.Story.Catalogs.Require("dialogues").Entries.Count==244&&route.Story.Catalogs.Require("quests").Entries.Count==33);route.CloseModal();
   string before=Json(state.Snapshot());route.Story.RunActions(P("[[\"wt_open\",\"smithing\"]]"));Check("story_native_context_services_no_fake_rewards",before==Json(state.Snapshot())&&route.LastStoryService=="wt_open");
   Travel("village");route.Story.ToggleFocus("main");route.ShowMessage("");route.ItemNotices.Clear();world.Teleport(new Vector2(640,520));world.Step(0,new MotionInput());world.FocusCameraOnPlayer();route.Tick(0);yield return new WaitForEndOfFrame();
   var capture=ScreenCapture.CaptureScreenshotAsTexture();try{File.WriteAllBytes(Path.Combine(output,"screenshot-story-consequence.png"),capture.EncodeToPNG());}finally{UnityEngine.Object.Destroy(capture);}
   Check("story_native_consequence_rendered",world.RoutePresentation.StoryVisuals.ChangedVisuals>=3&&route.Hud.TrackerTextFits&&File.Exists(Path.Combine(output,"screenshot-story-consequence.png")));
   var ui=StoryUiProbeRunner.Run(identity,output,world,route,catalog,Check);while(ui.MoveNext())yield return ui.Current;
   Check("story_no_personal_saves_used",Fixture.Current.Snapshot.CopyOriginals().Count==0&&PersistencePaths.Within(PersistencePaths.Checked(output),root)&&!PersistencePaths.Within(PersistencePaths.UnityDefault,root)&&!PersistencePaths.Within(PersistencePaths.LegacyDefault,root));
   route.CloseModal();route.CombatSimulationEnabled=false;route.Save();Last.success=checks.All(c=>c.passed);Last.checks=checks.ToArray();File.WriteAllText(Path.Combine(output,"story-result.json"),JsonUtility.ToJson(Last,true));Debug.Log("Story native proof: "+checks.Count+" checks");
  }
 }
}
