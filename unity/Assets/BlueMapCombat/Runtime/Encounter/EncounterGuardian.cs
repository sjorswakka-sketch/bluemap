using System;
using System.Linq;
using UnityEngine;

namespace BlueMapMigration.Combat
{
    public sealed partial class CombatEncounter
    {
        static readonly double[,] GuardianPhases={{.28,70,.7,380,.58,1.6,.64,.68,.4,0,0,0,0,0},{.22,80,.6,410,.48,1.4,.56,.58,.5,2.9,4,.85,118,1},{.15,94,.52,450,.42,1.1,.46,.5,.6,2.1,5,.75,135,2}};
        static double PhaseValue(EncounterActor e,int field)=>GuardianPhases[Mathf.Clamp(e.Phase-1,0,2),field];
        static int GuardianPhase(EncounterActor e)=>e.Hp>e.MaxHp*.66?1:e.Hp>e.MaxHp*.33?2:3;
        void Guardian(EncounterActor e,double dt)
        {
            if(e.Finished)return;
            if(!e.Active){if(state.Flag("guardian_started"))Activate(e);return;}
            e.StateTime+=dt;e.Desired=Vector2.zero;
            if(e.State=="dying"){if(e.StateTime>=2.8&&!e.Finished){e.Finished=true;foreach(var pillar in e.Pillars)pillar.Cancel();GuardianFinished?.Invoke(e);}return;}
            switch(e.State)
            {
                case "waking":if(e.StateTime>=1.8)Enter(e,"idle");break;
                case "idle":
                    Vector2 offset=player.Position-e.Position;float distance=offset.magnitude;
                    if(distance<104)e.Desired=-offset.normalized*(float)PhaseValue(e,1)*1.3f;else if(distance>190)e.Desired=offset.normalized*(float)PhaseValue(e,1);
                    if(e.StateTime>=PhaseValue(e,0))GuardianAttack(e,distance);break;
                case "charge_windup":
                    double windup=PhaseValue(e,2);if(e.StateTime<windup*.6){Vector2 lead=player.Position-e.Position+player.Velocity*(float)((windup-e.StateTime)*.6);e.Aim=Vector2.Lerp(e.Aim,lead.normalized,.18f).normalized;e.Length=ChargeLength(e);}
                    if(e.StateTime>=windup){e.DashLeft=e.Length;Enter(e,"charge_dash");}break;
                case "charge_dash":e.Desired=e.Aim*(float)PhaseValue(e,3);break;
                case "stunned":if(e.StateTime>=PhaseValue(e,5))Enter(e,"idle");break;
                case "recover":if(e.StateTime>=PhaseValue(e,4))AfterGuardianAttack(e);break;
                case "slam_windup":if(e.StateTime>=PhaseValue(e,6)){Enter(e,"slam_recover");if(Vector2.Distance(e.Position,player.Position)<78)Hurt(e.Position,(int)e.Number("slam_damage",2),e.Text("name")+" (klap)");if(e.SlamAngles.Count>0){ShootRing(e,e.Position+new Vector2(0,14),e.SlamAngles.ToArray(),110);e.SlamAngles.Clear();}SoundRequested?.Invoke("slam");}break;
                case "slam_recover":if(e.StateTime>=PhaseValue(e,7))AfterGuardianAttack(e);break;
                case "phase_shift":if(e.StateTime>=1.8){e.Phase=e.ShiftTo;e.VolleyTimer=1.5;Enter(e,"idle");}break;
            }
            if(e.Phase>=2&&e.State!="waking"&&e.State!="phase_shift")
            {
                e.VolleyTimer-=dt;if(e.VolleyTimer<=0){var ready=e.Pillars.Where(p=>!p.Charging&&Vector2.Distance(p.Position,player.Position)>=120).OrderBy(p=>Rand()).Take((int)PhaseValue(e,10)).ToArray();if(ready.Length==0)e.VolleyTimer=.5;else{foreach(var pillar in ready){pillar.Angles.Clear();pillar.Angles.AddRange(RingAngles(Range(0,Mathf.PI*2),2).Select(a=>(double)a));pillar.AngleStep=Math.PI*2/16;pillar.Windup=pillar.TotalWindup=PhaseValue(e,11);pillar.Speed=PhaseValue(e,12);pillar.Rings=(int)PhaseValue(e,13);pillar.Wait=0;pillar.Charging=true;SoundRequested?.Invoke("pillar_charge");}e.VolleyTimer=PhaseValue(e,9);}}
            }
            Vector2 before=e.Position;Move(e,(e.Desired+e.Knockback)*(float)dt);e.Velocity=(e.Position-before)/(float)dt;e.Knockback=Vector2.MoveTowards(e.Knockback,Vector2.zero,(float)(700*dt));
            if(e.State=="charge_dash"){e.DashLeft-=Vector2.Distance(e.Position,before);if(Vector2.Distance(e.Position,before)<e.Desired.magnitude*dt*.5f){Enter(e,"stunned");SoundRequested?.Invoke("slam");}else if(e.DashLeft<=0)Enter(e,"recover");}
            if(new[]{"idle","charge_windup","charge_dash","slam_windup"}.Contains(e.State)&&e.TouchCooldown<=0&&Vector2.Distance(e.Position,player.Position)<e.Radius+9){e.TouchCooldown=.8;Hurt(e.Position,e.State=="charge_dash"?2:(int)e.Number("damage",1),e.Text("name")+(e.State=="charge_dash"?" (storm)":""));}
        }
        void AfterGuardianAttack(EncounterActor e){if(Rand()<PhaseValue(e,8))GuardianAttack(e,Vector2.Distance(player.Position,e.Position));else Enter(e,"idle");}
        void GuardianAttack(EncounterActor e,float distance)
        {
            string choice=distance<92?"slam":"charge";if(choice==e.LastAttack&&e.RepeatCount>=2){string other=choice=="slam"?"charge":"slam";if(other=="charge"||distance<92*1.6f)choice=other;}e.RepeatCount=choice==e.LastAttack?e.RepeatCount+1:1;e.LastAttack=choice;
            if(choice=="charge"){e.Aim=(player.Position-e.Position).normalized;e.Length=ChargeLength(e);Enter(e,"charge_windup");SoundRequested?.Invoke("guardian_charge");}
            else{e.SlamAngles.Clear();if(e.Phase==3)e.SlamAngles.AddRange(RingAngles(Range(0,Mathf.PI*2),1));Enter(e,"slam_windup");SoundRequested?.Invoke("pillar_charge");}
        }
        float ChargeLength(EncounterActor e)
        {Vector2 feet=e.Position+new Vector2(0,e.Size*.28f);float length=0;while(length<340){if(Solid?.Invoke(feet+e.Aim*(length+16))??false)break;length+=8;}foreach(var pillar in e.Pillars){Vector2 rel=pillar.Position+new Vector2(0,8)-feet;float along=Vector2.Dot(rel,e.Aim);if(along>0&&Math.Abs(rel.x*e.Aim.y-rel.y*e.Aim.x)<24)length=Math.Min(length,along-18);}return Mathf.Clamp(length,40,340);}
        float[] RingAngles(float start,int gaps)
        {var skip=new System.Collections.Generic.HashSet<int>();int first=random.Next(16);for(int g=0;g<gaps;g++){int at=((first+g*16/gaps+random.Next(-1,2))%16+16)%16;skip.Add(at);skip.Add((at+1)%16);}return Enumerable.Range(0,16).Where(i=>!skip.Contains(i)).Select(i=>start+Mathf.PI*2*i/16).ToArray();}
        void ShootRing(EncounterActor e,Vector2 at,float[] angles,float speed)
        {SoundRequested?.Invoke("shard_burst");foreach(float angle in angles){Vector2 dir=Rotate(Vector2.right,angle);SpawnProjectile("guardian_shard",at+dir*24,dir,speed,1,e.Text("name")+" (scherf)");}}
        void Pillar(EncounterPillar p,double dt)
        {
            p.Time+=dt;p.Flash=Math.Max(0,p.Flash-dt);if(!p.Charging)return;if(p.Windup>0){p.Windup-=dt;if(p.Windup<=0)PillarFire(p);}else if(p.Rings>0){p.Wait-=dt;if(p.Wait<=0)PillarFire(p);}if(p.Rings<=0&&p.Windup<=0)p.Charging=false;
        }
        void PillarFire(EncounterPillar p)
        {p.Rings--;p.Flash=.25;SoundRequested?.Invoke("shard_burst");foreach(double angle in p.Angles){Vector2 dir=Rotate(Vector2.right,(float)angle);SpawnProjectile("guardian_shard",p.Position+new Vector2(0,2)+dir*22,dir,(float)p.Speed,1,"De Vergeten Wachter (scherf)");}if(p.Rings>0){for(int i=0;i<p.Angles.Count;i++)p.Angles[i]+=p.AngleStep*.5;p.Wait=.7;}}
    }
}
