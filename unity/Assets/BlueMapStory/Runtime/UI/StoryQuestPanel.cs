using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using UnityEngine;
namespace BlueMapMigration.Story
{
 /// <summary>The source's five-row quest ledger with separate details and one optional persisted focus.</summary>
 public sealed class StoryQuestPanel
 {
  public static readonly Rect PanelRect=new Rect(76,68,1000,556),ListViewportRect=new Rect(100,176,420,360),DetailsViewportRect=new Rect(546,176,490,350),FollowRect=new Rect(546,542,490,44),CloseRect=new Rect(1034,84,22,32);
  const float RowHeight=72;readonly Phase6Catalog catalog;readonly Func<string,string> translate,binding;readonly Func<string,string,string> bilingual;IReadOnlyList<StoryQuestEntry> entries=Array.Empty<StoryQuestEntry>();GUIStyle text,title,small,detail;InputFrame lastHandled;int selected,firstRow,focus;float detailsScroll,maxDetailsScroll;double repeatWait,stickWait;bool controller;string selectedId="";
  public event Action<string> ToggleFocusRequested;public event Action CloseRequested;
  public bool IsOpen{get;private set;}public IReadOnlyList<StoryQuestEntry> Entries=>entries;public string SelectedId=>entries.Count==0?"":entries[selected].Id;public int SelectedIndex{get=>selected;set{selected=Mathf.Clamp(value,0,Math.Max(0,entries.Count-1));if(SelectedId!=selectedId){detailsScroll=0;selectedId=SelectedId;}EnsureVisible();}}public int FocusZone=>focus;public int ListScroll=>firstRow;public float DetailsScroll=>detailsScroll;public float MaxDetailsScroll=>maxDetailsScroll;public bool ControllerActive=>controller;public Rect RenderedSelectedBounds{get;private set;}=Rect.zero;public Rect SelectedScreenRect=>entries.Count==0?Rect.zero:new Rect(ListViewportRect.x,ListViewportRect.y+(selected-firstRow)*RowHeight,ListViewportRect.width,RowHeight-6);public bool SelectionVisible=>entries.Count==0||StoryUi.Contains(ListViewportRect,SelectedScreenRect);public bool LayoutFits=>new[]{PanelRect,ListViewportRect,DetailsViewportRect,FollowRect,CloseRect}.All(r=>StoryUi.Contains(new Rect(0,0,1152,648),r));
  public StoryQuestPanel(Phase6Catalog sourceCatalog,Func<string,string> sourceTranslator,Func<string,string,string> textTranslator,Func<string,string> bindingLabel){catalog=sourceCatalog;translate=sourceTranslator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  string T(string nl,string en)=>bilingual(nl,en);
  public void SetEntries(IReadOnlyList<StoryQuestEntry> value){string old=SelectedId;entries=value??Array.Empty<StoryQuestEntry>();int found=entries.ToList().FindIndex(e=>e.Id==old);SelectedIndex=found>=0?found:selected;}
  public void Open(){IsOpen=true;lastHandled=null;focus=0;EnsureVisible();}public void Close(){IsOpen=false;lastHandled=null;}public void SetControllerActive(bool active){controller=active;}public void SetFocus(int zone){focus=Mathf.Clamp(zone,0,3);}public void Tick(double delta){if(!double.IsFinite(delta)||delta<0)return;repeatWait=Math.Max(0,repeatWait-delta);stickWait=Math.Max(0,stickWait-delta);}
  public void MoveSelection(int amount)=>SelectedIndex=selected+amount;public void ScrollDetails(float amount)=>detailsScroll=Mathf.Clamp(detailsScroll+amount,0,maxDetailsScroll);
  void EnsureVisible(){if(selected<firstRow)firstRow=selected;if(selected>=firstRow+5)firstRow=selected-4;firstRow=Mathf.Clamp(firstRow,0,Math.Max(0,entries.Count-5));}
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;controller=frame.ControllerActive;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("quests")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_next_tab"))focus=(focus+1)%4;if(frame.Pressed("ui_prev_tab"))focus=(focus+3)%4;
   int vertical=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0,horizontal=frame.Pressed("ui_right")?1:frame.Pressed("ui_left")?-1:0;
   if(controller&&frame.UiScroll.magnitude>.45&&stickWait<=0){if(Math.Abs(frame.UiScroll.x)>Math.Abs(frame.UiScroll.y))horizontal=Math.Sign(frame.UiScroll.x);else vertical=Math.Sign(frame.UiScroll.y);stickWait=.13;}
   if(!controller&&frame.UiScroll.y!=0){var point=StoryUi.Pointer(frame.MousePosition);if(ListViewportRect.Contains(point)){MoveSelection(frame.UiScroll.y<0?1:-1);focus=0;}else if(DetailsViewportRect.Contains(point)){ScrollDetails(frame.UiScroll.y<0?48:-48);focus=1;}}
   if(vertical==0&&horizontal==0&&repeatWait<=0){if(frame.Held("ui_down"))vertical=1;else if(frame.Held("ui_up"))vertical=-1;if(frame.Held("ui_right"))horizontal=1;else if(frame.Held("ui_left"))horizontal=-1;}
   if(horizontal!=0){focus=horizontal>0?1:0;repeatWait=.16;}if(vertical!=0){if(focus==0)MoveSelection(vertical);else if(focus==1)ScrollDetails(vertical*48);else focus=vertical>0?(focus+1)%4:(focus+3)%4;repeatWait=.16;}
   if(frame.Pressed("ui_accept")||frame.Pressed("interact")){if(focus==3)CloseRequested?.Invoke();else if(entries.Count>0&&!entries[selected].IsDone)ToggleFocusRequested?.Invoke(SelectedId);}
  }
  void Styles(){text=StoryUi.Text(catalog,19,true);title=StoryUi.Text(catalog,24);title.normal.textColor=StoryUi.Blue;small=StoryUi.Text(catalog,15,true);small.normal.textColor=StoryUi.Quiet;detail=StoryUi.Text(catalog,18,true);}
  public void Draw()
  {
   if(!IsOpen)return;Styles();RenderedSelectedBounds=Rect.zero;var e=Event.current;if(controller&&(e.isMouse||e.type==EventType.ScrollWheel))e.Use();if(!controller&&e.type==EventType.MouseDown&&e.button==1){CloseRequested?.Invoke();e.Use();return;}
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(.01f,.025f,.045f,.70f));StoryUi.Panel(PanelRect);GUI.Label(new Rect(100,96,860,36),T("Je opdrachten","Your quests"),title);GUI.Label(new Rect(100,139,936,24),T("Volg één lopende opdracht; je avontuur blijft vrij.","Follow one active quest; your adventure stays open."),small);
   if(StoryUi.Button(CloseRect,"×",text,controller,focus==3)){CloseRequested?.Invoke();e.Use();}
   StoryUi.Panel(ListViewportRect,focus==0);StoryUi.Panel(DetailsViewportRect,focus==1);
   if(!controller&&e.type==EventType.MouseDown&&e.button==0&&DetailsViewportRect.Contains(e.mousePosition)){focus=1;e.Use();}
   if(entries.Count==0){GUI.Label(new Rect(116,192,388,120),T("Je hebt nog geen opdrachten. Praat met de mensen in het dorp!","You have no quests yet. Talk to the people in town!"),text);GUI.Label(new Rect(562,192,458,110),T("Hier verschijnen de stappen, routes en gevolgen van ontdekte opdrachten.","Discovered quests will show their steps, routes and consequences here."),detail);}
   else
   {
    for(int i=firstRow;i<Math.Min(firstRow+5,entries.Count);i++){var q=entries[i];Rect r=new Rect(ListViewportRect.x,ListViewportRect.y+(i-firstRow)*RowHeight,ListViewportRect.width,RowHeight-6);StoryUi.Fill(r,i==selected?new Color(.18f,.3f,.55f):new Color(.1f,.16f,.3f));if(i==selected){StoryUi.Border(r,StoryUi.Gold);RenderedSelectedBounds=r;}var heading=new GUIStyle(text){normal={textColor=q.IsDone?new Color(.55f,1,.65f):new Color(1,.9f,.5f)}};while(heading.fontSize>14&&heading.CalcHeight(new GUIContent(q.Title),392)>33)heading.fontSize--;GUI.Label(new Rect(r.x+12,r.y+4,392,33),(q.IsDone?"✓ ":q.IsFocused?"◆ ":"• ")+q.Title,heading);GUI.Label(new Rect(r.x+12,r.y+39,392,22),q.Status,small);if(!controller&&e.type==EventType.MouseDown&&e.button==0&&r.Contains(e.mousePosition)){SelectedIndex=i;focus=0;e.Use();}}
    float full=detail.CalcHeight(new GUIContent(entries[selected].Detail??""),458);maxDetailsScroll=Math.Max(0,full-318);detailsScroll=Mathf.Clamp(detailsScroll,0,maxDetailsScroll);GUI.BeginGroup(new Rect(562,192,458,318));GUI.Label(new Rect(0,-detailsScroll,458,Math.Max(318,full)),entries[selected].Detail,detail);GUI.EndGroup();StoryUi.Rail(new Rect(562,192,458,318),detailsScroll,full);StoryUi.Rail(ListViewportRect,firstRow*RowHeight,entries.Count*RowHeight);
    string follow=entries[selected].IsDone?T("Deze opdracht is afgerond","This quest is complete"):entries[selected].IsFocused?T("Stop met volgen","Stop following"):T("Volg deze opdracht","Follow this quest");if(StoryUi.Button(FollowRect,follow,text,controller,focus==2,!entries[selected].IsDone)){ToggleFocusRequested?.Invoke(SelectedId);e.Use();}
   }
   GUI.Label(new Rect(100,596,936,22),controller?T("↑ ↓ kiezen · → details · rechterstick scrollen · A volgen · B sluiten","↑ ↓ select · → details · right stick scroll · A follow · B close"):T("↑ ↓ kiezen · → details · muiswiel scrollen · Enter volgen · Esc sluiten","↑ ↓ select · → details · wheel scroll · Enter follow · Esc close"),small);
  }
 }
}
