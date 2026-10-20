using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using UnityEngine;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    public static class LegacySaveChecks
    {
        public static int OracleCases { get; private set; }
        public static void Verify(FoundationWorldRepository repository,Action<string,bool> check)
        {
            var importer=new LegacySaveImporter(repository);
            var oracle=FoundationJson.ParsePlain(Resources.Load<TextAsset>("BlueMapSaveOracle").text);
            OracleCases=0;
            foreach(var sourceCase in oracle.Require("cases").Items)
            {
                string id=sourceCase.Require("id").AsString();
                var actual=importer.Import(Encoding.UTF8.GetBytes(sourceCase.Require("inputJson").AsString()));
                string failure=Difference(actual.State.Snapshot(),sourceCase.Require("expected"),id);
                if(failure!=null)throw new InvalidOperationException("Original save import differs: "+failure);
                check("persistence_save_source_"+id,true);OracleCases++;
                foreach(string key in FoundationGameState.SaveKeys)if(!actual.State.Fields.ContainsKey(key))throw new InvalidOperationException("Save field missing: "+key);
                check("persistence_save_fields_"+id,actual.State.Fields.Count==34&&actual.State.UseLoadPosition&&actual.State.SpawnName=="start"&&!actual.State.InGame);
            }
            foreach(var sourceCase in oracle.Require("corrupt").Items)
            {
                bool accepted=true;try{importer.Import(Encoding.UTF8.GetBytes(sourceCase.Require("inputJson").AsString()));}catch(FormatException){accepted=false;}
                check("persistence_save_corrupt_source_"+OracleCases,accepted==sourceCase.Require("accepted").AsBool());OracleCases++;
            }
            check("persistence_save_source_oracle_complete",OracleCases==30);
            var unknown=importer.Import(Encoding.UTF8.GetBytes("{\"version\":999,\"kind\":\"modded\",\"future\":{\"kind\":\"future_tag\",\"value\":123},\"homestead\":{\"future_crop\":42}}"));
            check("persistence_save_unknown_fields_retained",unknown.Raw.Require("kind").AsString()=="modded"&&unknown.Raw.Require("future").Require("kind").AsString()=="future_tag"&&unknown.Raw.Require("homestead").Require("future_crop").AsInt64()==42&&unknown.Raw.Require("version").AsInt64()==999);
            var precise=importer.Import(Encoding.UTF8.GetBytes("{\"coins\":9007199254740993,\"inventory\":{\"future_stack\":-9007199254740993},\"pos\":[16777217,-0]}"));
            check("persistence_save_binary64_projection_keeps_raw_int64",precise.Raw.Require("coins").AsInt64()==9007199254740993L&&precise.State.Coins==9007199254740992L&&precise.Raw.Require("inventory").Require("future_stack").AsInt64()==-9007199254740993L&&precise.State.Count("future_stack")==-9007199254740992L);
            check("persistence_save_float32_position_keeps_signed_zero",precise.State.Position.Items[0].AsDouble()==16777216.0&&precise.State.Position.Items[1].DoubleBits==0x8000000000000000UL);
            var legacy=importer.Import(Encoding.UTF8.GetBytes("{\"flags\":{\"golem_ruins\":false,\"cat_found\":false}}"));
            check("persistence_save_legacy_flags_and_atlas_distinct",legacy.State.Flag("golem_ruins")&&legacy.State.Get("kills_by").Require("golem").AsInt64()==1&&!legacy.State.Get("visited_maps").TryGet("ruins",out _)&&legacy.State.Get("talked").Items[0].AsString()=="muis_bos");
            check("persistence_save_new_adventure_flag_not_leaked",!importer.Import(Encoding.UTF8.GetBytes("{}")).State.Flag("op_new_adventure"));
            var merged=importer.Import(Encoding.UTF8.GetBytes("{\"achievements\":[\"existing\",\"new\"]}"),FoundationJson.ParsePlain("{\"meta_only\":false,\"existing\":true}"));
            check("persistence_save_global_meta_keys_merge_without_rewards",merged.State.Get("achievements").Items.Count==3&&merged.State.Get("achievements").Items[0].AsString()=="meta_only"&&merged.State.Coins==0);
            int refused=0;foreach(var invalid in new[]{new byte[]{0xff},Encoding.UTF8.GetBytes("{\"coins\":1,\"coins\":2}"),Encoding.UTF8.GetBytes("{\"map\":\"unreleased_map\"}"),Encoding.UTF8.GetBytes("{\"pos\":[1]}"),Encoding.UTF8.GetBytes("{\"quests\":{\"x\":{\"step\":1}}}")})try{importer.Import(invalid);}catch(FormatException){refused++;}
            check("persistence_save_malformed_imports_do_not_construct_partial_state",refused==5);
            check("persistence_save_model_checks_ran",true);
        }
        private static string Difference(FoundationValue actual,FoundationValue expected,string path)
        {
            if(expected.TryGet("$f64",out var bits))
            {
                if(actual.Kind!="float"&&actual.Kind!="int")return path+": expected source number, got "+actual.Kind;
                string actualBits=BitConverter.ToString(BitConverter.GetBytes(actual.AsDouble())).Replace("-","").ToLowerInvariant();
                return actualBits==bits.AsString()?null:path+": numeric bytes "+actualBits+" != "+bits.AsString();
            }
            if(expected.Kind=="object"||expected.Kind=="dictionary")
            {
                if(actual.Kind!="object"&&actual.Kind!="dictionary")return path+": expected object, got "+actual.Kind;
                if(actual.Entries.Count!=expected.Entries.Count)return path+": field count "+actual.Entries.Count+" != "+expected.Entries.Count;
                foreach(var pair in expected.Entries)
                {if(!actual.TryGet(pair.Key.AsString(),out var child))return path+": missing "+pair.Key.AsString();string failure=Difference(child,pair.Value,path+"."+pair.Key.AsString());if(failure!=null)return failure;}return null;
            }
            if(expected.Kind=="array")
            {
                if(actual.Kind!="array"||actual.Items.Count!=expected.Items.Count)return path+": array shape differs";
                for(int i=0;i<expected.Items.Count;i++){string failure=Difference(actual.Items[i],expected.Items[i],path+"["+i+"]");if(failure!=null)return failure;}return null;
            }
            if(actual.Kind!=expected.Kind)return path+": kind "+actual.Kind+" != "+expected.Kind;
            if(actual.Kind=="int")return actual.AsInt64()==expected.AsInt64()?null:path+": integer differs";
            if(actual.Kind=="string")return actual.AsString()==expected.AsString()?null:path+": text differs";
            if(actual.Kind=="bool")return actual.AsBool()==expected.AsBool()?null:path+": boolean differs";
            return actual.Kind=="nil"?null:path+": unsupported source oracle scalar";
        }
    }
}
