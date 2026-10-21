using System;
using System.Collections.Generic;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.Story
{
 /// <summary>Presentation-only snapshots. The original story model owns choices, conditions and all actions.</summary>
 public sealed class StoryDialogueView
 {
  public object Token;public string Id="",Speaker="";public IReadOnlyList<string> Lines=Array.Empty<string>(),Choices=Array.Empty<string>();public bool ChoicesReady,FromData=true;public int LineIndex;
 }
 public sealed class StoryQuestEntry
 {
  public string Id="",Title="",Status="",Detail="";public bool IsDone,IsMain,IsFocused;
 }
 internal static class StoryUi
 {
  public static readonly Color Ink=new Color(.90f,.94f,1),Quiet=new Color(.68f,.78f,.86f),Blue=new Color(.55f,.85f,1),Gold=new Color(1,.88f,.35f);
  public static GUIStyle Text(Phase6Catalog catalog,int size,bool wrapped=false)
  {var style=new GUIStyle(GUI.skin.label){font=catalog?.originalFont??GUI.skin.font,fontSize=size,wordWrap=wrapped,richText=false,clipping=TextClipping.Clip,padding=new RectOffset(0,0,0,0),normal={textColor=Ink}};return style;}
  public static void Fill(Rect r,Color c){GUI.color=c;GUI.DrawTexture(r,Texture2D.whiteTexture);GUI.color=Color.white;}
  public static void Border(Rect r,Color c,float width=2){Fill(new Rect(r.x,r.y,r.width,width),c);Fill(new Rect(r.x,r.yMax-width,r.width,width),c);Fill(new Rect(r.x,r.y,width,r.height),c);Fill(new Rect(r.xMax-width,r.y,width,r.height),c);}
  public static void Panel(Rect r,bool focused=false){Fill(r,new Color(.06f,.1f,.22f,.97f));Border(r,focused?Gold:new Color(.32f,.52f,.72f),focused?2:1);}
  public static bool Contains(Rect outer,Rect inner)=>inner.width>=0&&inner.height>=0&&inner.x>=outer.x-.1f&&inner.y>=outer.y-.1f&&inner.xMax<=outer.xMax+.1f&&inner.yMax<=outer.yMax+.1f;
  public static Vector2 Pointer(Vector2 physical)=>new Vector2(physical.x*1152/Math.Max(1,Screen.width),(Screen.height-physical.y)*648/Math.Max(1,Screen.height));
  public static int RuneCount(string value){int count=0;for(int i=0;i<(value??"").Length;i++,count++)if(char.IsHighSurrogate(value[i])&&i+1<value.Length&&char.IsLowSurrogate(value[i+1]))i++;return count;}
  public static string Prefix(string value,int runes){int index=0;while(index<value.Length&&runes-->0){if(char.IsHighSurrogate(value[index])&&index+1<value.Length&&char.IsLowSurrogate(value[index+1]))index++;index++;}return value.Substring(0,index);}
  public static void Rail(Rect view,float offset,float fullHeight)
  {if(fullHeight<=view.height)return;float h=Math.Max(18,view.height*view.height/fullHeight);Fill(new Rect(view.xMax+7,view.y,3,view.height),new Color(.15f,.24f,.36f));Fill(new Rect(view.xMax+7,view.y+(view.height-h)*Mathf.Clamp01(offset/(fullHeight-view.height)),3,h),Blue);}
  public static bool Button(Rect r,string label,GUIStyle style,bool controller,bool selected=false,bool enabled=true)
  {Panel(r,selected);if(selected)Fill(new Rect(r.x+1,r.y+1,4,r.height-2),Gold);float inset=r.width<48?4:12;GUI.Label(new Rect(r.x+inset,r.y+5,r.width-inset*2,r.height-10),label,style);if(controller||!enabled)return false;return Event.current.type==EventType.MouseUp&&Event.current.button==0&&r.Contains(Event.current.mousePosition);}
 }
}
