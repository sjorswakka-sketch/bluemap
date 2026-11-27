using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using UnityEngine;
namespace BlueMapMigration.Professions
{
 public sealed class ShopRow
 {
  public int EntryIndex {get;internal set;} public string Item {get;internal set;} public string Label {get;internal set;} public string Text {get;internal set;} public long Price {get;internal set;} public bool Owned {get;internal set;}
 }
 public sealed class SkillProgress
 {
  public string Id {get;internal set;} public int Level {get;internal set;} public long XP {get;internal set;} public long Current {get;internal set;} public long Needed {get;internal set;} public bool AtMax {get;internal set;}
 }
 /// <summary>
 /// Original professions, gathering, recipes, work notes, shops and fish trade. Every rule reads the
 /// recorded source tables; opening a page, a shop or the field guide never grants or removes anything.
 /// </summary>
 public sealed class ProfessionsModel
 {
  public const int MaxLevel=10,MaxXp=1350; public const double HarvestRange=40;
  static FoundationValue catalogs,orders,newGame;
  readonly FoundationConditionRegistry rules; bool busy;
  public FoundationGameState State {get;} public InventoryModel Inventory {get;} public ProgressionModel Progression {get;}
  public FoundationValue Catalogs=>catalogs; public static FoundationValue NewGame=>newGame;
  public string LastMessage {get;private set;}="";
  public Func<string,string> Translator {get;set;}=text=>text;
  /// <summary>Singular, plural and count; the Dutch source chooses the singular only for exactly one.</summary>
  public Func<string,string,long,string> PluralTranslator {get;set;}
  public event Action Changed; public event Action SaveRequested; public event Action<string> Toast; public event Action<string> SoundRequested; public event Action<string,long> ItemObtained;
  public static FoundationValue LoadCatalog()
  {
   if(catalogs!=null)return catalogs;
   var asset=UnityEngine.Resources.Load<TextAsset>("BlueMapProfessionsCatalog");if(asset==null)throw new FormatException("Missing original professions catalog");
   var document=FoundationJson.ParsePlain(asset.text);
   if(document.Require("schema").AsString()!="bluemap.professions.runtime-catalog.v1"||document.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid professions source reference");
   orders=document.Require("orders");newGame=document.Require("newGame");catalogs=InventoryModelChecks.DecodeOrdered(document.Require("catalogsOrdered"));return catalogs;
  }
  public ProfessionsModel(FoundationWorldRepository repository,FoundationGameState state,InventoryModel inventory=null,ProgressionModel progression=null)
  {
   State=state??throw new ArgumentNullException(nameof(state));Inventory=inventory??new InventoryModel(repository,state);Progression=progression??new ProgressionModel(repository,state,Inventory);
   if(!ReferenceEquals(State,Inventory.State)||!ReferenceEquals(State,Progression.State))throw new ArgumentException("Professions must share one game state");
   LoadCatalog();rules=new FoundationConditionRegistry(State);
  }
  static FoundationValue S(string v)=>FoundationValue.StringValue(v);static FoundationValue I(long v)=>FoundationValue.Integer(v);static FoundationValue D(double v)=>FoundationValue.Number(v);static FoundationValue E()=>InventoryModel.Empty();
  static FoundationValue G(FoundationValue d,string k,FoundationValue f)=>InventoryModel.Get(d,k,f);static FoundationValue R(FoundationValue d,string k,FoundationValue v,bool remove=false)=>InventoryModel.Replace(d,k,v,remove);
  static bool Obj(FoundationValue v)=>v!=null&&(v.Kind=="object"||v.Kind=="dictionary");static bool Num(FoundationValue v)=>v!=null&&(v.Kind=="int"||v.Kind=="float");
  static long N(FoundationValue v)=>v==null?0:v.Kind=="int"?v.AsInt64():v.Kind=="float"?(long)v.AsDouble():0;
  static bool Finite(double v)=>!Double.IsNaN(v)&&!Double.IsInfinity(v);
  public string Tr(string value)=>Translator==null?value:Translator(value);
  public string Plural(string one,string many,long count)=>PluralTranslator!=null?PluralTranslator(one,many,count):Tr(count==1?one:many);
  public static string Fill(string text,params object[] values)
  {
   foreach(var v in values){int a=text.IndexOf("%s",StringComparison.Ordinal),b=text.IndexOf("%d",StringComparison.Ordinal),i=a<0?b:b<0?a:Math.Min(a,b);if(i<0)break;text=text.Substring(0,i)+Convert.ToString(v,CultureInfo.InvariantCulture)+text.Substring(i+2);}return text;
  }
  string F(string template,params object[] values)=>Fill(Tr(template),values);
  string Text(string key)=>catalogs.Require("text").Require(key).AsString();
  void Say(string message){LastMessage=message;Toast?.Invoke(message);}
  public FoundationValue Skills=>catalogs.Require("skills");public FoundationValue Recipes=>catalogs.Require("recipes");public FoundationValue Resources=>catalogs.Require("resources");public FoundationValue Shops=>catalogs.Require("shops");public FoundationValue Notes=>catalogs.Require("notes");public FoundationValue Fishing=>catalogs.Require("fishing");
  public IReadOnlyList<string> SkillIds=>Skills.Entries.Select(v=>v.Key.AsString()).ToArray();public IReadOnlyList<string> RecipeIds=>Recipes.Entries.Select(v=>v.Key.AsString()).ToArray();
  public IReadOnlyList<string> Consumables=>catalogs.Require("consumables").Items.Select(v=>v.AsString()).ToArray();
  public string SkillName(string skill)=>Tr(Skills.Require(skill).Require("name").AsString());public string SkillDescription(string skill)=>Tr(Skills.Require(skill).Require("desc").AsString());
  public string ItemName(string id)=>Inventory.ItemName(id);
  public string MapName(string map)=>Tr(G(catalogs.Require("mapNames"),map,S(map)).AsString());
  // --- Saved state ---------------------------------------------------------------------------
  public double CooldownLimit(string resourceId){var limit=G(catalogs.Require("dynamicLimits"),resourceId,D(0));return Num(limit)?limit.AsDouble():0;}
  public FoundationValue Normalize(FoundationValue raw,double clock)
  {
   var result=new Dictionary<string,FoundationValue>{{"xp",E()},{"cooldowns",E()}};if(!Obj(raw))return FoundationValue.Object(result);
   var goal=G(raw,"goal",S(""));if(goal.Kind=="string"&&Recipes.TryGet(goal.AsString(),out _))result["goal"]=goal;
   var xp=G(raw,"xp",E());var cleanXp=E();
   if(Obj(xp))foreach(string skill in SkillIds){var value=G(xp,skill,I(0));if(Num(value)&&Finite(value.AsDouble()))cleanXp=R(cleanXp,skill,I(Math.Max(0,Math.Min(MaxXp,N(value)))));}
   result["xp"]=cleanXp;
   var cooldowns=G(raw,"cooldowns",E());var clean=E();
   if(Obj(cooldowns))
   {
    foreach(var map in catalogs.Require("placements").Entries)foreach(var obj in map.Value.Items)
    {
     string id=obj.Require("id").AsString();var value=G(cooldowns,id,D(0));
     if(Num(value)&&Finite(value.AsDouble())&&value.AsDouble()>clock)clean=R(clean,id,D(Math.Min(value.AsDouble(),clock+Resources.Require(obj.Require("kind").AsString()).Require("cooldown").AsDouble())));
    }
    foreach(var row in cooldowns.Entries)
    {
     string id=row.Key.AsString();if(!(id.StartsWith("trail:",StringComparison.Ordinal)||id.StartsWith("winter:",StringComparison.Ordinal)||id.StartsWith("forestfood:",StringComparison.Ordinal)))continue;
     if(!Num(row.Value)||!Finite(row.Value.AsDouble())||row.Value.AsDouble()<=clock)continue;
     double limit=CooldownLimit(id);if(limit>0)clean=R(clean,id,D(Math.Min(row.Value.AsDouble(),clock+limit)));
    }
   }
   result["cooldowns"]=clean;return FoundationValue.Object(result);
  }
  /// <summary>A save from before professions gains empty tables; unknown later fields stay untouched.</summary>
  FoundationValue Ensure()
  {
   var raw=State.Get("professions");if(Obj(raw)&&raw.TryGet("xp",out _)&&raw.TryGet("cooldowns",out _))return raw;
   var normalized=Normalize(raw,State.PlayTime);
   if(Obj(raw))
   {
    foreach(var row in raw.Entries)if(!normalized.TryGet(row.Key.AsString(),out _))normalized=R(normalized,row.Key.AsString(),row.Value);
    foreach(string field in new[]{"xp","cooldowns"}){var table=G(normalized,field,E());var original=G(raw,field,E());if(Obj(original))foreach(var row in original.Entries)if(!table.TryGet(row.Key.AsString(),out _))table=R(table,row.Key.AsString(),row.Value);normalized=R(normalized,field,table);}
   }
   State.Set("professions",normalized);return normalized;
  }
  /// <summary>The source normalizes an older save the first time a profession is consulted.</summary>
  public void EnsureState()=>Ensure();
  FoundationValue Peek(){var raw=State.Get("professions");return Obj(raw)&&raw.TryGet("xp",out _)&&raw.TryGet("cooldowns",out _)?raw:Normalize(raw,State.PlayTime);}
  // --- Experience -----------------------------------------------------------------------------
  public static int Threshold(int level){int n=Math.Max(1,Math.Min(MaxLevel,level));return 15*(n-1)*n;}
  public long Xp(string skill)=>N(G(G(Peek(),"xp",E()),skill,I(0)));
  public int Level(string skill){long total=Xp(skill);int level=1;while(level<MaxLevel&&total>=Threshold(level+1))level++;return level;}
  public SkillProgress Progress(string skill){int level=Level(skill);long xp=Xp(skill);bool top=level==MaxLevel;return new SkillProgress{Id=skill,Level=level,XP=xp,AtMax=top,Current=top?0:xp-Threshold(level),Needed=top?0:Threshold(level+1)-Threshold(level)};}
  public bool AddXp(string skill,long amount)
  {
   if(!Skills.TryGet(skill,out _)||amount<=0)return false;
   var prof=Ensure();long previous=Xp(skill);int oldLevel=Level(skill);long next=previous+Math.Min(amount,MaxXp-previous);if(next==previous)return false;
   State.Set("professions",R(prof,"xp",R(G(prof,"xp",E()),skill,I(next))));int level=Level(skill);Changed?.Invoke();
   if(level>oldLevel)Say(F(Text("skill_up"),SkillName(skill),level));return true;
  }
  public void RecordFish(string item){switch(item){case "meer_baars":AddXp("fishing",8);break;case "meer_snoek":AddXp("fishing",12);break;case "meer_gouden_karper":AddXp("fishing",20);break;}}
  // --- Quests touched by a recipe ---------------------------------------------------------------
  void RefreshQuests()
  {
   var quests=State.Get("quests");var info=Progression.Catalogs.Require("quests");bool changed=false;
   foreach(var row in quests.Entries.ToArray())
   {
    if(G(row.Value,"state",S("none")).AsString()!="active"||!info.TryGet(row.Key.AsString(),out var quest))continue;
    long step=row.Value.Require("step").AsInt64(),start=step;var steps=quest.Require("steps").Items;
    while(step>=0&&step<steps.Count-1&&steps[(int)step].TryGet("advance_if",out var c)){var result=rules.CheckAll(c);if(result.Status!=FoundationRuleStatus.Supported||!result.Value)break;step++;}
    if(step!=start){quests=R(quests,row.Key.AsString(),R(row.Value,"step",I(step)));changed=true;}
   }
   if(changed)State.Set("quests",quests);
  }
  string QuestTitle(string id)=>Tr(G(G(Progression.Catalogs.Require("quests"),id,E()),"title",S(id)).AsString());
  void StartQuest(string id)
  {
   if(State.Get("quests").TryGet(id,out _))return;
   State.Set("quests",R(State.Get("quests"),id,FoundationValue.Object(new Dictionary<string,FoundationValue>{{"state",S("active")},{"step",I(0)}})));
   Say(F("Nieuwe opdracht: %s",QuestTitle(id)));RefreshQuests();
  }
  void FinishQuest(string id)
  {
   if(!State.Get("quests").TryGet(id,out var quest)||G(quest,"state",S("")).AsString()=="done")return;
   Say(F("Opdracht voltooid: %s",QuestTitle(id)));Action<string> forward=text=>Say(text);Progression.Toast+=forward;try{Progression.FinishQuest(id);}finally{Progression.Toast-=forward;}
  }
  void LanternMade()
  {
   if(State.Count("lw_lantern")<1)return;StartQuest("lichtwerk");FinishQuest("lichtwerk");StartQuest("mistsporen");
   if(!State.Flag("lw_lantern_made")){State.SetFlag("lw_lantern_made",true);RefreshQuests();SaveRequested?.Invoke();}
  }
  // --- Recipes ----------------------------------------------------------------------------------
  public string StationName(string station)=>Tr(Text(String.IsNullOrEmpty(station)?"anywhere":station));
  public string CraftReason(string recipeId)
  {
   if(!Recipes.TryGet(recipeId,out var recipe))return Tr(Text("unknown"));
   if(recipe.TryGet("unlock",out var unlock)&&!State.Flag(unlock.AsString()))return Tr(G(recipe,"unlock_hint",S("Nog vergrendeld: herstel de prismabank of Mees’ oversteek.")).AsString());
   string skill=recipe.Require("skill").AsString();long level=recipe.Require("level").AsInt64();
   if(Level(skill)<level)return F(Text("skill_required"),SkillName(skill),level);
   string station=G(recipe,"station",S("")).AsString();if(station!=""&&State.MapId!=station)return F(Text("station_required"),Tr(Text(station)));
   string output=recipe.Require("output").AsString();if(Inventory.Room(output)<N(G(recipe,"amount",I(1))))return F(Text("full"),ItemName(output));
   foreach(var input in recipe.Require("inputs").Entries)if(Inventory.Available(input.Key.AsString())<N(input.Value))return F(Text("missing"),ItemName(input.Key.AsString()));
   return "";
  }
  public bool Craft(string recipeId)
  {
   if(busy)return false;Ensure();string reason=CraftReason(recipeId);if(reason!=""){Say(reason);return false;}
   busy=true;
   try
   {
    var recipe=Recipes.Require(recipeId);string output=recipe.Require("output").AsString(),skill=recipe.Require("skill").AsString(),old=G(recipe,"upgrade_from",S("")).AsString();long amount=N(G(recipe,"amount",I(1)));
    bool worn=old!=""&&Progression.Equipped(Progression.SlotOf(old))==old;
    if(!Inventory.Consume(recipe.Require("inputs")))return false;
    // The source reconciles worn gear right after the materials leave: capacity never refills.
    Inventory.StaminaCapacity=100+Progression.Bonus("stamina_max");Inventory.Stamina=Math.Max(0,Math.Min(Inventory.Stamina,Inventory.StaminaCapacity));
    Inventory.Give(output,amount,true);if(worn)Progression.Equip(output);
    var prof=Ensure();if(G(prof,"goal",S("")).Kind=="string"&&G(prof,"goal",S("")).AsString()==recipeId){State.Set("professions",R(prof,"goal",S("")));Changed?.Invoke();}
    AddXp(skill,recipe.Require("xp").AsInt64());
    if(output=="lw_lantern")LanternMade();
    Say(F(Text("made"),ItemName(output),amount));ItemObtained?.Invoke(output,amount);
   }
   finally{busy=false;}
   SaveRequested?.Invoke();return true;
  }
  // --- Gathering ----------------------------------------------------------------------------------
  public double Remaining(string resourceId){var value=G(G(Peek(),"cooldowns",E()),resourceId,D(0));return Math.Max((Num(value)?value.AsDouble():0)-State.PlayTime,0);}
  public string GatherTool(string kind){if(!Resources.TryGet(kind,out var resource)||!resource.TryGet("tools",out var tools))return "";foreach(var tool in tools.Items)if(State.Count(tool.AsString())>0)return tool.AsString();return "";}
  public long GatherAmount(string kind){long amount=Resources.Require(kind).Require("amount").AsInt64();if(kind=="stump"&&State.Count("prof_iron_axe")>0)amount++;return amount;}
  public double GatherDuration(string kind){double basis=Resources.TryGet(kind,out var resource)?G(resource,"duration",D(.65)).AsDouble():.65;return basis*(1.0-Progression.Bonus("harvest_time_reduction"));}
  public string GatherAnimation(string kind)=>Resources.TryGet(kind,out var resource)?G(resource,"animation",S("foraging")).AsString():"foraging";
  public string GatherReason(string kind,string resourceId)
  {
   if(!Resources.TryGet(kind,out var resource))return Tr(Text("unknown"));
   double wait=Remaining(resourceId);if(wait>0)return F(Text("recovering"),Tr(resource.Require("name").AsString()),(long)Math.Ceiling(wait));
   string skill=resource.Require("skill").AsString();long level=N(G(resource,"level",I(1)));if(Level(skill)<level)return F(Text("skill_required"),SkillName(skill),level);
   if(resource.TryGet("tools",out var tools)&&tools.Items.Count>0&&GatherTool(kind)=="")return F(Text("tool_required"),ItemName(tools.Items[tools.Items.Count-1].AsString()));
   string item=resource.Require("item").AsString();if(Inventory.Room(item)<GatherAmount(kind))return F(Text("full"),ItemName(item));
   return "";
  }
  public bool Gather(string kind,string resourceId)
  {
   if(busy)return false;Ensure();string reason=GatherReason(kind,resourceId);if(reason!=""){Say(reason);return false;}
   busy=true;
   try
   {
    var resource=Resources.Require(kind);string item=resource.Require("item").AsString(),skill=resource.Require("skill").AsString();long amount=GatherAmount(kind),xp=resource.Require("xp").AsInt64();
    // The cooldown is saved before any inventory or quest listener runs.
    var prof=Ensure();State.Set("professions",R(prof,"cooldowns",R(G(prof,"cooldowns",E()),resourceId,D(State.PlayTime+resource.Require("cooldown").AsDouble()))));
    Inventory.Give(item,amount,true);AddXp(skill,xp);
    Say(F(Text("gathered"),ItemName(item),amount,xp,SkillName(skill)));ItemObtained?.Invoke(item,amount);
   }
   finally{busy=false;}
   return true;
  }
  // --- Work journal -------------------------------------------------------------------------------
  public string Goal{get{var id=G(State.Get("professions"),"goal",S(""));return id.Kind=="string"&&Recipes.TryGet(id.AsString(),out _)?id.AsString():"";}}
  public void ToggleGoal(string id){if(!Recipes.TryGet(id,out _))return;State.Set("professions",R(State.Get("professions"),"goal",S(Goal==id?"":id)));Changed?.Invoke();SaveRequested?.Invoke();}
  public bool Learn(string kind)
  {
   if(!Notes.TryGet(kind,out var note))return false;string flag=note.Require("flag").AsString();if(State.Flag(flag))return false;
   State.SetFlag(flag,true);RefreshQuests();Say(F("Werktekening geleerd: %s. Kies een materiaaldoel via Beroepen.",ItemName(Recipes.Require(note.Require("recipe").AsString()).Require("output").AsString())));SaveRequested?.Invoke();return true;
  }
  public string NoteName(string kind)=>Tr(Notes.Require(kind).Require("name").AsString());public IReadOnlyList<string> NoteLines(string kind)=>Notes.Require(kind).Require("lines").Items.Select(v=>Tr(v.AsString())).ToArray();
  public IReadOnlyList<string> RecipesFor(string item)=>Recipes.Entries.Where(v=>v.Value.Require("output").AsString()==item).Select(v=>v.Key.AsString()).ToArray();
  string ForageSource(string item)
  {
   if(!catalogs.Require("foragePlaces").TryGet(item,out var places)||places.Items.Count==0)return "";
   string here=State.MapId;var sorted=places.Items.Where(p=>p.Require("map").AsString()==here).Concat(places.Items.Where(p=>p.Require("map").AsString()!=here)).Take(2);
   return String.Join(", ",sorted.Select(p=>F("%s (%d, %d)",MapName(p.Require("map").AsString()),N(p.Require("pos").Items[0])+1,N(p.Require("pos").Items[1])+1)));
  }
  public string Source(string item)
  {
   if(item.StartsWith("or_",StringComparison.Ordinal))
   {
    if(item.EndsWith("_seed",StringComparison.Ordinal))return Tr("Tuinhulp of huisvoorraad: U → Zaden en boomgaard.");
    foreach(var crop in catalogs.Require("orchard").Entries)if(crop.Value.Require("output").AsString()==item)return F("Eigen tuin: %s. Kies zaden via U → Zaden en boomgaard.",Tr(crop.Value.Require("name").AsString()));
   }
   if(item=="hs_honey")return Tr("Eigen bijenkast met drie bloeiende planten binnen vijf tegels.");
   string forage=ForageSource(item);if(forage!="")return forage;
   var places=new List<string>();FoundationValue resource=null;var ids=catalogs.Require("placements").Entries.Select(v=>v.Key.AsString()).ToList();
   if(ids.Contains(State.MapId)){ids.Remove(State.MapId);ids.Insert(0,State.MapId);}
   foreach(string map in ids)foreach(var entry in catalogs.Require("placements").Require(map).Items)
   {
    var candidate=Resources.Require(entry.Require("kind").AsString());if(candidate.Require("item").AsString()!=item)continue;
    resource=candidate;string label=MapName(map);if(!places.Contains(label))places.Add(label);
   }
   if(places.Count>0)
   {
    string text=String.Join(", ",places.Take(3));
    if(resource.TryGet("tools",out var tools))text+=" · "+ItemName(tools.Items[tools.Items.Count-1].AsString());
    if(N(G(resource,"level",I(1)))>1)text+=" · "+F("%s niveau %d",SkillName(resource.Require("skill").AsString()),N(resource.Require("level")));
    return text;
   }
   var made=RecipesFor(item);
   if(made.Count>0){var recipe=Recipes.Require(made[0]);return F("Maken: %s · %s niveau %d",StationName(G(recipe,"station",S("")).AsString()),SkillName(recipe.Require("skill").AsString()),N(recipe.Require("level")));}
   switch(item)
   {
    case "gel":return Tr("Slijmen in het Fluisterbos en de Ruïne.");
    case "meer_baars":return Tr("Hengel van Joris; visplekken bij het Zilvermeer.");
    case "jacht_vlees":case "jacht_huid":return Tr("Jachtwild in de Dorstvallei.");
    case "moeras_huid":return Tr("Moeraswild in het Kruipmoeras.");
    case "shard":return Tr("Golembewakers in de Ruïne en de Echo-grot.");
   }
   return Tr("Ontdek dit voorwerp tijdens je avonturen.");
  }
  public string RecipeText(string id)
  {
   if(!Recipes.TryGet(id,out var recipe))return "";
   string output=recipe.Require("output").AsString();var lines=new List<string>{Tr(Inventory.ItemDescription(output)),F("%s niveau %d · %s",SkillName(recipe.Require("skill").AsString()),N(recipe.Require("level")),StationName(G(recipe,"station",S("")).AsString()))};
   if(recipe.TryGet("unlock",out var unlock)&&!State.Flag(unlock.AsString()))lines.Add(Tr(G(recipe,"unlock_hint",S("Nog vergrendeld: herstel de prismabank of Mees’ oversteek.")).AsString()));
   foreach(var input in recipe.Require("inputs").Entries){string item=input.Key.AsString();lines.Add(F("%s: %d/%d · %s",ItemName(item),Inventory.Available(item),N(input.Value),Source(item)));}
   foreach(var input in recipe.Require("inputs").Entries){string item=input.Key.AsString();if(Inventory.Available(item)>State.Count(item))lines.Add(F("Binnen bereik: %s · tas %d + kist %d.",ItemName(item),State.Count(item),Inventory.Available(item)-State.Count(item)));}
   string effect=Progression.StatsText(output);if(effect!="")lines.Add(effect);
   if(recipe.TryGet("upgrade_from",out _))lines.Add(Tr("Verbeteren verbruikt het oude voorwerp. Een gedragen exemplaar wordt meteen vervangen; stamina wordt niet bijgevuld."));
   return String.Join("\n",lines);
  }
  public string UsesText(string item)
  {
   var uses=new List<string>();foreach(var recipe in Recipes.Entries)if(recipe.Value.Require("inputs").TryGet(item,out _)){string label=ItemName(recipe.Value.Require("output").AsString());if(!uses.Contains(label))uses.Add(label);}
   return uses.Count==0?"":F("Voor: %s",String.Join(", ",uses.Take(4)));
  }
  public string IngredientStatus(string id)=>String.Join(" · ",Recipes.Require(id).Require("inputs").Entries.Select(v=>ItemName(v.Key.AsString())+" "+Inventory.Available(v.Key.AsString())+"/"+N(v.Value)));
  public int IngredientsReady(string id)=>Recipes.Require(id).Require("inputs").Entries.Count(v=>Inventory.Available(v.Key.AsString())>=N(v.Value));
  // --- Workplace identity ---------------------------------------------------------------------------
  public string AccentHtml(string id)=>G(catalogs.Require("colors"),id,S("91b9b0")).AsString();
  public Color Accent(string id){string hex=AccentHtml(id);return new Color(Convert.ToInt32(hex.Substring(0,2),16)/255f,Convert.ToInt32(hex.Substring(2,2),16)/255f,Convert.ToInt32(hex.Substring(4,2),16)/255f,1f);}
  public string IconItem(string skill)=>G(catalogs.Require("icons"),skill,S("")).AsString();
  public string Title(string id)
  {
   switch(id)
   {
    case "foraging":return Tr("Veldboek · kruiden en zaden");case "woodcutting":return Tr("Houtwerkbank · gereedschap en vlechtwerk");case "mining":return Tr("Ertskaart · steen en metalen");case "fishing":return Tr("Visboek · hengel en vangst");
    case "smithing":return Tr("Smidswerkbank · smelten en smeden");case "alchemy":return Tr("Mengtafel · kruiden en elixers");case "cooking":return Tr("Keukenboek · gerechten en proviand");
   }
   return Tr("Beroepen & ambachten");
  }
  public string Intro(string id)
  {
   switch(id)
   {
    case "foraging":return Tr("Van bosvondst naar tuinzaad; lees bij elk recept welke planten je nodig hebt.");case "woodcutting":return Tr("Werk met hout en vezels; werktekeningen verbinden gereedschap, uitrusting en inrichting.");
    case "mining":return Tr("Begin met losse vuurstenen; een stenen pikhouweel opent koper, koper en niveau 2 openen ijzer.");case "fishing":return Tr("Vis bij de kringen in het Zilvermeer; iedere echte vangst telt voor dit beroep.");
    case "smithing":return Tr("Controleer erts, brandstof en niveau; Greta's smederij is je werkplek voor metaal.");case "alchemy":return Tr("Kies een mengsel en bekijk de ingrediënten; bijzondere bereidingen vragen Lena's alchemietafel.");
    case "cooking":return Tr("Vergelijk herstel en ingrediënten; snacks maak je onderweg, warme gerechten in de herberg.");
   }
   return "";
  }
  public string Tab(string id)
  {
   switch(id)
   {
    case "foraging":return Tr("Zaden & bereidingen");case "woodcutting":return Tr("Werktekeningen");case "mining":return Tr("Gereedschap");case "fishing":return Tr("Vangst & hengel");case "smithing":return Tr("Smelten & smeden");case "alchemy":return Tr("Mengrecepten");case "cooking":return Tr("Gerechten");
   }
   return Tr("Maken");
  }
  // --- Shops -------------------------------------------------------------------------------------------
  bool Allowed(FoundationValue entry){if(!entry.TryGet("if",out var tests))return true;var result=rules.CheckAll(tests);return result.Status==FoundationRuleStatus.Supported&&result.Value;}
  public string ShopName(string shop)=>Tr(Shops.Require(shop).Require("name").AsString());
  public string EntryLabel(FoundationValue entry)
  {
   if(entry.TryGet("label",out var label))return Tr(label.AsString());
   long amount=N(G(entry,"amount",I(1)));string name=ItemName(entry.Require("item").AsString());return amount==1?name:name+" x"+amount;
  }
  public IReadOnlyList<ShopRow> ShopRows(string shop)
  {
   var rows=new List<ShopRow>();var items=Shops.Require(shop).Require("items").Items;
   for(int index=0;index<items.Count;index++)
   {
    var entry=items[index];if(!Allowed(entry))continue;string item=entry.Require("item").AsString();long price=entry.Require("price").AsInt64();
    bool owned=G(entry,"once",FoundationValue.Boolean(false)).AsBool()&&State.Count(item)>0;string label=EntryLabel(entry);
    rows.Add(new ShopRow{EntryIndex=index,Item=item,Label=label,Price=price,Owned=owned,Text=label+"   —   "+(owned?Tr("gekocht"):Fill(Plural("%d munt","%d munten",price),price))});
   }
   return rows;
  }
  string NoRoomText(string item)
  {
   var info=Inventory.ItemInfo(item);
   if(Inventory.Room(item)>0&&info.TryGet("almost_full_text",out var almost))return F("%s (%d van de %d)",Tr(almost.AsString()),State.Count(item),N(info.Require("max")));
   return Inventory.FullText(item);
  }
  public bool Buy(string shop,int entryIndex)
  {
   if(busy||!Shops.TryGet(shop,out var data))return false;var items=data.Require("items").Items;if(entryIndex<0||entryIndex>=items.Count)return false;
   var entry=items[entryIndex];string item=entry.Require("item").AsString();long price=entry.Require("price").AsInt64(),amount=N(G(entry,"amount",I(1)));
   if(G(entry,"once",FoundationValue.Boolean(false)).AsBool()&&State.Count(item)>0)return false;
   if(!Allowed(entry))return false;
   if(State.Coins<price){SoundRequested?.Invoke("error");Say(Tr("Je hebt niet genoeg munten."));return false;}
   if(Inventory.Room(item)<amount){SoundRequested?.Invoke("error");Say(NoRoomText(item));return false;}
   busy=true;
   try
   {
    Inventory.AddCoins(-price);Inventory.Give(item,amount,true);
    if(entry.TryGet("with",out var extras))foreach(var extra in extras.Items)Inventory.Give(extra.Items[0].AsString(),N(extra.Items[1]),true);
    SoundRequested?.Invoke("buy");Say(F("Gekocht: %s",EntryLabel(entry)));
   }
   finally{busy=false;}
   SaveRequested?.Invoke();return true;
  }
  // --- Fish trade and catch records --------------------------------------------------------------------
  public string Golden=>Fishing.Require("golden").AsString();
  public FoundationValue FishStats(string fish)=>fish==Golden?Fishing.Require("goldenStats"):Fishing.Require("catches").Require(fish);
  public double GoldenChance(long pity)=>Math.Min(Fishing.Require("goldenChance").AsDouble()+Fishing.Require("goldenPity").AsDouble()*pity,Fishing.Require("goldenMaxChance").AsDouble());
  public long Pity=>N(G(State.Get("meer"),"pech",I(0)));public long SoldCount=>N(G(State.Get("meer"),"verkocht",I(0)));
  public bool GoldenCanBite=>State.QuestState("meer_karper")!="done"&&State.Count(Golden)==0;
  static long RoundAway(double value)=>(long)Math.Round(value,MidpointRounding.AwayFromZero);
  public long FishPrice(string fish,long nth,bool cap)
  {
   double value=Fishing.Require("catches").Require(fish).Require("sell").AsDouble();if(nth>=Fishing.Require("fullPriceFish").AsInt64())value*=0.5;
   long coins=Math.Max(1,RoundAway(value));if(cap)coins+=Math.Max(1,RoundAway(coins*Fishing.Require("capBonus").AsDouble()));return coins;
  }
  public IReadOnlyList<string> SellableFish=>Fishing.Require("fishIds").Items.Select(v=>v.AsString()).Where(id=>State.Count(id)>0).ToArray();
  public long PriceNow(string fish)=>FishPrice(fish,SoldCount,State.Count("fishers_cap")>0);
  public long SaleValue(){long nth=SoldCount,coins=0;bool cap=State.Count("fishers_cap")>0;foreach(string fish in SellableFish)for(long i=0;i<State.Count(fish);i++){coins+=FishPrice(fish,nth,cap);nth++;}return coins;}
  public long SellFish()
  {
   if(busy)return 0;long coins=SaleValue(),amount=0;var fish=SellableFish;
   foreach(string id in fish){long count=State.Count(id);amount+=count;Inventory.Take(id,count);}
   if(amount==0)return 0;
   Inventory.AddCoins(coins);State.Set("meer",R(State.Get("meer"),"verkocht",I(SoldCount+amount)));SoundRequested?.Invoke("buy");
   Say(F("Verkocht: %s voor %s",Fill(Plural("%d vis","%d vissen",amount),amount),Fill(Plural("%d munt","%d munten",coins),coins)));return coins;
  }
  public void RecordCatch(string fish,bool deep)
  {
   var lake=State.Get("meer");lake=R(lake,"gevangen",I(N(G(lake,"gevangen",I(0)))+1));State.Set("meer",lake);RecordFish(fish);
   if(deep)State.Set("meer",R(State.Get("meer"),"pech",I(fish==Golden?0:Pity+1)));
  }
  /// <summary>The generator results are the caller's explicit input, exactly as the source consumes them.</summary>
  public string RollCatch(Func<double> randf,bool deep,long pity,bool golden)
  {
   if(deep&&golden&&randf()<GoldenChance(pity))return Golden;
   string weight=deep?"deep_weight":"weight";double total=0;foreach(var row in Fishing.Require("catches").Entries)total+=row.Value.Require(weight).AsDouble();
   double pick=randf()*total;foreach(var row in Fishing.Require("catches").Entries){pick-=row.Value.Require(weight).AsDouble();if(pick<0)return row.Key.AsString();}
   return "meer_baars";
  }
  public void NotifyRodNeeded(){SoundRequested?.Invoke("error");Say(Tr("Je hebt een hengel nodig. Misschien heeft Visser Joris er een."));}
  /// <summary>Completes a landed catch: the fish, the catch record and the one golden notice.</summary>
  public void LandCatch(string fish,bool deep)
  {
   Inventory.Give(fish,1,true);RecordCatch(fish,deep);SoundRequested?.Invoke("meer_vangst");ItemObtained?.Invoke(fish,1);
   if(fish==Golden){SoundRequested?.Invoke("crystal");Say(Tr("Je hebt de Gouden Karper gevangen!"));}
   SaveRequested?.Invoke();
  }
 }
}
