using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
namespace BlueMapMigration.Route
{
 public sealed partial class RouteWorldController
 {
  public StoryModel Story=>Gameplay?.Story;
  public StoryDialoguePanel DialoguePanel {get;private set;}
  public StoryQuestPanel QuestPanel {get;private set;}
  public string LastStoryService {get;private set;}="";
  public event Action<FoundationValue> StoryServiceRequested;
  object lastDialogueToken;InputFrame storyInput;double storyFrameDelta=1.0/60;IDisposable storySubscription;
  bool storyEndingPending,refreshingStory;
  void InitializeStory()
  {
   Story.Translator=Translate;
   DialoguePanel=new StoryDialoguePanel(Catalog,Translate,T,Gameplay.FormatDialogue,BindingLabel);
   DialoguePanel.AdvanceRequested+=AdvanceDialogue;DialoguePanel.ChoiceRequested+=ChooseDialogue;DialoguePanel.CloseRequested+=CloseModal;
   QuestPanel=new StoryQuestPanel(Catalog,Translate,T,BindingLabel);QuestPanel.ToggleFocusRequested+=ToggleStoryFocus;QuestPanel.CloseRequested+=CloseModal;
   Story.EffectRequested+=StoryEffect;Story.DialogueChanged+=SyncDialogue;Story.ExternalActionHandler=HandleStoryExternal;
   Story.Journey.SaveRequested+=OnSaveRequested;
   storySubscription=Gameplay.State.Events.Subscribe<FoundationStateChanged>(change=>
   {if((change.Field=="inventory"||change.Field=="flags")&&!Story.IsExecuting&&!refreshingStory){refreshingStory=true;try{Story.RefreshQuests();}finally{refreshingStory=false;}}});
   lastDialogueToken=null;storyInput=null;storyEndingPending=false;LastStoryService="";RefreshStoryViews();
  }
  void DetachStory()
  {
   storySubscription?.Dispose();storySubscription=null;
   if(Story!=null){Story.EffectRequested-=StoryEffect;Story.DialogueChanged-=SyncDialogue;Story.ExternalActionHandler=null;Story.Journey.SaveRequested-=OnSaveRequested;}
   if(DialoguePanel!=null){DialoguePanel.AdvanceRequested-=AdvanceDialogue;DialoguePanel.ChoiceRequested-=ChooseDialogue;DialoguePanel.CloseRequested-=CloseModal;DialoguePanel.SetView(null);}
   if(QuestPanel!=null){QuestPanel.ToggleFocusRequested-=ToggleStoryFocus;QuestPanel.CloseRequested-=CloseModal;QuestPanel.Close();}
   DialoguePanel=null;QuestPanel=null;lastDialogueToken=null;storyInput=null;ResetStoryObjectWork();
  }
  bool InteractStoryResident(RouteTarget target)
  {
   bool opened=target.Kind=="coast_resident"?Story.TalkCoastResident(target.Id):target.Kind=="village_actor"?Story.TalkVillageActor(target.Id):Story.TalkSupperActor(target.Id,target.Fields.Require("role").AsString());
   SyncDialogue();if(opened)DialoguePanel.NotifyOpened(storyInput);return opened;
  }
  void SyncStoryDialogue()
  {
   if(DialoguePanel==null)return;var d=Gameplay.Dialogue;
   DialoguePanel.SetView(d==null?null:new StoryDialogueView{Token=d,Id=d.Id,Speaker=d.Speaker,Lines=d.Lines,Choices=d.Choices.Select(c=>c.Text).ToArray(),ChoicesReady=d.ChoicesReady,FromData=d.FromData,LineIndex=DialogueLineIndex});
  }
  public void RefreshStoryViews(bool includeJournal=true)
  {
   if(Story==null||QuestPanel==null)return;
   Story.Translator=Translate;Story.ArenaActive=Access?.ArenaRunActive??false;
   Story.Journey.Stamina=World.Motor.Stamina.Stamina;Story.Journey.StaminaCapacity=World.Motor.Stamina.Capacity;
   if(includeJournal)QuestPanel.SetEntries(Story.Journey.QuestOrder.Select(id=>new StoryQuestEntry{Id=id,Title=Story.Journey.QuestTitle(id),Status=Story.Journey.QuestStatusText(id),Detail=Story.Journey.QuestDetail(id),IsDone=Story.QuestState(id)=="done",IsMain=StoryModel.G(Story.Catalogs.Require("quests").Require(id),"main",FoundationValue.Boolean(false)).AsBool(),IsFocused=Story.FocusedQuest==id}).ToArray());
   Hud.StoryTrackerText=Story.HudTrackedText;SyncDialogue();
  }
  void ToggleStoryFocus(string id){if(Story.ToggleFocus(id)){OnSound("select");RefreshStoryViews();}else OnSound("error");}
  void TickStory(double delta)
  {
   if(Story==null||DialoguePanel==null)return;storyFrameDelta=delta;FlushStoryObjectActions();RefreshStoryViews(Modal=="quests");DialoguePanel.SetControllerActive(ControllerActive);QuestPanel.SetControllerActive(ControllerActive);DialoguePanel.Tick(delta);QuestPanel.Tick(delta);
   TickStoryObjectWork(delta);
   if(storyEndingPending&&!Story.IsExecuting){storyEndingPending=false;CloseModal();CompleteKingEnding();}
  }
  void StoryEffect(StoryEffect effect)
  {
   switch(effect.Kind)
   {
    case "full_rest":World.Motor.Stamina.Reset();UpdateInventoryContext();break;
    case "toast":string message=effect.Payload.AsString();if(!message.StartsWith("Gekregen:",StringComparison.Ordinal)&&!message.StartsWith("Obtained:",StringComparison.Ordinal)&&!message.StartsWith("Received:",StringComparison.Ordinal))ShowMessage(message);break;
    case "world_action":var a=effect.Payload.Items;switch(a[0].AsString()){case "music":World.PlayRouteMusic(a[1].AsString());break;case "boss_start":OnSound("boss");World.PlayRouteMusic("boss");Encounter?.ActivateBosses();break;}break;
    case "ending_requested":storyEndingPending=true;break;
    case "shop_requested":LastStoryService="shop:"+effect.Payload.AsString();StoryServiceRequested?.Invoke(StoryModel.A(StoryModel.S("shop"),effect.Payload));ShowMessage(T("Deze winkel opent in de handelsfase van de migratie.","This shop opens in the trading phase of the migration."));break;
   }
  }
  bool HandleStoryExternal(FoundationValue action)
  {
   if(action.Items[0].AsString()=="rf_choose")return RememberStoryChoice(action.Items[1].AsString());
   // Source contextual commands without their required live actor are no-ops; retain the complete payload for its owning later phase.
   LastStoryService=action.Items[0].AsString();StoryServiceRequested?.Invoke(action);
   ShowMessage(T("Deze activiteit wordt aangesloten in de bijbehorende migratiefase.","This activity will be connected in its corresponding migration phase."));return false;
  }
 }
}
