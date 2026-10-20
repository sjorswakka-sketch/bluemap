using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.Probe;
using UnityEngine;
namespace BlueMapMigration.Player
{
    [Serializable] public sealed class PlayerProof
    {
        public int schemaVersion=1;public bool success;public Phase2Probe.Check[] checks;
        public bool gameSaveAccessed=false;public BuildIdentity identity;
    }
    public static class PlayerProbeRunner
    {
        public static PlayerProof Run(BuildIdentity identity,PlayerWorld world)
        {
            var checks=new List<Phase2Probe.Check>();
            Action<string,bool> check=(name,passed)=>
            {
                if(checks.Any(c=>c.name==name))throw new InvalidOperationException("Duplicate player check: "+name);
                checks.Add(new Phase2Probe.Check{name=name,passed=passed});
            };
            Group("motion",PlayerMotionChecks.Verify,check);
            Group("input",PlayerInputChecks.Verify,check);
            bool oracle=false;
            try
            {
                var source=Resources.Load<TextAsset>("BlueMapPlayerMotionOracle");
                if(source==null)throw new FormatException("Missing source motion oracle");
                int before=checks.Count;
                PlayerMotionChecks.VerifyOracle(FoundationJson.Parse(source.text),check);
                oracle=checks.Count-before==6 && checks.Skip(before).All(c=>c.passed);
            }
            catch(Exception error){Debug.LogWarning("Player source oracle: "+error);}
            check("player_motion_oracle_complete",oracle);
            check("player_input_oracle_complete",checks.Any(c=>c.name=="player_input_all_36_source_actions_native_bindings"&&c.passed)
                && checks.Any(c=>c.name=="player_input_16_original_circular_deadzone_vectors"&&c.passed));
            Group("world",c=>PlayerWorldChecks.Verify(world,c),check);
            return new PlayerProof{identity=identity,checks=checks.ToArray(),success=checks.Count>40&&checks.All(c=>c.passed)};
        }
        private static void Group(string group,Action<Action<string,bool>> run,Action<string,bool> check)
        {
            bool ran=false;try{run(check);ran=true;}catch(Exception error){Debug.LogWarning("Player "+group+": "+error);}
            check("player_"+group+"_checks_ran",ran);
        }
    }
    public static class PlayerWorldChecks
    {
        public static void Verify(PlayerWorld world,Action<string,bool> check)
        {
            check("player_world_original_terrain_complete",world.Snapshot.TerrainCells.Count==world.Snapshot.Width*world.Snapshot.Height);
            check("player_world_source_collision",world.SourceTileColliders>100&&world.SourceObjectColliders>10);
            check("player_world_source_foot_shape",world.Foot.radius==7f/32 && world.Foot.offset==new Vector2(0,-8f/32)
                && world.Body.bodyType==RigidbodyType2D.Kinematic);
            Vector2 saved=world.Position;
            // Real Box2D sweeps against isolated source-shaped obstacles. Far outside
            // all maps, so no unrelated object or renderer can affect the outcome.
            var wall=new GameObject("Player swept-shape wall witness");wall.transform.position=FoundationCoordinates.ToUnity(new Vector2(-1000,-1000));
            try
            {
                FoundationCollision.Box(wall,new Rect(0,-100,32,200),1,0);
                world.Teleport(new Vector2(-1040,-1008));
                Vector2 blocked=world.Sweep(new Vector2(100,0));
                check("player_world_sweep_stops_before_solid",blocked.x<=-1006.9f && blocked.x>-1040 && Math.Abs(blocked.y+1008)<.01);
                world.Teleport(new Vector2(-1040,-1008));Vector2 slide=world.Sweep(new Vector2(100,50));
                check("player_world_sweep_slides_along_wall",slide.x<=-1006.9f && slide.y>-978.1f);
                world.Teleport(new Vector2(-1040,-1008));world.Motor.Stamina.Reset();
                world.Sweep(new Vector2(100,0));double before=world.Motor.Stamina.Stamina;
                for(int i=0;i<10;i++)world.Step(1.0/60,new MotionInput{Direction=Vector2.right,SprintHeld=true});
                check("player_world_blocked_running_preserves_stamina",world.Motor.Stamina.Stamina==before&&!world.Motor.Sprinting);
                world.Teleport(new Vector2(-1100,-1300));Vector2 clear=world.Sweep(new Vector2(32,0));
                check("player_world_free_movement_no_grid_snap",Math.Abs(clear.x+1068)<.01&&Math.Abs(clear.y+1300)<.01);
                world.Motor.Stamina.Reset();world.Step(.2,new MotionInput{Direction=Vector2.right,SprintHeld=true});
                check("player_world_running_available_immediately",world.Motor.Sprinting&&world.Motor.Stamina.Stamina==96);
                world.Motor.AimDirection=Vector2.left;world.Step(.1,new MotionInput{Direction=Vector2.right});world.UpdateAppearance();
                check("player_body_faces_movement",world.Motor.Facing==Vector2.right&&world.DirectionRow=="right"&&world.Motor.AimDirection==Vector2.left);
                Vector2 pausedAt=world.Position;double staminaAt=world.Motor.Stamina.Stamina;
                world.Step(3,new MotionInput{Direction=Vector2.right,SprintHeld=true,Paused=true});
                check("player_world_pause_stops_motion",world.Position==pausedAt&&world.Motor.Stamina.Stamina==staminaAt);
                world.Motor.RollCooldown=0;world.Motor.TryRoll(Vector2.right);world.Teleport(saved);
                check("player_world_teleport_cancels_roll_keeps_energy",!world.Motor.IsRolling&&world.Motor.Stamina.Stamina==staminaAt);
            }
            finally{wall.SetActive(false);UnityEngine.Object.Destroy(wall);world.Teleport(saved);}
            var aim=new PlayerAimModel();
            aim.Update(Vector2.zero,Vector2.right,Vector2.right,Vector2.left,true,false,Vector2.zero,false);
            check("player_aim_independent",aim.Direction==Vector2.left&&aim.Position==new Vector2(-90,0));
            aim.Update(Vector2.zero,Vector2.right,Vector2.zero,Vector2.zero,true,false,Vector2.zero,false);
            bool retained=aim.Direction==Vector2.left;
            aim.Update(Vector2.zero,Vector2.right,Vector2.right,Vector2.zero,true,false,Vector2.zero,false);
            check("player_aim_idle_retains_stick_movement_resets",retained&&aim.Direction==Vector2.right);
            aim.Update(new Vector2(50,50),Vector2.up,Vector2.zero,Vector2.zero,false,true,new Vector2(20,50),false);
            check("player_aim_mouse_world_coordinates",aim.Position==new Vector2(20,50)&&aim.Direction==Vector2.left);
            Vector2 prior=aim.Position;aim.Update(Vector2.one,Vector2.up,Vector2.zero,Vector2.right,true,false,Vector2.zero,true);
            check("player_aim_locked_state_unchanged",aim.Position==prior);
            bool bounds=PlayerCameraMath.Clamp(Vector2.zero,40,30)==new Vector2(288,162)
                &&PlayerCameraMath.Clamp(new Vector2(99999,99999),40,30)==new Vector2(992,798)
                &&PlayerCameraMath.Clamp(Vector2.zero,10,8)==new Vector2(160,128);
            check("player_camera_bounds",bounds);
            check("player_camera_source_smoothing",PlayerCameraMath.Follow(Vector2.zero,new Vector2(100,100),.1)==new Vector2(50,50));
            check("player_camera_small_map_centered",PlayerCameraMath.Clamp(new Vector2(1000,-200),8,6)==new Vector2(128,96));
            world.Motor.Stamina.Reset();world.Teleport(saved);
        }
    }
}