using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
using UnityEngine;
namespace BlueMapMigration.Combat
{
 public sealed partial class CombatEncounter
 {
  // An access/gate projection refresh is not a real map departure. Keep every ongoing encounter and delayed death event.
  public void LoadRetained(FoundationWorldSnapshot map)
  {
   if(map==null)throw new ArgumentNullException(nameof(map));
   if(snapshot==null||snapshot.MapId!=map.MapId){Load(map);return;}
   var unmatched=new HashSet<EncounterActor>(actors.Where(actor=>actor.SourceNode!=null));
   snapshot=map;sourceSupport.Clear();presentation?.Clear();
   foreach(var node in map.Root.Require("scene").Items)
   {
    string script=node.Require("script").AsString();string address=string.Join("/",node.Require("address").Items.Select(value=>value.Kind=="string"?value.AsString():value.AsInt64().ToString(CultureInfo.InvariantCulture)));
    if(new[]{"/guardian_pillar.gd","/habitat_warning.gd","/coastal_warning.gd","/king_warning.gd"}.Any(script.EndsWith))sourceSupport.Add(address);
    if(!script.EndsWith("/enemy.gd",StringComparison.Ordinal)&&!script.EndsWith("/guardian.gd",StringComparison.Ordinal))continue;
    var fields=node.Require("fields");string kind=Text(fields,"kind",script.EndsWith("/guardian.gd",StringComparison.Ordinal)?"guardian":"slime");string unique=kind=="guardian"?"guardian_defeated":Text(fields,"unique_flag");Vector2 home=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));
    var existing=unmatched.FirstOrDefault(actor=>actor.Kind==kind&&actor.UniqueFlag==unique&&actor.Home.x==home.x&&actor.Home.y==home.y);
    if(existing!=null){unmatched.Remove(existing);existing.SourceNode=node;existing.Address=address;continue;}
    // Runtime actors, including a previously omitted dying actor, are never interpreted as a fresh map population.
    existing=actors.FirstOrDefault(actor=>actor.Kind==kind&&actor.UniqueFlag==unique&&actor.Home.x==home.x&&actor.Home.y==home.y&&actor.SourceNode==null&&actor.Address.StartsWith("retained-source/",StringComparison.Ordinal));
    if(existing!=null){existing.SourceNode=node;existing.Address=address;continue;}
    var data=Get(fields,"data");if(data.Entries.Count==0)data=Get(Get(rules,"enemies"),kind);var added=Spawn(kind,home,unique,address,data);added.SourceNode=node;added.PatrolRadius=Number(fields,"patrol_radius");added.Practice=Get(node,"groups").Items.Any(value=>value.Kind=="string"&&value.AsString()=="practice");
    if(kind=="guardian")foreach(var tile in Get(Get(fields,"obj"),"pillars").Items){var pillar=new EncounterPillar{Position=V(tile)*32+Vector2.one*16,Address=address+"/pillar/"+pillars.Count};pillars.Add(pillar);added.Pillars.Add(pillar);}
   }
   foreach(var actor in unmatched)
   {
    // Source child indices can be reused by a chest after a unique enemy disappears. Never hide that unrelated node.
    actor.SourceNode=null;actor.Address="retained-source/"+(serial++).ToString(CultureInfo.InvariantCulture);
    if(!actor.Dead&&actor.State!="dying"){actor.Dead=true;actor.Finished=true;}
   }
   Render();
  }
 }
}
