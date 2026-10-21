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
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
namespace BlueMapMigration.Combat
{
    /// <summary>Actual native combat, collision, saving and device paths. Every profile and actor fixture is synthetic.</summary>
    public static class CombatProbeRunner
    {
        [Serializable] public sealed class Result{public int schemaVersion=1;public bool success,gameSaveAccessed=false;public BuildIdentity identity;public Phase2Probe.Check[] checks=Array.Empty<Phase2Probe.Check>();}
        public static Result Last {get;private set;}
        public static PersistenceCoordinator Fixture {get;private set;}
        static FoundationValue I(long n)=>FoundationValue.Integer(n);
        static FoundationValue P(string json)=>FoundationJson.ParsePlain(json);
        static string Json(FoundationValue v)=>FoundationJson.StringifyPlain(v);
        static string Spawn(FoundationWorldSnapshot map)=>map.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name??map.Arrivals[0].Name;
        public static IEnumerator Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route,Phase6Catalog catalog)
        {
            Last=new Result{identity=identity};var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool ok){if(checks.Any(c=>c.name==name))throw new InvalidOperationException("Duplicate combat check "+name);checks.Add(new Phase2Probe.Check{name=name,passed=ok});Last.checks=checks.ToArray();if(!ok)Debug.Log("Combat check failed: "+name);}
            var repository=FoundationWorldRepository.LoadRequired();CombatModelChecks.Verify(repository,Check);EncounterModelChecks.Verify(repository,catalog,Check);
            string root=PersistencePaths.Checked(Path.Combine(output,"combat-profiles"));if(Directory.Exists(root))throw new IOException("Fresh combat profile is required.");
            route.CloseModal();Fixture=new PersistenceCoordinator(repository,world.InputSource,root);if(!route.BeginNew(Fixture))throw new IOException(Fixture.Status);route.CombatSimulationEnabled=true;
            var state=route.Gameplay.State;var combat=route.Combat;
            void Travel(string map){route.CloseModal();if(!route.TryTravel(map,Spawn(repository.Read(map))))throw new InvalidOperationException("Combat travel failed: "+map);combat=route.Combat;state=route.Gameplay.State;}
            Vector2 ClearSpot()
            {for(int y=4;y<route.Session.Current.Height-4;y++)for(int x=4;x<route.Session.Current.Width-4;x++){Vector2 p=new Vector2(x*32+16,y*32+16);if(route.Access.SpawnFits(route.Session.Current,p)&&new[]{new Vector2(0,32),new Vector2(32,0),new Vector2(-32,0),new Vector2(0,-32),new Vector2(65,0),new Vector2(120,0)}.All(d=>route.Access.SpawnFits(route.Session.Current,p+d))&&new[]{0f,4f,8f}.All(yOffset=>world.CombatClearLine(p+new Vector2(0,yOffset),p+new Vector2(150,yOffset),true)))return p;}return world.Position;}
            void At(Vector2 p){world.Teleport(p);combat.Player.Position=p;combat.Player.AimDirection=Vector2.right;world.Aim.Update(p,Vector2.right,Vector2.zero,Vector2.zero,false,true,p+Vector2.right*90,false);world.Step(0,new MotionInput());world.FocusCameraOnPlayer();}
            void Reset(){combat.ResetTransient();world.Motor.RollCooldown=0;world.Motor.Stamina.Reset();state.Hp=state.MaxHp;foreach(var a in route.Encounter.Actors)a.Finished=true;foreach(var projectile in route.Encounter.Projectiles)projectile.Dead=true;}
            EncounterActor Target(string kind,Vector2 at){var a=route.Encounter.Spawn(kind,at);a.StateTime=0;return a;}
            void Step(double dt){world.Step(dt,new MotionInput{Direction=Vector2.zero,Locked=state.InputLocked,Paused=state.Paused});route.Tick(dt);}
            void Capture(string name){var image=ScreenCapture.CaptureScreenshotAsTexture();try{File.WriteAllBytes(Path.Combine(output,"screenshot-combat-"+name+".png"),image.EncodeToPNG());}finally{UnityEngine.Object.Destroy(image);}}
            Check("combat_shared_state_motor_energy",ReferenceEquals(combat.State,state)&&ReferenceEquals(combat.Inventory,route.Inventory)&&ReferenceEquals(combat.Progression,route.Progression)&&ReferenceEquals(combat.Motor,world.Motor)&&ReferenceEquals(combat.Movement,world.Motor.Stamina));
            Travel("forest");Reset();Vector2 center=ClearSpot();At(center);
            var enemy=Target("slime",center+Vector2.right*25);int oldHp=enemy.Hp;bool attacked=combat.Attack();
            Check("combat_native_melee_hits_actual_actor",attacked&&enemy.Hp==oldHp-combat.Damage&&combat.Player.AttackTimer==.18);
            combat.Player.Cooldown=0;combat.Attack();combat.Player.Cooldown=0;double energy=world.Motor.Stamina.Stamina;combat.Attack();
            Check("combat_native_combo_spends_shared_stamina",combat.Player.ComboStep==3&&combat.Player.ComboSweep&&world.Motor.Stamina.Stamina==energy-18);
            Reset();At(center);combat.Player.AimDirection=Vector2.right;var facingBefore=world.Motor.Facing;world.Step(.02,new MotionInput{Direction=Vector2.up});
            Check("combat_native_facing_follows_movement",world.Motor.Facing==Vector2.up&&world.Aim.Direction==Vector2.right);
            Reset();At(center);double before=world.Motor.Stamina.Stamina;bool prepared=combat.BeginTechnique(false);world.Step(.02,new MotionInput{Direction=Vector2.right,SprintHeld=true});
            Check("combat_native_technique_slows_and_blocks_sprint",prepared&&combat.Player.Phase=="prepare"&&!world.Motor.Sprinting&&world.Motor.Velocity.magnitude<50&&world.Motor.Stamina.Stamina<before);
            combat.Player.Cooldown=.25;combat.Player.Invulnerable=.6;combat.Player.ComboWindow=.7;world.Motor.RollCooldown=.4;bool retained=route.TryTravel(state.MapId,state.SpawnName,true)&&combat.Player.Phase=="prepare"&&combat.Player.Cooldown==.25&&world.Motor.RollCooldown==.4&&world.Aim.Direction==Vector2.right;route.OpenInventory();world.Step(1,new MotionInput{Paused=true,Locked=true});route.Tick(1);bool cancel=retained&&combat.Player.Phase==""&&combat.Player.Cooldown==.25&&combat.Player.Invulnerable==.6&&combat.Player.ComboWindow==.7;route.CloseModal();Check("combat_native_menu_cancels_preparation",cancel);
            Reset();At(center);combat.BeginTechnique(false);bool rolled=world.Roll(Vector2.right);long hp=state.Hp;bool safe=!combat.Hurt(center-Vector2.right*20,2,"synthetic roll");
            Check("combat_native_roll_cancels_and_protects",rolled&&combat.Player.Phase==""&&safe&&state.Hp==hp);
            var toolResource=route.Gameplay.Resources.Entries.First(e=>e.Value.TryGet("tools",out var tools)&&tools.Items.Count>0&&(!e.Value.TryGet("level",out var level)||level.AsInt64()<=1));state.Set("inventory",P("{}"));string toolId=toolResource.Value.Require("tools").Items.Last().AsString();bool toolDenied=route.Gameplay.ResourceReason(toolResource.Key.AsString(),"combat-tool-proof").StartsWith("Nodig:",StringComparison.Ordinal);state.Set("inventory",FoundationValue.Object(new Dictionary<string,FoundationValue>{{toolId,I(1)}}));
            Check("combat_native_existing_tool_requirements",toolDenied&&route.Gameplay.ResourceReason(toolResource.Key.AsString(),"combat-tool-proof")=="");
            Reset();At(center);state.Set("equipment",P("{}"));hp=state.Hp;bool hurt=combat.Hurt(center-Vector2.right*20,2,"synthetic hit"),again=combat.Hurt(center,2,"synthetic hit");
            Check("combat_native_hurt_invulnerability_knockback",hurt&&!again&&state.Hp==hp-2&&combat.Player.Invulnerable==1&&world.Motor.Knockback.x>0);
            Reset();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":40,\"potion\":2}"));var arrowTarget=Target("slime",center+Vector2.right*65);oldHp=arrowTarget.Hp;long arrows=state.Count("arrow");bool shot=combat.Shoot();for(int i=0;i<12;i++)Step(1.0/60);
            Check("combat_native_bow_consumes_one_hits_monster",shot&&state.Count("arrow")==arrows-1&&arrowTarget.Hp<oldHp);
            Reset();At(center);state.Set("inventory",P("{\"bow\":1}"));int projectileCount=route.Encounter.Projectiles.Count;bool empty=!combat.Shoot();Check("combat_native_empty_quiver_no_free_projectile",empty&&route.Encounter.Projectiles.Count==projectileCount&&state.Count("arrow")==0);
            // Real Unity collision obstruction, not an injected model answer.
            Reset();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":40}"));var blocker=new GameObject("Synthetic source static cover");blocker.transform.position=FoundationCoordinates.ToUnity(center+Vector2.right*32);FoundationCollision.Box(blocker,new Rect(-4,-20,8,40),1,1);Physics2D.SyncTransforms();
            var covered=Target("slime",center+Vector2.right*55);int coveredHp=covered.Hp;combat.Shoot();for(int i=0;i<10;i++)Step(1.0/60);
            Check("combat_native_cover_precedes_arrow_target",covered.Hp==coveredHp&&route.Encounter.Projectiles.Any(p=>p.PlayerOwned&&p.State=="stuck"));blocker.SetActive(false);UnityEngine.Object.Destroy(blocker);
            Reset();At(center);var orb=route.Encounter.SpawnProjectile("arcane_orb",center+Vector2.right*20,Vector2.left,90,1,"Synthetic orb");combat.Attack();Check("combat_native_sword_shatters_hostile_projectile",orb.Dead);
            bool foundWater=false,waterPass=false;foreach(var cell in route.Session.Current.TerrainCells){Vector2 point=new Vector2(cell.X*32+16,cell.Y*32+16);if(world.TileAt(point)=="water"&&world.TileAt(point+Vector2.right*32)=="water"){foundWater=true;waterPass=world.CombatClearLine(point,point+Vector2.right*32,true)&&!world.CombatClearLine(point,point+Vector2.right*32);if(waterPass)break;}}
            Check("combat_native_arrows_fly_over_original_water",foundWater&&waterPass);
            Reset();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":40}"));combat.BeginTechnique(true);long held=state.Count("arrow");route.OpenPause();route.Tick(.8);route.CloseModal();
            Check("combat_native_cancelled_bow_keeps_ammunition",held==state.Count("arrow")&&combat.Player.Phase=="");
            // Every original loaded placement comes from retained scene documents; no crowding is added.
            int actorCount=0;bool allMaps=true;var kinds=new HashSet<string>();foreach(string map in RouteWorldController.Maps){Travel(map);actorCount+=route.Encounter.Actors.Count;foreach(var a in route.Encounter.Actors){kinds.Add(a.Kind);allMaps&=a.SourceNode!=null&&a.Home==FoundationCoordinates.Vector(a.SourceNode.Require("globalTransform").Require("origin"));}yield return null;}
            Check("combat_native_all_maps_original_placements",allMaps&&actorCount>100&&kinds.Count>15);
            Travel("forest");Reset();center=ClearSpot();At(center);var animalKind=combat.Catalogs.Require("enemies").Entries.First(e=>e.Value.TryGet("behavior",out var b)&&b.AsString()=="animal").Key.AsString();var animal=Target(animalKind,center+Vector2.right*18);hp=state.Hp;route.Tick(.1);
            Check("combat_native_peaceful_wildlife_no_contact_damage",state.Hp==hp&&!animal.Dead&&animal.Behavior=="animal");
            Reset();At(center);long kills=state.Get("kills").AsInt64();long xp=route.Progression.Progress.XP;enemy=Target("slime",center+Vector2.right*25);route.Encounter.HurtActor(enemy,enemy.Hp,Vector2.right);route.Encounter.HurtActor(enemy,999,Vector2.right);
            Check("combat_native_defeat_rewards_once",state.Get("kills").AsInt64()==kills+1&&route.Progression.Progress.XP==xp+route.Progression.EnemyXp("slime"));
            Travel("watchyard");Reset();var post=route.Targets.First(t=>t.Kind=="combat_post"&&BlueMapMigration.WorldAccess.WorldAccessModel.Get(t.Fields.Require("obj"),"kind",FoundationValue.StringValue("")).AsString()!="rack"&&BlueMapMigration.WorldAccess.WorldAccessModel.Get(t.Fields.Require("obj"),"kind",FoundationValue.StringValue("")).AsString()!="entrance");At(post.Position+new Vector2(0,24));bool instructions=route.InteractTarget(post.Address)&&route.Gameplay.DialogueOpen;route.CloseModal();bool started=route.InteractTarget(post.Address);route.Tick(2.6);var practices=route.Encounter.Actors.Where(a=>a.Practice).ToArray();long trainingXp=route.Progression.Progress.XP,trainingKills=state.Get("kills").AsInt64();foreach(var a in practices)route.Encounter.HurtActor(a,a.Hp,Vector2.right);route.Tick(.01);
            Check("combat_native_training_no_loot_or_xp",instructions&&started&&practices.Length==1&&!route.PracticeRunning&&route.Progression.Progress.XP==trainingXp&&state.Get("kills").AsInt64()==trainingKills);Travel("forest");Reset();center=ClearSpot();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":40}"));
            // Actual native keyboard and controller events enter the real route action handler.
            var oldMode=InputSystem.settings.updateMode;var devices=new List<InputDevice>();PlayerInputSource source=null;
            try
            {
                InputSystem.settings.updateMode=InputSettings.UpdateMode.ProcessEventsManually;var keyboard=InputSystem.AddDevice<Keyboard>("Combat keyboard");var mouse=InputSystem.AddDevice<Mouse>("Combat mouse");var pad=InputSystem.AddDevice<Gamepad>("Combat controller");devices.AddRange(new InputDevice[]{keyboard,mouse,pad});source=new PlayerInputSource(devices);source.SetFocused(true);
                InputFrame Sample(KeyboardState keys,GamepadState gamepad,Vector2 pointer)
                {InputSystem.QueueStateEvent(keyboard,keys);InputSystem.QueueStateEvent(mouse,new MouseState{position=pointer});InputSystem.QueueStateEvent(pad,gamepad);InputSystem.Update();source.SetContext(true,state.InputLocked);var frame=source.Read();route.HandleFrame(frame);return frame;}
                Reset();At(center);Sample(new KeyboardState(),new GamepadState(),new Vector2(500,350));var key=Sample(new KeyboardState(Key.J),new GamepadState(),new Vector2(500,350));bool keyboardSword=key.Pressed("attack")&&combat.Player.AttackTimer>0;
                Sample(new KeyboardState(),new GamepadState(),new Vector2(500,350));Reset();var bowPad=Sample(new KeyboardState(),new GamepadState{rightTrigger=1},new Vector2(500,350));
                Check("combat_native_keyboard_and_controller_actions",keyboardSword&&bowPad.ControllerActive&&bowPad.Pressed("bow")&&combat.Player.BowAnim>0);
                Sample(new KeyboardState(),new GamepadState(),new Vector2(500,350));Reset();var technique=Sample(new KeyboardState(),new GamepadState{leftTrigger=1}.WithButton(GamepadButton.West),new Vector2(500,350));
                Check("combat_native_controller_technique_modifier",technique.Held("technique")&&technique.Pressed("attack")&&combat.Player.Phase=="prepare");
                Sample(new KeyboardState(),new GamepadState{leftTrigger=1},new Vector2(500,350));var switched=Sample(new KeyboardState(Key.J),new GamepadState{leftTrigger=1},new Vector2(530,350));Check("combat_native_devices_remain_exclusive",!switched.ControllerActive&&!switched.Held("technique"));
            }
            finally{source?.Dispose();foreach(var d in devices)if(d.added)InputSystem.RemoveDevice(d);InputSystem.settings.updateMode=oldMode;}
            // Death writes counters only into the last safe revision; retry never commits unsaved dead possessions.
            Reset();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":20,\"gel\":4}"));state.Coins=123;state.Set("future_combat",P("{\"exact\":9007199254740993,\"kept\":[true,null,\"🌊\"]}"));route.Save();var safeSave=Fixture.Current.Snapshot.State;long savedDeaths=state.Get("deaths").AsInt64();state.Coins=999;state.Hp=1;combat.Hurt(center-Vector2.right*30,99,"Synthetic defeat");var saved=Fixture.Current.Snapshot.State;
            Check("combat_native_death_keeps_last_safe_inventory",state.Ended&&route.Modal=="defeat"&&saved.Require("hp").AsInt64()==safeSave.Require("hp").AsInt64()&&saved.Require("coins").AsInt64()==123&&Json(saved.Require("inventory"))==Json(safeSave.Require("inventory"))&&saved.Require("deaths").AsInt64()==savedDeaths+1&&!route.Save());
            bool retry=route.RetryAfterDefeat();state=route.Gameplay.State;combat=route.Combat;
            Check("combat_native_retry_heals_retains_unknowns",retry&&!state.Ended&&state.Hp==state.MaxHp&&state.Coins==123&&state.Get("future_combat").Require("exact").AsInt64()==9007199254740993L&&state.Get("deaths").AsInt64()==savedDeaths+1);
            // The original trigger and dialogue start a boss; its real vulnerable phases and delayed reward are retained.
            Travel("depths2");state.SetFlag("guardian_started",false);state.SetFlag("guardian_defeated",false);world.Teleport(new Vector2(13*32+16,16*32+16));route.Tick(0);
            Check("combat_native_guardian_source_intro",state.Flag("guardian_started")&&route.Gameplay.Dialogue?.Id=="guardian_intro");route.CloseModal();combat.Player.Invulnerable=100;route.Tick(.01);var guardian=route.Encounter.Actors.First(a=>a.Kind=="guardian");route.Tick(1.9);bool awakened=guardian.Active&&guardian.State!="waking";
            guardian.State="idle";route.Encounter.HurtActor(guardian,Mathf.CeilToInt(guardian.MaxHp*.35f),Vector2.right);bool phase2=guardian.State=="phase_shift"&&guardian.ShiftTo==2;route.Tick(1.9);bool shifted=guardian.Phase==2;
            guardian.State="idle";route.Encounter.HurtActor(guardian,guardian.Hp,Vector2.right);long oldCoins=state.Coins;bool delayed=!state.Flag("guardian_defeated");route.Tick(2.9);
            Check("combat_native_guardian_phases_delayed_reward",awakened&&phase2&&shifted&&delayed&&state.Flag("guardian_defeated")&&state.Coins>=oldCoins+500&&state.Get("weapon").AsString()=="star");
            long rewarded=state.Coins;bool duplicate=!combat.CompleteGuardianReward(true);Check("combat_native_guardian_reward_once",duplicate&&rewarded==state.Coins);
            route.Tick(0);route.CloseModal();Check("combat_native_guardian_reward_chest_exists",route.Targets.Any(t=>t.Kind=="chest"&&t.UniqueKey=="chest:depths2:heart"));
            Travel("temple");state.SetFlag("boss_started",false);state.SetFlag("boss_defeated",false);state.SetFlag("game_completed",false);world.Teleport(new Vector2(10*32+16,12*32+16));route.Tick(0);bool kingIntro=route.Gameplay.Dialogue?.Id=="king_intro";route.CloseModal();combat.Player.Invulnerable=100;route.Tick(.02);var king=route.Encounter.Actors.First(a=>a.Kind=="king");king.State="idle";route.Encounter.HurtActor(king,king.Hp,Vector2.right);route.Tick(1.7);
            Check("combat_native_king_victory_saves_safe_village",kingIntro&&state.Flag("boss_defeated")&&state.Flag("game_completed")&&state.MapId=="village"&&route.Modal=="victory"&&Fixture.Current.Snapshot.State.Require("map").AsString()=="village");route.CloseModal();
            Travel("village");Check("combat_native_towns_keep_source_enemy_population",route.Encounter.Actors.Count==0);
            // Screens are ordinary rendered source terrain and native actors, with the active game's real HUD.
            Travel("forest");Reset();route.ItemNotices.Clear();route.ShowMessage("");center=ClearSpot();At(center);state.Set("inventory",P("{\"bow\":1,\"arrow\":40}"));state.Set("weapon",FoundationValue.StringValue("iron"));enemy=Target("slime",center+new Vector2(30,6));enemy.MaxHp=enemy.Hp=20;combat.Attack();world.UpdateAppearance();route.Tick(0);yield return new WaitForEndOfFrame();Capture("melee");
            Reset();At(center);Target("slime",center+new Vector2(120,0));combat.Shoot();world.UpdateAppearance();route.Tick(.05);yield return new WaitForEndOfFrame();Capture("bow");
            state.SetFlag("guardian_defeated",false);state.SetFlag("guardian_started",true);Travel("depths2");Reset();route.ShowMessage("");guardian=route.Encounter.Actors.First(a=>a.Kind=="guardian"&&a.SourceNode!=null);guardian.Finished=false;guardian.Dead=false;guardian.Active=true;Vector2 stand=guardian.Home+new Vector2(-120,0);At(route.Access.ResolveArrival(route.Session.Current,stand));guardian.State="charge_windup";guardian.StateTime=.2;guardian.Aim=(world.Position-guardian.Position).normalized;route.Tick(.1);yield return new WaitForEndOfFrame();Capture("monsters");
            Travel("forest_edge");Reset();route.ShowMessage("");center=ClearSpot();At(center);Target(animalKind,center+new Vector2(55,20));route.Tick(.1);yield return new WaitForEndOfFrame();Capture("wildlife");
            Check("combat_native_four_rendered_captures",new[]{"melee","bow","monsters","wildlife"}.All(n=>File.Exists(Path.Combine(output,"screenshot-combat-"+n+".png"))));
            Check("combat_no_personal_saves_used",Fixture.Current.Snapshot.CopyOriginals().Count==0&&PersistencePaths.Within(PersistencePaths.Checked(output),root)&&!PersistencePaths.Within(PersistencePaths.UnityDefault,root)&&!PersistencePaths.Within(PersistencePaths.LegacyDefault,root));
            route.CloseModal();route.CombatSimulationEnabled=false;route.Save();Last.success=checks.All(c=>c.passed);Last.checks=checks.ToArray();File.WriteAllText(Path.Combine(output,"combat-result.json"),JsonUtility.ToJson(Last,true));Debug.Log("Combat native proof: "+checks.Count+" checks");
        }
    }
}
