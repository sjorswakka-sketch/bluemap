using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
namespace BlueMapMigration.Story
{
 public static class StoryModelChecks
 {
  public static int OracleCases {get;private set;}public static IReadOnlyList<string> CaseIds {get;private set;}=Array.Empty<string>();
  static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue O(params (string,FoundationValue)[] p)=>FoundationValue.Object(p.ToDictionary(v=>v.Item1,v=>v.Item2));
  static readonly HashSet<string> SourceSignals=new HashSet<string>{"hp_changed","items_changed","quests_changed","progression_changed","equipment_changed","appearance_changed","save_requested","ending_requested","toast","dialogue_requested","text_dialogue_requested","shop_requested","world_action"};
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   bool loadedBefore=StoryModel.SourceOracleLoaded;var baseline=new StoryModel(repository,new FoundationGameState());bool constructorKeptLazy=loadedBefore==StoryModel.SourceOracleLoaded;var oracle=baseline.Oracle;string catalogDifference=DifferenceOrdered(baseline.Catalogs,InventoryModelChecks.DecodeOrdered(oracle.Require("catalogsOrdered")),"gameplayCatalog");if(catalogDifference!=null)throw new InvalidOperationException("Original gameplay catalog differs: "+catalogDifference);OracleCases=0;var ids=new List<string>();
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var state=new FoundationGameState(InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));state.InGame=true;var model=new StoryModel(repository,state);var events=new List<FoundationValue>();model.EffectRequested+=e=>{if(SourceSignals.Contains(e.Kind))events.Add(O(("kind",S(e.Kind)),("payload",e.Payload)));};
    var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;
    for(int i=0;i<ops.Count;i++)
    {
     var result=Execute(model,ops[i]);string failure=Difference(result,row.Require("resultsExact").Items[i],id+".results["+i+"]");if(failure!=null)throw new InvalidOperationException("Original story result differs: "+failure);
     var actual=O(("state",state.Snapshot()),("dialogue",View(model)),("events",FoundationValue.Array(events)));failure=Difference(actual,row.Require("observationsExact").Items[i],id+".observations["+i+"]");if(failure!=null)throw new InvalidOperationException("Original story observation differs: "+failure);failure=DifferenceOrdered(actual,InventoryModelChecks.DecodeOrdered(row.Require("observationsOrdered").Items[i]),id+".orderedObservations["+i+"]");if(failure!=null)throw new InvalidOperationException("Original story dictionary order differs: "+failure);
    }
    string finalFailure=Difference(state.Snapshot(),row.Require("expectedExact"),id+".state");if(finalFailure!=null)throw new InvalidOperationException("Original story state differs: "+finalFailure);ids.Add(id);OracleCases++;if(OracleCases%200==0)UnityEngine.Debug.Log("Story original source replay: "+OracleCases+"/"+oracle.Require("cases").Items.Count);
   }
   CaseIds=ids.AsReadOnly();check("story_model_source_equivalence",constructorKeptLazy&&OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count);
   var fresh=new FoundationGameState(oracle.Require("newGame"));fresh.InGame=true;var atomic=new StoryModel(repository,fresh);var unknown=FoundationJson.ParsePlain("{\"big\":9007199254740993,\"nested\":[null,true,\"🌿\"]}");fresh.Set("future_story",unknown);string before=FoundationJson.StringifyPlain(fresh.Snapshot());new StoryModel(repository,fresh,atomic.Inventory,atomic.Progression);bool pure=before==FoundationJson.StringifyPlain(fresh.Snapshot());bool coherent=false,reentry=false;
   using(fresh.Events.Subscribe<FoundationStateChanged>(e=>{if(e.Field!="quests")return;coherent=fresh.QuestState("kat")=="done"&&fresh.Count("gel")==3&&fresh.Coins>=17;reentry=atomic.RunActions(FoundationJson.ParsePlain("[[\"coins\",99]]"));}))atomic.RunActions(FoundationJson.ParsePlain("[[\"start_quest\",\"kat\"],[\"give\",\"gel\",3],[\"coins\",17],[\"finish_quest\",\"kat\"]]"));
   long xp=atomic.Progression.Progress.XP,coins=fresh.Coins;atomic.FinishQuest("kat");bool once=xp==atomic.Progression.Progress.XP&&coins==fresh.Coins;
   check("story_model_ordered_actions_and_unknown_safety",pure&&coherent&&!reentry&&once&&ReferenceEquals(unknown,fresh.Get("future_story")));
  }
  public static FoundationValue View(StoryModel model)
  {
   var d=model.Dialogue??model.LastPresentedDialogue;var choices=model.Dialogue?.Choices??Array.Empty<StoryChoice>();return O(("id",S(model.Dialogue?.Id??"")),("active",B(model.DialogueOpen)),("fromData",B(d?.FromData??true)),("speaker",S(d==null?"":d.FromData?model.Tr(d.Speaker):d.Speaker)),("lines",FoundationValue.Array((d?.Lines??Array.Empty<string>()).Select(S))),("choices",FoundationValue.Array(choices.Select(v=>S(model.Format(model.Tr(v.Text)))))),("sourceIndices",FoundationValue.Array(choices.Select(v=>I(v.SourceIndex)))),("choicesReady",B(model.Dialogue?.ChoicesReady??false)),("stamina",FoundationValue.Number(model.Inventory.Stamina)));
  }
  static FoundationValue Execute(StoryModel model,FoundationValue op)
  {
   var a=op.Items;string id=a[0].AsString();string text=a.Count>1&&a[1].Kind=="string"?a[1].AsString():"";
   switch(id){case "stitch_context":model.PendingSupperStitch=(int)a[1].AsInt64();break;case "language":model.Inventory.Language=text;model.Translator=v=>StoryModel.G(model.Catalogs.Require("translations").Require(text),v,S(v)).AsString();return S(text);case "hud_tracker":return S(model.HudTrackedText);case "trigger":model.RunTrigger(a[1],a[2].AsString(),a[3],a[4].AsBool());break;case "npc_variant":if(text=="coast_resident")model.TalkCoastResident(a[2].AsString());else if(text=="village_actor")model.TalkVillageActor(a[3].AsString());else model.TalkSupperActor(a[2].AsString(),a[3].AsString());return B(model.DialogueOpen);case "run":model.RunActions(FoundationValue.Array(new[]{a[1]}));break;case "run_all":model.RunActions(a[1]);break;case "check":return B(model.Check(a[1]));case "check_all":return B(model.CheckAll(a[1]));case "start":model.StartQuest(text);break;case "step":model.SetQuestStep(text,a[2].AsInt64());break;case "finish":model.FinishQuest(text);break;case "refresh":model.RefreshQuests();break;case "state":return S(model.QuestState(text));case "quest_step":return I(model.QuestStep(text));case "quest_text":return S(model.QuestText(text));case "tracked":return S(model.TrackedText);case "format":return S(model.Format(text));
    case "enter":model.ShowDialogue(text);return B(model.DialogueOpen);case "lines":model.ShowLines(text,a[2].AsString(),a[3].Items.Select(v=>v.AsString()));return B(model.DialogueOpen);case "finish_node":return B(model.Advance());case "choose":return B(model.Choose((int)a[1].AsInt64()));case "choose_source":int index=model.Dialogue==null?-1:model.Dialogue.Choices.ToList().FindIndex(v=>v.SourceIndex==a[1].AsInt64());return B(index>=0&&model.Choose(index));case "close":model.CloseDialogue();break;
    case "npc":model.Talk(text,new StoryNpcContext{CatCalm=a.Count>2?a[2].AsDouble():0,CatPanic=a.Count>3?a[3].AsDouble():0});return B(model.DialogueOpen);case "focus":return S(model.FocusedQuest);case "toggle_focus":return B(model.ToggleFocus(text));case "target":return S(model.QuestTarget(text));case "route":return S(model.RouteText(text));case "compact_route":return S(model.CompactRoute(text));case "detail":return S(model.QuestDetail(text));case "preparation":return FoundationValue.Array(model.Preparation(text).Select(S));case "stamina":model.Inventory.Stamina=a[1].AsDouble();model.Journey.Stamina=model.Inventory.Stamina;return FoundationValue.Number(model.Inventory.Stamina);case "set_field":model.State.Set(text,a[2]);break;default:throw new InvalidOperationException("Unknown original story operation: "+id);
   }return FoundationValue.Nil();
  }
  public static string DifferenceOrdered(FoundationValue actual,FoundationValue expected,string path)
  {
   bool objectExpected=expected.Kind=="dictionary"||expected.Kind=="object";
   if(objectExpected){if(actual.Kind!="dictionary"&&actual.Kind!="object"||actual.Entries.Count!=expected.Entries.Count)return path+": dictionary shape differs";for(int i=0;i<expected.Entries.Count;i++){if(actual.Entries[i].Key.AsString()!=expected.Entries[i].Key.AsString())return path+": dictionary key order differs at "+i;string error=DifferenceOrdered(actual.Entries[i].Value,expected.Entries[i].Value,path+"."+expected.Entries[i].Key.AsString());if(error!=null)return error;}return null;}
   if(expected.Kind=="array"){if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array shape differs";for(int i=0;i<expected.Items.Count;i++){string error=DifferenceOrdered(actual.Items[i],expected.Items[i],path+"["+i+"]");if(error!=null)return error;}return null;}
   if(expected.Kind=="float")return actual.Kind=="float"&&BitConverter.DoubleToInt64Bits(actual.AsDouble())==BitConverter.DoubleToInt64Bits(expected.AsDouble())?null:path+": exact Float64 differs";
   return Difference(actual,expected,path);
  }
        public static string Difference(FoundationValue actual,FoundationValue expected,string path)
        {
            if(expected.TryGet("$f64",out var bits))
            {
                if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected number, got "+actual.Kind;
                string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString();
            }
            if(expected.Kind=="object"||expected.Kind=="dictionary")
            {
                if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected dictionary";
                if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
                foreach(var row in expected.Entries){if(!actual.TryGet(row.Key.AsString(),out var child))return path+": missing "+row.Key.AsString();string failure=Difference(child,row.Value,path+"."+row.Key.AsString());if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="array")
            {
                if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array length differs";
                for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="int")return actual.Kind=="int"&&actual.AsInt64()==expected.AsInt64()?null:path+": integer differs";
            if(expected.Kind=="bool")return actual.Kind=="bool"&&actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
            if(expected.Kind=="string")return actual.Kind=="string"&&actual.AsString()==expected.AsString()?null:path+": text differs ("+(actual.Kind=="string"?actual.AsString():actual.Kind)+")";
            return actual.Kind=="nil"&&expected.Kind=="nil"?null:path+": scalar kind differs";
        }
 }
}
