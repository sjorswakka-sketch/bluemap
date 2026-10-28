using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.WorldAccess;
using UnityEngine;

namespace BlueMapMigration.Residents
{
 // Original node artwork remains separate from its geometry and from live actors.
 public sealed class ResidentSourceVisuals:IDisposable
 {
  sealed class Visual {public string Script,Kind,Current;public Vector2 Anchor;public SpriteRenderer Renderer;public Sprite Original;public Vector3 Position,Scale;public Material Material;public readonly Dictionary<string,FoundationValue> Variants=new Dictionary<string,FoundationValue>();}
  readonly Phase6Catalog catalog;readonly string original;readonly List<Visual> visuals=new List<Visual>();readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();
  public ResidentSourceVisuals(Phase6Catalog catalog,FoundationWorldSnapshot snapshot,IReadOnlyDictionary<string,GameObject> objects)
  {
   this.catalog=catalog;original=snapshot.ScenarioId;
   foreach(var node in snapshot.Root.Require("scene").Items)
   {
    string script=node.Require("script").AsString();
    if(!script.EndsWith("/lake_supper.gd",StringComparison.Ordinal)&&!script.EndsWith("/village_opening.gd",StringComparison.Ordinal))continue;
    string address=BlueMapMigration.Route.RouteSourcePresentation.Address(node);if(!objects.TryGetValue(address,out var obj))continue;
    var renderer=obj.GetComponent<SpriteRenderer>();if(renderer==null)continue;
    var v=new Visual{Script=script,Kind=Story.StoryModel.G(node.Require("fields"),"kind",Story.StoryModel.S("")).AsString(),Anchor=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin")),Renderer=renderer,Original=renderer.sprite,Position=renderer.transform.localPosition,Scale=renderer.transform.localScale,Material=renderer.sharedMaterial,Current=original};
    foreach(var art in WorldArtCatalog.Data.Require("nodes").Items)
    {
     if(art.Require("mapId").AsString()!=snapshot.MapId||art.Require("script").AsString()!=script)continue;
     var p=art.Require("position").Items;if(p[0].AsDouble()!=v.Anchor.x||p[1].AsDouble()!=v.Anchor.y)continue;
     v.Variants[art.Require("scenarioId").AsString()]=art;
    }
    visuals.Add(v);
   }
  }
  public void Tick(FoundationGameState state)
  {
   foreach(var v in visuals)
   {
    string desired=original;
    if(v.Script.EndsWith("/village_opening.gd",StringComparison.Ordinal)&&(!state.Flag("op_new_adventure")||state.Flag("op_water")))desired="opening_water_restored";
    else if(v.Script.EndsWith("/lake_supper.gd",StringComparison.Ordinal)&&state.Flag("ls_served"))desired="routines_evening";
    else if(v.Kind=="table"&&state.Flag("ls_served"))desired="routines_evening";
    if(desired==v.Current)continue;
    if(desired==original){v.Renderer.sprite=v.Original;v.Renderer.transform.localPosition=v.Position;v.Renderer.transform.localScale=v.Scale;v.Renderer.sharedMaterial=v.Material;v.Current=desired;continue;}
    if(!v.Variants.TryGetValue(desired,out var art))continue;
    string file=art.Require("file").AsString();if(!sprites.TryGetValue(file,out var sprite))
    {
     var texture=Resources.Load<Texture2D>("BlueMapWorldArt/"+file.Substring(0,file.Length-4));if(texture==null)throw new FormatException("Missing original resident artwork "+file);
     sprite=Sprite.Create(texture,new Rect(0,0,texture.width,texture.height),new Vector2(0,1),32,0,SpriteMeshType.FullRect);sprites.Add(file,sprite);
    }
    var offset=art.Require("offset").Items;v.Renderer.sprite=sprite;v.Renderer.sharedMaterial=catalog.premultipliedMaterial;v.Renderer.transform.localScale=Vector3.one;v.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(v.Anchor+new Vector2((float)offset[0].AsDouble(),(float)offset[1].AsDouble()));v.Current=desired;
   }
  }
  public void Dispose(){foreach(var sprite in sprites.Values)UnityEngine.Object.Destroy(sprite);sprites.Clear();}
 }
}
