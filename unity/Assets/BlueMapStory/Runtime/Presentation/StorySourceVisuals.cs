using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.WorldAccess;
using UnityEngine;
namespace BlueMapMigration.Story
{
 /// <summary>Swap only individual original source-node captures; never import a fixture's gameplay state or move map objects.</summary>
 public sealed class StorySourceVisuals:IDisposable
 {
  sealed class Visual{public string Address,Kind,Id,OriginalKey,CurrentKey;public SpriteRenderer Renderer;public Sprite Original;public Material Material;public Vector3 Position,Scale;public Vector2 Anchor;}
  readonly Phase6Catalog catalog;readonly FoundationWorldSnapshot snapshot;readonly List<Visual> visuals=new List<Visual>();readonly Dictionary<string,Sprite> sprites=new Dictionary<string,Sprite>();readonly Dictionary<string,FoundationValue> variants=new Dictionary<string,FoundationValue>();
  public int ChangedVisuals=>visuals.Count(v=>v.CurrentKey!=v.OriginalKey);
  public string SourceVisualKey(string address)=>visuals.FirstOrDefault(v=>v.Address==address)?.CurrentKey??"";
  public StorySourceVisuals(Phase6Catalog catalog,FoundationWorldSnapshot snapshot,IReadOnlyDictionary<string,GameObject> objects)
  {
   this.catalog=catalog;this.snapshot=snapshot;
   foreach(var node in snapshot.Root.Require("scene").Items)
   {
    string script=node.Require("script").AsString();if(!script.EndsWith("/fountain.gd",StringComparison.Ordinal)&&!script.EndsWith("/opening_device.gd",StringComparison.Ordinal)&&!script.EndsWith("/route_object.gd",StringComparison.Ordinal))continue;
    string address=BlueMapMigration.Route.RouteSourcePresentation.Address(node);if(!objects.TryGetValue(address,out var go))continue;var renderer=go.GetComponent<SpriteRenderer>();if(renderer==null)continue;
    var f=node.Require("fields");string kind=script.EndsWith("/fountain.gd",StringComparison.Ordinal)?"fountain":StoryModel.G(f,"kind",StoryModel.S("")).AsString();string id=StoryModel.G(f,"id",StoryModel.S("")).AsString();
    if(!new[]{"fountain","grate","wheel","memorial","bowl"}.Contains(kind))continue;
    if((kind=="fountain"||kind=="grate"||kind=="wheel")&&snapshot.MapId!="village")continue;
    Vector2 anchor=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));
    var visual=new Visual{Address=address,Kind=kind,Id=id,Renderer=renderer,Original=renderer.sprite,Material=renderer.sharedMaterial,Position=renderer.transform.localPosition,Scale=renderer.transform.localScale,Anchor=anchor,OriginalKey=snapshot.ScenarioId,CurrentKey=snapshot.ScenarioId};visuals.Add(visual);
    foreach(var art in WorldArtCatalog.Data.Require("nodes").Items)
    {if(art.Require("mapId").AsString()!=snapshot.MapId||art.Require("script").AsString()!=script)continue;var pos=art.Require("position").Items;if(pos[0].AsDouble()!=anchor.x||pos[1].AsDouble()!=anchor.y)continue;variants[address+"/"+art.Require("scenarioId").AsString()]=art;}
   }
  }
  public void Tick(FoundationGameState state)
  {
   bool flowing=!state.Flag("op_new_adventure")||state.Get("ng_plus").AsInt64()!=0||state.Flag("op_water");
   foreach(var v in visuals)
   {
    string key=v.OriginalKey;
    switch(v.Kind)
    {case "fountain":case "wheel":if(flowing)key="opening_water_restored";break;case "grate":if(state.Flag("op_grate"))key="opening_water_restored";break;case "memorial":if(state.Flag("rf_memorial"))key=state.Flag("rf_guide")?"route_memorial_guide":"route_memorial_guard";break;case "bowl":if(state.Flag(v.Id))key="route_echo_end";break;}
    if(key==v.CurrentKey)continue;
    if(key==v.OriginalKey){v.Renderer.sprite=v.Original;v.Renderer.sharedMaterial=v.Material;v.Renderer.transform.localPosition=v.Position;v.Renderer.transform.localScale=v.Scale;v.CurrentKey=key;continue;}
    if(!variants.TryGetValue(v.Address+"/"+key,out var art))throw new FormatException("Missing original story visual: "+snapshot.MapId+"/"+v.Address+"/"+key);
    string file=art.Require("file").AsString();if(!sprites.TryGetValue(file,out var sprite))
    {var texture=Resources.Load<Texture2D>("BlueMapWorldArt/"+file.Substring(0,file.Length-4));if(texture==null||texture.width!=art.Require("width").AsInt64()||texture.height!=art.Require("height").AsInt64())throw new FormatException("Invalid original story capture "+file);sprite=Sprite.Create(texture,new Rect(0,0,texture.width,texture.height),new Vector2(0,1),32,0,SpriteMeshType.FullRect);sprites.Add(file,sprite);}
    var offset=art.Require("offset").Items;v.Renderer.sprite=sprite;v.Renderer.sharedMaterial=catalog.premultipliedMaterial;v.Renderer.transform.localScale=Vector3.one;v.Renderer.transform.localPosition=FoundationCoordinates.ToUnity(v.Anchor+new Vector2((float)offset[0].AsDouble(),(float)offset[1].AsDouble()));v.CurrentKey=key;
   }
  }
  public void Dispose(){foreach(var sprite in sprites.Values)UnityEngine.Object.Destroy(sprite);sprites.Clear();}
 }
}
