using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using UnityEngine;

namespace BlueMapMigration.Route
{
    public static class RouteGameplayChecks
    {
        public static int OracleCases { get; private set; }
        public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
        {
            var reference=RouteGameplay.NewGame(repository).Oracle;OracleCases=0;
            foreach(var row in reference.Require("cases").Items)
            {
                string id=row.Require("id").AsString();var model=new RouteGameplay(repository,new FoundationGameState(row.Require("initial")));int index=0;
                foreach(var operation in row.Require("operations").Items)
                {
                    bool result=Execute(model,operation);
                    if(result!=row.Require("results").Items[index].AsBool())throw new InvalidOperationException("Route source result differs: "+id+" operation "+index);index++;
                }
                string difference=Difference(model.State.Snapshot(),row.Require("expectedExact"),id);
                if(difference!=null)throw new InvalidOperationException("Route source state differs: "+difference);
                bool dialogue=(model.Dialogue?.Id??"")==row.Require("dialogue").AsString()&&(model.Dialogue?.ChoicesReady??false)==row.Require("choicesReady").AsBool();
                var cat=row.Require("cat");bool catEqual=model.CatCalm==cat.Require("calm").AsDouble()&&model.CatPanic==cat.Require("panic").AsDouble()&&model.CatWaiting==cat.Require("waiting").AsBool();
                check("route_source_"+id,dialogue&&catEqual);OracleCases++;
            }
            check("route_source_oracle_complete",OracleCases==26);
            foreach(var row in reference.Require("durations").Items)
            {
                var model=RouteGameplay.NewGame(repository);model.State.Set("inventory",row.Require("inventory"));model.State.Set("equipment",row.Require("equipment"));
                string duration=BitConverter.ToString(BitConverter.GetBytes(model.ResourceDuration("branches"))).Replace("-","").ToLowerInvariant();
                check("route_source_gear_"+row.Require("id").AsString(),duration==row.Require("durationExact").Require("$f64").AsString()&&model.Bonus("move_speed")==row.Require("moveSpeed").AsDouble()&&model.Bonus("magnet_range")==row.Require("magnetRange").AsDouble());
            }
            var reward=RouteGameplay.NewGame(repository);reward.State.SetFlag("cat_found",true);reward.State.Set("quests",FoundationJson.ParsePlain("{\"kat\":{\"state\":\"active\",\"step\":1}}"));
            reward.Talk("pim");reward.Advance();long coins=reward.State.Coins,xp=reward.State.Get("hero_xp").AsInt64();reward.Talk("pim");reward.Advance();
            check("route_quest_rewards_idempotent",reward.State.Count("heart_container")==1&&xp==40&&reward.State.Get("hero_xp").AsInt64()==xp&&reward.State.Coins==coins&&reward.State.Flag("cat_home")&&reward.State.QuestState("kat")=="done");
            var questAtomic=RouteGameplay.NewGame(repository);questAtomic.State.SetFlag("cat_found",true);questAtomic.State.Set("quests",FoundationJson.ParsePlain("{\"kat\":{\"state\":\"active\",\"step\":1}}"));questAtomic.Talk("pim");bool coherentQuest=false;
            using(questAtomic.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="inventory"){coherentQuest=questAtomic.State.Count("heart_container")==1&&questAtomic.State.QuestState("kat")=="done"&&questAtomic.State.Get("hero_xp").AsInt64()==40&&questAtomic.State.Flag("cat_home");}}))questAtomic.Advance();
            check("route_dialogue_reward_commits_coherently",coherentQuest);
            var calm=RouteGameplay.NewGame(repository);calm.Talk("muis_bos");calm.TickCat(1,32,0,false);calm.TickCat(.1,32,6,false);bool cancelled=calm.CatCalm==0&&!calm.CatWaiting;calm.TickCat(.25,60,0,true);bool frightened=calm.CatPanic==2.25;calm.TickCat(3,150,0,false);calm.Talk("muis_bos");calm.TickCat(2,32,0,false);calm.Talk("muis_bos");calm.Advance();
            check("route_cat_calm_and_panic",cancelled&&frightened&&calm.State.Flag("cat_found")&&calm.State.QuestStep("kat")==1);
            var gather=RouteGameplay.NewGame(repository);gather.State.PlayTime=10.125;bool picked=gather.Gather("branches","prof:village:twigs_west");bool repeated=gather.Gather("branches","prof:village:twigs_west");bool tool=gather.Gather("stump","prof:forest:birch_west");
            check("route_harvest_cooldowns_and_tools",picked&&!repeated&&!tool&&gather.State.Count("prof_branch")==2&&gather.ResourceRemaining("prof:village:twigs_west")==90);
            var chest=RouteGameplay.NewGame(repository);bool sawCoherent=false;bool reentrant=false;
            var loot=FoundationJson.ParsePlain("[[\"potion\",1],[\"coins\",25]]");
            using(chest.State.Events.Subscribe<FoundationStateChanged>(change=>
            {if(change.Field=="flags"){sawCoherent=chest.State.Flag("chest:route:atomic")&&chest.State.Coins==25&&chest.State.Count("potion")==1;reentrant=chest.OpenChest("chest:route:atomic",loot);}}))
                chest.OpenChest("chest:route:atomic",loot);
            check("route_chest_atomic_rewards",sawCoherent&&!reentrant&&chest.State.Coins==25&&chest.State.Count("potion")==1);
            var unknown=RouteGameplay.NewGame(repository);var payload=FoundationJson.ParsePlain("{\"kind\":\"future_mod\",\"bits\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");unknown.State.Set("future_fields",payload);unknown.State.Set("inventory",FoundationJson.ParsePlain("{\"future_stack\":9007199254740993}"));unknown.Gather("branches","prof:village:twigs_west");unknown.Rest();
            check("route_unknown_fields_retained",FoundationJson.StringifyPlain(unknown.State.Get("future_fields"))==FoundationJson.StringifyPlain(payload)&&unknown.State.Count("future_stack")==9007199254740993L&&unknown.State.Fields.Count==35);
            var rest=RouteGameplay.NewGame(repository);rest.State.Hp=1;rest.State.PlayTime=96;rest.State.DayTime=.8;rest.State.DayCount=7;rest.Rest();
            check("route_rest_source_policy",rest.State.Hp==5&&rest.State.PlayTime==96&&rest.State.DayTime==.8&&rest.State.DayCount==7);
            var paused=RouteGameplay.NewGame(repository);paused.State.SetUi("modal",true);bool blocked=!paused.Talk("pim")&&!paused.Gather("branches","prof:village:twigs_west")&&!paused.OpenChest("chest:blocked",loot)&&!paused.Rest();paused.TickCat(2,20,0,false);
            check("route_modal_actions_and_calm_paused",blocked&&paused.State.Coins==0&&paused.State.Count("prof_branch")==0&&paused.CatCalm==0);
            var invalid=RouteGameplay.NewGame(repository);bool refused=false;try{invalid.State.CommitFields(new Dictionary<string,FoundationValue>{{"coins",FoundationValue.Integer(77)},{"",FoundationValue.Nil()}});}catch(ArgumentException){refused=true;}
            check("route_invalid_transaction_preserves_state",refused&&invalid.State.Coins==0);
            var fault=RouteGameplay.NewGame(repository);bool alreadyCommitted=false;
            using(fault.State.Events.Subscribe<FoundationStateChanged>(change=>{if(change.Field=="flags")throw new InvalidOperationException("Injected observer failure");}))
                try{fault.OpenChest("chest:observer",loot);}catch(FoundationLocationCommittedException error){alreadyCommitted=error.AlreadyCommitted;}
            bool repeat=fault.OpenChest("chest:observer",loot);
            check("route_observer_failure_cannot_duplicate_rewards",alreadyCommitted&&repeat&&fault.State.Coins==25&&fault.State.Count("potion")==1);
            var pickup=RouteGameplay.NewGame(repository);bool crystalPicked=pickup.CollectPickup("crystal_bos","pickup:forest:source");bool pickedTwice=pickup.CollectPickup("crystal_bos","pickup:forest:source");
            check("route_pickup_unique_claim_and_full_hearts",crystalPicked&&!pickedTwice&&pickup.State.Count("crystal_bos")==1&&!pickup.CollectPickup("heart","")&&pickup.State.Hp==5);
            check("route_model_checks_ran",true);
        }
        private static bool Execute(RouteGameplay model,FoundationValue operation)
        {
            var a=operation.Items;
            switch(a[0].AsString())
            {
                case "talk":return model.Talk(a[1].AsString());
                case "advance":return model.Advance();
                case "choose":return model.Choose((int)a[1].AsInt64());
                case "close":model.CloseDialogue();return true;
                case "cat_tick":model.TickCat(a[1].AsDouble(),a[2].AsDouble(),a[3].AsDouble(),a[4].AsBool());return true;
                case "gather":return model.Gather(a[1].AsString(),a[2].AsString());
                case "pickup":return model.CollectPickup(a[1].AsString(),a[2].AsString());
                case "time":model.State.PlayTime=a[1].AsDouble();return true;
                case "rest":return model.Rest();
                case "chest":return model.OpenChest(a[1].AsString(),a[2]);
                default:throw new InvalidOperationException("Unknown route oracle operation: "+a[0].AsString());
            }
        }
        private static string Difference(FoundationValue actual,FoundationValue expected,string path)
        {
            if(expected.TryGet("$f64",out var bits))
            {
                if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected source number, got "+actual.Kind;
                string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();
                return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString();
            }
            if(expected.Kind=="object"||expected.Kind=="dictionary")
            {
                if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected object, got "+actual.Kind;
                if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
                foreach(var pair in expected.Entries)
                {if(!actual.TryGet(pair.Key.AsString(),out var child))return path+": missing "+pair.Key.AsString();string failure=Difference(child,pair.Value,path+"."+pair.Key.AsString());if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="array")
            {
                if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array shape differs";
                for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
            }
            if(actual.Kind!=expected.Kind)return path+": kind "+actual.Kind+" != "+expected.Kind;
            if(actual.Kind=="int")return actual.AsInt64()==expected.AsInt64()?null:path+": integer differs";
            if(actual.Kind=="string")return actual.AsString()==expected.AsString()?null:path+": text differs";
            if(actual.Kind=="bool")return actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
            return actual.Kind=="nil"?null:path+": unsupported source oracle scalar";
        }
    }
}
