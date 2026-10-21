using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using UnityEngine;

namespace BlueMapMigration.Combat
{
    public sealed class EncounterPlayer
    {
        public Vector2 Position,Velocity;
        public bool Noisy,Lamp;
    }
    public sealed class EncounterActor
    {
        public string Address,Kind,Behavior,UniqueFlag,State="idle";
        public FoundationValue Data,SourceNode;
        public Vector2 Position,Home,Velocity,Desired,Knockback,Aim=new Vector2(0,1),Wander,HopFrom,HopTo,Origin,StuckAnchor;
        public float Radius,PatrolRadius;
        public double Time,StateTime,Flash,TouchCooldown,GuardBroken,AirHeight,Anim,Special=1.2,HopCooldown,ActionFlash,StuckTime,WanderTimer,Strafe=1,Panic,Length,Traveled,Pulse,VolleyTimer=3,DashLeft,DeathTimer;
        public int Hp,MaxHp,HopCount,HopPhase=1,Combo,Phase=1,ShiftTo=1,RepeatCount;
        public bool Active=true,Dead,Fleeing,Hit, Distracted,Practice,Finished;
        public string LastAttack="";
        public readonly List<float> SlamAngles=new List<float>();
        public readonly List<EncounterPillar> Pillars=new List<EncounterPillar>();
        public float Number(string id,float fallback=0)=>Data!=null&&Data.TryGet(id,out var value)?(float)value.AsDouble():fallback;
        public double Scalar(string id,double fallback=0)=>Data!=null&&Data.TryGet(id,out var value)?value.AsDouble():fallback;
        public string Text(string id,string fallback="")=>Data!=null&&Data.TryGet(id,out var value)?value.AsString():fallback;
        public bool IsBoss=>Data!=null&&Data.TryGet("boss",out var value)&&value.AsBool();
        public float Size=>Number("cell",16)*Number("scale",2);
    }
    public sealed class EncounterProjectile
    {
        public string Id,Kind,Source,State="flying";
        public Vector2 Position,Direction,Velocity;
        public double Age,Life=5,Turn,Traveled,MaxRange=280,Speed,Timer,Spin,TrailTimer;
        public int Damage=1;
        public bool PlayerOwned,Precise,Dead,Breakable;
        public readonly List<Vector2> Trail=new List<Vector2>();
    }
    public sealed class EncounterPillar
    {
        public string Address;
        public Vector2 Position;
        public bool Charging;
        public double Windup,TotalWindup=1,Speed=100,AngleStep,Wait,Flash,Time;
        public int Rings;
        public readonly List<double> Angles=new List<double>();
        public void Cancel(){Charging=false;Rings=0;Windup=0;}
    }
}
