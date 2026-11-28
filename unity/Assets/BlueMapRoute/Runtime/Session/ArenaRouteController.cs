using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Combat;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// The arena: signing up with Bruno, the rounds behind closed gates, records, rewards, the heart the crowd throws
 /// and giving up at the gong. A defeat in the arena is never a game over: Bruno catches you in the hall.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  sealed class ArenaEntry{public string Kind;public int Gate;public double Delay,Time;public Vector2 Position;}
  sealed class ArenaEmerging{public EncounterActor Enemy;public double Time;}
  const double ArenaIntro=3.2,ArenaRest=3.0,ArenaFirstSpawn=1.0,ArenaSpawnGap=.45,ArenaWarn=.7,ArenaEmerge=.4,ArenaDefeatTime=1.8;
  public string ArenaPhase {get;private set;}="idle";public string ArenaRank {get;private set;}="";public int ArenaRound {get;private set;}=-1;public double ArenaRunTime {get;private set;}
  public string ArenaBannerTitle {get;private set;}="";public string ArenaBannerSub {get;private set;}="";public double ArenaBannerTime {get;private set;}
  public string ArenaStatus {get;private set;}="";public int ArenaHeartsThrown {get;private set;}
  double arenaTimer,arenaCheer;bool arenaHeartThrown;FoundationWorldSnapshot arenaBuiltFor;FoundationValue arenaObj;
  readonly List<ArenaEntry> arenaQueue=new List<ArenaEntry>(),arenaWarnings=new List<ArenaEntry>();readonly List<EncounterActor> arenaFoes=new List<EncounterActor>();readonly List<ArenaEmerging> arenaEmerging=new List<ArenaEmerging>();
  bool ArenaActive=>ArenaPhase=="intro"||ArenaPhase=="fight"||ArenaPhase=="rest";
  FoundationValue ArenaRanks=>Story.Catalogs.Require("arenaRanks");IReadOnlyList<string> ArenaOrder=>Story.Catalogs.Require("arenaOrder").Items.Select(v=>v.AsString()).ToArray();
  FoundationValue ArenaInfo(string rank)=>ArenaRanks.Require(rank);
  string ArenaName(string rank)=>Translate(ArenaInfo(rank).Require("name").AsString());
  public int ArenaFoesLeft=>arenaQueue.Count+arenaWarnings.Count+arenaFoes.Count(e=>!e.Dead);
  // --- Rules --------------------------------------------------------------------------------------------
  public bool ArenaUnlocked(string rank){int index=ArenaOrder.ToList().IndexOf(rank);return index==0||(index>0&&Gameplay.State.Flag("arena_"+ArenaOrder[index-1]+"_done"));}
  public bool ArenaDone(string rank)=>Gameplay.State.Flag("arena_"+rank+"_done");
  public string ArenaRegistered(){foreach(string rank in ArenaOrder)if(Gameplay.State.Flag("arena_signed_"+rank))return rank;return "";}
  public double ArenaBest(string rank)=>StoryModel.G(Gameplay.State.Get("arena_records"),rank,FoundationValue.Number(0)).AsDouble();
  public static string ArenaTime(double seconds){long total=(long)Math.Round(seconds,MidpointRounding.AwayFromZero);return (total/60)+":"+(total%60).ToString("00");}
  public string ArenaRecordText(string rank)=>ArenaBest(rank)>0?ArenaTime(ArenaBest(rank)):Translate("nog niet gehaald");
  public string ArenaTitle(){foreach(string rank in ArenaOrder.Reverse())if(ArenaDone(rank))return Translate(ArenaInfo(rank).Require("title").AsString());return Translate("nieuwkomer");}
  public bool ArenaRegister(string rank)
  {
   if(rank==null||!ArenaRanks.TryGet(rank,out var info)||Access.ArenaRunActive)return false;var b=new AreaBatch(this);
   if(ArenaRegistered()!=""){b.Toast("Je staat al ingeschreven. Loop maar naar de arenadeur!");b.Run();return false;}
   if(!ArenaUnlocked(rank)){b.Toast("Die rang is nog niet open. Win eerst de vorige.");b.Run();return false;}
   long fee=info.Require("fee").AsInt64();
   if(b.Coins<fee){b.Toast(Farm.Format("Je hebt niet genoeg munten (%d nodig).",fee));b.Sound("error");b.Run();return false;}
   b.AddCoins(-fee);b.Set("arena_signed_"+rank);b.Sound("buy");b.Toast(Farm.Format("Ingeschreven voor %s! Loop door de deur naar de arena.",ArenaName(rank)));b.Run();return true;
  }
  public bool ArenaCancel()
  {
   string rank=ArenaRegistered();if(rank==""||Access.ArenaRunActive)return false;var b=new AreaBatch(this);
   b.AddCoins(ArenaInfo(rank).Require("fee").AsInt64());b.Set("arena_signed_"+rank,false);b.Toast("Je bent uitgeschreven. Je krijgt je munten terug.");b.Run();return true;
  }
  string ArenaRewardText(string rank,long coins,bool first)
  {
   string Many(string one,string many)=>Farm.Format(Professions.Plural(one,many,coins),coins);
   if(!first)return Many("Beloning: %d munt!","Beloning: %d munten!");
   switch(rank)
   {
    case "bronze":return Many("Beloning: %d munt en een bronzen trofee!","Beloning: %d munten en een bronzen trofee!");
    case "silver":return Many("Beloning: %d munt en een zilveren trofee!","Beloning: %d munten en een zilveren trofee!");
    case "gold":return Many("Beloning: %d munt, een gouden trofee en de Arenahelm!","Beloning: %d munten, een gouden trofee en de Arenahelm!");
   }
   return Many("Beloning: %d munt!","Beloning: %d munten!");
  }
  /// <summary>Hand out the reward of a won rank. Coins and records every time (half the coins later); trophy, helm and title once.</summary>
  bool ArenaComplete(string rank,double seconds,out bool newRecord)
  {
   var info=ArenaInfo(rank);bool first=!ArenaDone(rank),last=rank==ArenaOrder[ArenaOrder.Count-1];long reward=info.Require("reward").AsInt64(),coins=first?reward:reward/2;
   double old=ArenaBest(rank);newRecord=old<=0||seconds<old;var b=new AreaBatch(this);
   b.AddCoins(coins);
   if(first){b.Give(info.Require("trophy").AsString());if(last)b.Give("arena_helm");b.Set("arena_"+rank+"_done");b.Set("arena_first_"+rank);if(last)b.Finish("arena_kampioen");}
   if(newRecord)Gameplay.State.Set("arena_records",InventoryModel.Replace(Gameplay.State.Get("arena_records"),rank,FoundationValue.Number(seconds)));
   b.Set("arena_fresh_"+rank);b.Toast(ArenaRewardText(rank,coins,first));
   if(first)b.Toast(Farm.Format("Nieuwe titel: %s!",Translate(info.Require("title").AsString())));
   if(newRecord&&old>0)b.Toast(Farm.Format("Nieuw record: %s!",ArenaTime(seconds)));
   b.Save();b.Run();return first;
  }
  // --- The run ------------------------------------------------------------------------------------------
  void ArenaBanner(string title,string sub,double seconds){ArenaBannerTitle=title;ArenaBannerSub=sub;ArenaBannerTime=seconds;}
  void ReleaseArena(){Access.ArenaRunActive=false;if(Combat!=null&&Combat.DefeatHandler==ArenaDefeated)Combat.DefeatHandler=null;accessDirty=true;}
  void ResetArena(){ArenaPhase="idle";ArenaRank="";ArenaRound=-1;ArenaRunTime=0;arenaTimer=0;arenaQueue.Clear();arenaWarnings.Clear();arenaFoes.Clear();arenaEmerging.Clear();ArenaStatus="";ArenaBannerTime=0;arenaHeartThrown=false;}
  public bool StartArenaRun(string rank)
  {
   if(rank==null||!ArenaRanks.TryGet(rank,out var info)||arenaObj==null||Combat==null)return false;
   ResetArena();ArenaRank=rank;Access.ArenaRunActive=true;Combat.DefeatHandler=ArenaDefeated;accessDirty=true;ArenaPhase="intro";arenaTimer=ArenaIntro;
   long count=info.Require("rounds").Items.Count;
   ArenaBanner(Farm.Format("%s-rang",ArenaName(rank)),Farm.Format(Professions.Plural("De poorten sluiten. %d ronde!","De poorten sluiten. %d rondes!",count),count),ArenaIntro);
   Message="";OnSound("arena_crowd");OnSound("slam");return true;
  }
  static void ArenaShuffle<T>(IList<T> list){for(int i=list.Count-1;i>0;i--){int j=UnityEngine.Random.Range(0,i+1);(list[i],list[j])=(list[j],list[i]);}}
  void StartArenaRound(int index)
  {
   Gameplay.State.SetFlag("arena_signed_"+ArenaRank,false);ArenaRound=index;ArenaPhase="fight";arenaHeartThrown=false;var rounds=ArenaInfo(ArenaRank).Require("rounds").Items;
   ArenaBanner(Farm.Format("Ronde %d",index+1),index==rounds.Count-1?Translate("Laatste ronde!"):"",2.4);OnSound("arena_gong");
   var kinds=new List<string>();foreach(var entry in rounds[index].Items)for(int i=0;i<entry.Items[1].AsInt64();i++)kinds.Add(entry.Items[0].AsString());ArenaShuffle(kinds);
   var gates=arenaObj.Require("gates").Items;var order=Enumerable.Range(0,gates.Count).ToList();ArenaShuffle(order);arenaQueue.Clear();
   for(int i=0;i<kinds.Count;i++)arenaQueue.Add(new ArenaEntry{Kind=kinds[i],Gate=order[i%order.Count],Delay=ArenaFirstSpawn+i*ArenaSpawnGap});
  }
  Vector2 ArenaSpawnPoint(int gateIndex,string kind)
  {
   var gate=arenaObj.Require("gates").Items[gateIndex].Items;var outward=new Vector2((float)gate[2].AsDouble(),(float)gate[3].AsDouble());
   var pos=(new Vector2((float)gate[0].AsDouble(),(float)gate[1].AsDouble())+outward+new Vector2(.5f,.5f))*32;
   if(outward.y<0&&Encounter.EnemyData(kind) is FoundationValue info)
   {
    float feet=(float)(StoryModel.G(info,"cell",FoundationValue.Number(16)).AsDouble()*StoryModel.G(info,"scale",FoundationValue.Number(2)).AsDouble()*.28+StoryModel.G(info,"radius",FoundationValue.Number(7)).AsDouble()+2);
    pos.y=Mathf.Min(pos.y,(float)gate[1].AsDouble()*32-feet);
   }
   return pos+new Vector2(Mathf.Abs(outward.y),Mathf.Abs(outward.x))*UnityEngine.Random.Range(-8f,8f);
  }
  void ArenaEmergeFoe(ArenaEntry entry)
  {
   var enemy=Encounter.Spawn(entry.Kind,entry.Position);
   // In the arena the fight is for honour, not loot, and every foe sees you.
   enemy.Data=InventoryModel.Replace(InventoryModel.Replace(enemy.Data,"sight",FoundationValue.Number(900)),"drops",FoundationValue.Array(Array.Empty<FoundationValue>()));
   enemy.Active=false;arenaFoes.Add(enemy);arenaEmerging.Add(new ArenaEmerging{Enemy=enemy});
   if(StoryModel.G(enemy.Data,"boss",FoundationValue.Boolean(false)).Kind=="bool"&&StoryModel.G(enemy.Data,"boss",FoundationValue.Boolean(false)).AsBool()){OnSound("boss");World.PlayRouteMusic("boss");}
  }
  void ArenaClearProjectiles(){if(Encounter!=null)foreach(var projectile in Encounter.Projectiles)projectile.Dead=true;}
  void ArenaRoundClear()
  {
   var rounds=ArenaInfo(ArenaRank).Require("rounds").Items;
   if(ArenaRound>=rounds.Count-1){ArenaVictory();return;}
   ArenaPhase="rest";arenaTimer=ArenaRest;ArenaClearProjectiles();
   ArenaBanner(Farm.Format("Ronde %d gehaald!",ArenaRound+1),Translate("Even rust..."),ArenaRest);OnSound("arena_crowd");
   if(Gameplay.State.Hp<Gameplay.MaxHp){Gameplay.State.Hp=Gameplay.State.Hp+1;OnSound("heart");}
  }
  void ArenaVictory()
  {
   ArenaPhase="done";string rank=ArenaRank;double time=ArenaRunTime;bool first=ArenaComplete(rank,time,out bool record);ReleaseArena();ArenaClearProjectiles();
   ArenaBanner(Farm.Format("%s gehaald!",ArenaName(rank)),Farm.Format(record&&!first?"Nieuw record: %s":"Tijd: %s",ArenaTime(time)),6);
   OnSound("arena_fanfare");OnSound("arena_crowd");World.PlayRouteMusic("arena");ArenaStatus="";World.RefreshRouteState();
  }
  bool ArenaDefeated()
  {
   if(ArenaPhase=="defeat")return true;if(!ArenaActive)return false;ArenaLose("defeat");return true;
  }
  public bool ArenaForfeit(){if(!ArenaActive)return false;ArenaLose("quit");return true;}
  void ArenaLose(string reason)
  {
   bool lost=reason=="defeat";ArenaPhase="defeat";Gameplay.State.SetFlag("arena_signed_"+ArenaRank,false);Gameplay.State.Transitioning=true;arenaTimer=ArenaDefeatTime+.4;
   ArenaBanner(Translate(lost?"Verslagen!":"Opgegeven"),Translate(lost?"Bruno vangt je op in de hal.":"Geen schande!"),ArenaDefeatTime+.4);OnSound(lost?"arena_defeat":"arena_gong");
   arenaQueue.Clear();arenaWarnings.Clear();arenaEmerging.Clear();foreach(var foe in arenaFoes){foe.Dead=true;foe.Active=false;}arenaFoes.Clear();ArenaClearProjectiles();
   arenaLostByDefeat=lost;
  }
  bool arenaLostByDefeat;
  void FinishArenaLoss()
  {
   var state=Gameplay.State;state.Hp=Gameplay.MaxHp;World.Motor.Stamina.Reset();state.SetFlag(arenaLostByDefeat?"arena_just_lost":"arena_just_quit",true);ReleaseArena();
   state.Transitioning=false;Combat.ResetTransient();ResetArena();
   if(!TryTravel("arena_hall","from_arena"))ShowMessage(T("De hal is niet bereikbaar.","The hall cannot be reached."));
   Save();World.RefreshRouteState();
  }
  void TickArena(double delta)
  {
   if(Session?.Current==null||Story==null)return;
   if(!ReferenceEquals(arenaBuiltFor,Session.Current))
   {
    arenaBuiltFor=Session.Current;bool wasActive=Access.ArenaRunActive;ResetArena();arenaObj=null;if(wasActive)ReleaseArena();
    foreach(var node in Session.Current.Root.Require("scene").Items)
    {
     if(!node.TryGet("script",out var script)||script.Kind!="string"||System.IO.Path.GetFileNameWithoutExtension(script.AsString())!="arena_master"||!node.TryGet("fields",out var fields))continue;
     arenaObj=StoryModel.G(fields,"obj",fields);
    }
    string signed=ArenaRegistered();if(arenaObj!=null&&signed!="")StartArenaRun(signed);
   }
   ArenaBannerTime=Math.Max(0,ArenaBannerTime-delta);arenaCheer=Math.Max(0,arenaCheer-delta);
   if(ArenaPhase=="defeat"){arenaTimer-=delta;if(arenaTimer<=0)FinishArenaLoss();return;}
   if(arenaObj==null||Encounter==null||Gameplay.State.InputLocked&&ArenaPhase!="intro")return;
   foreach(var entry in arenaEmerging){entry.Time+=delta;if(entry.Time>=ArenaEmerge&&!entry.Enemy.Dead)entry.Enemy.Active=true;}
   arenaEmerging.RemoveAll(entry=>entry.Time>=ArenaEmerge);
   switch(ArenaPhase)
   {
    case "intro":arenaTimer-=delta;if(arenaTimer<=0)StartArenaRound(0);break;
    case "fight":
     ArenaRunTime+=delta;foreach(var entry in arenaQueue)entry.Delay-=delta;
     while(arenaQueue.Count>0&&arenaQueue[0].Delay<=0){var entry=arenaQueue[0];arenaQueue.RemoveAt(0);entry.Position=ArenaSpawnPoint(entry.Gate,entry.Kind);arenaWarnings.Add(entry);OnSound("arena_gate");}
     foreach(var entry in arenaWarnings)entry.Time+=delta;
     while(arenaWarnings.Count>0&&arenaWarnings[0].Time>=ArenaWarn){var entry=arenaWarnings[0];arenaWarnings.RemoveAt(0);ArenaEmergeFoe(entry);}
     int before=arenaFoes.Count;arenaFoes.RemoveAll(e=>e.Dead||!Encounter.Actors.Contains(e));
     if(arenaFoes.Count<before&&arenaCheer<=0){arenaCheer=.6;OnSound("arena_cheer");}
     if(arenaQueue.Count==0&&arenaWarnings.Count==0&&arenaFoes.Count==0)ArenaRoundClear();
     else if(!arenaHeartThrown&&Gameplay.State.Hp<=2&&Gameplay.State.Hp>0)
     {
      // The crowd throws one heart per round when you are nearly down.
      arenaHeartThrown=true;ArenaHeartsThrown++;var field=arenaObj.Require("field").Items;var center=new Vector2((float)(field[0].AsDouble()+field[2].AsDouble()+1)*16,(float)(field[1].AsDouble()+field[3].AsDouble()+1)*16);
      var toCenter=center-World.Position;var spot=World.Position+(toCenter.magnitude>24?toCenter.normalized:Vector2.right)*90;
      SpawnLootPickup("heart",spot);OnSound("arena_cheer");StoryActions(Action("toast",StoryModel.S("Het publiek gooit een hartje!")));
     }
     break;
    case "rest":ArenaRunTime+=delta;arenaTimer-=delta;if(arenaTimer<=0)StartArenaRound(ArenaRound+1);break;
   }
   ArenaStatus=ArenaActive&&ArenaRound>=0?Farm.Format("%s · Ronde %d/%d · Vijanden %d · %s",ArenaName(ArenaRank),ArenaRound+1,ArenaInfo(ArenaRank).Require("rounds").Items.Count,ArenaFoesLeft,ArenaTime(ArenaRunTime)):"";
  }
  // --- Objects ------------------------------------------------------------------------------------------
  bool InteractArenaObject(RouteTarget target)
  {
   if(target.Kind=="arena_gong")
   {
    if(Access.ArenaRunActive){StoryActions(Action("talk",StoryModel.S(AreaText(target,"talk")==""?"arena_forfeit_ask":AreaText(target,"talk"))));SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);return true;}
    OnSound("arena_gong");SayAs(Translate("Gong"),"Een enorme bronzen gong. Bruno slaat hem aan het begin van elke ronde.");return true;
   }
   OnSound("select");
   if(AreaText(target,"board")=="scores")
   {
    var lines=new List<string>{Farm.Format("Beste tijden in de arena. Jouw titel: %s.",ArenaTitle())};foreach(string rank in ArenaOrder)lines.Add(ArenaName(rank)+": "+ArenaRecordText(rank));
    Story.RequestLines(Translate("Scorebord"),lines.ToArray());
   }
   else
   {
    var lines=new List<string>{Translate("De trofeeënplank van de arena.")};int owned=0;var slots=ArenaOrder.Select(rank=>ArenaInfo(rank).Require("trophy").AsString()).Concat(new[]{"arena_helm"}).ToArray();
    foreach(string item in slots)if(Gameplay.State.Count(item)>0){owned++;lines.Add(Translate(Inventory.ItemName(item))+": "+Translate(item=="arena_helm"?"een verzamelstuk voor kampioenen.":"gewonnen!"));}
    lines.Add(Translate(owned==0?"Nog niets op de plank. Win een rang en zet hier je eerste trofee neer!":owned<slots.Length?"Er is nog plek op de plank. Win meer rangen!":"Een volle plank! Jij bent een echte kampioen."));
    Story.RequestLines(Translate("Trofeeënplank"),lines.ToArray());
   }
   SyncDialogue();DialoguePanel?.NotifyOpened(storyInput);return true;
  }
  bool HandleArenaExternal(string name,FoundationValue action)
  {
   switch(name)
   {
    case "arena_enter":ArenaRegister(action.Items.Count>1?action.Items[1].AsString():"");return true;
    case "arena_cancel":ArenaCancel();return true;
    case "arena_forfeit":ArenaForfeit();return true;
   }
   return false;
  }
 }
}
