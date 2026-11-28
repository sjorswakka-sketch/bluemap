using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Atmosphere;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>
 /// Achievements unlock when their original conditions hold, are announced once and stay earned;
 /// the bestiary lists every creature you have defeated at least once.
 /// </summary>
 public sealed partial class RouteWorldController
 {
  public RecordsPanel Records {get;private set;}
  public string AchievementBanner {get;private set;}="";public double AchievementBannerTime {get;private set;} public int AchievementsUnlockedThisSession {get;private set;}
  static FoundationValue achievementCatalog;IDisposable achievementSubscription;readonly Queue<string> achievementQueue=new Queue<string>();readonly HashSet<string> achievementUnsupported=new HashSet<string>(StringComparer.Ordinal);
  public static FoundationValue AchievementCatalog
  {
   get
   {
    if(achievementCatalog!=null)return achievementCatalog;var asset=Resources.Load<TextAsset>("BlueMapAchievements");if(asset==null)throw new FormatException("Missing original achievements");
    var document=FoundationJson.ParsePlain(asset.text);if(document.Require("schema").AsString()!="bluemap.achievements.runtime-catalog.v1")throw new FormatException("Invalid achievements catalog");
    achievementCatalog=document.Require("achievements");return achievementCatalog;
   }
  }
  void InitializeRecords()
  {
   Records=new RecordsPanel(Catalog,Translate,T,BindingLabel){Achievements=AchievementRows,Beasts=BeastRows};Records.CloseRequested+=CloseModal;
   achievementSubscription=Gameplay.State.Events.Subscribe<FoundationAchievementCheckRequested>(request=>CheckAchievements());achievementQueue.Clear();AchievementBanner="";AchievementBannerTime=0;
  }
  void DetachRecords(){achievementSubscription?.Dispose();achievementSubscription=null;Records=null;}
  public bool AchievementOwned(string id){var owned=Gameplay.State.Get("achievements");return owned.Kind=="array"?owned.Items.Any(v=>v.Kind=="string"&&v.AsString()==id):owned.TryGet(id,out var value)&&(value.Kind!="bool"||value.AsBool());}
  public int AchievementsOwned=>AchievementCatalog.Items.Count(row=>AchievementOwned(row.Require("id").AsString()));
  /// <summary>Unlock every achievement whose conditions now hold. One without conditions is never earned by itself.</summary>
  public int CheckAchievements()
  {
   if(Story==null)return 0;int unlocked=0;
   foreach(var row in AchievementCatalog.Items)
   {
    string id=row.Require("id").AsString();var tests=row.Require("if");if(tests.Items.Count==0||AchievementOwned(id)||achievementUnsupported.Contains(id))continue;bool met;
    try{met=Story.CheckAll(tests);}catch(Exception){achievementUnsupported.Add(id);continue;}
    if(!met)continue;UnlockAchievement(id);unlocked++;
   }
   return unlocked;
  }
  public bool UnlockAchievement(string id)
  {
   if(AchievementOwned(id)||!AchievementCatalog.Items.Any(row=>row.Require("id").AsString()==id))return false;
   var owned=Gameplay.State.Get("achievements");var list=owned.Kind=="array"?owned.Items.ToList():owned.Entries.Select(row=>row.Key).ToList();list.Add(StoryModel.S(id));Gameplay.State.Set("achievements",FoundationValue.Array(list));achievementQueue.Enqueue(id);AchievementsUnlockedThisSession++;return true;
  }
  string AchievementName(string id){var row=AchievementCatalog.Items.First(r=>r.Require("id").AsString()==id);return Translate(row.Require("name").AsString());}
  void TickRecords(double delta)
  {
   if(Records==null)return;
   if(AchievementBannerTime>0){AchievementBannerTime-=delta;if(AchievementBannerTime<=0)AchievementBanner="";}
   if(AchievementBannerTime<=0&&achievementQueue.Count>0&&Modal==""&&!Gameplay.DialogueOpen)
   {
    // Several at once (an old save, for instance) pass more quickly, as in the source.
    AchievementBannerTime=achievementQueue.Count<=2?4.0:1.8;AchievementBanner=AchievementName(achievementQueue.Dequeue());OnSound("wereld_prestatie");
   }
  }
  IReadOnlyList<RecordRow> AchievementRows()
  {
   var rows=new List<RecordRow>();
   foreach(var row in AchievementCatalog.Items)
   {
    string id=row.Require("id").AsString();bool done=AchievementOwned(id),secret=row.Require("secret").AsBool()&&!done;
    rows.Add(new RecordRow{Id=id,Known=done,Title=secret?"???":Translate(row.Require("name").AsString()),Mark=done?"✓":"",
     Detail=(secret?Translate("Een geheime prestatie. Blijf het spel ontdekken!"):Translate(row.Require("desc").AsString()))+"\n\n"+Translate("Die houd je, ook als je een nieuw spel begint.")});
   }
   return rows;
  }
  IReadOnlyList<RecordRow> BeastRows()
  {
   var rows=new List<RecordRow>();if(Encounter==null)return rows;var kills=Gameplay.State.Get("kills_by");
   foreach(string kind in Encounter.EnemyKinds)
   {
    var data=Encounter.EnemyData(kind);long count=kills.TryGet(kind,out var value)&&(value.Kind=="int"||value.Kind=="float")?(long)value.AsDouble():0;bool known=count>0;
    if(!known){rows.Add(new RecordRow{Id=kind,Known=false,Title="???",Mark="",Detail=Translate("Dit beest ken je nog niet.\nVersla hem één keer, dan komt hij in je boek te staan!")});continue;}
    long damage=(long)StoryModel.G(data,"damage",FoundationValue.Integer(1)).AsDouble();string hits=Farm.Format(Professions.Plural("%d hartje","%d hartjes",damage),damage);
    if(data.TryGet("slam_damage",out var slam))hits=Farm.Format("%s (klap: %d)",hits,(long)slam.AsDouble());
    var lines=new List<string>();if(StoryModel.G(data,"boss",FoundationValue.Boolean(false)).Kind=="bool"&&StoryModel.G(data,"boss",FoundationValue.Boolean(false)).AsBool())lines.Add(Translate("Baas"));
    lines.Add(Farm.Format("Levens:  %d",(long)StoryModel.G(data,"hp",FoundationValue.Integer(1)).AsDouble()));lines.Add(Farm.Format("Schade:  %s",hits));lines.Add(Farm.Format("Verslagen:  %d",count));
    string desc=StoryModel.G(data,"desc",StoryModel.S("")).AsString();if(desc!="")lines.Add("\n"+Translate(desc));
    rows.Add(new RecordRow{Id=kind,Known=true,Title=Translate(StoryModel.G(data,"name",StoryModel.S(kind)).AsString()),Mark="x"+count,Detail=String.Join("\n",lines)});
   }
   return rows;
  }
  public bool OpenRecords(string tab)
  {
   if(!Running||Records==null||Gameplay.State.Ended)return false;SetModal("records");Records.SetControllerActive(ControllerActive);Records.Open(tab);Records.NotifyOpened(storyInput);return true;
  }
  bool HandleRecordsModal(InputFrame frame){if(Modal!="records")return false;Records.SetControllerActive(ControllerActive);Records.HandleInput(frame,inventoryFrameDelta);return true;}
 }
}
