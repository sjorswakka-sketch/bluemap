using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using UnityEngine;
namespace BlueMapMigration.Combat
{
 public sealed class CombatCatalog
 {
  static FoundationValue source,rules;
  public FoundationValue Oracle=>source;public FoundationValue Catalogs=>rules;
  public CombatCatalog(){if(source==null){var asset=Resources.Load<TextAsset>("BlueMapCombatOracle");if(asset==null)throw new FormatException("Missing original combat oracle");source=FoundationJson.ParsePlain(asset.text);if(source.Require("schema").AsString()!="bluemap.combat.source-oracle.v1"||source.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid original combat reference");rules=InventoryModelChecks.DecodeOrdered(source.Require("catalogsOrdered"));}}
 }
}
