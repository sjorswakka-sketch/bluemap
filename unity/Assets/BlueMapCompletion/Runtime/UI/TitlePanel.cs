using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
using UnityEngine.InputSystem;
namespace BlueMapMigration.Completion
{
 /// <summary>The title screen: continue, new game, New Game+, sound, controls, saves, quit and the language button.</summary>
 public sealed class TitlePanel
 {
  /// <summary>Entries in the order of the original menu; the language button sits apart in the corner.</summary>
  public static readonly string[] Entries={"continue","new","new_plus","sound","controls","saves","quit","language"};
  readonly Phase6Catalog catalog;readonly Func<string,string,string> bilingual;
  float nextMove,nextUse;bool wasAccept=true;int lastFrame=-1;
  public bool Visible {get;private set;} public int Focus {get;private set;} public int Draws {get;private set;} public bool LayoutFits {get;private set;}=true;
  public string Version {get;set;}="";public string Notice {get;set;}="";
  public Func<bool> CanContinue {get;set;}=()=>false;public Func<bool> CanNewGamePlus {get;set;}=()=>false;public Func<bool> Muted {get;set;}=()=>false;public Func<string> Locale {get;set;}=()=>"nl";
  public event Action<string> Chosen;
  public TitlePanel(Phase6Catalog sourceCatalog,Func<string,string,string> textTranslator){catalog=sourceCatalog;bilingual=textTranslator??((nl,en)=>nl);}
  public bool Enabled(string id)=>id=="continue"?CanContinue():id!="new_plus"||CanNewGamePlus();
  public string Label(string id)
  {
   switch(id)
   {
    case "continue":return bilingual("Doorgaan","Continue");case "new":return bilingual("Nieuw spel","New game");case "new_plus":return bilingual("Nieuw spel+","New Game+");
    case "sound":return Muted()?bilingual("Geluid: uit","Sound: off"):bilingual("Geluid: aan","Sound: on");case "controls":return bilingual("Bediening","Controls");
    case "saves":return bilingual("Opslag en import","Saves and import");case "quit":return bilingual("Afsluiten","Quit");
    default:return Locale()=="en"?"Language: English":"Taal: Nederlands";
   }
  }
  public void Show(){Visible=true;Focus=Array.IndexOf(Entries,CanContinue()?"continue":"new");wasAccept=true;nextUse=Time.unscaledTime+.25f;nextMove=nextUse;}
  public void Hide(){Visible=false;}
  /// <summary>Move to the next entry that can be used; the list wraps, so the language button is reachable from both ends.</summary>
  public void Move(int step)
  {for(int i=0;i<Entries.Length;i++){Focus=(Focus+step+Entries.Length)%Entries.Length;if(Enabled(Entries[Focus]))return;}}
  public bool Activate(string id){if(!Visible||Array.IndexOf(Entries,id)<0||!Enabled(id))return false;Focus=Array.IndexOf(Entries,id);Chosen?.Invoke(id);return true;}
  public static Rect EntryRect(string id)
  {
   switch(id)
   {
    case "continue":return new Rect(406,262,340,46);case "new":return new Rect(406,316,166,46);case "new_plus":return new Rect(580,316,166,46);
    case "sound":return new Rect(406,370,340,46);case "controls":return new Rect(406,424,340,46);case "saves":return new Rect(406,478,340,46);
    case "quit":return new Rect(406,532,340,46);default:return new Rect(886,16,250,44);
   }
  }
  void Navigate(PlayerInputSource input)
  {
   if(lastFrame==Time.frameCount)return;lastFrame=Time.frameCount;
   if(!Application.isFocused){wasAccept=true;nextUse=Time.unscaledTime+.2f;nextMove=nextUse;return;}
   bool controller=input!=null&&input.ControllerActive;var pad=controller?InputSystem.GetDeviceById(input.ControllerDeviceId) as Gamepad:null;var keyboard=controller?null:Keyboard.current;
   bool accept=pad!=null?pad.buttonSouth.isPressed:keyboard!=null&&(keyboard.enterKey.isPressed||keyboard.eKey.isPressed||keyboard.spaceKey.isPressed);
   int vertical=pad!=null?(pad.dpad.down.isPressed||pad.leftStick.y.ReadValue()<-.5f?1:pad.dpad.up.isPressed||pad.leftStick.y.ReadValue()>.5f?-1:0)
    :keyboard!=null?(keyboard.downArrowKey.isPressed||keyboard.sKey.isPressed?1:keyboard.upArrowKey.isPressed||keyboard.wKey.isPressed?-1:0):0;
   if(vertical!=0&&Time.unscaledTime>=nextMove){Move(vertical);nextMove=Time.unscaledTime+.18f;}
   if(accept&&!wasAccept&&Time.unscaledTime>=nextUse){Activate(Entries[Focus]);nextUse=Time.unscaledTime+.2f;}
   wasAccept=accept;
  }
  public void Draw(PlayerInputSource input)
  {
   if(!Visible)return;Navigate(input);if(!Visible)return;Draws++;var screen=new Rect(0,0,1152,648);bool controller=input!=null&&input.ControllerActive;
   StoryUi.Fill(screen,new Color(.04f,.07f,.15f));StoryUi.Fill(new Rect(0,430,1152,218),new Color(.05f,.10f,.17f));
   for(int i=0;i<9;i++)StoryUi.Fill(new Rect(96+i*124,96+(i*53)%70,3,3),new Color(.7f,.9f,1,.5f));
   var title=StoryUi.Text(catalog,72);title.alignment=TextAnchor.MiddleCenter;title.normal.textColor=new Color(.7f,.92f,1);GUI.Label(new Rect(0,56,1152,96),"Bluemap Quest",title);
   var subtitle=StoryUi.Text(catalog,26);subtitle.alignment=TextAnchor.MiddleCenter;subtitle.normal.textColor=new Color(.85f,.9f,1);GUI.Label(new Rect(0,156,1152,40),bilingual("Een kleine fantasy-quest","A small fantasy quest"),subtitle);
   bool fits=true;
   foreach(string id in Entries)
   {
    if(id=="new_plus"&&!CanNewGamePlus())continue;var rect=EntryRect(id);if(id=="new"&&!CanNewGamePlus())rect=new Rect(406,316,340,46);
    fits&=StoryUi.Contains(screen,rect);var style=StoryUi.Text(catalog,id=="language"?18:22);style.alignment=TextAnchor.MiddleCenter;
    bool enabled=Enabled(id);if(!enabled)style.normal.textColor=new Color(.5f,.56f,.64f);
    if(StoryUi.Button(rect,Label(id),style,controller,Focus==Array.IndexOf(Entries,id),enabled))Activate(id);
   }
   var small=StoryUi.Text(catalog,16);small.alignment=TextAnchor.MiddleCenter;small.normal.textColor=StoryUi.Quiet;
   if(Notice!="")GUI.Label(new Rect(126,212,900,40),Notice,small);
   GUI.Label(new Rect(0,600,1152,26),controller?bilingual("Linkerstick / D-pad kiezen  ·  A bevestigen","Left stick / D-pad select  ·  A confirm"):bilingual("W/S of pijlen kiezen  ·  Enter of E bevestigen  ·  muis werkt ook","W/S or arrows select  ·  Enter or E confirm  ·  mouse works too"),small);
   var version=StoryUi.Text(catalog,14);version.alignment=TextAnchor.MiddleRight;version.normal.textColor=StoryUi.Quiet;GUI.Label(new Rect(886,620,250,22),Version,version);
   LayoutFits=fits;
  }
 }
}
