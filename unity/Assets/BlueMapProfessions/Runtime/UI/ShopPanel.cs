using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Professions
{
 /// <summary>Native view of an original shop: the same rows, prices, one-time purchases and refusals.</summary>
 public sealed class ShopPanel
 {
  readonly Phase6Catalog catalog;readonly ProfessionsModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;
  InputFrame lastHandled,openingFrame;bool controller;int selected,pressed=-1,openedFrame=-1;float scroll;double repeatWait;IReadOnlyList<ShopRow> rows=Array.Empty<ShopRow>();GUIStyle heading,coins,text,small,row;
  public const float RowHeight=44;
  public static readonly Rect PanelRect=new Rect(276,54,600,540),ListRect=new Rect(296,146,560,280),DescriptionRect=new Rect(296,436,560,62),CloseRect=new Rect(296,534,560,40),HintRect=new Rect(296,506,560,22);
  public bool IsOpen {get;private set;} public string ShopId {get;private set;}="";
  public IReadOnlyList<ShopRow> Rows=>rows;public int Selected=>selected;public float Scroll=>scroll;public bool ControllerActive=>controller;public Rect RenderedSelectedBounds {get;private set;}=Rect.zero;
  /// <summary>Index of the close control, directly after the last shop row.</summary>
  public int CloseIndex=>rows.Count;
  public event Action CloseRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&new[]{ListRect,DescriptionRect,CloseRect,HintRect}.All(r=>StoryUi.Contains(PanelRect,r))&&ListRect.yMax<=DescriptionRect.y&&DescriptionRect.yMax<=HintRect.y&&HintRect.yMax<=CloseRect.y;
  public bool SelectionVisible{get{if(!IsOpen||selected>=rows.Count)return true;float top=selected*RowHeight-scroll;return top>=-.1f&&top+RowHeight<=ListRect.height+.1f;}}
  public ShopPanel(Phase6Catalog sourceCatalog,ProfessionsModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);
  bool Selectable(int index)=>index==rows.Count||index>=0&&index<rows.Count&&!rows[index].Owned;
  public bool Open(string shop)
  {
   if(!model.Shops.TryGet(shop??"",out _))return false;ShopId=shop;IsOpen=true;scroll=0;pressed=-1;openedFrame=Time.frameCount;Populate(0);return true;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;pressed=-1;}
  public void SetControllerActive(bool active){controller=active;if(active)pressed=-1;}
  /// <summary>Rebuilds the visible rows and keeps the focus on the row that was just used, as the source does.</summary>
  void Populate(int focus)
  {
   rows=model.ShopRows(ShopId);int first=-1;
   for(int i=0;i<rows.Count;i++)if(!rows[i].Owned&&(first<0||i==focus))first=i;
   selected=first<0?rows.Count:first;KeepVisible();
  }
  public void Refresh(){if(IsOpen)Populate(selected);}
  void KeepVisible()
  {
   float max=Math.Max(0,rows.Count*RowHeight-ListRect.height);if(selected<rows.Count){float top=selected*RowHeight;if(top<scroll)scroll=top;else if(top+RowHeight>scroll+ListRect.height)scroll=top+RowHeight-ListRect.height;}
   scroll=Mathf.Clamp(scroll,0,max);
  }
  public void MoveSelection(int amount)
  {
   if(!IsOpen||amount==0)return;int count=rows.Count+1,next=selected;
   for(int i=0;i<count;i++){next=(next+Math.Sign(amount)+count)%count;if(Selectable(next))break;}
   selected=next;KeepVisible();
  }
  public bool ActivateSelected()
  {
   if(!IsOpen)return false;pressed=-1;if(selected>=rows.Count){CloseRequested?.Invoke();return true;}
   int index=selected;bool bought=model.Buy(ShopId,rows[index].EntryIndex);Populate(index);return bought;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(double.IsFinite(delta)&&delta>0)repeatWait=Math.Max(0,repeatWait-delta);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseRequested?.Invoke();return;}
   int move=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;if(move==0&&repeatWait<=0){if(frame.Held("ui_down"))move=1;else if(frame.Held("ui_up"))move=-1;}
   if(move!=0){MoveSelection(move);repeatWait=.16;}
   if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateSelected();
  }
  public string Description=>selected<rows.Count?Tr(model.Inventory.ItemDescription(rows[selected].Item)):rows.All(r=>r.Owned)&&rows.Count>0?Tr("Je hebt alles gekocht!"):"";
  void Styles(){heading=StoryUi.Text(catalog,30);heading.normal.textColor=new Color(.6f,.88f,1);coins=StoryUi.Text(catalog,24);coins.normal.textColor=new Color(1,.9f,.4f);text=StoryUi.Text(catalog,18,true);small=StoryUi.Text(catalog,16);small.normal.textColor=StoryUi.Quiet;row=StoryUi.Text(catalog,21);}
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&e.type==EventType.ScrollWheel){scroll=Mathf.Clamp(scroll+e.delta.y*20,0,Math.Max(0,rows.Count*RowHeight-ListRect.height));e.Use();return;}
   if(!controller&&(e.type==EventType.MouseDown||e.type==EventType.MouseUp))
   {
    int hit=-1;if(ListRect.Contains(e.mousePosition)){hit=(int)((e.mousePosition.y-ListRect.y+scroll)/RowHeight);if(hit>=rows.Count)hit=-1;}else if(CloseRect.Contains(e.mousePosition))hit=rows.Count;
    if(e.type==EventType.MouseDown){pressed=-1;if(e.button==1){e.Use();CloseRequested?.Invoke();return;}if(e.button==0&&hit>=0&&Selectable(hit)&&openedFrame!=Time.frameCount){pressed=hit;selected=hit;}}
    else{bool activate=e.button==0&&hit>=0&&hit==pressed;pressed=-1;if(activate){selected=hit;ActivateSelected();}}
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Fill(new Rect(0,0,1152,648),new Color(0,0,0,.6f));StoryUi.Panel(PanelRect);StoryUi.Border(PanelRect,new Color(.45f,.75f,1),3);
   GUI.Label(new Rect(296,66,560,38),model.ShopName(ShopId),heading);GUI.Label(new Rect(296,106,560,30),ProfessionsModel.Fill(Tr("Munten: %d"),model.State.Coins),coins);
   GUI.BeginGroup(ListRect);
   for(int i=0;i<rows.Count;i++)
   {
    var r=new Rect(0,i*RowHeight-scroll,ListRect.width-14,RowHeight-6);if(r.yMax<0||r.y>ListRect.height)continue;var style=new GUIStyle(row);style.fontSize=20;if(rows[i].Owned)style.normal.textColor=new Color(.42f,.5f,.56f);
    while(style.fontSize>15&&style.CalcSize(new GUIContent(rows[i].Text)).x>r.width-24)style.fontSize--;
    StoryUi.Button(r,rows[i].Text,style,true,selected==i,!rows[i].Owned);if(selected==i)RenderedSelectedBounds=new Rect(ListRect.x+r.x,ListRect.y+r.y,r.width,r.height);
   }
   GUI.EndGroup();StoryUi.Rail(new Rect(ListRect.x,ListRect.y,ListRect.width-10,ListRect.height),scroll,rows.Count*RowHeight);
   GUI.Label(DescriptionRect,Description,text);
   GUI.Label(HintRect,ProfessionsModel.Fill(Tr("↑ ↓ kiezen  ·  %s kopen  ·  %s sluiten"),binding("ui_accept"),binding("ui_cancel")),small);
   StoryUi.Button(CloseRect,Tr("Sluiten"),row,true,selected==rows.Count);if(selected==rows.Count)RenderedSelectedBounds=CloseRect;
  }
 }
 /// <summary>Native view of the original lake fishing: the line, the bite, the reel bar and the result card.</summary>
 public sealed class FishingView
 {
  readonly Phase6Catalog catalog;readonly ProfessionsModel model;readonly Func<string,string,string> bilingual;readonly Func<string,string> binding;
  InputFrame lastHandled,openingFrame;bool controller,mouseHeld;GUIStyle heading,text,small;
  public static readonly Rect ReelPanel=new Rect(826,120,270,400),Bar=new Rect(872,190,64,280),ProgressBar=new Rect(962,190,26,280),StatusPanel=new Rect(326,468,500,70),ResultCard=new Rect(346,150,460,300);
  public FishingSession Session {get;private set;}
  public bool IsOpen=>Session!=null&&Session.Active;public bool Holding {get;set;}
  public event Action CloseRequested;
  public bool LayoutFits=>new[]{ReelPanel,StatusPanel,ResultCard}.All(r=>StoryUi.Contains(new Rect(0,0,1152,648),r))&&StoryUi.Contains(ReelPanel,Bar)&&StoryUi.Contains(ReelPanel,ProgressBar)&&Bar.xMax<=ProgressBar.x;
  public FishingView(Phase6Catalog sourceCatalog,ProfessionsModel sourceModel,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;model=sourceModel??throw new ArgumentNullException(nameof(sourceModel));bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  string T(string nl,string en)=>bilingual(nl,en);string Tr(string source)=>model.Tr(source);
  public void Bind(FishingSession session){Session=session;Holding=false;mouseHeld=false;}
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void SetControllerActive(bool active){controller=active;if(active)mouseHeld=false;}
  public void HandleInput(InputFrame frame)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);
   Holding=frame.Held("interact")||frame.Held("ui_accept")||!controller&&mouseHeld;
   if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("interact")||frame.Pressed("ui_accept"))Session.Press();
  }
  public string StatusLine
  {
   get
   {
    if(Session==null)return "";
    switch(Session.Phase)
    {
     case "cast":return T("Je werpt je lijn uit…","You cast your line…");
     case "wait":return T("Wachten op een beet…","Waiting for a bite…");
     case "bite":return T("Beet! Sla aan!","A bite! Strike!");
     case "reel":return T("Houd de vis in de groene zone.","Keep the fish inside the green zone.");
     case "result":return Session.Outcome=="gevangen"?ProfessionsModel.Fill(T("Gevangen: %s","Caught: %s"),model.ItemName(Session.CatchId)):Session.Outcome=="te_laat"?T("Te laat — de vis is weg.","Too late — the fish is gone."):T("De vis is ontsnapt.","The fish escaped.");
    }
    return "";
   }
  }
  public string HintLine
  {
   get
   {
    if(Session==null)return "";string accept=binding("interact"),cancel=binding("ui_cancel");
    switch(Session.Phase)
    {
     case "bite":return accept+T(" aanslaan"," strike");
     case "reel":return accept+T(" ingedrukt: zone omhoog · loslaten: zone zakt"," held: zone rises · released: zone sinks");
     case "result":return (Session.CanCastAgain?accept+T(" opnieuw uitwerpen · "," cast again · "):"")+cancel+T(" stoppen"," stop");
    }
    return cancel+T(" stoppen"," stop");
   }
  }
  void Styles(){heading=StoryUi.Text(catalog,24);text=StoryUi.Text(catalog,20,true);small=StoryUi.Text(catalog,16,true);small.normal.textColor=StoryUi.Quiet;}
  public void Draw()
  {
   if(!IsOpen)return;Styles();var e=Event.current;
   if(e.type==EventType.MouseDown||e.type==EventType.MouseUp)
   {
    if(!controller){if(e.button==0){mouseHeld=e.type==EventType.MouseDown;if(e.type==EventType.MouseDown)Session.Press();}else if(e.button==1&&e.type==EventType.MouseDown){e.Use();CloseRequested?.Invoke();return;}}
    e.Use();if(!IsOpen)return;
   }
   StoryUi.Panel(StatusPanel);GUI.Label(new Rect(StatusPanel.x+16,StatusPanel.y+8,StatusPanel.width-32,28),StatusLine,text);GUI.Label(new Rect(StatusPanel.x+16,StatusPanel.y+40,StatusPanel.width-32,22),HintLine,small);
   if(Session.Phase=="bite"){float left=Mathf.Clamp01(1f-(float)(Session.PhaseTime/Session.BiteWindow));StoryUi.Fill(new Rect(StatusPanel.x,StatusPanel.y-8,StatusPanel.width*left,4),StoryUi.Gold);}
   var reel=Session.Reel;
   if(Session.Phase=="reel"&&reel!=null)
   {
    StoryUi.Panel(ReelPanel);GUI.Label(new Rect(ReelPanel.x+16,ReelPanel.y+14,ReelPanel.width-32,30),model.ItemName(Session.CatchId),heading);
    StoryUi.Fill(Bar,new Color(.07f,.14f,.24f));StoryUi.Border(Bar,new Color(.45f,.75f,1),1);
    float zoneHeight=Bar.height*(float)reel.ZoneSize,zoneY=Bar.yMax-Bar.height*(float)reel.ZonePos-zoneHeight/2;StoryUi.Fill(new Rect(Bar.x+2,zoneY,Bar.width-4,zoneHeight),reel.InZone?new Color(.45f,.85f,.5f,.85f):new Color(.3f,.6f,.36f,.7f));
    float fishY=Bar.yMax-Bar.height*(float)reel.FishPos;StoryUi.Fill(new Rect(Bar.x+10,fishY-6,Bar.width-20,12),StoryUi.Gold);
    StoryUi.Fill(ProgressBar,new Color(.07f,.14f,.24f));StoryUi.Border(ProgressBar,new Color(.45f,.75f,1),1);float fill=ProgressBar.height*(float)reel.Progress;StoryUi.Fill(new Rect(ProgressBar.x+2,ProgressBar.yMax-fill,ProgressBar.width-4,fill),new Color(.55f,.85f,1));
   }
   if(Session.Phase=="result")
   {
    StoryUi.Panel(ResultCard,Session.Outcome=="gevangen");GUI.Label(new Rect(ResultCard.x+24,ResultCard.y+22,ResultCard.width-48,34),StatusLine,heading);
    if(Session.Outcome=="gevangen")GUI.Label(new Rect(ResultCard.x+24,ResultCard.y+70,ResultCard.width-48,150),Tr(model.Inventory.ItemDescription(Session.CatchId))+"\n\n"+ProfessionsModel.Fill(T("Vissen: niveau %d","Fishing: level %d"),model.Level("fishing")),text);
    GUI.Label(new Rect(ResultCard.x+24,ResultCard.yMax-40,ResultCard.width-48,24),HintLine,small);
   }
  }
 }
}
