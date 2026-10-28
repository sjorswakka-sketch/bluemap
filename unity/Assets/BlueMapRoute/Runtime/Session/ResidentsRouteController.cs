using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Residents;
using BlueMapMigration.Story;
using UnityEngine;

namespace BlueMapMigration.Route
{
 public sealed class ResidentLiveActor
 {
  public RouteTarget Target;
  public ResidentMotionState Motion;
  public string Sheet="";
  public string Bubble="";
  public int RoleFrame;
 }
 public sealed partial class RouteWorldController
 {
  public ResidentSocialModel Residents {get;private set;}
  public ResidentsKitchenView ResidentsKitchen {get;private set;}
  readonly List<ResidentLiveActor> residents=new List<ResidentLiveActor>();
  readonly Dictionary<string,ResidentSupperObject> supperObjects=new Dictionary<string,ResidentSupperObject>(StringComparer.Ordinal);
  readonly System.Random residentRandom=new System.Random();
  public IReadOnlyList<ResidentLiveActor> ResidentActors=>residents;
  bool? residentsEnabled;
  string residentsMap="",activeSupperAddress="",residentLanguage="";
  ResidentFootGrid residentTerrain;
  ResidentSourceVisuals residentSourceVisuals;
  List<ResidentRoamObstacle> residentObstacles=new List<ResidentRoamObstacle>();
  public bool ResidentsSimulationEnabled
  {
   get=>residentsEnabled??!Automated;
   set{residentsEnabled=value;if(Residents!=null)LoadResidentsMap(true);}
  }
  static FoundationValue RV(FoundationValue value,string key,FoundationValue fallback)=>StoryModel.G(value,key,fallback);
  void InitializeResidents()
  {
   Residents=new ResidentSocialModel(repository,Story);
   ResidentsKitchen=new ResidentsKitchenView(Catalog,Residents,T,BindingLabel);
   Story.ContextActionResolver=Residents.ResolveStagedAction;
   Residents.PresentationChanged+=ResidentPresentationChanged;
   Residents.KitchenChanged+=ResidentKitchenChanged;
   Story.Changed+=ResidentStoryChanged;
   LoadResidentsMap();
  }
  void DetachResidents()
  {
   if(Residents!=null){Residents.CloseKitchen();Residents.PresentationChanged-=ResidentPresentationChanged;Residents.KitchenChanged-=ResidentKitchenChanged;}
   if(Story!=null)Story.Changed-=ResidentStoryChanged;
   if(Story!=null)Story.ContextActionResolver=null;
   residentSourceVisuals?.Dispose();residentSourceVisuals=null;
   Residents=null;ResidentsKitchen=null;residents.Clear();supperObjects.Clear();residentsMap="";activeSupperAddress="";
  }
  void ResidentKitchenChanged(){World?.Motor?.StopForTransition();}
  void ResidentStoryChanged(){if(Residents?.Pending==true)Residents.SynchronizePendingStitch();}
  void ResidentPresentationChanged()
  {
   if(Residents==null)return;
   if(ResidentsSimulationEnabled)foreach(var pair in supperObjects)PresentSupperObject(pair.Key,pair.Value);
   if(activeSupperAddress!=""&&Residents.Object!=null)
   {
    var t=targets.FirstOrDefault(v=>v.Address==activeSupperAddress);
    if(t!=null){t.Consumed=!Residents.Object.Interactable;World.SetRouteObjectVisible(t.Address,Residents.Object.Visible);}
   }
  }
  void LoadResidentsMap(bool preserveTransient=false)
  {
   if(Residents==null)return;
   bool retain=preserveTransient&&residentsMap==Session.Current.MapId;
   var previous=retain?residents.ToDictionary(a=>a.Target.Address,StringComparer.Ordinal):new Dictionary<string,ResidentLiveActor>(StringComparer.Ordinal);
   residents.Clear();if(!retain){Residents.CloseKitchen();Residents.RemoveObject();foreach(var o in supperObjects.Values)o.Alive=false;supperObjects.Clear();activeSupperAddress="";}
   residentsMap=Session.Current.MapId;
   residentTerrain=new ResidentFootGrid(Session.Current.Width,Session.Current.Height,
    Session.Current.Root.Require("terrain").Require("solidCells").Items.Select(v=>ResidentMotionModel.Cell(FoundationCoordinates.Vector(v)*32)));
   residentObstacles=new List<ResidentRoamObstacle>();
   foreach(var spec in Session.Current.MapData.Require("objects").Items)
   {
    bool enabled=RV(spec,"enabled",FoundationValue.Boolean(true)).AsBool();
    residentObstacles.Add(new ResidentRoamObstacle{Type=RV(spec,"type",StoryModel.S("")).AsString(),Enabled=enabled,
     PositionTiles=Position(spec.Require("pos")),SizeTiles=Position(RV(spec,"size",FoundationJson.ParsePlain("[1,1]")))});
   }
   foreach(var target in targets.Where(t=>new[]{"npc","coast_resident","village_actor","supper_actor","memory_actor"}.Contains(t.Kind)).ToArray())
   {
    if(!Enabled(target))continue;
    ResidentLiveActor actor;
    previous.TryGetValue(target.Address,out actor);
    if(actor!=null&&(actor.Target.Kind!=target.Kind||actor.Target.Id!=target.Id))actor=null;
    if(actor==null&&retain)actor=previous.Values.FirstOrDefault(v=>v.Target.Kind==target.Kind&&v.Target.Id==target.Id);
    if(actor!=null){actor.Target=target;target.Position=actor.Motion.Position;}
    else actor=CreateResident(target);
    residents.Add(actor);
   }
   if(retain)foreach(var actor in previous.Values.Where(a=>a.Target.SceneNode==null&&!residents.Contains(a)))
   {if(actor.Motion.Kind=="memory"&&!Residents.Enabled(actor.Motion.Role))continue;targets.Add(actor.Target);residents.Add(actor);}
   if(Session.Current.MapId=="village"&&!retain)Residents.StartVillage();
   foreach(var t in targets.Where(t=>t.Kind=="supper_object"))
   {
    if(!supperObjects.ContainsKey(t.Address))supperObjects[t.Address]=new ResidentSupperObject{Kind=t.Id,MapId=residentsMap,Position=t.Position};
    var o=supperObjects[t.Address];if(o.Kind=="basket"&&Gameplay.State.Flag("ls_basket")){o.Visible=false;o.Interactable=false;}
    t.Consumed=!o.Interactable;World.SetRouteObjectVisible(t.Address,o.Visible);
    if(ResidentsSimulationEnabled)PresentSupperObject(t.Address,o);
   }
   residentSourceVisuals?.Dispose();residentSourceVisuals=new ResidentSourceVisuals(Catalog,Session.Current,World.RoutePresentation.Objects);
   if(ResidentsSimulationEnabled){RefreshResidentActors();foreach(var actor in residents)PresentResident(actor);residentSourceVisuals.Tick(Gameplay.State);}
  }
  ResidentLiveActor CreateResident(RouteTarget target)
  {
   string kind=target.Kind=="coast_resident"?"coast":target.Kind=="village_actor"?"village":target.Kind=="supper_actor"?"supper":target.Kind=="memory_actor"?"memory":"npc";
   string role=RV(target.Fields,"role",StoryModel.S("")).AsString();
   var motion=new ResidentMotionState{Kind=kind,Id=target.Id,Role=role,Position=target.Position,Anchor=target.Position,Goal=target.Position,
    Wait=kind=="npc"||kind=="coast"?2+residentRandom.NextDouble()*4:kind=="village"?2:kind=="supper"?4:1};
   if(kind=="village"&&Vector2.Distance(motion.Position,World.Position)<28)
   {
    var grid=ResidentGrid("village");var at=ResidentMotionModel.Cell(motion.Position);
    foreach(var offset in new[]{Vector2Int.right,Vector2Int.left,new Vector2Int(0,1),new Vector2Int(0,-1)})
     if(!grid.IsSolid(at+offset)){motion.Position=ResidentFootGrid.Center(at+offset);target.Position=motion.Position;break;}
   }
   string sheet="";int frame=0;
   if(kind=="memory")
   {
    frame=(int)Residents.Place(role).Require("frame").AsInt64();target.Label=Residents.Name(role);
    motion.Resting=Residents.Resting(RV(Session.Current.MapData,"weather",StoryModel.S("")).AsString());
    var points=ResidentMotionModel.Routes(motion,new ResidentMotionContext{WaterWild=Gameplay.State.Flag("ra_water_wild")});
    var goal=points[0];motion.Position=ResidentGrid("memory").SafeSpawn(new Vector2Int((int)goal.x,(int)goal.y),World.Position,residents.Where(a=>a.Motion.Kind=="memory").Select(a=>a.Motion.Position));
    target.Position=motion.Position;motion.Anchor=motion.Position;motion.Goal=motion.Position;
   }
   else if(kind=="village")sheet=role=="gardener"?"op_gardener":"op_courier";
   else if(kind=="supper")
   {sheet=role=="joris"?"npc_meer_joris":role=="bo"?"op_courier":"op_gardener";if(residentsMap=="inn")motion.Wait=(role=="joris"?0:role=="bo"?1:2)*.8;}
   else if(target.Fields.TryGet("data",out var data))sheet=RV(data,"sheet",StoryModel.S("")).AsString();
   return new ResidentLiveActor{Target=target,Motion=motion,Sheet=sheet,RoleFrame=frame};
  }
  ResidentMotionContext ResidentContext(ResidentLiveActor actor)
  {
   var s=actor.Motion;string weather=RV(Session.Current.MapData,"weather",StoryModel.S("")).AsString();
   return new ResidentMotionContext{MapId=residentsMap,Weather=weather,DayTime=Gameplay.State.DayTime,
    Flowing=Residents.Flowing,WaterWild=Gameplay.State.Flag("ra_water_wild"),Resting=Residents.Resting(weather),
    Locked=Gameplay.State.InputLocked,Paused=Gameplay.State.Paused,PlayerPosition=World.Position,
    IsSolid=p=>residentTerrain.IsSolid(ResidentMotionModel.Cell(p)),
    RoamSafe=p=>ResidentPassability.RoamSafe(p,s.Anchor,residentsMap,
     probe=>residentTerrain.IsSolid(ResidentMotionModel.Cell(probe)),residentObstacles,
     residents.Where(a=>a!=actor&&(a.Motion.Kind=="npc"||a.Motion.Kind=="coast"||a.Motion.Id=="meer_joris")).Select(a=>a.Motion.Position)),
    FindPath=(from,goal)=>ResidentPath(actor,from,goal),
    ResolveMove=(from,velocity,dt)=>World.ResolveResidentMove(actor.Target.Address,from,velocity,dt),
    ResolveVelocity=v=>World.ResidentMoveVelocity(actor.Target.Address),
    DrawWaitSeconds=()=>3+residentRandom.NextDouble()*4,DrawChoiceIndex=count=>residentRandom.Next(count)};
  }
  ResidentFootGrid ResidentGrid(string kind)
  {
   var grid=residentTerrain.Clone();
   foreach(var obstacle in residentObstacles)
   {
    string t=obstacle.Type;
    bool blocked=kind=="village"?new[]{"npc","sign","portal","savepoint","wereld_lantaarn","chest"}.Contains(t):kind=="supper"?new[]{"sign","chest","portal","savepoint","profession_resource"}.Contains(t)||t=="npc":new[]{"portal","savepoint","gate","trigger"}.Contains(t);
    if(kind=="supper"&&t=="npc"&&residents.Any(a=>a.Motion.Id=="meer_joris"&&ResidentMotionModel.Cell(a.Motion.Anchor)==new Vector2Int((int)obstacle.PositionTiles.x,(int)obstacle.PositionTiles.y)))blocked=false;
    if(blocked)grid.SetSolid(new Vector2Int((int)obstacle.PositionTiles.x,(int)obstacle.PositionTiles.y));
   }
   if(kind=="village")
   {
    foreach(int x in new[]{14,15})grid.SetSolid(new Vector2Int(x,16));
    if(Residents.OpeningEnabled){grid.SetSolid(new Vector2Int(16,12));grid.SetSolid(new Vector2Int(16,14));}
   }
   else if(kind=="supper")
   {
    foreach(var target in targets.Where(t=>t.Kind=="supper_object"))
     if(target.Id=="table")foreach(int x in new[]{17,18,19})grid.SetSolid(new Vector2Int(x,5));
     else if(target.Id!="basket")grid.SetSolid(ResidentMotionModel.Cell(target.Position));
    if(residentsMap=="inn"&&Gameplay.State.Flag("ls_served"))foreach(var p in new[]{new Vector2Int(17,4),new Vector2Int(20,5),new Vector2Int(17,6)})grid.SetSolid(p);
   }
   else
   {
    foreach(var node in Session.Current.Root.Require("scene").Items)
    {
     if(!node.TryGet("collision",out var collision)||(collision.Require("layer").AsInt64()&1)==0||!Access.NodeVisible(node))continue;
     string script=node.Require("script").AsString();if(script.EndsWith("/player.gd",StringComparison.Ordinal)||script.EndsWith("/memory_actor.gd",StringComparison.Ordinal))continue;
     if(node.Require("parent").Items.Count!=1||node.Require("parent").Items[0].AsString()!="entities")continue;
     string address=RouteSourcePresentation.Address(node);var actor=residents.FirstOrDefault(a=>a.Target.Address==address);
     Vector2 at=actor?.Motion.Position??FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));grid.SetSolid(ResidentMotionModel.Cell(at));
    }
   }
   return grid;
  }
  List<Vector2> ResidentPath(ResidentLiveActor actor,Vector2 from,Vector2Int goal)
  {
   var grid=ResidentGrid(actor.Motion.Kind);var others=residents.Where(a=>a!=actor&&a.Motion.Kind==actor.Motion.Kind).Select(a=>a.Motion.Position);
   if(actor.Motion.Kind=="memory")return grid.MemoryPath(from,goal,others,World.Position);
   if(actor.Motion.Kind=="supper")return grid.SupperPath(from,goal,others,World.Position);
   return grid.FindPath(ResidentMotionModel.Cell(from),goal);
  }
  public void RefreshResidentActors()
  {
   if(Residents==null||!ResidentsSimulationEnabled)return;
   foreach(var actor in residents.Where(a=>(a.Motion.Kind=="npc"||a.Motion.Kind=="coast")&&!Enabled(a.Target)).ToArray())
   {residents.Remove(actor);World.RemoveResident(actor.Target.Address);}
   foreach(var target in targets.Where(t=>(t.Kind=="npc"||t.Kind=="coast_resident")&&Enabled(t)).ToArray())
    if(!residents.Any(a=>a.Target.Address==target.Address)){var actor=CreateResident(target);residents.Add(actor);PresentResident(actor);}
   foreach(string role in Residents.Roles)
   {
    var spec=Residents.Place(role);if(spec.Require("map").AsString()!=residentsMap)continue;
    var existing=residents.FirstOrDefault(a=>a.Motion.Kind=="memory"&&a.Motion.Role==role);
    if(!Residents.Enabled(role))
    {if(existing!=null){residents.Remove(existing);targets.Remove(existing.Target);World.RemoveResident(existing.Target.Address);}continue;}
    if(existing!=null)continue;
    var motion=new ResidentMotionState{Kind="memory",Role=role,Resting=Residents.Resting(RV(Session.Current.MapData,"weather",StoryModel.S("")).AsString())};
    var context=new ResidentMotionContext{WaterWild=Gameplay.State.Flag("ra_water_wild")};var route=ResidentMotionModel.Routes(motion,context);var at=route[0];
    Vector2 pos=ResidentGrid("memory").SafeSpawn(new Vector2Int((int)at.x,(int)at.y),World.Position,residents.Where(a=>a.Motion.Kind=="memory").Select(a=>a.Motion.Position));
    var target=new RouteTarget{Address="resident-memory/"+role,Kind="memory_actor",Id=role,Label=Residents.Name(role),Position=pos,Fields=RouteGameplay.Object(("role",StoryModel.S(role)))};
    targets.Add(target);var actor=CreateResident(target);actor.Motion.Resting=motion.Resting;residents.Add(actor);PresentResident(actor);
   }
   if(residentsMap=="inn"&&Gameplay.State.Flag("ls_served"))
   {
    string[] roles={"joris","bo","nelle"};for(int i=0;i<roles.Length;i++)
    {
     string role=roles[i];if(residents.Any(a=>a.Motion.Kind=="supper"&&a.Motion.Role==role))continue;
     var pos=new Vector2(15.5f,3.5f+i*2)*32;if(Vector2.Distance(pos,World.Position)<28)pos.x+=32;
     var target=new RouteTarget{Address="resident-supper/"+role,Kind="supper_actor",Id="ls_"+role,Label=Translate(role=="joris"?"Visser Joris":role=="bo"?"Bo de broodbezorger":"Nelle de hovenier"),Position=pos,
      Fields=RouteGameplay.Object(("role",StoryModel.S(role)),("npc_id",StoryModel.S("ls_"+role)),("data",RouteGameplay.Object(("name",StoryModel.S(role)))))};
     targets.Add(target);var actor=CreateResident(target);actor.Motion.Wait=i*.8;residents.Add(actor);PresentResident(actor);
    }
   }
  }
  void PresentResident(ResidentLiveActor actor)
  {
   var s=actor.Motion;actor.Target.Position=s.Position;s.VisualDirection=ResidentMotionModel.Direction(s.Velocity,s.VisualDirection);
   World.UpsertResident(actor.Target.Address,s.Kind,actor.Sheet,actor.RoleFrame,s.Position,s.Velocity,s.Time,s.VisualDirection,s.Resting);
   World.UpdateResidentWork(actor.Target.Address,s.Kind,s.Role,s.TaskIndex,s.Path.Count==0,s.Evening,s.Resting);
   if(s.Id=="muis_bos")World.UpdateResidentCat(actor.Target.Address,s.CatPanic,s.CatCalm,s.CatWaiting);
  }
  void PresentSupperObject(string address,ResidentSupperObject obj)
  {
   if(!obj.Alive||obj.MapId!=residentsMap)return;
   World.UpdateResidentObject(address,obj.Kind,obj.Position,obj.Time,obj.Pulling,obj.Progress,World.Position,
    Gameplay.State.Flag("ls_net"),Gameplay.State.Flag("ls_served"),Gameplay.State.Flag("ls_favorite_broth"));
  }
  void TickResidents(double delta,double uiDelta)
  {
   if(Residents==null||!ResidentsSimulationEnabled)return;
   Residents.PlayerPosition=World.Position;Residents.PlayerLoud=World.Motor.Sprinting||World.Motor.IsRolling||(Combat?.Player.AttackTimer??0)>0||(Combat?.Player.BowAnim??0)>0||(Combat?.Player.Phase??"")!="";
   if(residentLanguage!=Locale){residentLanguage=Locale;foreach(var a in residents){a.Bubble="";a.Motion.BubbleTime=0;}if(Residents.Village!=null){Residents.Village.GardenerTime=0;Residents.Village.CourierTime=0;}}
   Residents.SetLanguage(Locale);ResidentsKitchen?.SetControllerActive(ControllerActive);
   if(Residents.Kitchen?.Active==true){Residents.TickKitchen(uiDelta);ResidentsKitchen?.Tick(uiDelta);}
   if(Gameplay.State.Paused)return;
   RefreshResidentActors();residentSourceVisuals.Tick(Gameplay.State);
   if(residentsMap=="village"&&Residents.Village!=null)
   {
    var gardener=residents.FirstOrDefault(a=>a.Motion.Kind=="village"&&a.Motion.Role=="gardener");
    var courier=residents.FirstOrDefault(a=>a.Motion.Kind=="village"&&a.Motion.Role=="courier");
    if(gardener!=null){Residents.Village.GardenerPosition=gardener.Motion.Position;Residents.Village.GardenerTime=gardener.Motion.BubbleTime;}
    if(courier!=null)Residents.Village.CourierTime=courier.Motion.BubbleTime;
    Residents.TickVillage(delta,World.Motor.Sprinting);
    if(gardener!=null){gardener.Bubble=Residents.Village.Gardener;gardener.Motion.BubbleTime=Residents.Village.GardenerTime;}
    if(courier!=null){courier.Bubble=Residents.Village.Courier;courier.Motion.BubbleTime=Residents.Village.CourierTime;}
   }
   var selectedObject=Residents.Object;string selectedAddress=activeSupperAddress;
   foreach(var pair in supperObjects)
   {if(!pair.Value.Alive)continue;Residents.BindObject(pair.Value);activeSupperAddress=pair.Key;Residents.TickObject(delta);PresentSupperObject(pair.Key,pair.Value);}
   Residents.BindObject(selectedObject);activeSupperAddress=selectedAddress;
   foreach(var actor in residents.ToArray())
   {
    var s=actor.Motion;var context=ResidentContext(actor);
    if(s.Kind=="npc"||s.Kind=="coast")s.Time+=delta;
    if(s.Id=="muis_bos")
    {
     s.CatPanic=Gameplay.CatPanic;s.CatCalm=Gameplay.CatCalm;s.CatWaiting=Gameplay.CatWaiting;double calm=s.CatCalm;
     ResidentMotionModel.CatStep(s,delta,context,Residents.PlayerLoud,World.Motor.Velocity,Combat?.Player.AttackTimer??0);
     Gameplay.SynchronizeResidentCat(s.CatCalm,s.CatPanic,s.CatWaiting);if(calm<2&&s.CatCalm>=2)OnSound("rf_purr");
    }
    else ResidentMotionModel.Step(s,delta,context);
    PresentResident(actor);
   }
  }
  bool InteractResidentObject(RouteTarget target)
  {
   Residents.PlayerPosition=World.Position;
   if(target.Kind=="memory_actor")return Residents.TalkMemory(target.Id,RV(Session.Current.MapData,"weather",StoryModel.S("")).AsString(),Vector2.Distance(World.Position,target.Position));
   if(target.Kind=="memory_book")return Residents.ReadBook(Vector2.Distance(World.Position,target.Position));
   if(!supperObjects.TryGetValue(target.Address,out var obj)){obj=new ResidentSupperObject{Kind=target.Id,Position=target.Position,MapId=residentsMap};supperObjects[target.Address]=obj;}
   Residents.BindObject(obj);Residents.SetPending(false);Residents.ObjectPosition=target.Position;activeSupperAddress=target.Address;
   bool opened=Residents.InteractObject();SyncDialogue();if(Gameplay.DialogueOpen)DialoguePanel?.NotifyOpened(storyInput);if(Residents.Kitchen?.Active==true)ResidentsKitchen?.NotifyOpened(storyInput);return opened;
  }
  void DrawResidentBubbles()
  {
   if(!ResidentsSimulationEnabled||Gameplay.State.InputLocked||Modal!=""||Gameplay.DialogueOpen||CurrentTarget!=null)return;
   var style=new GUIStyle(GUI.skin.label){font=Catalog.originalFont,fontSize=13,wordWrap=true,alignment=TextAnchor.MiddleCenter,normal={textColor=new Color(.94f,.94f,.86f)}};
   foreach(var actor in residents.Where(a=>a.Motion.BubbleTime>0&&a.Bubble!=""&&Vector2.Distance(World.Position,a.Motion.Position)<130))
   {
    var point=Camera.WorldToScreenPoint(FoundationCoordinates.ToUnity(actor.Motion.Position+new Vector2(0,-40)));
    if(point.z<0)continue;float x=point.x*1152/Screen.width,y=(Screen.height-point.y)*648/Screen.height;
    float h=style.CalcHeight(new GUIContent(actor.Bubble),176)+12;var r=new Rect(Mathf.Clamp(x-94,10,954),y-h,188,h);
    if(r.y<138||r.yMax>620||r.Overlaps(new Rect(18,144,298,180)))continue;
    GUI.color=new Color(.035f,.072f,.078f,.93f);GUI.DrawTexture(r,Texture2D.whiteTexture);GUI.color=Color.white;GUI.Label(new Rect(r.x+6,r.y+6,176,h-12),actor.Bubble,style);
   }
  }
 }
}
