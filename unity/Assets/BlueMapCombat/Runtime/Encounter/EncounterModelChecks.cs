using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Phase6;
using UnityEngine;
namespace BlueMapMigration.Combat
{
 public static class EncounterModelChecks
 {
  public static int OracleCases{get;private set;}
  public static IReadOnlyList<string> CaseIds{get;private set;}=Array.Empty<string>();
  static FoundationValue N(double n)=>FoundationValue.Number(n);static FoundationValue I(long n)=>FoundationValue.Integer(n);static FoundationValue S(string s)=>FoundationValue.StringValue(s);static FoundationValue B(bool b)=>FoundationValue.Boolean(b);static FoundationValue A(IEnumerable<FoundationValue> a)=>FoundationValue.Array(a);static FoundationValue V(Vector2 v)=>A(new[]{N(v.x),N(v.y)});static Vector2 RV(FoundationValue v)=>new Vector2((float)v.Items[0].AsDouble(),(float)v.Items[1].AsDouble());
  static FoundationValue O(params(string key,FoundationValue value)[] pairs)=>FoundationValue.Object(pairs.ToDictionary(p=>p.key,p=>p.value));
  sealed class Replay:IDisposable
  {
   public readonly CombatEncounter Encounter;public readonly FoundationGameState State=new FoundationGameState();public readonly EncounterPlayer Player=new EncounterPlayer{Position=new Vector2(550,500),Lamp=true};public EncounterActor Actor;public EncounterProjectile Projectile;public EncounterPillar Pillar;public readonly List<FoundationValue> Hits=new List<FoundationValue>();public readonly Dictionary<string,long> Drops=new Dictionary<string,long>();public int Deaths;readonly FoundationValue Row;bool deathMode;
   public Replay(FoundationWorldRepository repository,FoundationValue rules,FoundationValue row)
   {
    Row=row;State.InGame=true;State.MapId="forest";Encounter=new CombatEncounter(repository,State,null,null,rules);var f=InventoryModelChecks.DecodeOrdered(row.Require("fixtureOrdered"));Rect cover=new Rect(-100,-100,1,1);if(f.TryGet("cover",out var c))cover=new Rect((float)c.Items[0].AsDouble(),(float)c.Items[1].AsDouble(),(float)c.Items[2].AsDouble(),(float)c.Items[3].AsDouble());if(f.TryGet("player",out var p))Player.Position=RV(p);if(f.TryGet("noisy",out var n))Player.Noisy=n.AsBool();Encounter.Solid=at=>cover.Contains(at);Encounter.BodyFits=(at,r)=>!cover.Contains(at);Encounter.ClearLine=(a,b)=>{int steps=Math.Max(1,(int)Math.Ceiling(Vector2.Distance(a,b)/4));for(int j=0;j<=steps;j++)if(cover.Contains(Vector2.Lerp(a,b,(float)j/steps)))return false;return true;};Encounter.ArrowClearLine=Encounter.ClearLine;Encounter.PlayerLampAt=at=>true;Encounter.HurtRequested+=(from,damage,source)=>Hits.Add(A(new[]{V(from),I(damage),S(source)}));Encounter.LootRequested+=(id,count,at)=>{Drops[id]=Drops.TryGetValue(id,out long old)?old+count:count;};Encounter.ActorDied+=e=>Deaths++;
    string kind=row.Require("kind").AsString();if(row.TryGet("projectile",out var flag)&&flag.AsBool()){if(kind=="player_arrow")Projectile=new EncounterProjectile{Kind=kind,Position=new Vector2(500,500),Direction=Vector2.right,Speed=320,MaxRange=280,PlayerOwned=true};else Projectile=Encounter.SpawnProjectile(kind,new Vector2(500,500),Vector2.right,150,1,"fixture");return;}
    if(row.TryGet("component",out var component)&&component.AsString()=="pillar"){Pillar=new EncounterPillar{Position=new Vector2(500,500)};return;}
    State.SetFlag("vijanden_hint_"+kind,true);Actor=Encounter.Spawn(kind,new Vector2(500,500));Actor.Time=Actor.Anim=Actor.StateTime=0;
    foreach(var pair in f.Entries){string k=pair.Key.AsString();var value=pair.Value;switch(k){case "player":case "cover":case "noisy":break;case "mode":deathMode=true;Actor.Practice=value.AsString()=="practice";Actor.UniqueFlag="fixture_unique";Actor.Data=InventoryModel.Replace(Actor.Data,"drops",A(Actor.Data.Require("drops").Items.Select(d=>A(new[]{d.Items[0],N(1),d.Items[2]}))));break;case "state":Actor.State=value.AsString();break;case "active":Actor.Active=value.AsBool();break;case "wander_timer":Actor.WanderTimer=value.AsDouble();break;case "wander_dir":Actor.Wander=RV(value);break;case "state_time":Actor.StateTime=value.AsDouble();break;case "guard_broken":Actor.GuardBroken=value.AsDouble();break;case "aim_dir":Actor.Aim=RV(value);break;case "habitat_length":Actor.Length=value.AsDouble();break;case "habitat_origin":case "ad_origin":Actor.Origin=RV(value);break;case "hp":Actor.Hp=(int)value.AsInt64();break;case "shift_to":Actor.ShiftTo=(int)value.AsInt64();break;case "line_length":Actor.Length=value.AsDouble();break;default:throw new InvalidOperationException("Unknown source encounter fixture: "+k);}}
   }
   public FoundationValue ActorSnapshot()
   {
    var e=Actor;var dict=new Dictionary<string,FoundationValue>{{"kind",S(e.Kind)},{"hp",I(e.Hp)},{"max_hp",I(e.MaxHp)},{"state",S(e.State)},{"state_time",N(e.StateTime)},{"active",B(e.Active)},{"dead",B(e.Dead)},{"desired",V(e.Desired)},{"aim_dir",V(e.Aim)},{"knockback",V(e.Knockback)},{"guard_broken",N(e.GuardBroken)},{"panic",N(e.Panic)},{"fleeing",B(e.Fleeing)},{"air_height",N(e.AirHeight)},{"hop_count",I(e.HopCount)},{"hop_cooldown",N(e.HopCooldown)},{"special_timer",N(e.Special)},{"ad_combo",I(e.Combo)},{"ad_radius",N(e.Pulse)},{"habitat_length",N(e.Length)},{"habitat_traveled",N(e.Traveled)},{"habitat_hit",B(e.Hit)},{"phase",I(e.Phase)},{"shift_to",I(e.ShiftTo)},{"dash_left",N(e.DashLeft)},{"line_length",N(e.Length)},{"last_attack",S(e.LastAttack)},{"repeat_count",I(e.RepeatCount)},{"volley_timer",N(e.VolleyTimer)},{"shots",A(Encounter.Projectiles.Where(x=>!x.PlayerOwned).Select(x=>A(new[]{S(x.Kind),V(x.Position),V(x.Direction),N(x.Speed),I(x.Damage),S(x.Source)})))},{"hits",A(Hits)}};
    if(deathMode){dict["drop_counts"]=FoundationValue.Object(Drops.ToDictionary(x=>x.Key,x=>I(x.Value)));dict["kill_events"]=I(Deaths);dict["unique_claimed"]=B(State.Flag("fixture_unique"));}
    // Guardian has its own smaller original script; project precisely its declared field schema.
    return FoundationValue.Object(Row.Require("initial").Entries.ToDictionary(x=>x.Key.AsString(),x=>dict[x.Key.AsString()]));
   }
   public FoundationValue ProjectileSnapshot()=>O(("position",V(Projectile.Position)),("dead",B(Projectile.Dead)),("state",S(Projectile.State)),("age",N(Projectile.PlayerOwned?0:Projectile.Age)),("traveled",N(Projectile.PlayerOwned?Projectile.Traveled:0)),("hits",A(Hits)));
   public FoundationValue PillarSnapshot()=>O(("angles",A(Pillar.Angles.Select(N))),("windup",N(Pillar.Windup)),("windup_total",N(Pillar.TotalWindup)),("rings_left",I(Pillar.Rings)),("ring_wait",N(Pillar.Wait)),("shard_speed",N(Pillar.Speed)),("charging",B(Pillar.Charging)),("flash",N(Pillar.Flash)),("shards",A(Encounter.Projectiles.Select(p=>A(new[]{V(p.Position),V(p.Velocity),I(p.Damage)})))));
   public FoundationValue Snapshot()=>Pillar!=null?PillarSnapshot():Projectile!=null?ProjectileSnapshot():ActorSnapshot();
   public FoundationValue Execute(FoundationValue op)
   {
    var a=op.Items;switch(a[0].AsString()){
     case "ai":Encounter.ReplayAi(Actor,a[1].AsDouble(),Player);break;case "hurt":Encounter.HurtActor(Actor,(int)a[1].AsInt64(),RV(a[2]));break;case "break_guard":Encounter.BreakGuard(Actor);break;
     case "step":if(Pillar!=null)Encounter.ReplayPillar(Pillar,a[1].AsDouble());else Encounter.ReplayProjectile(Projectile,a[1].AsDouble(),Player);break;case "launch":Encounter.ReplayLaunch(Projectile,a[1].AsDouble());break;case "sword":Encounter.BreakProjectile(Projectile,RV(a[1]),RV(a[2]),a[3].AsDouble());break;
     case "begin":Pillar.Angles.Clear();Pillar.Angles.AddRange(a[1].Items.Select(x=>x.AsDouble()));Pillar.AngleStep=a[2].AsDouble();Pillar.Windup=Pillar.TotalWindup=a[3].AsDouble();Pillar.Speed=a[4].AsDouble();Pillar.Rings=(int)a[5].AsInt64();Pillar.Wait=0;Pillar.Charging=true;break;case "cancel":Pillar.Cancel();break;default:throw new InvalidOperationException("Unknown encounter oracle operation");}
    return Snapshot();
   }
   public void Dispose()=>Encounter.Dispose();
  }
  public static void Verify(FoundationWorldRepository repository,Phase6Catalog catalog,Action<string,bool> check)
  {
   var resource=Resources.Load<TextAsset>("BlueMapEncounterOracle");if(resource==null)throw new InvalidOperationException("Missing original encounter oracle");var oracle=FoundationJson.ParsePlain(resource.text);var rules=InventoryModelChecks.DecodeOrdered(oracle.Require("catalogsOrdered"));var ids=new List<string>();OracleCases=0;
   foreach(var row in oracle.Require("cases").Items){string id=row.Require("id").AsString();using(var replay=new Replay(repository,rules,row)){
    if(replay.Projectile==null){string first=Difference(replay.Snapshot(),row.Require("initialExact"),id+".initial");if(first!=null)throw new InvalidOperationException(first);}
    var operations=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;for(int i=0;i<operations.Count;i++){string failure=Difference(replay.Execute(operations[i]),row.Require("resultsExact").Items[i],id+".results["+i+"]");if(failure!=null)throw new InvalidOperationException("Original encounter differs: "+failure);}ids.Add(id);OracleCases++;}}
   CaseIds=ids.AsReadOnly();check("combat_encounter_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct().Count()==ids.Count);check("combat_encounter_source_family_coverage",oracle.Require("families").Entries.All(f=>ids.Contains("acquire-"+f.Key.AsString())));check("combat_encounter_source_projectile_pillar_guardian_coverage",ids.Contains("guardian-charge-lock")&&ids.Contains("guardian-next-phase")&&ids.Contains("pillar-rage-two-rings")&&ids.Contains("projectile-flight-guardian_shard")&&ids.Contains("arrow-launch-cover"));
  }
  static string Difference(FoundationValue actual,FoundationValue expected,string path)
  {
   if(expected.TryGet("$f64",out var bits)){double value=BitConverter.ToDouble(Enumerable.Range(0,8).Select(i=>Convert.ToByte(bits.AsString().Substring(i*2,2),16)).ToArray(),0);double got=actual.AsDouble();if(BitConverter.DoubleToInt64Bits(got)==BitConverter.DoubleToInt64Bits(value))return null;
    return path+": "+got.ToString("R")+" != "+value.ToString("R");}
   if(expected.Kind=="object"||expected.Kind=="dictionary"){if(actual.Entries.Count!=expected.Entries.Count)return path+": dictionary count differs";foreach(var p in expected.Entries){if(!actual.TryGet(p.Key.AsString(),out var v))return path+": missing "+p.Key.AsString();string d=Difference(v,p.Value,path+"."+p.Key.AsString());if(d!=null)return d;}return null;}
   if(expected.Kind=="array"){if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array length "+actual.Items.Count+" != "+expected.Items.Count;for(int i=0;i<expected.Items.Count;i++){string d=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(d!=null)return d;}return null;}
   return FoundationJson.StringifyPlain(actual)==FoundationJson.StringifyPlain(expected)?null:path+": "+FoundationJson.StringifyPlain(actual)+" != "+FoundationJson.StringifyPlain(expected);
  }
 }
}
