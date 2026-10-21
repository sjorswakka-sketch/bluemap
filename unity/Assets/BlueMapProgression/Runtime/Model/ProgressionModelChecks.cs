using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using UnityEngine;
namespace BlueMapMigration.Progression
{
 public static class ProgressionModelChecks
 {
  public static int OracleCases {get;private set;} public static IReadOnlyList<string> CaseIds {get;private set;}=Array.Empty<string>();
  static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue B(bool v)=>FoundationValue.Boolean(v);static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue A(IEnumerable<string> values)=>FoundationValue.Array(values.Select(S));
  static FoundationValue O(params (string key,FoundationValue value)[] entries)=>FoundationValue.Object(entries.ToDictionary(v=>v.key,v=>v.value,StringComparer.Ordinal));
  static FoundationValue P(HeroProgress p)=>O(("level",I(p.Level)),("xp",I(p.XP)),("current",I(p.Current)),("needed",I(p.Needed)),("max_level",B(p.AtMax)),("next_reward",I(p.NextReward)));
  public static void Run(Action<string,bool> check)=>Verify(FoundationWorldRepository.LoadRequired(),check);
  public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
  {
   var baseModel=new ProgressionModel(repository,new FoundationGameState());var oracle=baseModel.Oracle;var ids=new List<string>();OracleCases=0;
   foreach(var row in oracle.Require("cases").Items)
   {
    string id=row.Require("id").AsString();var state=new FoundationGameState(InventoryModelChecks.DecodeOrdered(row.Require("initialOrdered")));state.InGame=true;var model=new ProgressionModel(repository,state);var ops=InventoryModelChecks.DecodeOrdered(row.Require("operationsOrdered")).Items;
    for(int index=0;index<ops.Count;index++){var actual=Execute(model,ops[index]);string failure=Difference(actual,row.Require("resultsExact").Items[index],id+".results["+index+"]");if(failure!=null)throw new InvalidOperationException("Original progression result differs: "+failure);}
    string stateFailure=Difference(state.Snapshot(),row.Require("expectedExact"),id+".state");if(stateFailure!=null)throw new InvalidOperationException("Original progression state differs: "+stateFailure);ids.Add(id);OracleCases++;
   }
   CaseIds=ids.AsReadOnly();check("progression_model_source_equivalence",OracleCases==oracle.Require("cases").Items.Count&&ids.Distinct(StringComparer.Ordinal).Count()==ids.Count);
   var atomic=Fresh(repository,oracle);bool coherent=false,reentered=false;int toasts=0;atomic.Toast+=text=>toasts++;
   using(atomic.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field!="hero_xp")return;coherent=atomic.Progress.XP==900&&atomic.State.Coins==75;reentered=atomic.AddHeroXp(900);}))atomic.AddHeroXp(900);
   atomic.AddHeroXp(1);bool oneToast=toasts==1;atomic.AddHeroXp(Int64.MaxValue);long coins=atomic.State.Coins;atomic.AddHeroXp(Int64.MaxValue);bool cap=atomic.Progress.XP==2250&&atomic.Progress.Level==10&&coins==135&&atomic.State.Coins==135;
   var imported=Fresh(repository,oracle);imported.State.Set("hero_xp",I(2250));imported.State.Coins=4;var same=new ProgressionModel(repository,imported.State,imported.Inventory);bool noImportReward=same.State.Coins==4&&same.Progress.AtMax&&!same.AddHeroXp(1)&&same.State.Coins==4;
   var fault=Fresh(repository,oracle);bool observerCommitted=false;using(fault.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="hero_xp")throw new InvalidOperationException("Injected observer failure");}))try{fault.AddHeroXp(2250);}catch(FoundationLocationCommittedException error){observerCommitted=error.AlreadyCommitted;}bool committedOnlyOnce=fault.State.Coins==135&&fault.Progress.AtMax&&!fault.AddHeroXp(2250);
   check("progression_model_atomic_rewards",coherent&&!reentered&&oneToast&&cap&&noImportReward&&observerCommitted&&committedOnlyOnce);
   var unknown=Fresh(repository,oracle);var payload=FoundationJson.ParsePlain("{\"counter\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");unknown.State.Set("future_fields",payload);unknown.State.Set("appearance",InventoryModel.Replace(unknown.State.Get("appearance"),"future_appearance",payload));var before=FoundationJson.StringifyPlain(unknown.State.Snapshot());new ProgressionModel(repository,unknown.State,unknown.Inventory);bool constructorPure=before==FoundationJson.StringifyPlain(unknown.State.Snapshot());unknown.SetHairColor(4);unknown.AddHeroXp(50);bool unknownSafe=ReferenceEquals(unknown.State.Get("future_fields"),payload)&&ReferenceEquals(unknown.State.Get("appearance").Require("future_appearance"),payload);
   bool unowned=!unknown.Equip("gear_bronze_helm")&&!unknown.Wear("cloth_cap");unknown.Inventory.Give("gear_bronze_helm",1,true);unknown.Inventory.Stamina=7;unknown.Equip("gear_bronze_helm");bool noRefill=unknown.Inventory.Stamina==7&&unknown.Inventory.StaminaCapacity==130;unknown.Inventory.Stamina=130;unknown.Unequip("head");bool clamp=unknown.Inventory.Stamina==100&&unknown.Inventory.StaminaCapacity==100;
   var star=Fresh(repository,oracle);star.State.SetFlag("guardian_defeated",true);star.State.Set("weapon",S("crystal"));star.SetUpgradeContext(true);bool noFreeStar=!star.UpgradeWeapon("star")&&star.State.Get("weapon").AsString()=="crystal";
   var legacy=Fresh(repository,oracle);legacy.State.Set("professions",O(("xp",O(("smithing",I(30)),("future_skill",I(9007199254740993L)))),("future_progress",payload)));string legacyBefore=FoundationJson.StringifyPlain(legacy.State.Snapshot());legacy.UpgradeReason("pg_grip_plus");bool pureLegacyQuery=legacyBefore==FoundationJson.StringifyPlain(legacy.State.Snapshot());bool lockedLegacy=!legacy.UpgradeGear("pg_grip_plus");bool legacySafe=legacy.State.Get("professions").Require("xp").Require("smithing").AsInt64()==30&&legacy.State.Get("professions").Require("xp").Require("future_skill").AsInt64()==9007199254740993L&&ReferenceEquals(legacy.State.Get("professions").Require("future_progress"),payload)&&legacy.State.Get("professions").Require("cooldowns").Entries.Count==0;
   check("progression_model_owned_cosmetic_and_upgrade_safety",constructorPure&&unknownSafe&&unowned&&noRefill&&clamp&&noFreeStar&&pureLegacyQuery&&lockedLegacy&&legacySafe&&baseModel.HairIds("m").Count+baseModel.HairIds("v").Count==90&&baseModel.Catalogs.Require("clothing").Entries.Count==24);
  }
  static ProgressionModel Fresh(FoundationWorldRepository repository,FoundationValue oracle){var state=new FoundationGameState(oracle.Require("newGame"));state.InGame=true;return new ProgressionModel(repository,state);}
  static FoundationValue Execute(ProgressionModel model,FoundationValue op)
  {
   var a=op.Items;string id=a[0].AsString();var state=model.State;
   switch(id)
   {
    case "progress":return P(model.Progress);
    case "normalize_xp":return I(ProgressionModel.NormalizeHeroXp(a[1]));
    case "threshold":return I(ProgressionModel.HeroThreshold((int)a[1].AsInt64()));
    case "level_for":return I(ProgressionModel.LevelFor(a[1].AsInt64()));
    case "add_xp":model.AddHeroXp(a[1].AsInt64());return P(model.Progress);
    case "kill":model.RegisterKill(a[1].AsString());return P(model.Progress);
    case "quest_xp":return I(model.QuestXp(a[1].AsString()));
    case "finish":model.FinishQuest(a[1].AsString());return P(model.Progress);
    case "enemy_xp":return I(model.EnemyXp(a[1].AsString()));
    case "normalize_gear":return model.NormalizeEquipment(a[1],a[2]);
    case "normalize_owned":return model.NormalizeOwned(a[1]);
    case "equipped":return S(model.Equipped(a[1].AsString()));
    case "owned_gear":return A(model.OwnedGear(a[1].AsString()));
    case "equip":return B(model.Equip(a[1].AsString()));
    case "unequip":return B(model.Unequip(a[1].AsString()));
    case "gear_reconcile":model.ReconcileEquipment();return state.Get("equipment");
    case "bonus":return FoundationValue.Number(model.Bonus(a[1].AsString()));
    case "preview":return FoundationValue.Number(model.PreviewBonus(a[1].AsString(),a[2].AsString()));
    case "comparison":return S(model.ComparisonText(a[1].AsString()));
    case "stats_text":return S(model.StatsText(a[1].AsString()));
    case "stamina":model.Inventory.Stamina=a[1].AsDouble();return FoundationValue.Number(model.Inventory.Stamina);
    case "energy":return O(("stamina",FoundationValue.Number(model.Inventory.Stamina)),("capacity",FoundationValue.Number(100+model.Bonus("stamina_max"))));
    case "normalize_appearance":return model.NormalizeAppearance(a[1]);
    case "normalize_clothing":return model.NormalizeClothing(a[1],a[2]);
    case "worn":return model.Worn(a[1].AsString());
    case "owned_clothing":return A(model.OwnedClothing(a[1].AsString()));
    case "gender":model.SetGender(a[1].AsString());return state.Get("appearance");
    case "hair":model.SetHair(a[1].AsString());return state.Get("appearance");
    case "hair_color":model.SetHairColor((int)a[1].AsInt64());return state.Get("appearance");
    case "eyes":model.SetEyes(a[1].AsString());return state.Get("appearance");
    case "eye_color":model.SetEyeColor((int)a[1].AsInt64());return state.Get("appearance");
    case "wear":return B(model.Wear(a[1].AsString()));
    case "unwear":return B(model.Unwear(a[1].AsString()));
    case "dye":return B(model.Dye(a[1].AsString(),(int)a[2].AsInt64()));
    case "clothing_reconcile":model.ReconcileClothing();return state.Get("clothing");
    case "craft_reason":return S(model.UpgradeReason(a[1].AsString()));
    case "craft":return B(model.UpgradeGear(a[1].AsString()));
    case "weapon_cost":string next=state.Get("weapon").AsString()=="wood"?"iron":state.Get("weapon").AsString()=="iron"?"crystal":state.Get("weapon").AsString()=="crystal"?"star":"";var recipe=next!=""?model.Catalogs.Require("weaponUpgrades").Require(next):InventoryModel.Empty();return O(("weapon",S(next)),("coins",InventoryModel.Get(recipe,"coins",I(0))),("materials",InventoryModel.Get(recipe,"materials",InventoryModel.Empty())));
    case "weapon_allowed":var target=a[1].AsString();var conditions=model.Catalogs.Require("dialogues").Require("greta_"+target).Require("branch").Items[0].Require("if");return B(new FoundationConditionRegistry(state).CheckAll(conditions).Value);
    case "weapon_actions":model.SetUpgradeContext(true);if(!model.UpgradeWeapon(a[1].AsString()))throw new InvalidOperationException("Original legal weapon action rejected: "+model.LastMessage);return state.Get("weapon");
    case "set_weapon":model.SetWeapon(a[1].AsString());return state.Get("weapon");
    case "context":state.MapId=a[2].AsString();state.InGame=a[4].AsBool();model.Inventory.SetContext(a[1].AsString(),a[2].AsString(),Vector2.zero,new Vector2((float)a[3].AsDouble(),0),a[4].AsBool());return S(model.Inventory.NearbyKind);
    case "take":model.Inventory.Take(a[1].AsString(),a[2].AsInt64());model.Inventory.Stamina=Math.Max(0,Math.Min(model.Inventory.Stamina,100+model.Bonus("stamina_max")));return I(state.Count(a[1].AsString()));
    default:throw new InvalidOperationException("Unknown original progression operation: "+id);
   }
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
