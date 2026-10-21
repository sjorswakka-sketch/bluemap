using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using BlueMapMigration.Player;
using UnityEngine;
namespace BlueMapMigration.Combat
{
 public static class CombatModelChecks
 {
  public static int OracleCases {get;private set;} public static IReadOnlyList<string> CaseIds{get;private set;}=Array.Empty<string>();
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue N(double v)=>FoundationValue.Number(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue Z()=>FoundationValue.Nil();
  static FoundationValue A(IEnumerable<FoundationValue> v)=>FoundationValue.Array(v);static FoundationValue V(Vector2 v)=>A(new[]{N(v.x),N(v.y)});static Vector2 ReadV(FoundationValue v)=>new Vector2((float)v.Items[0].AsDouble(),(float)v.Items[1].AsDouble());
  static FoundationValue O(params(string key,FoundationValue value)[] v)=>FoundationValue.Object(v.ToDictionary(x=>x.key,x=>x.value,StringComparer.Ordinal));
  sealed class Target{public string Id,Behavior,State;public Vector2 At;public double Radius,Height,Guard;public bool Active,Dead,Boss;public int Breaks;public List<FoundationValue> Hits=new List<FoundationValue>();public void Break(){Breaks++;Guard=2;if(Behavior=="hb_root")State="hb_rest";}}
  sealed class Replay
  {
   public CombatModel Model;public List<Target> Targets=new List<Target>();public List<FoundationValue> Arrows=new List<FoundationValue>();public bool Clear=true,Lent;const string owner="combat-fixture";
   public Replay(FoundationWorldRepository repo,FoundationValue row)
   {
    var state=new FoundationGameState(InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));state.InGame=true;var inv=new InventoryModel(repo,state);var progression=new ProgressionModel(repo,state,inv);Model=new CombatModel(repo,state,inv,progression);Model.ClearLine=(a,b)=>Clear;Model.LentArrows=()=>Lent;
    Model.Movement.ConfigureBonuses(progression.Bonus("stamina_max"),progression.Bonus("stamina_regen"));Model.Movement.Stamina=100;
    foreach(var field in InventoryModelChecks.DecodeOrdered(row.Require("transientOrdered")).Entries){if(field.Key.AsString()=="arenaIntercept")Model.DefeatHandler=()=>true;else SetTimer(field.Key.AsString(),field.Value);}
    Model.StrikeRequested+=strike=>{foreach(var t in Targets){var offset=t.At-strike.Position;double dot=Vector2.Dot(strike.Direction,PlayerMotorModel.NormalizeSource(offset));if(PlayerMotorModel.SourceLength(offset)>strike.Reach+t.Radius||!(strike.InclusiveCone?dot>=strike.Cone:dot>strike.Cone)||!Clear)continue;if(strike.BreakGuard)t.Break();t.Hits.Add(O(("damage",I(strike.Damage)),("direction",V(strike.Direction))));}};
    Model.ArrowRequested+=arrow=>{Vector2 at=arrow.Position;double left=arrow.LaunchDistance;while(left>0){double step=Math.Min(left,8);left-=step;at+=PlayerMotorModel.ScaleSource(arrow.Direction,step);}Arrows.Add(O(("position",V(at)),("direction",V(arrow.Direction)),("damage",I(arrow.Damage)),("speed",N(arrow.Speed)),("maxRange",N(arrow.MaxRange)),("precise",B(arrow.Precise)),("traveled",N(0)),("state",S("flying"))));};
   }
   public FoundationValue Snapshot()
   {
    var p=Model.Player;var m=Model.Movement;return O(("position",V(p.Position)),("aim",V(p.AimDirection)),("attackDirection",V(p.AttackDirection)),("bowDirection",V(p.BowDirection)),("attackTimer",N(p.AttackTimer)),("cooldown",N(p.Cooldown)),("bowCooldown",N(p.BowCooldown)),("bowAnim",N(p.BowAnim)),("invulnerable",N(p.Invulnerable)),("knockback",V(p.Knockback)),("rollTimer",N(p.RollTimer)),("comboStep",I(p.ComboStep)),("comboWindow",N(p.ComboWindow)),("comboSweep",B(p.ComboSweep)),("phase",S(p.Phase)),("elapsed",N(p.Elapsed)),("recovery",N(p.Recovery)),("hintTime",N(p.HintTime)),("profile",p.Profile),("originMap",S(p.OriginMap)),("techniqueDirection",V(p.TechniqueDirection)),("ranged",B(p.Ranged)),("noArrowsToast",N(p.NoArrowsToast)),("stamina",N(m.Stamina)),("regenDelay",N(m.RegenDelay)),("exhausted",B(m.Exhausted)),("ended",B(Model.State.Ended)),("damageSource",S(p.LastDamageSource)),("damageLog",FoundationValue.Object(p.DamageLog.ToDictionary(x=>x.Key,x=>I(x.Value),StringComparer.Ordinal))),("arrows",A(Arrows)),("targets",A(Targets.Select(t=>O(("id",S(t.Id)),("hits",A(t.Hits)),("breaks",I(t.Breaks)),("state",S(t.State)))))));
   }
   void SetTimer(string key,FoundationValue v)
   {var p=Model.Player;switch(key){case "aim_direction":p.AimDirection=ReadV(v);break;case "invuln":p.Invulnerable=v.AsDouble();break;case "roll_timer":p.RollTimer=v.AsDouble();break;case "cooldown":p.Cooldown=v.AsDouble();break;case "bow_cooldown":p.BowCooldown=v.AsDouble();break;default:throw new InvalidOperationException("Unknown original player fixture field: "+key);}}
   public FoundationValue Execute(FoundationValue op)
   {
    var a=op.Items;var p=Model.Player;var state=Model.State;FoundationValue result=Z();switch(a[0].AsString())
    {
     case "attack":Model.Attack(a[1].AsBool());break;
     case "shoot":Model.Shoot(a[1].AsBool());break;
     case "begin":Model.BeginTechnique(a[1].AsBool());break;
     case "step":double dt=a[1].AsDouble();Model.BeforePhysics(dt);var frame=Model.Motor.BeginStep(dt,new MotionInput{Locked=state.InputLocked,CombatBusy=Model.TechniqueBusy,AttackActive=p.AttackTimer>0,BowActive=p.BowAnim>0,CombatMovementFactor=Model.MovementScale});Model.Motor.CompleteStep(frame,0,"");Model.AfterPhysics(dt);p.Position=Vector2.zero;break;
     case "cancel":Model.Cancel();break;case "stop":Model.StopForTransition();break;
     case "hurt":Model.Hurt(ReadV(a[1]),(int)a[2].AsInt64(),a[3].AsString());break;
     case "profile":result=Model.EffectiveProfile(a[1].AsString(),a[2].AsBool());break;
     case "counter":result=B(Model.Counter());break;case "block":result=B(Model.TryBlock(ReadV(a[1])));break;
     case "timer":SetTimer(a[1].AsString(),a[2]);break;case "clear":Clear=a[1].AsBool();break;case "lent":Lent=a[1].AsBool();break;
     case "stamina":Model.Movement.Stamina=a[1].AsDouble();Model.Movement.RegenDelay=0;Model.Movement.Exhausted=a[2].AsBool();break;
     case "locked":state.SetUi(owner,a[1].AsBool());break;case "map":state.MapId=a[1].AsString();break;
     case "take":Model.Inventory.Take(a[1].AsString(),a[2].AsInt64());break;case "equip":Model.Progression.Equip(a[1].AsString());break;
     case "target":Targets.Add(new Target{Id=a[1].AsString(),At=ReadV(a[2]),Radius=a[3].AsDouble(),Behavior=a[4].AsString(),State=a[5].AsString(),Boss=a[6].AsBool(),Active=a[7].AsBool(),Dead=a[8].AsBool(),Height=a[9].AsDouble()});break;
     case "arrow_can_hit":result=B(CombatModel.CanArrowHit(a[1].AsBool(),a[2].AsBool(),a[3].AsDouble()));break;
     case "arrow_armored":result=B(CombatModel.ArrowArmored(a[1].AsString(),a[2].AsString(),a[3].AsBool(),a[4].AsDouble()>0));break;
     case "segment":result=N(SegmentDistance(ReadV(a[1]),ReadV(a[2]),ReadV(a[3])));break;
     case "arrow_travel":Vector2 at=ReadV(a[1]),direction=ReadV(a[2]);double left=a[3].AsDouble(),travel=0;string flight="flying";while(left>0&&flight=="flying"){double step=Math.Min(left,8);left-=step;at+=PlayerMotorModel.ScaleSource(direction,step);travel+=step;if(travel>=a[4].AsDouble())flight="fading";}result=O(("position",V(at)),("traveled",N(travel)),("state",S(flight)));break;
     case "projectile_sword":result=B(CombatModel.SwordHitsProjectile(ReadV(a[1]),ReadV(a[2]),ReadV(a[3]),a[4].AsDouble()));break;
     case "ng_hp":result=I(Model.NgHp((int)a[1].AsInt64()));break;case "ng_coins":result=I(Model.NgCoins((int)a[1].AsInt64()));break;
     case "guardian_chest":result=O(("contents",Model.GuardianChestContents()),("key",S("chest:depths2:heart")));break;
     case "guardian_finish":Model.CompleteGuardianReward(true);break;
     default:throw new InvalidOperationException("Unknown original combat operation: "+a[0].AsString());
    }
    return O(("value",result),("player",Snapshot()));
   }
  }
  public static double SegmentDistance(Vector2 point,Vector2 from,Vector2 to){Vector2 segment=to-from;float length=PlayerMotorModel.SourceLengthSquared(segment);if(length==0)return PlayerMotorModel.SourceLength(point-from);float weight=Math.Max(0,Math.Min(1,Vector2.Dot(point-from,segment)/length));return PlayerMotorModel.SourceLength(point-(from+segment*weight));}
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   var oracle=new CombatCatalog().Oracle;var ids=new List<string>();OracleCases=0;
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var replay=new Replay(repository,row);string failure=Difference(replay.Snapshot(),row.Require("initialPlayerExact"),id+".initialPlayer");if(failure!=null)throw new InvalidOperationException("Original combat initial differs: "+failure);
    var operations=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;for(int index=0;index<operations.Count;index++){var actual=replay.Execute(operations[index]);failure=Difference(actual,row.Require("resultsExact").Items[index],id+".results["+index+"]");if(failure!=null)throw new InvalidOperationException("Original combat result differs: "+failure);}
    failure=Difference(replay.Model.State.Snapshot(),row.Require("expectedExact"),id+".state");if(failure!=null)throw new InvalidOperationException("Original combat state differs: "+failure);ids.Add(id);OracleCases++;
   }
   CaseIds=ids.AsReadOnly();check("combat_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count);
   var freshRow=oracle.Require("cases").Items[0];var fresh=new Replay(repository,freshRow);var unknown=FoundationJson.ParsePlain("{\"big\":9007199254740993,\"nested\":[null,true,\"🌿\"]}");fresh.Model.State.Set("future_combat",unknown);string before=FoundationJson.StringifyPlain(fresh.Model.State.Snapshot());var duplicate=new CombatModel(repository,fresh.Model.State,fresh.Model.Inventory,fresh.Model.Progression,fresh.Model.Motor);bool pure=before==FoundationJson.StringifyPlain(fresh.Model.State.Snapshot());fresh.Model.Movement.Stamina=0;fresh.Model.Movement.Exhausted=true;string bag=FoundationJson.StringifyPlain(fresh.Model.State.Snapshot());bool noSpend=!fresh.Model.BeginTechnique(false)&&fresh.Model.Movement.Stamina==0&&bag==FoundationJson.StringifyPlain(fresh.Model.State.Snapshot());bool noGift=!fresh.Model.CompleteGuardianReward(false)&&bag==FoundationJson.StringifyPlain(fresh.Model.State.Snapshot());fresh.Model.Hurt(new Vector2(1,0),0,"future");var guarded=new Replay(repository,freshRow);bool reentered=false;guarded.Model.CancelWorkRequested+=()=>{reentered|=guarded.Model.BeginTechnique(false);};bool started=guarded.Model.BeginTechnique(false);bool oneSpend=guarded.Model.Movement.Stamina==84;
   var reward=new Replay(repository,freshRow);long xpBefore=reward.Model.Progression.Progress.XP;bool paid=reward.Model.CompleteGuardianReward(true);string afterReward=FoundationJson.StringifyPlain(reward.Model.State.Snapshot());bool oneReward=!reward.Model.CompleteGuardianReward(true)&&afterReward==FoundationJson.StringifyPlain(reward.Model.State.Snapshot())&&reward.Model.Progression.Progress.XP==xpBefore&&reward.Model.State.Get("weapon").AsString()=="star";
   check("combat_model_atomic_and_unknown_safety",pure&&noSpend&&noGift&&ReferenceEquals(unknown,fresh.Model.State.Get("future_combat"))&&ReferenceEquals(duplicate.Movement,fresh.Model.Movement)&&started&&!reentered&&oneSpend&&paid&&oneReward);
  }
        static string Difference(FoundationValue actual,FoundationValue expected,string path)
        {
            if(expected.TryGet("$f64",out var bits))
            {
                if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected number, got "+actual.Kind;
                string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString();
            }
            if(expected.Kind=="object"||expected.Kind=="dictionary")
            {
                if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected dictionary";
                if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
                foreach(var row in expected.Entries){if(!actual.TryGet(row.Key.AsString(),out var child))return path+": missing "+row.Key.AsString();string failure=Difference(child,row.Value,path+"."+row.Key.AsString());if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="array")
            {
                if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array length differs";
                for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="int")return actual.Kind=="int"&&actual.AsInt64()==expected.AsInt64()?null:path+": integer differs";
            if(expected.Kind=="bool")return actual.Kind=="bool"&&actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
            if(expected.Kind=="string")return actual.Kind=="string"&&actual.AsString()==expected.AsString()?null:path+": text differs ("+(actual.Kind=="string"?actual.AsString():actual.Kind)+")";
            return actual.Kind=="nil"&&expected.Kind=="nil"?null:path+": scalar kind differs";
        }
 }
}
