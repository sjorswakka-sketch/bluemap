using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Atmosphere
{
 /// <summary>One row of the achievements or bestiary book.</summary>
 public sealed class RecordRow{public string Id,Title,Detail,Mark;public bool Known;}
 /// <summary>The achievements list and the bestiary: what you earned, what you met, and what is still hidden.</summary>
 public sealed class RecordsPanel
 {
  readonly Phase6Catalog catalog;readonly Func<string,string> translate,binding;readonly Func<string,string,string> bilingual;
  InputFrame lastHandled,openingFrame;bool controller;int selected;float scroll;
  public static readonly Rect PanelRect=new Rect(96,40,960,568),ListRect=new Rect(120,116,480,410),DetailRect=new Rect(620,116,412,410);
  public const float RowHeight=41;
  public bool IsOpen {get;private set;} public string Tab {get;private set;}="achievements";public int Selected=>selected;public int Draws {get;private set;} public bool DetailFits {get;private set;}=true;
  public Func<IReadOnlyList<RecordRow>> Achievements {get;set;}=()=>Array.Empty<RecordRow>();public Func<IReadOnlyList<RecordRow>> Beasts {get;set;}=()=>Array.Empty<RecordRow>();
  public event Action CloseRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&StoryUi.Contains(PanelRect,ListRect)&&StoryUi.Contains(PanelRect,DetailRect)&&ListRect.xMax<=DetailRect.x;
  public RecordsPanel(Phase6Catalog sourceCatalog,Func<string,string> translator,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;translate=translator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  public IReadOnlyList<RecordRow> Rows=>Tab=="bestiary"?Beasts():Achievements();
  public void Open(string tab){IsOpen=true;Tab=tab=="bestiary"?"bestiary":"achievements";selected=0;scroll=0;}
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;}
  public void SetControllerActive(bool active){controller=active;}
  public void SetTab(string tab){if(IsOpen){Tab=tab=="bestiary"?"bestiary":"achievements";selected=0;scroll=0;}}
  public void Move(int amount)
  {
   int count=Rows.Count;if(count==0)return;selected=Mathf.Clamp(selected+amount,0,count-1);float top=selected*RowHeight;
   if(top<scroll)scroll=top;else if(top+RowHeight>scroll+ListRect.height)scroll=top+RowHeight-ListRect.height;
  }
  public bool SelectionVisible{get{float top=selected*RowHeight-scroll;return top>=-.1f&&top+RowHeight<=ListRect.height+.1f;}}
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("wereld_prestaties")||frame.Pressed("wereld_beestenboek")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_next_tab")||frame.Pressed("ui_prev_tab")||frame.Pressed("ui_left")||frame.Pressed("ui_right")){SetTab(Tab=="bestiary"?"achievements":"bestiary");return;}
   if(frame.Pressed("ui_down"))Move(1);else if(frame.Pressed("ui_up"))Move(-1);
   if(Math.Abs(frame.UiScroll.y)>.2f)Move(frame.UiScroll.y<0?1:-1);
  }
  public void Draw()
  {
   if(!IsOpen)return;Draws++;var heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.94f,.83f,.61f);var row=StoryUi.Text(catalog,17);var dim=StoryUi.Text(catalog,17);dim.normal.textColor=new Color(.55f,.62f,.68f);
   var small=StoryUi.Text(catalog,14);small.normal.textColor=StoryUi.Quiet;var e=Event.current;var rows=Rows;if(selected>=rows.Count)selected=Math.Max(0,rows.Count-1);
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&e.type==EventType.ScrollWheel){Move(e.delta.y>0?1:-1);e.Use();}
   if(!controller&&e.type==EventType.MouseUp)
   {
    if(e.button==1){e.Use();CloseRequested?.Invoke();return;}
    if(new Rect(620,56,200,36).Contains(e.mousePosition))SetTab("achievements");else if(new Rect(832,56,200,36).Contains(e.mousePosition))SetTab("bestiary");
    else if(ListRect.Contains(e.mousePosition)){int hit=(int)((e.mousePosition.y-ListRect.y+scroll)/RowHeight);if(hit>=0&&hit<rows.Count)selected=hit;}
    e.Use();rows=Rows;
   }
   int known=rows.Count(r=>r.Known);
   StoryUi.Panel(PanelRect);GUI.Label(new Rect(120,52,480,40),translate(Tab=="bestiary"?"Beestenboek":"Prestaties")+"  ·  "+known+" / "+rows.Count,heading);
   StoryUi.Button(new Rect(620,56,200,36),translate("Prestaties"),row,true,Tab=="achievements");StoryUi.Button(new Rect(832,56,200,36),translate("Beestenboek"),row,true,Tab=="bestiary");
   GUI.BeginGroup(ListRect);
   for(int i=0;i<rows.Count;i++)
   {
    var r=new Rect(0,i*RowHeight-scroll,ListRect.width-14,RowHeight-5);if(r.yMax<0||r.y>ListRect.height)continue;
    StoryUi.Button(r,(rows[i].Known?"":"")+rows[i].Title,rows[i].Known?row:dim,true,selected==i);
    if(rows[i].Mark!=""){var mark=new GUIStyle(small){alignment=TextAnchor.MiddleRight};mark.normal.textColor=StoryUi.Gold;GUI.Label(new Rect(r.x,r.y,r.width-10,r.height),rows[i].Mark,mark);}
   }
   GUI.EndGroup();StoryUi.Rail(new Rect(ListRect.x,ListRect.y,ListRect.width-12,ListRect.height),scroll,rows.Count*RowHeight);
   StoryUi.Panel(DetailRect);
   if(rows.Count>0)
   {
    var title=StoryUi.Text(catalog,22);title.normal.textColor=rows[selected].Known?StoryUi.Gold:new Color(.6f,.66f,.72f);GUI.Label(new Rect(DetailRect.x+14,DetailRect.y+12,DetailRect.width-28,34),rows[selected].Title,title);
    var info=StoryUi.Text(catalog,17,true);var box=new Rect(DetailRect.x+14,DetailRect.y+54,DetailRect.width-28,DetailRect.height-68);var content=new GUIContent(rows[selected].Detail);
    while(info.fontSize>12&&info.CalcHeight(content,box.width)>box.height)info.fontSize--;DetailFits=info.CalcHeight(content,box.width)<=box.height+.5f;GUI.Label(box,rows[selected].Detail,info);
   }
   GUI.Label(new Rect(120,568,912,22),binding("ui_prev_tab")+" / "+binding("ui_next_tab")+bilingual(" wisselen · "," switch · ")+binding("ui_cancel")+bilingual(" sluiten"," close"),small);
  }
 }
}
