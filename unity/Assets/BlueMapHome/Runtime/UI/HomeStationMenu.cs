using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Home
{
 /// <summary>The small menu of a home station: rest, design the house or design the yard.</summary>
 public sealed class HomeStationMenu
 {
  readonly Phase6Catalog catalog;readonly Func<string,string> binding;readonly Func<string,string,string> bilingual;
  InputFrame lastHandled,openingFrame;bool controller;int selected,pressed=-1,openedFrame=-1;double repeatWait;
  readonly List<KeyValuePair<string,string>> options=new List<KeyValuePair<string,string>>();
  public static readonly Rect PanelRect=new Rect(246,150,660,348),BodyRect=new Rect(270,208,612,96);
  public const float OptionHeight=46;
  public bool IsOpen {get;private set;} public string Title {get;private set;}="";public string Body {get;private set;}="";public int Selected=>selected;
  public IReadOnlyList<string> OptionIds=>options.Select(v=>v.Key).ToArray();public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  public event Action<string> Chosen;public event Action CloseRequested;
  public static Rect OptionRect(int index)=>new Rect(270,312+index*OptionHeight,612,OptionHeight-8);
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&StoryUi.Contains(PanelRect,BodyRect)&&Enumerable.Range(0,Math.Max(1,options.Count)).All(i=>StoryUi.Contains(PanelRect,OptionRect(i)));
  public HomeStationMenu(Phase6Catalog sourceCatalog,Func<string,string,string> textTranslator,Func<string,string> bindingLabel){catalog=sourceCatalog;bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  public void Open(string title,string body,IEnumerable<KeyValuePair<string,string>> choices)
  {Title=title??"";Body=body??"";options.Clear();options.AddRange(choices);if(options.Count>4)throw new ArgumentException("A station menu holds at most four choices");IsOpen=true;selected=0;pressed=-1;openedFrame=Time.frameCount;}
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressed=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressed=-1;}
  public void MoveSelection(int amount){if(IsOpen&&options.Count>0)selected=(selected+Math.Sign(amount)+options.Count)%options.Count;}
  public bool ActivateSelected(){if(!IsOpen||selected<0||selected>=options.Count)return false;Chosen?.Invoke(options[selected].Key);return true;}
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(double.IsFinite(delta)&&delta>0)repeatWait=Math.Max(0,repeatWait-delta);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseRequested?.Invoke();return;}
   int move=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;if(move!=0){MoveSelection(move);repeatWait=.16;}
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateSelected();
  }
  public void Draw()
  {
   if(!IsOpen)return;var heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.94f,.83f,.61f);var text=StoryUi.Text(catalog,18,true);var row=StoryUi.Text(catalog,20);var small=StoryUi.Text(catalog,15);small.normal.textColor=StoryUi.Quiet;var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hit=-1;for(int i=0;i<options.Count;i++)if(OptionRect(i).Contains(e.mousePosition))hit=i;
    if(e.type==EventType.MouseDown){pressed=-1;if(e.button==1){e.Use();CloseRequested?.Invoke();return;}if(e.button==0&&hit>=0&&openedFrame!=Time.frameCount){pressed=hit;selected=hit;}}
    else{bool activate=e.button==0&&hit>=0&&hit==pressed;pressed=-1;if(activate){selected=hit;ActivateSelected();}}
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Panel(PanelRect);GUI.Label(new Rect(270,164,612,36),Title,heading);GUI.Label(BodyRect,Body,text);
   for(int i=0;i<options.Count;i++){var r=OptionRect(i);StoryUi.Button(r,options[i].Value,row,true,selected==i);if(selected==i)RenderedSelectedBounds=r;}
   GUI.Label(new Rect(270,PanelRect.yMax-26,612,20),binding("ui_accept")+bilingual(" kiezen · "," choose · ")+binding("ui_cancel")+bilingual(" sluiten"," close"),small);
  }
 }
}
