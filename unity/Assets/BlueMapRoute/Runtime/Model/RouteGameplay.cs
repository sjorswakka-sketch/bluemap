using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Inventory;
using BlueMapMigration.Progression;
using BlueMapMigration.Story;
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
        public bool FromData {get;internal set;}=true;
    }
    /// <summary>First source route: original conversations, quest actions, harvest commits, loot and rest.</summary>
    public sealed class RouteGameplay
    {
        private readonly FoundationValue oracle,catalogs;
        private readonly FoundationWorldRepository repository;
        private bool busy;
        private StoryDialogue storyDialogue;
        private RouteDialogue routeDialogue;
        public StoryModel Story {get;}
        public FoundationGameState State { get; }
        public FoundationValue Resources => catalogs.Require("resources");
        public InventoryModel Inventory { get; }
        public ProgressionModel Progression { get; }
        public FoundationValue Items => Inventory.Items;
        public RouteDialogue Dialogue
        {
            get
            {
                var current=Story.Dialogue;if(current==null){storyDialogue=null;routeDialogue=null;return null;}
                if(!ReferenceEquals(storyDialogue,current)){storyDialogue=current;routeDialogue=new RouteDialogue();}
                routeDialogue.Id=current.Id;routeDialogue.Speaker=current.Speaker;routeDialogue.Lines=current.Lines;routeDialogue.Source=current.Source;routeDialogue.FromData=current.FromData;
                routeDialogue.Choices=current.Choices.Select(c=>new RouteChoice(c.Source)).ToArray();routeDialogue.ChoicesReady=current.ChoicesReady;return routeDialogue;
            }
        }
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
            catalogs=oracle.Require("catalogs");
            Inventory=new InventoryModel(repository,State);
            Progression=new ProgressionModel(repository,State,Inventory);
            Progression.SaveRequested+=Saved;
            Progression.SoundRequested+=id=>SoundRequested?.Invoke(id);
            Progression.Toast+=text=>LastMessage=text;
            Inventory.ItemObtained+=(id,quantity)=>ItemObtained?.Invoke(id,quantity);
            Inventory.SoundRequested+=id=>SoundRequested?.Invoke(id);
            Inventory.SaveRequested+=Saved;
            Story=new StoryModel(repository,State,Inventory,Progression);
            Story.SaveRequested+=Saved;Story.ItemObtained+=(id,amount)=>ItemObtained?.Invoke(id,amount);
            Story.SoundRequested+=id=>SoundRequested?.Invoke(id);Story.Toast+=text=>LastMessage=text;
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
        public string FormatDialogue(string line)=>Story.Format(line);
        public string ItemName(string id)=>Inventory.ItemName(id);
        public long Room(string id)=>Inventory.Room(id);
        private void Give(string id,long quantity)=>Inventory.Give(id,quantity);
        private void RefreshQuests()=>Story.RefreshQuests();
        public bool Talk(string npcId)
        {
            if(busy||State.InputLocked||DialogueOpen)return false;busy=true;
            try
            {
                if(npcId=="muis_bos"&&State.Flag("cat_found")){LastMessage="Muis is al op weg naar Pim.";return false;}
                bool result=Story.Talk(npcId,new StoryNpcContext{CatCalm=CatCalm,CatPanic=CatPanic});
                if(npcId=="muis_bos"&&CatCalm<2&&CatPanic<=0)CatWaiting=true;
                if(Story.LastMessage!="")LastMessage=Story.LastMessage;return result;
            }
            finally{busy=false;Saved();}
        }
        public bool ShowSourceLines(string id,string speaker,IEnumerable<string> lines)=>!State.Ended&&!DialogueOpen&&Story.ShowLines(id,speaker,lines);
        public bool ShowSourceDialogue(string id)=>!State.Ended&&!DialogueOpen&&Story.ShowDialogue(id);
        public void CloseDialogue()=>Story.CloseDialogue();
        private bool CanRun(FoundationValue actions)
        {
            foreach(var action in actions.Items)
                switch(action.Items[0].AsString())
                {
                    case "start_quest":case "quest_step":case "finish_quest":case "set_flag":case "clear_flag":case "give":case "take":case "coins":case "heal":case "save":case "sound":case "toast":break;
                    case "weapon":
                        string target=action.Items[1].AsString();
                        if(!Progression.Catalogs.Require("weapons").TryGet(target,out _)){LastMessage="Onbekende wapenverbetering.";return false;}
                        if(target=="iron"||target=="crystal")
                        {
                            var recipe=Progression.Catalogs.Require("weaponUpgrades").Require(target);
                            if(State.Get("weapon").AsString()!=recipe.Require("from").AsString()||State.Coins<recipe.Require("coins").AsInt64()){LastMessage="De voorwaarde is intussen veranderd.";return false;}
                            foreach(var input in recipe.Require("materials").Entries)if(State.Count(input.Key.AsString())<input.Value.AsInt64()){LastMessage="De voorwaarde is intussen veranderd.";return false;}
                        }
                        break;
                    default:if(!Story.CanRunActions(FoundationValue.Array(new[]{action}))){LastMessage="Onbekende verhaalactie: "+action.Items[0].AsString();return false;}break;
                }
            return true;
        }
        public bool Advance()
        {
            if(busy||!DialogueOpen||Dialogue.ChoicesReady)return false;
            if(Dialogue.Source.TryGet("do",out var actions)&&!CanRun(actions))return false;
            busy=true;try{return Story.Advance();}finally{busy=false;Saved();}
        }
        public bool Choose(int index)
        {
            if(busy||!DialogueOpen||!Dialogue.ChoicesReady||index<0||index>=Dialogue.Choices.Count)return false;
            var selected=Dialogue.Choices[index].Source;
            // Original model preserves source event semantics; the interactive boundary rejects stale purchases.
            if(selected.TryGet("if",out var tests)&&!Story.CheckAll(tests)){LastMessage="De voorwaarde is intussen veranderd.";return false;}
            if(selected.TryGet("do",out var actions)&&!CanRun(actions))return false;
            busy=true;try{return Story.Choose(index);}finally{busy=false;Saved();}
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
        public double Bonus(string stat)=>Progression.Bonus(stat);
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
        public string QuestText(string id)=>Story.QuestText(id);
    }
}
