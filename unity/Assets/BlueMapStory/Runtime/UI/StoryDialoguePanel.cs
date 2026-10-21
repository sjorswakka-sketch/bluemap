using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using UnityEngine;
namespace BlueMapMigration.Story
{
 /// <summary>Source60-codepoint/s dialogue window. Input reveals before advancing; model callbacks commit actions.</summary>
 public sealed class StoryDialoguePanel
 {
  readonly Phase6Catalog catalog;readonly Func<string,string> translate,format,binding;readonly Func<string,string,string> bilingual;
  StoryDialogueView view;object token;string nodeId="",fullText="",speaker="";IReadOnlyList<string> choices=Array.Empty<string>();int lineIndex=-1,selected,consumedPointerFrame=-1,openedPointerFrame=-1,guiPointerFrame=-1;double shown,repeatWait,stickWait;bool controller,ready;InputFrame lastHandled,openingFrame;float textScroll,choiceScroll,fullTextHeight;float[] rowHeights=Array.Empty<float>();GUIStyle text,title,small,choiceText;
  long choiceContext,pressedChoiceContext=-1;int pressedChoice=-1;
  public event Action AdvanceRequested,CloseRequested;public event Action<int> ChoiceRequested;
  public bool IsOpen=>view!=null;public bool IsRevealed=>VisibleCharacters>=StoryUi.RuneCount(fullText);public int VisibleCharacters=>(int)Math.Min(StoryUi.RuneCount(fullText),Math.Floor(shown));public string DisplayedText=>StoryUi.Prefix(fullText,VisibleCharacters);public string FullText=>fullText;public string Speaker=>speaker;public int SelectedChoice{get=>selected;set{selected=Mathf.Clamp(value,0,Math.Max(0,choices.Count-1));EnsureChoiceVisible();}}public IReadOnlyList<string> Choices=>choices;
  public bool ControllerActive=>controller;public float TextScroll=>textScroll;public float ChoiceScroll=>choiceScroll;public float MaxTextScroll=>Math.Max(0,fullTextHeight-TextViewportRect.height);public float MaxChoiceScroll=>Math.Max(0,rowHeights.Sum()-ChoiceViewportRect.height);public Rect PanelRect{get;private set;}=new Rect(60,420,1032,202);public Rect TextViewportRect{get;private set;}=new Rect(84,472,984,92);public Rect ChoiceViewportRect{get;private set;}=Rect.zero;public Rect RenderedSelectedBounds{get;private set;}=Rect.zero;public Rect ContinueRect{get;private set;}=Rect.zero;
  public bool SelectionVisible=>!ready||choices.Count==0||StoryUi.Contains(ChoiceViewportRect,SelectedChoiceRect);public Rect SelectedChoiceRect{get{if(!ready||rowHeights.Length!=choices.Count||choices.Count==0)return Rect.zero;float y=ChoiceViewportRect.y-choiceScroll;for(int i=0;i<selected;i++)y+=rowHeights[i];return new Rect(ChoiceViewportRect.x,y,ChoiceViewportRect.width,rowHeights[selected]-4);}}public bool LayoutFits=>!IsOpen||StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&StoryUi.Contains(PanelRect,TextViewportRect)&&(!ready||StoryUi.Contains(PanelRect,ChoiceViewportRect));
  public StoryDialoguePanel(Phase6Catalog sourceCatalog,Func<string,string> sourceTranslator,Func<string,string,string> textTranslator,Func<string,string> sourceFormatter,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;translate=sourceTranslator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);format=sourceFormatter??(s=>s);binding=bindingLabel??(s=>s);}
  string T(string nl,string en)=>bilingual(nl,en);string Text(string value)=>format(view.FromData?translate(value??""):value??"");
  public void SetView(StoryDialogueView next)
  {
   if(next==null){view=null;token=null;nodeId="";lastHandled=null;openingFrame=null;pressedChoice=-1;choiceContext++;return;}
   bool newNode=view==null||(next.Token!=null||token!=null?!ReferenceEquals(token,next.Token):nodeId!=next.Id);bool newLine=newNode||lineIndex!=next.LineIndex;bool newChoices=newNode||!ready&&next.ChoicesReady;
   bool wasReady=ready;var oldChoices=choices;view=next;token=next.Token;nodeId=next.Id??"";lineIndex=next.LineIndex;ready=next.ChoicesReady;speaker=next.FromData?translate(next.Speaker??""):next.Speaker??"";fullText=next.Lines.Count==0?"":Text(next.Lines[Mathf.Clamp(lineIndex,0,next.Lines.Count-1)]);choices=next.Choices.Select(Text).ToArray();
   if(newLine||wasReady!=ready||!oldChoices.SequenceEqual(choices)){choiceContext++;pressedChoice=-1;}if(newLine){shown=0;textScroll=0;openedPointerFrame=Time.frameCount;}if(newChoices){selected=0;choiceScroll=0;openedPointerFrame=Time.frameCount;}if(ready)shown=StoryUi.RuneCount(fullText);selected=Mathf.Clamp(selected,0,Math.Max(0,choices.Count-1));if(text!=null)Layout();
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;openedPointerFrame=Time.frameCount;}
  public void SetControllerActive(bool active){controller=active;if(active)pressedChoice=-1;}
  public void Tick(double delta){if(!IsOpen||!double.IsFinite(delta)||delta<0)return;shown=Math.Min(StoryUi.RuneCount(fullText),shown+delta*60);repeatWait=Math.Max(0,repeatWait-delta);stickWait=Math.Max(0,stickWait-delta);}
  public void Reveal(){shown=StoryUi.RuneCount(fullText);}
  public void Advance(){if(!IsOpen||ready)return;if(!IsRevealed){Reveal();return;}AdvanceRequested?.Invoke();}
  public void MoveChoice(int amount){if(!ready||choices.Count==0)return;SelectedChoice=((selected+amount)%choices.Count+choices.Count)%choices.Count;}
  public void ScrollText(float delta){textScroll=Mathf.Clamp(textScroll+delta,0,MaxTextScroll);}
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseRequested?.Invoke();return;}
   bool accept=frame.Pressed("ui_accept")||frame.Pressed("interact");int vertical=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;
   if(controller&&Math.Abs(frame.UiScroll.y)>.45&&stickWait<=0){if(ready)vertical=Math.Sign(frame.UiScroll.y);else ScrollText(Math.Sign(frame.UiScroll.y)*48);stickWait=.13;}
   if(!controller&&frame.UiScroll.y!=0){Vector2 point=StoryUi.Pointer(frame.MousePosition);if(ready&&ChoiceViewportRect.Contains(point))MoveChoice(frame.UiScroll.y<0?1:-1);else if(TextViewportRect.Contains(point))ScrollText(frame.UiScroll.y<0?48:-48);}
   if(ready){if(vertical==0&&repeatWait<=0){if(frame.Held("ui_down"))vertical=1;else if(frame.Held("ui_up"))vertical=-1;}if(vertical!=0){MoveChoice(vertical);repeatWait=.16;}if(frame.Pressed("ui_next_tab"))MoveChoice(1);if(frame.Pressed("ui_prev_tab"))MoveChoice(-1);if(accept&&choices.Count>0){consumedPointerFrame=Time.frameCount;ChoiceRequested?.Invoke(selected);}}
   else if(accept||frame.Pressed("attack")){if(!accept&&!controller&&guiPointerFrame==Time.frameCount)return;consumedPointerFrame=Time.frameCount;Advance();}
  }
  void Styles(){text=StoryUi.Text(catalog,24,true);title=StoryUi.Text(catalog,22);title.normal.textColor=StoryUi.Blue;small=StoryUi.Text(catalog,16,true);small.normal.textColor=StoryUi.Quiet;choiceText=StoryUi.Text(catalog,22,true);}
  void Layout()
  {
   fullTextHeight=Math.Max(fullText==""?0:28,text.CalcHeight(new GUIContent(fullText),984));float body=Mathf.Clamp(fullTextHeight,fullText==""?0:64,ready?132:340);rowHeights=choices.Select(c=>Math.Max(44,choiceText.CalcHeight(new GUIContent(c),960)+18)).ToArray();float choicesHeight=ready?Math.Min(284,rowHeights.Sum()):0;float height=Math.Max(196,52+body+(ready?choicesHeight+10:0)+52);PanelRect=new Rect(60,622-height,1032,height);TextViewportRect=new Rect(84,PanelRect.y+52,984,body);ChoiceViewportRect=ready?new Rect(84,TextViewportRect.yMax+10,984,choicesHeight):Rect.zero;ContinueRect=new Rect(858,PanelRect.yMax-40,210,30);textScroll=Mathf.Clamp(textScroll,0,MaxTextScroll);EnsureChoiceVisible();
  }
  void EnsureChoiceVisible(){if(!ready||choices.Count==0||rowHeights.Length!=choices.Count)return;float top=0;for(int i=0;i<selected;i++)top+=rowHeights[i];float bottom=top+rowHeights[selected];if(top<choiceScroll)choiceScroll=top;if(bottom>choiceScroll+ChoiceViewportRect.height)choiceScroll=bottom-ChoiceViewportRect.height;choiceScroll=Mathf.Clamp(choiceScroll,0,MaxChoiceScroll);}
  public void Draw()
  {
   if(!IsOpen)return;Styles();Layout();RenderedSelectedBounds=Rect.zero;var e=Event.current;bool pointerRelease=!controller&&e.type==EventType.MouseUp&&e.button==0;if(!controller&&e.type==EventType.MouseDown&&e.button==0)pressedChoice=-1;if(controller&&(e.isMouse||e.type==EventType.ScrollWheel))e.Use();
   if(!controller&&e.type==EventType.MouseDown&&PanelRect.Contains(e.mousePosition)&&e.button==1&&openedPointerFrame!=Time.frameCount){CloseRequested?.Invoke();e.Use();return;}
   StoryUi.Panel(PanelRect);StoryUi.Border(PanelRect,new Color(.45f,.75f,1),3);GUI.Label(new Rect(84,PanelRect.y+12,950,30),speaker,title);
   GUI.BeginGroup(TextViewportRect);GUI.Label(new Rect(0,-textScroll,TextViewportRect.width,Math.Max(fullTextHeight,TextViewportRect.height)),DisplayedText,text);GUI.EndGroup();StoryUi.Rail(TextViewportRect,textScroll,fullTextHeight);
   if(ready)
   {GUI.BeginGroup(ChoiceViewportRect);float y=-choiceScroll;var clip=new Rect(0,0,ChoiceViewportRect.width,ChoiceViewportRect.height);for(int i=0;i<choices.Count;i++){var r=new Rect(0,y,ChoiceViewportRect.width,rowHeights[i]-4);if(i==selected)RenderedSelectedBounds=new Rect(r.x+ChoiceViewportRect.x,r.y+ChoiceViewportRect.y,r.width,r.height);bool released=StoryUi.Button(r,choices[i],choiceText,controller,i==selected);if(!controller&&e.type==EventType.MouseDown&&e.button==0&&openedPointerFrame!=Time.frameCount&&clip.Contains(e.mousePosition)&&r.Contains(e.mousePosition)){pressedChoice=i;pressedChoiceContext=choiceContext;e.Use();}if(released){if(pressedChoice==i&&pressedChoiceContext==choiceContext&&clip.Contains(e.mousePosition)){selected=i;consumedPointerFrame=Time.frameCount;pressedChoice=-1;ChoiceRequested?.Invoke(i);e.Use();break;}e.Use();}y+=rowHeights[i];}GUI.EndGroup();StoryUi.Rail(ChoiceViewportRect,choiceScroll,rowHeights.Sum());GUI.Label(new Rect(84,PanelRect.yMax-34,984,25),T("↑ ↓ kiezen · ","↑ ↓ choose · ")+binding("ui_accept")+T(" bevestigen · "," confirm · ")+binding("ui_cancel")+T(" sluiten"," close"),small);}
   else
   {GUI.Label(new Rect(84,PanelRect.yMax-34,746,25),(Math.Max(0,lineIndex)+1)+" / "+Math.Max(1,view.Lines.Count)+" · "+binding("ui_accept")+T(" / klik verder · "," / click continue · ")+binding("ui_cancel")+T(" sluiten"," close"),small);if(StoryUi.Button(ContinueRect,IsRevealed?T("Verder  ▾","Continue  ▾"):T("Alles tonen","Show all"),small,controller))e.Use();}
   // The source panel acts once on press, including its continue affordance. Release must not advance again.
   if(!controller&&!ready&&e.type==EventType.MouseDown&&e.button==0&&PanelRect.Contains(e.mousePosition)){if(openedPointerFrame!=Time.frameCount&&consumedPointerFrame!=Time.frameCount){guiPointerFrame=consumedPointerFrame=Time.frameCount;Advance();}e.Use();}
   if(pointerRelease)pressedChoice=-1;
  }
 }
}
