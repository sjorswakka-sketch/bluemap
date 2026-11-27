using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Professions
{
 /// <summary>
 /// Native view of the original professions book: seven trades, their recipes, the material goal and
 /// food and drink. Only the source model crafts or consumes; this view reads and asks.
 /// </summary>
 public sealed class ProfessionsPanel
 {
  public sealed class Entry
  {
   public string Kind="",Id="",Title="",Status="";public bool Ready;
  }
  readonly Phase6Catalog catalog;readonly ProfessionsModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;
  InputFrame lastHandled,openingFrame;bool controller;int column=1,skillIndex,entryIndex,pressedRow=-1,pressedColumn=-1,openedFrame=-1;float scroll,detailScroll;double repeatWait,stickWait;
  List<Entry> entries=new List<Entry>();GUIStyle heading,text,small,row,detail;
  public const float RowHeight=74,SkillHeight=50;
  public static readonly Rect PanelRect=new Rect(36,26,1080,596),SkillsRect=new Rect(56,134,252,420),ListRect=new Rect(324,134,424,420),DetailRect=new Rect(768,134,328,362),GoalRect=new Rect(768,506,328,48),HintRect=new Rect(56,582,1040,24);
  public bool IsOpen {get;private set;} public bool Supplies {get;private set;} public string SelectedSkill {get;private set;}="";
  public int Column=>column;public int SkillIndex=>skillIndex;public int EntryIndex=>entryIndex;public float Scroll=>scroll;public bool ControllerActive=>controller;
  public IReadOnlyList<Entry> Entries=>entries;public Entry Current=>column==1&&entryIndex>=0&&entryIndex<entries.Count?entries[entryIndex]:null;
  public string LastSound {get;private set;}="";public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  public event Action CloseRequested;public event Action<string> SoundRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&new[]{SkillsRect,ListRect,DetailRect,GoalRect,HintRect}.All(r=>StoryUi.Contains(PanelRect,r))&&SkillsRect.xMax<=ListRect.x&&ListRect.xMax<=DetailRect.x&&DetailRect.yMax<=GoalRect.y&&model.SkillIds.Count*SkillHeight+SkillHeight<=SkillsRect.height;
  public bool SelectionVisible{get{if(!IsOpen||column!=1||entries.Count==0)return true;float top=entryIndex*RowHeight-scroll;return top>=-.1f&&top+RowHeight<=ListRect.height+.1f;}}
  public ProfessionsPanel(Phase6Catalog sourceCatalog,ProfessionsModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);string Text(string key)=>Tr(model.Catalogs.Require("text").Require(key).AsString());
  IReadOnlyList<string> Skills=>model.SkillIds;
  /// <summary>Opens on a recipe, else on the saved material goal, else on the first trade.</summary>
  public void Open(string recipe="")
  {
   string focus=model.Recipes.TryGet(recipe??"",out _)?recipe:model.Goal;
   if(focus!=""){SelectedSkill=model.Recipes.Require(focus).Require("skill").AsString();Supplies=false;}
   else if(SelectedSkill==""||!Skills.Contains(SelectedSkill))SelectedSkill=Skills[0];
   skillIndex=Math.Max(0,Skills.ToList().IndexOf(SelectedSkill));IsOpen=true;column=1;scroll=0;detailScroll=0;pressedRow=-1;openedFrame=Time.frameCount;Refresh();
   entryIndex=focus==""?0:Math.Max(0,entries.FindIndex(e=>e.Id==focus));if(entries.Count==0)column=0;KeepVisible();
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressedRow=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressedRow=-1;}
  public void Tick(double delta){if(!double.IsFinite(delta)||delta<0)return;repeatWait=Math.Max(0,repeatWait-delta);stickWait=Math.Max(0,stickWait-delta);}
  public void Refresh()
  {
   string keep=Current?.Id??"";var list=new List<Entry>();
   if(Supplies)
   {
    foreach(string item in model.Consumables)if(model.State.Count(item)>0){string reason=model.Inventory.UseReason(item);list.Add(new Entry{Kind="use",Id=item,Title=ProfessionsModel.Fill(Text("use"),model.ItemName(item),model.State.Count(item)),Status=reason,Ready=reason==""});}
   }
   else
   {
    if(SelectedSkill=="fishing")foreach(string fish in new[]{"meer_baars","meer_snoek","meer_gouden_karper"})list.Add(new Entry{Kind="fish",Id=fish,Title=ProfessionsModel.Fill(Tr("%s · bij je: %d"),model.ItemName(fish),model.State.Count(fish)),Status="",Ready=true});
    foreach(string id in model.RecipeIds)
    {
     var recipe=model.Recipes.Require(id);if(recipe.Require("skill").AsString()!=SelectedSkill)continue;string reason=model.CraftReason(id);long amount=recipe.TryGet("amount",out var n)?n.AsInt64():1;
     list.Add(new Entry{Kind="recipe",Id=id,Ready=reason=="",Title=ProfessionsModel.Fill(Text("recipe_line"),model.ItemName(recipe.Require("output").AsString()),amount,model.SkillName(SelectedSkill),recipe.Require("level").AsInt64()),
      Status=ProfessionsModel.Fill(Tr("Materialen compleet: %d/%d"),model.IngredientsReady(id),recipe.Require("inputs").Entries.Count)+"\n"+(reason==""?Text("ready"):reason)});
    }
   }
   entries=list;if(keep!=""){int at=entries.FindIndex(e=>e.Id==keep);if(at>=0)entryIndex=at;}
   entryIndex=entries.Count==0?0:Math.Max(0,Math.Min(entries.Count-1,entryIndex));if(entries.Count==0&&column==1)column=0;KeepVisible();
  }
  void KeepVisible()
  {
   float full=entries.Count*RowHeight,max=Math.Max(0,full-ListRect.height);float top=entryIndex*RowHeight;
   if(top<scroll)scroll=top;else if(top+RowHeight>scroll+ListRect.height)scroll=top+RowHeight-ListRect.height;scroll=Mathf.Clamp(scroll,0,max);
  }
  public void SelectSkill(int index)
  {
   // The last row of the left column is the food and drink page.
   if(index>=Skills.Count){Supplies=true;skillIndex=Skills.Count;}else{Supplies=false;skillIndex=Math.Max(0,index);SelectedSkill=Skills[skillIndex];}
   entryIndex=0;scroll=0;detailScroll=0;Refresh();
  }
  public void ToggleSupplies(){if(Supplies)SelectSkill(Math.Max(0,Skills.ToList().IndexOf(SelectedSkill)));else SelectSkill(Skills.Count);column=entries.Count>0?1:0;}
  public void MoveSelection(int amount)
  {
   if(!IsOpen||amount==0)return;detailScroll=0;
   if(column==0)SelectSkill((skillIndex+Math.Sign(amount)+Skills.Count+1)%(Skills.Count+1));
   else if(column==1&&entries.Count>0){entryIndex=Math.Max(0,Math.Min(entries.Count-1,entryIndex+Math.Sign(amount)));KeepVisible();}
  }
  public void MoveColumn(int amount)
  {
   if(!IsOpen||amount==0)return;int next=Math.Max(0,Math.Min(2,column+Math.Sign(amount)));if(next==1&&entries.Count==0)next=amount>0?2:0;if(next==2&&!GoalAvailable)next=column;column=next;
  }
  public bool GoalAvailable=>!Supplies&&entries.Count>0&&entries[Math.Min(entryIndex,entries.Count-1)].Kind=="recipe";
  public string GoalLabel{get{if(!GoalAvailable)return T("Kies een recept voor een materiaaldoel","Choose a recipe for a material goal");return model.Goal==entries[entryIndex].Id?T("Materiaaldoel wissen","Clear material goal"):T("Als materiaaldoel volgen","Track as material goal");}}
  public bool ToggleGoal(){if(!GoalAvailable)return false;model.ToggleGoal(entries[entryIndex].Id);Refresh();return true;}
  void Play(string sound){LastSound=sound;SoundRequested?.Invoke(sound);}
  public bool ActivateSelected()
  {
   if(!IsOpen)return false;pressedRow=-1;
   if(column==0){if(entries.Count>0)column=1;return true;}
   if(column==2)return ToggleGoal();
   var entry=Current;if(entry==null)return false;
   if(entry.Kind=="recipe"){bool made=model.Craft(entry.Id);Play(made?(model.Recipes.Require(entry.Id).Require("skill").AsString()=="smithing"?"pg_forge":"buy"):"error");Refresh();return made;}
   if(entry.Kind=="use"){bool used=model.Inventory.UseItem(entry.Id);Play(used?"drink":"error");Refresh();return used;}
   return false;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);Tick(delta);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("crafting")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_next_tab")||frame.Pressed("ui_prev_tab")){ToggleSupplies();return;}
   if(frame.Pressed("ui_left"))MoveColumn(-1);else if(frame.Pressed("ui_right"))MoveColumn(1);
   int move=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;
   if(move==0&&repeatWait<=0){if(frame.Held("ui_down"))move=1;else if(frame.Held("ui_up"))move=-1;}
   if(move!=0){MoveSelection(move);repeatWait=.16;}
   if(controller&&Math.Abs(frame.UiScroll.y)>.45&&stickWait<=0){detailScroll=Math.Max(0,detailScroll-Math.Sign(frame.UiScroll.y)*36);stickWait=.08;}
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateSelected();
  }
  public string DetailText()
  {
   if(column==0||entries.Count==0)
   {
    if(Supplies)return entries.Count==0?Text("none"):Tr("Proviand · eten en drinken");
    var p=model.Progress(SelectedSkill);return model.SkillDescription(SelectedSkill)+"\n"+(p.AtMax?Text("master"):ProfessionsModel.Fill(Text("xp"),p.Current,p.Needed))+"\n\n"+model.Intro(SelectedSkill);
   }
   var entry=entries[Math.Min(entryIndex,entries.Count-1)];
   if(entry.Kind=="recipe")return model.RecipeText(entry.Id);
   if(entry.Kind=="use")return Tr(model.Inventory.ItemDescription(entry.Id))+(entry.Status==""?"":"\n"+entry.Status);
   return Tr(model.Inventory.ItemDescription(entry.Id));
  }
  void Styles()
  {
   heading=StoryUi.Text(catalog,28);text=StoryUi.Text(catalog,18,true);small=StoryUi.Text(catalog,15,true);small.normal.textColor=StoryUi.Quiet;row=StoryUi.Text(catalog,17,true);detail=StoryUi.Text(catalog,17,true);
  }
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;string accentId=Supplies?"cooking":SelectedSkill;Color accent=model.Accent(accentId);
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&e.type==EventType.ScrollWheel){if(ListRect.Contains(e.mousePosition)){scroll=Mathf.Clamp(scroll+e.delta.y*24,0,Math.Max(0,entries.Count*RowHeight-ListRect.height));}else if(DetailRect.Contains(e.mousePosition))detailScroll=Math.Max(0,detailScroll+e.delta.y*24);e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hitColumn=-1,hit=-1;
    if(SkillsRect.Contains(e.mousePosition)){hitColumn=0;hit=(int)((e.mousePosition.y-SkillsRect.y)/SkillHeight);if(hit>Skills.Count)hit=-1;}
    else if(ListRect.Contains(e.mousePosition)){hitColumn=1;hit=(int)((e.mousePosition.y-ListRect.y+scroll)/RowHeight);if(hit>=entries.Count)hit=-1;}
    else if(GoalRect.Contains(e.mousePosition)){hitColumn=2;hit=0;}
    if(e.type==EventType.MouseDown){pressedRow=-1;if(e.button==1){e.Use();CloseRequested?.Invoke();return;}if(e.button==0&&hit>=0&&openedFrame!=Time.frameCount){pressedRow=hit;pressedColumn=hitColumn;}}
    else
    {
     bool activate=e.button==0&&hit>=0&&hit==pressedRow&&hitColumn==pressedColumn;pressedRow=-1;
     if(activate)
     {
      if(hitColumn==0)SelectSkill(hit);
      else if(hitColumn==1){bool same=column==1&&entryIndex==hit;column=1;entryIndex=hit;detailScroll=0;KeepVisible();if(same)ActivateSelected();}
      else{column=2;ToggleGoal();column=1;}
     }
    }
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(.02f,.04f,.07f,.8f));StoryUi.Panel(PanelRect);StoryUi.Border(PanelRect,accent,2);
   heading.normal.textColor=Color.Lerp(accent,Color.white,.15f);GUI.Label(new Rect(56,40,1040,36),Supplies?Tr("Proviand · eten en drinken"):model.Title(SelectedSkill),heading);
   GUI.Label(new Rect(56,80,1040,44),Supplies?Text("intro"):model.Intro(SelectedSkill),text);
   // Trades with their level and progress to the next one.
   for(int i=0;i<=Skills.Count;i++)
   {
    var r=new Rect(SkillsRect.x,SkillsRect.y+i*SkillHeight,SkillsRect.width,SkillHeight-6);bool active=Supplies?i==Skills.Count:i==skillIndex;bool focused=column==0&&active;
    StoryUi.Panel(r,focused);if(active)StoryUi.Fill(new Rect(r.x+1,r.y+1,4,r.height-2),accent);
    if(i==Skills.Count){GUI.Label(new Rect(r.x+12,r.y+11,r.width-24,24),Text("supplies"),row);continue;}
    var p=model.Progress(Skills[i]);GUI.Label(new Rect(r.x+12,r.y+5,r.width-24,22),ProfessionsModel.Fill(Text("skill_line"),model.SkillName(Skills[i]),p.Level),row);
    var bar=new Rect(r.x+12,r.yMax-11,r.width-24,5);StoryUi.Fill(bar,new Color(.12f,.2f,.25f));StoryUi.Fill(new Rect(bar.x,bar.y,bar.width*(p.AtMax?1f:p.Needed<=0?0f:Mathf.Clamp01((float)p.Current/p.Needed)),bar.height),model.Accent(Skills[i]));
    if(focused)RenderedSelectedBounds=r;
   }
   // Recipes, catch cards or food and drink.
   GUI.BeginGroup(ListRect);
   for(int i=0;i<entries.Count;i++)
   {
    var r=new Rect(0,i*RowHeight-scroll,ListRect.width-14,RowHeight-6);if(r.yMax<0||r.y>ListRect.height)continue;bool focused=column==1&&i==entryIndex;
    StoryUi.Panel(r,focused);if(i==entryIndex)StoryUi.Fill(new Rect(r.x+1,r.y+1,4,r.height-2),accent);
    var title=new GUIStyle(row);if(!entries[i].Ready)title.normal.textColor=new Color(.7f,.75f,.82f);
    GUI.Label(new Rect(r.x+12,r.y+4,r.width-24,22),entries[i].Title,title);if(entries[i].Status!="")GUI.Label(new Rect(r.x+12,r.y+26,r.width-24,r.height-28),entries[i].Status,small);
    if(focused)RenderedSelectedBounds=new Rect(ListRect.x+r.x,ListRect.y+r.y,r.width,r.height);
   }
   if(entries.Count==0)GUI.Label(new Rect(0,0,ListRect.width-14,ListRect.height),Supplies?Text("none"):model.SkillDescription(SelectedSkill),text);
   GUI.EndGroup();StoryUi.Rail(new Rect(ListRect.x,ListRect.y,ListRect.width-10,ListRect.height),scroll,entries.Count*RowHeight);
   // Sources, stock within reach and the effect of the selected line.
   StoryUi.Panel(DetailRect);string body=DetailText();float bodyHeight=detail.CalcHeight(new GUIContent(body),DetailRect.width-24);detailScroll=Mathf.Clamp(detailScroll,0,Math.Max(0,bodyHeight-(DetailRect.height-16)));
   GUI.BeginGroup(new Rect(DetailRect.x+12,DetailRect.y+8,DetailRect.width-24,DetailRect.height-16));GUI.Label(new Rect(0,-detailScroll,DetailRect.width-24,bodyHeight),body,detail);GUI.EndGroup();
   bool goalFocused=column==2;var goal=new GUIStyle(row);if(!GoalAvailable)goal.normal.textColor=new Color(.42f,.5f,.56f);StoryUi.Button(GoalRect,GoalLabel,goal,true,goalFocused,GoalAvailable);if(goalFocused)RenderedSelectedBounds=GoalRect;
   GUI.Label(HintRect,binding("ui_accept")+T(" maken / gebruiken · "," make / use · ")+binding("ui_prev_tab")+"/"+binding("ui_next_tab")+T(" eten & drinken · "," food & drink · ")+binding("ui_cancel")+T(" sluiten"," close"),small);
  }
 }
}
