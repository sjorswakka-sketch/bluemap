using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Player;
using BlueMapMigration.Progression;
using UnityEngine;
namespace BlueMapMigration.Combat
{
 public sealed class CombatStrike
 {public Vector2 Position,Direction;public double Reach,Cone;public int Damage;public bool InclusiveCone,BreakGuard;public string Kind="sword";}
 public sealed class CombatArrow
 {public Vector2 Position,Direction;public int Damage=2;public double Speed=320,MaxRange=280,LaunchDistance=12;public bool Precise;}
 public sealed class CombatDamage
 {public Vector2 From,Knockback;public int Requested,Applied;public string Source="";public bool Lethal;}
 public sealed class PlayerCombatState
 {
  readonly PlayerMotorModel motor;
  public Vector2 Position,AimDirection=new Vector2(0,1),AttackDirection=new Vector2(0,1),BowDirection=new Vector2(0,1),TechniqueDirection=new Vector2(0,1);
  public Vector2 Facing{get=>motor.Facing;set=>motor.Facing=value;}public Vector2 Knockback{get=>motor.Knockback;set=>motor.Knockback=value;}public double RollTimer{get=>motor.RollTimer;set=>motor.RollTimer=value;}
  public double AttackTimer,Cooldown,BowCooldown,BowAnim,Invulnerable,ComboWindow,Elapsed,Recovery,HintTime,NoArrowsToast,DrinkAnim;
  public int ComboStep;public bool ComboSweep,Ranged;public string Phase="",OriginMap="",LastDamageSource="";
  public FoundationValue Profile=InventoryModel.Empty();public Dictionary<string,long> DamageLog=new Dictionary<string,long>(StringComparer.Ordinal);
  public PlayerCombatState(PlayerMotorModel motor){this.motor=motor;}
 }
 /// <summary>Original player combat actions. Actor simulation/presentation is owned by the encounter; saved state and energy are shared.</summary>
 public sealed class CombatModel
 {
  readonly FoundationWorldRepository repository;bool busy;
  public FoundationGameState State{get;}public InventoryModel Inventory{get;}public ProgressionModel Progression{get;}public PlayerMotorModel Motor{get;}public PlayerStamina Movement=>Motor.Stamina;public PlayerCombatState Player{get;private set;}
  public CombatCatalog Source{get;}public FoundationValue Oracle=>Source.Oracle;public FoundationValue Catalogs=>Source.Catalogs;
  public bool TechniqueBusy=>Player.Phase!=""||Player.Recovery>0;public double MovementScale=>Player.Phase=="prepare"||Player.Phase=="guard"||Player.Phase=="counter"?.35:1;public bool SprintAllowed=>!TechniqueBusy;
  public Func<Vector2,Vector2,bool> ClearLine{get;set;}=(a,b)=>true;public Func<bool> LentArrows{get;set;}=()=>false;public Func<bool> DefeatHandler{get;set;}
  public Func<string,string> Translator{get;set;}=value=>value;public string LastMessage{get;private set;}="";
  public event Action<CombatStrike> StrikeRequested;public event Action<CombatArrow> ArrowRequested;public event Action<CombatDamage> PlayerDamaged;
  public event Action Changed,SaveRequested,Defeated,CancelWorkRequested;public event Action<long,long> DefeatRecorded;public event Action<string> Toast,SoundRequested;public event Action<double> HitstopRequested,ShakeRequested;
  public CombatModel(FoundationWorldRepository repository,FoundationGameState state,InventoryModel inventory,ProgressionModel progression,PlayerMotorModel motor=null)
  {this.repository=repository??throw new ArgumentNullException(nameof(repository));State=state??throw new ArgumentNullException(nameof(state));Inventory=inventory??throw new ArgumentNullException(nameof(inventory));Progression=progression??throw new ArgumentNullException(nameof(progression));if(!ReferenceEquals(state,inventory.State)||!ReferenceEquals(state,progression.State)||!ReferenceEquals(inventory,progression.Inventory))throw new ArgumentException("Combat must share original state/inventory/progression");Motor=motor??new PlayerMotorModel();Player=new PlayerCombatState(Motor);Source=new CombatCatalog();}
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue E()=>InventoryModel.Empty();static FoundationValue G(FoundationValue d,string key,FoundationValue fallback)=>InventoryModel.Get(d,key,fallback);
  string Tr(string value)=>Translator==null?value:Translator(value);void Say(string value){LastMessage=Tr(value);Toast?.Invoke(LastMessage);}
  public int Damage=>(int)Catalogs.Require("weapons").Require(State.Get("weapon").AsString()).Require("damage").AsInt64();public double Reach=>Catalogs.Require("weapons").Require(State.Get("weapon").AsString()).Require("reach").AsDouble();
  public string CoastalMode(bool bow){string hands=Progression.Equipped("hands");return hands=="gear_cw_anchor"&&!bow?"cw_anchor":hands=="gear_cw_fan"&&bow?"cw_fan":"";}
  public FoundationValue EffectiveProfile(string weapon,bool bow=false)
  {
   var profile=bow?Catalogs.Require("bowTechnique"):G(Catalogs.Require("techniques"),weapon,Catalogs.Require("techniques").Require("wood"));string mode=CoastalMode(bow);if(mode!="")profile=Catalogs.Require("coastalProfiles").Require(mode);
   double cost=Math.Max(1,Math.Round(profile.Require("cost").AsDouble()*(1-Progression.Bonus("technique_cost_reduction")),MidpointRounding.AwayFromZero));profile=InventoryModel.Replace(profile,"cost",FoundationValue.Number(cost));if(bow)profile=InventoryModel.Replace(profile,"windup",FoundationValue.Number(profile.Require("windup").AsDouble()*(1-Progression.Bonus("bow_preparation_reduction"))));return profile;
  }
  public void Cancel(){Player.Phase="";Player.Elapsed=0;}
  public void ResetTransient(){Player=new PlayerCombatState(Motor);Motor.Knockback=Vector2.zero;Motor.RollTimer=0;}
  public void StopForTransition(){CancelWorkRequested?.Invoke();Cancel();Motor.StopForTransition();Player.AttackTimer=0;Player.BowAnim=0;Player.ComboStep=0;Player.ComboWindow=0;}
  public void OnRolled(){Player.AttackTimer=0;Player.ComboStep=0;Player.ComboWindow=0;Cancel();CancelWorkRequested?.Invoke();}
  public bool Attack(bool technique=false)
  {
   if(busy||State.InputLocked)return false;if(Counter())return true;if(TechniqueBusy)return false;if(technique)return BeginTechnique(false);if(Player.Cooldown>0||Player.RollTimer>0)return false;
   busy=true;try{CancelWorkRequested?.Invoke();Player.AttackDirection=Player.AimDirection;Player.ComboStep=Player.ComboWindow>0?Player.ComboStep%3+1:1;Player.ComboWindow=.9;Player.ComboSweep=Player.ComboStep==3&&Movement.Spend(18);Player.AttackTimer=.18;Player.Cooldown=.35*(1-Progression.Bonus("attack_cooldown_reduction"));SoundRequested?.Invoke("swing");StrikeRequested?.Invoke(new CombatStrike{Position=Player.Position,Direction=Player.AttackDirection,Reach=Reach+(Player.ComboSweep?8:0),Cone=Player.ComboSweep?-.35:.2,Damage=Damage,InclusiveCone=false,BreakGuard=Player.ComboSweep&&State.Flag("lw_workshop")});Changed?.Invoke();return true;}finally{busy=false;}
  }
  public bool Shoot(bool technique=false,bool precise=false,Vector2? lockedDirection=null)
  {
   if(busy||State.InputLocked)return false;if(!precise&&TechniqueBusy)return false;if(!precise&&technique)return BeginTechnique(true);if(Player.BowCooldown>0||Player.RollTimer>0)return false;
   if(State.Count("bow")<=0){if(Player.NoArrowsToast<=0){Player.NoArrowsToast=3.4;Say("Je hebt een boog nodig. Tobias verkoopt er een.");SoundRequested?.Invoke("error");}return false;}
   CancelWorkRequested?.Invoke();Player.BowCooldown=precise?.8:.4;bool lent=LentArrows?.Invoke()==true;
   if(State.Count("arrow")<=0&&!lent){SoundRequested?.Invoke("error");if(Player.NoArrowsToast<=0){Player.NoArrowsToast=3.4;Say("Geen pijlen!");}return false;}
   busy=true;try{if(!lent)Inventory.Take("arrow",1);Player.BowAnim=.25;Player.BowDirection=precise?(lockedDirection??Vector2.zero):Player.AimDirection;ArrowRequested?.Invoke(new CombatArrow{Position=Player.Position+new Vector2(0,4),Direction=Player.BowDirection,Precise=precise,Damage=precise?3:2,Speed=precise?420:320,MaxRange=precise?400:280});SoundRequested?.Invoke("boog_twang");Changed?.Invoke();return true;}finally{busy=false;}
  }
  public bool BeginTechnique(bool bow)
  {
   if(busy||TechniqueBusy||Player.RollTimer>0||Player.Cooldown>0||Player.BowCooldown>0||State.InputLocked)return false;if(bow&&(State.Count("bow")<=0||(State.Count("arrow")<=0&&LentArrows?.Invoke()!=true)))return Shoot(false);
   busy=true;try{var profile=EffectiveProfile(State.Get("weapon").AsString(),bow);Player.OriginMap=State.MapId;Player.Profile=profile;string mode=G(profile,"mode",S("")).AsString();if(mode=="cw_fan"&&!ArrowsReady()){Say("Een waaierschot vraagt drie pijlen. Je verliest niets als ze ontbreken.");return false;}
   if(!Movement.Spend(profile.Require("cost").AsDouble())){if(Player.HintTime<=0){Say("Deze techniek vraagt "+(int)profile.Require("cost").AsDouble()+" stamina. Gewone aanvallen blijven beschikbaar.");Player.HintTime=2.5;}return false;}
   CancelWorkRequested?.Invoke();Player.OriginMap=State.MapId;Player.Profile=profile;Player.TechniqueDirection=Player.AimDirection;Player.Ranged=bow;Player.Phase="prepare";Player.Elapsed=0;Player.ComboStep=0;Player.ComboWindow=0;SoundRequested?.Invoke("cv_ready");Changed?.Invoke();return true;}finally{busy=false;}
  }
  bool ArrowsReady()=>State.Count("bow")>0&&(LentArrows?.Invoke()==true||State.Count("arrow")>=3);
  bool StyleValid()=>G(Player.Profile,"mode",S("")).AsString()==CoastalMode(Player.Ranged)&&(Player.OriginMap==""||Player.OriginMap==State.MapId);
  public void BeforePhysics(double delta)
  {
   if(!double.IsFinite(delta)||delta<0)throw new ArgumentOutOfRangeException(nameof(delta));Player.HintTime=Math.Max(0,Player.HintTime-delta);Player.Recovery=Math.Max(0,Player.Recovery-delta);
   if(State.InputLocked||(Player.OriginMap!=""&&Player.OriginMap!=State.MapId)){Cancel();}else if(Player.Phase!="")
   {
    Player.Elapsed+=delta;string mode=G(Player.Profile,"mode",S("")).AsString();
    if(mode!=""&&!StyleValid())Cancel();
    else if(mode=="cw_anchor")
    {if(Player.Phase=="prepare"&&Player.Elapsed>=.12){Player.Phase="guard";Player.Elapsed=0;}else if(Player.Phase=="guard"&&Player.Elapsed>=.32){Player.Phase="";Player.Recovery=.6;}else if(Player.Phase=="counter"&&Player.Elapsed>=.7){Player.Phase="";Player.Recovery=.4;}else if(Player.Phase=="strike"&&Player.Elapsed>=.2)Player.Phase="";}
    else if(Player.Phase=="prepare"&&Player.Elapsed>=Player.Profile.Require("windup").AsDouble())
    {
     Player.Phase="strike";Player.Elapsed=0;Player.Recovery=Player.Ranged?.5:.4;
     if(Player.Ranged&&mode=="cw_fan")ReleaseFan();else if(Player.Ranged){if(State.Count("bow")>0&&(State.Count("arrow")>0||LentArrows?.Invoke()==true))Shoot(false,true,Player.TechniqueDirection);}
     else {StrikeRequested?.Invoke(new CombatStrike{Position=Player.Position,Direction=Player.TechniqueDirection,Reach=Reach+Player.Profile.Require("reach").AsDouble(),Cone=Player.Profile.Require("cone").AsDouble(),Damage=Damage+(int)Player.Profile.Require("bonus").AsInt64(),InclusiveCone=true,BreakGuard=true,Kind="technique"});SoundRequested?.Invoke("cv_strike");}
    }
    else if(Player.Phase=="strike"&&Player.Elapsed>=.2)Player.Phase="";
   }
   Player.ComboWindow=Math.Max(0,Player.ComboWindow-delta);if(Player.ComboWindow<=0)Player.ComboStep=0;
  }
  public void AfterPhysics(double delta){Player.DrinkAnim=Math.Max(0,Player.DrinkAnim-delta);Player.AttackTimer=Math.Max(0,Player.AttackTimer-delta);Player.Cooldown=Math.Max(0,Player.Cooldown-delta);Player.Invulnerable=Math.Max(0,Player.Invulnerable-delta);Player.BowCooldown=Math.Max(0,Player.BowCooldown-delta);Player.BowAnim=Math.Max(0,Player.BowAnim-delta);Player.NoArrowsToast=Math.Max(0,Player.NoArrowsToast-delta);}
  public void Tick(double delta){BeforePhysics(delta);AfterPhysics(delta);}
  void ReleaseFan(){if(!StyleValid()||!ArrowsReady())return;if(LentArrows?.Invoke()!=true)Inventory.Take("arrow",3);Player.BowCooldown=.9;Player.BowAnim=.25;Player.BowDirection=Player.TechniqueDirection;foreach(float angle in new[]{-.4f,0f,.4f}){float c=(float)Math.Cos(angle),s=(float)Math.Sin(angle);var d=Player.TechniqueDirection;var rotated=new Vector2(d.x*c-d.y*s,d.x*s+d.y*c);ArrowRequested?.Invoke(new CombatArrow{Position=Player.Position+new Vector2(0,4),Direction=rotated,Damage=1,Speed=300,MaxRange=240});}SoundRequested?.Invoke("cw_fan");}
  public bool TryBlock(Vector2 from){if(Player.Phase!="guard"||Player.Elapsed>.32||G(Player.Profile,"mode",S("")).AsString()!="cw_anchor"||!StyleValid()||State.InputLocked)return false;Vector2 offset=from-Player.Position;if(PlayerMotorModel.SourceLength(offset)<1||Vector2.Dot(Player.TechniqueDirection,PlayerMotorModel.NormalizeSource(offset))<.5||!(ClearLine?.Invoke(Player.Position,from)??true))return false;Player.Phase="counter";Player.Elapsed=0;SoundRequested?.Invoke("cw_guard");return true;}
  public bool Counter(){if(busy||Player.Phase!="counter"||G(Player.Profile,"mode",S("")).AsString()!="cw_anchor"||!StyleValid()||State.InputLocked)return false;busy=true;try{Player.Phase="strike";Player.Elapsed=0;Player.Recovery=.6;StrikeRequested?.Invoke(new CombatStrike{Position=Player.Position,Direction=Player.TechniqueDirection,Reach=Reach+20,Cone=.86,Damage=Damage+1,InclusiveCone=true,BreakGuard=true,Kind="counter"});SoundRequested?.Invoke("cw_guard");return true;}finally{busy=false;}}
  public int DamageAfterArmor(int amount)=>amount>0?Math.Max(amount-(int)Progression.Bonus("armor"),1):0;
  public bool Hurt(Vector2 from,int amount=1,string source="")
  {
   if(busy||Player.Invulnerable>0||State.Ended||Player.RollTimer>.3-.24)return false;if(TryBlock(from))return false;busy=true;
   try{CancelWorkRequested?.Invoke();Cancel();Player.LastDamageSource=source;int applied=DamageAfterArmor(amount);Player.DamageLog[source]=(Player.DamageLog.TryGetValue(source,out var previous)?previous:0)+applied;bool lethal=false;
    if(amount>0){long hp=Math.Max(0,State.Hp-applied);State.Hp=hp;if(hp==0){bool handled=DefeatHandler?.Invoke()==true;if(!handled){State.Ended=true;State.CommitFields(new Dictionary<string,FoundationValue>{{"deaths",I(checked(State.Get("deaths").AsInt64()+1))},{"boss_deaths",I(checked(State.Get("boss_deaths").AsInt64()+(State.Flag("boss_started")&&!State.Flag("boss_defeated")?1:0)))}});lethal=true;DefeatRecorded?.Invoke(State.Get("deaths").AsInt64(),State.Get("boss_deaths").AsInt64());Defeated?.Invoke();}}}
    SoundRequested?.Invoke("hurt");Player.Invulnerable=1;Player.Knockback=PlayerMotorModel.ScaleSource(PlayerMotorModel.NormalizeSource(Player.Position-from),260);ShakeRequested?.Invoke(5);HitstopRequested?.Invoke(.07);PlayerDamaged?.Invoke(new CombatDamage{From=from,Knockback=Player.Knockback,Requested=amount,Applied=applied,Source=source,Lethal=lethal});Changed?.Invoke();return true;
   }finally{busy=false;}
  }
  public int NgHp(int hp)=>(int)Math.Ceiling(hp*(1+.5*State.Get("ng_plus").AsInt64()));public int NgCoins(int amount)=>State.Get("ng_plus").AsInt64()>0?(int)Math.Ceiling(amount*1.5):amount;
  public static bool CanArrowHit(bool dead,bool active,double airHeight=0)=>!dead&&active&&airHeight<=4;
  public static bool ArrowArmored(string behavior,string state,bool precise=false,bool guardBroken=false)=>behavior=="hb_root"?!precise&&!guardBroken&&(state=="idle"||state=="hb_root_warn"):behavior=="golem"&&state!="windup"&&state!="recover";
  public static int ArrowDamage(bool boss,int damage=2)=>boss?1:damage;
  public static bool SwordHitsProjectile(Vector2 position,Vector2 from,Vector2 direction,double reach){Vector2 offset=position-from;return PlayerMotorModel.SourceLength(offset)<=reach+10&&Vector2.Dot(direction,PlayerMotorModel.NormalizeSource(offset))>.2;}
  public FoundationValue GuardianChestContents()=>Inventory.Room("heart_container")>0?FoundationJson.ParsePlain("[[\"heart_container\",1]]"):FoundationJson.ParsePlain("[[\"potion\",2],[\"coins\",100]]");
  public bool CompleteGuardianReward(bool earned)
  {
   if(busy||!earned||State.Flag("guardian_defeated"))return false;busy=true;try{var staged=new FoundationGameState(State.Snapshot());var inv=new InventoryModel(repository,staged);var progression=new ProgressionModel(repository,staged,inv);staged.SetFlag("guardian_defeated",true);inv.AddCoins(500);progression.SetWeapon("star");progression.FinishQuest("diepte");var updates=staged.Fields.Where(row=>!ReferenceEquals(State.Get(row.Key),row.Value)).ToDictionary(row=>row.Key,row=>row.Value,StringComparer.Ordinal);State.CommitFields(updates);Changed?.Invoke();SaveRequested?.Invoke();return true;}finally{busy=false;}
  }
 }
}
