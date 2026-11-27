using System;
using BlueMapMigration.Foundation;
namespace BlueMapMigration.Professions
{
 /// <summary>Generator results in source call order. Live play draws them; equivalence checks replay recorded ones.</summary>
 public interface IFishingRandom
 {
  double Randf();
  double Range(double from,double to);
 }
 /// <summary>Unity's generator, narrowed to the source's single-precision results.</summary>
 public sealed class UnityFishingRandom : IFishingRandom
 {
  public double Randf()=>UnityEngine.Random.value;
  public double Range(double from,double to)=>(float)(UnityEngine.Random.value*((float)to-(float)from)+(float)from);
 }
 /// <summary>The original reel: hold to lift the zone, release to let it sink, keep the fish inside it.</summary>
 public sealed class FishingReel
 {
  readonly IFishingRandom random;
  readonly double startProgress,drainTime,lift,gravity,drag,bounce,fishBaseSpeed,fishMargin,tireTime,tired;
  public double ZoneSize {get;} public double ZonePos {get;private set;} public double ZoneVel {get;private set;} public double FishPos {get;private set;} public double FishTarget {get;private set;}
  public double FishSpeed {get;} public double FillTime {get;} public double Progress {get;private set;} public bool InZone {get;private set;} public string State {get;private set;}="bezig"; public double Elapsed {get;private set;} public double RetargetIn {get;private set;}
  public FishingReel(IFishingRandom random,FoundationValue constants,FoundationValue stats)
  {
   this.random=random??throw new ArgumentNullException(nameof(random));
   startProgress=constants.Require("startProgress").AsDouble();drainTime=constants.Require("drainTime").AsDouble();lift=constants.Require("lift").AsDouble();gravity=constants.Require("gravity").AsDouble();drag=constants.Require("drag").AsDouble();
   bounce=constants.Require("bounce").AsDouble();fishBaseSpeed=constants.Require("fishSpeed").AsDouble();fishMargin=constants.Require("fishMargin").AsDouble();tireTime=constants.Require("tireTime").AsDouble();tired=constants.Require("tired").AsDouble();
   ZoneSize=stats.Require("zone").AsDouble();FishSpeed=stats.Require("speed").AsDouble();FillTime=stats.Require("fill_time").AsDouble();Progress=startProgress;
   FishPos=random.Range(0.25,0.75);FishTarget=FishPos;ZonePos=FishPos;
  }
  static double MoveToward(double from,double to,double delta)=>Math.Abs(to-from)<=delta?to:from+Math.Sign(to-from)*delta;
  public void Update(double delta,bool holding)
  {
   if(State!="bezig")return;
   Elapsed+=delta;
   double accel=holding?lift:-gravity;
   ZoneVel+=(accel-ZoneVel*drag)*delta;ZonePos+=ZoneVel*delta;
   double half=ZoneSize/2.0;
   if(ZonePos<half){ZonePos=half;ZoneVel=Math.Abs(ZoneVel)*bounce;}
   else if(ZonePos>1.0-half){ZonePos=1.0-half;ZoneVel=-Math.Abs(ZoneVel)*bounce;}
   double strength=1.0+(tired-1.0)*Math.Min(Elapsed/tireTime,1.0);
   RetargetIn-=delta;
   if(RetargetIn<=0.0){RetargetIn=random.Range(0.5,1.4)/(FishSpeed*strength);FishTarget=random.Range(fishMargin,1.0-fishMargin);}
   FishPos=MoveToward(FishPos,FishTarget,fishBaseSpeed*FishSpeed*strength*delta);
   InZone=Math.Abs(FishPos-ZonePos)<=half;
   Progress+=InZone?delta/FillTime:-delta*strength/drainTime;
   if(Progress>=1.0){Progress=1.0;State="gevangen";}
   else if(Progress<=0.0){Progress=0.0;State="ontsnapt";}
  }
 }
 /// <summary>Cast, wait, bite, reel and result, with the original timings and one catch per landed fish.</summary>
 public sealed class FishingSession
 {
  readonly ProfessionsModel model; readonly IFishingRandom random; readonly double castTime,biteWindow,resultLock,haspelInterval,waitMin,waitMax; double haspelTimer;
  public string Phase {get;private set;}="idle"; public string Outcome {get;private set;}=""; public string CatchId {get;private set;}=""; public double PhaseTime {get;private set;} public double WaitTime {get;private set;}
  public FishingReel Reel {get;private set;} public bool Deep {get;private set;} public string ForcedCatch {get;set;}=""; public double ForcedWait {get;set;}=-1;
  public bool Active=>Phase!="idle"; public bool CanCastAgain=>Phase=="result"&&PhaseTime>=resultLock; public double BiteWindow=>biteWindow;
  public event Action<string> SoundRequested; public event Action<string> PhaseChanged;
  public FishingSession(ProfessionsModel model,IFishingRandom random)
  {
   this.model=model??throw new ArgumentNullException(nameof(model));this.random=random??throw new ArgumentNullException(nameof(random));var data=model.Fishing;
   castTime=data.Require("castTime").AsDouble();biteWindow=data.Require("biteWindow").AsDouble();resultLock=data.Require("resultLock").AsDouble();haspelInterval=data.Require("haspelInterval").AsDouble();waitMin=data.Require("waitMin").AsDouble();waitMax=data.Require("waitMax").AsDouble();
  }
  void Enter(string phase){Phase=phase;PhaseTime=0;PhaseChanged?.Invoke(phase);}
  public bool Start(bool deep)
  {
   if(Phase!="idle")return false;Deep=deep;model.State.SetUi("vissen",true);Cast();return true;
  }
  public void Close(){Phase="idle";Reel=null;model.State.SetUi("vissen",false);SoundRequested?.Invoke("select");PhaseChanged?.Invoke("idle");}
  void Cast(){Enter("cast");SoundRequested?.Invoke("dodge");}
  void Land(){Enter("wait");WaitTime=ForcedWait>=0?ForcedWait:random.Range(waitMin,waitMax);SoundRequested?.Invoke("meer_plons");}
  void Bite(){Enter("bite");CatchId=ForcedCatch!=""?ForcedCatch:model.RollCatch(random.Randf,Deep,model.Pity,model.GoldenCanBite);SoundRequested?.Invoke("meer_beet");}
  void StartReel(){Enter("reel");haspelTimer=0;Reel=new FishingReel(random,model.Fishing.Require("reel"),model.FishStats(CatchId));}
  void Finish(string result)
  {
   Enter("result");Outcome=result;Reel=null;
   if(result=="gevangen")model.LandCatch(CatchId,Deep);else SoundRequested?.Invoke("meer_ontsnapt");
  }
  /// <summary>The accept press: hook a biting fish, or cast again once the result card may close.</summary>
  public bool Press()
  {
   if(Phase=="bite"){StartReel();return true;}
   if(Phase=="result"&&PhaseTime>=resultLock){Cast();return true;}
   return false;
  }
  public void Tick(double delta,bool holding)
  {
   if(Phase=="idle")return;
   PhaseTime+=delta;
   switch(Phase)
   {
    case "cast":if(PhaseTime>=castTime)Land();break;
    case "wait":if(PhaseTime>=WaitTime)Bite();break;
    case "bite":if(PhaseTime>=biteWindow)Finish("te_laat");break;
    case "reel":
     Reel.Update(delta,holding);haspelTimer-=delta;
     if(Reel.InZone&&haspelTimer<=0){haspelTimer=haspelInterval;SoundRequested?.Invoke("meer_haspel");}
     if(Reel.State!="bezig")Finish(Reel.State);
     break;
   }
  }
 }
}
