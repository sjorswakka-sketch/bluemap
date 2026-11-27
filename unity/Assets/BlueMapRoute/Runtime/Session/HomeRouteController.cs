using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Home;
using BlueMapMigration.Player;
using BlueMapMigration.WorldAccess;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>Connects the original house and yard designers to the playable world.</summary>
 public sealed partial class RouteWorldController
 {
  sealed class YardGate
  {
   public HomeCell Cell;public SpriteRenderer Renderer;public BoxCollider2D Collider;public Sprite Closed,Open;public bool Opened;
  }
  public HomeModel Home {get;private set;}
  public HouseEditorPanel HouseEditor {get;private set;}
  public YardEditorPanel YardEditor {get;private set;}
  public HomeStationMenu HomeMenu {get;private set;}
  public int YardPathNodes {get;private set;} public int YardFenceNodes {get;private set;} public int YardGateNodes=>yardGates.Count;public int YardOpenGates=>yardGates.Count(g=>g.Opened);
  public long YardWorldVersion {get;private set;}
  GameObject yardRoot;readonly List<YardGate> yardGates=new List<YardGate>();FoundationWorldSnapshot homeBuiltFor;bool homeWorldDirty;RouteTarget homeMenuStation;
  static bool HomeModal(string mode)=>mode=="home_menu"||mode=="house_editor"||mode=="yard_editor";
  void InitializeHome()
  {
   Home=new HomeModel(repository,Gameplay.State,Inventory){Translator=Translate};Home.SaveRequested+=OnSaveRequested;Home.Changed+=HomeChanged;
   HouseEditor=new HouseEditorPanel(Catalog,Home,T,BindingLabel,()=>World.Position);HouseEditor.CloseRequested+=CloseModal;HouseEditor.SoundRequested+=OnSound;HouseEditor.Applied+=HouseApplied;
   YardEditor=new YardEditorPanel(Catalog,Home,T,BindingLabel,()=>World.Position);YardEditor.CloseRequested+=CloseModal;YardEditor.SoundRequested+=OnSound;YardEditor.Applied+=YardApplied;
   HomeMenu=new HomeStationMenu(Catalog,T,BindingLabel);HomeMenu.CloseRequested+=CloseModal;HomeMenu.Chosen+=HomeMenuChosen;
   World.SurfaceOverride=YardSurface;homeBuiltFor=null;homeWorldDirty=true;
  }
  void DetachHome()
  {
   if(Home!=null){Home.SaveRequested-=OnSaveRequested;Home.Changed-=HomeChanged;}
   if(World!=null)World.SurfaceOverride=null;ClearYardWorld();
   Home=null;HouseEditor=null;YardEditor=null;HomeMenu=null;homeBuiltFor=null;homeMenuStation=null;
  }
  void HomeChanged(){homeWorldDirty=true;}
  void CloseHomeViews(string keep)
  {
   if(keep!="house_editor")HouseEditor?.Close();if(keep!="yard_editor")YardEditor?.Close();if(keep!="home_menu")HomeMenu?.Close();
  }
  string YardSurface(Vector2 sourcePosition)
  {
   if(Home==null||Session?.Current==null||Session.Current.MapId!="village")return "";
   var kind=InventoryValue(Home.YardView.Require("paths"),new HomeCell(Mathf.FloorToInt(sourcePosition.x/32),Mathf.FloorToInt((sourcePosition.y+8)/32)).Key);
   return kind=="boards"?"yard_boards":kind!=""?"path":"";
  }
  static string InventoryValue(FoundationValue table,string key)=>table.TryGet(key,out var value)&&value.Kind=="string"?value.AsString():"";
  static string StationRole(RouteTarget target)=>target.Id??"";
  string StationUnit(RouteTarget target)
  {
   string role=StationRole(target);if(role=="compost")return "compost";if(role!="wine"&&role!="hive")return "";
   return WorldAccessModel.Get(WorldAccessModel.Get(target.Fields,"obj",target.Fields),"unit",FoundationValue.StringValue(role=="hive"?"hive":"")).AsString();
  }
  bool InteractHomeStation(RouteTarget target)
  {
   string role=StationRole(target),map=Gameplay.State.MapId;var choices=new List<KeyValuePair<string,string>>();string title,body;
   if(map=="player_home"&&(role=="bed"||role=="guide"||role=="supplies"))
   {
    title=Translate(role=="bed"?"Je eigen bed":role=="supplies"?"Tuinvoorraad":"Woning en tuin");
    body=role=="bed"?Translate("Een rustige eigen woning. Rusten vult hartjes en stamina aan en slaat hier op. Het blauwe punt voor je huis ontdekt een snelreisbestemming op de kaart."):T("Dit huis is van jou. Verplaats je meubels, maak nieuwe en kies vloer, wand en licht. Tuinwerk volgt in de volgende migratiefase.","This house is yours. Move your furniture, make more and choose the floor, wall and light. Garden work follows in the next migration phase.");
    if(role=="bed")choices.Add(new KeyValuePair<string,string>("rest",Translate("Rusten en opslaan")));
    choices.Add(new KeyValuePair<string,string>("decorate",Translate("Je huis inrichten")));
   }
   else if(map=="village"&&(role=="guide"||role=="supplies"))
   {
    title=Translate("Woning en tuin");body=T("Dit huis en de tuin zijn van jou. Verplaats je werkplekken, leg paden, hekken en poortjes en ontsluit extra bouwruimte. Landbouw en productie volgen in de volgende migratiefase.","This house and garden are yours. Move your work stations, lay paths, fences and gates and unlock more building room. Farming and production follow in the next migration phase.");
    choices.Add(new KeyValuePair<string,string>("yard",Translate("Erf inrichten")));
   }
   else{ShowMessage(T("Deze werkplek is bewaard; productie volgt in de volgende migratiefase.","This work station is retained; production follows in the next migration phase."));return true;}
   choices.Add(new KeyValuePair<string,string>("close",Translate("Sluiten")));
   homeMenuStation=target;SetModal("home_menu");HomeMenu.SetControllerActive(ControllerActive);HomeMenu.Open(title,body,choices);HomeMenu.NotifyOpened(storyInput);return true;
  }
  void HomeMenuChosen(string id)
  {
   switch(id)
   {
    case "rest":CloseModal();bool rest=Gameplay.Rest();World.Motor.Stamina.Reset();ShowMessage(Translate(Gameplay.LastMessage));if(rest)OnSound("select");break;
    case "decorate":OpenHouseEditor();break;
    case "yard":OpenYardEditor();break;
    default:CloseModal();break;
   }
  }
  public bool OpenHouseEditor()
  {
   if(!Running||Home==null||Gameplay.State.MapId!="player_home")return false;UpdateInventoryContext();SetModal("house_editor");HouseEditor.SetControllerActive(ControllerActive);bool opened=HouseEditor.Open();HouseEditor.NotifyOpened(storyInput);if(!opened)CloseModal();return opened;
  }
  public bool OpenYardEditor()
  {
   if(!Running||Home==null||Gameplay.State.MapId!="village")return false;UpdateInventoryContext();SetModal("yard_editor");YardEditor.SetControllerActive(ControllerActive);bool opened=YardEditor.Open();YardEditor.NotifyOpened(storyInput);if(!opened)CloseModal();return opened;
  }
  /// <summary>The interior is drawn from the saved layout; re-entering the same room rebuilds art and collisions.</summary>
  void HouseApplied()
  {
   CloseModal();Gameplay.State.Position=PositionValue(World.Position);TryTravel("player_home","start",true);ShowMessage(T("Je inrichting is toegepast en opgeslagen.","Your design is applied and saved."));
  }
  void YardApplied(){CloseModal();homeWorldDirty=true;RefreshHomeWorld();ShowMessage(T("Je erf is toegepast en opgeslagen.","Your yard is applied and saved."));}
  bool HandleHomeModal(InputFrame frame)
  {
   if(!HomeModal(Modal))return false;UpdateInventoryContext();
   if(Modal=="home_menu"){HomeMenu.SetControllerActive(ControllerActive);HomeMenu.HandleInput(frame,inventoryFrameDelta);}
   else if(Modal=="house_editor"){HouseEditor.SetControllerActive(ControllerActive);HouseEditor.HandleInput(frame,inventoryFrameDelta);}
   else{YardEditor.SetControllerActive(ControllerActive);YardEditor.HandleInput(frame,inventoryFrameDelta);}
   return true;
  }
  void ClearYardWorld(){if(yardRoot!=null)UnityEngine.Object.Destroy(yardRoot);yardRoot=null;yardGates.Clear();YardPathNodes=0;YardFenceNodes=0;}
  int PathMask(HomeCell at,FoundationValue paths)
  {
   int mask=0,bit=0;foreach(var next in new[]{at.Offset(0,-1),at.Offset(1,0),at.Offset(0,1),at.Offset(-1,0)}){string terrain=Home.Terrain(next);if(paths.TryGet(next.Key,out _)||terrain==","||terrain=="=")mask|=1<<bit;bit++;}
   return mask;
  }
  /// <summary>Draws the saved yard: paths, fences, self-opening gates and the moved or stored work stations.</summary>
  public void RefreshHomeWorld()
  {
   if(Home==null||World==null||Session?.Current==null)return;homeBuiltFor=Session.Current;homeWorldDirty=false;ClearYardWorld();YardWorldVersion++;
   if(Session.Current.MapId!="village")return;
   var yard=Home.YardView;yardRoot=new GameObject("Saved yard design");yardRoot.transform.SetParent(World.transform,false);
   var paths=yard.Require("paths");
   foreach(var path in paths.Entries)
   {
    var cell=HomeModel.ParseCell(path.Key.AsString());var sprite=Catalog.GetSprite("yard:path:"+path.Value.AsString()+":"+PathMask(cell,paths));
    var node=new GameObject("Yard path "+path.Key.AsString());node.transform.SetParent(yardRoot.transform,false);node.transform.localPosition=FoundationCoordinates.ToUnity(new Vector2(cell.X*32+16,cell.Y*32+16));
    var renderer=node.AddComponent<SpriteRenderer>();Catalog.Apply(renderer,sprite);renderer.sortingOrder=-19000;YardPathNodes++;
   }
   foreach(var fence in yard.Require("fences").Entries)
   {
    var cell=HomeModel.ParseCell(fence.Key.AsString());string kind=fence.Value.AsString();int frame=(int)Home.YardPieces.Require(kind).Require("frame").AsInt64();bool vertical=kind.EndsWith("_v",StringComparison.Ordinal);
    var center=new Vector2(cell.X*32+16,cell.Y*32+16);var node=new GameObject("Yard fence "+fence.Key.AsString());node.transform.SetParent(yardRoot.transform,false);node.transform.localPosition=FoundationCoordinates.ToUnity(center);
    var renderer=node.AddComponent<SpriteRenderer>();var closed=Catalog.GetSprite("yard:fence:"+frame);Catalog.Apply(renderer,closed);renderer.sortingOrder=Mathf.RoundToInt(center.y);
    var collider=node.AddComponent<BoxCollider2D>();collider.size=vertical?new Vector2(6/32f,28/32f):new Vector2(28/32f,6/32f);collider.offset=vertical?new Vector2(8/32f,0):new Vector2(0,-8/32f);YardFenceNodes++;
    if(Home.IsGate(kind))
    {
     var gate=new YardGate{Cell=cell,Renderer=renderer,Collider=collider,Closed=closed,Open=Catalog.GetSprite("yard:fence:"+(frame+2))};
     if(Vector2.Distance(World.Position,center)<64){gate.Opened=true;collider.enabled=false;Catalog.Apply(renderer,gate.Open);}
     yardGates.Add(gate);
    }
   }
   foreach(var target in targets.Where(t=>t.Kind=="home_station"))
   {
    string unit=StationUnit(target);if(unit==""||!Home.Units.TryGet(unit,out _))continue;var anchor=Home.Anchor(unit,yard);
    // A stored station keeps its production; it simply leaves the yard until it is placed again.
    Vector2 position=anchor.X<0?new Vector2(-4000,-4000):new Vector2(anchor.X*32+16-(unit=="compost"?12:0),anchor.Y*32+16);
    target.Position=position;World.SetRouteObjectPosition(target.Address,position);
   }
   Physics2D.SyncTransforms();
  }
  void TickHome(double delta)
  {
   if(Home==null||Session?.Current==null)return;
   if(homeWorldDirty||!ReferenceEquals(homeBuiltFor,Session.Current))RefreshHomeWorld();
   foreach(var gate in yardGates)
   {
    float distance=Vector2.Distance(World.Position,new Vector2(gate.Cell.X*32+16,gate.Cell.Y*32+16));bool next=gate.Opened?distance<82:distance<64;
    if(next==gate.Opened)continue;gate.Opened=next;gate.Collider.enabled=!next;Catalog.Apply(gate.Renderer,next?gate.Open:gate.Closed);OnSound("yard_gate");
   }
   if(Modal=="house_editor"&&HouseEditor!=null&&(!HouseEditor.IsOpen||Gameplay.State.MapId!="player_home"))CloseModal();
   if(Modal=="yard_editor"&&YardEditor!=null&&(!YardEditor.IsOpen||Gameplay.State.MapId!="village"))CloseModal();
  }
 }
}
