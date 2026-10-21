using System;
using System.Collections.Generic;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Inventory;
using UnityEngine;

namespace BlueMapMigration.Route
{
    public sealed class RouteChoice
    {
        public string Text { get; }
        internal FoundationValue Source { get; }
        internal RouteChoice(FoundationValue source) { Source=source;Text=source.Require("text").AsString(); }
    }
    public sealed class RouteDialogue
    {
        public string Id { get; internal set; }
        public string Speaker { get; internal set; }
        public IReadOnlyList<string> Lines { get; internal set; }
        public IReadOnlyList<RouteChoice> Choices { get; internal set; }
        public bool ChoicesReady { get; internal set; }
        internal FoundationValue Source;
    }
    /// <summary>First source route: original conversations, quest actions, harvest commits, loot and rest.</summary>
    public sealed class RouteGameplay
    {
        private readonly FoundationValue oracle,catalogs;
        private readonly FoundationConditionRegistry conditions;
        private readonly LegacySaveImporter importer;
        private readonly FoundationWorldRepository repository;
        private bool busy,dialogueActionsDone;
        private const string DialogueOwner="route_dialogue";
        public FoundationGameState State { get; }
        public FoundationValue Resources => catalogs.Require("resources");
        public InventoryModel Inventory { get; }
        public FoundationValue Items => Inventory.Items;
        public RouteDialogue Dialogue { get; private set; }
        public bool DialogueOpen => Dialogue!=null;
        public string LastMessage { get; private set; }="";
        public long DirtyVersion { get; private set; }
        public long MaxHp => checked(5+State.Count("heart_container"));
        public double CatCalm { get; private set; }
        public double CatPanic { get; private set; }
        public bool CatWaiting { get; private set; }
        public event Action SaveRequested;
        public event Action<string,long> ItemObtained;
        public event Action<string> SoundRequested;
        public FoundationValue Oracle => oracle;
        public RouteGameplay(FoundationWorldRepository repository,FoundationGameState state)
        {
            if(repository==null)throw new ArgumentNullException(nameof(repository));
            this.repository=repository;State=state??throw new ArgumentNullException(nameof(state));
            var resource=UnityEngine.Resources.Load<TextAsset>("BlueMapRouteOracle");
            if(resource==null)throw new FormatException("Missing original route reference.");
            oracle=FoundationJson.ParsePlain(resource.text);
            if(oracle.Require("schema").AsString()!="bluemap.route.source-oracle.v1" || oracle.Require("personalSavesUsed").AsBool())throw new FormatException("Invalid route reference.");
            catalogs=oracle.Require("catalogs");conditions=new FoundationConditionRegistry(State);importer=new LegacySaveImporter(repository);
            Inventory=new InventoryModel(repository,State);
            Inventory.ItemObtained+=(id,quantity)=>ItemObtained?.Invoke(id,quantity);
            Inventory.SoundRequested+=id=>SoundRequested?.Invoke(id);
            Inventory.SaveRequested+=Saved;
        }
        public static RouteGameplay NewGame(FoundationWorldRepository repository)
        {
            var resource=UnityEngine.Resources.Load<TextAsset>("BlueMapRouteOracle");
            if(resource==null)throw new FormatException("Missing original new-game state.");
            return new RouteGameplay(repository,new FoundationGameState(FoundationJson.ParsePlain(resource.text).Require("newGame")));
        }
        public static FoundationValue Object(params (string name,FoundationValue value)[] entries)
        { var values=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);foreach(var entry in entries)values.Add(entry.name,entry.value);return FoundationValue.Object(values); }
        private static FoundationValue Get(FoundationValue value,string key,FoundationValue fallback)=>value.TryGet(key,out var found)?found:fallback;
        private static FoundationValue Empty()=>FoundationValue.Object(new Dictionary<string,FoundationValue>());
        private static FoundationValue Replace(FoundationValue source,string key,FoundationValue value,bool remove=false)
        {
            var entries=new List<KeyValuePair<FoundationValue,FoundationValue>>();
            foreach(var entry in source.Entries)if(entry.Key.AsString()!=key)entries.Add(entry);
            if(!remove)entries.Add(new KeyValuePair<FoundationValue,FoundationValue>(FoundationValue.StringValue(key),value));return FoundationValue.Object(entries);
        }
        private void Commit(Dictionary<string,FoundationValue> updates)
        { State.CommitFields(updates); }
        private void Saved() { DirtyVersion=checked(DirtyVersion+1);SaveRequested?.Invoke(); }
        public string ItemName(string id)=>Inventory.ItemName(id);
        public long Room(string id)=>Inventory.Room(id);
        private void Give(string id,long quantity)=>Inventory.Give(id,quantity);
        private void StartQuest(string id)
        {
            if(State.Get("quests").TryGet(id,out _))return;
            State.Set("quests",Replace(State.Get("quests"),id,Object(("state",FoundationValue.StringValue("active")),("step",FoundationValue.Integer(0)))));RefreshQuests();
        }
        private void FinishQuest(string id)
        {
            if(!State.Get("quests").TryGet(id,out var quest)||quest.Require("state").AsString()=="done")return;
            var updated=Replace(quest,"state",FoundationValue.StringValue("done"));
            long before=LegacySaveImporter.NormalizeHeroXp(State.Get("hero_xp"));
            bool main=catalogs.Require("quests").TryGet(id,out var questInfo)&&Get(questInfo,"main",FoundationValue.Boolean(false)).AsBool();
            long reward=catalogs.Require("quests").TryGet(id,out _)?(main||id=="diepte"?100:40):0;
            long total=Math.Min(2250,checked(before+reward));
            long coins=checked(State.Coins+(HeroLevel(total)-HeroLevel(before))*15);
            Commit(new Dictionary<string,FoundationValue>{{"quests",Replace(State.Get("quests"),id,updated)},{"hero_xp",FoundationValue.Integer(total)},{"coins",FoundationValue.Integer(Math.Max(0,coins))}});RefreshQuests();
        }
        private static int HeroLevel(long xp) { int level=1;while(level<10&&xp>=25*level*(level+1))level++;return level; }
        private void RefreshQuests()
        {
            var next=State.Get("quests");bool changed=false;
            foreach(var entry in State.Get("quests").Entries)
            {
                string id=entry.Key.AsString();var quest=entry.Value;
                if(quest.Require("state").AsString()!="active"||!catalogs.Require("quests").TryGet(id,out var info))continue;
                var steps=info.Require("steps").Items;long step=quest.Require("step").AsInt64();
                while(step>=0&&step<steps.Count-1&&steps[(int)step].TryGet("advance_if",out var tests))
                { var result=conditions.CheckAll(tests);if(result.Status!=FoundationRuleStatus.Supported||!result.Value)break;step++;changed=true; }
                if(step!=quest.Require("step").AsInt64())next=Replace(next,id,Replace(quest,"step",FoundationValue.Integer(step)));
            }
            if(changed)State.Set("quests",next);
        }
        private bool Check(FoundationValue row)=>!row.TryGet("if",out var tests)||conditions.CheckAll(tests).Value;
        private void NoteTalked(string id)
        {
            var talked=new List<FoundationValue>(State.Get("talked").Items);foreach(var value in talked)if(value.AsString()==id)return;
            talked.Add(FoundationValue.StringValue(id));State.Set("talked",FoundationValue.Array(talked));
        }
        public bool Talk(string npcId)
        {
            if(busy||State.InputLocked||DialogueOpen)return false;
            if(!catalogs.Require("npcs").TryGet(npcId,out var npc)){LastMessage="Dit gesprek is nog niet aangesloten.";return false;}
            busy=true;
            try
            {
                NoteTalked(npcId);
                if(npcId=="muis_bos")
                {
                    if(State.Flag("cat_found")){LastMessage="Muis is al op weg naar Pim.";return false;}
                    if(CatCalm<2)
                    {
                        if(CatPanic>0)LastMessage="Muis schrikt van het lawaai. Geef haar even rust.";
                        else {CatWaiting=true;LastMessage="Je steekt rustig je hand uit. Blijf bij Muis staan tot ze je vertrouwt.";}
                        return false;
                    }
                    StartQuest("kat");
                }
                foreach(var rule in npc.Require("rules").Items)
                    if(Check(rule)){Enter(rule.Require("talk").AsString());return true;}
                return false;
            }
            finally{busy=false;Saved();}
        }
        private void Enter(string id)
        {
            if(!catalogs.Require("dialogues").TryGet(id,out var node))throw new FormatException("Unknown original dialogue: "+id);
            var lines=new List<string>();foreach(var line in Get(node,"lines",FoundationValue.Array(Array.Empty<FoundationValue>())).Items)lines.Add(line.AsString());
            Dialogue=new RouteDialogue{Id=id,Speaker=Get(node,"speaker",FoundationValue.StringValue("")).AsString(),Lines=lines.AsReadOnly(),Choices=new List<RouteChoice>().AsReadOnly(),ChoicesReady=false,Source=node};
            dialogueActionsDone=false;State.SetUi(DialogueOwner,true);
        }
        public void CloseDialogue(){Dialogue=null;dialogueActionsDone=false;State.SetUi(DialogueOwner,false);}
        private bool CanRun(FoundationValue actions)
        {
            foreach(var action in actions.Items)
                switch(action.Items[0].AsString())
                {
                    case "start_quest":case "quest_step":case "finish_quest":case "set_flag":case "clear_flag":case "give":case "take":case "coins":case "heal":case "save":case "sound":case "toast":break;
                    default:LastMessage="Dit onderdeel volgt in een volgende migratiefase: "+action.Items[0].AsString();return false;
                }
            return true;
        }
        private void Run(FoundationValue actions)
        {
            // Original actions remain sequential in the detached state. The coherent final
            // transaction prevents an observer failure from duplicating a quest reward.
            var staged=new RouteGameplay(repository,new FoundationGameState(State.Snapshot()));
            var receipts=new List<KeyValuePair<string,long>>();var sounds=new List<string>();
            staged.ItemObtained+=(id,amount)=>receipts.Add(new KeyValuePair<string,long>(id,amount));
            staged.SoundRequested+=id=>sounds.Add(id);staged.RunDirect(actions);
            var updates=new Dictionary<string,FoundationValue>(StringComparer.Ordinal);
            foreach(var entry in staged.State.Fields)if(!State.Fields.TryGetValue(entry.Key,out var previous)||!ReferenceEquals(previous,entry.Value))updates.Add(entry.Key,entry.Value);
            Commit(updates);if(staged.LastMessage!="")LastMessage=staged.LastMessage;
            foreach(var receipt in receipts)ItemObtained?.Invoke(receipt.Key,receipt.Value);foreach(var sound in sounds)SoundRequested?.Invoke(sound);
        }
        private void RunDirect(FoundationValue actions)
        {
            foreach(var action in actions.Items)
            {
                var a=action.Items;string id=a.Count>1&&a[1].Kind=="string"?a[1].AsString():"";long count=a.Count>2?a[2].AsInt64():1;
                switch(a[0].AsString())
                {
                    case "start_quest":StartQuest(id);break;
                    case "finish_quest":FinishQuest(id);break;
                    case "quest_step":if(State.Get("quests").TryGet(id,out var q)){State.Set("quests",Replace(State.Get("quests"),id,Replace(q,"step",a[2])));RefreshQuests();}break;
                    case "set_flag":State.SetFlag(id,true);RefreshQuests();break;
                    case "clear_flag":State.SetFlag(id,false);RefreshQuests();break;
                    case "give":Give(id,count);break;
                    case "take":Inventory.Take(id,count);break;
                    case "coins":State.Coins=Math.Max(0,checked(State.Coins+a[1].AsInt64()));break;
                    case "heal":State.Hp=MaxHp;SoundRequested?.Invoke("heal");break;
                    case "sound":SoundRequested?.Invoke(id);break;
                    case "toast":LastMessage=id;break;
                    case "save":break;
                }
            }
        }
        public bool Advance()
        {
            if(busy||Dialogue==null||Dialogue.ChoicesReady)return false;
            busy=true;
            try
            {
                var node=Dialogue.Source;
                if(!dialogueActionsDone&&node.TryGet("do",out var actions)) { if(!CanRun(actions))return false;dialogueActionsDone=true;Run(actions); }
                if(node.TryGet("choices",out var choices))
                {
                    var available=new List<RouteChoice>();foreach(var choice in choices.Items)if(Check(choice))available.Add(new RouteChoice(choice));
                    Dialogue.Choices=available.AsReadOnly();Dialogue.ChoicesReady=true;if(available.Count==0)CloseDialogue();return true;
                }
                if(node.TryGet("branch",out var branches))foreach(var branch in branches.Items)if(Check(branch)){Enter(branch.Require("next").AsString());return true;}
                if(node.TryGet("next",out var next))Enter(next.AsString());else CloseDialogue();return true;
            }
            finally{busy=false;Saved();}
        }
        public bool Choose(int index)
        {
            if(busy||Dialogue==null||!Dialogue.ChoicesReady||index<0||index>=Dialogue.Choices.Count)return false;
            var selected=Dialogue.Choices[index].Source;
            if(!Check(selected)){LastMessage="De voorwaarde is intussen veranderd.";return false;}
            if(selected.TryGet("do",out var actions)&&!CanRun(actions))return false;
            busy=true;
            try{if(actions!=null)Run(actions);if(selected.TryGet("next",out var next))Enter(next.AsString());else CloseDialogue();return true;}
            finally{busy=false;Saved();}
        }
        public void ResetCat(){CatCalm=0;CatPanic=0;CatWaiting=false;}
        public void TickCat(double delta,double distance,double speed,bool loud)
        {
            if(delta<0||double.IsNaN(delta)||double.IsInfinity(delta)||distance<0||speed<0||double.IsNaN(distance)||double.IsInfinity(distance)||double.IsNaN(speed)||double.IsInfinity(speed))throw new ArgumentOutOfRangeException(nameof(delta));
            if(State.InputLocked)return;
            if(distance<105&&loud){CatPanic=2.5;CatWaiting=false;CatCalm=0;}
            if(CatPanic>0)CatPanic=Math.Max(0,CatPanic-delta);
            else if(CatWaiting)
            {if(distance>56||speed>5){CatWaiting=false;CatCalm=0;}else CatCalm=Math.Min(2,CatCalm+delta);}
        }
        private FoundationValue EnsureProfessions()
        {
            var prof=State.Get("professions");
            if(prof.TryGet("xp",out _)&&prof.TryGet("cooldowns",out _))return prof;
            var xp=Empty();foreach(var skill in catalogs.Require("skills").Entries)xp=Replace(xp,skill.Key.AsString(),FoundationValue.Integer(0));
            prof=Replace(Replace(prof,"xp",xp),"cooldowns",Empty());State.Set("professions",prof);return prof;
        }
        public int SkillLevel(string skill)
        { long xp=Get(EnsureProfessions().Require("xp"),skill,FoundationValue.Integer(0)).AsInt64();int level=1;while(level<10&&xp>=15*level*(level+1))level++;return level; }
        public double ResourceRemaining(string id)
        { var prof=EnsureProfessions();return Math.Max(0,Get(prof.Require("cooldowns"),id,FoundationValue.Number(0)).AsDouble()-State.PlayTime); }
        public long ResourceAmount(string kind)
        { long amount=Resources.Require(kind).Require("amount").AsInt64();return amount+(kind=="stump"&&State.Count("prof_iron_axe")>0?1:0); }
        public double ResourceDuration(string kind)
        {return Get(Resources.Require(kind),"duration",FoundationValue.Number(.65)).AsDouble()*(1-Bonus("harvest_time_reduction"));}
        public double Bonus(string stat)
        {
            double result=0;var gear=catalogs.Require("gear");
            foreach(var slotEntry in catalogs.Require("slots").Entries)
            { var slot=slotEntry.Key;
                if(State.Get("equipment").TryGet(slot.AsString(),out var id)&&State.Count(id.AsString())>0&&gear.TryGet(id.AsString(),out var info)&&Get(info,"slot",FoundationValue.StringValue("")).AsString()==slot.AsString()&&Get(info,"bonuses",Empty()).TryGet(stat,out var number))result+=stat=="move_speed"?number.AsDouble():Math.Max(0,number.AsDouble());
            }
            double limit=catalogs.Require("bonusLimits").Require(stat).AsDouble();return Math.Max(-limit,Math.Min(limit,result));
        }
        public string ResourceReason(string kind,string id)
        {
            if(!Resources.TryGet(kind,out var resource))return "Onbekende grondstof.";
            double wait=ResourceRemaining(id);if(wait>0)return resource.Require("name").AsString()+" herstelt over "+Math.Ceiling(wait)+" s";
            if(SkillLevel(resource.Require("skill").AsString())<Get(resource,"level",FoundationValue.Integer(1)).AsInt64())return "Een hoger beroepniveau is nodig.";
            if(resource.TryGet("tools",out var tools)&&tools.Items.Count>0)
            {bool found=false;foreach(var tool in tools.Items)if(State.Count(tool.AsString())>0){found=true;break;}if(!found)return "Nodig: "+ItemName(tools.Items[tools.Items.Count-1].AsString());}
            if(Room(resource.Require("item").AsString())<ResourceAmount(kind))return "Geen ruimte voor: "+ItemName(resource.Require("item").AsString());return "";
        }
        public bool Gather(string kind,string id)
        {
            if(busy||State.InputLocked||String.IsNullOrEmpty(id))return false;
            string reason=ResourceReason(kind,id);if(reason!=""){LastMessage=reason;return false;}
            busy=true;
            try
            {
                var resource=Resources.Require(kind);var prof=EnsureProfessions();string skill=resource.Require("skill").AsString(),item=resource.Require("item").AsString();long amount=ResourceAmount(kind);
                var due=Replace(prof.Require("cooldowns"),id,FoundationValue.Number(State.PlayTime+resource.Require("cooldown").AsDouble()));
                long xp=Get(prof.Require("xp"),skill,FoundationValue.Integer(0)).AsInt64();xp=checked(xp+Math.Min(resource.Require("xp").AsInt64(),1350-xp));
                prof=Replace(Replace(prof,"cooldowns",due),"xp",Replace(prof.Require("xp"),skill,FoundationValue.Integer(xp)));
                Commit(new Dictionary<string,FoundationValue>{{"professions",prof},{"inventory",Replace(State.Get("inventory"),item,FoundationValue.Integer(checked(State.Count(item)+amount)))}});
                RefreshQuests();LastMessage=ItemName(item)+" x"+amount;ItemObtained?.Invoke(item,amount);Saved();return true;
            }
            finally{busy=false;}
        }
        public bool OpenChest(string uniqueKey,FoundationValue contents)
        {
            if(busy)return false;
            bool opened=Inventory.OpenChest(uniqueKey??"",contents);LastMessage=Inventory.LastMessage;return opened;
        }
        public bool CollectPickup(string item,string uniqueKey,string instanceKey="")
        {
            if(busy)return false;
            bool collected=Inventory.CollectPickup(item,uniqueKey??"",instanceKey??"");LastMessage=Inventory.LastMessage;return collected;
        }
        public bool Rest()
        {if(busy||State.InputLocked)return false;State.Hp=MaxHp;LastMessage="Je bent uitgerust. Je voortgang is opgeslagen.";SoundRequested?.Invoke("heal");Saved();return true;}
        public string QuestText(string id)
        {
            if(!catalogs.Require("quests").TryGet(id,out var info)||info.Require("steps").Items.Count==0)return "";
            int step=(int)Math.Max(0,Math.Min(info.Require("steps").Items.Count-1,State.QuestStep(id)));return info.Require("steps").Items[step].Require("text").AsString();
        }
    }
}
