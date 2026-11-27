using System;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Professions;
using BlueMapMigration.WorldAccess;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>Connects the original professions, shops, work notes and lake fishing to the playable world.</summary>
 public sealed partial class RouteWorldController
 {
  public ProfessionsModel Professions {get;private set;}
  public ProfessionsPanel ProfessionsPanel {get;private set;}
  public ShopPanel ShopPanel {get;private set;}
  public FishingView FishingView {get;private set;}
  public FishingSession Fishing {get;private set;}
  /// <summary>Automated proofs replace the generator; ordinary play draws from Unity's.</summary>
  public IFishingRandom FishingRandom {get;set;}=new UnityFishingRandom();
  double rodHint;string pendingShop="";
  static bool ProfessionsModal(string mode)=>mode=="professions"||mode=="shop"||mode=="fishing";
  void InitializeProfessions()
  {
   Professions=new ProfessionsModel(repository,Gameplay.State,Inventory,Progression){Translator=Translate,PluralTranslator=(one,many,count)=>localization.Translate(one,plural:many,count:count,locale:Locale)};
   Professions.Toast+=ShowMessage;Professions.SoundRequested+=OnSound;Professions.SaveRequested+=OnSaveRequested;Professions.Changed+=ProfessionsChanged;
   ProfessionsPanel=new ProfessionsPanel(Catalog,Professions,T,BindingLabel);ProfessionsPanel.CloseRequested+=CloseModal;ProfessionsPanel.SoundRequested+=OnSound;
   ShopPanel=new ShopPanel(Catalog,Professions,T,BindingLabel);ShopPanel.CloseRequested+=CloseModal;
   FishingView=new FishingView(Catalog,Professions,T,BindingLabel);FishingView.CloseRequested+=CloseModal;
  }
  void DetachProfessions()
  {
   if(Fishing!=null&&Fishing.Active)Fishing.Close();Fishing=null;pendingShop="";
   if(Professions!=null){Professions.Toast-=ShowMessage;Professions.SoundRequested-=OnSound;Professions.SaveRequested-=OnSaveRequested;Professions.Changed-=ProfessionsChanged;}
   Professions=null;ProfessionsPanel=null;ShopPanel=null;FishingView=null;
  }
  void ProfessionsChanged(){World.RefreshRouteState();ProfessionsPanel?.Refresh();}
  void CloseProfessionViews(string keep)
  {
   if(keep!="professions")ProfessionsPanel?.Close();if(keep!="shop")ShopPanel?.Close();
   if(keep!="fishing"&&Fishing!=null&&Fishing.Active)Fishing.Close();
  }
  public void OpenProfessions(string recipe="")
  {
   if(!Running||Professions==null||Gameplay.State.InputLocked)return;UpdateInventoryContext();SetModal("professions");ProfessionsPanel.SetControllerActive(ControllerActive);ProfessionsPanel.Open(recipe);ProfessionsPanel.NotifyOpened(storyInput);
  }
  public bool OpenShop(string shop)
  {
   if(!Running||Professions==null||!Professions.Shops.TryGet(shop??"",out _))return false;SetModal("shop");ShopPanel.SetControllerActive(ControllerActive);bool opened=ShopPanel.Open(shop);ShopPanel.NotifyOpened(storyInput);return opened;
  }
  static bool DeepSpot(RouteTarget target)
  {
   if(target.Fields.TryGet("deep",out var deep)&&deep.Kind=="bool")return deep.AsBool();
   return WorldAccessModel.Get(WorldAccessModel.Get(target.Fields,"obj",target.Fields),"type",FoundationValue.StringValue("")).AsString()=="meer_diepe_visplek";
  }
  public bool StartFishing(string address)
  {
   var target=targets.FirstOrDefault(t=>t.Address==address&&t.Kind=="meer_visplek");if(target==null||Professions==null||Gameplay.State.InputLocked)return false;
   if(Gameplay.State.Count("fishing_rod")<=0){OnSound("error");if(rodHint<=0){rodHint=3;ShowMessage(Translate("Je hebt een hengel nodig. Misschien heeft Visser Joris er een."));}return false;}
   SetModal("fishing");Fishing=new FishingSession(Professions,FishingRandom);Fishing.SoundRequested+=OnSound;FishingView.Bind(Fishing);FishingView.SetControllerActive(ControllerActive);FishingView.NotifyOpened(storyInput);
   return Fishing.Start(DeepSpot(target));
  }
  bool ReadCraftNotes(RouteTarget target)
  {
   string kind=WorldAccessModel.Get(WorldAccessModel.Get(target.Fields,"obj",target.Fields),"kind",FoundationValue.StringValue("")).AsString();if(Professions==null||!Professions.Notes.TryGet(kind,out _))return false;
   if(Professions.Learn(kind))OnSound("pg_pattern");
   SetModal("sign");Hud.SignSpeaker=Professions.NoteName(kind);Hud.SignLines=Professions.NoteLines(kind).ToArray();return true;
  }
  /// <summary>Completes a timed harvest through the source rules; the final check repeats after the animation.</summary>
  bool CompleteHarvest(RouteTarget completed)
  {
   if(Professions==null)return Gameplay.Gather(completed.Id,completed.UniqueKey);
   bool gathered=Professions.Gather(completed.Id,completed.UniqueKey);OnSound(gathered?"coin":"error");return gathered;
  }
  bool HandleProfessionsModal(InputFrame frame)
  {
   if(!ProfessionsModal(Modal))return false;
   if(Modal=="professions"){UpdateInventoryContext();ProfessionsPanel.SetControllerActive(ControllerActive);ProfessionsPanel.HandleInput(frame,inventoryFrameDelta);}
   else if(Modal=="shop"){ShopPanel.SetControllerActive(ControllerActive);ShopPanel.HandleInput(frame,inventoryFrameDelta);}
   else{FishingView.SetControllerActive(ControllerActive);FishingView.HandleInput(frame);}
   return true;
  }
  void TickProfessions(double delta,double uiDelta)
  {
   rodHint=Math.Max(0,rodHint-delta);
   // A shop asked for by a conversation opens once that conversation has closed.
   if(pendingShop!=""&&!Gameplay.DialogueOpen&&(Story==null||!Story.IsExecuting)){string shop=pendingShop;pendingShop="";OpenShop(shop);}
   if(Modal=="fishing"&&Fishing!=null)
   {
    if(!Fishing.Active){CloseModal();return;}
    Fishing.Tick(uiDelta,FishingView.Holding);
   }
  }
 }
}
