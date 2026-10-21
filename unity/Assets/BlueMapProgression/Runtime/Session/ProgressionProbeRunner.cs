using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Persistence;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using BlueMapMigration.Route;
using UnityEngine;
namespace BlueMapMigration.Progression
{
    /// <summary>Native source-equivalent progression and its actual world/menu/save connections, using fresh synthetic profiles.</summary>
    public static class ProgressionProbeRunner
    {
        [Serializable] public sealed class Result
        {public int schemaVersion=1;public bool success,gameSaveAccessed=false;public BuildIdentity identity;public Phase2Probe.Check[] checks=Array.Empty<Phase2Probe.Check>();}
        public static Result Last {get;private set;}
        public static PersistenceCoordinator Fixture {get;private set;}
        static FoundationValue P(string text)=>FoundationJson.ParsePlain(text);
        static FoundationValue I(long n)=>FoundationValue.Integer(n);
        static FoundationValue S(string text)=>FoundationValue.StringValue(text);
        static string Json(FoundationValue v)=>FoundationJson.StringifyPlain(v);
        static string Spawn(FoundationWorldSnapshot s)=>s.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name??s.Arrivals[0].Name;
        static void At(PlayerWorld world,RouteWorldController route,Vector2 p){world.Teleport(p);world.Step(0,new MotionInput{Direction=Vector2.zero});route.Tick(0);}
        static bool Travel(RouteWorldController route,string map){route.CloseModal();return route.TryTravel(map,Spawn(route.Session.Repository.Read(map)));}
        static void Bag(FoundationGameState state,IEnumerable<KeyValuePair<string,long>> items)=>state.Set("inventory",FoundationValue.Object(items.ToDictionary(r=>r.Key,r=>I(r.Value),StringComparer.Ordinal)));
        static void FinishToAsk(RouteWorldController route,string ask)
        {
            for(int guard=0;guard<24&&route.Gameplay.DialogueOpen;guard++)
            {var dialogue=route.Gameplay.Dialogue;if(dialogue.Id==ask&&dialogue.ChoicesReady)return;if(dialogue.ChoicesReady)route.ChooseDialogue(0);else route.AdvanceDialogue();}
            throw new InvalidOperationException("Original Greta confirmation was not reached: "+ask+" / "+route.Gameplay.Dialogue?.Id);
        }
        public static IEnumerator Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route,Phase6Catalog catalog)
        {
            Last=new Result{identity=identity};var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool passed){if(checks.Any(c=>c.name==name))throw new InvalidOperationException("Duplicate progression check "+name);checks.Add(new Phase2Probe.Check{name=name,passed=passed});Last.checks=checks.ToArray();if(!passed)Debug.Log("Progression check failed: "+name);}
            var repository=FoundationWorldRepository.LoadRequired();ProgressionModelChecks.Verify(repository,Check);
            string root=PersistencePaths.Checked(Path.Combine(output,"progression-profiles"));if(Directory.Exists(root))throw new IOException("Progression synthetic profile must be fresh.");
            route.CloseModal();Fixture?.Dispose();Fixture=new PersistenceCoordinator(repository,world.InputSource,root);if(!route.BeginNew(Fixture))throw new IOException(Fixture.Status);
            var state=route.Gameplay.State;var model=route.Progression;
            Debug.Log("Progression stage: real native experience, coherent level rewards and unchanged combat stats");
            state.Set("hero_xp",I(0));state.Coins=0;long hp=state.Hp,maxHp=state.MaxHp;string weapon=state.Get("weapon").AsString();
            bool awarded=model.AddHeroXp(900);long coins=state.Coins;bool additional=model.AddHeroXp(1);
            Check("progression_native_xp_rewards_once",awarded&&additional&&model.Progress.Level==6&&model.Progress.XP==901&&coins==75&&state.Coins==75&&route.Message.Contains("6")&&hp==state.Hp&&maxHp==state.MaxHp&&state.Get("weapon").AsString()==weapon);
            route.Save();bool loaded=route.Reload(false);state=route.Gameplay.State;model=route.Progression;
            Check("progression_native_reload_does_not_reward_levels",loaded&&model.Progress.XP==901&&state.Coins==75);
            state.Set("hero_xp",I(0));state.Coins=0;state.Set("quests",P("{\"drank\":{\"state\":\"active\",\"step\":0},\"kat\":{\"state\":\"active\",\"step\":0}}"));
            bool q1=model.FinishQuest("drank"),q2=model.FinishQuest("kat");long questXp=model.Progress.XP,questCoins=state.Coins;string done=Json(state.Get("quests"));bool repeat=!model.FinishQuest("kat")&&!model.FinishQuest("drank");
            Check("progression_native_quest_xp_main_and_repeat",q1&&q2&&questXp==model.QuestXp("drank")+model.QuestXp("kat")&&questCoins==(ProgressionModel.LevelFor(questXp)-1)*15&&repeat&&model.Progress.XP==questXp&&state.Coins==questCoins&&Json(state.Get("quests"))==done);
            Travel(route,"arena");long beforeArena=model.Progress.XP,oldKills=state.Get("kills").AsInt64();bool arena=model.RegisterKill("slime");Travel(route,"village");long beforeEnemy=model.Progress.XP;bool enemy=model.RegisterKill("slime");
            Check("progression_native_arena_exclusion",arena&&enemy&&beforeArena==beforeEnemy&&model.Progress.XP==beforeEnemy+model.EnemyXp("slime")&&state.Get("kills").AsInt64()==oldKills+2);
            Debug.Log("Progression stage: all source gear drives the actual native player without stamina refills");
            Bag(state,model.Catalogs.Require("gear").Entries.Select(r=>new KeyValuePair<string,long>(r.Key.AsString(),1)));state.Set("equipment",P("{}"));world.RefreshRouteState();
            bool gearAll=true;int gearCount=0;foreach(var row in model.Catalogs.Require("gear").Entries)
            {string id=row.Key.AsString();world.Motor.Stamina.Stamina=7;route.UpdateInventoryContext();bool equip=model.Equip(id);gearAll&=equip&&model.Equipped(model.SlotOf(id))==id&&world.Motor.Stamina.Stamina==7&&world.Motor.Stamina.Capacity==100+model.Bonus("stamina_max")&&world.Motor.Stamina.RegenRate==25*(1+model.Bonus("stamina_regen"));gearCount++;}
            Check("progression_native_all_equipment_slots_apply",gearAll&&gearCount==24&&model.EquipmentSlotIds.Count==5);
            model.Equip("gear_bronze_helm");world.Motor.Stamina.Stamina=world.Motor.Stamina.Capacity;model.Unequip("head");
            bool capacityClamp=world.Motor.Stamina.Stamina==world.Motor.Stamina.Capacity;model.Equip("gear_bronze_helm");route.Inventory.Take("gear_bronze_helm",1);
            Check("progression_native_removed_gear_reconciles_capacity",capacityClamp&&model.Equipped("head")==""&&world.Motor.Stamina.Capacity==100+model.Bonus("stamina_max")&&world.Motor.Stamina.Stamina<=world.Motor.Stamina.Capacity);
            state.Set("equipment",P("{}"));world.RefreshRouteState();model.Equip("gear_pg_pack_plus");string resource=route.Gameplay.Resources.Entries.First().Key.AsString();double originalDuration=route.Gameplay.Resources.Require(resource).TryGet("duration",out var duration)?duration.AsDouble():.65;
            bool harvest=route.Gameplay.ResourceDuration(resource)==originalDuration*.75;model.Equip("gear_crystal_ring");At(world,route,new Vector2(770,624));var loot=route.SpawnLootPickup("prof_branch",world.Position+new Vector2(70,0));loot.Pickup.Age=.3;loot.Age=.3;Vector2 beforePull=loot.Position;route.Tick(.1);
            Check("progression_native_gather_and_magnet_bonuses",harvest&&Vector2.Distance(loot.Position,world.Position)<Vector2.Distance(beforePull,world.Position)&&route.Gameplay.Bonus("magnet_range")==24);
            string beforeBrowse=Json(state.Snapshot());foreach(var item in model.Catalogs.Require("gear").Entries){model.ComparisonText(item.Key.AsString());foreach(var cap in model.Catalogs.Require("bonusLimits").Entries)model.PreviewBonus(cap.Key.AsString(),item.Key.AsString());}route.OpenProgression("equipment");route.ProgressionPanel.SelectSlot(0);route.ProgressionPanel.Refresh();
            Check("progression_native_gear_browsing_pure",beforeBrowse==Json(state.Snapshot())&&state.Paused&&route.Modal=="progression");route.CloseModal();
            Debug.Log("Progression stage: actual original Greta dialogue and physically gated upgrades");
            var gretaMap=repository.MapIds.First(map=>repository.Read(map).Root.Require("scene").Items.Any(node=>node.TryGet("script",out var script)&&script.AsString().EndsWith("/npc.gd",StringComparison.Ordinal)&&node.Require("fields").TryGet("npc_id",out var id)&&id.AsString()=="greta"));
            Travel(route,gretaMap);var greta=route.Targets.First(t=>t.Kind=="npc"&&t.Id=="greta");At(world,route,greta.Position+new Vector2(0,28));
            state.Set("weapon",S("wood"));Bag(state,new[]{new KeyValuePair<string,long>("gel",13),new KeyValuePair<string,long>("shard",2)});state.Coins=120;
            bool talked=route.InteractTarget(greta.Address);FinishToAsk(route,"greta_iron_ask");route.ChooseDialogue(0);bool iron=state.Get("weapon").AsString()=="iron"&&state.Count("gel")==8&&state.Coins==80&&state.Count("sword_iron")==0;
            route.CloseModal();route.InteractTarget(greta.Address);FinishToAsk(route,"greta_crystal_ask");route.ChooseDialogue(0);bool crystal=state.Get("weapon").AsString()=="crystal"&&state.Count("gel")==0&&state.Count("shard")==0&&state.Coins==0&&state.Count("sword_crystal")==0;
            Check("progression_native_greta_original_dialogue_upgrades",talked&&iron&&crystal);
            route.CloseModal();state.Set("weapon",S("wood"));Bag(state,new[]{new KeyValuePair<string,long>("gel",5)});state.Coins=40;At(world,route,greta.Position+new Vector2(160,0));route.OpenProgression("upgrade");string remote=Json(state.Snapshot());bool remoteDenied=!model.UpgradeWeapon("iron")&&remote==Json(state.Snapshot());route.CloseModal();At(world,route,greta.Position+new Vector2(0,28));route.OpenProgression("upgrade");bool localUpgrade=model.UpgradeWeapon("iron");long spent=state.Coins;bool noRepeat=!model.UpgradeWeapon("iron");state.Set("weapon",S("crystal"));bool noStar=!model.UpgradeWeapon("star");
            Check("progression_native_forge_proximity_and_no_free_star",remoteDenied&&localUpgrade&&state.Count("gel")==0&&spent==0&&noRepeat&&noStar&&state.Get("weapon").AsString()=="crystal");
            route.CloseModal();state.Set("weapon",S("wood"));Bag(state,new[]{new KeyValuePair<string,long>("gel",5)});state.Coins=40;route.InteractTarget(greta.Address);FinishToAsk(route,"greta_iron_ask");route.Inventory.Take("gel",1);string missing=Json(state.Snapshot());bool denied=!route.Gameplay.Choose(0);
            Check("progression_native_forge_rechecks_complete_cost",denied&&missing==Json(state.Snapshot())&&state.Get("weapon").AsString()=="wood");route.CloseModal();
            Debug.Log("Progression stage: three original gear upgrades and worn replacement in the actual world");
            bool allUpgrades=true,locked=true;int upgrades=0;
            foreach(var row in model.Catalogs.Require("upgradeRecipes").Entries)
            {
                string id=row.Key.AsString();var recipe=row.Value;string station=recipe.TryGet("station",out var st)?st.AsString():"village";Travel(route,station);string flag=recipe.Require("unlock").AsString();state.SetFlag(flag,false);state.Set("equipment",P("{}"));state.Set("clothing",P("{}"));Bag(state,recipe.Require("inputs").Entries.Select(input=>new KeyValuePair<string,long>(input.Key.AsString(),input.Value.AsInt64())));
                var prof=state.Get("professions");prof=InventoryModel.Replace(prof,"xp",InventoryModel.Replace(InventoryModel.Get(prof,"xp",P("{}")),recipe.Require("skill").AsString(),I(30)));prof=InventoryModel.Replace(prof,"cooldowns",InventoryModel.Get(prof,"cooldowns",P("{}")));state.Set("professions",prof);route.UpdateProgressionContext();string beforeLocked=Json(state.Snapshot());locked&=!model.UpgradeGear(id)&&beforeLocked==Json(state.Snapshot());state.SetFlag(flag,true);string old=recipe.Require("upgrade_from").AsString(),outputId=recipe.Require("output").AsString();model.Equip(old);bool made=model.UpgradeGear(id);Debug.Log("Native gear upgrade "+id+": made="+made+" message="+model.LastMessage+" old="+state.Count(old)+" output="+state.Count(outputId)+" worn="+model.Equipped(model.SlotOf(outputId))+" capacity="+world.Motor.Stamina.Capacity);allUpgrades&=made&&state.Count(old)==0&&state.Count(outputId)==1&&model.Equipped(model.SlotOf(outputId))==outputId&&world.Motor.Stamina.Capacity==100+model.Bonus("stamina_max");upgrades++;
            }
            Check("progression_native_source_gear_upgrades",allUpgrades&&locked&&upgrades==3);
            Debug.Log("Progression stage: all original hair and clothing layers are visible and cosmetic");
            Travel(route,"village");Bag(state,model.Catalogs.Require("clothing").Entries.Select(row=>new KeyValuePair<string,long>(row.Key.AsString(),1)).Concat(model.Catalogs.Require("gear").Entries.Select(row=>new KeyValuePair<string,long>(row.Key.AsString(),1))));state.Set("equipment",P("{}"));state.Set("clothing",P("{}"));world.RefreshRouteState();long cosmeticHp=state.Hp,cosmeticMax=state.MaxHp;string cosmeticWeapon=state.Get("weapon").AsString();bool hairAll=true,clothesAll=true;int hairstyles=0,garments=0;
            foreach(string gender in model.GenderIds){model.SetGender(gender);foreach(string hair in model.HairIds(gender)){model.SetHair(hair);foreach(string row in new[]{"down","up","left","right"})hairAll&=world.AvatarLayers(row).Any(layer=>layer.Id=="hair:"+hair+":"+row)&&catalog.GetSprite("hair:"+hair+":"+row)!=null;hairstyles++;}}
            foreach(var row in model.Catalogs.Require("clothing").Entries){string id=row.Key.AsString();clothesAll&=model.Wear(id);foreach(string direction in new[]{"down","up","left","right"})foreach(string pose in new[]{"idle","step1","step2"})clothesAll&=world.AvatarLayers(direction,pose).Any(layer=>layer.Id.StartsWith("clothes:"+id+":"+direction+":",StringComparison.Ordinal))&&world.AvatarLayers(direction,pose).All(layer=>catalog.GetSprite(layer.Id)!=null);garments++;}
            Check("progression_native_all_hair_and_clothing_layers",hairAll&&clothesAll&&hairstyles==90&&garments==24);
            bool cosmetic=state.Hp==cosmeticHp&&state.MaxHp==cosmeticMax&&state.Get("weapon").AsString()==cosmeticWeapon&&model.Catalogs.Require("bonusLimits").Entries.All(row=>model.Bonus(row.Key.AsString())==0);model.SetEyes(model.EyeIds.Last());model.SetEyeColor(11);model.SetHairColor(15);foreach(string slot in model.ClothingSlotIds)if(model.Worn(slot).Entries.Count>0)model.Dye(slot,19);
            var visual=world.AvatarLayers("down");bool dyes=visual.Any(layer=>layer.Id.StartsWith("generated:eyes:",StringComparison.Ordinal))&&visual.Any(layer=>layer.Id.StartsWith("hair:",StringComparison.Ordinal));model.Wear("cloth_cape");model.Wear("cloth_tunic");model.Wear("cloth_straw_hat");model.Equip("gear_iron_armor");model.Equip("gear_bronze_helm");visual=world.AvatarLayers("down");
            bool occlusion=visual.Any(layer=>layer.Id=="clothes:cloth_cape:down:idle"&&layer.Depth<0)&&!visual.Any(layer=>layer.Id.StartsWith("clothes:gear_chest:",StringComparison.Ordinal)||layer.Id.StartsWith("clothes:gear_helmet:",StringComparison.Ordinal))&&visual.Last().Id=="clothes:cloth_straw_hat:down:idle";
            var retainedGear=state.Get("equipment");var retainedClothes=state.Get("clothing");state.Set("clothing",P("{}"));state.Set("equipment",P("{\"head\":\"unowned_hat\",\"chest\":\"gear_bronze_helm\"}"));
            bool staleHidden=!world.AvatarLayers("down").Any(layer=>layer.Id.StartsWith("clothes:gear_",StringComparison.Ordinal));state.Set("equipment",retainedGear);state.Set("clothing",retainedClothes);world.RefreshRouteState();
            Check("progression_native_cosmetic_stats_and_shared_layer_order",cosmetic&&dyes&&occlusion&&staleHidden);
            var unknown=P("{\"count\":9007199254740993,\"future\":[null,true,\"🌱\"]}");state.Set("future_progression",unknown);state.Set("appearance",InventoryModel.Replace(state.Get("appearance"),"future_palette",unknown));model.SetHairColor(4);string appearance=Json(state.Get("appearance")),clothing=Json(state.Get("clothing")),equipment=Json(state.Get("equipment"));long savedXp=model.Progress.XP,savedCoins=state.Coins;route.Save();state.Set("equipment",P("{}"));world.RefreshRouteState();bool oldCapacity=world.Motor.Stamina.Capacity==100;bool reload=route.Reload(false);state=route.Gameplay.State;model=route.Progression;
            Check("progression_native_save_reload_preserves_selections",reload&&oldCapacity&&world.Motor.Stamina.Capacity==130&&world.Motor.Stamina.Stamina==130&&appearance==Json(state.Get("appearance"))&&clothing==Json(state.Get("clothing"))&&equipment==Json(state.Get("equipment"))&&model.Progress.XP==savedXp&&state.Coins==savedCoins&&state.Get("future_progression").Require("count").AsInt64()==9007199254740993L&&state.Get("appearance").Require("future_palette").Require("future").Items[2].AsString()=="🌱");
            Debug.Log("Progression stage: real native input, character menus and screenshots");
            yield return ProgressionUiProbeRunner.Run(identity,output,world,route,catalog,Check);
            route.CloseModal();route.Save();Check("progression_no_real_saves_accessed",PersistencePaths.Within(PersistencePaths.Checked(output),root)&&!PersistencePaths.Within(PersistencePaths.LegacyDefault,root)&&!PersistencePaths.Within(PersistencePaths.UnityDefault,root)&&Fixture.Current.Snapshot.CopyOriginals().Count==0);
            Check("progression_native_checks_ran",route.Running&&world.RouteMode&&ProgressionModelChecks.OracleCases==model.Oracle.Require("cases").Items.Count&&ProgressionModelChecks.OracleCases>=407&&checks.Count>=20);
            Last.success=checks.All(c=>c.passed);Last.checks=checks.ToArray();File.WriteAllText(Path.Combine(output,"progression-result.json"),JsonUtility.ToJson(Last,true));Debug.Log("Progression native proof: "+checks.Count+" checks / "+ProgressionModelChecks.OracleCases+" exact original cases");
        }
    }
}
