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
 /// Native view of the original house designer. The design is a draft: only "apply" saves it,
 /// cancelling discards it, and made furniture stays in the furniture stock either way.
 /// </summary>
 public sealed class HouseEditorPanel
 {
  readonly Phase6Catalog catalog;readonly HomeModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;readonly Func<Vector2> player;
  InputFrame lastHandled,openingFrame;bool controller;int zone,kindIndex,actionIndex,pressedZone=-1,pressedIndex=-1,openedFrame=-1;double repeatWait;long tint;GUIStyle heading,text,small,row;
  FoundationValue draft;string editingId="";HomeCell cursor=new HomeCell(4,9);
  public const float Step=34,RowHeight=27,ActionHeight=37;
  public static readonly Rect PanelRect=new Rect(24,14,1104,620),ListRect=new Rect(40,84,300,13*RowHeight),DetailRect=new Rect(40,444,300,128),PlanRect=new Rect(360,84,10*Step,10*Step),ActionsRect=new Rect(720,84,392,9*ActionHeight),StatusRect=new Rect(360,434,752,44),CounterRect=new Rect(360,484,752,22),HintRect=new Rect(40,598,1072,22);
  public static readonly string[] ActionIds={"make","pack","tint","floor","wall","light","apply","reset","cancel"};
  public bool IsOpen {get;private set;} public string Kind=>model.PieceIds[kindIndex];public string EditingId=>editingId;public HomeCell Cursor=>cursor;public int Zone=>zone;public int ActionIndex=>actionIndex;public long Tint=>tint;
  public FoundationValue Draft=>draft;public bool ControllerActive=>controller;public string LastStatus {get;private set;}="";public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  public event Action CloseRequested;public event Action Applied;public event Action<string> SoundRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&new[]{ListRect,DetailRect,PlanRect,ActionsRect,StatusRect,CounterRect,HintRect}.All(r=>StoryUi.Contains(PanelRect,r))&&ListRect.xMax<=PlanRect.x&&PlanRect.xMax<=ActionsRect.x&&ListRect.yMax<=DetailRect.y&&PlanRect.yMax<=StatusRect.y&&StatusRect.yMax<=CounterRect.y&&DetailRect.yMax<=HintRect.y;
  public HouseEditorPanel(Phase6Catalog sourceCatalog,HomeModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel,Func<Vector2> playerPosition)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);player=playerPosition??(()=>Vector2.zero);}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);
  static string Fill(string text,params object[] values){foreach(var v in values){int a=text.IndexOf("%s",StringComparison.Ordinal),b=text.IndexOf("%d",StringComparison.Ordinal),i=a<0?b:b<0?a:Math.Min(a,b);if(i<0)break;text=text.Substring(0,i)+Convert.ToString(v,System.Globalization.CultureInfo.InvariantCulture)+text.Substring(i+2);}return text;}
  FoundationValue Layout=>draft.Require("layout");
  long DraftNumber(string key)=>draft.Require(key).AsInt64();
  public bool Open()
  {
   if(model.State.MapId!="player_home"||model.State.Transitioning)return false;
   draft=model.HouseState();IsOpen=true;zone=0;actionIndex=0;openedFrame=Time.frameCount;pressedIndex=-1;SelectKind(Math.Max(0,model.PieceIds.ToList().IndexOf("chair")));return true;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressedIndex=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressedIndex=-1;}
  /// <summary>Selecting a kind picks its next free copy, or the first placed one to move.</summary>
  public void SelectKind(int index)
  {
   if(index<0||index>=model.PieceIds.Count)return;kindIndex=index;string kind=Kind;editingId=model.NextPieceId(kind,Layout);
   if(editingId=="")foreach(var row in Layout.Entries)if(row.Value.Require("kind").AsString()==kind){editingId=row.Key.AsString();var r=model.PieceRect(row.Value);cursor=new HomeCell(r.X,r.Y);tint=row.Value.TryGet("tint",out var saved)?saved.AsInt64():0;break;}
   if(editingId=="")editingId=kind+":1";
  }
  public bool PickAt(HomeCell at)
  {
   foreach(var row in Layout.Entries)
   {
    string kind=row.Value.Require("kind").AsString();if(model.IsFloor(kind)||!model.PieceRect(row.Value).Has(at))continue;
    editingId=row.Key.AsString();kindIndex=model.PieceIds.ToList().IndexOf(kind);var r=model.PieceRect(row.Value);cursor=new HomeCell(r.X,r.Y);tint=row.Value.TryGet("tint",out var saved)?saved.AsInt64():0;return true;
   }
   return false;
  }
  public FoundationValue Proposal()=>HomeModel.HouseCandidate(Layout,editingId,Kind,cursor,tint);
  public string PlacementReason()
  {
   var next=Proposal();string reason=model.HouseLayoutReason(next,model.HouseView.Require("owned"));return reason!=""?reason:model.HousePlayerReason(next,player());
  }
  public void MoveCursor(int dx,int dy){LastStatus="";cursor=new HomeCell(Math.Max(2,Math.Min(11,cursor.X+dx)),Math.Max(2,Math.Min(11,cursor.Y+dy)));}
  public bool Place()
  {
   if(!IsOpen||PlacementReason()!="")return false;draft=InventoryModel.Replace(draft,"layout",Proposal());SoundRequested?.Invoke("select");return true;
  }
  public bool Pack()
  {
   if(!IsOpen||!Layout.TryGet(editingId,out _)||model.IsBase(Kind))return false;
   draft=InventoryModel.Replace(draft,"layout",InventoryModel.Replace(Layout,editingId,null,true));editingId=model.NextPieceId(Kind,Layout);if(editingId=="")editingId=Kind+":1";return true;
  }
  public bool MakePiece()
  {
   if(!IsOpen||!model.MakePiece(Kind))return false;draft=InventoryModel.Replace(draft,"owned",model.HouseView.Require("owned"));SelectKind(kindIndex);SoundRequested?.Invoke("select");return true;
  }
  public void CycleTint(){tint=(tint+1)%3;if(Layout.TryGet(editingId,out var entry)&&entry.Require("kind").AsString()==Kind)draft=InventoryModel.Replace(draft,"layout",InventoryModel.Replace(Layout,editingId,InventoryModel.Replace(entry,"tint",FoundationValue.Integer(tint))));}
  public void Cycle(string key){long limit=key=="light"?3:4;draft=InventoryModel.Replace(draft,key,FoundationValue.Integer((DraftNumber(key)+1)%limit));}
  public bool Apply()
  {
   if(!IsOpen)return false;string reason=model.HouseLayoutReason(Layout,model.HouseView.Require("owned"));if(reason=="")reason=model.HousePlayerReason(Layout,player());
   if(reason!=""){LastStatus=reason;return false;}
   if(!model.ApplyHouse(draft,player()))return false;SoundRequested?.Invoke("select");Close();Applied?.Invoke();return true;
  }
  public void ResetDraft(){draft=InventoryModel.Replace(model.HouseDefaults(),"owned",model.HouseView.Require("owned"));SelectKind(kindIndex);LastStatus=Tr("Beginindeling als ontwerp. Pas toe om deze te bewaren.");}
  bool ActionEnabled(string id)
  {
   switch(id){case "make":return model.MakePieceReason(Kind)=="";case "pack":return Layout.TryGet(editingId,out _)&&!model.IsBase(Kind);}
   return true;
  }
  string ActionLabel(string id)
  {
   switch(id)
   {
    case "make":return Kind.StartsWith("trophy_",StringComparison.Ordinal)?Tr("Ontvang aandenken"):Tr("Maak extra meubel");
    case "pack":return Tr("Berg meubel op");
    case "tint":return T("Kleur: ","Colour: ")+Tr(model.House.Require("colors").Items[(int)tint].AsString());
    case "floor":return T("Vloer: ","Floor: ")+Tr(model.House.Require("floors").Items[(int)DraftNumber("floor")].AsString());
    case "wall":return T("Wand: ","Wall: ")+Tr(model.House.Require("walls").Items[(int)DraftNumber("wall")].AsString());
    case "light":return T("Licht: ","Light: ")+Tr(model.House.Require("lights").Items[(int)DraftNumber("light")].AsString());
    case "apply":return Tr("Toepassen en opslaan");
    case "reset":return Tr("Beginindeling bekijken");
   }
   return Tr("Annuleren");
  }
  public bool Activate(string id)
  {
   if(!IsOpen||!ActionEnabled(id))return false;
   switch(id)
   {
    case "make":return MakePiece();case "pack":return Pack();case "tint":CycleTint();return true;case "floor":case "wall":case "light":Cycle(id);return true;
    case "apply":return Apply();case "reset":ResetDraft();return true;
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
    repeatWait=.14;
    if(zone==1)MoveCursor(dx,dy);
    else if(dy!=0){if(zone==0)SelectKind((kindIndex+dy+model.PieceIds.Count)%model.PieceIds.Count);else actionIndex=(actionIndex+dy+ActionIds.Length)%ActionIds.Length;}
    else zone=Math.Max(0,Math.Min(2,zone+dx));
   }
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))
   {
    if(zone==0)zone=1;else if(zone==1){if(!Place())LastStatus=PlacementReason();}else Activate(ActionIds[actionIndex]);
   }
  }
  public string DetailText()
  {
   string kind=Kind;var info=model.Piece(kind);var size=model.PieceSize(kind);long count=Layout.Entries.Count(row=>row.Value.Require("kind").AsString()==kind);
   var lines=new List<string>{model.PieceName(kind)+" · "+Fill(Tr("%d × %d tegels"),size.X,size.Y),Fill(Tr("In je meubelvoorraad: %d · geplaatst: %d"),model.HouseView.Require("owned").TryGet(kind,out var have)?have.AsInt64():0,count)};
   if(!model.PieceUnlocked(kind))lines.Add(Tr(info.TryGet("hint",out var hint)?hint.AsString():"Nog niet ontdekt."));
   var cost=info.Require("cost");
   if(cost.Entries.Count>0)lines.Add(Fill(Tr("Maken: %s"),String.Join(", ",cost.Entries.Select(row=>model.ItemName(row.Key.AsString())+" "+model.Inventory.Available(row.Key.AsString())+"/"+row.Value.AsInt64()))));
   lines.Add(model.PieceDescription(kind));return String.Join("\n",lines);
  }
  public string StatusText(){string reason=PlacementReason();return reason!=""?reason:Tr("Plek past. Pijltjes of stick verplaatsen de markering; bevestig om dit ontwerp aan te passen.");}
  public string CounterText()
  {
   int solid=0;foreach(var row in Layout.Entries)if(!model.IsFloor(row.Value.Require("kind").AsString())){var r=model.PieceRect(row.Value);solid+=r.W*r.H;}
   return Fill(Tr("Meubels %d/12 · vrije vloer %d/100"),Layout.Entries.Count,100-model.HouseFixedCells().Count-solid);
  }
  void Styles(){heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.89f,.8f,.63f);text=StoryUi.Text(catalog,16,true);small=StoryUi.Text(catalog,14,true);small.normal.textColor=StoryUi.Quiet;row=StoryUi.Text(catalog,16);}
  static Rect CellRect(HomeCell cell,int w=1,int h=1)=>new Rect(PlanRect.x+(cell.X-2)*Step,PlanRect.y+(cell.Y-2)*Step,w*Step,h*Step);
  static readonly Color[] FloorColors={new Color(.55f,.42f,.28f),new Color(.72f,.62f,.45f),new Color(.42f,.47f,.5f),new Color(.72f,.47f,.36f)};
  void DrawPiece(FoundationValue entry,float alpha)
  {
   string kind=entry.Require("kind").AsString();var r=model.PieceRect(entry);var box=CellRect(new HomeCell(r.X,r.Y),r.W,r.H);long shade=entry.TryGet("tint",out var saved)?saved.AsInt64():0;
   Sprite sprite=null;try{sprite=catalog?.GetSprite((kind=="rug"?"rug:":"furniture:"+kind+":")+Math.Max(0,Math.Min(2,shade)));}catch(Exception){sprite=null;}
   GUI.color=new Color(1,1,1,alpha);
   if(sprite!=null&&sprite.texture!=null){var tr=sprite.textureRect;GUI.DrawTextureWithTexCoords(box,sprite.texture,new Rect(tr.x/sprite.texture.width,tr.y/sprite.texture.height,tr.width/sprite.texture.width,tr.height/sprite.texture.height));}
   else StoryUi.Fill(new Rect(box.x+3,box.y+3,box.width-6,box.height-6),new Color(.72f,.6f,.42f,alpha));
   GUI.color=Color.white;
  }
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hitZone=-1,hit=-1;
    if(ListRect.Contains(e.mousePosition)){hitZone=0;hit=(int)((e.mousePosition.y-ListRect.y)/RowHeight);}
    else if(PlanRect.Contains(e.mousePosition)){hitZone=1;hit=(int)((e.mousePosition.y-PlanRect.y)/Step)*10+(int)((e.mousePosition.x-PlanRect.x)/Step);}
    else if(ActionsRect.Contains(e.mousePosition)){hitZone=2;hit=(int)((e.mousePosition.y-ActionsRect.y)/ActionHeight);}
    if(e.type==EventType.MouseDown){pressedIndex=-1;if(e.button==0&&hit>=0&&openedFrame!=Time.frameCount){pressedZone=hitZone;pressedIndex=hit;}else if(e.button==1&&hitZone==1){PickAt(new HomeCell(2+hit%10,2+hit/10));zone=1;}}
    else
    {
     bool activate=e.button==0&&hit>=0&&hit==pressedIndex&&hitZone==pressedZone;pressedIndex=-1;
     if(activate)
     {
      zone=hitZone;
      if(hitZone==0)SelectKind(hit);
      else if(hitZone==1){var at=new HomeCell(2+hit%10,2+hit/10);if(at.Equals(cursor)){if(!Place())LastStatus=PlacementReason();}else cursor=at;}
      else{actionIndex=hit;Activate(ActionIds[hit]);}
     }
    }
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(.025f,.04f,.045f,.9f));StoryUi.Panel(PanelRect);
   GUI.Label(new Rect(40,24,1072,34),Tr("Je huis · rustig inrichten"),heading);GUI.Label(new Rect(40,58,300,22),Tr("Meubelvoorraad · kiezen of verplaatsen"),small);
   var ids=model.PieceIds;var owned=model.HouseView.Require("owned");
   for(int i=0;i<ids.Count;i++)
   {
    var r=new Rect(ListRect.x,ListRect.y+i*RowHeight,ListRect.width,RowHeight-3);bool focused=zone==0&&i==kindIndex;StoryUi.Panel(r,focused);if(i==kindIndex)StoryUi.Fill(new Rect(r.x+1,r.y+1,4,r.height-2),StoryUi.Gold);
    GUI.Label(new Rect(r.x+12,r.y+2,r.width-18,r.height-2),model.PieceName(ids[i])+" · "+(owned.TryGet(ids[i],out var n)?n.AsInt64():0),row);if(focused)RenderedSelectedBounds=r;
   }
   StoryUi.Panel(DetailRect);GUI.Label(new Rect(DetailRect.x+8,DetailRect.y+4,DetailRect.width-16,DetailRect.height-8),DetailText(),small);
   // The plan: floor, the marked walking route, fixed fittings and every drafted piece.
   StoryUi.Fill(new Rect(PlanRect.x-6,PlanRect.y-6,PlanRect.width+12,PlanRect.height+12),new Color(.43f,.41f,.36f));StoryUi.Fill(PlanRect,FloorColors[(int)Math.Max(0,Math.Min(3,DraftNumber("floor")))]);
   for(int y=2;y<12;y++)for(int x=2;x<12;x++){var c=CellRect(new HomeCell(x,y));if(HomeModel.HouseReserved(new HomeCell(x,y)))StoryUi.Fill(c,new Color(.48f,.76f,.74f,.22f));StoryUi.Border(c,new Color(.12f,.2f,.18f,.18f),1);}
   foreach(var row in Layout.Entries)if(model.IsFloor(row.Value.Require("kind").AsString()))DrawPiece(row.Value,.9f);
   foreach(var fixedCell in model.HouseFixedCells()){var c=CellRect(fixedCell);StoryUi.Fill(new Rect(c.x+4,c.y+4,c.width-8,c.height-8),new Color(.61f,.5f,.36f));}
   foreach(var row in Layout.Entries)if(!model.IsFloor(row.Value.Require("kind").AsString())&&row.Key.AsString()!=editingId)DrawPiece(row.Value,1f);
   string reason=PlacementReason();var size=model.PieceSize(Kind);var ghost=FoundationValue.Object(new Dictionary<string,FoundationValue>{{"kind",FoundationValue.StringValue(Kind)},{"cell",FoundationValue.Array(new[]{FoundationValue.Integer(cursor.X),FoundationValue.Integer(cursor.Y)})},{"tint",FoundationValue.Integer(tint)}});
   DrawPiece(ghost,.75f);var mark=CellRect(cursor,size.X,size.Y);GUI.BeginGroup(new Rect(PlanRect.x-6,PlanRect.y-6,PlanRect.width+12,PlanRect.height+12));StoryUi.Border(new Rect(mark.x-PlanRect.x+6,mark.y-PlanRect.y+6,mark.width,mark.height),reason==""?new Color(.6f,.92f,.6f):new Color(.95f,.45f,.4f),zone==1?3:2);GUI.EndGroup();
   if(zone==1)RenderedSelectedBounds=CellRect(cursor);
   for(int i=0;i<ActionIds.Length;i++)
   {
    var r=new Rect(ActionsRect.x,ActionsRect.y+i*ActionHeight,ActionsRect.width,ActionHeight-5);bool focused=zone==2&&i==actionIndex;var style=new GUIStyle(row);if(!ActionEnabled(ActionIds[i]))style.normal.textColor=new Color(.42f,.5f,.56f);
    StoryUi.Button(r,ActionLabel(ActionIds[i]),style,true,focused,ActionEnabled(ActionIds[i]));if(focused)RenderedSelectedBounds=r;
   }
   string status=LastStatus!=""&&reason==""?LastStatus:StatusText();GUI.Label(StatusRect,status,text);GUI.Label(CounterRect,CounterText(),small);
   GUI.Label(HintRect,binding("ui_prev_tab")+"/"+binding("ui_next_tab")+T(" lijst · plattegrond · acties   "," list · plan · actions   ")+binding("ui_accept")+T(" bevestigen   "," confirm   ")+binding("ui_cancel")+T(" annuleren · Toepassen bewaart, annuleren verwerpt"," cancel · Apply saves, cancel discards"),small);
  }
 }
}
