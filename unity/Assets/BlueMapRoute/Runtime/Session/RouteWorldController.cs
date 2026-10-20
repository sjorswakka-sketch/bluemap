using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using UnityEngine;

namespace BlueMapMigration.Route
{
    public sealed class RouteTarget
    {
        public string Address,Kind,Label,Id,UniqueKey;
        public Vector2 Position;
        public FoundationValue Fields;
        public bool Consumed;
        public double Age;
    }
    // One live adventure owns one source state and one session. Imported parents are never edited.
    public sealed class RouteWorldController : MonoBehaviour
    {
        public static readonly string[] Maps={"village","player_home","forest_edge","forest"};
        public PlayerWorld World {get;private set;}
        public RouteGameplay Gameplay {get;private set;}
        public FoundationSession Session {get;private set;}
        public PersistenceCoordinator Persistence {get;private set;}
        public RouteHUD Hud {get;private set;}
        public string Modal {get;private set;}="";
        public int DialogueLineIndex {get;private set;}
        public int Selection {get;private set;}
        public int InventoryIndex {get;private set;}
        public float InventoryScroll {get;set;}
        public string Message {get;private set;}="";
        public string SaveStatus {get;private set;}="";
        public bool SaveFailed {get;private set;}
        public bool Running {get;private set;}
        public RouteTarget CurrentTarget {get;private set;}
        public IReadOnlyList<RouteTarget> Targets=>targets;
        public bool Working=>work!=null;
        public float WorkFraction=>work==null?0:Mathf.Clamp01((float)(workTime/workDuration));
        public Camera Camera {get;private set;}
        public Phase6Catalog Catalog {get;private set;}
        public string Locale=>Persistence?.Preferences.Locale??"nl";
        public bool ControllerActive {get;private set;}
        public bool Automated {get;private set;}
        public event Action ProfilesRequested;
        private readonly List<RouteTarget> targets=new List<RouteTarget>();
        private readonly List<Portal> portals=new List<Portal>();
        private FoundationWorldRepository repository;
        private FoundationInteractionRegistry interaction;
        private FoundationConditionRegistry conditions;
        private Phase6Localization localization;
        private RouteTarget work;
        private Vector2 workOrigin,lastPosition;
        private double workTime,workDuration,autoTime,messageTime,noticeTime,uiRepeat;
        private string lastDialogue="";
        public readonly List<string> ItemNotices=new List<string>();
        private sealed class Portal {public Rect Bounds;public string Map,Spawn,Locked;public FoundationValue Conditions;public bool Armed;public double Hint;}
        public void Initialize(PlayerWorld world,Camera camera,Phase6Catalog catalog,bool automated)
        {World=world;Camera=camera;Catalog=catalog;Automated=automated;repository=FoundationWorldRepository.LoadRequired();localization=new Phase6Localization(catalog);Hud=new RouteHUD(this);Application.wantsToQuit+=WantsToQuit;}
        public string T(string nl,string en)=>Locale=="en"?en:nl;
        public string BindingLabel(string action)
        {
            string category=ControllerActive?"controller":"keyboard";
            var binding=World.InputSource.Bindings(action).FirstOrDefault(v=>v.category==category);
            if(binding==null)return action;
            string value=binding.path??"";int slash=value.LastIndexOf('/');if(slash>=0)value=value.Substring(slash+1);
            switch(value){case "buttonSouth":value="A";break;case "buttonEast":value="B";break;case "leftShoulder":value="LB";break;case "rightShoulder":value="RB";break;case "leftStickPress":value="L3";break;case "rightStickPress":value="R3";break;case "select":value="Select";break;case "start":value="Start";break;case "escape":value="Esc";break;case "enter":value="Enter";break;case "tab":value="Tab";break;case "leftCtrl":case "rightCtrl":value="Ctrl";break;case "leftShift":case "rightShift":value="Shift";break;default:value=value.Length==1?value.ToUpperInvariant():value;break;}
            return (binding.ctrl?"Ctrl+":"")+(binding.shift?"Shift+":"")+(binding.alt?"Alt+":"")+value;
        }
        public string Translate(string source)=>localization.Translate(source,locale:Locale);
        public string AreaName=>Session?.Current==null?"":Translate(Session.Current.MapData.TryGet("name",out var name)?name.AsString():Gameplay.State.MapId);
        private static FoundationValue PositionValue(Vector2 p)=>FoundationValue.Array(new[]{FoundationValue.Number(p.x),FoundationValue.Number(p.y)});
        private static Vector2 Position(FoundationValue v)=>new Vector2((float)v.Items[0].AsDouble(),(float)v.Items[1].AsDouble());
        public bool BeginNew(PersistenceCoordinator coordinator)
        {
            if(Running&&!Save())return false;
            var game=RouteGameplay.NewGame(repository);
            var initial=repository.Read("village");game.State.Position=PositionValue((initial.Arrivals.FirstOrDefault(v=>v.Name=="start")??initial.Arrivals[0]).Resolved);
            if(coordinator.HasProfile&&coordinator.Current.Snapshot.State.TryGet("achievements",out var achievements))game.State.Set("achievements",achievements);
            if(!coordinator.CreateRouteCopy(game.State.Snapshot(),false)){ShowMessage(coordinator.Status);return false;}
            return Begin(coordinator);
        }
        public bool BeginContinue(PersistenceCoordinator coordinator)
        {
            if(Running&&!Save())return false;
            if(!coordinator.HasProfile){ShowMessage(T("Open eerst een profiel.","Open a profile first."));return false;}
            if(!coordinator.IsRouteProfile&&!coordinator.CreateRouteCopy(coordinator.Current.Snapshot.State,true)){ShowMessage(coordinator.Status);return false;}
            return Begin(coordinator);
        }
        private bool Begin(PersistenceCoordinator coordinator)
        {
            Detach();Persistence=coordinator;
            Gameplay=new RouteGameplay(repository,new FoundationGameState(coordinator.Current.Snapshot.State));
            Session=new FoundationSession(repository,Gameplay.State);interaction=new FoundationInteractionRegistry(Gameplay.State);conditions=new FoundationConditionRegistry(Gameplay.State);
            string map=Gameplay.State.MapId;Vector2 saved=Position(Gameplay.State.Position);
            bool relocated=!Maps.Contains(map,StringComparer.Ordinal);
            if(relocated)map="village";
            var source=repository.Read(map);string spawn=source.Arrivals.FirstOrDefault(v=>v.Name=="start")?.Name??source.Arrivals[0].Name;
            if(!Session.TryEnter(map,spawn))throw new InvalidOperationException(Session.LastDiagnostic);
            if(!relocated&&saved.x>=0&&saved.y>=0&&saved.x<source.Width*32&&saved.y<source.Height*32)Gameplay.State.Position=PositionValue(saved);
            RecordVisit(map);World.RouteMode=true;World.gameObject.SetActive(true);World.BindSession(Session);World.PresentCurrent();World.Motor.Stamina.Reset();
            Gameplay.SaveRequested+=OnSaveRequested;Gameplay.ItemObtained+=OnItem;Gameplay.SoundRequested+=OnSound;
            Running=true;Modal="";Selection=0;lastDialogue="";autoTime=0;SaveFailed=false;BuildTargets();
            ShowMessage(relocated?T("Je speelkopie begint in het dorp; je oorspronkelijke locatie en profiel zijn bewaard.","Your play copy starts in the village; the original location and profile are retained."):T("Welkom in BlueMap Quest. Praat met Pim op het dorpsplein.","Welcome to BlueMap Quest. Talk to Pim in the village."));
            return Save();
        }
        private void Detach()
        {
            if(Gameplay!=null){Gameplay.SaveRequested-=OnSaveRequested;Gameplay.ItemObtained-=OnItem;Gameplay.SoundRequested-=OnSound;Gameplay.CloseDialogue();Gameplay.State.SetUi("route_modal",false);}
            Running=false;work=null;Session?.Dispose();Session=null;
        }
        private void RecordVisit(string map)
        {var visits=Gameplay.State.Get("visited_maps").Entries.ToDictionary(p=>p.Key.AsString(),p=>p.Value,StringComparer.Ordinal);visits[map]=FoundationValue.Boolean(true);Gameplay.State.Set("visited_maps",FoundationValue.Object(visits));}
        public bool TryTravel(string map,string spawn,bool preservePosition=false)
        {
            if(!Running||!Maps.Contains(map,StringComparer.Ordinal)||Gameplay.State.InputLocked)return false;
            var old=Gameplay.State.Position;
            if(!Session.TryEnter(map,spawn)){ShowMessage(Session.LastDiagnostic);return false;}
            if(preservePosition)Gameplay.State.Position=old;
            work=null;Gameplay.ResetCat();RecordVisit(map);World.PresentCurrent();BuildTargets();ShowMessage(AreaName);Save();return true;
        }
        public bool Save()
        {
            if(!Running||Persistence==null)return false;
            bool saved=Persistence.SaveAdventure(Gameplay.State.Snapshot());SaveFailed=!saved;autoTime=0;
            SaveStatus=saved?T("Opgeslagen","Saved"):Persistence.Status;
            if(!saved)ShowMessage(T("Opslaan is niet gelukt; je voortgang blijft actief. Probeer opnieuw.","Saving failed; your progress remains active. Please retry."));
            return saved;
        }
        public bool Reload(bool saveFirst=true)
        {if(!Running||(saveFirst&&!Save()))return false;if(!Persistence.ReloadAdventure()){ShowMessage(Persistence.Status);return false;}return Begin(Persistence);}
        public void OpenInventory(){SetModal("inventory");InventoryIndex=0;InventoryScroll=0;}
        public void OpenQuests(){SetModal("quests");}
        public void OpenPause(){SetModal("pause");Selection=0;}
        private void SetModal(string mode){if(!Running)return;work=null;Gameplay.CloseDialogue();Modal=mode;Selection=0;Gameplay.State.SetUi("route_modal",mode!="");World.Motor.StopForTransition();}
        public void CloseModal(){if(Gameplay==null)return;Gameplay.CloseDialogue();Modal="";Selection=0;Gameplay.State.SetUi("route_modal",false);lastDialogue="";}
        public bool PrepareMovementPreview()
        {
            if(Running&&!Save())return false;
            Detach();World.RouteMode=false;World.BindSession(new FoundationSession(repository,new FoundationGameState()),true);World.Show("village");return true;
        }
        public void ReturnToProfiles(){if(!Save())return;CloseModal();Running=false;World.gameObject.SetActive(false);ProfilesRequested?.Invoke();}
        public void ShowMessage(string text){Message=text??"";messageTime=5;}
        private void OnSaveRequested(){if(Running){Save();World.RefreshRouteState();}}
        private void OnItem(string id,long count){ItemNotices.Add("+"+count+"  "+Translate(Gameplay.ItemName(id)));while(ItemNotices.Count>4)ItemNotices.RemoveAt(0);noticeTime=5;}
        private void OnSound(string id) {World.PlayRouteEffect(id);}
        public string[] InventoryItems()=>Gameplay.State.Get("inventory").Entries.Where(p=>p.Value.AsInt64()>0).Select(p=>p.Key.AsString()).OrderBy(id=>Translate(Gameplay.ItemName(id)),StringComparer.Ordinal).ToArray();
        public void MoveInventory(int delta)
        {var ids=InventoryItems();InventoryIndex=Mathf.Clamp(InventoryIndex+delta,0,Math.Max(0,ids.Length-1));float top=InventoryIndex*38;if(top<InventoryScroll)InventoryScroll=top;if(top+38>InventoryScroll+310)InventoryScroll=top+38-310;InventoryScroll=Mathf.Clamp(InventoryScroll,0,Math.Max(0,ids.Length*38-310));}
        public void AdvanceDialogue()
        {
            if(!Gameplay.DialogueOpen)return;
            var dialogue=Gameplay.Dialogue;
            if(DialogueLineIndex+1<dialogue.Lines.Count){DialogueLineIndex++;return;}
            Gameplay.Advance();SyncDialogue();World.RefreshRouteState();
            if(!Gameplay.DialogueOpen&&Gameplay.LastMessage!="")ShowMessage(Translate(Gameplay.LastMessage));
        }
        public void ChooseDialogue(int index){if(!Gameplay.DialogueOpen)return;Gameplay.Choose(index);SyncDialogue();World.RefreshRouteState();}
        private void SyncDialogue(){string id=Gameplay.Dialogue?.Id??"";if(id!=lastDialogue){DialogueLineIndex=0;Selection=0;lastDialogue=id;}}
        private void Update()
        {if(!Running||Automated||!World.gameObject.activeInHierarchy)return;HandleFrame(World.LastInputFrame);Tick(Time.unscaledDeltaTime);if(!World.InputSource.ControllerActive&&Input.GetKeyDown(KeyCode.F5))Save();}
        public void HandleFrame(InputFrame frame)
        {
            if(!Running||frame==null||World.ControlsOpen)return;ControllerActive=frame.ControllerActive;
            if(Gameplay.DialogueOpen)
            {
                SyncDialogue();if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseModal();return;}
                if(Gameplay.Dialogue.ChoicesReady){if(frame.Pressed("ui_up"))Selection=Math.Max(0,Selection-1);if(frame.Pressed("ui_down"))Selection=Math.Min(Gameplay.Dialogue.Choices.Count-1,Selection+1);if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ChooseDialogue(Selection);}
                else if(frame.Pressed("ui_accept")||frame.Pressed("interact"))AdvanceDialogue();return;
            }
            if(Modal!="")
            {
                if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("menu")&&Modal=="inventory"||frame.Pressed("quests")&&Modal=="quests"){CloseModal();return;}
                if(Modal=="inventory")
                {
                    if(frame.Pressed("ui_up"))MoveInventory(-1);if(frame.Pressed("ui_down"))MoveInventory(1);
                    if(frame.ControllerActive&&Mathf.Abs(frame.Aim.y)>.25f&&uiRepeat<=0){MoveInventory(frame.Aim.y>0?1:-1);uiRepeat=.1;}
                }
                else if(Modal=="pause")
                {if(frame.Pressed("ui_up"))Selection=(Selection+4)%5;if(frame.Pressed("ui_down"))Selection=(Selection+1)%5;if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivatePause(Selection);}
                return;
            }
            if(frame.Pressed("menu")){OpenInventory();return;}if(frame.Pressed("quests")){OpenQuests();return;}if(frame.Pressed("pause")){OpenPause();return;}
            if(frame.Pressed("interact")&&CurrentTarget!=null)InteractTarget(CurrentTarget.Address);
            if(frame.Pressed("attack")||frame.Pressed("bow"))ShowMessage(T("Gevechten volgen in fase 14; deze bosroute is een rustige proef.","Combat arrives in phase 14; this forest route is a peaceful preview."));
        }
        public void ActivatePause(int index)
        {switch(index){case 0:CloseModal();break;case 1:Save();break;case 2:Reload();break;case 3:CloseModal();World.ToggleControls();break;case 4:ReturnToProfiles();break;}}
        public void Tick(double delta)
        {
            if(!Running||!double.IsFinite(delta)||delta<0)return;uiRepeat=Math.Max(0,uiRepeat-delta);messageTime-=delta;if(messageTime<=0)Message="";noticeTime-=delta;if(noticeTime<=0)ItemNotices.Clear();
            bool locked=Gameplay.State.InputLocked;
            if(locked){foreach(var portal in portals)portal.Armed=false;work=null;lastPosition=World.Position;return;}
            autoTime+=delta;if(autoTime>=30&&!SaveFailed)Save();
            var cat=targets.FirstOrDefault(t=>t.Kind=="npc"&&t.Id=="muis_bos"&&!t.Consumed);
            if(cat!=null&&!Gameplay.State.Flag("cat_found"))Gameplay.TickCat(delta,Vector2.Distance(World.Position,cat.Position),World.Motor.Velocity.magnitude,World.Motor.Sprinting||World.Motor.IsRolling);
            CurrentTarget=null;
            var eligible=targets.Where(Enabled).Select(t=>new FoundationInteractionCandidate(t.Address,t.Kind,t.Position.x,t.Position.y));
            var found=interaction.FindTarget(eligible,World.Position.x,World.Position.y,(World.InputSource.ControllerActive||World.InputSource.MouseAimActive),World.Aim.Direction.x,World.Aim.Direction.y);
            if(found.HasValue)CurrentTarget=targets.First(t=>t.Address==found.Value.Id);
            if(work!=null)
            {
                if(Vector2.Distance(World.Position,workOrigin)>4||Vector2.Distance(World.Position,work.Position)>=40){work=null;ShowMessage(T("Verzamelen onderbroken.","Gathering interrupted."));}
                else{workTime+=delta;if(workTime>=workDuration){var completed=work;work=null;if(Gameplay.Gather(completed.Id,completed.UniqueKey)){World.RefreshRouteState();ShowMessage(Translate(Gameplay.LastMessage));}else ShowMessage(Translate(Gameplay.LastMessage));}}
            }
            foreach(var pickup in targets.Where(t=>t.Kind=="pickup"&&!t.Consumed))
            {
                pickup.Age+=delta;float distance=Vector2.Distance(World.Position,pickup.Position);
                if(pickup.Age>.25&&distance<54+Gameplay.Bonus("magnet_range")){pickup.Position=Vector2.MoveTowards(pickup.Position,World.Position,170*(float)delta);World.SetRouteObjectPosition(pickup.Address,pickup.Position);distance=Vector2.Distance(World.Position,pickup.Position);}
                if(pickup.Age>.2&&distance<16&&Gameplay.CollectPickup(pickup.Id,pickup.UniqueKey)){pickup.Consumed=true;World.SetRouteObjectVisible(pickup.Address,false);}
            }
            foreach(var portal in portals)
            {
                portal.Hint=Math.Max(0,portal.Hint-delta);bool inside=portal.Bounds.Contains(World.Position);
                bool segment=Vector2.Distance(lastPosition,World.Position)<=(Math.Max(World.Motor.Velocity.magnitude,235)+100)*delta+8&&Crossed(portal.Bounds,lastPosition,World.Position);
                if(!inside&&!(portal.Armed&&segment)){portal.Armed=true;continue;}if(!portal.Armed)continue;
                var check=conditions.CheckAll(portal.Conditions);
                if(check.Status!=FoundationRuleStatus.Supported||!check.Value||!Maps.Contains(portal.Map,StringComparer.Ordinal))
                {if(portal.Hint<=0){ShowMessage(Maps.Contains(portal.Map,StringComparer.Ordinal)?Translate(portal.Locked):T("Dit gebied volgt in fase 11. Dorp, woning, bosrand en Fluisterbos zijn nu verbonden.","This area arrives in phase 11. Village, home, forest edge and Whispering Woods are connected now."));portal.Hint=2.5;}continue;}
                portal.Armed=false;if(TryTravel(portal.Map,portal.Spawn))break;
            }
            // Original connected exits transfer before reaching the edge. Until every
            // destination is ported, an unavailable exit must never strand the actor
            // beyond the retained terrain or outside the camera's reachable area.
            Vector2 current=World.Position;
            Vector2 insideMap=new Vector2(Mathf.Clamp(current.x,8,Session.Current.Width*32-8),Mathf.Clamp(current.y,16,Session.Current.Height*32-16));
            if(current!=insideMap){World.Teleport(insideMap);Gameplay.State.Position=PositionValue(insideMap);}
            lastPosition=World.Position;
        }
        public static bool Crossed(Rect rect,Vector2 from,Vector2 to)
        {
            rect=new Rect(rect.x+.01f,rect.y+.01f,rect.width-.02f,rect.height-.02f);float first=0,last=1;Vector2 d=to-from;
            for(int axis=0;axis<2;axis++){float a=axis==0?from.x:from.y,v=axis==0?d.x:d.y,min=axis==0?rect.xMin:rect.yMin,max=axis==0?rect.xMax:rect.yMax;if(Math.Abs(v)<.00001){if(a<=min||a>=max)return false;continue;}float t1=(min-a)/v,t2=(max-a)/v;if(t1>t2){float tmp=t1;t1=t2;t2=tmp;}first=Math.Max(first,t1);last=Math.Min(last,t2);if(first>=last)return false;}return last-first>.00001;
        }
        private bool Enabled(RouteTarget target)
        {
            if(target.Consumed||target.Kind=="pickup")return false;
            if(target.Kind=="npc"&&target.Id=="muis_bos"&&Gameplay.State.Flag("cat_found"))return false;
            if(target.Kind=="npc"&&target.Id=="muis_dorp"&&!Gameplay.State.Flag("cat_home"))return false;
            if(target.Fields.TryGet("exists_if",out var tests)){var result=conditions.CheckAll(tests);if(!result.Value)return false;}
            return true;
        }
        public bool StartResource(string address)
        {
            var target=targets.FirstOrDefault(t=>t.Address==address&&t.Kind=="resource_node");if(target==null||!Enabled(target)||Gameplay.State.InputLocked||Vector2.Distance(World.Position,target.Position)>=40)return false;
            string reason=Gameplay.ResourceReason(target.Id,target.UniqueKey);if(reason!=""){ShowMessage(Translate(reason));return false;}
            work=target;workOrigin=World.Position;workTime=0;workDuration=Gameplay.ResourceDuration(target.Id);return true;
        }
        public bool InteractTarget(string address)
        {
            var target=targets.FirstOrDefault(t=>t.Address==address);if(target==null||!Enabled(target)||Gameplay.State.InputLocked||Vector2.Distance(World.Position,target.Position)>=40)return false;
            work=null;
            switch(target.Kind)
            {
                case "npc":bool talked=Gameplay.Talk(target.Id);SyncDialogue();if(!talked)ShowMessage(Translate(Gameplay.LastMessage));return talked;
                case "resource_node":return StartResource(address);
                case "chest":bool opened=Gameplay.OpenChest(target.UniqueKey,target.Fields.Require("contents"));ShowMessage(Translate(Gameplay.LastMessage));World.RefreshRouteState();return opened;
                case "home_station":if(target.Id=="bed"){bool rest=Gameplay.Rest();World.Motor.Stamina.Reset();ShowMessage(Translate(Gameplay.LastMessage));return rest;}ShowMessage(T("Je woning en inrichting zijn bewaard. Uitbreiden volgt later in het migratieplan.","Your home and furnishings are retained. Expansion follows later in the migration plan."));return true;
                case "savepoint":var flags=Gameplay.State.Get("flags").Entries.ToDictionary(p=>p.Key.AsString(),p=>p.Value,StringComparer.Ordinal);flags["altaar_"+Gameplay.State.MapId+"_"+(int)(target.Position.x/32)+"_"+(int)(target.Position.y/32)]=FoundationValue.Boolean(true);Gameplay.State.Set("flags",FoundationValue.Object(flags));Gameplay.Rest();World.Motor.Stamina.Reset();ShowMessage(T("Voortgang opgeslagen. Je bent genezen!","Progress saved. You are healed!"));return true;
                case "sign":SetModal("sign");Hud.SignSpeaker=target.Fields.TryGet("speaker",out var speaker)?speaker.AsString():"";Hud.SignLines=target.Fields.Require("lines").Items.Select(v=>Translate(v.AsString())).ToArray();return true;
                case "stock_chest":ShowMessage(T("De volledige huisopslag volgt in fase 12; alle opgeslagen voorwerpen zijn behouden.","Full home storage arrives in phase 12; all stored items are retained."));return true;
                default:ShowMessage(T("Deze interactie volgt in een volgende migratiefase.","This interaction arrives in a later migration phase."));return false;
            }
        }
        private void BuildTargets()
        {
            targets.Clear();portals.Clear();CurrentTarget=null;Gameplay.ResetCat();
            foreach(var node in Session.Current.Root.Require("scene").Items)
            {
                if(!node.TryGet("script",out var script)||script.Kind!="string"||!node.TryGet("fields",out var fields))continue;
                string kind=System.IO.Path.GetFileNameWithoutExtension(script.AsString());
                if(!node.TryGet("globalTransform",out var transform))continue;Vector2 at=FoundationCoordinates.Vector(transform.Require("origin"));
                if(kind=="portal")
                {
                    var rect=fields.Require("rect");Vector2 origin=FoundationCoordinates.Vector(rect.Require("position")),size=FoundationCoordinates.Vector(rect.Require("size"));
                    portals.Add(new Portal{Bounds=new Rect(origin,size),Map=fields.Require("target_map").AsString(),Spawn=fields.Require("target_spawn").AsString(),Conditions=fields.TryGet("conditions",out var tests)?tests:FoundationValue.Array(Array.Empty<FoundationValue>()),Locked=fields.TryGet("locked_text",out var text)?text.AsString():T("Deze doorgang is nog gesloten.","This passage is still closed.")});continue;
                }
                if(!new[]{"npc","resource_node","chest","pickup","home_station","stock_chest","savepoint","sign","route_object","opening_device","combat_post"}.Contains(kind))continue;
                var target=new RouteTarget{Address=RouteSourcePresentation.Address(node),Kind=kind,Position=at,Fields=fields,Id="",UniqueKey="",Label=kind};
                switch(kind)
                {
                    case "npc":target.Id=fields.Require("npc_id").AsString();target.Label=fields.Require("data").Require("name").AsString();break;
                    case "resource_node":target.Id=fields.Require("kind").AsString();target.UniqueKey=fields.Require("resource_id").AsString();target.Label=Gameplay.Resources.TryGet(target.Id,out var info)&&info.TryGet("name",out var resourceName)?resourceName.AsString():target.Id;break;
                    case "chest":target.UniqueKey=fields.Require("unique_key").AsString();target.Label=T("Schatkist","Treasure chest");break;
                    case "pickup":target.Id=fields.Require("item").AsString();target.UniqueKey=fields.Require("unique_key").AsString();target.Consumed=target.UniqueKey!=""&&Gameplay.State.Flag(target.UniqueKey);break;
                    case "home_station":target.Id=fields.Require("obj").Require("role").AsString();if(World.RoutePresentation!=null&&World.RoutePresentation.Objects.TryGetValue("home-furniture/"+target.Id,out var furnishing))target.Position=FoundationCoordinates.ToGodot(furnishing.transform.position);target.Label=target.Id=="bed"?T("Rusten en opslaan","Rest and save"):T("Woning","Home");break;
                    case "savepoint":target.Label=T("Genezen en opslaan","Heal and save");break;
                    case "stock_chest":target.Label=T("Huisopslag","Home storage");break;
                    case "sign":target.Label=T("Lezen","Read");break;
                    default:target.Label=T("Onderzoeken","Inspect");break;
                }
                targets.Add(target);if(target.Consumed)World.SetRouteObjectVisible(target.Address,false);
            }
            if(Session.Current.MapId=="village"&&!targets.Any(t=>t.Id=="muis_dorp"))
            {
                var catData=Gameplay.Oracle.Require("catalogs").Require("npcs").Require("muis_dorp");
                var catObject=Session.Current.MapData.Require("objects").Items.First(o=>o.TryGet("id",out var id)&&id.AsString()=="muis_dorp");
                var tile=catObject.Require("pos");
                targets.Add(new RouteTarget{Address="conditional-npc/muis_dorp",Kind="npc",Id="muis_dorp",UniqueKey="",Label=catData.Require("name").AsString(),Position=new Vector2((float)tile.Items[0].AsDouble()*32+16,(float)tile.Items[1].AsDouble()*32+16),Fields=RouteGameplay.Object(("data",catData))});
            }
            lastPosition=World.Position;World.RefreshRouteState();
        }
        private void OnGUI(){if(!Running||World.ControlsOpen||!World.gameObject.activeInHierarchy)return;var matrix=GUI.matrix;var font=GUI.skin.font;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1152f,Screen.height/648f,1));GUI.skin.font=Catalog.originalFont;Hud.Draw();GUI.skin.font=font;GUI.matrix=matrix;}
        private bool WantsToQuit()
        {
            if(Automated||!Running)return true;
            if(Save())return true;
            OpenPause();return false;
        }
        private void OnDestroy(){Application.wantsToQuit-=WantsToQuit;Detach();}
    }
}