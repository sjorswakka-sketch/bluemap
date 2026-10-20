using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using UnityEngine;
using BlueMapMigration.Foundation;

namespace BlueMapMigration.Persistence
{
    public sealed class LegacySaveImport
    {
        public FoundationValue Raw { get; }
        public FoundationGameState State { get; }
        public IReadOnlyList<string> Warnings { get; }
        internal LegacySaveImport(FoundationValue raw, FoundationGameState state, List<string> warnings)
        { Raw = raw; State = state; Warnings = warnings.AsReadOnly(); }
    }

    /// <summary>Pure source-compatible projection; original bytes remain in the separate transactional store.</summary>
    public sealed partial class LegacySaveImporter
    {
        private readonly FoundationValue rules;
        private readonly HashSet<string> maps, solidChars;
        private readonly HashSet<Cell> fixedCells, baseReach;
        public FoundationValue Rules => rules;
        public LegacySaveImporter(FoundationWorldRepository repository)
        {
            if (repository == null) throw new ArgumentNullException(nameof(repository));
            var asset = Resources.Load<TextAsset>("BlueMapSaveOracle");
            if (asset == null) throw new FormatException("Missing frozen source save rules.");
            var source = FoundationJson.ParsePlain(asset.text);
            if (source.Require("schema").AsString() != "bluemap.persistence.save.source-oracle.v1") throw new FormatException("Unknown source save rules.");
            rules = source.Require("rules"); maps = Strings(rules.Require("maps")); solidChars = Strings(rules.Require("solidChars"));
            fixedCells = CellSet(rules.Require("yardFixed")); baseReach = CellSet(rules.Require("yardBaseReach"));
            foreach (string id in repository.MapIds) if (!maps.Contains(id)) throw new FormatException("Save geography disagrees with source world.");
        }
        public LegacySaveImport Import(byte[] utf8, FoundationValue metaAchievements = null)
        {
            if (utf8 == null || utf8.Length > 16 * 1024 * 1024) throw new FormatException("Save is absent or exceeds the import limit.");
            string text;
            try { text = new UTF8Encoding(false, true).GetString(utf8); } catch (DecoderFallbackException e) { throw new FormatException("Save is not UTF-8.", e); }
            if (text.Length > 0 && text[0] == '\uFEFF') text = text.Substring(1);
            var preservedRaw = FoundationJson.ParsePlain(text);
            if (!Obj(preservedRaw)) throw new FormatException("Save root must be an object.");
            // Godot's JSON reader produces binary64 for every JSON number.
            // Preserve the original int64/lexical tree separately; use the source
            // numeric semantics only in the gameplay projection, never ConfigFile.
            var raw = SourceJsonNumbers(preservedRaw);
            var warnings = new List<string>();
            var values = new Dictionary<string, FoundationValue>(StringComparer.Ordinal);
            values["version"] = I(1);
            string map = Str(Get(raw,"map",S("village"))), weapon = Str(Get(raw,"weapon",S("wood")));
            if (!maps.Contains(map)) throw new FormatException("Save refers to an unknown map; original bytes remain available.");
            values["map"] = S(map); values["weapon"] = S(weapon);
            var position = Get(raw,"pos",A(I(0),I(0)));
            if (position.Kind != "array" || position.Items.Count != 2 || !Numeric(position.Items[0]) || !Numeric(position.Items[1])) throw new FormatException("Save position must contain two finite coordinates.");
            values["pos"] = A(N((double)(float)position.Items[0].AsDouble()),N((double)(float)position.Items[1].AsDouble()));
            foreach(string key in new[]{"coins","kills","ng_plus","day_count","rolls","potions_drunk","deaths","boss_deaths"}) values[key]=I(Int(Get(raw,key,I(0))));
            double clock = Real(Get(raw,"play_time",N(0))); values["play_time"]=N(clock);
            double day=Real(Get(raw,"day_time",N(.15))); double wrapped=day%1; if(wrapped<0)wrapped+=1; if(wrapped==0)wrapped=0; values["day_time"]=N(wrapped);
            values["hero_xp"]=I(NormalizeHeroXp(Get(raw,"hero_xp",I(0))));
            var inventory = new Dictionary<string,FoundationValue>(StringComparer.Ordinal);
            foreach(var pair in Dict(Get(raw,"inventory",Empty())).Entries)
            {
                string id=pair.Key.AsString();
                if(Slot(id)!="") { if(Owns(Get(raw,"inventory",Empty()),id))inventory[id]=I(1); }
                else inventory[id]=I(Int(pair.Value));
            }
            values["inventory"]=O(inventory);
            values["equipment"]=NormalizeEquipment(Get(raw,"equipment",Empty()),values["inventory"]);
            values["appearance"]=NormalizeAppearance(Get(raw,"appearance",Empty()));
            values["clothing"]=NormalizeClothing(Get(raw,"clothing",Empty()),values["inventory"]);
            var flags=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);
            foreach(var pair in Dict(Get(raw,"flags",Empty())).Entries)flags[pair.Key.AsString()]=B(true);
            values["flags"]=O(flags);
            var quests=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);
            foreach(var pair in Dict(Get(raw,"quests",Empty())).Entries)
            {
                var q=Dict(pair.Value); var questState=q.Require("state"); if(questState.Kind!="string")throw new FormatException("Quest state must be text.");
                quests[pair.Key.AsString()]=O("state",questState,"step",I(Int(q.Require("step"))));
            }
            values["quests"]=O(quests);
            foreach(string field in new[]{"meer","kills_by"})
            {
                var d=new Dictionary<string,FoundationValue>();
                foreach(var pair in Dict(Get(raw,field,Empty())).Entries)d[pair.Key.AsString()]=I(Int(pair.Value));
                values[field]=O(d);
            }
            foreach(string field in new[]{"talked","achievements"})
            {
                var list=Get(raw,field,A()); if(list.Kind!="array")throw new FormatException("Saved "+field+" must be an array.");
                var unique=new List<FoundationValue>();var seen=new HashSet<string>();
                if(field=="achievements"&&Obj(metaAchievements))foreach(var p in metaAchievements.Entries)if(seen.Add(p.Key.AsString()))unique.Add(p.Key);
                foreach(var item in list.Items) { string id=Str(item); if(seen.Add(id))unique.Add(S(id)); }
                values[field]=FoundationValue.Array(unique);
            }
            if(!raw.TryGet("kills_by",out _))
            {
                var kb=Copy(values["kills_by"]);long golems=0;
                foreach(string flag in new[]{"golem_ruins","golem_cave"})if(flags.ContainsKey(flag))golems++;
                if(golems>0)kb["golem"]=I(golems);if(flags.ContainsKey("boss_defeated"))kb["king"]=I(1);values["kills_by"]=O(kb);
            }
            if(!raw.TryGet("talked",out _) && flags.ContainsKey("cat_found"))values["talked"]=A(S("muis_bos"));
            var records=new Dictionary<string,FoundationValue>();var savedRecords=Get(raw,"arena_records",Empty());
            if(Obj(savedRecords))foreach(var pair in savedRecords.Entries)records[pair.Key.AsString()]=N(Real(pair.Value));values["arena_records"]=O(records);
            values["homestead"]=NormalizeFarm(Get(raw,"homestead",Empty()),clock);
            values["stockroom"]=NormalizeStock(Get(raw,"stockroom",Empty()));
            values["coastal_storage"]=NormalizeStorage(Get(raw,"coastal_storage",Empty()),12,99,true);
            values["personal_home"]=NormalizeHome(Get(raw,"personal_home",Empty()));
            values["yard"]=NormalizeYard(Get(raw,"yard",Empty()),values["homestead"].Require("cells"));
            values["professions"]=NormalizeProfessions(Get(raw,"professions",Empty()),clock);
            values["visited_maps"]=RestoreVisits(raw,map);
            long hearts=inventory.TryGetValue("heart_container",out var heart)?heart.AsInt64():0;
            long maximum; try {maximum=checked(5+hearts);}catch(OverflowException){throw new FormatException("Saved maximum HP overflows source capacity.");}
            values["hp"]=I(Math.Min(Math.Max(Int(Get(raw,"hp",I(5))),1),maximum));
            foreach(var pair in raw.Entries)if(!values.ContainsKey(pair.Key.AsString()))warnings.Add("Retained unknown source field: "+pair.Key.AsString());
            if(raw.TryGet("version",out var version) && (!Numeric(version)||version.AsDouble()!=1))warnings.Add("Original loader ignores this version; raw source version retained.");
            var stateOut=new FoundationGameState(O(values)){UseLoadPosition=true,SpawnName="start",InGame=false};
            return new LegacySaveImport(preservedRaw,stateOut,warnings);
        }
        private static FoundationValue SourceJsonNumbers(FoundationValue value)
        {
            if(Numeric(value))return N(value.AsDouble());
            if(value.Kind=="array")
            {var items=new List<FoundationValue>();foreach(var item in value.Items)items.Add(SourceJsonNumbers(item));return FoundationValue.Array(items);}
            if(Obj(value))
            {var fields=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);foreach(var pair in value.Entries)fields[pair.Key.AsString()]=SourceJsonNumbers(pair.Value);return O(fields);}
            return value;
        }
        public static long NormalizeHeroXp(FoundationValue raw)=> (long)Bound(raw,0,2250);
        public FoundationValue NormalizeOwned(FoundationValue raw)
        {
            var result=new Dictionary<string,FoundationValue>();if(Obj(raw))foreach(var pair in rules.Require("gear").Entries)if(Owns(raw,pair.Key.AsString()))result[pair.Key.AsString()]=I(1);return O(result);
        }
        public FoundationValue NormalizeEquipment(FoundationValue raw,FoundationValue inventory)
        {
            var result=new Dictionary<string,FoundationValue>();if(Obj(raw))foreach(var entry in rules.Require("gearSlots").Entries)
            {string slot=entry.Key.AsString();var item=Get(raw,slot,S(""));if(item.Kind=="string" && Slot(item.AsString())==slot && Owns(inventory,item.AsString()))result[slot]=item;}return O(result);
        }
        private string Slot(string item)=>rules.Require("gear").TryGet(item,out var gear)?Str(Get(gear,"slot",S(""))):"";
        public FoundationValue NormalizeAppearance(FoundationValue raw)
        {
            string gender=Obj(raw)&&Get(raw,"gender",S("m")).Kind=="string"&&Get(raw,"gender",S("m")).AsString()=="v"?"v":"m";
            var styles=rules.Require(gender=="v"?"hairV":"hairM"); string hair=styles.Items[2].AsString(),eyes="rond";
            if(!Obj(raw))return O("gender",S("m"),"hair",S("m_kort"),"hair_color",I(2),"eyes",S("rond"),"eye_color",I(0));
            var candidate=Get(raw,"hair",S(""));if(candidate.Kind=="string"&&Strings(styles).Contains(candidate.AsString()))hair=candidate.AsString();
            candidate=Get(raw,"eyes",S(""));if(candidate.Kind=="string"&&Strings(rules.Require("eyes")).Contains(candidate.AsString()))eyes=candidate.AsString();
            return O("gender",S(gender),"hair",S(hair),"hair_color",I(Clamp(Int(Get(raw,"hair_color",I(2))),0,rules.Require("hairColorCount").AsInt64()-1)),"eyes",S(eyes),"eye_color",I(Clamp(Int(Get(raw,"eye_color",I(0))),0,rules.Require("eyeColorCount").AsInt64()-1)));
        }
        public FoundationValue NormalizeClothing(FoundationValue raw,FoundationValue inventory)
        {
            var result=new Dictionary<string,FoundationValue>();if(Obj(raw))foreach(var s in rules.Require("clothingSlots").Entries)
            {
                string slot=s.Key.AsString();var e=Get(raw,slot,Empty());var item=Get(e,"item",S(""));
                if(Obj(e)&&item.Kind=="string"&&rules.Require("clothing").TryGet(item.AsString(),out var catalog)&&Str(Get(catalog,"slot",S("")))==slot&&Owns(inventory,item.AsString()))
                    result[slot]=O("item",item,"dye",I(Clamp(Int(Get(e,"dye",I(0))),0,rules.Require("dyeColorCount").AsInt64()-1)));
            }return O(result);
        }
        private FoundationValue NormalizeProfessions(FoundationValue raw,double clock)
        {
            var result=new Dictionary<string,FoundationValue>{{"xp",Empty()},{"cooldowns",Empty()}};if(!Obj(raw))return O(result);
            var goal=Get(raw,"goal",S(""));if(goal.Kind=="string"&&Strings(rules.Require("recipes")).Contains(goal.AsString()))result["goal"]=goal;
            var xp=Get(raw,"xp",Empty());var cleanXp=new Dictionary<string,FoundationValue>();
            if(Obj(xp))foreach(var skill in rules.Require("skills").Items){var n=Get(xp,skill.AsString(),I(0));if(Numeric(n))cleanXp[skill.AsString()]=I(Clamp(Int(n),0,1350));}result["xp"]=O(cleanXp);
            var cooldowns=Get(raw,"cooldowns",Empty());var clean=new Dictionary<string,FoundationValue>();
            if(Obj(cooldowns))foreach(var limit in rules.Require("resourceLimits").Entries)
            {string id=limit.Key.AsString();var n=Get(cooldowns,id,N(0));if(Numeric(n)&&n.AsDouble()>clock)clean[id]=N(Math.Min(n.AsDouble(),clock+limit.Value.AsDouble()));}result["cooldowns"]=O(clean);return O(result);
        }
        private FoundationValue NormalizeStorage(FoundationValue raw,int capSlots,int cap,bool materials)
        {
            var result=new Dictionary<string,FoundationValue>();if(!Obj(raw))return O(result);
            foreach(var p in raw.Entries)
            {
                if(result.Count>=capSlots)break;string id=p.Key.AsString();
                if(rules.Require("items").TryGet(id,out var item)&&Get(item,"type",S("")).Kind=="string")
                {string type=Get(item,"type",S("")).AsString();if((type=="material"||(!materials&&(type=="use"||type=="ammo")))&&Numeric(p.Value)&&p.Value.AsDouble()>=1)result[id]=I((long)Math.Min(cap,p.Value.AsDouble()));}
            }return O(result);
        }
        private FoundationValue NormalizeStock(FoundationValue raw)
        {
            var result=O("home",Empty(),"favorites",Empty(),"sort",I(0));if(!Obj(raw))return result;
            var favorites=new Dictionary<string,FoundationValue>();var saved=Get(raw,"favorites",Empty());if(Obj(saved))foreach(var p in saved.Entries)if(rules.Require("items").TryGet(p.Key.AsString(),out _)&&True(p.Value))favorites[p.Key.AsString()]=B(true);
            return O("home",NormalizeStorage(Get(raw,"home",Empty()),144,999,false),"favorites",O(favorites),"sort",I((long)Bound(Get(raw,"sort",I(0)),0,3)));
        }
        private FoundationValue RestoreVisits(FoundationValue raw,string map)
        {
            var result=new Dictionary<string,FoundationValue>();var visits=Get(raw,"visited_maps",Empty());
            if(Obj(visits))foreach(var p in visits.Entries)if(maps.Contains(p.Key.AsString())&&True(p.Value))result[p.Key.AsString()]=B(true);
            if(maps.Contains(map))result[map]=B(true);if(raw.TryGet("visited_maps",out _))return O(result);
            var flags=Get(raw,"flags",Empty());if(!Obj(flags))flags=Empty();
            foreach(var e in rules.Require("atlasEvidence").Items)if(True(Get(flags,e.Require("key").AsString(),B(false))))result[e.Require("map").AsString()]=B(true);
            var talked=Get(raw,"talked",A());if(talked.Kind=="array")foreach(var npc in talked.Items)if(npc.Kind=="string"&&rules.Require("atlasNpcs").TryGet(npc.AsString(),out var m))result[m.AsString()]=B(true);
            foreach(var e in rules.Require("atlasPlaces").Entries)if(True(Get(flags,"wm_met_"+e.Key.AsString(),B(false))))result[e.Value.Require("map").AsString()]=B(true);
            foreach(var e in rules.Require("atlasBattles").Entries)if(True(Get(flags,e.Key.AsString(),B(false))))result[e.Value.AsString()]=B(true);return O(result);
        }
        private static bool Obj(FoundationValue v)=>v!=null&&(v.Kind=="object"||v.Kind=="dictionary");
        private static FoundationValue Dict(FoundationValue v){if(!Obj(v))throw new FormatException("Saved field must be an object.");return v;}
        private static FoundationValue Get(FoundationValue v,string k,FoundationValue fallback)=>v!=null&&v.TryGet(k,out var value)?value:fallback;
        private static bool Numeric(FoundationValue v)=>v!=null&&(v.Kind=="int"||v.Kind=="float");
        private static bool True(FoundationValue v)=>v.Kind=="bool"&&v.AsBool();
        private static bool Owns(FoundationValue v,string id)=>Get(v,id,I(0)) is FoundationValue n&&Numeric(n)&&n.AsDouble()>=1;
        private static string Str(FoundationValue v)=>v.AsString();
        private static string MaybeString(FoundationValue v)=>v.Kind=="string"?v.AsString():"";
        private static long Int(FoundationValue v)
        {
            if(v.Kind=="int")return v.AsInt64();if(v.Kind=="float"){double f=v.AsDouble();if(f<long.MinValue||f>=9223372036854775808.0)throw new FormatException("Source integer overflow.");return (long)f;}if(v.Kind=="bool")return v.AsBool()?1:0;if(v.Kind=="nil")return 0;
            if(v.Kind=="string"){string text=v.AsString().Trim();int end=0;if(text.StartsWith("-")||text.StartsWith("+"))end++;while(end<text.Length&&text[end]>='0'&&text[end]<='9')end++;if(end==0||(end==1&&(text[0]=='-'||text[0]=='+')))return 0;if(long.TryParse(text.Substring(0,end),NumberStyles.Integer,CultureInfo.InvariantCulture,out long n))return n;throw new FormatException("Source integer string overflow.");}throw new FormatException("Source integer conversion is unsupported.");
        }
        private static double Real(FoundationValue v){if(Numeric(v))return v.AsDouble();if(v.Kind=="bool")return v.AsBool()?1:0;if(v.Kind=="nil")return 0;if(v.Kind=="string"&&double.TryParse(v.AsString(),NumberStyles.Float,CultureInfo.InvariantCulture,out var d)&&!double.IsNaN(d)&&!double.IsInfinity(d))return d;throw new FormatException("Source float conversion is unsupported.");}
        private static double Bound(FoundationValue v,double low,double high)=>Numeric(v)?Math.Min(Math.Max(v.AsDouble(),low),high):low;
        private static long Clamp(long n,long lo,long hi)=>Math.Min(Math.Max(n,lo),hi);
        private static Dictionary<string,FoundationValue> Copy(FoundationValue v){var d=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);foreach(var p in v.Entries)d.Add(p.Key.AsString(),p.Value);return d;}
        private static HashSet<string> Strings(FoundationValue a){var s=new HashSet<string>(StringComparer.Ordinal);foreach(var item in a.Items)s.Add(item.AsString());return s;}
        private static bool Same(FoundationValue a,FoundationValue b){if(a.Items.Count!=b.Items.Count)return false;for(int i=0;i<a.Items.Count;i++)if(!Numeric(a.Items[i])||!Numeric(b.Items[i])||a.Items[i].AsDouble()!=b.Items[i].AsDouble())return false;return true;}
        private static FoundationValue I(long n)=>FoundationValue.Integer(n);private static FoundationValue N(double n)=>FoundationValue.Number(n);private static FoundationValue S(string s)=>FoundationValue.StringValue(s);private static FoundationValue B(bool b)=>FoundationValue.Boolean(b);private static FoundationValue A(params FoundationValue[] a)=>FoundationValue.Array(a);private static FoundationValue Empty()=>O(new Dictionary<string,FoundationValue>());private static FoundationValue O(IDictionary<string,FoundationValue> d)=>FoundationValue.Object(d);
        private static FoundationValue O(params object[] pairs){var d=new Dictionary<string,FoundationValue>();for(int i=0;i<pairs.Length;i+=2)d[(string)pairs[i]]=(FoundationValue)pairs[i+1];return O(d);}
    }
}
