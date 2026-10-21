using System;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using UnityEngine;

namespace BlueMapMigration.Combat
{
    public sealed partial class CombatEncounter
    {
        void Wander(EncounterActor e,double dt)
        {if(e.PatrolRadius>0&&Vector2.Distance(e.Position,e.Home)>e.PatrolRadius*.45f){e.Desired=Free(e,(e.Home-e.Position).normalized)*e.Number("speed");return;}e.WanderTimer-=dt;if(e.WanderTimer<=0){e.WanderTimer=Range(.8f,2);e.Wander=Rand()<.7f?Rotate(Vector2.right,Range(0,Mathf.PI*2)):Vector2.zero;}e.Desired=e.Wander*e.Number("speed");}
        bool SlotFree(EncounterActor e)=>!actors.Any(other=>other!=e&&!other.Dead&&Vector2.Distance(other.Position,e.Position)<240&&new[]{"cv_warn","cv_charge","lw_warn","lw_lunge","echo_warn","rf_warn","hb_root_warn","hb_root_hit","hb_moth_warn","hb_moth_dash"}.Contains(other.State));
        void Ai(EncounterActor e,double dt)
        {
            Vector2 offset=player.Position-e.Position;float distance=offset.magnitude;Vector2 direction=offset.normalized;
            switch(e.Behavior)
            {
                case "animal":e.Panic=Math.Max(0,e.Panic-dt);e.Fleeing=e.Panic>0||distance<e.Number("panic_range",90);if(e.Fleeing){Vector2 away=-direction;if(e.Kind.StartsWith("trail_",StringComparison.Ordinal)&&Vector2.Distance(e.Position,e.Home)>e.PatrolRadius)away=(e.Home-e.Position).normalized;e.Desired=away*e.Number("chase_speed");}else Wander(e,dt);AnimalDrop(e);break;
                case "chase":if(distance<e.Number("sight")&&(e.PatrolRadius<=0||Vector2.Distance(e.Home,player.Position)<e.PatrolRadius))e.Desired=direction*e.Number("chase_speed");else Wander(e,dt);break;
                case "bat":
                    if(e.State=="idle"){if(distance>e.Number("sight"))Wander(e,dt);else{e.Desired=PlayerMotorModel.NormalizeSource(Side(direction)*(float)e.Strafe*.8f+direction*(distance>90?.3f:-.4f))*e.Number("speed");if(e.StateTime>Range(1.2f,2.2f)){Enter(e,"telegraph");e.Aim=direction;}}}
                    else if(e.State=="telegraph"){e.Aim=direction;if(e.StateTime>.35)Enter(e,"dash");}
                    else if(e.State=="dash"){e.Desired=e.Aim*210;if(e.StateTime>.45){Enter(e,"retreat");e.Strafe=-e.Strafe;}}
                    else if(e.State=="retreat"){e.Desired=-direction*e.Number("speed");if(e.StateTime>.7)Enter(e,"idle");}break;
                case "archer":
                    if(e.State=="idle"){if(distance>e.Number("sight")){Wander(e,dt);break;}if(distance<75)e.Desired=-direction*e.Number("speed")*1.4f;else if(distance>150)e.Desired=direction*e.Number("chase_speed");else{e.Desired=Side(direction)*(float)e.Strafe*e.Number("speed")*.8f;if(Rand()<.01f)e.Strafe=-e.Strafe;}if(e.StateTime>2.2)Enter(e,"aim");}
                    else if(e.State=="aim"){e.Aim=direction;if(e.StateTime>.55){Fire(e,"arrow",e.Position,e.Aim,150);Enter(e,"idle");SoundRequested?.Invoke("arrow");}}break;
                case "mage":Mage(e,offset,distance,dt);break;
                case "spitter":Spitter(e,offset,distance,dt);break;
                case "golem":
                    bool enraged=e.Hp*2<e.MaxHp;if(e.State=="idle"){if(distance<e.Number("sight"))e.Desired=direction*e.Number("chase_speed")*(enraged?1.4f:1);else Wander(e,dt);if(distance<66&&e.StateTime>1.2)Enter(e,"windup");}
                    else if(e.State=="windup"&&e.StateTime>(enraged?.65:.9)){if(distance<56)Hurt(e.Position,(int)e.Number("slam_damage",e.Number("damage")),e.Text("name")+" (klap)");if(enraged)for(int i=0;i<6;i++)Fire(e,"rock",e.Position,Rotate(Vector2.right,Mathf.PI*2*i/6+.3f),95,1);SoundRequested?.Invoke("slam");Enter(e,"recover");}
                    else if(e.State=="recover"&&e.StateTime>.9)Enter(e,"idle");break;
                case "king":King(e,dt);break;
                case "cv_ram":case "cv_slinger":CombatAi(e,offset,distance);break;
                case "rf_ambush":case "rf_listen":RouteAi(e,offset,distance);break;
                case "lw_guard":case "lw_flank":case "lw_support":LivingAi(e,offset,distance,dt);break;
                case "echo_charge":case "echo_volley":EchoAi(e,offset,distance,dt);break;
                case "hb_root":case "hb_moth":Habitat(e,offset,distance,dt);break;
                case "ad_crab":case "ad_wisp":case "ad_keeper":Coastal(e,offset,distance,dt);break;
                default:throw new FormatException("Unported original enemy behavior: "+e.Behavior);
            }
        }
        void Fire(EncounterActor e,string kind,Vector2 at,Vector2 aim,float speed,int damage=-1)=>SpawnProjectile(kind,at,aim,speed,damage<0?(int)e.Number("damage",1):damage,e.Text("name",e.Kind)+(kind=="arrow"?" (pijl)":kind=="arcane_orb"?" (tovervonk)":kind=="slimeball"?" (slijmbal)":kind=="rock"?" (steen)":""));
        void Hint(EncounterActor e){string hint=e.Text("hint");string flag="vijanden_hint_"+e.Kind;if(hint!=""&&!state.Flag(flag)){state.SetFlag(flag,true);MessageRequested?.Invoke(hint);e.Special=Math.Max(e.Special,3.5);}}
        void Mage(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            e.Special-=dt;Vector2 dir=offset.normalized;
            if(e.State=="idle")
            {
                if(distance>e.Number("sight")){Wander(e,dt);e.Special=1.2;return;}Hint(e);var keep=Get(e.Data,"keep_distance").Items;float first=keep.Count>0?(float)keep[0].AsDouble():90,last=keep.Count>1?(float)keep[1].AsDouble():160;
                if(distance<first)e.Desired=Free(e,-dir)*e.Number("speed")*1.3f;else if(distance>last)e.Desired=Free(e,dir)*e.Number("chase_speed");else{e.Desired=Free(e,Side(dir)*(float)e.Strafe)*e.Number("speed")*.5f;if(Rand()<.01f)e.Strafe=-e.Strafe;}
                bool stuck=false;if(distance>=first&&distance<=last){e.StuckTime=0;e.StuckAnchor=e.Position;}else{e.StuckTime+=dt;if(e.StuckTime>=.5f){stuck=Vector2.Distance(e.Position,e.StuckAnchor)<10;e.StuckTime=0;e.StuckAnchor=e.Position;}}
                if(e.Special<=0||stuck){Enter(e,"vanish");e.Special=e.Scalar("teleport_every");e.StuckTime=0;e.StuckAnchor=e.Position;SoundRequested?.Invoke("mage_teleport");}
            }
            else if(e.State=="vanish"&&e.StateTime>=e.Scalar("vanish_time"))
            {var span=Get(e.Data,"teleport_range").Items;float first=span.Count>0?(float)span[0].AsDouble():100,last=span.Count>1?(float)span[1].AsDouble():140;Vector2? fallback=null;for(int i=0;i<24;i++){Vector2 spot=player.Position+Rotate(Vector2.right,Range(0,Mathf.PI*2))*Range(first,last);if(!Fits(e,spot))continue;fallback=fallback??spot;if(!(Solid?.Invoke(spot+new Vector2(0,-14))??false)&&Clear(spot+new Vector2(0,-14),player.Position+new Vector2(0,4))){fallback=spot;break;}}if(fallback.HasValue){e.Position=fallback.Value;e.Knockback=Vector2.zero;}e.StuckAnchor=e.Position;Enter(e,"appear");}
            else if(e.State=="appear"){e.Aim=dir;if(e.StateTime>=e.Scalar("appear_time")){Enter(e,"cast");SoundRequested?.Invoke("mage_charge");}}
            else if(e.State=="cast"){e.Aim=dir;if(e.StateTime>=e.Scalar("cast_time")){Vector2 at=e.Position+new Vector2(0,-14);Fire(e,"arcane_orb",at,(player.Position+new Vector2(0,4)-at).normalized,e.Number("orb_speed"));SoundRequested?.Invoke("mage_orb");e.ActionFlash=.15;Enter(e,"idle");}}
        }
        void Spitter(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            e.Special-=dt;e.HopCooldown=Math.Max(0,e.HopCooldown-dt);
            if(e.State=="idle")
            {
                if(distance>e.Number("spit_range")){Wander(e,dt);e.Special=1.2;return;}Hint(e);if(distance>e.Number("spit_range")*.8f)e.Desired=Free(e,offset.normalized)*e.Number("speed");else Wander(e,dt);
                if(distance<e.Number("flee_range")&&e.HopCooldown<=0){foreach(float shrink in new[]{1,.8f,.6f,.45f})foreach(float turn in new[]{0,.5f,-.5f,1,-1,1.5f,-1.5f}){Vector2 spot=e.Position+Rotate(-offset.normalized,turn)*e.Number("hop_distance")*shrink;if(Vector2.Distance(spot,player.Position)>distance+15&&Fits(e,spot)&&BodyClear(e,e.Position,spot)){e.HopFrom=e.Position;e.HopTo=spot;e.HopCount++;Enter(e,"hop");SoundRequested?.Invoke("spitter_hop");return;}}e.HopCooldown=.5;}
                else if(e.Special<=0){Enter(e,"windup");e.Special=e.Scalar("spit_every");e.Aim=offset.normalized;}
            }
            else if(e.State=="windup"){if(e.StateTime<e.Scalar("windup")-.15)e.Aim=offset.normalized;if(e.StateTime>=e.Scalar("windup")){int fan=(int)e.Number("fan");for(int i=0;i<fan;i++)Fire(e,"slimeball",e.Position+new Vector2(0,6),Rotate(e.Aim,(i-(fan-1)/2f)*e.Number("fan_spread")),e.Number("ball_speed"));e.Knockback=-e.Aim*90;e.ActionFlash=.2;Enter(e,"idle");SoundRequested?.Invoke("spitter_spit");}}
            else if(e.State=="hop"){double p=Math.Clamp(e.StateTime/e.Scalar("hop_time"),0,1);e.AirHeight=Math.Sin(p*Math.PI)*14;e.Position=Vector2.Lerp(e.HopFrom,e.HopTo,(float)p);if(p>=1){e.AirHeight=0;e.HopCooldown=e.Scalar("hop_cooldown");e.Special=Math.Max(e.Special,.7);Enter(e,"idle");}}
        }
        void King(EncounterActor e,double dt)
        {
            int phase=e.Hp>(e.MaxHp*.65)?1:e.Hp>e.MaxHp*.3?2:3;
            if(e.State=="idle"&&e.StateTime>(phase==1?.9:phase==2?.6:.4)){e.HopPhase=phase;Vector2 goal=player.Position+player.Velocity*.2f;if(!Fits(e,goal)){bool found=false;for(int radius=1;radius<5&&!found;radius++)for(int i=0;i<8;i++){Vector2 candidate=goal+Rotate(Vector2.right,i*Mathf.PI/4)*radius*24;if(Fits(e,candidate)){goal=candidate;found=true;break;}}if(!found)goal=e.Position;}e.HopTo=goal;Enter(e,"crouch");}
            else if(e.State=="crouch"&&e.StateTime>(e.HopPhase==1?.65:e.HopPhase==2?.6:.5)){Enter(e,"hop");e.HopFrom=e.Position;}
            else if(e.State=="hop"){double p=Math.Clamp(e.StateTime/(e.HopPhase<3?.8:.6),0,1);e.AirHeight=Math.Sin(p*Math.PI)*52;e.Position=Vector2.Lerp(e.HopFrom,e.HopTo,(float)p);if(p>=1){e.AirHeight=0;e.HopCount++;float shock=e.HopPhase==1?64:e.HopPhase==2?74:86;if(Vector2.Distance(e.Position,player.Position)<shock)Hurt(e.Position,e.HopPhase==1?1:(int)e.Number("slam_damage",2),e.Text("name")+" (landing)");if((e.HopPhase==1&&e.HopCount%4==0||e.HopPhase==3&&e.HopCount%3==0)&&actors.Count(a=>!a.Dead&&a.Kind=="slime_mini")<3)for(int i=0;i<2;i++){Vector2 at=e.Position+Rotate(Vector2.right,Range(0,Mathf.PI*2))*60;if(Fits(e,at))Spawn("slime_mini",at);}if(e.HopPhase>=2){int bullets=e.HopPhase==2?3:5;for(int i=0;i<bullets;i++)Fire(e,"slimeball",e.Position,Rotate((player.Position-e.Position).normalized,(i-(bullets-1)/2f)*.3f),115,1);}SoundRequested?.Invoke("slam");Enter(e,"land");}}
            else if(e.State=="land"&&e.StateTime>.65)Enter(e,"idle");
        }
        void CombatAi(EncounterActor e,Vector2 offset,float distance)
        {
            if(e.State=="cv_warn"){if(e.StateTime>=.85){if(e.Behavior=="cv_ram")Enter(e,"cv_charge");else{Fire(e,"cv_thorn",e.Position,e.Aim,150,1);SoundRequested?.Invoke("cv_thorn");Enter(e,"cv_rest");}}return;}
            if(e.State=="cv_charge"){if(e.StateTime>.45||!BodyClear(e,e.Position,e.Position+e.Aim*16))Enter(e,"cv_rest");else e.Desired=e.Aim*205;return;}
            if(e.State=="cv_rest"){if(e.StateTime>1.3)Enter(e,"idle");return;}
            if(!Clear(e.Position,player.Position)||distance>(player.Noisy?230:140)){e.StateTime=Math.Min(e.StateTime,.6);return;}
            if(e.Behavior=="cv_slinger"){if(distance<85)e.Desired=Free(e,-offset.normalized)*34;else if(distance>185)e.Desired=Free(e,offset.normalized)*25;}else if(distance>115)e.Desired=Free(e,offset.normalized)*42;
            if(e.StateTime>1.1&&distance>24&&SlotFree(e)){e.Aim=offset.normalized;Enter(e,"cv_warn");SoundRequested?.Invoke("cv_ready");}
        }
        void RouteAi(EncounterActor e,Vector2 offset,float distance)
        {
            if(e.State=="rf_warn"){if(e.StateTime>=.85)Enter(e,"rf_jump");}
            else if(e.State=="rf_jump"){e.Desired=e.Aim*185;if(e.StateTime>=.32)Enter(e,"rf_rest");}
            else if(e.State=="rf_rest"){if(e.StateTime>=1.5)Enter(e,"idle");}
            else if(((e.Behavior=="rf_ambush"?distance<115:distance<170&&player.Noisy)||distance<28||e.Flash>0)&&e.StateTime>.8&&Clear(e.Position,player.Position)){e.Aim=offset.normalized;Enter(e,"rf_warn");SoundRequested?.Invoke(e.Behavior=="rf_ambush"?"rf_rustle":"rf_low");}
        }
        void LivingAi(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            if(e.GuardBroken>0)return;
            if(e.Behavior=="lw_guard")
            {if(distance<260){var ally=actors.Where(a=>a!=e&&!a.Dead&&(a.Behavior=="lw_support"||a.Behavior=="cv_slinger")&&Vector2.Distance(a.Position,e.Position)<150&&Clear(e.Position,a.Position)).OrderBy(a=>Vector2.Distance(a.Position,e.Position)).FirstOrDefault();if(ally!=null){offset=ally.Position+(player.Position-ally.Position).normalized*45-e.Position;distance=offset.magnitude;}}if(distance>320){Wander(e,dt);return;}e.Aim=Rotate(e.Aim,Angle(e.Aim,(player.Position-e.Position).normalized)*(float)Math.Min(1,dt*2.5));if(distance>24)e.Desired=Free(e,offset.normalized)*37;}
            else if(e.Behavior=="lw_flank")
            {if(LightAt?.Invoke(e.Position)??false){e.Desired=Free(e,-offset.normalized)*60;Enter(e,"idle");return;}if(distance>300)Wander(e,dt);else if(e.State=="lw_lunge"){e.Desired=e.Aim*175;if(e.StateTime>.28)Enter(e,"lw_rest");}else if(e.State=="lw_warn"){if(e.StateTime>.65)Enter(e,"lw_lunge");}else if(e.State=="lw_rest"){if(e.StateTime>.9)Enter(e,"idle");}else{e.Desired=Free(e,distance>105?offset.normalized:(Side(offset).normalized+offset.normalized*.2f).normalized)*58;if(e.StateTime>1.6&&distance<155&&Clear(e.Position,player.Position)){Enter(e,"lw_warn");e.Aim=offset.normalized;}}}
            else if(e.State=="lw_song"){if(e.StateTime>1){foreach(var ally in actors.Where(a=>a!=e&&!a.Dead&&Vector2.Distance(a.Position,e.Position)<160&&Clear(e.Position,a.Position)))ally.Hp=Math.Min(ally.Hp+1,ally.MaxHp);Enter(e,"idle");}}
            else{if(distance<100)e.Desired=Free(e,-offset.normalized)*35;else if(distance>210&&distance<400)e.Desired=Free(e,offset.normalized)*25;if(e.StateTime>4&&distance<350)Enter(e,"lw_song");}
        }
        void EchoAi(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            bool charge=e.Behavior=="echo_charge";
            if(e.State=="idle"){if(distance>e.Number("sight")){Wander(e,dt);e.StateTime=0;return;}e.Desired=Free(e,charge?offset.normalized:distance<105?-offset.normalized:distance>185?offset.normalized:Side(offset).normalized)*e.Number("speed");if(e.StateTime>=1.35&&Clear(e.Position,player.Position)){Enter(e,"echo_warn");e.Aim=offset.normalized;SoundRequested?.Invoke("mage_charge");}}
            else if(e.State=="echo_warn"){if(e.StateTime<.35)e.Aim=offset.normalized;if(e.StateTime>=.7){if(charge){Enter(e,"echo_dash");SoundRequested?.Invoke("dodge");}else{foreach(float angle in new[]{-.45f,0,.45f})Fire(e,"prism_spark",e.Position,Rotate(e.Aim,angle),115,1);Enter(e,"echo_rest");SoundRequested?.Invoke("mage_orb");}}}
            else if(e.State=="echo_dash"){e.Desired=e.Aim*230;if(e.StateTime>=.48||e.StateTime>.06&&!BodyClear(e,e.Position,e.Position+e.Aim*8)){e.Desired=Vector2.zero;Enter(e,"echo_rest");}}
            else if(e.State=="echo_rest"&&e.StateTime>=.95)Enter(e,"idle");
        }
        bool Protected(Vector2 at)
        {
            if(snapshot==null)return false;foreach(var arrival in snapshot.Arrivals)if(Vector2.Distance(at,arrival.Nominal)<80)return true;
            foreach(var obj in snapshot.MapData.Require("objects").Items){string type=Text(obj,"type");if(type!="savepoint"&&type!="portal")continue;if(obj.TryGet("enabled",out var enabled)&&!enabled.AsBool())continue;Vector2 p=V(obj.Require("pos"))*32+Vector2.one*16;if(type=="portal"&&obj.TryGet("size",out var size))p+=(V(size)-Vector2.one)*16;if(Vector2.Distance(at,p)<80)return true;}return false;
        }
        bool Home(EncounterActor e,Vector2 at)=>Vector2.Distance(at,e.Home+new Vector2(0,8))<=144;
        bool HabitatTarget(EncounterActor e)=>Home(e,player.Position+new Vector2(0,8))&&!Protected(player.Position+new Vector2(0,8))&&Clear(e.Position,player.Position);
        float Clip(EncounterActor e,float requested,float half)
        {float length=0;Vector2 side=Side(e.Aim)*half;for(int step=4;step<=requested;step+=4){Vector2 at=e.Origin+e.Aim*step;bool clear=true;foreach(Vector2 offset in new[]{-side,Vector2.zero,side})if(!Home(e,at+offset)||Protected(at+offset)||!Clear(e.Origin+offset,at+offset)){clear=false;break;}if(!clear)break;length=step;}return length;}
        bool Strip(EncounterActor e,Vector2 at,double first,double last,double half){Vector2 offset=at-e.Origin;float along=Vector2.Dot(offset,e.Aim);return along>=first&&along<=last&&Math.Abs(Vector2.Dot(offset,Side(e.Aim)))<=half;}
        void HabitatMove(EncounterActor e,Vector2 direction,double speed,double dt){Vector2 next=e.Position+direction*(float)Math.Max(speed*dt,8);if(Home(e,next)&&!Protected(next)&&BodyClear(e,e.Position,next))e.Desired=direction*(float)speed;}
        Vector2? FixedLight(EncounterActor e)
        {Vector2? best=null;float nearest=float.PositiveInfinity;if(snapshot!=null&&LightNeed>.02f)foreach(var node in snapshot.Root.Require("scene").Items){string script=node.Require("script").AsString();if(!script.EndsWith("/torch.gd",StringComparison.Ordinal)||(NodeVisible!=null&&!NodeVisible(node)))continue;Vector2 at=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));float distance=Vector2.Distance(e.Position,at);if(distance<=144&&Home(e,at)&&!Protected(at)&&Clear(e.Position,at)&&distance<nearest){nearest=distance;best=at;}}return best;}
        void Habitat(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            if(e.Behavior=="hb_root")
            {
                if(e.State=="hb_rest"){if(e.StateTime>=1.8)Enter(e,"idle");return;}
                if(e.State=="hb_root_warn"){e.Length=Math.Min(e.Length,Clip(e,100,12));if(e.Length<18){Enter(e,"hb_rest");return;}if(e.StateTime>=1.1){Enter(e,"hb_root_hit");SoundRequested?.Invoke("hb_root_strike");}return;}
                if(e.State=="hb_root_hit"){if(!e.Hit&&HabitatTarget(e)&&Strip(e,player.Position+new Vector2(0,8),18,e.Length,12)){e.Hit=true;Hurt(e.Origin,1,e.Text("name"));}if(e.StateTime>=.18)Enter(e,"hb_rest");return;}
                if(e.StateTime<1.6||!HabitatTarget(e)||distance>100||!SlotFree(e))return;e.Aim=distance>.1f?offset.normalized:new Vector2(0,1);e.Origin=e.Position+new Vector2(0,8);e.Length=Clip(e,100,12);if(e.Length<18)return;Enter(e,"hb_root_warn");SoundRequested?.Invoke("hb_root_ready");return;
            }
            if(e.State=="hb_rest"){if(e.StateTime>=1.6)Enter(e,"idle");return;}
            var light=FixedLight(e);
            if(e.State=="hb_moth_warn"){if(light.HasValue||!HabitatTarget(e)){Enter(e,"hb_rest");return;}e.Length=Math.Min(e.Length,Clip(e,70,12));if(e.StateTime>=.85)Enter(e,"hb_moth_dash");return;}
            if(e.State=="hb_moth_dash"){if(!HabitatTarget(e)||e.StateTime>=.46||e.Traveled>=e.Length){Enter(e,"hb_rest");return;}HabitatMove(e,e.Aim,Math.Min(155,(e.Length-e.Traveled)/Math.Max(dt,.001)),dt);if(e.Desired==Vector2.zero)Enter(e,"hb_rest");return;}
            e.Distracted=light.HasValue;Vector2 target=light??player.Position;bool lamp=player.Lamp&&(PlayerLampAt?.Invoke(player.Position)??true);
            if(!light.HasValue&&(!lamp||distance>=112||!HabitatTarget(e))){Vector2 back=e.Home-e.Position;if(back.magnitude>10)HabitatMove(e,back.normalized,28,dt);e.StateTime=Math.Min(e.StateTime,.7);return;}
            Vector2 toward=target-e.Position;if(e.Distracted){if(toward.magnitude>30)HabitatMove(e,toward.normalized,38,dt);e.StateTime=Math.Min(e.StateTime,.7);return;}
            if(toward.magnitude>52)HabitatMove(e,toward.normalized,38,dt);else if(e.StateTime>1.4&&SlotFree(e)){e.Aim=toward.magnitude>.1f?toward.normalized:new Vector2(0,1);e.Origin=e.Position+new Vector2(0,8);e.Length=Clip(e,70,12);e.Traveled=0;if(e.Length<20)return;Enter(e,"hb_moth_warn");SoundRequested?.Invoke("hb_moth_ready");}
        }
        bool CoastAllowed(EncounterActor e,Vector2 at)=>new Rect((e.Kind=="ad_keeper"?38*32:8*32)+20,5*32+20,(e.Kind=="ad_keeper"?18*32:16*32)-40,18*32-40).Contains(at)&&at.y<24*32&&at.x>=7*32;
        bool CoastTarget(EncounterActor e)=>CoastAllowed(e,player.Position)&&Vector2.Distance(e.Position,player.Position)<e.Number("sight")&&Clear(e.Position,player.Position);
        void Coastal(EncounterActor e,Vector2 offset,float distance,double dt)
        {
            if(!CoastTarget(e)){if(e.State!="ad_idle")Enter(e,"ad_idle");e.Knockback=Vector2.zero;Vector2 home=e.Home-e.Position;if(home.magnitude>3&&CoastAllowed(e,e.Position+home.normalized*(float)(30*dt)))e.Desired=home.normalized*30;return;}
            if(e.State=="idle"||e.State=="ad_idle"){if(e.StateTime<1.2||actors.Any(a=>a!=e&&!a.Dead&&Vector2.Distance(a.Position,e.Position)<280&&a.State.StartsWith("ad_",StringComparison.Ordinal)&&a.State!="ad_rest"&&a.State!="ad_idle"))return;if(e.Kind!="ad_wisp"&&distance>100){Vector2 direction=Rotate(offset.normalized,(float)(.25*Math.Sin(e.Time)));Vector2 next=e.Position+direction*(float)(e.Number("speed")*dt);if(CoastAllowed(e,next)&&BodyClear(e,e.Position,next))e.Desired=direction*e.Number("speed");return;}e.Aim=offset.normalized;e.Origin=e.Position;e.Pulse=0;e.Combo=0;Enter(e,"ad_warn");SoundRequested?.Invoke("ad_warn");return;}
            if(e.State=="ad_warn"||e.State=="ad_warn2"){if(e.StateTime>=.95){Enter(e,e.Kind=="ad_wisp"?"ad_pulse":"ad_swing");SoundRequested?.Invoke(e.Kind=="ad_wisp"?"ad_pulse":"ad_swipe");}return;}
            if(e.State=="ad_swing"){Vector2 d=player.Position-e.Origin;if(!e.Hit&&CoastTarget(e)&&d.magnitude<=118&&(d.magnitude<8||Math.Abs(Angle(e.Aim,d))<=.58)){Hurt(e.Position,(int)e.Number("damage"),e.Text("name"));e.Hit=true;}if(e.StateTime>=.18){if(e.Kind=="ad_keeper"&&e.Combo==0){e.Combo=1;e.Aim=Rotate(e.Aim,Mathf.PI/2);Enter(e,"ad_warn2");SoundRequested?.Invoke("ad_warn");}else Enter(e,"ad_rest");}}
            else if(e.State=="ad_pulse"){double previous=e.Pulse;e.Pulse=Math.Min(148,e.StateTime/.7*148);Vector2 d=player.Position-e.Origin;if(!e.Hit&&CoastTarget(e)&&d.magnitude<=e.Pulse+8&&d.magnitude>=Math.Max(0,previous-8)&&Math.Abs(Angle(e.Aim,d))>.52){Hurt(e.Position,(int)e.Number("damage"),e.Text("name"));e.Hit=true;}if(e.StateTime>=.7)Enter(e,"ad_rest");}
            else if(e.State=="ad_rest"&&e.StateTime>=1.6)Enter(e,"ad_idle");if(!CoastAllowed(e,e.Position+e.Knockback*(float)dt))e.Knockback=Vector2.zero;
        }
        void AfterMove(EncounterActor e,Vector2 before)
        {if(e.Behavior.StartsWith("ad_",StringComparison.Ordinal)&&!CoastAllowed(e,e.Position)){e.Position=before;e.Knockback=e.Velocity=Vector2.zero;}if(e.State=="hb_moth_dash"){double first=e.Traveled;e.Traveled=Math.Min(e.Length,e.Traveled+Math.Max(0,Vector2.Dot(e.Position-before,e.Aim)));if(!e.Hit&&HabitatTarget(e)&&Strip(e,player.Position+new Vector2(0,8),first,e.Traveled,12)){e.Hit=true;Hurt(e.Position,1,e.Text("name"));}}}
        public event Action<string,Vector2> AnimalDropRequested;
        void AnimalDrop(EncounterActor e)
        {if(e.Practice||e.Kind=="trail_moth"||e.Kind=="trail_gull")return;var data=state.Get("homestead");var due=Get(data,"animal_due");var drops=Get(data,"drops");if(drops.Entries.Count>=64)return;string id=state.MapId+":"+e.Kind+":"+(int)(e.Home.x/32)+","+(int)(e.Home.y/32);double now=state.PlayTime;if(Number(due,id)>now)return;string key=id+":"+(long)(now*1000);due=BlueMapMigration.Inventory.InventoryModel.Replace(due,id,FoundationValue.Number(now+90));var record=FoundationValue.Object(new System.Collections.Generic.Dictionary<string,FoundationValue>{{"map",FoundationValue.StringValue(state.MapId)},{"pos",FoundationValue.Array(new[]{FoundationValue.Number(e.Position.x),FoundationValue.Number(e.Position.y)})}});drops=BlueMapMigration.Inventory.InventoryModel.Replace(drops,key,record);data=BlueMapMigration.Inventory.InventoryModel.Replace(data,"animal_due",due);data=BlueMapMigration.Inventory.InventoryModel.Replace(data,"drops",drops);state.Set("homestead",data);AnimalDropRequested?.Invoke(key,e.Position);}
    }
}
