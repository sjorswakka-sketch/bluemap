using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Atmosphere;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Route
{
 /// <summary>The world atlas, travel between discovered rest altars, and the settings you can change while playing.</summary>
 public sealed partial class RouteWorldController
 {
  public WorldMapPanel WorldMap {get;private set;}
  List<TravelPoint> travelCache;FoundationValue travelFlags;
  void InitializeWorldMap()
  {
   WorldMap=new WorldMapPanel(Catalog,Translate,T,BindingLabel){Visited=MapVisited,CurrentMap=()=>Gameplay.State.MapId,MapTitle=MapTitle,RouteHint=AtlasRouteHint,TravelPoints=DiscoveredAltars,TravelBlocked=TravelBlockedReason};
   WorldMap.CloseRequested+=CloseModal;WorldMap.TravelRequested+=point=>TravelToAltar(point);travelCache=null;
  }
  void DetachWorldMap(){WorldMap=null;travelCache=null;}
  bool MapVisited(string id){var visits=Gameplay.State.Get("visited_maps");return visits.TryGet(id,out var seen)&&seen.Kind=="bool"&&seen.AsBool();}
  /// <summary>Where to go next towards a visited place; an unvisited place gives nothing away.</summary>
  string AtlasRouteHint(string id)
  {
   string here=Gameplay.State.MapId;if(WorldMapPanel.RegionFor(here)==id)return Translate("Je bent hier.");
   if(!WorldMap.RegionVisited(id))return Translate("Nog niet bezocht. Ontdek deze plek tijdens je reis.");
   var path=Story.Journey.Path(here,id);if(path.Count>1)return Farm.Format("Volgende doorgang: %s.",WorldMap.PlaceTitle(path[1]));
   return Translate("Volg de bestaande doorgangen naar deze plek.");
  }
  /// <summary>Every rest altar whose discovery is saved, with its own name and arrival.</summary>
  public IReadOnlyList<TravelPoint> DiscoveredAltars()
  {
   var flags=Gameplay.State.Get("flags");if(travelCache!=null&&ReferenceEquals(travelFlags,flags))return travelCache;travelFlags=flags;travelCache=new List<TravelPoint>();
   foreach(var row in flags.Entries)
   {
    string key=row.Key.AsString();if(!key.StartsWith("altaar_",StringComparison.Ordinal)||row.Value.Kind!="bool"||!row.Value.AsBool())continue;
    var parts=key.Split('_');if(parts.Length<4||!Int32.TryParse(parts[parts.Length-2],out int x)||!Int32.TryParse(parts[parts.Length-1],out int y))continue;
    string map=String.Join("_",parts.Skip(1).Take(parts.Length-3));if(!Maps.Contains(map,StringComparer.Ordinal))continue;
    var source=repository.Read(map);string name=source.MapData.TryGet("name",out var title)?title.AsString():map,spawn="";
    foreach(var node in source.Root.Require("scene").Items)
    {
     if(!node.TryGet("script",out var script)||script.Kind!="string"||System.IO.Path.GetFileNameWithoutExtension(script.AsString())!="savepoint"||!node.TryGet("globalTransform",out var transform))continue;
     var at=FoundationCoordinates.Vector(transform.Require("origin"));if((int)(at.x/32)!=x||(int)(at.y/32)!=y||!node.TryGet("fields",out var fields))continue;
     var obj=StoryModel.G(fields,"obj",fields);name=StoryModel.G(obj,"name",StoryModel.S(name)).AsString();spawn=StoryModel.G(obj,"spawn",StoryModel.S("altar")).AsString();
    }
    if(!source.Arrivals.Any(a=>a.Name==spawn))spawn="";
    travelCache.Add(new TravelPoint{Map=map,Key=key,Name=name,Spawn=spawn,Tile=new Vector2(x,y)});
   }
   travelCache=travelCache.OrderBy(p=>Array.IndexOf(Maps.ToArray(),p.Map)).ThenBy(p=>p.Key,StringComparer.Ordinal).ToList();return travelCache;
  }
  public string TravelBlockedReason()
  {
   var state=Gameplay.State;
   if(state.Ended)return Translate("Je kunt nu niet reizen.");
   if(state.Transitioning)return Translate("Wacht even, je bent al onderweg.");
   if(Gameplay.DialogueOpen)return Translate("Je kunt niet reizen tijdens een gesprek.");
   if(ActiveBoss!=null)return Translate("Je kunt niet reizen tijdens een baasgevecht!");
   if(Access.ArenaRunActive)return Translate("Je kunt niet reizen tijdens een arenagevecht!");
   if(DiscoveredAltars().Count==0)return Translate("Je hebt nog geen altaar ontdekt.");
   return "";
  }
  /// <summary>Travel to a discovered altar; nothing is spent and nothing is lost.</summary>
  public bool TravelToAltar(TravelPoint point)
  {
   string reason=TravelBlockedReason();if(reason==""&&(point==null||!Gameplay.State.Flag(point.Key)))reason=Translate("Dat altaar heb je nog niet ontdekt.");
   if(reason!=""){ShowMessage(reason);OnSound("error");return false;}
   CloseModal();OnSound("wereld_reis");var beside=new Vector2(point.Tile.x*32+16,(point.Tile.y+1)*32+16);bool arrived;
   if(point.Map==Gameplay.State.MapId){World.Teleport(point.Spawn!=""?Session.Current.Arrivals.First(a=>a.Name==point.Spawn).Resolved:beside);World.Motor.StopForTransition();World.FocusCameraOnPlayer();arrived=true;}
   else
   {
    arrived=TryTravel(point.Map,point.Spawn!=""?point.Spawn:(repository.Read(point.Map).Arrivals.FirstOrDefault(a=>a.Name=="start")??repository.Read(point.Map).Arrivals[0]).Name);
    if(arrived&&point.Spawn==""&&GardenSpawnFitsAt(beside)){World.Teleport(beside);World.FocusCameraOnPlayer();}
   }
   if(!arrived)return false;Gameplay.State.SetFlag("wereld_snel_gereisd",true);Save();World.RefreshRouteState();return true;
  }
  public bool OpenWorldMap(string tab="map")
  {
   if(!Running||WorldMap==null||Gameplay.State.Ended)return false;SetModal("world_map");WorldMap.SetControllerActive(ControllerActive);WorldMap.Open(tab);WorldMap.NotifyOpened(storyInput);return true;
  }
  bool HandleWorldMapModal(InputFrame frame)
  {
   if(Modal!="world_map")return false;WorldMap.SetControllerActive(ControllerActive);WorldMap.HandleInput(frame,inventoryFrameDelta);return true;
  }
  // --- Settings while playing -----------------------------------------------------------------------------
  /// <summary>Switch between Dutch and English; every panel reads the new language at once.</summary>
  public bool ToggleLanguage()
  {
   if(Persistence==null)return false;var old=Persistence.Preferences;return Persistence.SetPreferences(new LegacyPreferences(old.Locale=="en"?"nl":"en",old.Muted,old.MusicVolume,old.SfxVolume))&&ApplyPreferences();
  }
  public bool ToggleMute()
  {
   if(Persistence==null)return false;var old=Persistence.Preferences;return Persistence.SetPreferences(new LegacyPreferences(old.Locale,!old.Muted,old.MusicVolume,old.SfxVolume))&&ApplyPreferences();
  }
  /// <summary>Step the music or effects volume by a tenth; it wraps from full back to silent.</summary>
  public bool StepVolume(bool music)
  {
   if(Persistence==null)return false;var old=Persistence.Preferences;double Next(double v){double n=Math.Round(v*10)+1;return n>10?0:n/10;}
   return Persistence.SetPreferences(new LegacyPreferences(old.Locale,old.Muted,music?Next(old.MusicVolume):old.MusicVolume,music?old.SfxVolume:Next(old.SfxVolume)))&&ApplyPreferences();
  }
  bool ApplyPreferences(){World.SetPersistencePreferences(Persistence.Preferences,true);foreach(var target in targets)if(target.Kind=="living_object"||target.Kind=="regional_object"||target.Kind=="coastal_adventure")target.Label=target.Kind=="coastal_adventure"?CoastLabel(target):AreaLabel(target);return true;}
  public string SettingsLine(int index)
  {
   var p=Persistence?.Preferences;if(p==null)return "";
   switch(index)
   {
    case 0:return T("Taal: Nederlands","Language: English");
    case 1:return T("Muziek: ","Music: ")+Math.Round(p.MusicVolume*100)+"%";
    case 2:return T("Geluid: ","Sound: ")+Math.Round(p.SfxVolume*100)+"%";
   }
   return p.Muted?T("Geluid dempen: aan","Mute: on"):T("Geluid dempen: uit","Mute: off");
  }
 }
}
