using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Player;
using BlueMapMigration.Inventory;
using BlueMapMigration.Combat;
using UnityEngine;
namespace BlueMapMigration.Route
{
    public sealed partial class RouteWorldController
    {
        public CombatModel Combat {get;private set;}
        public CombatEncounter Encounter {get;private set;}
        private bool? combatEnabled;
        private bool bossIntroPending;private double guardianMusicReturn;
        public bool CombatSimulationEnabled
        {
            get=>combatEnabled??!Automated;
            set{combatEnabled=value;if(Encounter!=null)Encounter.Enabled=value;World?.BindCombat(value?Combat:null);}
        }
        public EncounterActor ActiveBoss=>CombatSimulationEnabled?Encounter?.Actors.FirstOrDefault(e=>e.IsBoss&&e.Active&&!e.Dead&&!e.Finished):null;
        private void InitializeCombat()
        {
            Combat=new CombatModel(repository,Gameplay.State,Inventory,Progression,World.Motor){Translator=Translate,ClearLine=(a,b)=>World.CombatClearLine(a,b)};
            Encounter=new CombatEncounter(repository,Gameplay.State,Catalog,World.transform,Combat.Catalogs){Enabled=CombatSimulationEnabled,
                Solid=World.CombatSolid,BodyFits=World.CombatBodyFits,ClearLine=(a,b)=>World.CombatClearLine(a,b),ArrowClearLine=(a,b)=>World.CombatClearLine(a,b,true),
                NodeVisible=Access.NodeVisible,LightAt=CombatLightAt,PlayerLampAt=p=>Encounter.PlayerLampActive};
            Combat.StrikeRequested+=Encounter.ApplyStrike;Combat.ArrowRequested+=Encounter.SpawnArrow;
            Combat.CancelWorkRequested+=CancelCombatWork;Combat.Toast+=ShowMessage;Combat.SoundRequested+=OnSound;
            Combat.HitstopRequested+=seconds=>World.CombatImpact(seconds,0);Combat.ShakeRequested+=pixels=>World.CombatImpact(0,pixels);
            Combat.DefeatRecorded+=RecordDeathAtLastSafeSave;Combat.Defeated+=PlayerDefeated;Combat.SaveRequested+=OnSaveRequested;
            Encounter.HurtRequested+=EncounterHurt;Encounter.LootRequested+=EncounterLoot;Encounter.EnemyDied+=EnemyDied;
            Encounter.GuardianFinished+=GuardianReward;Encounter.EndingRequested+=CompleteKingEnding;
            Encounter.SoundRequested+=OnSound;Encounter.MessageRequested+=ShowMessage;Encounter.SourceVisibilityRequested+=World.SetRouteObjectVisible;
            Encounter.PlayerPushRequested+=PushPlayer;Encounter.AnimalDropRequested+=AnimalDrop;
            World.BindCombat(CombatSimulationEnabled?Combat:null);LoadCombatMap();
        }
        private bool CombatLightAt(Vector2 at)
        {
            if(Gameplay.State.Count("lw_lantern")>0&&Vector2.Distance(World.Position,at)<66)return true;
            foreach(var node in Session.Current.Root.Require("scene").Items)
            {
                if(!node.Require("script").AsString().EndsWith("/living_object.gd",StringComparison.Ordinal))continue;
                var f=node.Require("fields");if(!f.TryGet("kind",out var k)||k.AsString()!="brazier")continue;
                bool active=f.TryGet("active",out var a)&&a.AsBool();if(f.TryGet("id",out var id))active|=Gameplay.State.Flag(id.AsString());
                if(active&&Vector2.Distance(at,FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin")))<86)return true;
            }
            return false;
        }
        private void AnimalDrop(string key,Vector2 at){SpawnLootPickup("hs_manure",at,"hs_drop:"+key);Save();}
        private void RestoreAnimalDrops()
        {
            if(!CombatSimulationEnabled)return;var home=Gameplay.State.Get("homestead");if(!home.TryGet("drops",out var drops))return;
            foreach(var entry in drops.Entries){var data=entry.Value;if(data.Require("map").AsString()==Gameplay.State.MapId&&!Gameplay.State.Flag("hs_drop:"+entry.Key.AsString())&&!targets.Any(t=>t.UniqueKey=="hs_drop:"+entry.Key.AsString()))SpawnLootPickup("hs_manure",Position(data.Require("pos")),"hs_drop:"+entry.Key.AsString());}
        }
        private void CollectAnimalDrops()
        {
            if(!CombatSimulationEnabled)return;var home=Gameplay.State.Get("homestead");if(!home.TryGet("drops",out var drops))return;
            var keep=drops.Entries.Where(e=>!Gameplay.State.Flag("hs_drop:"+e.Key.AsString())).ToDictionary(e=>e.Key.AsString(),e=>e.Value,StringComparer.Ordinal);
            if(keep.Count==drops.Entries.Count)return;
            foreach(var e in drops.Entries)if(!keep.ContainsKey(e.Key.AsString()))Gameplay.State.SetFlag("hs_drop:"+e.Key.AsString(),false);
            Gameplay.State.Set("homestead",InventoryModel.Replace(home,"drops",FoundationValue.Object(keep)));Save();
        }
        private void CancelCombatWork(){work=null;}
        private void EncounterHurt(Vector2 from,int amount,string source){if(CombatSimulationEnabled){Combat.Player.Position=World.Position;Combat.Hurt(from,amount,source);}}
        private void EncounterLoot(string item,int amount,Vector2 at){for(int i=0;i<amount;i++)SpawnLootPickup(item,at,"",true);}
        private void EnemyDied(EncounterActor enemy){Progression.RegisterKill(enemy.Kind);World.RefreshRouteState();}
        private void PushPlayer(Vector2 direction,float force){World.Motor.Knockback=PlayerMotorModel.ScaleSource(PlayerMotorModel.NormalizeSource(direction),force);}
        private void GuardianReward(EncounterActor enemy)
        {
            if(!Combat.CompleteGuardianReward(enemy.Kind=="guardian"&&enemy.Dead))return;
            OnSound("star_fanfare");ItemNotices.Add(T("+500  munten","+500  coins"));itemNoticeLives.Add(4.5);while(ItemNotices.Count>4){ItemNotices.RemoveAt(0);itemNoticeLives.RemoveAt(0);}guardianMusicReturn=6;World.RefreshRouteState();accessDirty=true;
        }
        private void LoadCombatMap(bool preserveTransient=false)
        {
            if(Encounter==null)return;double musicReturn=preserveTransient?guardianMusicReturn:0;if(!preserveTransient){StopPractice();practiceRead.Clear();practiceLesson=0;bossIntroPending=false;}if(preserveTransient)Encounter.LoadRetained(Session.Current);else Encounter.Load(Session.Current);guardianMusicReturn=musicReturn;if(guardianMusicReturn>0)World.PlayRouteMusic("guardian");if(!preserveTransient)Combat.StopForTransition();
            Combat.Player.Position=World.Position;Combat.Player.AimDirection=World.Aim.Direction;RestoreAnimalDrops();
            if(Gameplay.State.Flag("boss_started")&&Session.Current.MapId=="temple"){Encounter.ActivateBosses();World.PlayRouteMusic("boss");}
        }
        private void DetachCombat()
        {World?.BindCombat(null);Encounter?.Dispose();Encounter=null;Combat=null;bossIntroPending=false;}
        public void HandleCombatFrame(InputFrame frame)
        {
            if(!CombatSimulationEnabled||Combat==null||Gameplay.State.InputLocked)return;
            Combat.Player.Position=World.Position;Combat.Player.AimDirection=World.Aim.Direction;
            if(frame.Pressed("attack"))Combat.Attack(frame.Held("technique"));
            if(frame.Pressed("bow"))Combat.Shoot(frame.Held("technique"));
            World.UpdateAppearance();
        }
        private void TickCombat(double delta)
        {
            if(Combat==null||Encounter==null)return;
            if(Gameplay.State.InputLocked)Combat.Cancel();
            if(CombatSimulationEnabled&&!Gameplay.State.InputLocked)TickCombatTriggers();
            if(bossIntroPending&&!Gameplay.DialogueOpen&&!Gameplay.State.InputLocked){bossIntroPending=false;Encounter.ActivateBosses();if(Session.Current.MapId=="temple"){OnSound("boss");World.PlayRouteMusic("boss");}else World.PlayRouteMusic("guardian");}
            if(guardianMusicReturn>0&&!Gameplay.State.Paused){guardianMusicReturn-=delta;if(guardianMusicReturn<=0&&Gameplay.State.MapId=="depths2")World.PlayRouteMusic("depths");}
            TickPractice(delta);CollectAnimalDrops();
            Encounter.Tick(delta,new EncounterPlayer{Position=World.Position,Velocity=World.Motor.Velocity,Noisy=World.Motor.Sprinting||World.Motor.IsRolling,Lamp=Encounter.PlayerLampActive});
        }
        private void TickCombatTriggers()
        {
            if(Session.Current.MapId!="temple"&&Session.Current.MapId!="depths2")return;
            foreach(var node in Session.Current.Root.Require("scene").Items)
            {
                if(!node.Require("script").AsString().EndsWith("/trigger.gd",StringComparison.Ordinal))continue;
                var fields=node.Require("fields");if(!fields.TryGet("actions",out var actions))continue;
                var talk=actions.Items.FirstOrDefault(a=>a.Items.Count>=2&&a.Items[0].AsString()=="talk");if(talk==null)continue;
                string id=talk.Items[1].AsString();if(!new[]{"king_intro","guardian_intro","guardian_defeat"}.Contains(id))continue;
                string once=fields.TryGet("once_flag",out var of)?of.AsString():"";if(once!=""&&Gameplay.State.Flag(once))continue;
                if(fields.TryGet("conditions",out var tests)&&!conditions.CheckAll(tests).Value)continue;
                var rect=fields.Require("rect");var bounds=new Rect(FoundationCoordinates.Vector(rect.Require("position")),FoundationCoordinates.Vector(rect.Require("size")));if(!bounds.Contains(World.Position))continue;
                if(once!="")Gameplay.State.SetFlag(once,true);Combat.Cancel();work=null;
                if(Gameplay.ShowSourceDialogue(id)){SyncDialogue();bossIntroPending=id!="guardian_defeat";World.RefreshRouteState();}break;
            }
        }
        private void RecordDeathAtLastSafeSave(long deaths,long bossDeaths)
        {
            // Source death writes only counters into the previous safe save. Never persist dead HP or unsaved possessions.
            if(Persistence?.Current==null)return;
            var old=Persistence.Current.Snapshot.State;
            var merged=InventoryModel.Replace(InventoryModel.Replace(old,"deaths",FoundationValue.Integer(deaths)),"boss_deaths",FoundationValue.Integer(bossDeaths));
            SaveFailed=!Persistence.SaveAdventure(merged);SaveStatus=SaveFailed?Persistence.Status:T("Laatste veilige voortgang bewaard","Last safe progress retained");
        }
        private void PlayerDefeated(){work=null;Gameplay.CloseDialogue();Modal="defeat";Selection=0;World.Motor.StopForTransition();}
        public bool RetryAfterDefeat()
        {
            if(!Running||!Gameplay.State.Ended)return false;
            if(!Reload(false))return false;Gameplay.State.Hp=Gameplay.MaxHp;World.Motor.Stamina.Reset();Combat.ResetTransient();World.RefreshRouteState();
            ShowMessage(T("Je bent terug bij je laatste veilige voortgang.","You are back at your last safe progress."));return true;
        }
        private void CompleteKingEnding()
        {
            if(Gameplay.State.Flag("game_completed"))return;
            Gameplay.State.SetFlag("game_completed",true);Progression.FinishQuest("main");
            var map=repository.Read("village");string spawn=map.Arrivals.FirstOrDefault(a=>a.Name=="start")?.Name??map.Arrivals[0].Name;
            if(!TryTravel("village",spawn))return;
            SetModal("victory");ShowMessage(T("De Blauwe Kaart is gered!","The Blue Map is saved!"));Save();
        }
    }
}
