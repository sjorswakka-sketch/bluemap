using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using UnityEngine;

namespace BlueMapMigration.Inventory
{
    /// <summary>Real Windows-player inventory proof. Every profile is created below the explicit probe output.</summary>
    public static class InventoryProbeRunner
    {
        [Serializable] public sealed class Result
        {
            public int schemaVersion=1;
            public bool success,gameSaveAccessed=false;
            public BuildIdentity identity;
            public Phase2Probe.Check[] checks=Array.Empty<Phase2Probe.Check>();
        }
        public static Result Last {get;private set;}
        public static PersistenceCoordinator Fixture {get;private set;}
        static FoundationValue Plain(string text)=>FoundationJson.ParsePlain(text);
        static FoundationValue I(long value)=>FoundationValue.Integer(value);
        static string Json(FoundationValue value)=>FoundationJson.StringifyPlain(value);
        static FoundationValue Get(FoundationValue value,string key,FoundationValue fallback)=>InventoryModel.Get(value,key,fallback);
        static string Spawn(FoundationWorldSnapshot snapshot)=>snapshot.Arrivals.FirstOrDefault(row=>row.Name=="start")?.Name??snapshot.Arrivals[0].Name;
        static void At(PlayerWorld world,Vector2 position){world.Teleport(position);world.Step(0,new MotionInput{Direction=Vector2.zero});}
        static bool Visible(PlayerWorld world,string address)=>world.RoutePresentation.Objects.TryGetValue(address,out var obj)&&obj.activeSelf;
        static void FreshLootState(FoundationGameState state)
        {
            state.Set("flags",Plain("{\"op_new_adventure\":true}"));state.Set("inventory",Plain("{}"));state.Set("equipment",Plain("{}"));state.Set("clothing",Plain("{}"));state.Set("quests",Plain("{}"));state.Coins=0;state.Hp=1;
        }
        public static IEnumerator Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route,Phase6Catalog catalog)
        {
            Last=new Result{identity=identity};var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool passed)
            {
                if(checks.Any(row=>row.name==name))throw new InvalidOperationException("Duplicate inventory proof: "+name);
                checks.Add(new Phase2Probe.Check{name=name,passed=passed});Last.checks=checks.ToArray();
                if(!passed)Debug.Log("Inventory check failed: "+name);
            }
            Debug.Log("Inventory stage: exact original model operations and every observed scene reward");
            var repository=FoundationWorldRepository.LoadRequired();InventoryModelChecks.Verify(repository,Check);
            string profileRoot=PersistencePaths.Checked(Path.Combine(output,"inventory-profiles"));
            if(Directory.Exists(profileRoot))throw new IOException("Inventory synthetic profile directory must be fresh.");
            route.CloseModal();Fixture?.Dispose();Fixture=new PersistenceCoordinator(repository,world.InputSource,profileRoot);
            if(!route.BeginNew(Fixture))throw new IOException("Cannot start synthetic inventory adventure: "+Fixture.Status);
            var state=route.Gameplay.State;var oracle=route.Inventory.Oracle;
            Debug.Log("Inventory stage: real original loot in all 37 maps");
            bool nativeLoot=true,chestFrames=true,pickupSprites=true;int nativeMaps=0,chests=0,pickups=0;
            foreach(string map in repository.MapIds)
            {
                route.CloseModal();FreshLootState(state);if(!route.TryTravel(map,Spawn(repository.Read(map)))){nativeLoot=false;continue;}nativeMaps++;
                var original=oracle.Require("loadedSceneLoot").Items.Single(row=>row.Require("map").AsString()==map&&row.Require("scenario").AsString()=="fresh_baseline");
                var liveChests=route.Targets.Where(target=>target.Kind=="chest").ToArray();
                nativeLoot&=liveChests.Length==original.Require("chests").Items.Count;
                foreach(var chest in liveChests)
                {
                    state.Set("inventory",Plain("{}"));state.Set("equipment",Plain("{}"));state.Set("clothing",Plain("{}"));state.Coins=11;state.Hp=1;
                    At(world,chest.Position+new Vector2(0,28));var sprite=world.RoutePresentation.Objects[chest.Address].GetComponent<SpriteRenderer>().sprite;
                    bool opened=route.InteractTarget(chest.Address);long coins=11;var totals=new Dictionary<string,long>(StringComparer.Ordinal);
                    foreach(var reward in chest.Fields.Require("contents").Items){string item=reward.Items[0].AsString();totals[item]=(totals.TryGetValue(item,out var amount)?amount:0)+reward.Items[1].AsInt64();}
                    if(totals.TryGetValue("coins",out var money))coins+=money;
                    nativeLoot&=opened&&state.Flag(chest.UniqueKey)&&state.Coins==coins&&totals.Where(row=>row.Key!="coins").All(row=>state.Count(row.Key)==row.Value);
                    var afterSprite=world.RoutePresentation.Objects[chest.Address].GetComponent<SpriteRenderer>().sprite;chestFrames&=sprite!=afterSprite&&Visible(world,chest.Address);
                    string after=Json(state.Snapshot());bool repeated=route.InteractTarget(chest.Address);nativeLoot&=repeated&&after==Json(state.Snapshot());chests++;
                }
                state.Set("inventory",Plain("{}"));state.Set("equipment",Plain("{}"));state.Set("clothing",Plain("{}"));state.Coins=0;state.Hp=1;
                var livePickups=route.Targets.Where(target=>target.Kind=="pickup").ToArray();nativeLoot&=livePickups.Length==original.Require("pickups").Items.Count;
                foreach(var pickup in livePickups)
                {
                    if(!pickup.Consumed)
                    {
                        state.Hp=1;At(world,pickup.Position);route.Tick(.31);
                        if(!pickup.Consumed)route.Tick(.31);
                    }
                    nativeLoot&=pickup.Consumed&&(pickup.UniqueKey==""||state.Flag(pickup.UniqueKey));pickupSprites&=!Visible(world,pickup.Address);pickups++;
                }
                yield return null;
            }
            Check("inventory_native_pickups_and_chests",nativeLoot&&chests==33&&pickups==73);
            Check("inventory_native_all_37_map_loot",nativeLoot&&nativeMaps==37);
            Check("inventory_native_chest_and_pickup_art_updates",chestFrames&&pickupSprites&&chests==33&&pickups==73);

            Debug.Log("Inventory stage: live magnet motion and retained full drops");
            route.CloseModal();FreshLootState(state);route.TryTravel("player_home",Spawn(repository.Read("player_home")));At(world,new Vector2(208,304));
            bool allMagnetic=true;
            foreach(string item in new[]{"coin","heart","arrow","potion","prof_branch","hs_grape","herb","crystal_bos","ruin_key","gear_bronze_helm"})
            {
                state.Set("inventory",Plain("{}"));state.Hp=1;state.Coins=0;
                var pickup=route.SpawnLootPickup(item,world.Position+new Vector2(48,0));Vector2 start=pickup.Position;
                route.Tick(.3);bool magneticMoved=Vector2.Distance(world.Position,pickup.Position)<Vector2.Distance(world.Position,start);
                route.Tick(.1);allMagnetic&=magneticMoved&&pickup.Consumed&&!Visible(world,pickup.Address);
            }
            Check("inventory_native_magnetic_all_items",allMagnetic);
            state.Set("inventory",Plain("{\"arrow\":40}"));state.Hp=state.MaxHp;
            var fullArrow=route.SpawnLootPickup("arrow",world.Position+new Vector2(30,0));var fullHeart=route.SpawnLootPickup("heart",world.Position+new Vector2(-30,0));
            route.Tick(.3);bool retained=!fullArrow.Consumed&&!fullHeart.Consumed&&Visible(world,fullArrow.Address)&&Visible(world,fullHeart.Address)&&Vector2.Distance(world.Position,fullArrow.Position)<16&&Vector2.Distance(world.Position,fullHeart.Position)<16;
            state.Set("inventory",Plain("{\"arrow\":39}"));state.Hp=3;route.Tick(.1);
            Check("inventory_native_full_pickups_remain",retained&&fullArrow.Consumed&&fullHeart.Consumed&&state.Count("arrow")==40&&state.Hp==4);
            state.Set("inventory",Plain("{}"));string unique="pickup:inventory:native_unique";state.SetFlag(unique,false);var uniquePickup=route.SpawnLootPickup("crystal_bos",world.Position,unique);
            route.Tick(.31);long crystal=state.Count("crystal_bos");bool doubleBlocked=!route.Gameplay.CollectPickup("crystal_bos",unique,uniquePickup.Pickup.InstanceKey)&&route.SpawnLootPickup("crystal_bos",world.Position,unique)==null;
            Check("inventory_native_unique_pickup_once",uniquePickup.Consumed&&state.Flag(unique)&&crystal==1&&doubleBlocked&&state.Count("crystal_bos")==1);
            var pending=route.SpawnLootPickup("prof_branch",world.Position+new Vector2(112,0));route.Tick(.11);Vector2 savedDrop=pending.Position;double age=pending.Age;
            bool refreshed=route.TryTravel("player_home",Spawn(repository.Read("player_home")),true);
            var restored=route.Targets.Where(target=>target.Kind=="pickup"&&target.Address.StartsWith("runtime-pickup/",StringComparison.Ordinal)&&target.Id=="prof_branch"&&!target.Consumed&&Vector2.Distance(target.Position,savedDrop)<.01f).ToArray();
            bool retainedOnRefresh=refreshed&&restored.Length==1&&restored[0].Age==age&&Visible(world,restored[0].Address);
            if(restored.Length==1){At(world,restored[0].Position);route.Tick(.31);}
            Check("inventory_native_groundloot_refresh_retained",retainedOnRefresh&&restored.Length==1&&restored[0].Consumed&&state.Count("prof_branch")==1);

            Debug.Log("Inventory stage: actual mountain chest owned reward and full capacity");
            FreshLootState(state);route.TryTravel("ridgepass",Spawn(repository.Read("ridgepass")));var coat=route.Targets.Single(target=>target.Kind=="chest"&&target.Fields.Require("contents").Items.Any(row=>row.Items[0].AsString()=="gear_bastion_coat"));
            state.Set("inventory",Plain("{\"gear_bastion_coat\":1}"));state.Set("equipment",Plain("{\"chest\":\"gear_bastion_coat\"}"));state.Coins=10;At(world,coat.Position+new Vector2(0,28));
            bool owned=route.InteractTarget(coat.Address);
            Check("inventory_native_owned_unique_chest_reward",owned&&state.Count("gear_bastion_coat")==1&&state.Coins==85&&state.Flag(coat.UniqueKey)&&state.Get("equipment").Require("chest").AsString()=="gear_bastion_coat"&&route.Message.IndexOf("bezit",StringComparison.OrdinalIgnoreCase)>=0);
            var arrowSource=repository.MapIds.SelectMany(map=>repository.Read(map).Root.Require("scene").Items.Select(node=>(map,node))).First(row=>Get(row.node,"script",FoundationValue.StringValue("")).AsString().EndsWith("/chest.gd",StringComparison.Ordinal)&&row.node.Require("fields").Require("contents").Items.Any(reward=>reward.Items[0].AsString()=="arrow"));
            FreshLootState(state);route.TryTravel(arrowSource.map,Spawn(repository.Read(arrowSource.map)));var arrowChest=route.Targets.First(target=>target.Kind=="chest"&&target.Fields.Require("contents").Items.Any(reward=>reward.Items[0].AsString()=="arrow"));
            state.Set("inventory",Plain("{\"arrow\":40}"));state.Coins=70;At(world,arrowChest.Position+new Vector2(0,28));route.Save();string beforeFull=Json(state.Snapshot()),revision=Fixture.Current.RevisionId;
            bool denied=!route.InteractTarget(arrowChest.Address);bool noLootLost=beforeFull==Json(state.Snapshot())&&Fixture.Current.RevisionId==revision&&!state.Flag(arrowChest.UniqueKey);
            long arrowAmount=arrowChest.Fields.Require("contents").Items.Where(reward=>reward.Items[0].AsString()=="arrow").Sum(reward=>reward.Items[1].AsInt64());route.Inventory.Take("arrow",arrowAmount);bool fullClaim=route.InteractTarget(arrowChest.Address);
            Check("inventory_native_failed_chest_keeps_all_rewards",denied&&noLootLost&&fullClaim&&state.Count("arrow")==40&&state.Flag(arrowChest.UniqueKey));

            Debug.Log("Inventory stage: physically local home and coastal stores");
            route.CloseModal();route.TryTravel("player_home",Spawn(repository.Read("player_home")));var home=route.Targets.Single(target=>target.Kind=="stock_chest");At(world,home.Position+new Vector2(0,28));
            state.Set("inventory",Plain("{\"prof_branch\":40,\"gel\":6,\"potion\":4,\"arrow\":38,\"ruin_key\":1,\"gear_bronze_helm\":1}"));state.Set("stockroom",Plain("{\"home\":{},\"favorites\":{},\"sort\":0}"));
            bool openedHome=route.InteractTarget(home.Address);route.UpdateInventoryContext("home");
            bool deposit=route.Inventory.Transfer("prof_branch",10,true,"home")&&route.Inventory.Transfer("potion",4,true,"home")&&route.Inventory.Transfer("arrow",10,true,"home");
            bool withdraw=route.Inventory.Transfer("prof_branch",3,false,"home")&&route.Inventory.Transfer("arrow",10,false,"home");
            Check("inventory_native_home_storage_roundtrip",openedHome&&route.Modal=="inventory"&&state.Paused&&route.Inventory.NearbyKind=="home"&&deposit&&withdraw&&state.Count("prof_branch")==33&&route.Inventory.StockCount("prof_branch")==7&&state.Count("potion")==0&&route.Inventory.StockCount("potion")==4&&state.Count("arrow")==38);
            Check("inventory_native_home_chest_inside_house",home.SceneNode.Require("script").AsString().EndsWith("/stock_chest.gd",StringComparison.Ordinal)&&state.MapId=="player_home"&&home.Position.x>0&&home.Position.x<world.Snapshot.Width*32&&home.Position.y>0&&home.Position.y<world.Snapshot.Height*32&&world.RoutePresentation.Objects.ContainsKey(home.Address));
            string atomicBag=Json(state.Get("inventory")),atomicStock=Json(state.Get("stockroom"));bool invalid=!route.Inventory.Transfer("prof_branch",-1,true,"home")&&!route.Inventory.Transfer("prof_branch",1000,true,"home")&&!route.Inventory.Transfer("potion",1,false,"coast");
            Check("inventory_failed_transfer_is_atomic",invalid&&atomicBag==Json(state.Get("inventory"))&&atomicStock==Json(state.Get("stockroom")));
            route.Inventory.ToggleFavorite("prof_branch");long moved=route.Inventory.Bulk(false,"home");bool favoriteProtected=moved==6&&state.Count("prof_branch")==33&&route.Inventory.StockCount("prof_branch")==7&&route.Inventory.StockCount("gel")==6;
            route.Inventory.ToggleFavorite("prof_branch");long rest=route.Inventory.Bulk(true,"home");
            Check("inventory_native_favorites_bulk_preserved",favoriteProtected&&rest==33&&state.Count("prof_branch")==0&&route.Inventory.StockCount("prof_branch")==40);
            Check("inventory_native_key_items_retained",state.Count("ruin_key")==1&&state.Count("gear_bronze_helm")==1&&route.Inventory.Movable("ruin_key",true,"home")==0&&route.Inventory.Movable("gear_bronze_helm",true,"home")==0);
            state.Set("inventory",Plain("{\"prof_branch\":2}"));state.Set("stockroom",Plain("{\"home\":{\"prof_branch\":7,\"gel\":5},\"favorites\":{},\"sort\":0}"));
            bool supplied=route.Inventory.Available("prof_branch")==9&&route.Inventory.Consume(Plain("{\"prof_branch\":5,\"gel\":2}"))&&state.Count("prof_branch")==0&&route.Inventory.StockCount("prof_branch")==4&&route.Inventory.StockCount("gel")==3;
            At(world,home.Position-new Vector2(180,0));route.UpdateInventoryContext("home");string farBag=Json(state.Get("inventory")),farStock=Json(state.Get("stockroom"));bool far=!route.Inventory.Transfer("gel",1,false,"home")&&!route.Inventory.Consume(Plain("{\"gel\":1}"))&&route.InventoryPanel.IsReadOnly;
            Check("inventory_native_local_storage_supplies",supplied&&far&&farBag==Json(state.Get("inventory"))&&farStock==Json(state.Get("stockroom")));
            route.CloseModal();route.TryTravel("coast_workshop",Spawn(repository.Read("coast_workshop")));var coast=route.Targets.Single(target=>target.Kind=="coastal_workstation"&&Get(Get(target.Fields,"obj",target.Fields),"role",FoundationValue.StringValue("")).AsString()=="storage");At(world,coast.Position+new Vector2(0,28));
            state.Set("inventory",Plain("{\"prof_branch\":110,\"potion\":3,\"arrow\":7}"));state.Set("coastal_storage",Plain("{}"));bool openedCoast=route.InteractTarget(coast.Address);route.UpdateInventoryContext("coast");
            bool coastRound=route.Inventory.Transfer("prof_branch",99,true,"coast")&&route.Inventory.Transfer("prof_branch",3,false,"coast");
            Check("inventory_native_coastal_storage_roundtrip",openedCoast&&coastRound&&state.Paused&&route.Inventory.NearbyKind=="coast"&&state.Count("prof_branch")==14&&route.Inventory.StockCount("prof_branch","coast")==96&&!route.Inventory.Transfer("potion",1,true,"coast")&&!route.Inventory.Transfer("arrow",1,true,"coast"));
            var materialIds=route.Inventory.Items.Entries.Where(row=>route.Inventory.ItemType(row.Key.AsString())=="material").Select(row=>row.Key.AsString()).ToArray();var twelve=FoundationValue.Object(materialIds.Take(12).ToDictionary(id=>id,id=>I(1),StringComparer.Ordinal));
            state.Set("coastal_storage",twelve);string thirteenth=materialIds[12];state.Set("inventory",FoundationValue.Object(new Dictionary<string,FoundationValue>{{thirteenth,I(2)}}));bool coastSlots=route.Inventory.StockRoom(thirteenth,"coast")==0&&!route.Inventory.Transfer(thirteenth,1,true,"coast");
            route.CloseModal();route.TryTravel("player_home",Spawn(repository.Read("player_home")));home=route.Targets.Single(target=>target.Kind=="stock_chest");At(world,home.Position+new Vector2(0,28));route.OpenStorage("home");route.UpdateInventoryContext("home");
            var allowed=route.Inventory.Items.Entries.Where(row=>route.Inventory.Allowed(row.Key.AsString())).Select(row=>row.Key.AsString()).ToArray();int knownSlots=Math.Min(143,allowed.Length-1);var filledSlots=allowed.Take(knownSlots).ToDictionary(id=>id,id=>I(1),StringComparer.Ordinal);
            // Today's source has 133 storable IDs. Synthetic future slots exercise its 144-kind
            // boundary while proving unknown stored data occupies room and remains untouched.
            while(filledSlots.Count<144)filledSlots.Add("future_stock_slot_"+filledSlots.Count,I(1));var filled=FoundationValue.Object(filledSlots);string extra=allowed[knownSlots];
            state.Set("stockroom",InventoryModel.Replace(state.Get("stockroom"),"home",filled));state.Set("inventory",FoundationValue.Object(new Dictionary<string,FoundationValue>{{extra,I(2)}}));bool homeSlots=route.Inventory.StockRoom(extra,"home")==0&&!route.Inventory.Transfer(extra,1,true,"home");
            state.Set("stockroom",Plain("{\"home\":{\"prof_branch\":995},\"favorites\":{},\"sort\":0}"));state.Set("inventory",Plain("{\"prof_branch\":20}"));bool stack=!route.Inventory.Transfer("prof_branch",5,true,"home")&&route.Inventory.Transfer("prof_branch",4,true,"home")&&route.Inventory.StockCount("prof_branch")==999&&state.Count("prof_branch")==16;
            Check("inventory_native_storage_capacities",coastSlots&&homeSlots&&stack&&InventoryModel.HomeSlots==144&&InventoryModel.HomeCap==999&&InventoryModel.CoastSlots==12&&InventoryModel.CoastCap==99);

            Debug.Log("Inventory stage: consumables restore native health and stamina without waste");
            state.Set("inventory",Plain("{\"hs_grape\":2,\"hs_wine\":2,\"hs_honey\":2,\"potion\":2}"));state.Hp=2;world.Motor.Stamina.Stamina=30;route.UpdateInventoryContext();long oldDrunk=state.Get("potions_drunk").AsInt64();
            bool grape=route.Inventory.UseItem("hs_grape")&&state.Hp==3;route.UpdateInventoryContext();bool wine=route.Inventory.UseItem("hs_wine")&&world.Motor.Stamina.Stamina==70;route.UpdateInventoryContext();bool honey=route.Inventory.UseItem("hs_honey")&&state.Hp==4&&world.Motor.Stamina.Stamina==95;route.UpdateInventoryContext();bool potion=route.Inventory.UseItem("potion")&&state.Hp==5&&state.Get("potions_drunk").AsInt64()==oldDrunk+1;
            world.Motor.Stamina.Reset();route.UpdateInventoryContext();string full=Json(state.Snapshot());bool noWaste=!route.Inventory.CanUseItem("hs_grape")&&!route.Inventory.CanUseItem("hs_wine")&&!route.Inventory.UseItem("hs_grape")&&!route.Inventory.UseItem("hs_wine")&&full==Json(state.Snapshot());
            Check("inventory_native_consumables_and_stamina",grape&&wine&&honey&&potion&&noWaste&&state.Paused);

            Debug.Log("Inventory stage: synthetic profile durability, future fields and separate item receipts");
            var unknown=Plain("{\"kind\":\"future_mod\",\"value\":9007199254740993,\"nested\":[null,true,\"🌱\"]}");state.Set("future_inventory",unknown);
            state.Set("inventory",InventoryModel.Replace(state.Get("inventory"),"future_stack",I(9007199254740993L)));state.Set("stockroom",InventoryModel.Replace(state.Get("stockroom"),"future_setting",unknown));state.Set("stockroom",InventoryModel.Replace(state.Get("stockroom"),"home",InventoryModel.Replace(state.Get("stockroom").Require("home"),"future_stock",I(9007199254740993L))));
            route.Inventory.SetSort(3);route.Inventory.ToggleFavorite("hs_grape");route.CloseModal();route.Save();string savedBag=Json(state.Get("inventory")),savedStock=Json(state.Get("stockroom")),savedCoast=Json(state.Get("coastal_storage"));string savedFlags=Json(state.Get("flags"));long savedCoins=state.Coins;string savedMap=state.MapId;
            state.Set("inventory",Plain("{}"));state.Set("stockroom",Plain("{}"));state.Set("coastal_storage",Plain("{}"));state.Coins=1;
            bool reload=route.Reload(false);state=route.Gameplay.State;
            Check("inventory_native_save_reload_preserves_inventory",reload&&savedBag==Json(state.Get("inventory"))&&savedStock==Json(state.Get("stockroom"))&&savedCoast==Json(state.Get("coastal_storage"))&&savedFlags==Json(state.Get("flags"))&&state.Coins==savedCoins&&state.MapId==savedMap&&route.Inventory.Favorite("hs_grape")&&route.Inventory.Sort==3);
            Check("inventory_unknown_fields_retained",state.Count("future_stack")==9007199254740993L&&state.Get("future_inventory").Require("value").AsInt64()==9007199254740993L&&state.Get("future_inventory").Require("kind").AsString()=="future_mod"&&state.Get("stockroom").Require("future_setting").Require("nested").Items[2].AsString()=="🌱"&&state.Get("stockroom").Require("home").Require("future_stock").AsInt64()==9007199254740993L);
            route.CloseModal();route.Tick(6);route.Inventory.Give("hs_grape",1);route.ShowMessage(route.T("Het pad naar het Zilvermeer is open.","The path to Silver Lake is open."));
            string notice=route.ItemNotices.LastOrDefault()??"";yield return new WaitForEndOfFrame();
            bool separate=route.Hud.ReceiptsVisible&&route.Hud.LastReceiptBounds.Count>0&&route.Hud.LastMessageBounds.width>0&&route.Hud.LastReceiptBounds.All(bounds=>!bounds.Overlaps(route.Hud.LastMessageBounds))&&route.Message!=""&&notice.Contains(route.Translate(route.Gameplay.ItemName("hs_grape")));
            Check("inventory_item_receipts_separate_message_lane",separate);
            var notices=route.ItemNotices.ToArray();route.OpenInventory();route.Tick(9);yield return new WaitForEndOfFrame();bool pausedNotices=route.ItemNotices.SequenceEqual(notices)&&!route.Hud.ReceiptsVisible;
            route.CloseModal();yield return new WaitForEndOfFrame();bool resumed=route.Hud.ReceiptsVisible&&route.ItemNotices.SequenceEqual(notices);route.Tick(4.6);
            Check("inventory_item_receipts_pause_in_menus",pausedNotices&&resumed&&route.ItemNotices.Count==0);
            for(int index=0;index<7;index++)route.Inventory.Give("hs_grape",1);bool bounded=route.ItemNotices.Count==4;
            Check("inventory_native_receipt_feed_bounded",bounded);

            Debug.Log("Inventory stage: actual virtual-device inventory UI and native screenshots");
            yield return InventoryUiProbeRunner.Run(identity,output,world,route,catalog,Check);
            route.CloseModal();route.Save();
            Check("inventory_no_real_saves_accessed",PersistencePaths.Within(PersistencePaths.Checked(output),profileRoot)&&!PersistencePaths.Within(PersistencePaths.LegacyDefault,profileRoot)&&!PersistencePaths.Within(PersistencePaths.UnityDefault,profileRoot)&&Fixture.Current.Snapshot.Origin=="unity"&&Fixture.Current.Snapshot.CopyOriginals().Count==0);
            Check("inventory_native_checks_ran",world.RouteMode&&route.Running&&route.Gameplay.State.InGame&&InventoryModelChecks.OracleCases==304&&nativeMaps==37&&chests==33&&pickups==73&&checks.Count>=27);
            Last.checks=checks.ToArray();Last.success=checks.All(row=>row.passed);File.WriteAllText(Path.Combine(output,"inventory-result.json"),JsonUtility.ToJson(Last,true));
            Debug.Log("Inventory native proof: "+checks.Count+" checks; "+InventoryModelChecks.OracleCases+" original cases; 37 maps, 33 chests, 73 pickups");
        }
    }
}
