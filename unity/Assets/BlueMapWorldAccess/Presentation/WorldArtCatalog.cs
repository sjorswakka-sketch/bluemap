using System;using System.Linq;using BlueMapMigration.Foundation;using UnityEngine;
namespace BlueMapMigration.WorldAccess
{
    public static class WorldArtCatalog
    {
        public const string ResourcePath="BlueMapWorldArt/index";
        private static FoundationValue data;
        public static FoundationValue Data {get{if(data==null){var source=Resources.Load<TextAsset>(ResourcePath);if(source==null)throw new FormatException("Original world art is missing.");data=FoundationJson.ParsePlain(source.text);if(data.Require("schemaVersion").AsInt64()!=1||data.Require("gameSaveAccessed").AsBool()||data.Require("alphaMode").AsString()!="premultiplied")throw new FormatException("Invalid original world art contract.");}return data;}}
        public static bool UsesRouteArt(FoundationWorldSnapshot snapshot)=>snapshot.ScenarioId=="fresh_baseline"&&new[]{"village","player_home","forest_edge","forest"}.Contains(snapshot.MapId);
        public static FoundationValue For(FoundationWorldSnapshot snapshot)
        {
            if(UsesRouteArt(snapshot))return null;
            if(!Data.Require("snapshots").Items.Any(value=>value.Require("mapId").AsString()==snapshot.MapId&&value.Require("scenarioId").AsString()==snapshot.ScenarioId))throw new FormatException("Original visual state has no captured source identity: "+snapshot.MapId+"/"+snapshot.ScenarioId);
            return Data;
        }
    }
}
