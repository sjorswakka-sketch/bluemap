using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.Route;
using BlueMapMigration.WorldAccess;
using BlueMapMigration.Combat;
using UnityEngine;

namespace BlueMapMigration.Player
{
    // Original terrain, native foot collisions and layered player motion shared by the live adventure.
    [DefaultExecutionOrder(-50)]
    public sealed class PlayerWorld : MonoBehaviour
    {
        public PlayerMotorModel Motor { get; } = new PlayerMotorModel();
        public CombatModel Combat {get;private set;}
        private PlayerCombatPresentation combatArt;
        private readonly HashSet<string> arrowOver=new HashSet<string>(StringComparer.Ordinal){"water"};
        private double hitstop;private float shake;
        public bool CombatHitstop=>hitstop>0;
        public double CombatTimeScale=>CombatHitstop?.08:1;
        public void CombatImpact(double seconds,double pixels){if(!Frozen){hitstop=Math.Max(hitstop,seconds);shake=Math.Max(shake,(float)pixels);}}
        public void BindCombat(CombatModel combat){Combat=combat;arrowOver.Clear();arrowOver.Add("water");if(combat!=null&&combat.Catalogs.TryGet("arrowOverTiles",out var over))foreach(var type in over.Items)arrowOver.Add(type.AsString());combatArt?.Dispose();combatArt=combat==null?null:new PlayerCombatPresentation(catalog,avatar.transform);}
        public bool Roll(Vector2 direction){bool ok=Motor.TryRoll(direction,Session.State.InputLocked);if(ok){Combat?.OnRolled();stepAudio.PlayEffect("dodge",-3);}return ok;}
        public PlayerAimModel Aim { get; } = new PlayerAimModel();
        public FoundationWorldSnapshot Snapshot { get; private set; }
        public FoundationSession Session { get; private set; }
        public int SourceTileColliders { get; private set; }
        public int SourceObjectColliders { get; private set; }
        public Vector2 Position => FoundationCoordinates.ToGodot(body.position);
        public Rigidbody2D Body => body;
        public CircleCollider2D Foot => foot;
        public SpriteRenderer AvatarRenderer => actor;
        public bool Frozen;
        public bool RouteMode;
        public InputFrame LastInputFrame => frame;
        public RouteSourcePresentation RoutePresentation { get; private set; }
        public WorldAccessModel WorldAccess { get; private set; }
        public void SetWorldAccess(WorldAccessModel access)
        { WorldAccess=access;if(RoutePresentation!=null){RoutePresentation.Access=access;RefreshRouteState();} }
        private bool ownsSession = true;
        private RouteAvatarAppearance routeAppearance;
        private RouteGameplay routeBonuses;
        private UnityEngine.Rendering.SortingGroup routeSort;
        public bool ControllerActive { get; private set; }
        public bool ControlsOpen => controls != null && controls.IsOpen;
        public PlayerInputSource InputSource => input;
        public void SetPersistencePreferences(BlueMapMigration.Persistence.LegacyPreferences preferences,bool linked)
        {stepAudio.SetVolumes((float)preferences.MusicVolume,(float)preferences.SfxVolume,preferences.Muted);controls.PersistsChanges=linked;}
        public void ToggleControls() { controls.Toggle(); Session.State.SetUi("controls-preview",controls.IsOpen); }
        public string DirectionRow { get; private set; } = "down";
        public bool CrosshairVisible => gameObject.activeInHierarchy && Session != null && !Session.State.InputLocked;
        public int LastStepEffects { get; private set; }
        private Phase6Catalog catalog;
        private FoundationWorldRepository repository;
        private FoundationTileSet tileSet;
        private Phase6Audio stepAudio;
        private Camera cameraView;
        private PlayerInputSource input;
        private PlayerControlsPanel controls;
        private InputFrame frame;
        private Rigidbody2D body;
        private CircleCollider2D foot;
        private GameObject terrainRoot, avatar, visual;
        private SpriteRenderer actor;
        private readonly List<Sprite> ownedSprites = new List<Sprite>();
        private readonly List<Texture2D> ownedTextures = new List<Texture2D>();
        private readonly Dictionary<string,GameObject> routeColliderOwners=new Dictionary<string,GameObject>(StringComparer.Ordinal);
        private readonly List<Tuple<SpriteRenderer,Vector2>> crowns = new List<Tuple<SpriteRenderer,Vector2>>();
        private readonly List<Tuple<SpriteRenderer,int,int,int>> waters = new List<Tuple<SpriteRenderer,int,int,int>>();
        private Dictionary<string,CatalogSprite> terrain;
        private string[] tileNames;
        private Vector2 cameraPosition;
        private double clock;
        private bool rollPending, initialized, lastController;
        private readonly RaycastHit2D[] hits = new RaycastHit2D[64];
        public void Initialize(Phase6Catalog source, Camera camera, bool automated)
        {
            catalog = source; cameraView = camera; Frozen = automated;
            repository = FoundationWorldRepository.LoadRequired(); tileSet = new FoundationTileSet(repository);
            Session = new FoundationSession(repository, new FoundationGameState());
            terrain = catalog.sprites.Where(s=>s.definition.id.StartsWith("tile:",StringComparison.Ordinal))
                .ToDictionary(s=>(s.definition.x/32)+":"+(s.definition.y/32));
            tileNames = catalog.sprites.Where(s=>s.definition.id.StartsWith("tile:",StringComparison.Ordinal) && s.definition.y == 0)
                .OrderBy(s=>s.definition.x).Select(s=>s.definition.id.Split(':')[1]).ToArray();
            stepAudio = gameObject.AddComponent<Phase6Audio>(); stepAudio.Initialize(catalog);
            avatar = new GameObject("Source player foot"); avatar.transform.SetParent(transform,false);
            body = avatar.AddComponent<Rigidbody2D>(); body.bodyType = RigidbodyType2D.Kinematic;
            body.gravityScale = 0; body.freezeRotation = true; body.useFullKinematicContacts = true;
            foot = FoundationCollision.Circle(avatar,new Vector2(0,8),7,2,1);
            visual = new GameObject("Source layered appearance"); visual.transform.SetParent(avatar.transform,false);
            actor = visual.AddComponent<SpriteRenderer>();
            input = new PlayerInputSource(); controls = new PlayerControlsPanel(input); input.SetContext(true,false);
            Time.fixedDeltaTime = 1f/60f;
            initialized = true; Show("village");
        }
        public void BindSession(FoundationSession session, bool takeOwnership = false)
        {
            if (session == null) throw new ArgumentNullException(nameof(session));
            if (Session != null && !ReferenceEquals(Session,session))
            { Session.State.SetUi("preview-hidden",false); Session.State.SetUi("controls-preview",false); if (ownsSession) Session.Dispose(); }
            Session=session; ownsSession=takeOwnership;frame=null;rollPending=false;Motor.StopForTransition();
            if(controls.IsOpen)controls.Toggle();input.SetContext(true,false);input.SetFocused(Application.isFocused&&isActiveAndEnabled);
            routeBonuses=RouteMode?new RouteGameplay(repository,Session.State):null;
            Session.State.SetUi("preview-hidden",false); Session.State.SetUi("controls-preview",false);
        }
        public void PresentCurrent(bool preserveMotion=false)
        {
            if (Session.Current==null) throw new InvalidOperationException("Enter the route session before rendering it.");
            var position=Session.State.Position;
            Present(Session.Current,new Vector2((float)position.Items[0].AsDouble(),(float)position.Items[1].AsDouble()),preserveMotion);
        }
        public void Show(string mapId)
        {
            var source = repository.Read(mapId);
            string spawn = source.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name ?? source.Arrivals[0].Name;
            if (!Session.TryEnter(mapId,spawn)) throw new InvalidOperationException(Session.LastDiagnostic);
            Present(Session.Current,Session.Current.Arrivals.First(a=>a.Name==spawn).Resolved);
        }
        public void Present(FoundationWorldSnapshot snapshot, Vector2 sourcePosition,bool preserveMotion=false)
        {
            Snapshot=snapshot??throw new ArgumentNullException(nameof(snapshot));
            if (!float.IsFinite(sourcePosition.x)||!float.IsFinite(sourcePosition.y))throw new FormatException("Non-finite route position.");
            RoutePresentation?.Dispose(); RoutePresentation=null;
            if(!preserveMotion){Motor.StopForTransition();rollPending=false;Aim.DeviceChanged();}
            if (terrainRoot != null) { terrainRoot.SetActive(false); Destroy(terrainRoot); }
            terrainRoot = new GameObject("Retained terrain and passive collision geometry"); terrainRoot.transform.SetParent(transform,false);
            crowns.Clear(); waters.Clear();routeColliderOwners.Clear(); SourceTileColliders=0; SourceObjectColliders=0;
            foreach (var cell in Snapshot.TerrainCells)
            {
                CatalogSprite sprite = terrain[cell.AtlasX+":"+cell.AtlasY];
                var node = SpriteNode(sprite.sprite,FoundationCoordinates.TileCenter(cell.X,cell.Y),-20000,terrainRoot.transform);
                SourceTileColliders += tileSet.AddColliders(terrainRoot,cell);
                string name = tileNames[cell.AtlasX];
                if (name=="tree" || name=="pine" || name=="willow")
                {
                    Vector2 at=new Vector2(cell.X*32+16,cell.Y*32+28);
                    var crown=SpriteNode(catalog.GetSprite("canopy:"+name+":"+cell.AtlasY),FoundationCoordinates.ToUnity(at),(int)at.y,terrainRoot.transform);
                    crowns.Add(Tuple.Create(crown,at));
                }
                int waterRow = name=="water" ? 0 : name=="ce_sea" ? 1 : name=="bog_water" ? 2 : name=="ce_shore" ? 3 : -1;
                if (waterRow>=0) waters.Add(Tuple.Create(node,cell.X,cell.Y,waterRow));
            }
            AddSourceObjects();
            if(RouteMode)
            {
                RoutePresentation=new RouteSourcePresentation(catalog,Snapshot,Session.State,terrainRoot.transform,WorldAccess);
                if(routeAppearance==null)routeAppearance=new RouteAvatarAppearance(catalog,visual.transform);
                if(routeSort==null)routeSort=visual.AddComponent<UnityEngine.Rendering.SortingGroup>();
            }
            if(routeAppearance!=null)routeAppearance.Visible=RouteMode;
            if(routeSort!=null)routeSort.enabled=RouteMode;
            if(preserveMotion){MoveBody(FoundationCoordinates.ToUnity(sourcePosition));Physics2D.SyncTransforms();}
            else{Teleport(sourcePosition);Aim.Update(Position,Motor.Facing,Vector2.zero,Vector2.zero,false,false,Vector2.zero,false);cameraPosition=PlayerCameraMath.Clamp(Position,Snapshot.Width,Snapshot.Height);}
            ConfigureCamera(); UpdateAppearance();
            if (!Frozen) stepAudio.PlayMusic(Snapshot.MapData.TryGet("music",out var music)?music.AsString():"forest");
            SyncRouteFeet();Physics2D.SyncTransforms();
        }
        private SpriteRenderer SpriteNode(Sprite sprite, Vector2 position,int order,Transform parent)
        {
            if(sprite==null) throw new FormatException("Original sprite missing.");
            var node=new GameObject("Retained sprite"); node.transform.SetParent(parent,false); node.transform.localPosition=position;
            var renderer=node.AddComponent<SpriteRenderer>(); catalog.Apply(renderer,sprite); renderer.sortingOrder=order; return renderer;
        }
        private void AddSourceObjects()
        {
            // Preserve every source static/actor foot shape. Pending object graphics are
            // deliberately marked with a small amber outline instead of invisible walls.
            var nodes=Snapshot.Root.Require("scene").Items;
            var byAddress=nodes.ToDictionary(n=>n.Require("address").CanonicalJson);
            foreach(var node in nodes)
            {
                if(!node.TryGet("shape",out var shape)) continue;
                var parent=byAddress[node.Require("parent").CanonicalJson];
                bool disabled=shape.Require("disabled").AsBool();
                bool statefulGate=RouteMode&&parent.Require("fields").TryGet("block_if",out _);
                if(disabled&&!statefulGate)continue;
                if(!parent.TryGet("collision",out var collision) || parent.Require("script").AsString().EndsWith("/player.gd",StringComparison.Ordinal)) continue;
                if(RouteMode&&Snapshot.MapId=="player_home")
                {
                    string sourceScript=parent.Require("script").AsString();var sourceFields=parent.Require("fields");
                    if(sourceScript.EndsWith("/house_furniture.gd",StringComparison.Ordinal))continue;
                    if(sourceScript.EndsWith("/home_station.gd",StringComparison.Ordinal)&&sourceFields.TryGet("obj",out var sourceObject)&&sourceObject.TryGet("role",out var sourceRole)&&new[]{"bed","table","shelf"}.Contains(sourceRole.AsString()))continue;
                }
                uint layer=checked((uint)collision.Require("layer").AsInt64()),mask=checked((uint)collision.Require("mask").AsInt64());
                if(!FoundationCollision.GodotCanPair(2,1,layer,mask))continue;
                if(shape.Require("oneWay").AsBool())throw new FormatException("Source object has one-way geometry requiring an adapter.");
                Matrix4x4 matrix=FoundationCoordinates.Transform(node.Require("globalTransform"));
                var owner=new GameObject("Retained object foot: "+parent.Require("script").AsString()); owner.transform.SetParent(terrainRoot.transform,false);
                owner.transform.localPosition=matrix.GetColumn(3);
                if(RouteMode)routeColliderOwners[RouteSourcePresentation.Address(parent)]=owner;
                Vector3 x=matrix.GetColumn(0),y=matrix.GetColumn(1);
                owner.transform.localRotation=Quaternion.Euler(0,0,Mathf.Atan2(x.y,x.x)*Mathf.Rad2Deg);
                owner.transform.localScale=new Vector3(x.magnitude,y.magnitude*Mathf.Sign(x.x*y.y-x.y*y.x),1);
                var parameters=shape.Require("parameters"); string kind=shape.Require("class").AsString(); Vector2 size;
                if(kind=="CircleShape2D")
                { float radius=(float)parameters.Require("radius").AsDouble(); FoundationCollision.Circle(owner,Vector2.zero,radius,layer,mask); size=Vector2.one*radius*2; }
                else if(kind=="RectangleShape2D")
                { size=FoundationCoordinates.Vector(parameters.Require("size")); FoundationCollision.Box(owner,new Rect(-size*.5f,size),layer,mask); }
                else throw new FormatException("Unsupported source object foot: "+kind);
                if(!disabled)SourceObjectColliders++;
                string script=parent.Require("script").AsString();
                if(RouteMode)continue;
                if(script.EndsWith("/npc.gd",StringComparison.Ordinal))
                {
                    var fields=parent.Require("fields"); string spriteId="";
                    if(fields.TryGet("data",out var data) && data.TryGet("sheet",out var art))spriteId=art.AsString();
                    Sprite sprite=catalog.GetSprite(spriteId+":down:idle");
                    if(sprite!=null)
                    { var r=SpriteNode(sprite,FoundationCoordinates.ToUnity(FoundationCoordinates.Vector(parent.Require("globalTransform").Require("origin"))),(int)FoundationCoordinates.Vector(parent.Require("globalTransform").Require("origin")).y,terrainRoot.transform); continue; }
                }
                Sprite outline=Outline(size); var marker=new GameObject("Visible pending-object footprint");marker.transform.SetParent(owner.transform,false);
                var renderer=marker.AddComponent<SpriteRenderer>(); renderer.sprite=outline;renderer.sharedMaterial=catalog.straightMaterial;renderer.sortingOrder=19000;
            }
        }
        private Sprite Outline(Vector2 size)
        {
            int width=Mathf.Max(2,Mathf.CeilToInt(size.x)),height=Mathf.Max(2,Mathf.CeilToInt(size.y));
            var texture=new Texture2D(width,height,TextureFormat.RGBA32,false,true);texture.filterMode=FilterMode.Point;texture.wrapMode=TextureWrapMode.Clamp;
            var pixels=new Color32[width*height];var color=new Color32(224,192,112,150);
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)if(x==0||y==0||x==width-1||y==height-1)pixels[y*width+x]=color;
            texture.SetPixels32(pixels);texture.Apply();ownedTextures.Add(texture);
            Sprite sprite=Sprite.Create(texture,new Rect(0,0,width,height),Vector2.one*.5f,32);ownedSprites.Add(sprite);return sprite;
        }
        public void FocusCameraOnPlayer(){cameraPosition=PlayerCameraMath.Clamp(Position,Snapshot.Width,Snapshot.Height);ConfigureCamera();}
        public void Teleport(Vector2 sourcePosition)
        { Motor.StopForTransition(); MoveBody(FoundationCoordinates.ToUnity(sourcePosition)); Physics2D.SyncTransforms(); }
        private void MoveBody(Vector2 position)
        {
            // Rigidbody.position schedules a physics pose. Also synchronize the
            // visible transform for a same-frame teleport and GPU capture.
            body.position=position; avatar.transform.position=new Vector3(position.x,position.y,0);
        }
        public string SurfaceAt(Vector2 sourcePosition)
        {
            int x=Mathf.FloorToInt(sourcePosition.x/32),y=Mathf.FloorToInt((sourcePosition.y+8)/32);
            if(x<0||y<0||x>=Snapshot.Width||y>=Snapshot.Height)return "";
            var cell=Snapshot.TerrainCells[y*Snapshot.Width+x]; return tileNames[cell.AtlasX];
        }
        public string TileAt(Vector2 point)
        {int x=Mathf.FloorToInt(point.x/32),y=Mathf.FloorToInt(point.y/32);return x<0||y<0||x>=Snapshot.Width||y>=Snapshot.Height?"":tileNames[Snapshot.TerrainCells[y*Snapshot.Width+x].AtlasX];}
        public bool CombatSolid(Vector2 point)
        {int x=Mathf.FloorToInt(point.x/32),y=Mathf.FloorToInt(point.y/32);if(x<0||y<0||x>=Snapshot.Width||y>=Snapshot.Height)return true;return tileSet.IsSolid(Snapshot.TerrainCells[y*Snapshot.Width+x]);}
        public bool CombatBodyFits(Vector2 point,float radius)
        {var colliders=Physics2D.OverlapCircleAll(FoundationCoordinates.ToUnity(point),radius/32,FoundationCollision.Mask(1));return !colliders.Any(c=>!c.isTrigger&&c!=foot);}
        public bool CombatClearLine(Vector2 from,Vector2 to,bool arrow=false)
        {
            var start=FoundationCoordinates.ToUnity(from);var end=FoundationCoordinates.ToUnity(to);var d=end-start;
            foreach(var hit in Physics2D.RaycastAll(start,d.normalized,d.magnitude,FoundationCollision.Mask(1)))
            {
                if(hit.collider==null||hit.collider.isTrigger||hit.collider==foot)continue;
                if(arrow&&hit.collider.gameObject.name.StartsWith("tile ",StringComparison.Ordinal))
                {string[] xy=hit.collider.gameObject.name.Substring(5).Split(',');if(xy.Length==2&&int.TryParse(xy[0],out int x)&&int.TryParse(xy[1],out int y)&&arrowOver.Contains(TileAt(new Vector2(x*32+16,y*32+16))))continue;}
                return false;
            }
            return true;
        }
        public Vector2 Sweep(Vector2 displacement)
        {
            Vector2 remaining=FoundationCoordinates.ToUnity(displacement),position=body.position;
            var filter=new ContactFilter2D { useTriggers=false, useLayerMask=true, layerMask=~0 };
            for(int slide=0;slide<4 && remaining.sqrMagnitude>1e-12f;slide++)
            {
                Physics2D.SyncTransforms();float distance=remaining.magnitude;
                int count=body.Cast(remaining/distance,filter,hits,distance+.08f/32);
                float nearest=distance;Vector2 normal=Vector2.zero;
                for(int i=0;i<count;i++)
                {
                    var hit=hits[i];if(hit.collider==foot||hit.collider.isTrigger)continue;
                    var bits=hit.collider.GetComponent<FoundationCollisionBits>();
                    if(bits==null||!FoundationCollision.GodotCanPair(2,1,bits.sourceLayer,bits.sourceMask))continue;
                    if(Vector2.Dot(remaining,hit.normal)>=0)continue;
                    float travel=Mathf.Max(0,hit.distance-.08f/32);
                    if(travel<=nearest){nearest=travel;normal=hit.normal;}
                }
                Vector2 advance=remaining/distance*nearest;position+=advance;MoveBody(position);
                if(normal==Vector2.zero){remaining=Vector2.zero;break;}
                remaining-=advance;remaining-=normal*Mathf.Min(0,Vector2.Dot(remaining,normal));
            }
            Physics2D.SyncTransforms();return FoundationCoordinates.ToGodot(position);
        }
        public string Step(double delta,MotionInput motion)
        {
            Vector2 before=Position; motion.TileName=SurfaceAt(before);
            if(Combat!=null&&!motion.Paused){Combat.Player.Position=before;Combat.Player.AimDirection=Aim.Direction;Combat.BeforePhysics(delta);motion.AttackActive|=Combat.Player.AttackTimer>0;motion.BowActive|=Combat.Player.BowAnim>0;motion.CombatBusy|=Combat.TechniqueBusy;motion.CombatMovementFactor=Combat.MovementScale;}
            if(RouteMode)
            {
                ApplyEquipmentBonuses();
                motion.SpeedMultiplier=PlayerSurface.EquipmentSpeedMultiplier(Session.State.Count("boots")>0,routeBonuses.Bonus("move_speed"));
            }
            MotionFrame next=Motor.BeginStep(delta,motion); Sweep(next.VelocityPixels*(float)delta);
            string sound=Motor.CompleteStep(next,PlayerMotorModel.SourceLength(Position-before),SurfaceAt(Position));
            if(sound!=""&&stepAudio.PlayEffect("step_"+sound,Motor.Sprinting?-13:-17,UnityEngine.Random.Range(.94f,1.06f)))LastStepEffects++;
            if(Combat!=null&&!motion.Paused){Combat.Player.Position=Position;Combat.AfterPhysics(delta);}
            Session.State.Position=FoundationValue.Array(new[]{FoundationValue.Number(Position.x),FoundationValue.Number(Position.y)});UpdateAppearance();return sound;
        }
        private void Update()
        {
            if(!initialized||Frozen)return;
            hitstop=Math.Max(0,hitstop-Time.unscaledDeltaTime);shake=Mathf.MoveTowards(shake,0,22*Time.unscaledDeltaTime);
            frame=input.Read();ControllerActive=frame.ControllerActive;
            if(ControllerActive!=lastController){Aim.DeviceChanged();Combat?.Cancel();rollPending=false;lastController=ControllerActive;}
            if(Session.State.InputLocked)Combat?.Cancel();
            bool panelHandled=controls.IsOpen;
            if(!controls.BlocksShortcuts&&(UnityEngine.Input.GetKeyDown(KeyCode.F9)||(!RouteMode&&frame.Pressed("menu"))))controls.Toggle();
            controls.Handle(frame);
            panelHandled|=controls.IsOpen;
            Session.State.SetUi("controls-preview",controls.IsOpen);
            if(!RouteMode&&!panelHandled&&frame.Pressed("pause"))Session.State.SetUi("player-preview",!Session.State.Paused);
            input.SetContext(true,Session.State.InputLocked);
            if(!panelHandled&&!Session.State.InputLocked&&frame.RollPressed)rollPending=true;
            Session.Clock.Tick(Time.unscaledDeltaTime*CombatTimeScale);
            if(!Session.State.Paused)clock+=Time.unscaledDeltaTime*CombatTimeScale;
            if(!Session.State.InputLocked)
            {
                Vector2 mouse=FoundationCoordinates.ToGodot(cameraView.ScreenToWorldPoint(frame.MousePosition));
                Aim.Update(Position,Motor.Facing,frame.Move,frame.Aim,frame.ControllerActive,frame.MouseAimActive,mouse,false);
                Motor.AimDirection=Aim.Direction;
            }
            UpdateAppearance();
            RoutePresentation?.Tick(clock,Session.State);SyncRouteFeet();
        }
        private void FixedUpdate()
        {
            if(!initialized||Frozen||frame==null)return;
            if(rollPending)
            { Roll(frame.Move);rollPending=false; }
            Step(Time.fixedDeltaTime*CombatTimeScale,new MotionInput { Direction=frame.Move,SprintHeld=frame.SprintHeld,Locked=Session.State.InputLocked,Paused=Session.State.Paused });
        }
        private void LateUpdate()
        {
            if(!initialized)return;
            if(!Frozen&&!Session.State.Paused)cameraPosition=PlayerCameraMath.Follow(cameraPosition,Position,Time.unscaledDeltaTime*CombatTimeScale);
            cameraPosition=PlayerCameraMath.Clamp(cameraPosition,Snapshot.Width,Snapshot.Height);ConfigureCamera();
            foreach(var crown in crowns)
            {
                Vector2 at=crown.Item2,footAt=Position+new Vector2(0,12);
                bool behind=footAt.x>=at.x-25&&footAt.x<at.x+25&&footAt.y>=at.y-59&&footAt.y<at.y-5;
                crown.Item1.color=new Color(1,1,1,behind?.48f:1);
            }
        }
        private void ConfigureCamera()
        {
            cameraView.orthographic=true;cameraView.orthographicSize=5.0625f;
            Vector2 offset=shake>0?UnityEngine.Random.insideUnitCircle*shake:Vector2.zero;
            Vector2 at=FoundationCoordinates.ToUnity(cameraPosition+offset);cameraView.transform.position=new Vector3(at.x,at.y,-10);
        }
        public void UpdateAppearance()
        {
            Vector2 facing=Motor.Facing;
            DirectionRow=Mathf.Abs(facing.y)>Mathf.Abs(facing.x)?(facing.y>0?"down":"up"):(facing.x>0?"right":"left");
            string column=Motor.IsRolling?"step1":Motor.Moving?(((int)(Motor.WalkTime*9)%2)==0?"step1":"step2"):"idle";
            catalog.Apply(actor,catalog.GetSprite((RouteMode?"player:":"generated:hair:m_kort:")+DirectionRow+":"+column));
            if(routeAppearance!=null){routeAppearance.Visible=RouteMode; if(RouteMode)routeAppearance.Update(Session.State,DirectionRow,column,0,Motor.IsRollSafe?.8f:1);}
            float bob=Motor.Moving?Mathf.Sin((float)Motor.WalkTime*18)*(Motor.Sprinting?1.6f:.6f):Mathf.Sin((float)clock*2.4f)*.55f;
            if(Motor.IsRolling)
            {
                float angle=(float)(1-Motor.RollTimer/PlayerMotorModel.RollTime)*360*(Motor.RollDirection.x<0?-1:1);
                visual.transform.localRotation=Quaternion.Euler(0,0,-angle);
                Vector2 pivot=Quaternion.Euler(0,0,-angle)*new Vector2(0,4f/32);
                visual.transform.localPosition=new Vector3(pivot.x,pivot.y-4f/32,0);
            }
            else { visual.transform.localRotation=Quaternion.identity;visual.transform.localPosition=new Vector3(0,-bob/32,0); }
            if(Combat!=null&&Combat.Player.AttackTimer>0){Vector2 lean=Combat.Player.AttackDirection*Mathf.Sin((float)(1-Combat.Player.AttackTimer/.18)*Mathf.PI)*3;visual.transform.localPosition+=new Vector3(lean.x/32,-lean.y/32,0);}
            bool flicker=Combat!=null&&Combat.Player.Invulnerable>0&&((int)(Combat.Player.Invulnerable*12)%2==0);visual.SetActive(!flicker);combatArt?.Draw(Combat,Position);
            actor.color=new Color(1,1,1,Motor.IsRollSafe?.8f:1);actor.sortingOrder=RouteMode?0:Mathf.RoundToInt(Position.y)+1;
            if(routeSort!=null){routeSort.enabled=RouteMode;routeSort.sortingOrder=Mathf.RoundToInt(Position.y)+1;}
        }
        private void OnGUI()
        {
            if(!initialized)return;
            Matrix4x4 old=GUI.matrix;GUI.matrix=Matrix4x4.Scale(new Vector3(Screen.width/1152f,Screen.height/648f,1));
            GUI.skin.font=catalog.originalFont;
            if(controls.IsOpen)
            {
                GUI.color=new Color(0,0,0,.58f);GUI.DrawTexture(new Rect(0,0,1152,648),Texture2D.whiteTexture);
                GUI.color=new Color(.075f,.12f,.13f,1);GUI.DrawTexture(new Rect(196,80,760,480),Texture2D.whiteTexture);
                GUI.color=Color.white;controls.Draw(new Rect(196,80,760,480));GUI.matrix=old;return;
            }
            if(RouteMode){GUI.matrix=old;return;}
            var label=new GUIStyle(GUI.skin.label){fontSize=15,normal={textColor=new Color(.91f,.94f,.86f)}};
            GUI.Box(new Rect(16,14,510,80),"");GUI.Label(new Rect(28,22,480,24),"BlueMap Quest  /  Unity: loopproef",label);
            GUI.Label(new Rect(28,45,480,24),"Oorspronkelijk terrein • "+Snapshot.MapId+" • objectfuncties volgen",label);
            GUI.Box(new Rect(16,548,660,84),"");
            GUI.Label(new Rect(28,555,636,23),ControllerActive?"Linker stick lopen • L3 rennen • B rollen • rechter stick richten":"WASD / pijlen lopen • Ctrl rennen • Shift / K rollen • muis richten",label);
            GUI.Label(new Rect(28,578,636,23),"F1 Dorp   F2 Bos   F3 Grot   P / Start pauze   9 Opslag",label);
            GUI.Label(new Rect(28,601,636,23),Session.State.Paused?"Gepauzeerd — geen persoonlijke opslag":"Losse bewegingsproef — geen persoonlijke opslag",label);
            GUI.Box(new Rect(872,14,264,54),"");
            GUI.Label(new Rect(884,20,242,22),"Stamina "+Math.Ceiling(Motor.Stamina.Stamina)+" / "+Motor.Stamina.Capacity,label);
            GUI.color=Motor.Stamina.Exhausted?new Color(.83f,.49f,.32f):new Color(.39f,.75f,.62f);
            GUI.DrawTexture(new Rect(884,47,240*(float)(Motor.Stamina.Stamina/Motor.Stamina.Capacity),7),Texture2D.whiteTexture);GUI.color=Color.white;
            if(CrosshairVisible)
            {
                Vector3 screen=cameraView.WorldToScreenPoint(FoundationCoordinates.ToUnity(Aim.Position));
                Vector2 at=new Vector2(Mathf.Clamp(screen.x*1152/Screen.width,10,1142),Mathf.Clamp((Screen.height-screen.y)*648/Screen.height,10,638));
                foreach(Vector2 axis in new[]{Vector2.right,Vector2.up})
                foreach(float sign in new[]{-1f,1f})
                {
                    Vector2 center=at+axis*sign*7;GUI.color=Color.black;
                    GUI.DrawTexture(new Rect(center.x-(axis.x!=0?3:2),center.y-(axis.y!=0?3:2),axis.x!=0?6:4,axis.y!=0?6:4),Texture2D.whiteTexture);
                    GUI.color=new Color(.85f,.96f,1,.95f);
                    GUI.DrawTexture(new Rect(center.x-(axis.x!=0?2:1),center.y-(axis.y!=0?2:1),axis.x!=0?4:2,axis.y!=0?4:2),Texture2D.whiteTexture);
                }
                GUI.color=Color.white;
            }
            bool enabled=GUI.enabled;GUI.enabled=enabled&&!ControllerActive&&!controls.BlocksShortcuts;
            if(GUI.Button(new Rect(872,78,264,28),"F9 / Select  Bediening aanpassen"))controls.Toggle();
            GUI.enabled=enabled;
            controls.Draw(new Rect(196,80,760,480));
            GUI.matrix=old;
        }
        public void PlayRouteMusic(string id){if(!Frozen)stepAudio.PlayMusic(id);}
        public void PlayRouteEffect(string id) { stepAudio.PlayEffect(id,-8); }
        private void SyncRouteFeet()
        {
            if(!RouteMode||RoutePresentation==null)return;
            foreach(var pair in routeColliderOwners)if(pair.Value!=null&&RoutePresentation.Objects.TryGetValue(pair.Key,out var sourceVisual)&&sourceVisual!=null)pair.Value.SetActive(sourceVisual.activeSelf);
        }
        public void ApplyEquipmentBonuses()
        {
            if(!RouteMode||Session==null||Motor==null)return;
            if(routeBonuses==null||!ReferenceEquals(routeBonuses.State,Session.State))routeBonuses=new RouteGameplay(repository,Session.State);
            Motor.Stamina.ConfigureBonuses(routeBonuses.Bonus("stamina_max"),routeBonuses.Bonus("stamina_regen"));Motor.Stamina.ClampCapacity();
        }
        public void DrawAvatarPreview(Rect bounds,string row){routeAppearance?.DrawPreview(Session.State,bounds,row);}
        public IReadOnlyList<RouteAvatarAppearance.VisualLayer> AvatarLayers(string row,string pose="idle")=>routeAppearance?.Compose(Session.State,row,pose,0,1);
        public void RefreshRouteState() { ApplyEquipmentBonuses();RoutePresentation?.Tick(clock,Session.State);SyncRouteFeet();UpdateAppearance(); }
        public void SetRouteObjectPosition(string sourceAddress,Vector2 sourcePosition) { RoutePresentation?.SetPosition(sourceAddress,sourcePosition); }
        public void SetRouteObjectVisible(string sourceAddress,bool visible) { RoutePresentation?.SetVisible(sourceAddress,visible);SyncRouteFeet(); }
        private void OnApplicationFocus(bool focused) { if(input!=null){input.SetFocused(focused&&isActiveAndEnabled);if(!focused)Combat?.Cancel();rollPending=false;} }
        private void OnDisable() { if(initialized){Session.State.SetUi("preview-hidden",true);Motor.StopForTransition();input.SetFocused(false);} }
        private void OnEnable() { if(initialized){Session.State.SetUi("preview-hidden",false);input.SetFocused(Application.isFocused);ConfigureCamera();} }
        private void OnDestroy()
        {
            combatArt?.Dispose();input?.Dispose();if(ownsSession)Session?.Dispose();RoutePresentation?.Dispose();routeAppearance?.Dispose();
            foreach(var sprite in ownedSprites)Destroy(sprite);foreach(var texture in ownedTextures)Destroy(texture);
        }
    }
}
