using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Farm
{
 /// <summary>One choice of a garden menu; an unavailable choice stays visible but cannot be picked.</summary>
 public sealed class GardenOption
 {
  public string Id,Label,Info="";public bool Enabled=true;
  public GardenOption(string id,string label,bool enabled=true,string info=""){Id=id;Label=label;Enabled=enabled;Info=info??"";}
 }
 /// <summary>
 /// The menu of the hoe and of every garden station: a title, explanatory lines and up to fourteen choices
 /// in two columns. It is rebuilt after each choice, so counts and progress are always current.
 /// </summary>
 public sealed class GardenMenu
 {
  readonly Phase6Catalog catalog;readonly Func<string,string> binding;readonly Func<string,string,string> bilingual;
  InputFrame lastHandled,openingFrame;bool controller;int selected,pressed=-1,openedFrame=-1;
  readonly List<GardenOption> options=new List<GardenOption>();
  public static readonly Rect PanelRect=new Rect(126,44,900,560);
  public const float OptionHeight=44,ColumnWidth=420;public const int MaxOptions=14;
  public bool IsOpen {get;private set;} public string Role {get;private set;}="";public string Title {get;private set;}="";public string Body {get;private set;}="";
  public int Selected=>selected;public string SelectedId=>selected>=0&&selected<options.Count?options[selected].Id:"";
  public IReadOnlyList<string> OptionIds=>options.Select(v=>v.Id).ToArray();public IReadOnlyList<GardenOption> Options=>options;
  public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;public bool BodyFits {get;private set;}=true;public int Draws {get;private set;}
  public event Action<string> Chosen;public event Action CloseRequested;
  int Rows=>(options.Count+1)/2;
  float GridTop=>PanelRect.yMax-34-Rows*OptionHeight;
  public Rect OptionRect(int index)=>new Rect(PanelRect.x+24+(index%2)*(ColumnWidth+12),GridTop+(index/2)*OptionHeight,ColumnWidth,OptionHeight-6);
  public Rect InfoRect=>new Rect(PanelRect.x+24,GridTop-46,852,40);
  public Rect BodyRect=>new Rect(PanelRect.x+24,PanelRect.y+56,852,Math.Max(0,InfoRect.y-PanelRect.y-62));
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&BodyRect.height>=40&&Enumerable.Range(0,options.Count).All(i=>StoryUi.Contains(PanelRect,OptionRect(i)))&&StoryUi.Contains(PanelRect,InfoRect);
  public GardenMenu(Phase6Catalog sourceCatalog,Func<string,string,string> textTranslator,Func<string,string> bindingLabel){catalog=sourceCatalog;bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  /// <summary>Show a menu; when it is rebuilt for the same role the chosen entry stays under the cursor.</summary>
  public void Open(string role,string title,IEnumerable<string> lines,IEnumerable<GardenOption> choices,string focus=null)
  {
   string keep=focus??(IsOpen&&Role==role?SelectedId:null);bool fresh=!IsOpen;
   Role=role??"";Title=title??"";Body=String.Join("\n",(lines??Array.Empty<string>()).Where(v=>!String.IsNullOrEmpty(v)));options.Clear();options.AddRange(choices);
   if(options.Count>MaxOptions)throw new ArgumentException("A garden menu holds at most fourteen choices");
   IsOpen=true;pressed=-1;if(fresh)openedFrame=Time.frameCount;
   selected=options.FindIndex(v=>v.Id==keep&&v.Enabled);if(selected<0)selected=options.FindIndex(v=>v.Enabled);if(selected<0)selected=0;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressed=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressed=-1;}
  public bool Enabled(string id)=>options.Any(v=>v.Id==id&&v.Enabled);
  public string Label(string id)=>options.FirstOrDefault(v=>v.Id==id)?.Label??"";
  /// <summary>Move through the two columns; unavailable choices are stepped over.</summary>
  public void Move(int dx,int dy)
  {
   if(!IsOpen||options.Count==0)return;int index=selected;
   if(dx!=0){int side=index%2==0?index+1:index-1;if(side>=0&&side<options.Count&&options[side].Enabled)index=side;}
   if(dy!=0){int next=index+dy*2;while(next>=0&&next<options.Count&&!options[next].Enabled)next+=dy*2;if(next>=0&&next<options.Count)index=next;else{int other=index%2==0?index+1:index-1;next=other+dy*2;while(next>=0&&next<options.Count&&!options[next].Enabled)next+=dy*2;if(next>=0&&next<options.Count)index=next;}}
   selected=index;
  }
  public bool Select(string id){int index=options.FindIndex(v=>v.Id==id&&v.Enabled);if(!IsOpen||index<0)return false;selected=index;return true;}
  public bool ActivateSelected(){if(!IsOpen||selected<0||selected>=options.Count||!options[selected].Enabled)return false;Chosen?.Invoke(options[selected].Id);return true;}
  public bool Choose(string id)=>Select(id)&&ActivateSelected();
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("homestead")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_down"))Move(0,1);else if(frame.Pressed("ui_up"))Move(0,-1);else if(frame.Pressed("ui_left")||frame.Pressed("ui_right"))Move(1,0);
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateSelected();
  }
  public void Draw()
  {
   if(!IsOpen)return;Draws++;var heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.94f,.83f,.61f);var row=StoryUi.Text(catalog,17);var off=StoryUi.Text(catalog,17);off.normal.textColor=new Color(.55f,.62f,.68f);
   var small=StoryUi.Text(catalog,15);small.normal.textColor=StoryUi.Quiet;var info=StoryUi.Text(catalog,16,true);info.normal.textColor=new Color(.79f,.87f,.80f);var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hit=-1;for(int i=0;i<options.Count;i++)if(options[i].Enabled&&OptionRect(i).Contains(e.mousePosition))hit=i;
    if(e.type==EventType.MouseDown){pressed=-1;if(e.button==1){e.Use();CloseRequested?.Invoke();return;}if(e.button==0&&hit>=0&&openedFrame!=Time.frameCount){pressed=hit;selected=hit;}}
    else{bool activate=e.button==0&&hit>=0&&hit==pressed;pressed=-1;if(activate){selected=hit;ActivateSelected();}}
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Panel(PanelRect);GUI.Label(new Rect(PanelRect.x+24,PanelRect.y+12,852,38),Title,heading);
   var text=StoryUi.Text(catalog,18,true);var body=BodyRect;var content=new GUIContent(Body);while(text.fontSize>13&&text.CalcHeight(content,body.width)>body.height)text.fontSize--;
   BodyFits=text.CalcHeight(content,body.width)<=body.height+.5f;GUI.Label(body,Body,text);
   if(selected>=0&&selected<options.Count&&options[selected].Info!="")GUI.Label(InfoRect,options[selected].Info,info);
   for(int i=0;i<options.Count;i++){var r=OptionRect(i);StoryUi.Button(r,options[i].Label,options[i].Enabled?row:off,true,selected==i&&options[i].Enabled);if(selected==i)RenderedSelectedBounds=r;}
   GUI.Label(new Rect(PanelRect.x+24,PanelRect.yMax-28,852,20),binding("ui_accept")+bilingual(" kiezen · "," choose · ")+binding("ui_cancel")+bilingual(" sluiten"," close"),small);
  }
 }
}
