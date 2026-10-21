using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 public sealed partial class RouteWorldController
 {
  RouteTarget storyWorker,storyMemorial;string storyWorkMap="",storyMemorialMap="";Vector2 storyWorkOrigin;double storyWorkTime;long storyWorkHealth;
  readonly Dictionary<RouteTarget,double> storyPulses=new Dictionary<RouteTarget,double>();
  internal double StoryPulse(RouteTarget target)=>storyPulses.TryGetValue(target,out var value)?value:0;
  readonly Queue<FoundationValue> pendingStoryActions=new Queue<FoundationValue>();
  public bool StoryWorking=>storyWorker!=null;
  internal double StoryObjectElapsed=>storyWorkTime;
  internal void RestoreStoryActorState(FoundationValue initial)
  {refreshingStory=true;try{Gameplay.State.CommitFields(initial.Entries.ToDictionary(e=>e.Key.AsString(),e=>e.Value));}finally{refreshingStory=false;}}
  public double StoryWorkProgress=>storyWorker==null?0:Math.Min(1,storyWorkTime/(storyWorker.Kind=="opening_device"?1.6:1.5));
  static FoundationValue Action(string op,params FoundationValue[] args)=>FoundationValue.Array(new[]{StoryModel.S(op)}.Concat(args));
  void StoryActions(params FoundationValue[] actions)
  {var batch=FoundationValue.Array(actions);if(Story.IsExecuting)pendingStoryActions.Enqueue(batch);else Story.RunActions(batch);}
  internal void FlushStoryObjectActions(){while(pendingStoryActions.Count>0&&!Story.IsExecuting)Story.RunActions(pendingStoryActions.Dequeue());}
  internal void ResetStoryObjectWork(){storyWorker=null;storyMemorial=null;storyWorkMap="";storyMemorialMap="";storyWorkTime=0;pendingStoryActions.Clear();storyPulses.Clear();}
  string ObjectKind(RouteTarget t)=>StoryModel.G(t.Fields,"kind",StoryModel.G(StoryModel.G(t.Fields,"obj",t.Fields),"kind",StoryModel.S(t.Kind=="opening_device"?"grate":"track"))).AsString();
  string ObjectId(RouteTarget t)=>StoryModel.G(t.Fields,"id",StoryModel.G(StoryModel.G(t.Fields,"obj",t.Fields),"id",StoryModel.S(""))).AsString();
  string StoryObjectLabel(RouteTarget t)
  {switch(ObjectKind(t)){case "grate":return Translate("Verstopt rooster");case "wheel":return Translate("Sluisrad");case "track":return Translate("Pootafdrukken");case "relief":return Translate("Beschadigd reliëf");case "journal":return Translate("Wachtersboek");case "memorial":return Translate("Wilfreds gedenksteen");default:return Translate("Klankschaal");}}
  void SayStoryObject(RouteTarget target,string text)
  {Story.RequestLines(StoryObjectLabel(target),new[]{Translate(text)});SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);}
  bool ReadyToRemember()=>Gameplay.State.Flag("rf_relief")&&Gameplay.State.Flag("rf_journal")&&Gameplay.State.QuestState("medaillon")=="done";
  bool StoryLoud=>World.Motor.Sprinting||World.Motor.IsRolling||(Combat!=null&&(Combat.Player.Phase!=""||Combat.Player.AttackTimer>0||Combat.Player.BowAnim>0));
  internal bool InteractStoryObject(RouteTarget target)
  {
   if(storyWorker!=null||Gameplay.State.InputLocked)return false;
   string kind=ObjectKind(target),id=ObjectId(target);var state=Gameplay.State;
   if(target.Kind=="opening_device")
   {
    if(kind=="grate")
    {
     if(state.Flag("op_grate"))SayStoryObject(target,"Onder het riet zit een oud prismateken. Het rooster is schoon; het sluisrad staat iets zuidelijker.");
     else if(state.Count("op_rake")==0)SayStoryObject(target,"Het riet zit vast. Nelle, de hovenier met de strohoed, staat naast de fontein. Ze heeft een hark.");
     else{StartStoryWork(target);World.Motor.Facing=BlueMapMigration.Player.PlayerMotorModel.NormalizeSource(target.Position-World.Position);OnSound("op_rake");}return true;
    }
    if(!state.Flag("op_grate"))SayStoryObject(target,"Eerst het riet uit het rooster halen. Anders loopt het water over het plein.");
    else if(!state.Flag("op_water"))StoryActions(Action("set_flag",StoryModel.S("op_water")),Action("take",StoryModel.S("op_rake"),StoryModel.I(1)),Action("coins",StoryModel.I(12)),Action("sound",StoryModel.S("op_water")),Action("toast",StoryModel.S("Het water stroomt! Nelle heeft haar hark terug. Het prismateken lijkt op dat van Greta’s werkbank.")),Action("save"));
    else StoryActions(Action("toast",StoryModel.S("Het water stroomt naar de fontein en de bloembakken.")));
    World.RefreshRouteState();return true;
   }
   switch(kind)
   {
    case "track":StoryActions(Action("start_quest",StoryModel.S("kat")),Action("set_flag",StoryModel.S(id)),Action("save"));SayStoryObject(target,"Kleine pootjes, een witte haar. De afdrukken lopen zuidwaarts langs de vijver. Muis lijkt bang voor haastige stappen.");return true;
    case "relief":case "journal":
     storyPulses[target]=6;
     var acts=new List<FoundationValue>();if(!state.Flag("rf_memorial"))acts.Add(Action("start_quest",StoryModel.S("rf_memory")));acts.Add(Action("set_flag",StoryModel.S(id)));acts.Add(Action("save"));StoryActions(acts.ToArray());
     SayStoryObject(target,kind=="relief"?"Een bewaker houdt een poort omhoog. Achter hem trekken families naar een grot. Het medaillon op zijn borst lijkt op dat van Wilfred.":"Laatste wacht: de poort bleef open. De families volgden drie klankschalen naar de westelijke schuilplaats. Wilfred keerde niet terug. Hij bewaakte mensen, niet het goud.");return true;
    case "memorial":
     if(state.Flag("rf_memorial"))SayStoryObject(target,state.Flag("rf_guide")?"Hier wordt Wilfred herinnerd: de gids die anderen liet ontsnappen.":"Hier wordt Wilfred herinnerd: de bewaker die bleef.");
     else if(ReadyToRemember()){storyMemorial=target;storyMemorialMap=state.MapId;StoryActions(Action("talk",StoryModel.S("rf_inscription")));SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);}
     else{StoryActions(Action("start_quest",StoryModel.S("rf_memory")));SayStoryObject(target,"De steen mist zijn verhaal. Onderzoek het reliëf en het wachtersboek, en breng Wilfred zijn medaillon terug.");}return true;
    case "bowl":
     StoryActions(Action("start_quest",StoryModel.S("rf_echo")));string required=id=="rf_echo_mid"?"rf_echo_begin":"rf_echo_mid";
     if(id!="rf_echo_begin"&&!state.Flag(required))SayStoryObject(target,"De schaal blijft stil. Begin bij de ingang en volg daarna de blauwe tekens via de middelste kamer naar het westen.");else StartStoryWork(target);return true;
    default:return false;
   }
  }
  void StartStoryWork(RouteTarget target){storyWorker=target;storyWorkMap=Gameplay.State.MapId;storyWorkOrigin=World.Position;storyWorkHealth=Gameplay.State.Hp;storyWorkTime=0;}
  bool RememberStoryChoice(string choice)
  {
   if(choice!="guard"&&choice!="guide"||storyMemorial==null||storyMemorialMap!=Gameplay.State.MapId||!targets.Contains(storyMemorial)||!Enabled(storyMemorial)||Vector2.Distance(World.Position,storyMemorial.Position)>64||Gameplay.State.Flag("rf_memorial")||!ReadyToRemember())return false;
   StoryActions(Action("start_quest",StoryModel.S("rf_memory")),Action("set_flag",StoryModel.S("rf_"+choice)),Action("save"),Action("set_flag",StoryModel.S("rf_memorial")),Action("save"),Action("give",StoryModel.S("gear_rf_keepsake"),StoryModel.I(1)),Action("finish_quest",StoryModel.S("rf_memory")),Action("sound",StoryModel.S("rf_high")),Action("save"));return true;
  }
  internal void TickStoryObjectWork(double delta)
  {
   foreach(var key in storyPulses.Keys.ToArray())storyPulses[key]=Math.Max(0,storyPulses[key]-delta);
   if(storyWorker==null)return;var target=storyWorker;bool opening=target.Kind=="opening_device";
   if(storyWorkMap!=Gameplay.State.MapId||!targets.Contains(target)||Vector2.Distance(World.Position,storyWorkOrigin)>(opening?8:7)||Vector2.Distance(World.Position,target.Position)>(opening?58:60)||Gameplay.State.Hp<=0||World.Motor.IsRolling||Combat!=null&&(Combat.Player.AttackTimer>0||!opening&&Combat.Player.Phase!="")||!opening&&(Gameplay.State.InputLocked||StoryLoud||Gameplay.State.Hp<storyWorkHealth)){storyWorker=null;storyWorkTime=0;return;}
   storyWorkTime+=delta;if(storyWorkTime<(opening?1.6:1.5))return;storyWorker=null;
   if(opening)StoryActions(Action("set_flag",StoryModel.S("op_grate")),Action("toast",StoryModel.S("Het rooster is vrij. Draai nu het sluisrad aan de zuidkant open.")),Action("save"));
   else
   {
    storyPulses[target]=3;string id=ObjectId(target);OnSound(id=="rf_echo_begin"?"rf_low":id=="rf_echo_mid"?"rf_mid":"rf_high");
    if(!Gameplay.State.Flag(id))
    {
     var actions=new List<FoundationValue>{Action("set_flag",StoryModel.S(id)),Action("save")};
     if(id=="rf_echo_end"){actions.Add(Action("give",StoryModel.S("gear_rf_cord"),StoryModel.I(1)));actions.Add(Action("finish_quest",StoryModel.S("rf_echo")));actions.Add(Action("toast",StoryModel.S("De oude schuilplaats licht op. In de westelijke kamer staat een kist. Je vindt ook een stiltekoord: draag het via Uitrusting.")));}
     else actions.Add(Action("toast",StoryModel.S("Een echo antwoordt. Volg de oplichtende tekens; rustig lopen laat de steenluisteraars slapen.")));
     actions.Add(Action("save"));StoryActions(actions.ToArray());
    }
   }
   World.RefreshRouteState();
  }
 }
}
