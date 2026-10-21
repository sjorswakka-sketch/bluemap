using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
namespace BlueMapMigration.Story
{
 public sealed partial class StoryModel
 {
  const string DialogueOwner="route_dialogue";
  void Enter(string id)
  {
   if(!Catalogs.Require("dialogues").TryGet(id,out var node))throw new FormatException("Unknown original dialogue: "+id);
   Dialogue=new StoryDialogue{Id=id,Speaker=G(node,"speaker",S("")).AsString(),Lines=G(node,"lines",A()).Items.Select(v=>v.AsString()).ToArray(),Choices=Array.Empty<StoryChoice>(),ChoicesReady=false,FromData=true,Source=node};
   LastPresentedDialogue=Dialogue;dialogueActionsDone=false;State.SetUi(DialogueOwner,true);DialogueChanged?.Invoke();if(Dialogue.Lines.Count==0)FinishNode();
  }
  void EnterLines(string id,string speaker,IEnumerable<string> lines)
  {
   var text=lines.ToArray();var node=FoundationValue.Object(new Dictionary<string,FoundationValue>{{"speaker",S(speaker)},{"lines",FoundationValue.Array(text.Select(S))}});
   Dialogue=new StoryDialogue{Id=id,Speaker=speaker,Lines=text,Choices=Array.Empty<StoryChoice>(),ChoicesReady=false,FromData=false,Source=node};LastPresentedDialogue=Dialogue;dialogueActionsDone=false;State.SetUi(DialogueOwner,true);DialogueChanged?.Invoke();if(text.Length==0)FinishNode();
  }
  public bool ShowDialogue(string id)=>Operation(()=>{if(DialogueOpen)return false;Enter(id);Emit("sound_requested",S("select"));return true;});
  public bool ShowLines(string id,string speaker,IEnumerable<string> lines)=>Operation(()=>{if(DialogueOpen)return false;EnterLines(id,speaker,lines);Emit("sound_requested",S("select"));return true;});
  public void CloseDialogue(){if(Dialogue!=null){Dialogue.Choices=Array.Empty<StoryChoice>();Dialogue.ChoicesReady=false;LastPresentedDialogue=Dialogue;}Dialogue=null;dialogueActionsDone=false;State.SetUi(DialogueOwner,false);DialogueChanged?.Invoke();}
  bool FinishNode()
  {
   if(Dialogue==null||Dialogue.ChoicesReady)return false;var node=Dialogue.Source;
   if(!dialogueActionsDone&&node.TryGet("do",out var actions)){dialogueActionsDone=true;RunTransaction(actions);}
   if(node.TryGet("choices",out var choices))
   {
    var available=new List<StoryChoice>();for(int i=0;i<choices.Items.Count;i++){var choice=choices.Items[i];if(!choice.TryGet("if",out var tests)||CheckAll(tests))available.Add(new StoryChoice{Text=choice.Require("text").AsString(),SourceIndex=i,Source=choice});}
    if(available.Count==0){CloseDialogue();return true;}Dialogue.Choices=available.AsReadOnly();Dialogue.ChoicesReady=true;DialogueChanged?.Invoke();return true;
   }
   if(node.TryGet("branch",out var branches))foreach(var branch in branches.Items)if(!branch.TryGet("if",out var tests)||CheckAll(tests)){Enter(branch.Require("next").AsString());return true;}
   if(node.TryGet("next",out var next))Enter(next.AsString());else CloseDialogue();return true;
  }
  public bool Advance()=>Operation(FinishNode);
  public bool Choose(int index)=>Operation(()=>
  {
   if(Dialogue==null||!Dialogue.ChoicesReady||index<0||index>=Dialogue.Choices.Count)return false;var choice=Dialogue.Choices[index].Source;
   // The original button owns the choice snapshot; it does not re-evaluate a condition at confirmation.
   Dialogue.Choices=Array.Empty<StoryChoice>();Dialogue.ChoicesReady=false;dialogueActionsDone=true;Emit("sound_requested",S("select"));
   if(choice.TryGet("do",out var actions))RunTransaction(actions);
   if(choice.TryGet("next",out var next))Enter(next.AsString());else CloseDialogue();return true;
  });
  void NoteTalked(string id){var talked=State.Get("talked");if(talked.Items.Any(v=>v.AsString()==id))return;State.Set("talked",FoundationValue.Array(talked.Items.Concat(new[]{S(id)})));}
  void Say(string speaker,params string[] lines){Emit("text_dialogue_requested",FoundationValue.Object(new Dictionary<string,FoundationValue>{{"speaker",S(speaker)},{"lines",FoundationValue.Array(lines.Select(line=>S(Tr(line))))}}));}
  public bool Talk(string npcId,StoryNpcContext context=null)=>Operation(()=>
  {
   if(State.InputLocked||DialogueOpen)return false;if(!Catalogs.Require("npcs").TryGet(npcId,out var npc))return false;NoteTalked(npcId);var c=context??new StoryNpcContext();
   if(npcId=="muis_bos")
   {
    if(c.CatCalm>=2)StartDirect("kat");
    else{Emit("toast",S(c.CatPanic>0||c.CatLoud?Tr("Muis schrikt van het lawaai. Geef haar even rust."):Tr("Je steekt rustig je hand uit. Blijf bij Muis staan tot ze je vertrouwt.")));return false;}
   }
   if(npcId=="bram"&&State.Flag("rf_memorial")&&State.Flag("rf_echo_end")&&!State.Flag("rf_homecoming"))
   {SetFlagDirect("rf_homecoming",true);Emit("save_requested");Say("Bram","De oude route licht weer op. En Wilfred heeft eindelijk een naam op zijn steen. De Blauwe Kaart gaat over de mensen tussen de kristallen, net zo goed als over de kristallen zelf.");return DialogueOpen;}
   if(npcId=="greta"&&State.Flag("op_new_adventure")&&N(State.Get("ng_plus"))==0&&State.Flag("op_water")&&!State.Flag("op_greta"))
   {SetFlagDirect("op_greta",true);FinishDirect("first_water");Say("Greta","Dat teken ken ik! De oude waterbouwers gebruikten hetzelfde prisma als mijn werkbank. Je hebt meer hersteld dan alleen een fontein.","Kijk gerust bij de prismabank links van me. Voor de mijn heb je later een ijzeren zwaard nodig. Oudste Bram bij de tempel kan je eerst op weg helpen.");Emit("save_requested");return DialogueOpen;}
   string reaction="";
   if(npcId=="mira"&&State.Flag("lw_forest")&&QuestState("dauw")=="done"&&QuestState("mistbloemen")=="done")reaction="Je hebt de oude lichtkring hersteld. In de Dauwtuin bloeien de kruiden weer.";
   if(npcId=="olav"&&State.Flag("lw_heat"))reaction="Kijk naar de huizen: de families zijn terug. De Bergpas achter het oostelijke huis is open.";
   if(npcId=="stien"&&State.Flag("lw_bridge")&&QuestState("veenbessen")=="done")reaction="Mijn turf gaat weer over de brug. Aan de drooggevallen oever kun je nu vissen.";
   if(reaction!=""){Say(Tr(npc.Require("name").AsString()),reaction);return DialogueOpen;}
   foreach(var rule in npc.Require("rules").Items)if(!rule.TryGet("if",out var tests)||CheckAll(tests)){Emit("dialogue_requested",S(rule.Require("talk").AsString()));return DialogueOpen;}return false;
  });
  public bool TalkCoastResident(string npcId)=>Operation(()=>{if(State.InputLocked||DialogueOpen||!Catalogs.Require("npcs").TryGet(npcId,out _))return false;if(npcId=="rg_raf"&&!State.Flag("cw_raf_notes")){SetFlagDirect("cw_raf_notes",true);Emit("save_requested");}NoteTalked(npcId);Emit("dialogue_requested",S(npcId=="rg_ise"?"rg_ise":"rg_raf"));return DialogueOpen;});
  public bool TalkSupperActor(string npcId,string role)=>Operation(()=>
  {
   if(State.InputLocked||DialogueOpen)return false;
   if(State.MapId=="inn")
   {
    string speaker=role=="joris"?"Visser Joris":role=="bo"?"Bo de broodbezorger":"Nelle de hovenier";var lines=new List<string>();if(Catalogs.Require("supperLines").TryGet(role,out var first))lines.AddRange(first.Items.Select(v=>v.AsString()));foreach(string flag in new[]{"op_water","cat_found","rf_memorial"})if(State.Flag(flag))lines.AddRange(Catalogs.Require("supperLines").Require(flag).Items.Select(v=>v.AsString()));Say(Tr(speaker),lines.ToArray());return DialogueOpen;
   }
   if(!Catalogs.Require("npcs").TryGet(npcId,out var npc))return false;NoteTalked(npcId);foreach(var rule in npc.Require("rules").Items)if(!rule.TryGet("if",out var tests)||CheckAll(tests)){Emit("dialogue_requested",S(rule.Require("talk").AsString()));return DialogueOpen;}return false;
  });

  public bool RequestLines(string speaker,IEnumerable<string> lines)=>Operation(()=>{if(DialogueOpen)return false;Emit("text_dialogue_requested",FoundationValue.Object(new Dictionary<string,FoundationValue>{{"speaker",S(speaker)},{"lines",FoundationValue.Array(lines.Select(S))}}));return DialogueOpen;});
  public bool TalkVillageActor(string role)=>Operation(()=>
  {
   if(State.InputLocked||DialogueOpen)return false;bool enabled=State.Flag("op_new_adventure")&&N(State.Get("ng_plus"))==0,flowing=!enabled||State.Flag("op_water");string speaker=Tr(role=="gardener"?"Nelle de hovenier":"Bo de broodbezorger");
   if(role=="gardener")
   {
    if(!flowing)
    {
     if(State.Count("op_rake")==0){GiveDirect("op_rake",1,true);StartDirect("first_water");Say(speaker,"Hoor je dat gesputter? Er zit riet in het rooster. Hier, leen mijn hark. Het rooster ligt vlak ten zuiden van me.","Gebruik de hark bij het rooster, blijf even staan en draai daarna het sluisrad open. Dan krijgen het plein en mijn bloemen weer water.");}
     else Say(speaker,"Eerst het rooster schoonmaken met mijn hark. Daarna het sluisrad open. Je kunt de markering naast de fontein volgen.");
    }
    else Say(speaker,enabled?"Daar is het water weer! Bo hoeft zijn kruiken niet meer naar het meer te dragen. Bedankt — ik kan mijn bloemen weer verzorgen.":"Een beetje water en geduld. Meer hebben deze bloemen niet nodig.");
   }
   else if(State.Flag("ls_served"))Say(speaker,"Mila houdt de tafel gedekt. Ik neem voortaan wat extra brood mee voor iedereen die aanschuift.");
   else Say(speaker,flowing?"Mijn brood blijft nu droog en de kruiken vul ik hier. Mooi werk aan de fontein!":"Brood voor de herberg, lege kruiken mee terug. Hopelijk krijgt Nelle de fontein snel aan de praat.");
   Emit("save_requested");return DialogueOpen;
  });

 }
}
