using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>The seed book: every crop with its four growth stages, its yield, and seeds to buy at the garden guide.</summary>
 public sealed class SeedBookPanel
 {
  readonly Phase6Catalog catalog;readonly FarmModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;
  InputFrame lastHandled,openingFrame;bool controller;int crop,action,pressedList=-1,pressedAction=-1,openedFrame=-1;bool onActions;
  public static readonly Rect PanelRect=new Rect(126,44,900,560),CardRect=new Rect(444,140,558,128),InfoRect=new Rect(444,274,558,46),DescriptionRect=new Rect(444,324,558,150),StatusRect=new Rect(150,484,852,40),CoinsRect=new Rect(150,412,270,24);
  public const int StarterIndex=8;
  public static readonly string[] ActionIds={"plant","buy1","buy5","harvest","close"};
  public bool IsOpen {get;private set;} public int Draws {get;private set;} public bool DescriptionFits {get;private set;}=true;public int StagesDrawn {get;private set;}
  public IReadOnlyList<string> CropIds=>FarmModel.SeedBook;public string CropId=>crop<CropIds.Count?CropIds[crop]:CropIds[0];
  public int ListIndex=>crop;public bool OnActions=>onActions;public string ActionId=>ActionIds[action];public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  public event Action CloseRequested;public event Action<string> ModeChosen;public event Action<string> SoundRequested;
  public static Rect ListRect(int index)=>index==StarterIndex?new Rect(150,440,270,36):new Rect(150,104+index*38,270,34);
  public static Rect ActionRect(int index)=>new Rect(150+index*172,532,164,38);
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&new[]{CardRect,InfoRect,DescriptionRect,StatusRect,CoinsRect}.All(r=>StoryUi.Contains(PanelRect,r))&&Enumerable.Range(0,9).All(i=>StoryUi.Contains(PanelRect,ListRect(i)))
   &&Enumerable.Range(0,5).All(i=>StoryUi.Contains(PanelRect,ActionRect(i)))&&ListRect(7).yMax<=CoinsRect.y&&CoinsRect.yMax<=ListRect(StarterIndex).y&&ListRect(StarterIndex).yMax<=StatusRect.y&&StatusRect.yMax<=ActionRect(0).y&&DescriptionRect.yMax<=StatusRect.y;
  public SeedBookPanel(Phase6Catalog sourceCatalog,FarmModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  string Tr(string source)=>model.Tr(source);
  public bool Open()
  {
   var state=model.State;if(state.Ended||state.Transitioning||(state.MapId!="village"&&state.MapId!="player_home"))return false;
   IsOpen=true;crop=0;action=0;onActions=false;pressedList=pressedAction=-1;openedFrame=Time.frameCount;return true;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressedList=pressedAction=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressedList=pressedAction=-1;}
  public string CropTitle{get{string group=model.GroupName(CropId);return model.CropName(CropId)+(group!=""?" · "+group:"");}}
  public string Info
  {
   get
   {
    if(CropId=="flower")return Tr("Blijvende bloemen · 60 s groei · voedsel voor bijen");var data=FarmModel.Crop(CropId);double seconds=data.Require("seconds").AsDouble(),repeat=data.TryGet("regrow",out var regrow)?regrow.AsDouble():seconds;
    long yield=data.Require("yield").AsInt64(),bonus=data.TryGet("bonus",out var extra)?extra.AsInt64():0;
    return model.Format("Eerste groei %.0f s · daarna %.0f s · bij je: %d",seconds,repeat,model.State.Count(FarmModel.SeedOf(CropId)))+"\n"+model.Format("Oogst %d · bemest %d · waterbereik %d tegel(s)",yield,yield+bonus,CropId=="apple"?2:1);
   }
  }
  public string Description
  {
   get
   {
    string text=model.Note(CropId);if(!FarmModel.Named(CropId))return text;
    text+="\n"+model.Format("Product: %s",model.Inventory.ItemName(FarmModel.OutputOf(CropId)));
    if(CropId=="carrot"||CropId=="pumpkin")text+=" · "+Tr("Tuinstoofpot in de herberg");else if(CropId=="mint")text+=" · "+Tr("Muntthee in de herberg");else if(CropId=="rosemary")text+=" · "+Tr("Balsem in de bibliotheek");
    return text;
   }
  }
  public string Status{get{string reason=model.SupplyReason();return reason!=""?reason:Tr("Koop bij de tuingids. Groenten geven zaad terug; kruiden en fruit blijven staan.");}}
  public bool CanPlant=>model.State.MapId=="village"&&model.State.Count("hs_hoe")>0&&model.State.Count(FarmModel.SeedOf(CropId))>0;
  public bool CanHarvestMode=>model.State.MapId=="village"&&model.State.Count("hs_hoe")>0;
  public bool StarterReady=>!model.HasOrchardStarter&&model.SupplyReason()==""&&model.OrchardStarterFits;
  public bool ActionEnabled(int index)
  {
   switch(ActionIds[index]){case "plant":return CanPlant;case "buy1":return model.BuyReason(CropId,1)=="";case "buy5":return model.BuyReason(CropId,5)=="";case "harvest":return CanHarvestMode;}
   return true;
  }
  public string ActionLabel(int index)
  {
   switch(ActionIds[index])
   {
    case "plant":return Tr("Kies plantstand");case "buy1":return model.Format("Koop 1 · %d munten",model.Price(CropId));case "buy5":return model.Format("Koop 5 · %d munten",model.Price(CropId)*5);
    case "harvest":return Tr("Oogststand");
   }
   return Tr("Sluiten");
  }
  public void SelectCrop(int index){if(!IsOpen)return;crop=Mathf.Clamp(index,0,StarterIndex);onActions=false;}
  public bool SelectAction(string id){int index=Array.IndexOf(ActionIds,id);if(!IsOpen||index<0||!ActionEnabled(index))return false;action=index;onActions=true;return true;}
  void MoveAction(int direction){int next=action;for(int i=0;i<ActionIds.Length;i++){next+=direction;if(next<0||next>=ActionIds.Length)return;if(ActionEnabled(next)){action=next;return;}}}
  void FocusActions(){onActions=true;if(crop==StarterIndex)crop=0;if(!ActionEnabled(action)){action=0;while(action<ActionIds.Length-1&&!ActionEnabled(action))action++;}}
  public bool Activate()
  {
   if(!IsOpen)return false;
   if(!onActions)
   {
    if(crop==StarterIndex){if(!model.OrchardStarter())return false;SoundRequested?.Invoke("select");return true;}
    FocusActions();return true;
   }
   if(!ActionEnabled(action))return false;
   switch(ActionIds[action])
   {
    case "plant":ModeChosen?.Invoke(CropId);return true;
    case "harvest":ModeChosen?.Invoke("harvest");return true;
    case "buy1":case "buy5":{bool bought=model.Buy(CropId,ActionIds[action]=="buy1"?1:5);if(bought)SoundRequested?.Invoke("select");return bought;}
   }
   CloseRequested?.Invoke();return true;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("homestead")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_prev_tab")){onActions=false;if(crop==StarterIndex)crop=0;}
   else if(frame.Pressed("ui_next_tab"))FocusActions();
   else if(!onActions)
   {
    if(frame.Pressed("ui_down"))crop=Math.Min(StarterIndex,crop+1);else if(frame.Pressed("ui_up"))crop=Math.Max(0,crop-1);else if(frame.Pressed("ui_right")&&crop!=StarterIndex)FocusActions();
   }
   else
   {
    if(frame.Pressed("ui_right"))MoveAction(1);else if(frame.Pressed("ui_left")){int before=action;MoveAction(-1);if(before==action)onActions=false;}else if(frame.Pressed("ui_up"))onActions=false;
   }
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))Activate();
  }
  static void DrawSprite(Sprite sprite,Rect box,float alpha=1)
  {
   if(sprite==null||sprite.texture==null)return;var tr=sprite.textureRect;GUI.color=new Color(1,1,1,alpha);
   GUI.DrawTextureWithTexCoords(box,sprite.texture,new Rect(tr.x/sprite.texture.width,tr.y/sprite.texture.height,tr.width/sprite.texture.width,tr.height/sprite.texture.height));GUI.color=Color.white;
  }
  /// <summary>The growth stage the world would show for this share of the first growth.</summary>
  public static int StageAt(double ratio)=>ratio<.2?0:ratio<.55?1:ratio<1?2:3;
  void DrawCard(GUIStyle small)
  {
   StoryUi.Fill(CardRect,new Color(.16f,.26f,.22f));StoryUi.Border(CardRect,new Color(.47f,.57f,.48f),1);GUI.Label(new Rect(CardRect.x+14,CardRect.y+6,530,20),Tr("Groei op actieve speeltijd · droogte pauzeert veilig"),small);
   double seconds=FarmModel.Crop(CropId).Require("seconds").AsDouble();double[] shares={0,.3,.7,1};int drawn=0;
   for(int i=0;i<4;i++)
   {
    var at=new Rect(CardRect.x+26+i*134,CardRect.y+30,64,64);StoryUi.Fill(new Rect(at.x-8,at.yMax-2,80,1),new Color(.33f,.45f,.34f));
    if(CropId=="apple"){int frame=StageAt(shares[i]);var trunk=catalog.GetSprite("orchard:trunks:"+frame);var crown=catalog.GetSprite("orchard:canopies:"+frame);DrawSprite(trunk,at);DrawSprite(crown,at,.95f);if(trunk!=null&&crown!=null)drawn++;}
    else if(FarmModel.Named(CropId)){var sprite=catalog.GetSprite("crop:"+CropId+":"+StageAt(shares[i]));DrawSprite(sprite,at);if(sprite!=null)drawn++;}
    else{var sprite=GardenArt.Crop(CropId,shares[i]*seconds,seconds,false);DrawSprite(sprite,at);if(sprite!=null)drawn++;}
    GUI.Label(new Rect(at.x-8,at.yMax+2,90,20),model.Format("Fase %d",i+1),small);
   }
   StagesDrawn=drawn;
  }
  public void Draw()
  {
   if(!IsOpen)return;Draws++;var heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.94f,.83f,.61f);var row=StoryUi.Text(catalog,17);var off=StoryUi.Text(catalog,17);off.normal.textColor=new Color(.55f,.62f,.68f);
   var title=StoryUi.Text(catalog,22);var small=StoryUi.Text(catalog,14);small.normal.textColor=new Color(.85f,.87f,.74f);var info=StoryUi.Text(catalog,15,true);var quiet=StoryUi.Text(catalog,15,true);quiet.normal.textColor=StoryUi.Quiet;var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int list=-1,act=-1;for(int i=0;i<=StarterIndex;i++)if(ListRect(i).Contains(e.mousePosition))list=i;for(int i=0;i<ActionIds.Length;i++)if(ActionRect(i).Contains(e.mousePosition)&&ActionEnabled(i))act=i;
    if(e.type==EventType.MouseDown){pressedList=pressedAction=-1;if(e.button==1){e.Use();CloseRequested?.Invoke();return;}if(e.button==0&&openedFrame!=Time.frameCount){pressedList=list;pressedAction=act;if(list>=0&&list<StarterIndex){crop=list;onActions=false;}}}
    else
    {
     bool starter=e.button==0&&list==StarterIndex&&pressedList==StarterIndex,pick=e.button==0&&act>=0&&act==pressedAction;pressedList=pressedAction=-1;
     if(starter){crop=StarterIndex;onActions=false;Activate();crop=0;}else if(pick){action=act;onActions=true;Activate();}
    }
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Panel(PanelRect);GUI.Label(new Rect(150,56,852,38),Tr("Zadenboek · gewassen en boomgaard"),heading);
   for(int i=0;i<StarterIndex;i++){var r=ListRect(i);bool focus=!onActions&&crop==i;StoryUi.Button(r,model.CropName(CropIds[i]),row,true,focus||(onActions&&crop==i));if(focus)RenderedSelectedBounds=r;}
   GUI.Label(CoinsRect,model.Format("Munten: %d",model.State.Coins),row);
   {var r=ListRect(StarterIndex);bool focus=!onActions&&crop==StarterIndex;StoryUi.Button(r,Tr("Gratis beginpakket"),StarterReady?row:off,true,focus);if(focus)RenderedSelectedBounds=r;}
   GUI.Label(new Rect(444,104,558,32),CropTitle,title);DrawCard(small);GUI.Label(InfoRect,Info,info);
   var text=StoryUi.Text(catalog,17,true);var content=new GUIContent(Description);while(text.fontSize>13&&text.CalcHeight(content,DescriptionRect.width)>DescriptionRect.height)text.fontSize--;
   DescriptionFits=text.CalcHeight(content,DescriptionRect.width)<=DescriptionRect.height+.5f;GUI.Label(DescriptionRect,Description,text);
   GUI.Label(StatusRect,crop==StarterIndex&&!onActions?Tr("Eenmalig: twee van elke groente en kruid, één appelboompje en één bosbessenstek."):Status,quiet);
   for(int i=0;i<ActionIds.Length;i++){var r=ActionRect(i);bool enabled=ActionEnabled(i),focus=onActions&&action==i;var label=new GUIStyle(enabled?row:off){fontSize=15};StoryUi.Button(r,ActionLabel(i),label,true,focus&&enabled);if(focus)RenderedSelectedBounds=r;}
   GUI.Label(new Rect(150,578,852,20),binding("ui_prev_tab")+bilingual(" lijst · "," list · ")+binding("ui_next_tab")+bilingual(" knoppen · "," buttons · ")+binding("ui_cancel")+bilingual(" sluiten"," close"),small);
  }
 }
}
