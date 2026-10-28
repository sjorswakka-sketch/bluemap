using System;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Residents
{
 /// <summary>Native view of Mila's existing three-step kitchen. Only the source model can consume ingredients.</summary>
 public sealed class ResidentsKitchenView
 {
  readonly Phase6Catalog catalog;readonly ResidentSocialModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;
  InputFrame lastHandled,openingFrame;bool controller,wasActive,wasWorking;int selected,pressed=-1,openedFrame=-1;double repeatWait,stickWait,clock;long context,pressedContext=-1;
  GUIStyle heading,text,small,button;Texture2D stove,items;
  public static readonly Rect PanelRect=new Rect(196,58,760,532),DetailsRect=new Rect(220,294,712,100),ProgressRect=new Rect(220,404,712,16);
  public static readonly Rect[] ControlRects={new Rect(220,238,350,44),new Rect(582,238,350,44),new Rect(220,434,712,48),new Rect(220,494,712,48)};
  public bool IsOpen=>model.Kitchen?.Active??false;public bool ControllerActive=>controller;public int SelectedControl=>selected;public Rect RenderedSelectedBounds{get;private set;}=Rect.zero;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&StoryUi.Contains(PanelRect,DetailsRect)&&StoryUi.Contains(PanelRect,ProgressRect)&&ControlRects.All(r=>StoryUi.Contains(PanelRect,r));
  public bool SelectionVisible=>!IsOpen||selected>=0&&selected<ControlRects.Length&&StoryUi.Contains(PanelRect,ControlRects[selected]);
  public double PreparationProgress=>model.Kitchen==null?0:model.Kitchen.Stage+(model.Kitchen.Working?Math.Min(model.Kitchen.Elapsed/.9,1):0);
  public ResidentsKitchenView(Phase6Catalog sourceCatalog,ResidentSocialModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);model.KitchenChanged+=SynchronizeFocus;}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);
  bool Enabled(int at){var k=model.Kitchen;if(k==null||!k.Active)return false;if(at==3)return true;if(at<2)return !k.Working;return !k.Working&&k.Dish!=""&&model.CookReason(k.Dish)=="";}
  void SynchronizeFocus()
  {
   bool active=IsOpen,working=model.Kitchen?.Working??false;if(active&&!wasActive){selected=0;openedFrame=Time.frameCount;context++;pressed=-1;}else if(active&&working){selected=3;context++;pressed=-1;}else if(active&&wasWorking){selected=Enabled(2)?2:3;context++;pressed=-1;}wasActive=active;wasWorking=working;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;openedFrame=Time.frameCount;selected=0;context++;pressed=-1;SynchronizeFocus();}
  public void SetControllerActive(bool active){controller=active;if(active)pressed=-1;}
  public void Tick(double delta){if(!double.IsFinite(delta)||delta<0)return;repeatWait=Math.Max(0,repeatWait-delta);stickWait=Math.Max(0,stickWait-delta);if(IsOpen)clock+=delta;SynchronizeFocus();}
  public void MoveSelection(int amount){if(!IsOpen||amount==0)return;for(int i=0;i<4;i++){selected=(selected+Math.Sign(amount)+4)%4;if(Enabled(selected))break;}}
  public bool ActivateSelected()
  {
   if(!Enabled(selected))return false;pressed=-1;context++;if(selected==0||selected==1){model.SelectDish(selected==0?"ls_chowder":"ls_broth");if(Enabled(2))selected=2;return true;}if(selected==2){bool result=model.Prepare();if(result)selected=3;return result;}model.CloseKitchen();return true;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){model.CloseKitchen();return;}
   int move=frame.Pressed("ui_down")||frame.Pressed("ui_right")?1:frame.Pressed("ui_up")||frame.Pressed("ui_left")?-1:0;if(frame.Pressed("ui_next_tab"))move=1;if(frame.Pressed("ui_prev_tab"))move=-1;if(controller&&Math.Abs(frame.UiScroll.y)>.45&&stickWait<=0){move=Math.Sign(frame.UiScroll.y);stickWait=.13;}if(move==0&&repeatWait<=0){if(frame.Held("ui_down"))move=1;else if(frame.Held("ui_up"))move=-1;}if(move!=0){MoveSelection(move);repeatWait=.16;}if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateSelected();
  }
  string Detail()
  {
   var k=model.Kitchen;if(k.Result!="")return k.Result;if(k.Dish=="")return Tr("Stoof geeft meer hartjes; bouillon meer uithoudingsvermogen. De eerste mand is goed voor twee porties. Eén voor de dorpstafel, één voor onderweg.");string ingredients=String.Join(", ",model.Inputs(k.Dish).Entries.Select(row=>Tr(model.Story.Inventory.ItemInfo(row.Key.AsString()).Require("name").AsString())+" ×"+row.Value.AsInt64()));string reason=model.CookReason(k.Dish);return Tr(model.Story.Inventory.ItemDescription(k.Dish))+"\n"+ingredients+(reason==""?"":"\n"+reason);
  }
  void Styles(){heading=StoryUi.Text(catalog,28);heading.normal.textColor=new Color(.93f,.8f,.59f);text=StoryUi.Text(catalog,20,true);small=StoryUi.Text(catalog,17,true);small.normal.textColor=StoryUi.Quiet;button=StoryUi.Text(catalog,22,true);}
  void Sprite(Texture2D texture,Rect rect,int frame,int cellWidth,int cellHeight){if(texture==null)return;GUI.DrawTextureWithTexCoords(rect,texture,new Rect((float)(frame*cellWidth)/texture.width,(float)(texture.height-cellHeight)/texture.height,(float)cellWidth/texture.width,(float)cellHeight/texture.height));}
  void PreparationArt()
  {
   if(catalog!=null&&stove==null)stove=catalog.textures.FirstOrDefault(v=>v.definition.id=="png:assets/ls_stove.png")?.texture;if(catalog!=null&&items==null)items=catalog.textures.FirstOrDefault(v=>v.definition.id=="png:assets/ls_items.png")?.texture;Sprite(stove,new Rect(546,158,60,60),(int)(clock*3)%2,24,24);Sprite(items,new Rect(664,178,40,40),model.Kitchen.Dish=="ls_broth"?2:1,16,16);StoryUi.Fill(new Rect(414,196,56,16),new Color(.69f,.55f,.36f));for(int i=0;i<3;i++)StoryUi.Fill(new Rect(420+i*14,197,8,8),new Color(.55f,.68f,.45f));if(model.Kitchen.Working){if(model.Kitchen.Stage==0)StoryUi.Fill(new Rect(424,181-(float)Math.Abs(Math.Sin(clock*12))*14,20,5),new Color(.86f,.89f,.85f));else if(model.Kitchen.Stage==1)StoryUi.Fill(new Rect(573+(float)Math.Sin(clock*7)*8,164,4,23),new Color(.87f,.74f,.53f));}
  }
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {int hit=Array.FindIndex(ControlRects,r=>r.Contains(e.mousePosition));if(e.type==EventType.MouseDown){pressed=-1;if(e.button==1){model.CloseKitchen();e.Use();return;}if(e.button==0&&hit>=0&&Enabled(hit)&&openedFrame!=Time.frameCount){pressed=selected=hit;pressedContext=context;}}else{bool activate=e.button==0&&hit>=0&&hit==pressed&&pressedContext==context;pressed=-1;if(activate){selected=hit;ActivateSelected();}}e.Use();if(!IsOpen)return;}
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(.02f,.04f,.07f,.8f));StoryUi.Panel(PanelRect);GUI.Label(new Rect(220,74,712,38),Tr("Koken met Mila"),heading);GUI.Label(new Rect(220,118,712,28),Tr("Kies je gerecht. Snijden → roeren → opscheppen."),text);PreparationArt();RenderedSelectedBounds=ControlRects[selected];
   string[] labels={Tr(model.Story.Inventory.ItemInfo("ls_chowder").Require("name").AsString()),Tr(model.Story.Inventory.ItemInfo("ls_broth").Require("name").AsString()),model.Kitchen.Dish==""?Tr("Kies eerst een gerecht"):Tr(new[]{"Snijden","Roeren","Opscheppen"}[Math.Min(2,model.Kitchen.Stage)]),Tr("Sluiten — ongebruikte ingrediënten blijven in je tas")};
   for(int i=0;i<4;i++){var style=new GUIStyle(button);if(!Enabled(i))style.normal.textColor=new Color(.42f,.5f,.56f);while(style.fontSize>17&&style.CalcHeight(new GUIContent(labels[i]),ControlRects[i].width-24)>ControlRects[i].height-10)style.fontSize--;StoryUi.Button(ControlRects[i],labels[i],style,true,selected==i,Enabled(i));}
   string detail=Detail();var detailStyle=new GUIStyle(text);while(detailStyle.fontSize>16&&detailStyle.CalcHeight(new GUIContent(detail),DetailsRect.width)>DetailsRect.height)detailStyle.fontSize--;GUI.BeginGroup(DetailsRect);GUI.Label(new Rect(0,0,DetailsRect.width,DetailsRect.height),detail,detailStyle);GUI.EndGroup();StoryUi.Fill(ProgressRect,new Color(.12f,.2f,.25f));StoryUi.Fill(new Rect(ProgressRect.x,ProgressRect.y,ProgressRect.width*(float)(PreparationProgress/3),ProgressRect.height),new Color(.76f,.89f,.76f));GUI.Label(new Rect(220,554,712,22),binding("ui_accept")+T(" kiezen / bereiden · "," choose / prepare · ")+binding("ui_cancel")+T(" sluiten"," close"),small);
  }
 }
}
