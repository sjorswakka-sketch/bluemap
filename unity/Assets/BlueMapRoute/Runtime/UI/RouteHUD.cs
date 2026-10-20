using System;
using System.Linq;
using BlueMapMigration.Foundation;
using UnityEngine;

namespace BlueMapMigration.Route
{
    // Quiet in-world HUD; item notices have their own right-hand lane.
    public sealed class RouteHUD
    {
        private readonly RouteWorldController route;
        private GUIStyle text,title,small,wrap;
        public string SignSpeaker="";
        public string[] SignLines=Array.Empty<string>();
        public int LastInventoryRows {get;private set;}
        public int LastDialogueLines {get;private set;}
        public bool InventorySelectionVisible {get;private set;}
        public RouteHUD(RouteWorldController controller){route=controller;}
        private string T(string nl,string en)=>route.T(nl,en);
        private void Styles()
        {
            text=new GUIStyle(GUI.skin.label){fontSize=16,normal={textColor=new Color(.91f,.93f,.86f)}};
            title=new GUIStyle(text){fontSize=21,fontStyle=FontStyle.Bold};small=new GUIStyle(text){fontSize=13,normal={textColor=new Color(.69f,.79f,.76f)}};wrap=new GUIStyle(text){wordWrap=true};
        }
        private static void Panel(Rect rect)
        {GUI.color=new Color(.035f,.072f,.078f,.94f);GUI.DrawTexture(rect,Texture2D.whiteTexture);GUI.color=new Color(.33f,.52f,.47f,.9f);GUI.DrawTexture(new Rect(rect.x,rect.y,rect.width,2),Texture2D.whiteTexture);GUI.color=Color.white;}
        private void Label(float x,float y,float w,string value,GUIStyle style=null,float height=28)=>GUI.Label(new Rect(x,y,w,height),value,style??text);
        private bool Button(Rect rect,string label,bool selected=false)
        {
            var old=GUI.enabled;GUI.enabled=old&&!route.ControllerActive;
            var style=new GUIStyle(GUI.skin.button){font=GUI.skin.font,fontSize=16,alignment=TextAnchor.MiddleLeft,padding=new RectOffset(14,10,5,5)};
            var color=GUI.backgroundColor;GUI.backgroundColor=selected?new Color(.38f,.70f,.56f):new Color(.19f,.30f,.29f);
            bool clicked=GUI.Button(rect,(selected?"›  ":"   ")+label,style);GUI.backgroundColor=color;GUI.enabled=old;return clicked;
        }
        public void Draw()
        {
            Styles();var game=route.Gameplay;var state=game.State;
            Panel(new Rect(18,16,298,98));Label(32,24,270,route.AreaName,title);
            Label(32,54,270,T("Leven ","Health ")+state.Hp+" / "+game.MaxHp+"    ·    "+state.Coins+T(" munten"," coins"));
            GUI.color=new Color(.22f,.30f,.27f);GUI.DrawTexture(new Rect(32,92,270,7),Texture2D.whiteTexture);
            GUI.color=route.World.Motor.Stamina.Exhausted?new Color(.85f,.46f,.30f):new Color(.40f,.76f,.57f);GUI.DrawTexture(new Rect(32,92,270*(float)(route.World.Motor.Stamina.Stamina/route.World.Motor.Stamina.Capacity),7),Texture2D.whiteTexture);GUI.color=Color.white;
            Panel(new Rect(886,16,248,58));Label(900,23,222,"BlueMap Quest",text);Label(900,47,222,T("Unity-proef · fase 10","Unity preview · phase 10"),small);
            if(route.Message!=""){Panel(new Rect(326,18,550,84));Label(342,29,518,route.Message,wrap,63);}
            float noticeY=90;foreach(string notice in route.ItemNotices){Panel(new Rect(886,noticeY,248,44));Label(898,noticeY+9,222,notice,text);noticeY+=48;}
            if(route.Modal==""&&!game.DialogueOpen)
            {
                if(state.QuestState("kat")=="active")
                {Panel(new Rect(18,124,298,82));Label(32,133,270,T("Pim zoekt Muis","Pim is looking for Muis"));Label(32,160,270,route.Translate(game.QuestText("kat")),new GUIStyle(small){wordWrap=true},36);}
                Panel(new Rect(18,589,1116,43));Label(32,598,1090,route.BindingLabel("interact")+T(" praten / verzamelen  ·  "," talk / gather  ·  ")+route.BindingLabel("menu")+T(" tas  ·  "," inventory  ·  ")+route.BindingLabel("quests")+T(" opdrachten  ·  "," quests  ·  ")+route.BindingLabel("pause")+T(" menu  ·  "," menu  ·  ")+route.BindingLabel("sprint")+T(" rennen  ·  F9 bediening"," run  ·  F9 controls"),small);
                if(route.CurrentTarget!=null){Panel(new Rect(360,526,432,48));Label(376,538,400,(route.BindingLabel("interact")+"  ")+route.Translate(route.CurrentTarget.Label));}
                if(route.Working){Panel(new Rect(430,474,292,38));GUI.color=new Color(.43f,.77f,.57f);GUI.DrawTexture(new Rect(441,487,270*route.WorkFraction,10),Texture2D.whiteTexture);GUI.color=Color.white;}
                if(route.World.CrosshairVisible)
                {var p=route.Camera.WorldToScreenPoint(FoundationCoordinates.ToUnity(route.World.Aim.Position));float x=p.x*1152/Screen.width,y=(Screen.height-p.y)*648/Screen.height;GUI.color=new Color(.96f,.95f,.78f,.95f);GUI.DrawTexture(new Rect(x-6,y,4,1),Texture2D.whiteTexture);GUI.DrawTexture(new Rect(x+3,y,4,1),Texture2D.whiteTexture);GUI.DrawTexture(new Rect(x,y-6,1,4),Texture2D.whiteTexture);GUI.DrawTexture(new Rect(x,y+3,1,4),Texture2D.whiteTexture);GUI.color=Color.white;}
            }
            if(game.DialogueOpen){DrawDialogue();return;}
            if(route.Modal=="")return;
            GUI.color=new Color(0,0,0,.40f);GUI.DrawTexture(new Rect(0,0,1152,648),Texture2D.whiteTexture);GUI.color=Color.white;
            if(route.Modal=="inventory")DrawInventory();else if(route.Modal=="quests")DrawQuests();else if(route.Modal=="pause")DrawPause();else DrawSign();
        }
        private void DrawDialogue()
        {
            var dialogue=route.Gameplay.Dialogue;int line=Mathf.Clamp(route.DialogueLineIndex,0,Math.Max(0,dialogue.Lines.Count-1));LastDialogueLines=dialogue.Lines.Count;
            float height=dialogue.ChoicesReady?Math.Max(210,130+dialogue.Choices.Count*44):212;float top=620-height;
            Panel(new Rect(126,top,900,height));Label(148,top+13,850,route.Translate(dialogue.Speaker),title);
            if(dialogue.ChoicesReady)
            {for(int i=0;i<dialogue.Choices.Count;i++)if(Button(new Rect(146,top+56+i*44,860,38),route.Translate(dialogue.Choices[i].Text),i==route.Selection))route.ChooseDialogue(i);}
            else
            {
                string value=dialogue.Lines.Count==0?"…":route.Translate(dialogue.Lines[line]);Label(148,top+52,850,value,wrap,100);
                Label(148,top+168,560,(line+1)+" / "+Math.Max(1,dialogue.Lines.Count)+"    "+T("Esc / B sluiten","Esc / B close"),small);
                if(Button(new Rect(789,top+163,215,35),route.ControllerActive?T("A  Verder","A  Continue"):T("E / Enter  Verder","E / Enter  Continue")))route.AdvanceDialogue();
            }
        }
        private void DrawInventory()
        {
            Panel(new Rect(190,106,772,466));Label(214,121,710,T("Je tas","Your inventory"),title);Label(214,154,710,T("Voorwerpen en aantallen blijven tussen gebieden en na laden bewaard.","Items and quantities persist between areas and after reloading."),small);
            string[] ids=route.InventoryItems();var view=new Rect(214,196,724,310);var content=new Rect(0,0,700,Math.Max(310,ids.Length*38));
            var enabled=GUI.enabled;GUI.enabled=!route.ControllerActive;Vector2 scroll=GUI.BeginScrollView(view,new Vector2(0,route.InventoryScroll),content,false,true);GUI.enabled=enabled;route.InventoryScroll=scroll.y;LastInventoryRows=ids.Length;
            for(int i=0;i<ids.Length;i++)
            {bool selected=i==route.InventoryIndex;GUI.color=selected?new Color(.20f,.39f,.31f):new Color(.07f,.12f,.13f);GUI.DrawTexture(new Rect(0,i*38,700,36),Texture2D.whiteTexture);GUI.color=Color.white;Label(14,i*38+5,580,(selected?"› ":"")+route.Translate(route.Gameplay.ItemName(ids[i])));Label(604,i*38+5,80,"× "+route.Gameplay.State.Count(ids[i]));}
            GUI.EndScrollView();InventorySelectionVisible=ids.Length==0||route.InventoryIndex*38>=route.InventoryScroll-1&&route.InventoryIndex*38+38<=route.InventoryScroll+311;
            if(ids.Length==0)Label(230,213,660,T("Je tas is leeg. Verken de paden en verzamel planten.","Your inventory is empty. Explore the paths and gather plants."),wrap,60);
            Label(214,526,516,route.ControllerActive?T("D-pad kiezen · rechter stick scrollen · B sluiten","D-pad select · right stick scroll · B close"):T("Scroll met het muiswiel · I / Esc sluiten","Mouse wheel to scroll · I / Esc close"),small);
            if(Button(new Rect(755,520,183,34),T("Sluiten","Close")))route.CloseModal();
        }
        private void DrawQuests()
        {
            Panel(new Rect(190,106,772,466));Label(214,123,710,T("Je opdrachten","Your quests"),title);float y=179;
            foreach(var quest in route.Gameplay.State.Get("quests").Entries.Take(7))
            {string id=quest.Key.AsString();bool done=route.Gameplay.State.QuestState(id)=="done";Label(214,y,710,(done?"✓  ":"•  ")+route.Translate(route.Gameplay.QuestText(id)),wrap,43);y+=47;}
            if(y==179)Label(214,y,710,T("Praat met Pim in het dorp om Muis te helpen zoeken.","Talk to Pim in the village to help find Muis."),wrap,60);
            Label(214,480,710,T("Dorp ↔ woning  ·  dorp ↔ bosrand ↔ Fluisterbos","Village ↔ home  ·  village ↔ forest edge ↔ Whispering Woods"),small);
            if(Button(new Rect(755,520,183,34),T("Sluiten","Close")))route.CloseModal();
        }
        private void DrawPause()
        {
            Panel(new Rect(356,115,440,437));Label(380,132,392,T("Even rust","Take a break"),title);
            string[] choices={T("Verder spelen","Resume"),T("Avontuur opslaan","Save adventure"),T("Opslaan en opnieuw laden","Save and reload"),T("Bediening aanpassen","Edit controls"),T("Opslaan en naar profielen","Save and return to profiles")};
            for(int i=0;i<choices.Length;i++)if(Button(new Rect(378,183+i*55,396,44),choices[i],route.Selection==i))route.ActivatePause(i);
            Label(380,474,390,route.SaveStatus,wrap,65);
        }
        private void DrawSign()
        {Panel(new Rect(230,180,692,330));Label(254,194,644,route.Translate(SignSpeaker),title);Label(254,240,644,string.Join("\n",SignLines),wrap,190);if(Button(new Rect(715,456,183,34),T("Sluiten","Close")))route.CloseModal();}
    }
}