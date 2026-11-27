using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Home
{
 /// <summary>
 /// Native view of the original yard designer: move the existing work stations, lay paths, fences and
 /// gates, and unlock building room. Crops, channels, storage and open routes are never overwritten.
 /// </summary>
 public sealed class YardEditorPanel
 {
  readonly Phase6Catalog catalog;readonly HomeModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;readonly Func<Vector2> player;
  InputFrame lastHandled,openingFrame;bool controller,rowMode;int zone,kindIndex,actionIndex,view,extensionIndex,pressedZone=-1,pressedIndex=-1,openedFrame=-1;double repeatWait;GUIStyle heading,text,small,row;
  FoundationValue draft,candidate;string reason="";HomeCell cursor=new HomeCell(8,26),start=new HomeCell(-99,-99);string[] ids=Array.Empty<string>();
  public const float RowHeight=27,ActionHeight=37;
  public static readonly Rect PanelRect=new Rect(16,10,1120,628),ListRect=new Rect(30,76,250,11*RowHeight),DetailRect=new Rect(30,382,250,196),PlanRect=new Rect(296,76,600,380),ActionsRect=new Rect(912,76,214,10*ActionHeight),StatusRect=new Rect(296,466,830,44),CountsRect=new Rect(296,514,830,40),HintRect=new Rect(30,604,1096,22);
  public static readonly string[] ActionIds={"place","pack","row","view","make","extension","expand","apply","reset","cancel"};
  public bool IsOpen {get;private set;} public string Kind=>ids[kindIndex];public HomeCell Cursor=>cursor;public int Zone=>zone;public int View=>view;public bool RowMode=>rowMode;public string Reason=>reason;public int ActionIndex=>actionIndex;
  public FoundationValue Draft=>draft;public bool ControllerActive=>controller;public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  public event Action CloseRequested;public event Action Applied;public event Action<string> SoundRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&new[]{ListRect,DetailRect,PlanRect,ActionsRect,StatusRect,CountsRect,HintRect}.All(r=>StoryUi.Contains(PanelRect,r))&&ListRect.xMax<=PlanRect.x&&PlanRect.xMax<=ActionsRect.x&&ListRect.yMax<=DetailRect.y&&PlanRect.yMax<=StatusRect.y&&StatusRect.yMax<=CountsRect.y&&DetailRect.yMax<=HintRect.y;
  public YardEditorPanel(Phase6Catalog sourceCatalog,HomeModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel,Func<Vector2> playerPosition)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);player=playerPosition??(()=>Vector2.zero);}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);
  static string Fill(string text,params object[] values){foreach(var v in values){int a=text.IndexOf("%s",StringComparison.Ordinal),b=text.IndexOf("%d",StringComparison.Ordinal),i=a<0?b:b<0?a:Math.Min(a,b);if(i<0)break;text=text.Substring(0,i)+Convert.ToString(v,System.Globalization.CultureInfo.InvariantCulture)+text.Substring(i+2);}return text;}
  bool IsUnit(string kind)=>model.Units.TryGet(kind,out _);
  string Field(string kind)=>model.IsPath(kind)?"paths":"fences";
  string ExtensionId=>model.ExtensionIds[extensionIndex];
  HomeRect Region{get{var r=model.Yard.Require("views").Items[view].Items;return new HomeRect((int)r[0].AsInt64(),(int)r[1].AsInt64(),(int)r[2].AsInt64(),(int)r[3].AsInt64());}}
  float CellSize{get{var r=Region;return Mathf.Floor(Mathf.Min(PlanRect.width/r.W,PlanRect.height/r.H));}}
  public bool Open()
  {
   if(model.State.MapId!="village"||model.State.Transitioning)return false;
   ids=model.UnitIds.Concat(model.YardPieceIds).ToArray();draft=model.YardState();IsOpen=true;zone=0;actionIndex=0;view=0;rowMode=false;openedFrame=Time.frameCount;pressedIndex=-1;Choose(0);return true;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressedIndex=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressedIndex=-1;}
  public void Choose(int index)
  {
   if(!IsOpen||index<0||index>=ids.Length)return;kindIndex=index;start=new HomeCell(-99,-99);
   if(IsUnit(Kind)){var at=model.Anchor(Kind,draft);if(at.X>=0){cursor=at;view=at.Y<23?1:0;}}
   Refresh();
  }
  void ClampCursor(){var r=Region;cursor=new HomeCell(Math.Max(r.X,Math.Min(r.EndX-1,cursor.X)),Math.Max(r.Y,Math.Min(r.EndY-1,cursor.Y)));}
  public void ChangeView(){view=(view+1)%model.Yard.Require("views").Items.Count;ClampCursor();start=new HomeCell(-99,-99);Refresh();}
  public void MoveCursor(int dx,int dy){cursor=cursor.Offset(dx,dy);ClampCursor();Refresh();}
  /// <summary>A row runs straight from the last placed piece to the marker, at most forty tiles.</summary>
  public IReadOnlyList<HomeCell> StrokeCells()
  {
   var cells=new List<HomeCell>{cursor};if(IsUnit(Kind)||!rowMode||start.X<0)return cells;
   int dx=cursor.X-start.X,dy=cursor.Y-start.Y;if(dx!=0&&dy!=0)return cells;
   cells.Clear();int length=Math.Min(40,Math.Abs(dx)+Math.Abs(dy));for(int i=0;i<=length;i++)cells.Add(start.Offset(Math.Sign(dx)*i,Math.Sign(dy)*i));return cells;
  }
  public FoundationValue Proposal()
  {
   if(IsUnit(Kind))return InventoryModel.Replace(draft,"stations",InventoryModel.Replace(draft.Require("stations"),Kind,FoundationValue.Array(new[]{FoundationValue.Integer(cursor.X),FoundationValue.Integer(cursor.Y)})));
   string field=Field(Kind);var pieces=draft.Require(field);foreach(var at in StrokeCells())pieces=InventoryModel.Replace(pieces,at.Key,FoundationValue.StringValue(Kind));return InventoryModel.Replace(draft,field,pieces);
  }
  public void Refresh()
  {
   if(!IsOpen)return;var live=model.YardView;draft=InventoryModel.Replace(InventoryModel.Replace(draft,"owned",live.Require("owned")),"extensions",live.Require("extensions"));
   candidate=Proposal();reason=model.YardLayoutReason(candidate,model.FarmCells,live);
   if(!IsUnit(Kind)&&rowMode&&start.X>=0&&cursor.X!=start.X&&cursor.Y!=start.Y)reason=Tr("Een rij loopt recht; kies dezelfde rij of kolom.");
   if(reason=="")reason=model.ActorReason(candidate,player());
  }
  public bool Place(){if(!IsOpen)return false;Refresh();if(reason!="")return false;draft=candidate;start=cursor;Refresh();SoundRequested?.Invoke("select");return true;}
  public bool Pack()
  {
   if(!IsOpen)return false;
   if(IsUnit(Kind)){if(draft.Require("stations").Require(Kind).Items.Count==0)return false;draft=InventoryModel.Replace(draft,"stations",InventoryModel.Replace(draft.Require("stations"),Kind,FoundationValue.Array(Array.Empty<FoundationValue>())));}
   else{string field=Field(Kind);if(!draft.Require(field).TryGet(cursor.Key,out _))return false;draft=InventoryModel.Replace(draft,field,InventoryModel.Replace(draft.Require(field),cursor.Key,null,true));}
   start=new HomeCell(-99,-99);Refresh();return true;
  }
  public bool MakeParts(){if(!IsOpen||IsUnit(Kind)||!model.MakeParts(model.GroupOf(Kind)))return false;Refresh();SoundRequested?.Invoke("select");return true;}
  public bool Expand(){if(!IsOpen||!model.Expand(ExtensionId))return false;Refresh();SoundRequested?.Invoke("select");return true;}
  public bool PickAt(HomeCell at)
  {
   foreach(string id in model.UnitIds){var anchor=model.Anchor(id,draft);if(anchor.X>=0&&HomeModel.Bounds(anchor).Has(at)){Choose(Array.IndexOf(ids,id));return true;}}
   if(draft.Require("fences").TryGet(at.Key,out var fence))Choose(Array.IndexOf(ids,fence.AsString()));else if(draft.Require("paths").TryGet(at.Key,out var path))Choose(Array.IndexOf(ids,path.AsString()));
   cursor=at;ClampCursor();Refresh();return true;
  }
  public bool Apply()
  {
   if(!IsOpen)return false;string problem=model.YardLayoutReason(draft,model.FarmCells,model.YardView);if(problem=="")problem=model.ActorReason(draft,player());
   if(problem!=""){reason=problem;return false;}
   if(!model.ApplyYard(draft,player()))return false;SoundRequested?.Invoke("select");Close();Applied?.Invoke();return true;
  }
  public void ResetDraft(){var live=model.YardView;draft=InventoryModel.Replace(InventoryModel.Replace(model.YardDefaults(),"owned",live.Require("owned")),"extensions",live.Require("extensions"));start=new HomeCell(-99,-99);Refresh();}
  string CostText(FoundationValue cost)=>String.Join(" · ",cost.Entries.Select(row=>model.ItemName(row.Key.AsString())+" "+model.Inventory.Available(row.Key.AsString())+"/"+row.Value.AsInt64()));
  bool Owned(string extension)=>draft.Require("extensions").Items.Any(v=>v.AsString()==extension);
  bool ActionEnabled(string id)
  {
   switch(id)
   {
    case "place":return reason=="";
    case "pack":return IsUnit(Kind)?draft.Require("stations").Require(Kind).Items.Count>0:draft.Require(Field(Kind)).TryGet(cursor.Key,out _);
    case "row":return !IsUnit(Kind);
    case "make":if(IsUnit(Kind))return false;var supply=model.Supplies.Require(model.GroupOf(Kind));return model.MaterialReason(supply.Require("cost"))==""&&draft.Require("owned").Require(model.GroupOf(Kind)).AsInt64()+supply.Require("amount").AsInt64()<=supply.Require("cap").AsInt64();
    case "expand":return !Owned(ExtensionId)&&model.MaterialReason(model.Extensions.Require(ExtensionId).Require("cost"))=="";
   }
   return true;
  }
  string ActionLabel(string id)
  {
   switch(id)
   {
    case "place":return Tr("Bevestig plek");case "pack":return IsUnit(Kind)?T("Berg werkplek op","Store work station"):T("Haal deel weg","Remove piece");
    case "row":return (rowMode?"✓ ":"")+T("Hele rij leggen","Lay a whole row");
    case "view":return Tr(model.Yard.Require("viewNames").Items[view].AsString());
    case "make":return IsUnit(Kind)?Tr("Maak bouwdelen"):Fill(Tr("Maak %d bouwdelen"),model.Supplies.Require(model.GroupOf(Kind)).Require("amount").AsInt64());
    case "extension":return Tr(model.Extensions.Require(ExtensionId).Require("name").AsString());
    case "expand":return Owned(ExtensionId)?Tr("Bouwruimte al beschikbaar"):Fill(Tr("Ontsluit %s"),Tr(model.Extensions.Require(ExtensionId).Require("name").AsString()));
    case "apply":return Tr("Toepassen en opslaan");case "reset":return T("Beginindeling bekijken","View starting layout");
   }
   return Tr("Annuleren");
  }
  public bool Activate(string id)
  {
   if(!IsOpen||!ActionEnabled(id))return false;
   switch(id)
   {
    case "place":return Place();case "pack":return Pack();case "row":rowMode=!rowMode;start=new HomeCell(-99,-99);Refresh();return true;case "view":ChangeView();return true;case "make":return MakeParts();
    case "extension":extensionIndex=(extensionIndex+1)%model.ExtensionIds.Count;Refresh();return true;case "expand":return Expand();case "apply":return Apply();case "reset":ResetDraft();return true;
   }
   CloseRequested?.Invoke();return true;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(double.IsFinite(delta)&&delta>0)repeatWait=Math.Max(0,repeatWait-delta);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("menu")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_next_tab"))zone=(zone+1)%3;else if(frame.Pressed("ui_prev_tab"))zone=(zone+2)%3;
   int dx=frame.Pressed("ui_right")?1:frame.Pressed("ui_left")?-1:0,dy=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;
   if(dx==0&&dy==0&&repeatWait<=0){if(frame.Held("ui_right"))dx=1;else if(frame.Held("ui_left"))dx=-1;else if(frame.Held("ui_down"))dy=1;else if(frame.Held("ui_up"))dy=-1;}
   if(dx!=0||dy!=0)
   {
    repeatWait=.12;
    if(zone==1)MoveCursor(dx,dy);
    else if(dy!=0){if(zone==0)Choose((kindIndex+dy+ids.Length)%ids.Length);else actionIndex=(actionIndex+dy+ActionIds.Length)%ActionIds.Length;}
    else zone=Math.Max(0,Math.Min(2,zone+dx));
   }
   if(frame.Pressed("ui_accept")||frame.Pressed("interact")){if(zone==0)zone=1;else if(zone==1)Place();else Activate(ActionIds[actionIndex]);}
  }
  public string DetailText()
  {
   var lines=new List<string>();
   if(IsUnit(Kind))
   {
    var unit=model.Units.Require(Kind);lines.Add(Tr(unit.Require("name").AsString()));lines.Add(Tr(unit.Require("desc").AsString()));
    lines.Add(draft.Require("stations").Require(Kind).Items.Count==0?Tr("Opgeborgen; productie blijft bewaard."):Tr("Bestaande werkplek · geen nieuwe machine"));
   }
   else
   {
    var info=model.YardPieces.Require(Kind);string group=model.GroupOf(Kind);long owned=draft.Require("owned").Require(group).AsInt64();
    lines.Add(Tr(info.Require("name").AsString()));lines.Add(Fill(Tr("Delen vrij: %d · totaal: %d"),owned-model.Used(draft,group),owned));lines.Add(CostText(model.Supplies.Require(group).Require("cost")));lines.Add(Tr(info.Require("desc").AsString()));
   }
   return String.Join("\n",lines);
  }
  public string StatusText()=>reason!=""?reason:Tr("Plek past. Ontwerp eerst; pas toe als je tevreden bent.");
  public string CountsText()=>Fill(Tr("Paden %d/80 · hek/poort %d/40 · uitbreiding: %s"),draft.Require("paths").Entries.Count,draft.Require("fences").Entries.Count,Tr(model.Extensions.Require(ExtensionId).Require("name").AsString())+" · "+CostText(model.Extensions.Require(ExtensionId).Require("cost")));
  void Styles(){heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.89f,.8f,.63f);text=StoryUi.Text(catalog,16,true);small=StoryUi.Text(catalog,14,true);small.normal.textColor=StoryUi.Quiet;row=StoryUi.Text(catalog,15);}
  Rect CellRect(HomeCell cell){var r=Region;float s=CellSize;return new Rect(PlanRect.x+(cell.X-r.X)*s,PlanRect.y+(cell.Y-r.Y)*s,s,s);}
  static Color TerrainColor(string terrain)
  {
   switch(terrain){case ".":return new Color(.36f,.52f,.33f);case ",":case "=":return new Color(.66f,.58f,.43f);case "~":return new Color(.27f,.47f,.62f);case "b":case "n":return new Color(.55f,.42f,.3f);case "T":case "D":return new Color(.25f,.4f,.27f);}
   return new Color(.3f,.3f,.29f);
  }
  static Color PieceColor(string kind)
  {
   switch(kind){case "gravel":return new Color(.74f,.7f,.62f);case "stone":return new Color(.6f,.63f,.66f);case "boards":return new Color(.67f,.5f,.33f);}
   return new Color(.5f,.36f,.24f);
  }
  void DrawPieces(FoundationValue data,float alpha)
  {
   var region=Region;float s=CellSize;
   foreach(var path in data.Require("paths").Entries){var at=HomeModel.ParseCell(path.Key.AsString());if(!region.Has(at))continue;var c=CellRect(at);var color=PieceColor(path.Value.AsString());color.a=alpha;StoryUi.Fill(new Rect(c.x+1,c.y+1,c.width-2,c.height-2),color);}
   foreach(var fence in data.Require("fences").Entries)
   {
    var at=HomeModel.ParseCell(fence.Key.AsString());if(!region.Has(at))continue;var c=CellRect(at);string kind=fence.Value.AsString();bool vertical=kind.EndsWith("_v",StringComparison.Ordinal);var color=model.IsGate(kind)?new Color(.86f,.74f,.4f,alpha):new Color(.42f,.28f,.17f,alpha);
    StoryUi.Fill(vertical?new Rect(c.x+s*.62f,c.y,Math.Max(3,s*.2f),s):new Rect(c.x,c.y+s*.62f,s,Math.Max(3,s*.2f)),color);
   }
   foreach(string id in model.UnitIds)
   {
    var anchor=model.Anchor(id,data);if(anchor.X<0)continue;var bounds=HomeModel.Bounds(anchor);var a=CellRect(new HomeCell(bounds.X,bounds.Y));var area=new Rect(a.x,a.y,s*3,s*3);
    StoryUi.Border(area,new Color(.85f,.78f,.55f,alpha*.7f),1);var c=CellRect(anchor);StoryUi.Fill(new Rect(c.x+2,c.y+2,c.width-4,c.height-4),id=="hive"?new Color(.89f,.76f,.4f,alpha):id=="compost"?new Color(.5f,.39f,.25f,alpha):new Color(.6f,.42f,.6f,alpha));
   }
  }
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;var region=Region;float s=CellSize;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hitZone=-1,hit=-1;var planArea=new Rect(PlanRect.x,PlanRect.y,region.W*s,region.H*s);
    if(ListRect.Contains(e.mousePosition)){hitZone=0;hit=(int)((e.mousePosition.y-ListRect.y)/RowHeight);}
    else if(planArea.Contains(e.mousePosition)){hitZone=1;hit=(int)((e.mousePosition.y-PlanRect.y)/s)*region.W+(int)((e.mousePosition.x-PlanRect.x)/s);}
    else if(ActionsRect.Contains(e.mousePosition)){hitZone=2;hit=(int)((e.mousePosition.y-ActionsRect.y)/ActionHeight);}
    if(e.type==EventType.MouseDown){pressedIndex=-1;if(e.button==0&&hit>=0&&openedFrame!=Time.frameCount){pressedZone=hitZone;pressedIndex=hit;}else if(e.button==1&&hitZone==1){PickAt(new HomeCell(region.X+hit%region.W,region.Y+hit/region.W));zone=1;}}
    else
    {
     bool activate=e.button==0&&hit>=0&&hit==pressedIndex&&hitZone==pressedZone;pressedIndex=-1;
     if(activate)
     {
      zone=hitZone;
      if(hitZone==0)Choose(hit);
      else if(hitZone==1){var at=new HomeCell(region.X+hit%region.W,region.Y+hit/region.W);if(at.Equals(cursor))Place();else{cursor=at;Refresh();}}
      else{actionIndex=hit;Activate(ActionIds[hit]);}
     }
    }
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(.025f,.04f,.045f,.9f));StoryUi.Panel(PanelRect);
   GUI.Label(new Rect(30,20,1096,34),T("Je erf · rustig inrichten","Your yard · design at ease"),heading);GUI.Label(new Rect(30,52,250,22),T("Werkplekken en bouwdelen","Work stations and parts"),small);
   for(int i=0;i<ids.Length;i++)
   {
    var r=new Rect(ListRect.x,ListRect.y+i*RowHeight,ListRect.width,RowHeight-3);bool focused=zone==0&&i==kindIndex;StoryUi.Panel(r,focused);if(i==kindIndex)StoryUi.Fill(new Rect(r.x+1,r.y+1,4,r.height-2),StoryUi.Gold);
    string name=IsUnit(ids[i])?Tr(model.Units.Require(ids[i]).Require("name").AsString()):Tr(model.YardPieces.Require(ids[i]).Require("name").AsString());GUI.Label(new Rect(r.x+12,r.y+3,r.width-18,r.height-3),name,row);if(focused)RenderedSelectedBounds=r;
   }
   StoryUi.Panel(DetailRect);GUI.Label(new Rect(DetailRect.x+8,DetailRect.y+4,DetailRect.width-16,DetailRect.height-8),DetailText(),small);
   // The plan: terrain, owned building room, farm ground and the drafted design.
   StoryUi.Fill(new Rect(PlanRect.x-4,PlanRect.y-4,region.W*s+8,region.H*s+8),new Color(.2f,.24f,.22f));var farm=model.FarmCells;var extensions=draft.Require("extensions");
   foreach(var cell in region.Cells())
   {
    var c=CellRect(cell);StoryUi.Fill(c,TerrainColor(model.Terrain(cell)));
    if(model.OwnedCell(cell,extensions))StoryUi.Fill(c,new Color(.95f,.9f,.6f,.12f));else if(model.OnPlot(cell))StoryUi.Fill(c,new Color(0,0,0,.25f));
    if(farm.TryGet(cell.Key,out _))StoryUi.Fill(new Rect(c.x+2,c.y+2,c.width-4,c.height-4),new Color(.36f,.26f,.17f));
   }
   DrawPieces(candidate??draft,1f);
   foreach(var cell in StrokeCells())if(region.Has(cell))StoryUi.Border(CellRect(cell),reason==""?new Color(.6f,.92f,.6f):new Color(.95f,.45f,.4f),zone==1?3:2);
   if(zone==1)RenderedSelectedBounds=CellRect(cursor);
   for(int i=0;i<ActionIds.Length;i++)
   {
    var r=new Rect(ActionsRect.x,ActionsRect.y+i*ActionHeight,ActionsRect.width,ActionHeight-5);bool focused=zone==2&&i==actionIndex;var style=new GUIStyle(row);if(!ActionEnabled(ActionIds[i]))style.normal.textColor=new Color(.42f,.5f,.56f);
    string label=ActionLabel(ActionIds[i]);while(style.fontSize>11&&style.CalcSize(new GUIContent(label)).x>r.width-24)style.fontSize--;
    StoryUi.Button(r,label,style,true,focused,ActionEnabled(ActionIds[i]));if(focused)RenderedSelectedBounds=r;
   }
   GUI.Label(StatusRect,StatusText(),text);GUI.Label(CountsRect,CountsText(),small);
   GUI.Label(HintRect,binding("ui_prev_tab")+"/"+binding("ui_next_tab")+T(" lijst · plattegrond · acties   "," list · plan · actions   ")+binding("ui_accept")+T(" bevestigen   "," confirm   ")+binding("ui_cancel")+T(" annuleren · Toepassen bewaart, annuleren verwerpt"," cancel · Apply saves, cancel discards"),small);
  }
 }
}
