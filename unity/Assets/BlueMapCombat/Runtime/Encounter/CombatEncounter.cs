using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using UnityEngine;

namespace BlueMapMigration.Combat
{
    /// <summary>Original enemy state machines and independently animated native actors. Coordinates remain source pixels.</summary>
    public sealed partial class CombatEncounter : IDisposable
    {
        readonly FoundationWorldRepository repository;
        readonly FoundationGameState state;
        readonly FoundationValue rules;
        readonly List<EncounterActor> actors=new List<EncounterActor>();
        readonly List<EncounterProjectile> projectiles=new List<EncounterProjectile>();
        readonly List<EncounterPillar> pillars=new List<EncounterPillar>();
        readonly List<string> sourceSupport=new List<string>();
        readonly System.Random random=new System.Random(142041);
        readonly EncounterPresentation presentation;
        FoundationWorldSnapshot snapshot;
        EncounterPlayer player=new EncounterPlayer();
        int serial;
        public bool Enabled {get;set;}
        public IReadOnlyList<EncounterActor> Actors=>actors;
        public IReadOnlyList<EncounterProjectile> Projectiles=>projectiles;
        public IReadOnlyList<EncounterPillar> Pillars=>pillars;
        public int VisibleActors=>presentation?.VisibleActors??0;
        public int WarningRenderCount=>presentation?.WarningCount??0;
        public float LightNeed
        {
            get
            {
                if(snapshot==null)return 0;bool outdoor=Get(snapshot.MapData,"outdoor",FoundationValue.Boolean(false)).AsBool();if(!outdoor)return Number(snapshot.MapData,"darkness")>0?1:0;
                float[] times={0,.07f,.17f,.52f,.60f,.68f,.76f,.90f,.96f,1};float[] values={.35f,.05f,0,0,.15f,.6f,1,1,.7f,.35f};float t=(float)(state.Get("day_time").AsDouble()%1);if(t<0)t+=1;
                for(int i=1;i<times.Length;i++)if(t<=times[i]){float u=Mathf.InverseLerp(times[i-1],times[i],t);return Mathf.Lerp(values[i-1],values[i],u*u*(3-2*u));}return .35f;
            }
        }
        public bool PlayerLampActive
        {
            get{if(snapshot==null)return false;bool outdoor=Get(snapshot.MapData,"outdoor",FoundationValue.Boolean(false)).AsBool();if(!outdoor)return Number(snapshot.MapData,"darkness")>0;bool lantern=state.Count("lw_lantern")>0;float need=LightNeed;return ((need>.02f&&Number(snapshot.MapData,"darkness")<=0)||lantern)&&Math.Max(.3f*need,lantern?.45f:0)>.02f;}
        }
        public Func<Vector2,bool> Solid {get;set;}
        public Func<Vector2,float,bool> BodyFits {get;set;}
        public Func<Vector2,Vector2,bool> ClearLine {get;set;}
        public Func<Vector2,Vector2,bool> ArrowClearLine {get;set;}
        public Func<FoundationValue,bool> NodeVisible {get;set;}
        public Func<Vector2,bool> LightAt {get;set;}
        public Func<Vector2,bool> PlayerLampAt {get;set;}
        public event Action<Vector2,int,string> HurtRequested;
        public event Action<string,int,Vector2> LootRequested;
        public event Action<EncounterActor> EnemyDied,GuardianFinished,ActorDied;
        public event Action EndingRequested;
        public event Action<string> SoundRequested,MessageRequested;
        public event Action<Vector2,float> PlayerPushRequested;
        public event Action<string,bool> SourceVisibilityRequested;
        public event Action<EncounterActor,int> HitApplied;
        public CombatEncounter(FoundationWorldRepository worldRepository,FoundationGameState gameState,Phase6Catalog catalog,Transform parent,FoundationValue sourceRules)
        {repository=worldRepository??throw new ArgumentNullException(nameof(worldRepository));state=gameState??throw new ArgumentNullException(nameof(gameState));rules=sourceRules??throw new ArgumentNullException(nameof(sourceRules));presentation=catalog==null?null:new EncounterPresentation(catalog,parent);}
        static FoundationValue Empty()=>FoundationValue.Object(new Dictionary<string,FoundationValue>());
        static FoundationValue Get(FoundationValue source,string key,FoundationValue fallback=null)=>source!=null&&source.TryGet(key,out var value)?value:fallback??Empty();
        static string Text(FoundationValue source,string key,string fallback="")=>source!=null&&source.TryGet(key,out var value)&&value.Kind=="string"?value.AsString():fallback;
        static float Number(FoundationValue source,string key,float fallback=0)=>source!=null&&source.TryGet(key,out var value)&&(value.Kind=="int"||value.Kind=="float")?(float)value.AsDouble():fallback;
        static Vector2 V(FoundationValue pair)=>new Vector2((float)pair.Items[0].AsDouble(),(float)pair.Items[1].AsDouble());
        static Vector2 Rotate(Vector2 v,float angle)=>new Vector2(v.x*Mathf.Cos(angle)-v.y*Mathf.Sin(angle),v.x*Mathf.Sin(angle)+v.y*Mathf.Cos(angle));
        static Vector2 Side(Vector2 v)=>new Vector2(v.y,-v.x);
        static float Angle(Vector2 a,Vector2 b)=>Mathf.Atan2(a.x*b.y-a.y*b.x,Vector2.Dot(a,b));
        float Rand()=> (float)random.NextDouble();
        float Range(float first,float last)=>first+(last-first)*Rand();
        static void Enter(EncounterActor actor,string next){actor.State=next;actor.StateTime=0;actor.Hit=false;}
        bool Clear(Vector2 a,Vector2 b)=>ClearLine?.Invoke(a,b)??true;
        bool Fits(EncounterActor e,Vector2 at,float margin=2)=>!(Solid?.Invoke(at)??false)&&(BodyFits?.Invoke(at+new Vector2(0,e.Size*.28f),e.Kind=="guardian"?14:e.Radius+margin)??true);
        bool BodyClear(EncounterActor e,Vector2 a,Vector2 b){int steps=Math.Max(1,Mathf.CeilToInt(Vector2.Distance(a,b)/8));for(int i=1;i<=steps;i++)if(!Fits(e,Vector2.Lerp(a,b,(float)i/steps),0))return false;return true;}
        Vector2 Free(EncounterActor e,Vector2 wanted){foreach(float turn in new[]{0,.6f,-.6f,1.2f,-1.2f,1.8f,-1.8f}){Vector2 direction=Rotate(wanted,turn);if(!(Solid?.Invoke(e.Position+new Vector2(0,e.Size*.28f)+direction*22)??false))return direction;}return Vector2.zero;}
        public void Load(FoundationWorldSnapshot map)
        {
            foreach(var old in actors)SourceVisibilityRequested?.Invoke(old.Address,true);foreach(string address in sourceSupport)SourceVisibilityRequested?.Invoke(address,true);
            actors.Clear();projectiles.Clear();pillars.Clear();sourceSupport.Clear();presentation?.Clear();snapshot=map??throw new ArgumentNullException(nameof(map));serial=0;
            foreach(var node in map.Root.Require("scene").Items)
            {
                string script=node.Require("script").AsString();
                if(new[]{"/guardian_pillar.gd","/habitat_warning.gd","/coastal_warning.gd","/king_warning.gd"}.Any(script.EndsWith))sourceSupport.Add(string.Join("/",node.Require("address").Items.Select(v=>v.Kind=="string"?v.AsString():v.AsInt64().ToString(System.Globalization.CultureInfo.InvariantCulture))));
                if(!script.EndsWith("/enemy.gd",StringComparison.Ordinal)&&!script.EndsWith("/guardian.gd",StringComparison.Ordinal))continue;
                var fields=node.Require("fields");string kind=Text(fields,"kind",script.EndsWith("/guardian.gd",StringComparison.Ordinal)?"guardian":"slime");
                var data=Get(fields,"data");if(data.Entries.Count==0)data=Get(Get(rules,"enemies"),kind);
                if(data.Entries.Count==0)throw new FormatException("Original enemy data absent: "+kind);
                string address=string.Join("/",node.Require("address").Items.Select(v=>v.Kind=="string"?v.AsString():v.AsInt64().ToString(System.Globalization.CultureInfo.InvariantCulture)));
                var enemy=Spawn(kind,FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin")),Text(fields,"unique_flag"),address,data);enemy.SourceNode=node;enemy.PatrolRadius=Number(fields,"patrol_radius");enemy.Practice=Get(node,"groups").Items.Any(v=>v.Kind=="string"&&v.AsString()=="practice");
                if(kind=="guardian")
                {
                    enemy.UniqueFlag="guardian_defeated";enemy.State="dormant";enemy.Active=false;
                    var obj=Get(fields,"obj");foreach(var tile in Get(obj,"pillars").Items){var pillar=new EncounterPillar{Position=V(tile)*32+Vector2.one*16,Address=address+"/pillar/"+pillars.Count};pillars.Add(pillar);enemy.Pillars.Add(pillar);}
                }
            }
            Render();
        }
        public EncounterActor Spawn(string kind,Vector2 at,string uniqueFlag="",string address="",FoundationValue data=null)
        {
            data=data??Get(Get(rules,"enemies"),kind);if(data.Entries.Count==0)throw new ArgumentException("Unknown original enemy: "+kind);
            int ng=(int)Number(state.Snapshot(),"ng_plus");int hp=Mathf.CeilToInt(Number(data,"hp",1)*(1+ng*.5f));
            var actor=new EncounterActor{Kind=kind,Behavior=Text(data,"behavior"),Data=data,Address=address==""?"runtime-enemy/"+(serial++):address,UniqueFlag=uniqueFlag,Position=at,Home=at,Hp=hp,MaxHp=hp,Radius=Number(data,"radius",7),Active=!Get(data,"start_inactive",FoundationValue.Boolean(false)).AsBool(),Anim=Range(0,Mathf.PI*2),StateTime=Range(0,1)};
            if(kind=="guardian"){actor.State="dormant";actor.Active=false;actor.UniqueFlag="guardian_defeated";}actors.Add(actor);return actor;
        }
        public void ActivateBosses(){foreach(var e in actors.Where(e=>e.IsBoss&&!e.Dead))Activate(e);}
        public void Activate(EncounterActor e){if(e.Active||e.Dead)return;e.Active=true;if(e.Kind=="guardian"){Enter(e,"waking");SoundRequested?.Invoke("guardian_roar");}}
        bool Visible(EncounterActor e)=>!e.Finished&&((e.State=="dying"||e.Kind=="king"&&e.Dead)||((e.UniqueFlag==""||!state.Flag(e.UniqueFlag))&&(e.SourceNode==null||(NodeVisible?.Invoke(e.SourceNode)??true))));
        public void Tick(double delta,EncounterPlayer currentPlayer)
        {
            if(currentPlayer!=null)player=currentPlayer;
            if(!Enabled||snapshot==null){Render();return;}
            if(state.Paused||state.Ended||state.Transitioning){Render();return;}
            double left=Math.Max(0,delta);while(left>0){double step=Math.Min(left,1.0/60);Step(step);left-=step;}
            Render();
        }
        void Step(double dt)
        {
            foreach(var e in actors.ToArray())
            {
                if(!Visible(e))continue;e.Time+=dt;e.Anim+=dt*5;e.Flash=Math.Max(0,e.Flash-dt);e.TouchCooldown=Math.Max(0,e.TouchCooldown-dt);e.GuardBroken=Math.Max(0,e.GuardBroken-dt);e.ActionFlash=Math.Max(0,e.ActionFlash-dt);
                if(e.Kind=="guardian"){Guardian(e,dt);continue;}if(e.Kind=="king"&&e.Dead){e.DeathTimer+=dt;if(e.DeathTimer>=1.6&&!e.Finished){e.Finished=true;EndingRequested?.Invoke();}continue;}if(e.Dead||!e.Active)continue;e.StateTime+=dt;e.Desired=Vector2.zero;Ai(e,dt);
                Vector2 before=e.Position;Move(e,(e.Desired+e.Knockback)*(float)dt);e.Velocity=(e.Position-before)/(float)dt;e.Knockback=Vector2.MoveTowards(e.Knockback,Vector2.zero,(float)(700*dt));AfterMove(e,before);
                float touch=e.Radius+9;if((e.Behavior=="cv_ram"||e.Behavior=="cv_slinger")&&e.State!="cv_charge")touch=0;
                if(e.Behavior=="animal"||e.Behavior.StartsWith("hb_",StringComparison.Ordinal)||e.Behavior.StartsWith("ad_",StringComparison.Ordinal)||new[]{"hop","vanish","appear"}.Contains(e.State))touch=0;
                if(Vector2.Distance(e.Position,player.Position)<touch&&e.TouchCooldown<=0){e.TouchCooldown=.8;Hurt(e.Position,(int)e.Number("damage",1),e.Text("name",e.Kind));}
            }
            foreach(var p in projectiles.ToArray())if(!p.Dead)Projectile(p,dt);
            foreach(var pillar in pillars)Pillar(pillar,dt);
            projectiles.RemoveAll(p=>p.Dead);
        }
        void Move(EncounterActor e,Vector2 offset)
        {
            if(offset==Vector2.zero)return;int steps=Math.Max(1,Mathf.CeilToInt(offset.magnitude/6));Vector2 step=offset/steps;
            for(int i=0;i<steps;i++){Vector2 next=e.Position+step;if(Fits(e,next,0))e.Position=next;else{Vector2 x=e.Position+new Vector2(step.x,0),y=e.Position+new Vector2(0,step.y);if(Fits(e,x,0))e.Position=x;if(Fits(e,y,0))e.Position=y;}}
        }
        void Hurt(Vector2 from,int damage,string source)=>HurtRequested?.Invoke(from,damage,source);
        public bool HurtActor(EncounterActor e,int damage,Vector2 direction,bool breakGuard=false,bool arrow=false,bool precise=false)
        {
            if(e==null||e.Dead||!e.Active||!Visible(e)||damage<0)return false;
            if(e.Kind=="king"&&e.State=="hop"||e.Kind=="guardian"&&(e.State=="waking"||e.State=="phase_shift"))return false;
            if(breakGuard){if(e.Behavior=="hb_root"){e.GuardBroken=1.8;Enter(e,"hb_rest");}else if(e.Behavior=="lw_guard")e.GuardBroken=1.8;}
            if(arrow&&precise&&e.Behavior=="hb_root"){e.GuardBroken=1.8;Enter(e,"hb_rest");}
            if(e.Behavior=="hb_root"&&new[]{"idle","hb_root_warn"}.Contains(e.State)&&e.GuardBroken<=0)return false;
            if(e.Behavior=="lw_guard"&&e.GuardBroken<=0&&Vector2.Dot(direction.normalized,e.Aim)<-.45)return false;
            if(arrow&&e.Behavior=="golem"&&e.State!="windup"&&e.State!="recover")return false;
            if(e.Behavior=="hb_moth")Enter(e,"hb_rest");
            if(e.Behavior.StartsWith("ad_",StringComparison.Ordinal)&&e.State!="ad_swing"&&e.State!="ad_pulse")Enter(e,"ad_rest");
            if(e.Behavior=="lw_support")Enter(e,"idle");if(e.Behavior.StartsWith("rf_",StringComparison.Ordinal))Enter(e,"rf_rest");if(e.Behavior.StartsWith("cv_",StringComparison.Ordinal))Enter(e,"cv_rest");
            if(e.Behavior=="mage"&&(e.State=="appear"||e.State=="cast"))Enter(e,"idle");if(e.Behavior=="echo_volley"&&e.State=="echo_warn")Enter(e,"echo_rest");
            e.Hp-=damage;if(e.Kind!="guardian")e.Knockback=direction.normalized*e.Number("knockback",240);e.Flash=.15;if(e.Behavior=="animal")e.Panic=5;HitApplied?.Invoke(e,damage);
            if(e.Hp<=0)Die(e);else if(e.Kind=="guardian"){int phase=GuardianPhase(e);if(phase>e.Phase){e.ShiftTo=Math.Min(phase,e.Phase+1);Enter(e,"phase_shift");foreach(var pillar in e.Pillars)pillar.Cancel();if(Vector2.Distance(e.Position,player.Position)<110)PlayerPushRequested?.Invoke((player.Position-e.Position).normalized,320);SoundRequested?.Invoke("phase_shift");}}
            return true;
        }
        void Die(EncounterActor e)
        {
            if(e.Dead)return;e.Dead=true;if(e.Kind=="guardian")e.Hp=0;SoundRequested?.Invoke(e.Kind=="guardian"?"guardian_die":"die");
            if(e.Kind=="guardian"){foreach(var pillar in e.Pillars)pillar.Cancel();foreach(var p in projectiles.Where(p=>p.Kind=="guardian_shard"))p.Dead=true;Enter(e,"dying");}
            else if(e.Kind=="king"){e.DeathTimer=0;foreach(var other in actors.Where(a=>a!=e)){other.Dead=true;other.Finished=true;}}
            else e.Finished=true;
            ActorDied?.Invoke(e);if(e.UniqueFlag!=""&&e.Kind!="guardian")state.SetFlag(e.UniqueFlag,true);
            if(!e.Practice)
            {EnemyDied?.Invoke(e);foreach(var drop in Get(e.Data,"drops").Items)if(Rand()<(float)drop.Items[1].AsDouble()){string item=drop.Items[0].AsString();int amount=(int)drop.Items[2].AsInt64();if(item=="coin"&&Number(state.Snapshot(),"ng_plus")>0)amount=Mathf.CeilToInt(amount*1.5f);for(int i=0;i<amount;i++)LootRequested?.Invoke(item,1,e.Position+new Vector2(Range(-12,12),Range(-6,12)));}}
        }
        public void BreakGuard(EncounterActor e)
        {if(e.Behavior=="hb_root"){e.GuardBroken=1.8;Enter(e,"hb_rest");}else if(e.Behavior=="lw_guard")e.GuardBroken=1.8;}
        internal void ReplayAi(EncounterActor e,double delta,EncounterPlayer context){player=context;if(e.Kind=="guardian")Guardian(e,delta);else{e.StateTime+=delta;e.Desired=Vector2.zero;Ai(e,delta);}}
        internal void ReplayProjectile(EncounterProjectile p,double delta,EncounterPlayer context){player=context;Projectile(p,delta);}
        internal void ReplayLaunch(EncounterProjectile p,double distance){AdvanceArrow(p,distance);p.Traveled=0;}
        internal void ReplayPillar(EncounterPillar p,double delta){Pillar(p,delta);}
        internal bool BreakProjectile(EncounterProjectile p,Vector2 from,Vector2 direction,double reach){if(!p.Breakable||p.Dead)return false;Vector2 delta=p.Position-from;if(delta.magnitude>reach+10||Vector2.Dot(direction,delta.normalized)<=.2)return false;p.Dead=true;SoundRequested?.Invoke("mage_orb_pop");return true;}
        public void ApplyStrike(CombatStrike strike)
        {
            if(!Enabled||state.Paused||state.Ended)return;
            foreach(var e in actors.ToArray())
            {Vector2 offset=e.Position-strike.Position;float dot=Vector2.Dot(strike.Direction,offset.normalized);if(offset.magnitude<=strike.Reach+e.Radius&&((strike.InclusiveCone&&dot>=strike.Cone)||(!strike.InclusiveCone&&dot>strike.Cone))&&Clear(strike.Position,e.Position))HurtActor(e,strike.Damage,strike.Direction,strike.BreakGuard);}
            foreach(var p in projectiles)if(Clear(strike.Position,p.Position))BreakProjectile(p,strike.Position,strike.Direction,strike.Reach);
        }
        public void SpawnArrow(CombatArrow arrow)
        {var p=new EncounterProjectile{Id="player-arrow/"+(serial++),Kind="player_arrow",Position=arrow.Position,Direction=arrow.Direction,Velocity=arrow.Direction*(float)arrow.Speed,Speed=arrow.Speed,PlayerOwned=true,Damage=arrow.Damage,MaxRange=arrow.MaxRange,Precise=arrow.Precise};projectiles.Add(p);AdvanceArrow(p,arrow.LaunchDistance);p.Traveled=0;}
        public EncounterProjectile SpawnProjectile(string kind,Vector2 at,Vector2 direction,float speed,int damage,string source)
        {var p=new EncounterProjectile{Id="enemy-projectile/"+(serial++),Kind=kind,Position=at,Direction=direction,Velocity=(kind=="guardian_shard"?direction:direction.normalized)*speed,Speed=speed,Damage=damage,Source=source};if(kind=="cv_thorn"){p.Life=2.2;p.Breakable=true;}if(kind=="arcane_orb"){p.Turn=1;p.Life=3;p.Breakable=true;}if(kind=="prism_spark"){p.Life=3;p.Breakable=true;}if(kind=="guardian_shard")p.Life=6;projectiles.Add(p);return p;}
        void Projectile(EncounterProjectile p,double dt)
        {
            p.Age+=dt;if(p.PlayerOwned){if(p.State=="flying")AdvanceArrow(p,p.Speed*dt);else{if(p.State=="bounce"){p.Position-=p.Direction*(float)(110*(p.Timer/.4)*dt);p.Spin+=18*dt;}p.Timer-=dt;if(p.Timer<=0){if(p.State=="stuck"){p.State="fading";p.Timer=.25;}else p.Dead=true;}}return;}
            if(p.Turn>0){Vector2 wanted=player.Position+new Vector2(0,4)-p.Position;p.Velocity=Rotate(p.Velocity,(float)Math.Clamp(Angle(p.Velocity,wanted),-p.Turn*dt,p.Turn*dt));}
            Vector2 next=p.Position+p.Velocity*(float)dt;
            if(p.Kind=="cv_thorn"){int steps=Math.Max(1,Mathf.CeilToInt(Vector2.Distance(p.Position,next)/6));if(!Clear(p.Position,next)){p.Dead=true;return;}for(int i=1;i<=steps;i++)if(Solid?.Invoke(Vector2.Lerp(p.Position,next,(float)i/steps))??false){p.Dead=true;return;}}
            p.Position=next;if(p.Age>p.Life||(Solid?.Invoke(p.Position)??false)){p.Dead=true;return;}
            if(Vector2.Distance(p.Position,player.Position+new Vector2(0,4))<11){Hurt(p.Position-p.Velocity.normalized*8,p.Damage,p.Source);p.Dead=true;return;}
            if(p.Kind=="arcane_orb"||p.Kind=="prism_spark"){p.TrailTimer+=dt;if(p.TrailTimer>=.04){p.TrailTimer=0;p.Trail.Add(p.Position);while(p.Trail.Count>6)p.Trail.RemoveAt(0);}}
        }
        void AdvanceArrow(EncounterProjectile p,double distance)
        {
            while(distance>0&&p.State=="flying"&&!p.Dead)
            {
                double step=Math.Min(distance,8);distance-=step;Vector2 from=p.Position,to=from+p.Direction*(float)step;
                if(!(ArrowClearLine?.Invoke(from,to)??Clear(from,to))){p.State="stuck";p.Timer=.6;p.Position=from+p.Direction*4;return;}
                var target=actors.Where(e=>Visible(e)&&!e.Dead&&e.Active&&e.AirHeight<=4&&Segment(e.Position+new Vector2(0,4),from,to)<=e.Radius+3).OrderBy(e=>Vector2.Distance(from,e.Position+new Vector2(0,4))).FirstOrDefault();
                if(target!=null){p.Position=to;bool hit=HurtActor(target,target.IsBoss?1:p.Damage,p.Direction,false,true,p.Precise);if(!hit&&(target.Behavior=="golem"||target.Behavior=="hb_root")){p.State="bounce";p.Timer=.4;SoundRequested?.Invoke("boog_kets");}else p.Dead=true;return;}
                p.Position=to;p.Traveled+=step;if(p.Traveled>=p.MaxRange){p.State="fading";p.Timer=.25;return;}
            }
        }
        static float Segment(Vector2 p,Vector2 a,Vector2 b){float length=(b-a).sqrMagnitude;return Vector2.Distance(p,length==0?a:a+(b-a)*Mathf.Clamp01(Vector2.Dot(p-a,b-a)/length));}
        void Render(){foreach(var e in actors)SourceVisibilityRequested?.Invoke(e.Address,!Enabled);foreach(string address in sourceSupport)SourceVisibilityRequested?.Invoke(address,!Enabled);if(presentation==null)return;presentation.ClearLine=Clear;presentation.Draw(actors,projectiles,pillars,Enabled,e=>Visible(e),player);}
        public void Dispose(){foreach(var e in actors)SourceVisibilityRequested?.Invoke(e.Address,true);foreach(string address in sourceSupport)SourceVisibilityRequested?.Invoke(address,true);presentation?.Dispose();actors.Clear();projectiles.Clear();pillars.Clear();sourceSupport.Clear();}
    }
}
