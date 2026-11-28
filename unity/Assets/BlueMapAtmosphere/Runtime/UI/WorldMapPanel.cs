using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Atmosphere
{
 /// <summary>A discovered rest altar the player can travel to.</summary>
 public sealed class TravelPoint{public string Map,Key,Name,Spawn;public Vector2 Tile;}
 /// <summary>
 /// The world atlas: nineteen regions at their authored places, what you have visited, where you are and the next
 /// passage towards a place; and the list of rest altars you may travel to. The map never reveals an unvisited name.
 /// </summary>
 public sealed class WorldMapPanel
 {
  public sealed class Region{public string Id;public Vector2 At;}
  public static readonly Region[] Regions=
  {
   new Region{Id="steampeak",At=new Vector2(264,25)},new Region{Id="ijsdal",At=new Vector2(264,75)},new Region{Id="ridgepass",At=new Vector2(360,60)},new Region{Id="sunwell",At=new Vector2(408,85)},
   new Region{Id="dauwbos",At=new Vector2(264,139)},new Region{Id="dorstvallei",At=new Vector2(384,135)},new Region{Id="mistgarden",At=new Vector2(336,170)},new Region{Id="village",At=new Vector2(120,213)},
   new Region{Id="forest_edge",At=new Vector2(192,217)},new Region{Id="forest",At=new Vector2(264,209)},new Region{Id="watchyard",At=new Vector2(228,252)},new Region{Id="lake",At=new Vector2(120,280)},
   new Region{Id="kruipmoeras",At=new Vector2(120,333)},new Region{Id="river_mouth",At=new Vector2(294,249)},new Region{Id="coast",At=new Vector2(294,291)},new Region{Id="harbor",At=new Vector2(420,245)},
   new Region{Id="headland",At=new Vector2(522,227)},new Region{Id="gull_island",At=new Vector2(432,326)},new Region{Id="tide_cove",At=new Vector2(522,326)},
  };
  static readonly Dictionary<string,string[]> Locales=new Dictionary<string,string[]>
  {
   {"village",new[]{"smithy","shop","inn","player_home","arena_hall","arena","temple","depths1","depths2"}},{"forest",new[]{"ruins","cave","prismamine","resonance"}},{"lake",new[]{"fisher_hut","library"}},
   {"kruipmoeras",new[]{"reedvault"}},{"river_mouth",new[]{"tidal_hollow"}},{"harbor",new[]{"coast_workshop"}},
  };
  static readonly string[] Dungeons={"ruins","cave","temple","depths1","depths2","prismamine","resonance","reedvault","tidal_hollow"};
  readonly Phase6Catalog catalog;readonly Func<string,string> translate,binding;readonly Func<string,string,string> bilingual;
  InputFrame lastHandled,openingFrame;bool controller;int region,travel;
  public static readonly Rect PanelRect=new Rect(96,40,960,568),MapRect=new Rect(120,116,560,410),InfoRect=new Rect(700,116,332,410),ListRect=new Rect(120,116,560,410);
  public bool IsOpen {get;private set;} public string Tab {get;private set;}="map";public string RegionId=>Regions[region].Id;public int TravelIndex=>travel;public int Draws {get;private set;} public bool InfoFits {get;private set;}=true;
  public Func<string,bool> Visited {get;set;}=id=>false;public Func<string> CurrentMap {get;set;}=()=>"";public Func<string,string> MapTitle {get;set;}=id=>id;public Func<string,string> RouteHint {get;set;}=id=>"";
  public Func<IReadOnlyList<TravelPoint>> TravelPoints {get;set;}=()=>Array.Empty<TravelPoint>();public Func<string> TravelBlocked {get;set;}=()=>"";
  public event Action CloseRequested;public event Action<TravelPoint> TravelRequested;
  public bool LayoutFits=>StoryUi.Contains(new Rect(0,0,1152,648),PanelRect)&&StoryUi.Contains(PanelRect,MapRect)&&StoryUi.Contains(PanelRect,InfoRect)&&MapRect.xMax<=InfoRect.x&&Regions.All(r=>StoryUi.Contains(MapRect,NodeRect(r)));
  public WorldMapPanel(Phase6Catalog sourceCatalog,Func<string,string> translator,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;translate=translator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  public static string RegionFor(string map){if(Regions.Any(r=>r.Id==map))return map;foreach(var pair in Locales)if(pair.Value.Contains(map))return pair.Key;return "";}
  public static IReadOnlyList<string> LocalesOf(string id)=>new[]{id}.Concat(Locales.TryGetValue(id,out var more)?more:Array.Empty<string>()).ToArray();
  public bool RegionVisited(string id)=>LocalesOf(id).Any(Visited);
  /// <summary>2 = you are here, 1 = visited, 0 = unknown.</summary>
  public int RegionState(string id)=>RegionFor(CurrentMap())==id?2:RegionVisited(id)?1:0;
  public string RegionTitle(string id)=>RegionState(id)>0?MapTitle(id):translate("Onbekend gebied");
  public string PlaceTitle(string id)=>Visited(id)||CurrentMap()==id?MapTitle(id):translate("Onbekende plek");
  public string Kind(string id)=>Regions.Any(r=>r.Id==id)?translate("Streek"):Dungeons.Contains(id)?translate("Dungeon"):id=="arena"?translate("Arena"):translate("Gebouw");
  public int VisitedCount=>Regions.SelectMany(r=>LocalesOf(r.Id)).Distinct().Count(Visited);
  public static Rect NodeRect(Region r){var p=new Vector2(MapRect.x+16+r.At.x*(MapRect.width-60)/560f,MapRect.y+18+r.At.y*(MapRect.height-50)/380f);return new Rect(p.x-14,p.y-14,28,28);}
  public void Open(string tab="map")
  {
   IsOpen=true;Tab=tab=="travel"?"travel":"map";string here=RegionFor(CurrentMap());int index=Array.FindIndex(Regions,r=>r.Id==here);region=index<0?Array.FindIndex(Regions,r=>r.Id=="village"):index;travel=0;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;}
  public void SetControllerActive(bool active){controller=active;}
  public void SetTab(string tab){if(IsOpen)Tab=tab=="travel"?"travel":"map";}
  /// <summary>Step to the nearest region in a direction, as the source atlas does.</summary>
  public void MoveRegion(Vector2 direction)
  {
   int best=region;float score=float.PositiveInfinity;
   for(int i=0;i<Regions.Length;i++)
   {
    if(i==region)continue;var delta=Regions[i].At-Regions[region].At;float forward=Vector2.Dot(delta.normalized,direction);if(forward<.2f)continue;float value=delta.magnitude/forward;if(value<score){score=value;best=i;}
   }
   region=best;
  }
  public void MoveTravel(int amount){int count=TravelPoints().Count;if(count>0)travel=(travel+amount+count)%count;}
  public bool ActivateTravel()
  {
   var points=TravelPoints();if(!IsOpen||Tab!="travel"||travel<0||travel>=points.Count)return false;TravelRequested?.Invoke(points[travel]);return true;
  }
  public void HandleInput(InputFrame frame,double delta)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;SetControllerActive(frame.ControllerActive);if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("map")){CloseRequested?.Invoke();return;}
   if(frame.Pressed("ui_next_tab")||frame.Pressed("ui_prev_tab")){Tab=Tab=="map"?"travel":"map";return;}
   if(Tab=="map")
   {
    if(frame.Pressed("ui_left"))MoveRegion(Vector2.left);else if(frame.Pressed("ui_right"))MoveRegion(Vector2.right);else if(frame.Pressed("ui_up"))MoveRegion(new Vector2(0,-1));else if(frame.Pressed("ui_down"))MoveRegion(new Vector2(0,1));
   }
   else
   {
    if(frame.Pressed("ui_down"))MoveTravel(1);else if(frame.Pressed("ui_up"))MoveTravel(-1);
    if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivateTravel();
   }
  }
  public string InfoText
  {
   get
   {
    string id=RegionId;var lines=new List<string>{RegionTitle(id),Kind(id)};
    foreach(string place in LocalesOf(id).Skip(1))lines.Add("· "+PlaceTitle(place)+(Visited(place)||CurrentMap()==place?" ("+Kind(place)+")":""));
    string hint=RouteHint(id);if(hint!="")lines.Add("\n"+hint);return String.Join("\n",lines);
   }
  }
  public void Draw()
  {
   if(!IsOpen)return;Draws++;var heading=StoryUi.Text(catalog,26);heading.normal.textColor=new Color(.94f,.83f,.61f);var row=StoryUi.Text(catalog,17);var small=StoryUi.Text(catalog,14);small.normal.textColor=StoryUi.Quiet;var e=Event.current;
   if(controller&&(e.isMouse||e.type==EventType.ScrollWheel)){e.Use();return;}
   if(!controller&&e.type==EventType.MouseUp&&e.button==0)
   {
    if(new Rect(700,56,160,36).Contains(e.mousePosition))Tab="map";else if(new Rect(872,56,160,36).Contains(e.mousePosition))Tab="travel";
    else if(Tab=="map"){for(int i=0;i<Regions.Length;i++)if(NodeRect(Regions[i]).Contains(e.mousePosition))region=i;}
    else{var points=TravelPoints();for(int i=0;i<points.Count&&i<9;i++)if(new Rect(ListRect.x,ListRect.y+i*44,ListRect.width,38).Contains(e.mousePosition)){if(travel==i)ActivateTravel();else travel=i;}}
    e.Use();if(!IsOpen)return;
   }
   if(!controller&&e.type==EventType.MouseUp&&e.button==1){e.Use();CloseRequested?.Invoke();return;}
   StoryUi.Panel(PanelRect);GUI.Label(new Rect(120,52,560,40),Tab=="map"?translate("Wereldkaart"):bilingual("Snelreizen","Fast travel"),heading);
   StoryUi.Button(new Rect(700,56,160,36),translate("Kaart"),row,true,Tab=="map");StoryUi.Button(new Rect(872,56,160,36),bilingual("Snelreizen","Fast travel"),row,true,Tab=="travel");
   if(Tab=="map")
   {
    StoryUi.Fill(MapRect,new Color(.09f,.16f,.2f));StoryUi.Border(MapRect,new Color(.32f,.52f,.72f),1);var label=StoryUi.Text(catalog,12);label.alignment=TextAnchor.UpperCenter;
    for(int i=0;i<Regions.Length;i++)
    {
     var r=Regions[i];var node=NodeRect(r);int state=RegionState(r.Id);
     StoryUi.Fill(node,state==0?new Color(.22f,.26f,.3f):state==2?new Color(.95f,.8f,.35f):new Color(.38f,.62f,.5f));StoryUi.Border(node,i==region?StoryUi.Gold:new Color(.1f,.14f,.18f),i==region?3:1);
     label.normal.textColor=state==0?new Color(.55f,.6f,.66f):Color.white;GUI.Label(new Rect(node.x-46,node.yMax+1,120,18),state==0?"?":MapTitle(r.Id),label);
    }
    StoryUi.Panel(InfoRect);var info=StoryUi.Text(catalog,17,true);var content=new GUIContent(InfoText);var box=new Rect(InfoRect.x+14,InfoRect.y+12,InfoRect.width-28,InfoRect.height-24);
    while(info.fontSize>12&&info.CalcHeight(content,box.width)>box.height)info.fontSize--;InfoFits=info.CalcHeight(content,box.width)<=box.height+.5f;GUI.Label(box,InfoText,info);
    GUI.Label(new Rect(120,536,560,22),bilingual("Bezocht: ","Visited: ")+VisitedCount+" / 37",small);
   }
   else
   {
    var points=TravelPoints();string blocked=TravelBlocked();
    for(int i=0;i<points.Count&&i<9;i++){var r=new Rect(ListRect.x,ListRect.y+i*44,ListRect.width,38);StoryUi.Button(r,translate(points[i].Name)+" · "+MapTitle(points[i].Map),row,true,travel==i);}
    StoryUi.Panel(InfoRect);var info=StoryUi.Text(catalog,17,true);
    GUI.Label(new Rect(InfoRect.x+14,InfoRect.y+12,InfoRect.width-28,InfoRect.height-24),blocked!=""?blocked:points.Count==0?translate("Je hebt nog geen altaar ontdekt."):bilingual("Kies een ontdekt altaar en bevestig om erheen te reizen. Je spullen en gezondheid blijven zoals ze zijn.","Pick a discovered altar and confirm to travel there. Your items and health stay as they are."),info);
   }
   GUI.Label(new Rect(120,568,912,22),binding("ui_prev_tab")+" / "+binding("ui_next_tab")+bilingual(" wisselen · "," switch · ")+binding("ui_cancel")+bilingual(" sluiten"," close"),small);
  }
 }
}
