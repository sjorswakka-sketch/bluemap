using System;
using UnityEngine;
namespace BlueMapMigration.Story
{
 /// <summary>Actual OnGUI source-text census. The production panel renders unchanged original strings without executing their story actions.</summary>
 public sealed class StoryLayoutProbeHost:MonoBehaviour
 {
  public Action Render;public bool HasRepaint;public Exception Error;
  void OnGUI(){if(Render==null)return;var old=GUI.matrix;int depth=GUI.depth;try{GUI.depth=-10000;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1152f,Screen.height/648f,1));Render();if(Event.current.type==EventType.Repaint)HasRepaint=true;}catch(Exception e){Error=e;Render=null;}finally{GUI.matrix=old;GUI.depth=depth;}}
 }
}
