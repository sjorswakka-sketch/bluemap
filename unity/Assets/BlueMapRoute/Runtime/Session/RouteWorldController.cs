using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.WorldAccess;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using UnityEngine;

namespace BlueMapMigration.Route
{
    public sealed class RouteTarget
    {
        public string Address,Kind,Label,Id,UniqueKey;
        public Vector2 Position;
        public FoundationValue Fields,SceneNode;
        public bool Consumed;
        public double Age;
        public InventoryPickup Pickup;
    }
    // One live adventure owns one source state and one session. Imported parents are never edited.
    public sealed partial class RouteWorldController : MonoBehaviour
    {
        public static readonly string[] Maps={"arena","arena_hall","cave","coast","coast_workshop","dauwbos","depths1","depths2","dorstvallei","fisher_hut","forest","forest_edge","gull_island","harbor","headland","ijsdal","inn","kruipmoeras","lake","library","mistgarden","player_home","prismamine","reedvault","resonance","ridgepass","river_mouth","ruins","shop","smithy","steampeak","sunwell","temple","tidal_hollow","tide_cove","village","watchyard"};
        public WorldAccessModel Access {get;private set;}
        public string NearbyPassage {get;private set;}="";
        public IReadOnlyList<FoundationValue> VoyageRoutes=>boat==null?Array.Empty<FoundationValue>():Access.BoatRoutes(boat.Fields);
        public double VoyageProgress=>Math.Min(1,voyageTime/2.2);
        public long NativeTransitions {get;private set;}
        public string DestinationName(string map)=>Translate(repository.Read(map).MapData.Require("name").AsString());
        private RouteTarget boat,linkedDoor;
        private string linkedDoorMap="";
        private string boatMap="";
        private int boatChoice;
        private double voyageTime;
        private bool accessDirty;
        private string geometrySignature="";
        private IDisposable accessSubscription;
        public PlayerWorld World {get;private set;}
        public RouteGameplay Gameplay {get;private set;}
        public FoundationSession Session {get;private set;}
        public PersistenceCoordinator Persistence {get;private set;}
        public RouteHUD Hud {get;private set;}
        public InventoryModel Inventory=>Gameplay?.Inventory;
        public InventoryPanel InventoryPanel {get;private set;}
        public ProgressionModel Progression=>Gameplay?.Progression;
        public ProgressionPanel ProgressionPanel {get;private set;}
        public string Modal {get;private set;}="";
        public int DialogueLineIndex {get;private set;}
        public int Selection {get;private set;}
        public int InventoryIndex {get=>InventoryPanel?.SelectedIndex??0;private set{if(InventoryPanel!=null)InventoryPanel.SelectedIndex=value;}}
        public float InventoryScroll {get=>InventoryPanel?.Scroll??0;set{if(InventoryPanel!=null)InventoryPanel.Scroll=value;}}
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
        private double workTime,workDuration,autoTime,messageTime,uiRepeat;
        private string lastDialogue="";
        private double inventoryFrameDelta=1.0/60;
        private long spawnedPickupSequence;
        private int lastFullPickupWarning=-200;
        public readonly List<string> ItemNotices=new List<string>();
        private readonly List<double> itemNoticeLives=new List<double>();
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
            switch(value){case "buttonSouth":value="A";break;case "buttonEast":value="B";break;case "buttonWest":value="X";break;case "buttonNorth":value="Y";break;case "leftTrigger":value="LT";break;case "rightTrigger":value="RT";break;case "space":value=T("Spatie","Space");break;case "leftShoulder":value="LB";break;case "rightShoulder":value="RB";break;case "leftStickPress":value="L3";break;case "rightStickPress":value="R3";break;case "select":value="Select";break;case "start":value="Start";break;case "escape":value="Esc";break;case "enter":value="Enter";break;case "tab":value="Tab";break;case "leftCtrl":case "rightCtrl":value="Ctrl";break;case "leftShift":case "rightShift":value="Shift";break;default:value=value.Length==1?value.ToUpperInvariant():value;break;}
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
            Inventory.Language=Locale;Inventory.Translator=Translate;
            InventoryPanel=new InventoryPanel(Inventory,Catalog,Translate,T);
            InventoryPanel.Closed+=CloseModal;InventoryPanel.ContextRequested+=UpdateInventoryContext;
            InventoryPanel.CharacterRequested+=OpenCharacter;
            Progression.Translator=Translate;
            ProgressionPanel=new ProgressionPanel(Progression,Catalog,Translate,T){AvatarPreview=World.DrawAvatarPreview};
            ProgressionPanel.Closed+=CloseModal;ProgressionPanel.InventoryRequested+=OpenInventory;
            Progression.Changed+=ProgressionChanged;Progression.StaminaCapacityChanged+=ProgressionCapacityChanged;Progression.Toast+=ShowMessage;
            InventoryPanel.CanUse=CanUseInventoryItem;InventoryPanel.UseRequested+=UseInventoryItem;
            Inventory.StaminaRestored+=RestoreInventoryStamina;Inventory.Changed+=InventoryChanged;
            Session=new FoundationSession(repository,Gameplay.State);interaction=new FoundationInteractionRegistry(Gameplay.State);Access=new WorldAccessModel(repository,Gameplay.State);conditions=Access.Conditions;
            accessSubscription=Gameplay.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="flags")accessDirty=true;});
            Access.Changed+=AccessChanged;Access.SaveRequested+=OnSaveRequested;World.SetWorldAccess(Access);
            string map=Gameplay.State.MapId;Vector2 saved=Position(Gameplay.State.Position);
            bool relocated=!Maps.Contains(map,StringComparer.Ordinal);
            if(relocated)map="village";
            if(map=="tide_cove")Access.SyncTide(saved,true);
            Access.MigrateSourceWorldState();
            var source=Access.Project(map);string spawn=source.Arrivals.FirstOrDefault(v=>v.Name=="start")?.Name??source.Arrivals[0].Name;
            var requested=!relocated&&float.IsFinite(saved.x)&&float.IsFinite(saved.y)&&saved.x>=0&&saved.y>=0&&saved.x<source.Width*32&&saved.y<source.Height*32?saved:source.Arrivals.First(v=>v.Name==spawn).Resolved;
            var safe=Access.ResolveArrival(source,Access.PrepareSavedPosition(source,requested));if(!Access.SpawnFits(source,safe)){ShowMessage(T("Geen veilige aankomst beschikbaar.","No safe arrival is available."));return false;}
            if(!Session.TryEnterPrepared(source,spawn,safe))throw new InvalidOperationException(Session.LastDiagnostic);
            RecordVisit(map);World.RouteMode=true;World.gameObject.SetActive(true);World.BindSession(Session);World.PresentCurrent();World.ApplyEquipmentBonuses();World.Motor.Stamina.Reset();
            Gameplay.SaveRequested+=OnSaveRequested;Gameplay.ItemObtained+=OnItem;Gameplay.SoundRequested+=OnSound;
            Running=true;Modal="";Selection=0;lastDialogue="";autoTime=0;SaveFailed=false;BuildTargets();InitializeCombat();
            ShowMessage(relocated?T("Je speelkopie begint in het dorp; je oorspronkelijke locatie en profiel zijn bewaard.","Your play copy starts in the village; the original location and profile are retained."):(map=="village"&&Gameplay.State.QuestState("kat")=="none"?T("Welkom in BlueMap Quest. Praat met Pim op het dorpsplein.","Welcome to BlueMap Quest. Talk to Pim in the village."):AreaName));
            return Save();
        }
        private void Detach()
        {
            DetachCombat();
            if(Gameplay!=null){Gameplay.SaveRequested-=OnSaveRequested;Gameplay.ItemObtained-=OnItem;Gameplay.SoundRequested-=OnSound;Gameplay.CloseDialogue();Gameplay.State.SetUi("route_modal",false);}
            if(Inventory!=null){Inventory.StaminaRestored-=RestoreInventoryStamina;Inventory.Changed-=InventoryChanged;}
            if(InventoryPanel!=null){InventoryPanel.CharacterRequested-=OpenCharacter;InventoryPanel.Closed-=CloseModal;InventoryPanel.Close();InventoryPanel=null;}
            if(Progression!=null){Progression.Changed-=ProgressionChanged;Progression.StaminaCapacityChanged-=ProgressionCapacityChanged;Progression.Toast-=ShowMessage;}
            if(ProgressionPanel!=null){ProgressionPanel.Closed-=CloseModal;ProgressionPanel.InventoryRequested-=OpenInventory;ProgressionPanel.Close();ProgressionPanel=null;}
            if(Access!=null){Access.Changed-=AccessChanged;Access.SaveRequested-=OnSaveRequested;}accessSubscription?.Dispose();accessSubscription=null;
            Running=false;work=null;boat=null;ItemNotices.Clear();itemNoticeLives.Clear();Session?.Dispose();Session=null;
        }
        private void RecordVisit(string map)
        {var visits=Gameplay.State.Get("visited_maps").Entries.ToDictionary(p=>p.Key.AsString(),p=>p.Value,StringComparer.Ordinal);visits[map]=FoundationValue.Boolean(true);Gameplay.State.Set("visited_maps",FoundationValue.Object(visits));}
        public bool TryTravel(string map,string spawn,bool preservePosition=false)
        {
            if(!Running||!Maps.Contains(map,StringComparer.Ordinal)||Gameplay.State.InputLocked)return false;
            if(!repository.Read(map).Arrivals.Any(a=>a.Name==spawn)){ShowMessage(T("Deze aankomst bestaat niet.","This arrival does not exist."));return false;}
            Access.MigrateSourceWorldState();
            var old=Gameplay.State.Position;
            var retainedPickups=preservePosition&&Session.Current.MapId==map?targets.Where(t=>t.Kind=="pickup").ToArray():Array.Empty<RouteTarget>();
            if(map=="tide_cove"&&Session.Current.MapId!=map)Access.SyncTide(World.Position,true);
            FoundationWorldSnapshot prepared;Vector2 arrival;
            try{prepared=Access.Project(map);var at=prepared.Arrivals.FirstOrDefault(v=>v.Name==spawn);if(at==null){ShowMessage(T("Deze aankomst bestaat niet.","This arrival does not exist."));return false;}arrival=Access.ResolveArrival(prepared,preservePosition?Access.PrepareSavedPosition(prepared,Position(old)):at.Resolved);if(!Access.SpawnFits(prepared,arrival)){ShowMessage(T("Geen veilige aankomst beschikbaar.","No safe arrival is available."));return false;}}
            catch(Exception error)when(error is FormatException||error is InvalidOperationException){ShowMessage(error.Message);return false;}
            if(!Session.TryEnterPrepared(prepared,spawn,arrival)){ShowMessage(Session.LastDiagnostic);return false;}NativeTransitions++;accessDirty=false;
            work=null;Gameplay.ResetCat();RecordVisit(map);if(!preservePosition)Combat?.StopForTransition();World.PresentCurrent(preservePosition);BuildTargets();RestorePickups(retainedPickups);LoadCombatMap(preservePosition);ShowMessage(AreaName);Save();return true;
        }
        public bool Save()
        {
            if(!Running||Persistence==null||Gameplay.State.Ended||Gameplay.State.Hp<=0)return false;
            bool saved=Persistence.SaveAdventure(Gameplay.State.Snapshot());SaveFailed=!saved;autoTime=0;
            SaveStatus=saved?T("Opgeslagen","Saved"):Persistence.Status;
            if(!saved)ShowMessage(T("Opslaan is niet gelukt; je voortgang blijft actief. Probeer opnieuw.","Saving failed; your progress remains active. Please retry."));
            return saved;
        }
        public bool Reload(bool saveFirst=true)
        {if(!Running||(saveFirst&&!Save()))return false;if(!Persistence.ReloadAdventure()){ShowMessage(Persistence.Status);return false;}return Begin(Persistence);}
        public void OpenInventory()
        {if(!Running)return;SetModal("inventory");UpdateInventoryContext("bag");InventoryPanel.SetControllerActive(ControllerActive);InventoryPanel.Open("bag");InventoryIndex=0;InventoryScroll=0;}
        private void OpenCharacter()=>OpenProgression();
        public void OpenProgression(string tab="overview")
        {if(!Running)return;SetModal("progression");UpdateProgressionContext();ProgressionPanel.SetControllerActive(ControllerActive);ProgressionPanel.Open(tab);}
        public void UpdateProgressionContext()
        {if(Progression==null)return;UpdateInventoryContext();Progression.Translator=Translate;Progression.SetUpgradeContext(Running&&!Gameplay.State.Ended&&!Gameplay.State.Transitioning&&targets.Any(t=>t.Kind=="npc"&&t.Id=="greta"&&Enabled(t)&&Vector2.Distance(World.Position,t.Position)<40));}
        private void ProgressionCapacityChanged(){World.RefreshRouteState();UpdateInventoryContext();}
        private void ProgressionChanged(){World.RefreshRouteState();ProgressionPanel?.Refresh();InventoryPanel?.Refresh();if(Running)Save();}
        public bool OpenStorage(string kind="home")
        {
            if(!Running||(kind!="home"&&kind!="coast"))return false;
            UpdateInventoryContext(kind);SetModal("inventory");InventoryPanel.SetControllerActive(ControllerActive);InventoryPanel.Open(kind);return true;
        }
        private static bool StorageTarget(RouteTarget target)=>target.Kind=="stock_chest"||target.Kind=="coastal_workstation"&&WorldAccessModel.Get(WorldAccessModel.Get(target.Fields,"obj",target.Fields),"role",FoundationValue.StringValue("")).AsString()=="storage";
        public void UpdateInventoryContext(string requestedKind="")
        {
            if(Inventory==null||World==null)return;Inventory.Language=Locale;Inventory.Translator=Translate;
            var source=targets.Where(t=>StorageTarget(t)&&(t.SceneNode==null||Access.NodeVisible(t.SceneNode)))
                .OrderBy(t=>t.Kind=="stock_chest"?0:1).ThenBy(t=>Vector2.Distance(t.Position,World.Position)).FirstOrDefault();
            Inventory.SetContext(source?.Kind=="stock_chest"?"home":"coast",Gameplay.State.MapId,source?.Position??Vector2.zero,World.Position,Running&&source!=null);
            Inventory.Stamina=World.Motor.Stamina.Stamina;Inventory.StaminaCapacity=World.Motor.Stamina.Capacity;
            World.RoutePresentation?.SetHomeStorageOpen(Modal=="inventory"&&(requestedKind!=""?requestedKind:InventoryPanel?.Kind)=="home");
            if(InventoryPanel!=null)InventoryPanel.SummaryText=T("Leven ","Health ")+Gameplay.State.Hp+" / "+Gameplay.State.MaxHp+"   ·   "+Gameplay.State.Coins+T(" munten"," coins")+"\n"+T("Uithoudingsvermogen ","Stamina ")+Math.Round(Inventory.Stamina)+" / "+Math.Round(Inventory.StaminaCapacity);
        }
        private bool CanUseInventoryItem(string id){UpdateInventoryContext();return Inventory.CanUseItem(id);}
        private void UseInventoryItem(string id)
        {
            UpdateInventoryContext();bool used=Inventory.UseItem(id);InventoryPanel.Refresh();
            if(!used&&Inventory.LastMessage!="")ShowMessage(Translate(Inventory.LastMessage));
            if(used)Save();World.RefreshRouteState();
        }
        public bool UseQuickPotion()
        {
            if(!Running||Gameplay.State.InputLocked)return false;
            UpdateInventoryContext();bool used=Inventory.UseItem("potion");
            if(used){work=null;Save();World.RefreshRouteState();}
            else ShowMessage(Translate(Gameplay.State.Count("potion")>0?"Je hebt al alle hartjes.":"Je hebt geen helddrank."));
            return used;
        }
        private void RestoreInventoryStamina(double amount){World.Motor.Stamina.Restore(amount);}
        private void InventoryChanged(){InventoryPanel?.Refresh();World.RefreshRouteState();}

        public void OpenQuests(){SetModal("quests");}
        public void OpenPause(){SetModal("pause");Selection=0;}
        private void SetModal(string mode){if(!Running)return;Combat?.Cancel();if(mode!="inventory")InventoryPanel?.Close();if(mode!="progression")ProgressionPanel?.Close();work=null;Gameplay.CloseDialogue();Modal=mode;Selection=0;Gameplay.State.SetUi("route_modal",mode!="");World.Motor.StopForTransition();}
        public void CloseModal(){if(Gameplay==null)return;linkedDoor=null;Gameplay.CloseDialogue();Modal="";Selection=0;Gameplay.State.SetUi("route_modal",false);lastDialogue="";InventoryPanel?.Close();ProgressionPanel?.Close();World.RoutePresentation?.SetHomeStorageOpen(false);}
        public bool PrepareMovementPreview()
        {
            if(Running&&!Save())return false;
            Detach();World.RouteMode=false;World.BindSession(new FoundationSession(repository,new FoundationGameState()),true);World.Show("village");return true;
        }
        public void ReturnToProfiles(){if(!Save())return;CloseModal();Running=false;World.gameObject.SetActive(false);ProfilesRequested?.Invoke();}
        public void ShowMessage(string text){Message=text??"";messageTime=5;}
        private void OnSaveRequested(){if(Running){Save();World.RefreshRouteState();}}
        private void AccessChanged(){accessDirty=true;World.RefreshRouteState();}
        private string AccessGeometrySignature(string map)=>Access.SelectScenario(map)+(map=="ijsdal"?"|"+Gameplay.State.Flag("lw_heat_west")+"|"+Gameplay.State.Flag("lw_heat_east"):"");
        public bool RefreshAccessGeometry()
        {
            if(!Running||Gameplay.State.InputLocked)return false;accessDirty=false;string map=Session.Current.MapId;
            if(AccessGeometrySignature(map)==geometrySignature){World.RefreshRouteState();return false;}
            return TryTravel(map,Gameplay.State.SpawnName,true);
        }
        public bool OpenLinkedDoor(string address)
        {
            var target=targets.FirstOrDefault(t=>t.Address==address&&t.Kind=="coastal_workstation");
            if(target==null||!Enabled(target)||Gameplay.State.InputLocked||Vector2.Distance(World.Position,target.Position)>=40)return false;
            var spec=WorldAccessModel.Get(target.Fields,"obj",target.Fields);
            if(!WorldAccessModel.Get(spec,"travel_link",FoundationValue.Boolean(false)).AsBool())return false;
            SetModal("door");linkedDoor=target;linkedDoorMap=Gameplay.State.MapId;return true;
        }
        public bool ConfirmLinkedDoor()
        {
            if(Modal!="door"||linkedDoor==null||Gameplay.State.MapId!=linkedDoorMap||!Enabled(linkedDoor)||Vector2.Distance(World.Position,linkedDoor.Position)>=40)return false;
            var spec=WorldAccessModel.Get(linkedDoor.Fields,"obj",linkedDoor.Fields);string map=spec.Require("to").AsString(),spawn=WorldAccessModel.Get(spec,"spawn",FoundationValue.StringValue("start")).AsString();
            CloseModal();return TryTravel(map,spawn);
        }
        public bool OpenVoyage(string address)
        {
            var target=targets.FirstOrDefault(t=>t.Address==address&&(t.Kind=="coast_dock"||t.Kind=="tide_station"));
            if(target==null||Gameplay.State.InputLocked||Vector2.Distance(World.Position,target.Position)>=40||Access.BoatRoutes(target.Fields).Count==0)return false;
            boat=target;boatMap=Gameplay.State.MapId;SetModal("boat");return true;
        }
        public bool ConfirmVoyage(int index)
        {
            var routes=VoyageRoutes;if(Modal!="boat"||index<0||index>=routes.Count)return false;var chosen=routes[index];string map=chosen.Require("to").AsString(),spawn=WorldAccessModel.Get(chosen,"spawn",FoundationValue.StringValue("start")).AsString();
            if(!Access.BoatEligible(boatMap,boat.Position,boat.Fields,map,spawn,World.Position)){CloseModal();ShowMessage(T("Deze overtocht is niet meer beschikbaar.","This crossing is no longer available."));return false;}
            boatChoice=index;voyageTime=0;Modal="boat_sailing";return true;
        }
        public bool ArriveVoyage()
        {
            if(Modal!="boat_sailing"||boat==null)return false;var chosen=VoyageRoutes[boatChoice];string map=chosen.Require("to").AsString(),spawn=WorldAccessModel.Get(chosen,"spawn",FoundationValue.StringValue("start")).AsString();
            bool eligible=Access.BoatEligible(boatMap,boat.Position,boat.Fields,map,spawn,World.Position);CloseModal();boat=null;return eligible&&TryTravel(map,spawn);
        }
        private void OnItem(string id,long count)
        {
            if(count<=0)return;
            ItemNotices.Add("+"+count+"  "+Translate(Gameplay.ItemName(id)));itemNoticeLives.Add(4.5);
            while(ItemNotices.Count>4){ItemNotices.RemoveAt(0);itemNoticeLives.RemoveAt(0);}
        }
        private void TickItemNotices(double delta)
        {
            // Opening a menu pauses the original feed, so unread receipts remain available.
            if(Gameplay.State.InputLocked||Gameplay.DialogueOpen||Gameplay.State.Ended)return;
            while(itemNoticeLives.Count>ItemNotices.Count)itemNoticeLives.RemoveAt(0);
            for(int i=0;i<itemNoticeLives.Count;i++)itemNoticeLives[i]-=delta;
            while(itemNoticeLives.Count>0&&itemNoticeLives[0]<=0){itemNoticeLives.RemoveAt(0);ItemNotices.RemoveAt(0);}
        }
        private void OnSound(string id) {World.PlayRouteEffect(id);if(id=="guardian_roar")World.PlayRouteMusic("guardian");}
        public string[] InventoryItems()=>InventoryPanel?.Ids.ToArray()??Array.Empty<string>();
        public void MoveInventory(int delta){InventoryPanel?.MoveSelection(delta);}
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
        {if(!Running||Automated||!World.gameObject.activeInHierarchy)return;HandleFrame(World.LastInputFrame);Tick(Time.unscaledDeltaTime*World.CombatTimeScale);if(!World.InputSource.ControllerActive&&Input.GetKeyDown(KeyCode.F5))Save();}
        public void HandleFrame(InputFrame frame)
        {
            if(!Running||frame==null||World.ControlsOpen)return;if(ControllerActive!=frame.ControllerActive)Combat?.Cancel();ControllerActive=frame.ControllerActive;
            if(Gameplay.State.Ended){if(frame.Pressed("restart")||frame.Pressed("ui_accept")||frame.Pressed("interact"))RetryAfterDefeat();return;}
            if(Gameplay.DialogueOpen)
            {
                SyncDialogue();if(frame.Pressed("ui_cancel")||frame.Pressed("pause")){CloseModal();return;}
                if(Gameplay.Dialogue.ChoicesReady){if(frame.Pressed("ui_up"))Selection=Math.Max(0,Selection-1);if(frame.Pressed("ui_down"))Selection=Math.Min(Gameplay.Dialogue.Choices.Count-1,Selection+1);if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ChooseDialogue(Selection);}
                else if(frame.Pressed("ui_accept")||frame.Pressed("interact"))AdvanceDialogue();return;
            }
            if(Modal!="")
            {
                if(Modal=="progression")
                {
                    UpdateProgressionContext();ProgressionPanel.SetControllerActive(ControllerActive);ProgressionPanel.HandleInput(frame,inventoryFrameDelta);return;
                }
                if(Modal=="victory"){if(frame.Pressed("ui_accept")||frame.Pressed("interact"))CloseModal();return;}
                if(Modal=="inventory")
                {
                    if(frame.Pressed("menu")&&!InventoryPanel.SearchEditing){CloseModal();return;}
                    UpdateInventoryContext(InventoryPanel.Kind);InventoryPanel.SetControllerActive(ControllerActive);
                    InventoryPanel.HandleInput(frame,inventoryFrameDelta);return;
                }
                if(frame.Pressed("ui_cancel")||frame.Pressed("pause")||frame.Pressed("menu")&&Modal=="inventory"||frame.Pressed("quests")&&Modal=="quests"){CloseModal();return;}
                if(Modal=="door"){if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ConfirmLinkedDoor();}
                else if(Modal=="boat")
                {if(frame.Pressed("ui_up"))Selection=(Selection+VoyageRoutes.Count-1)%VoyageRoutes.Count;if(frame.Pressed("ui_down"))Selection=(Selection+1)%VoyageRoutes.Count;if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ConfirmVoyage(Selection);}
                else if(Modal=="boat_sailing")
                {if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ArriveVoyage();}
                else if(Modal=="pause")
                {if(frame.Pressed("ui_up"))Selection=(Selection+4)%5;if(frame.Pressed("ui_down"))Selection=(Selection+1)%5;if(frame.Pressed("ui_accept")||frame.Pressed("interact"))ActivatePause(Selection);}
                return;
            }
            if(frame.Pressed("menu")){OpenInventory();return;}if(frame.Pressed("quests")){OpenQuests();return;}if(frame.Pressed("pause")){OpenPause();return;}
            if(frame.Pressed("potion")){UseQuickPotion();return;}
            if(frame.Pressed("interact")&&CurrentTarget!=null)InteractTarget(CurrentTarget.Address);
            HandleCombatFrame(frame);
        }
        public void ActivatePause(int index)
        {switch(index){case 0:CloseModal();break;case 1:Save();break;case 2:Reload();break;case 3:CloseModal();World.ToggleControls();break;case 4:ReturnToProfiles();break;}}
        public void Tick(double delta)
        {
            if(!Running||!double.IsFinite(delta)||delta<0)return;uiRepeat=Math.Max(0,uiRepeat-delta);messageTime-=delta;if(messageTime<=0)Message="";TickItemNotices(delta);
            if(Modal=="boat_sailing"){voyageTime+=delta;if(voyageTime>=2.2){ArriveVoyage();return;}}
            if(!Gameplay.State.InputLocked&&Session.Current.MapId=="tide_cove"&&Access.SyncTide(World.Position))accessDirty=true;
            if(accessDirty&&!Gameplay.State.InputLocked)RefreshAccessGeometry();
            foreach(var seal in targets.Where(t=>t.Kind=="diepte_seal"))if(Access.TickSeal(seal.Fields,SealCenter(seal),World.Position,delta)){World.RefreshRouteState();ShowMessage(Translate(Access.LastMessage));}
            inventoryFrameDelta=delta;UpdateInventoryContext(InventoryPanel?.Kind??"bag");UpdateProgressionContext();TickPickups(delta);
            TickCombat(delta);
            bool locked=Gameplay.State.InputLocked;
            if(locked){foreach(var portal in portals)portal.Armed=false;work=null;lastPosition=World.Position;return;}
            autoTime+=delta;if(autoTime>=30&&!SaveFailed)Save();
            var cat=targets.FirstOrDefault(t=>t.Kind=="npc"&&t.Id=="muis_bos"&&!t.Consumed);
            if(cat!=null&&!Gameplay.State.Flag("cat_found"))Gameplay.TickCat(delta,Vector2.Distance(World.Position,cat.Position),World.Motor.Velocity.magnitude,World.Motor.Sprinting||World.Motor.IsRolling);
            NearbyPassage="";var nearby=portals.OrderBy(p=>Vector2.Distance(World.Position,p.Bounds.center)).FirstOrDefault();
            if(nearby!=null&&Vector2.Distance(World.Position,nearby.Bounds.center)<96){var allowed=conditions.CheckAll(nearby.Conditions);NearbyPassage=allowed.Status==FoundationRuleStatus.Supported&&allowed.Value?DestinationName(nearby.Map):Translate(nearby.Locked);}
            CurrentTarget=null;
            var eligible=targets.Where(Enabled).Select(t=>new FoundationInteractionCandidate(t.Address,t.Kind,t.Position.x,t.Position.y));
            var found=interaction.FindTarget(eligible,World.Position.x,World.Position.y,(World.InputSource.ControllerActive||World.InputSource.MouseAimActive),World.Aim.Direction.x,World.Aim.Direction.y);
            if(found.HasValue)CurrentTarget=targets.First(t=>t.Address==found.Value.Id);
            if(work!=null)
            {
                if(Vector2.Distance(World.Position,workOrigin)>4||Vector2.Distance(World.Position,work.Position)>=40){work=null;ShowMessage(T("Verzamelen onderbroken.","Gathering interrupted."));}
                else{workTime+=delta;if(workTime>=workDuration){var completed=work;work=null;if(Gameplay.Gather(completed.Id,completed.UniqueKey)){World.RefreshRouteState();ShowMessage(Translate(Gameplay.LastMessage));}else ShowMessage(Translate(Gameplay.LastMessage));}}
            }
            foreach(var portal in portals)
            {
                portal.Hint=Math.Max(0,portal.Hint-delta);bool inside=portal.Bounds.Contains(World.Position);
                bool segment=Vector2.Distance(lastPosition,World.Position)<=(Math.Max(World.Motor.Velocity.magnitude,235)+100)*delta+8&&Crossed(portal.Bounds,lastPosition,World.Position);
                if(!inside&&!(portal.Armed&&segment)){portal.Armed=true;continue;}if(!portal.Armed)continue;
                var check=conditions.CheckAll(portal.Conditions);
                if(check.Status!=FoundationRuleStatus.Supported||!check.Value||!Maps.Contains(portal.Map,StringComparer.Ordinal))
                {if(portal.Hint<=0){ShowMessage(Translate(portal.Locked));portal.Hint=2.5;}continue;}
                portal.Armed=false;if(TryTravel(portal.Map,portal.Spawn))break;
            }
            // Transfer before clamping; locked exits still retain a safe map boundary.
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
        public RouteTarget SpawnLootPickup(string item,Vector2 position,string uniqueKey="",bool scatter=false)
        {
            if(!Running||String.IsNullOrEmpty(item)||!float.IsFinite(position.x)||!float.IsFinite(position.y))return null;
            if(!String.IsNullOrEmpty(uniqueKey)&&Gameplay.State.Flag(uniqueKey))return null;
            string address="runtime-pickup/"+(++spawnedPickupSequence);
            var pickup=new InventoryPickup(item,position,uniqueKey??"",Gameplay.State.MapId+"/"+address);
            if(scatter)pickup.Toss=UnityEngine.Random.insideUnitCircle.normalized*UnityEngine.Random.Range(40f,90f);
            World.RoutePresentation.SpawnPickup(address,item,position,uniqueKey??"");
            var target=new RouteTarget{Address=address,Kind="pickup",Id=item,UniqueKey=uniqueKey??"",Position=position,Pickup=pickup,
                Fields=RouteGameplay.Object(("item",FoundationValue.StringValue(item)),("unique_key",FoundationValue.StringValue(uniqueKey??"")))};
            targets.Add(target);return target;
        }
        private void TickPickups(double delta)
        {
            foreach(var target in targets.Where(t=>t.Kind=="pickup"&&!t.Consumed))
            {
                if(target.Pickup==null)target.Pickup=new InventoryPickup(target.Id,target.Position,target.UniqueKey,Gameplay.State.MapId+"/"+target.Address);
                Inventory.TickPickup(target.Pickup,World.Position,delta);target.Position=target.Pickup.Position;target.Age=target.Pickup.Age;
                World.SetRouteObjectPosition(target.Address,target.Position);
                if(target.Pickup.Collected){target.Consumed=true;World.SetRouteObjectVisible(target.Address,false);}
                else if(!Gameplay.State.InputLocked&&target.Id!="heart"&&target.Id!="coin"&&Inventory.Room(target.Id)<=0&&target.Age>.2&&Vector2.Distance(World.Position,target.Position)<16&&Time.frameCount-lastFullPickupWarning>=200)
                {lastFullPickupWarning=Time.frameCount;ShowMessage(Translate(Inventory.FullText(target.Id)));}
            }
        }
        private void RestorePickups(IEnumerable<RouteTarget> retained)
        {
            foreach(var previous in retained)
            {
                RouteTarget target;
                if(previous.Address.StartsWith("runtime-pickup/",StringComparison.Ordinal))
                {if(previous.Consumed)continue;target=SpawnLootPickup(previous.Id,previous.Position,previous.UniqueKey);}
                else target=targets.FirstOrDefault(t=>t.Address==previous.Address&&t.Kind=="pickup");
                if(target==null)continue;
                target.Position=previous.Position;target.Age=previous.Age;target.Consumed=previous.Consumed;
                target.Pickup=new InventoryPickup(target.Id,target.Position,target.UniqueKey,Gameplay.State.MapId+"/"+target.Address)
                    {Age=target.Age,Collected=target.Consumed,Toss=previous.Pickup?.Toss??Vector2.zero};
                World.SetRouteObjectPosition(target.Address,target.Position);if(target.Consumed)World.SetRouteObjectVisible(target.Address,false);
            }
        }
        private static Vector2 SealCenter(RouteTarget seal)
        {var spec=WorldAccessModel.Get(seal.Fields,"obj",seal.Fields);var size=WorldAccessModel.Get(spec,"size",FoundationJson.ParsePlain("[1,1]"));return seal.Position+new Vector2(((float)size.Items[0].AsDouble()-1)*16,((float)size.Items[1].AsDouble()-1)*16);}
        private bool Enabled(RouteTarget target)
        {
            if(target.Consumed||target.Kind=="pickup")return false;
            if(target.SceneNode!=null&&!Access.NodeVisible(target.SceneNode))return false;
            if((target.Kind=="gate"||target.Kind=="diepte_gate")&&!Access.GateBlocked(target.Fields))return false;
            if(target.Kind=="diepte_seal")return !Access.SealBreaking(SealCenter(target));
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
                case "combat_post":return InteractCombatPost(target);
                case "diepte_seal":SetModal("sign");Hud.SignSpeaker="Zegel";Hud.SignLines=new[]{Translate("Een zware steenplaat met een ster erin. De runen gloeien zachtjes."),Translate("Hij zit muurvast. Misschien gaat hij pas open als de Blauwe Kaart weer heel is.")};return true;
                case "coastal_workstation":if(StorageTarget(target))return OpenStorage("coast");return OpenLinkedDoor(address);
                case "coast_dock":case "tide_station":return OpenVoyage(address);
                case "gate":case "diepte_gate":bool unlocked=Access.OpenGate(target.Fields);ShowMessage(Translate(Access.LastMessage));World.RefreshRouteState();return unlocked;
                case "npc":bool talked=Gameplay.Talk(target.Id);SyncDialogue();if(!talked)ShowMessage(Translate(Gameplay.LastMessage));return talked;
                case "resource_node":return StartResource(address);
                case "chest":bool opened=Gameplay.OpenChest(target.UniqueKey,target.Fields.Require("contents"));ShowMessage(Translate(Gameplay.LastMessage));World.RefreshRouteState();return opened;
                case "home_station":if(target.Id=="bed"){bool rest=Gameplay.Rest();World.Motor.Stamina.Reset();ShowMessage(Translate(Gameplay.LastMessage));return rest;}ShowMessage(T("Je woning en inrichting zijn bewaard. Uitbreiden volgt later in het migratieplan.","Your home and furnishings are retained. Expansion follows later in the migration plan."));return true;
                case "savepoint":var flags=Gameplay.State.Get("flags").Entries.ToDictionary(p=>p.Key.AsString(),p=>p.Value,StringComparer.Ordinal);flags["altaar_"+Gameplay.State.MapId+"_"+(int)(target.Position.x/32)+"_"+(int)(target.Position.y/32)]=FoundationValue.Boolean(true);Gameplay.State.Set("flags",FoundationValue.Object(flags));Gameplay.Rest();World.Motor.Stamina.Reset();ShowMessage(T("Voortgang opgeslagen. Je bent genezen!","Progress saved. You are healed!"));return true;
                case "sign":SetModal("sign");Hud.SignSpeaker=target.Fields.TryGet("speaker",out var speaker)?speaker.AsString():"";Hud.SignLines=target.Fields.Require("lines").Items.Select(v=>Translate(v.AsString())).ToArray();return true;
                case "stock_chest":return OpenStorage("home");
                default:ShowMessage(T("Deze interactie volgt in een volgende migratiefase.","This interaction arrives in a later migration phase."));return false;
            }
        }
        private void BuildTargets()
        {
            targets.Clear();portals.Clear();spawnedPickupSequence=0;CurrentTarget=null;Gameplay.ResetCat();Inventory.ResetPickupInstances();
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
                if(!new[]{"npc","resource_node","chest","pickup","home_station","stock_chest","savepoint","sign","route_object","opening_device","combat_post","gate","diepte_gate","coast_dock","diepte_seal","coastal_workstation","tide_station"}.Contains(kind))continue;
                if(kind=="combat_post"&&WorldAccessModel.Get(fields.Require("obj"),"kind",FoundationValue.StringValue("")).AsString()=="rack")continue;
                if(kind=="tide_station"&&WorldAccessModel.Get(WorldAccessModel.Get(fields,"obj",fields),"role",FoundationValue.StringValue("")).AsString()!="routes")continue;
                if(kind=="coastal_workstation"&&!WorldAccessModel.Get(WorldAccessModel.Get(fields,"obj",fields),"travel_link",FoundationValue.Boolean(false)).AsBool()&&WorldAccessModel.Get(WorldAccessModel.Get(fields,"obj",fields),"role",FoundationValue.StringValue("")).AsString()!="storage")continue;
                var target=new RouteTarget{Address=RouteSourcePresentation.Address(node),Kind=kind,Position=at,Fields=fields,SceneNode=node,Id="",UniqueKey="",Label=kind};
                switch(kind)
                {
                    case "npc":target.Id=fields.Require("npc_id").AsString();target.Label=fields.Require("data").Require("name").AsString();break;
                    case "resource_node":target.Id=fields.Require("kind").AsString();target.UniqueKey=fields.Require("resource_id").AsString();target.Label=Gameplay.Resources.TryGet(target.Id,out var info)&&info.TryGet("name",out var resourceName)?resourceName.AsString():target.Id;break;
                    case "chest":target.UniqueKey=fields.Require("unique_key").AsString();target.Label=T("Schatkist","Treasure chest");break;
                    case "pickup":target.Id=fields.Require("item").AsString();target.UniqueKey=fields.Require("unique_key").AsString();target.Consumed=target.UniqueKey!=""&&Gameplay.State.Flag(target.UniqueKey);target.Pickup=new InventoryPickup(target.Id,target.Position,target.UniqueKey,Gameplay.State.MapId+"/"+target.Address){Collected=target.Consumed};break;
                    case "home_station":target.Id=fields.Require("obj").Require("role").AsString();if(World.RoutePresentation!=null&&World.RoutePresentation.Objects.TryGetValue("home-furniture/"+target.Id,out var furnishing))target.Position=FoundationCoordinates.ToGodot(furnishing.transform.position);target.Label=target.Id=="bed"?T("Rusten en opslaan","Rest and save"):T("Woning","Home");break;
                    case "diepte_seal":target.Label=T("Zegel","Seal");break;
                    case "coastal_workstation":target.Label=StorageTarget(target)?T("Havenopslag","Harbor storage"):T("Rafs havenwerkplaats","Raf’s harbor workshop");break;
                    case "tide_station":target.Label=T("Bestemmingen en reisroutes","Destinations and travel routes");break;
                    case "coast_dock":target.Label=T("Gratis overtocht","Free crossing");break;
                    case "gate":case "diepte_gate":target.Label=T("Poort openen","Open gate");break;
                    case "savepoint":target.Label=T("Genezen en opslaan","Heal and save");break;
                    case "stock_chest":target.Label=T("Huisopslag","Home storage");break;
                    case "combat_post":target.Label=T("Oefenerf","Training yard");break;
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
            lastPosition=World.Position;World.RefreshRouteState();geometrySignature=AccessGeometrySignature(Session.Current.MapId);accessDirty=false;
        }
        private void OnGUI(){if(!Running||World.ControlsOpen||!World.gameObject.activeInHierarchy)return;var matrix=GUI.matrix;var font=GUI.skin.font;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1152f,Screen.height/648f,1));GUI.skin.font=Catalog.originalFont;InventoryPanel?.SetControllerActive(ControllerActive);ProgressionPanel?.SetControllerActive(ControllerActive);Hud.Draw();GUI.skin.font=font;GUI.matrix=matrix;}
        private bool WantsToQuit()
        {
            if(Automated||!Running||Gameplay.State.Ended)return true;
            if(Save())return true;
            OpenPause();return false;
        }
        private void OnDestroy(){Application.wantsToQuit-=WantsToQuit;Detach();}
    }
}
