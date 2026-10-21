using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using UnityEngine;

namespace BlueMapMigration.Progression
{
    /// <summary>Source-backed character ledger. Browsing is pure; gear actions are explicit and appearance choices are immediate.</summary>
    public sealed class ProgressionPanel
    {
        public static readonly Rect PanelRect = new Rect(76,68,1000,556);
        public static readonly Rect GearSlotsRect = new Rect(350,180,222,352);
        public static readonly Rect CandidatesRect = new Rect(586,180,468,116);
        public static readonly Rect AppearanceRect = new Rect(360,184,694,370);
        readonly ProgressionModel model;
        readonly Phase6Catalog catalog;
        readonly Func<string,string> translate;
        readonly Func<string,string,string> bilingual;
        readonly Dictionary<string,Texture2D> textures = new Dictionary<string,Texture2D>(StringComparer.Ordinal);
        readonly string[] tabs = {"overview","equipment","appearance","upgrade"};
        GUIStyle text,small,title,wrap,button;
        InputFrame lastHandled;
        float stickWait,repeatWait,detailScroll,maxDetailsScroll;
        int selectedSlot,selectedCandidate,selectedOverview,selectedAppearance,selectedUpgrade,zone,action;
        bool controller,dyeMode,pendingConfirm=true;
        string pendingKind="",pendingId="",message="";
        public bool IsOpen {get;private set;}
        public string Tab {get;private set;}="overview";
        public bool ControllerActive => controller;
        public bool DyeMode => dyeMode;
        public bool ConfirmationVisible => pendingKind!="";
        public int Zone => zone;
        public int ActionIndex => action;
        public int SelectedSlot => selectedSlot;
        public int SelectedCandidate => selectedCandidate;
        public int SelectedOverview => selectedOverview;
        public int SelectedAppearanceRow => selectedAppearance;
        public int SelectedUpgrade => selectedUpgrade;
        public float DetailsScroll => detailScroll;
        public float MaxDetailsScroll => maxDetailsScroll;
        public int PreviewDraws {get;private set;}
        public Rect RenderedSelectedBounds {get;private set;}
        public Rect ViewportRect => Tab=="equipment"?(zone==1?CandidatesRect:GearSlotsRect):Tab=="appearance"?AppearanceRect:Tab=="overview"?new Rect(98,260,244,330):new Rect(98,180,244,352);
        public Rect SelectedScreenRect => Tab=="equipment"?(zone==1?CandidateRect(selectedCandidate):SlotRect(selectedSlot)):Tab=="appearance"?AppearanceRowRect(selectedAppearance):Tab=="overview"?OverviewRowRect(selectedOverview):UpgradeRowRect(selectedUpgrade);
        public bool SelectionVisible => Contains(ViewportRect,SelectedScreenRect);
        public bool LayoutFits => LayoutRects().All(rect=>Contains(new Rect(0,0,1152,648),rect));
        public string SlotId => GearSlots[Mathf.Clamp(selectedSlot,0,GearSlots.Count-1)];
        public string Candidate => Alternatives.Count==0?"":Alternatives[Mathf.Clamp(selectedCandidate,0,Alternatives.Count-1)];
        public IReadOnlyList<string> GearSlots => model.EquipmentSlotIds.Concat(new[]{"weapon","boots"}).ToArray();
        public IReadOnlyList<string> Alternatives => model.EquipmentAlternatives(SlotId);
        public IReadOnlyList<string> UpgradeIds => Cat("upgradeRecipes").Entries.Where(row=>Text(row.Value,"upgrade_from")!="").Select(row=>row.Key.AsString()).ToArray();
        public IReadOnlyList<string> SkillIds => Cat("skills").Entries.Select(row=>row.Key.AsString()).ToArray();
        public Action<Rect,string> AvatarPreview {get;set;}
        public Action<string,Rect> ItemIcon {get;set;}
        public event Action Closed;
        public event Action InventoryRequested;
        public ProgressionPanel(ProgressionModel progression,Phase6Catalog sourceCatalog,Func<string,string> sourceTranslator,Func<string,string,string> textTranslator)
        {model=progression??throw new ArgumentNullException(nameof(progression));catalog=sourceCatalog;translate=sourceTranslator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);}
        static FoundationValue Empty()=>FoundationValue.Object(new Dictionary<string,FoundationValue>());
        static FoundationValue Get(FoundationValue source,string key,FoundationValue fallback=null)=>source!=null&&source.TryGet(key,out var value)?value:fallback??Empty();
        static string Text(FoundationValue source,string key,string fallback="")=>source!=null&&source.TryGet(key,out var value)&&value.Kind=="string"?value.AsString():fallback;
        static double Number(FoundationValue source,string key,double fallback=0)=>source!=null&&source.TryGet(key,out var value)&&(value.Kind=="int"||value.Kind=="float")?value.AsDouble():fallback;
        FoundationValue Cat(string key)=>Get(model.Catalogs,key);
        string T(string nl,string en)=>bilingual(nl,en);
        string Tr(string value)=>translate(value??"");
        string Name(string id)=>id==""?T("Leeg","Empty"):model.Inventory.ItemName(id);
        static bool Contains(Rect outer,Rect inner)=>inner.xMin>=outer.xMin-.5f&&inner.yMin>=outer.yMin-.5f&&inner.xMax<=outer.xMax+.5f&&inner.yMax<=outer.yMax+.5f;
        static int Mod(int value,int count)=>count<=0?0:(value%count+count)%count;
        public IReadOnlyList<Rect> LayoutRects()=>new[]{PanelRect,new Rect(98,82,170,34),new Rect(280,84,114,30),new Rect(410,84,608,30),new Rect(98,150,956,96),new Rect(98,260,244,330),new Rect(358,260,696,330),new Rect(98,180,240,352),GearSlotsRect,CandidatesRect,new Rect(586,308,468,224),AppearanceRect,new Rect(586,544,468,38),new Rect(98,598,956,18)};
        public void Open(string tab="overview")
        {if(!tabs.Contains(tab))throw new ArgumentOutOfRangeException(nameof(tab));IsOpen=true;Tab=tab;zone=action=0;dyeMode=false;pendingKind="";message="";detailScroll=0;stickWait=repeatWait=0;lastHandled=null;SelectSlot(selectedSlot);}
        public void Close(){if(!IsOpen)return;IsOpen=false;dyeMode=false;pendingKind="";Closed?.Invoke();}
        public void SetControllerActive(bool active){controller=active;}
        public void ChangeTab(string tab){if(!tabs.Contains(tab))throw new ArgumentOutOfRangeException(nameof(tab));Tab=tab;zone=action=0;dyeMode=false;pendingKind="";detailScroll=0;message="";}
        public void SetZone(int value){zone=Mathf.Clamp(value,0,3);}
        public void SelectSlot(int index)
        {selectedSlot=Mathf.Clamp(index,0,GearSlots.Count-1);var all=Alternatives;int current=all.ToList().IndexOf(model.CurrentItem(SlotId));selectedCandidate=current<0?0:current;zone=0;detailScroll=0;}
        public void SelectCandidate(int index){selectedCandidate=Mathf.Clamp(index,0,Math.Max(0,Alternatives.Count-1));zone=1;detailScroll=0;}
        public void SelectOverview(int index){selectedOverview=Mathf.Clamp(index,0,3+SkillIds.Count);zone=0;detailScroll=0;}
        public void SelectAppearanceRow(int index){selectedAppearance=Mathf.Clamp(index,0,4+model.ClothingSlotIds.Count);dyeMode=false;zone=0;}
        public void SelectUpgrade(int index){selectedUpgrade=Mathf.Clamp(index,0,UpgradeIds.Count);zone=0;detailScroll=0;}
        public void Refresh(){selectedSlot=Mathf.Clamp(selectedSlot,0,GearSlots.Count-1);selectedCandidate=Mathf.Clamp(selectedCandidate,0,Math.Max(0,Alternatives.Count-1));}
        Rect SlotRect(int index)=>new Rect(360,190+index*47,202,43);
        Rect CandidateRect(int index)=>new Rect(596,190+(index%2)*51,448,47);
        Rect OverviewRowRect(int index)=>new Rect(98,260+index*30,244,28);
        Rect AppearanceRowRect(int index)=>new Rect(360,184+index*37,694,34);
        Rect UpgradeRowRect(int index)=>new Rect(98,180+index*52,244,48);

        public void HandleInput(InputFrame frame,double delta)
        {
            if(!IsOpen||frame==null||ReferenceEquals(frame,lastHandled))return;lastHandled=frame;controller=frame.ControllerActive;
            stickWait=Math.Max(0,stickWait-(float)delta);repeatWait=Math.Max(0,repeatWait-(float)delta);
            if(frame.Pressed("menu")){InventoryRequested?.Invoke();return;}
            bool accept=frame.Pressed("ui_accept")||frame.Pressed("interact");
            int horizontal=frame.Pressed("ui_right")?1:frame.Pressed("ui_left")?-1:0,vertical=frame.Pressed("ui_down")?1:frame.Pressed("ui_up")?-1:0;
            if(frame.Pressed("ui_cancel")||frame.Pressed("pause"))
            {if(pendingKind!=""){pendingKind="";return;}if(dyeMode){dyeMode=false;return;}if((Tab=="equipment"||Tab=="upgrade")&&zone>0){zone=0;return;}Close();return;}
            if(pendingKind!=""){if(horizontal!=0||vertical!=0)pendingConfirm=!pendingConfirm;if(accept){if(pendingConfirm)ConfirmUpgrade();else pendingKind="";}return;}
            if(frame.Pressed("ui_next_tab"))ChangeTab(tabs[(Array.IndexOf(tabs,Tab)+1)%tabs.Length]);
            if(frame.Pressed("ui_prev_tab"))ChangeTab(tabs[Mod(Array.IndexOf(tabs,Tab)-1,tabs.Length)]);
            if(controller&&frame.UiScroll.magnitude>.45f&&stickWait<=0)
            {if(Math.Abs(frame.UiScroll.x)>Math.Abs(frame.UiScroll.y))horizontal=Math.Sign(frame.UiScroll.x);else vertical=Math.Sign(frame.UiScroll.y);stickWait=.13f;}
            if(horizontal==0&&vertical==0&&repeatWait<=0)
            {if(frame.Held("ui_down"))vertical=1;else if(frame.Held("ui_up"))vertical=-1;if(frame.Held("ui_right"))horizontal=1;else if(frame.Held("ui_left"))horizontal=-1;}
            if(horizontal!=0||vertical!=0){Navigate(horizontal,vertical);repeatWait=.16f;}
            if(accept)ConfirmSelection();
        }
        void Navigate(int horizontal,int vertical)
        {
            if(Tab=="appearance")
            {if(vertical!=0)SelectAppearanceRow(selectedAppearance+vertical);else if(horizontal!=0)CycleAppearance(horizontal);return;}
            if(Tab=="overview"){if(zone==0&&vertical!=0)SelectOverview(selectedOverview+vertical);else if(horizontal!=0||zone==3)detailScroll=Math.Max(0,detailScroll+(vertical!=0?vertical:horizontal)*46);return;}
            if(Tab=="upgrade"){if(zone==0&&vertical!=0)SelectUpgrade(selectedUpgrade+vertical);if(horizontal<0)zone=0;else if(horizontal>0)zone=2;else if(zone==2&&vertical>0)zone=3;else if(zone==3&&vertical!=0)detailScroll=Math.Max(0,detailScroll+vertical*46);return;}
            if(zone==0){if(vertical!=0)SelectSlot(selectedSlot+vertical);if(horizontal>0&&Alternatives.Count>0)zone=1;}
            else if(zone==1){if(horizontal<0)zone=0;else if(horizontal>0||vertical>0&&selectedCandidate==Alternatives.Count-1){zone=2;action=0;}else if(vertical!=0)SelectCandidate(selectedCandidate+vertical);}
            else if(zone==2){if(vertical<0)zone=1;else if(vertical>0)zone=3;else if(horizontal<0){if(action==0)zone=0;else action=0;}else if(horizontal>0)action=1;}
            else if(horizontal<0)zone=1;else detailScroll=Math.Max(0,detailScroll+(vertical!=0?vertical:horizontal)*46);
        }
        public void ConfirmSelection()
        {
            if(Tab=="appearance"){if(selectedAppearance<5)CycleAppearance(1);else if(Text(model.Worn(model.ClothingSlotIds[selectedAppearance-5]),"item")!="")dyeMode=!dyeMode;return;}
            if(Tab=="overview"){zone=zone==3?0:3;return;}
            if(Tab=="upgrade"){if(zone==0)zone=2;else RequestUpgrade();return;}
            if(zone==0)zone=1;else if(zone==1){zone=2;action=0;}else if(zone==2)ApplyGearAction(action);else zone=1;
        }
        public bool CanEquip => Candidate!=""&&model.State.Count(Candidate)>0&&model.Equipped(SlotId)!=Candidate;
        public bool CanRemove => model.EquipmentSlotIds.Contains(SlotId)&&model.Equipped(SlotId)!="";
        public void ApplyGearAction(int index)
        {bool changed=index==0?CanEquip&&model.Equip(Candidate):CanRemove&&model.Unequip(SlotId);if(changed)message=T("Uitrusting aangepast.","Equipment updated.");Refresh();}
        public void CycleAppearance(int direction)
        {
            var appearance=model.State.Get("appearance");string gender=Text(appearance,"gender","m");
            if(dyeMode&&selectedAppearance>=5)
            {string slot=model.ClothingSlotIds[selectedAppearance-5];int count=Cat("dyeColors").Items.Count;model.Dye(slot,Mod((int)Number(model.Worn(slot),"dye")+direction,count));return;}
            switch(selectedAppearance)
            {
                case 0:var genders=model.GenderIds;model.SetGender(genders[Mod(genders.ToList().IndexOf(gender)+direction,genders.Count)]);break;
                case 1:var hairs=model.HairIds(gender);model.SetHair(hairs[Mod(hairs.ToList().IndexOf(Text(appearance,"hair"))+direction,hairs.Count)]);break;
                case 2:model.SetHairColor(Mod((int)Number(appearance,"hair_color")+direction,Cat("hairColors").Items.Count));break;
                case 3:var eyes=model.EyeIds;model.SetEyes(eyes[Mod(eyes.ToList().IndexOf(Text(appearance,"eyes"))+direction,eyes.Count)]);break;
                case 4:model.SetEyeColor(Mod((int)Number(appearance,"eye_color")+direction,Cat("eyeColors").Items.Count));break;
                default:string slot=model.ClothingSlotIds[selectedAppearance-5];var choices=new[]{""}.Concat(model.OwnedClothing(slot)).ToArray();string next=choices[Mod(Array.IndexOf(choices,Text(model.Worn(slot),"item"))+direction,choices.Length)];if(next=="")model.Unwear(slot);else model.Wear(next);break;
            }
        }
        string WeaponTarget()
        {foreach(var row in Cat("weaponUpgrades").Entries)if(Text(row.Value,"from")==model.State.Weapon)return Text(row.Value,"target",row.Key.AsString());return "";}
        string UpgradeId => selectedUpgrade<=0?WeaponTarget():UpgradeIds[Mathf.Clamp(selectedUpgrade-1,0,UpgradeIds.Count-1)];
        FoundationValue UpgradeRecord => selectedUpgrade<=0?Get(Cat("weaponUpgrades"),UpgradeId):Get(Cat("upgradeRecipes"),UpgradeId);
        public string UpgradeReason => UpgradeId==""?T("De hoogste verbetering is al bereikt.","You already have the highest upgrade."):selectedUpgrade==0?model.WeaponUpgradeReason(UpgradeId):model.UpgradeReason(UpgradeId);
        public void RequestUpgrade(){if(UpgradeId==""||UpgradeReason!="")return;pendingKind=selectedUpgrade==0?"weapon":"gear";pendingId=UpgradeId;pendingConfirm=true;}
        public void ConfirmUpgrade()
        {if(pendingKind=="")return;bool changed=pendingKind=="weapon"?model.UpgradeWeapon(pendingId):model.UpgradeGear(pendingId);pendingKind="";message=changed?T("Verbetering voltooid.","Upgrade complete."):Tr(model.LastMessage);Refresh();}

        void Styles()
        {
            text=new GUIStyle(GUI.skin.label){font=catalog!=null?catalog.originalFont:GUI.skin.font,fontSize=16,padding=new RectOffset(0,0,0,0),normal={textColor=new Color(.91f,.94f,.88f)}};
            small=new GUIStyle(text){fontSize=13,normal={textColor=new Color(.70f,.80f,.78f)}};title=new GUIStyle(text){fontSize=23,fontStyle=FontStyle.Bold};wrap=new GUIStyle(text){wordWrap=true};button=new GUIStyle(text){alignment=TextAnchor.MiddleCenter};
        }
        static void Fill(Rect rect,Color color){var old=GUI.color;GUI.color=color;GUI.DrawTexture(rect,Texture2D.whiteTexture);GUI.color=old;}
        static void Border(Rect rect,Color color,float thick=1){Fill(new Rect(rect.x,rect.y,rect.width,thick),color);Fill(new Rect(rect.x,rect.yMax-thick,rect.width,thick),color);Fill(new Rect(rect.x,rect.y,thick,rect.height),color);Fill(new Rect(rect.xMax-thick,rect.y,thick,rect.height),color);}
        static Color Gold=>new Color(.93f,.82f,.56f);
        static Color Blue=>new Color(.51f,.76f,.85f);
        void Card(Rect rect,bool chosen=false){Fill(rect,new Color(.035f,.075f,.09f,.99f));Border(rect,chosen?Gold:new Color(.22f,.36f,.39f),chosen?2:1);}
        void Label(Rect rect,string value,GUIStyle style=null,bool fit=false)
        {var used=new GUIStyle(style??text);if(fit)while(used.fontSize>11&&used.CalcSize(new GUIContent(value)).x>rect.width)used.fontSize--;GUI.BeginGroup(rect);GUI.Label(new Rect(0,0,rect.width,rect.height),value,used);GUI.EndGroup();}
        bool Button(Rect rect,string label,bool selected=false,bool enabled=true)
        {Fill(rect,enabled?(selected?new Color(.19f,.35f,.33f):new Color(.08f,.16f,.19f)):new Color(.06f,.10f,.12f));Border(rect,selected?Gold:new Color(.27f,.40f,.43f),selected?2:1);var style=new GUIStyle(button);style.normal.textColor=enabled?text.normal.textColor:new Color(.40f,.48f,.48f);Label(rect,label,style,true);bool old=GUI.enabled;GUI.enabled=old&&enabled&&!controller;bool clicked=GUI.Button(rect,GUIContent.none,GUIStyle.none);GUI.enabled=old;return clicked;}
        void Icon(string id,Rect rect)
        {
            if(id=="")return;if(ItemIcon!=null){ItemIcon(id,rect);return;}
            string sheet=model.Inventory.ItemSheet(id),key=sheet=="items_equipment"?"generated:equipment-icons":"png:assets/"+sheet+".png";
            if(!textures.TryGetValue(key,out var texture)){texture=catalog.textures.FirstOrDefault(t=>t.definition.id==key)?.texture;textures[key]=texture;}
            if(texture==null)return;float left=model.Inventory.ItemIcon(id)*16;if(left+16>texture.width)return;
            GUI.DrawTextureWithTexCoords(rect,texture,new Rect(left/texture.width,(texture.height-16f)/texture.height,16f/texture.width,16f/texture.height));
        }
        void Preview(Rect rect,string direction){if(AvatarPreview==null)return;AvatarPreview(rect,direction);PreviewDraws++;}
        public void Draw()
        {
            if(!IsOpen)return;if(controller&&(Event.current.isMouse||Event.current.type==EventType.ScrollWheel))Event.current.Use();
            if(!controller&&Event.current.type==EventType.MouseDown&&Event.current.button==1){if(pendingKind!="")pendingKind="";else if(dyeMode)dyeMode=false;else Close();Event.current.Use();if(!IsOpen)return;}
            Styles();PreviewDraws=0;RenderedSelectedBounds=Rect.zero;Fill(new Rect(0,0,1152,648),new Color(.01f,.025f,.035f,.80f));Card(PanelRect);Fill(new Rect(78,70,996,4),Blue);
            bool oldEnabled=GUI.enabled;GUI.enabled=oldEnabled&&!dyeMode&&pendingKind=="";
            Label(new Rect(98,82,170,34),T("Je held","Your hero"),title);
            if(Button(new Rect(280,84,114,30),T("Naar tas","Backpack")))InventoryRequested?.Invoke();
            string[] labels={T("Overzicht","Overview"),T("Uitrusting","Equipment"),T("Uiterlijk","Appearance"),T("Verbeteren","Upgrades")};
            for(int i=0;i<tabs.Length;i++)if(Button(new Rect(410+i*154,84,146,30),labels[i],Tab==tabs[i]))ChangeTab(tabs[i]);
            if(Button(new Rect(1034,84,20,30),"×"))Close();
            Label(new Rect(98,120,956,22),Tab=="equipment"?T("Bladeren verandert niets. Kies uitrusten of afdoen om je gedragen set te wijzigen.","Browsing changes nothing. Choose Equip or Remove to change your worn set."):Tab=="appearance"?T("Uiterlijk verandert direct; kleding is zichtbaar over je uitrusting en geeft geen bonussen.","Appearance choices apply immediately; clothes cover equipment and give no bonuses."):Tab=="upgrade"?T("Originele kosten en locaties. Verbeteren kan alleen bij de juiste persoon of werkbank.","Original costs and locations. Upgrades require the right person or workbench."):T("Ervaring, je gedragen set en duidelijke routes naar de volgende verbetering.","Experience, your worn set, and clear routes to your next upgrade."),small,true);
            if(Tab=="overview")DrawOverview();else if(Tab=="equipment")DrawGear();else if(Tab=="appearance")DrawAppearance();else DrawUpgrade();
            Label(new Rect(98,598,956,18),message!=""?message:controller?T("LB / RB: tabblad · rechterstick: bladeren · A: kiezen · B: stap terug","LB / RB: tab · right stick: browse · A: select · B: back"):T("PageUp / PageDown: tabblad · pijlen: kiezen · Enter: bevestigen · Esc: stap terug","PageUp / PageDown: tab · arrows: select · Enter: confirm · Esc: back"),small,true);
            GUI.enabled=oldEnabled;if(dyeMode)DrawDyes();if(pendingKind!="")DrawConfirmation();
        }
        void DrawOverview()
        {
            var progress=model.Progress;Card(new Rect(98,150,956,96));Label(new Rect(114,162,230,32),T("Held · niveau ","Hero · level ")+progress.Level,title);
            Label(new Rect(360,166,420,24),progress.AtMax?T("Alle heldlevels behaald","All hero levels reached"):progress.Current+" / "+progress.Needed+" XP",text);
            Fill(new Rect(360,196,420,8),new Color(.08f,.13f,.15f));Fill(new Rect(360,196,420*(progress.AtMax?1:Mathf.Clamp01((float)progress.Current/Math.Max(1,progress.Needed))),8),Blue);
            Label(new Rect(800,163,150,43),progress.AtMax?T("Maximaal niveau","Maximum level"):T("Volgend niveau\n+","Next level\n+")+progress.NextReward+T(" munten"," coins"),small);
            Label(new Rect(114,218,820,22),T("XP uit opdrachten en gevechten buiten de arena; levels geven munten, geen gratis gear.","XP comes from quests and fights outside the arena; levels award coins, not free gear."),small,true);Preview(new Rect(968,159,64,70),"down");
            string[] baseLabels={T("Zwaard & upgrades","Sword & upgrades"),T("Laarzen & snelheid","Boots & speed"),T("Hartjes & overleven","Hearts & survival"),T("Gereedschap & boog","Tools & bow")};
            int total=4+SkillIds.Count;
            for(int i=0;i<total;i++)
            {Rect rect=OverviewRowRect(i);string label=i<4?baseLabels[i]:Tr(Text(Get(Cat("skills"),SkillIds[i-4]),"name",SkillIds[i-4]));if(Button(rect,label,i==selectedOverview))SelectOverview(i);if(i==selectedOverview)RenderedSelectedBounds=rect;}
            Card(new Rect(358,260,696,330),zone==3);Label(new Rect(376,274,660,30),selectedOverview<4?baseLabels[selectedOverview]:Tr(Text(Get(Cat("skills"),SkillIds[selectedOverview-4]),"name")),new GUIStyle(title){fontSize=21},true);
            Description(new Rect(376,316,660,254),OverviewText(selectedOverview));
        }
        void DrawPreviewCard()
        {
            Card(new Rect(98,180,240,352));Label(new Rect(112,194,212,26),T("Je gedragen uiterlijk","Your worn appearance"),new GUIStyle(text){fontStyle=FontStyle.Bold},true);
            string[] directions={"down","up","right"};string[] names={T("Voor","Front"),T("Achter","Back"),T("Zij","Side")};
            for(int i=0;i<3;i++){Preview(new Rect(108+i*74,242,72,112),directions[i]);Label(new Rect(108+i*74,358,72,20),names[i],new GUIStyle(small){alignment=TextAnchor.MiddleCenter});}
            string stats=T("Pantser ","Armor ")+model.Bonus("armor")+"   ·   "+(100+model.Bonus("stamina_max"))+T(" stamina"," stamina")+"\n"+T("Set-snelheid ","Set speed ")+((model.State.Count("boots")>0?ProgressionModel.SourceBootsMultiplier:1)*(1+model.Bonus("move_speed"))*100).ToString("0")+"%\n"+T("Oppakbereik ","Pickup range ")+(54+model.Bonus("magnet_range"));
            Label(new Rect(112,398,212,76),stats,new GUIStyle(wrap){fontSize=14});
            Label(new Rect(112,484,212,38),T("Kleding kan harnas bedekken; de echte bonus blijft actief.","Clothes can cover armor; its actual bonus remains active."),new GUIStyle(small){wordWrap=true});
        }
        void DrawGear()
        {
            DrawPreviewCard();Card(GearSlotsRect);
            for(int i=0;i<GearSlots.Count;i++)
            {
                string slot=GearSlots[i],item=model.CurrentItem(slot);Rect rect=SlotRect(i);Card(rect,i==selectedSlot);Icon(item,new Rect(rect.x+7,rect.y+8,28,28));
                Label(new Rect(rect.x+43,rect.y+4,151,18),SlotName(slot),small,true);Label(new Rect(rect.x+43,rect.y+22,151,18),Name(item),new GUIStyle(text){fontSize=13},true);
                if(Pointer(rect))SelectSlot(i);if(i==selectedSlot&&zone!=1)RenderedSelectedBounds=rect;
            }
            var alternatives=Alternatives;
            if(alternatives.Count==0)
            {Card(CandidatesRect);Label(new Rect(602,194,436,30),T("Automatisch actief","Automatically active"),new GUIStyle(title){fontSize=20});Label(new Rect(602,236,436,48),T("Deze plek volgt je verdiende of gekochte verbetering.","This slot follows your earned or purchased upgrade."),wrap);}
            else
            {
                Label(new Rect(586,153,328,23),T("Alternatieven · ","Alternatives · ")+((selectedCandidate/2)+1)+" / "+((alternatives.Count+1)/2),small);
                if(Button(new Rect(956,150,44,26),"‹",false,selectedCandidate>=2))SelectCandidate(selectedCandidate-2);
                if(Button(new Rect(1010,150,44,26),"›",false,selectedCandidate/2*2+2<alternatives.Count))SelectCandidate(Math.Min(alternatives.Count-1,selectedCandidate+2));
                for(int i=selectedCandidate/2*2;i<Math.Min(selectedCandidate/2*2+2,alternatives.Count);i++)
                {
                    string id=alternatives[i];Rect rect=CandidateRect(i);Card(rect,i==selectedCandidate);Icon(id,new Rect(rect.x+8,rect.y+7,32,32));
                    Label(new Rect(rect.x+50,rect.y+5,250,23),Name(id),new GUIStyle(text){fontStyle=FontStyle.Bold,fontSize=15},true);
                    Label(new Rect(rect.x+50,rect.y+29,380,16),Tr(model.StatsText(id)),new GUIStyle(small){fontSize=12},true);
                    string status=model.Equipped(SlotId)==id?T("Uitgerust","Equipped"):model.State.Count(id)>0?T("In bezit","Owned"):T("Niet in bezit","Not owned");
                    Label(new Rect(rect.x+304,rect.y+6,136,20),status,new GUIStyle(small){alignment=TextAnchor.MiddleRight,normal={textColor=model.State.Count(id)>0?Gold:small.normal.textColor}},true);
                    if(Pointer(rect))SelectCandidate(i);if(i==selectedCandidate&&zone==1)RenderedSelectedBounds=rect;
                }
            }
            Card(new Rect(586,308,468,224),zone==3);Description(new Rect(602,322,436,196),GearDetail());
            if(Button(new Rect(586,544,230,38),T("Uitrusten","Equip"),zone==2&&action==0,CanEquip))ApplyGearAction(0);
            if(Button(new Rect(824,544,230,38),T("Afdoen","Remove"),zone==2&&action==1,CanRemove))ApplyGearAction(1);
        }
        string SlotName(string slot)=>slot=="weapon"?T("Zwaard","Sword"):slot=="boots"?T("Laarzen","Boots"):Tr(Text(Get(Cat("gearSlots"),slot),"name",slot));
        string GearDetail()
        {
            if(SlotId=="weapon")return OverviewText(0);
            if(SlotId=="boots")return OverviewText(1);
            if(Candidate=="")return T("Voor deze plek zijn nog geen alternatieven.","There are no alternatives for this slot.");
            string current=model.Equipped(SlotId);
            return T("Nu: ","Now: ")+(current==""?T("Geen bonus","No bonus"):Tr(model.StatsText(current)))+"\n"+T("Na wisselen: ","After changing: ")+Tr(model.StatsText(Candidate))+"\n\n"+Tr(model.ComparisonText(Candidate))+"\n\n"+Tr(model.Inventory.ItemDescription(Candidate))+"\n\n"+SourceText(Candidate);
        }
        void DrawAppearance()
        {
            DrawPreviewCard();Label(new Rect(360,151,694,24),T("Pijlen veranderen deze keuze direct; bevestigen op kleding opent verf.","Arrows apply this choice immediately; confirm on clothing opens dyes."),small,true);
            for(int i=0;i<5+model.ClothingSlotIds.Count;i++)
            {
                Rect rect=AppearanceRowRect(i);Card(rect,i==selectedAppearance);
                Label(new Rect(rect.x+12,rect.y+7,150,22),AppearanceLabel(i),new GUIStyle(small){fontSize=14},true);
                Label(new Rect(rect.x+170,rect.y+7,414,22),AppearanceValue(i),new GUIStyle(text){fontSize=15},true);
                if(Button(new Rect(rect.xMax-82,rect.y+3,32,28),"‹",i==selectedAppearance)){SelectAppearanceRow(i);CycleAppearance(-1);}
                if(Button(new Rect(rect.xMax-38,rect.y+3,32,28),"›",i==selectedAppearance)){SelectAppearanceRow(i);CycleAppearance(1);}
                if(Pointer(new Rect(rect.x,rect.y,rect.width-92,rect.height))){bool twice=Event.current.clickCount>1;SelectAppearanceRow(i);if(twice)ConfirmSelection();}
                if(i==selectedAppearance)RenderedSelectedBounds=rect;
            }
            Label(new Rect(360,566,694,22),T("90 haarstijlen · 24 kledingstukken · vijf aparte kledingvakken.","90 hairstyles · 24 clothes · five separate clothing slots."),small,true);
        }
        string AppearanceLabel(int row)
        {string[] nl={"Geslacht","Haarstijl","Haarkleur","Oogstijl","Oogkleur"},en={"Gender","Hairstyle","Hair color","Eye style","Eye color"};return row<5?T(nl[row],en[row]):Tr(Text(Get(Cat("clothingSlots"),model.ClothingSlotIds[row-5]),"name"));}
        string AppearanceValue(int row)
        {
            var a=model.State.Get("appearance");string gender=Text(a,"gender","m");
            if(row==0)return Tr(Text(Get(Cat("genders"),gender),"name",gender));
            if(row==1){var ids=model.HairIds(gender);string hair=Text(a,"hair");return Tr(Text(Get(Cat(gender=="v"?"hairV":"hairM"),hair),"name",hair))+"  ("+(ids.ToList().IndexOf(hair)+1)+"/"+ids.Count+")";}
            if(row==2)return ColorName("hairColors",(int)Number(a,"hair_color"));
            if(row==3){string eyes=Text(a,"eyes");return Tr(Text(Get(Cat("eyes"),eyes),"name",eyes))+"  ("+(model.EyeIds.ToList().IndexOf(eyes)+1)+"/"+model.EyeIds.Count+")";}
            if(row==4)return ColorName("eyeColors",(int)Number(a,"eye_color"));
            string slot=model.ClothingSlotIds[row-5];var worn=model.Worn(slot);string item=Text(worn,"item");
            return item==""?(model.OwnedClothing(slot).Count==0?T("Niets in bezit","Nothing owned"):T("Niets aan","Nothing worn")):Name(item)+" · "+ColorName("dyeColors",(int)Number(worn,"dye"));
        }
        string ColorName(string kind,int index){var colors=Cat(kind).Items;return colors.Count==0?"":Tr(Text(colors[Mathf.Clamp(index,0,colors.Count-1)],"name"));}
        Color ColorValue(string kind,int index)
        {
            var colors=Cat(kind).Items;if(colors.Count==0)return Color.white;var value=Get(colors[Mathf.Clamp(index,0,colors.Count-1)],"color");
            if(value.Kind=="array"&&value.Items.Count>=3)return new Color((float)value.Items[0].AsDouble(),(float)value.Items[1].AsDouble(),(float)value.Items[2].AsDouble(),value.Items.Count>3?(float)value.Items[3].AsDouble():1);
            if(value.Kind=="color"){var values=value.Require("value").Items;return new Color((float)values[0].AsDouble(),(float)values[1].AsDouble(),(float)values[2].AsDouble(),(float)values[3].AsDouble());}
            return Color.white;
        }
        void DrawDyes()
        {
            Fill(new Rect(0,0,1152,648),new Color(0,0,0,.60f));int count=Cat("dyeColors").Items.Count;int lines=(count+9)/10;
            Rect box=new Rect(450,218,548,112+lines*48);Card(box,true);Label(new Rect(470,234,508,28),T("Verf voor ","Dye for ")+Tr(Text(Get(Cat("clothingSlots"),model.ClothingSlotIds[selectedAppearance-5]),"name")),new GUIStyle(title){fontSize=20});
            string slot=model.ClothingSlotIds[selectedAppearance-5];int current=(int)Number(model.Worn(slot),"dye");
            for(int i=0;i<count;i++){Rect swatch=new Rect(474+i%10*50,278+i/10*48,34,32);Fill(swatch,ColorValue("dyeColors",i));Border(swatch,i==current?Gold:new Color(.5f,.6f,.6f),i==current?3:1);if(Pointer(swatch))model.Dye(slot,i);}
            Label(new Rect(474,280+lines*48,370,24),ColorName("dyeColors",current),text,true);if(Button(new Rect(866,278+lines*48,108,30),T("Klaar","Done"),true))dyeMode=false;
        }
        void DrawUpgrade()
        {
            Label(new Rect(98,150,956,24),T("Lees wat je nodig hebt; de wereld bepaalt waar een verbetering beschikbaar is.","Read what you need; the world determines where an upgrade is available."),small,true);
            var ids=UpgradeIds;for(int i=0;i<=ids.Count;i++){Rect rect=UpgradeRowRect(i);string label=i==0?T("Zwaard bij Greta","Sword with Greta"):Name(Text(Get(Cat("upgradeRecipes"),ids[i-1]),"output",ids[i-1]));if(Button(rect,label,i==selectedUpgrade))SelectUpgrade(i);if(i==selectedUpgrade)RenderedSelectedBounds=rect;}
            Card(new Rect(358,180,696,352),zone==3);Label(new Rect(376,194,660,32),UpgradeId==""?T("Hoogste niveau bereikt","Highest tier reached"):selectedUpgrade==0?Name(Text(Get(Cat("weapons"),UpgradeId),"item",UpgradeId)):Name(Text(UpgradeRecord,"output",UpgradeId)),new GUIStyle(title){fontSize=21},true);
            Description(new Rect(376,244,660,268),UpgradeText());
            string reason=UpgradeReason;Label(new Rect(98,544,476,42),reason==""?T("De materialen en de juiste werkplek zijn beschikbaar.","The materials and correct workplace are available."):Tr(reason),new GUIStyle(small){wordWrap=true});
            if(Button(new Rect(586,544,468,38),T("Deze verbetering uitvoeren","Make this upgrade"),zone==2,reason==""))RequestUpgrade();
        }
        string UpgradeText()
        {
            if(UpgradeId=="")return T("Je hebt de hoogste bestaande verbetering al.","You already have the highest existing upgrade.");
            var record=UpgradeRecord;
            if(selectedUpgrade==0)
            {
                if(UpgradeId=="star"||Text(record,"kind")=="guardian_reward")return T("Het Sterrenzwaard is een verdiende beloning. Herstel de Blauwe Kaart, daal af onder de Kristaltempel en versla De Vergeten Wachter. Dit scherm geeft het zwaard niet gratis.","The Star Sword is an earned reward. Restore the Blue Map, descend below the Crystal Temple, and defeat the Forgotten Guardian. This screen does not grant it for free.");
                return T("Greta · in de smederij ten noordwesten van het dorpsplein. Loop naar haar toe om te smeden.\n\nMunten: ","Greta · inside the smithy northwest of the town square. Approach her to forge.\n\nCoins: ")+model.State.Coins+" / "+Number(record,"coins")+"\n"+MaterialsText(Get(record,"materials"),false)+"\n\n"+T("Zwaardupgrades gebruiken alleen materialen in je tas; een held- of beroepsniveau is niet vereist.","Sword upgrades use only materials in your backpack; no hero or profession level is required.");
            }
            return RecipeText(UpgradeId,record)+"\n\n"+Tr(model.Inventory.ItemDescription(Text(record,"output")))+"\n\n"+T("De bestaande basisuitrusting wordt verbruikt. Een gedragen basisstuk wordt vervangen volgens de originele regels; energie wordt nooit bijgevuld.","The existing base equipment is consumed. A worn base item is replaced according to the original rules; energy is never refilled.");
        }
        string MaterialsText(FoundationValue inputs,bool nearby)
        {return string.Join("\n",inputs.Entries.Select(row=>Name(row.Key.AsString())+": "+(nearby?model.Inventory.Available(row.Key.AsString()):model.State.Count(row.Key.AsString()))+" / "+row.Value.AsInt64()));}
        string RecipeText(string id,FoundationValue recipe)
        {
            string skill=Text(recipe,"skill"),station=Text(recipe,"station","anywhere");string stationLabel=Tr(Text(Cat("stationText"),station,station));
            if(stationLabel==station&&Cat("stationText").TryGet(station,out var raw)&&raw.Kind=="string")stationLabel=Tr(raw.AsString());
            string text=T("Recept: ","Recipe: ")+Name(Text(recipe,"output",id))+"\n"+Tr(Text(Get(Cat("skills"),skill),"name",skill))+T(" · niveau "," · level ")+Number(recipe,"level")+"\n"+stationLabel+"\n\n"+MaterialsText(Get(recipe,"inputs"),true);
            if(recipe.TryGet("unlock_hint",out var hint)&&hint.Kind=="string")text+="\n\n"+Tr(hint.AsString());return text;
        }
        string SourceText(string id)
        {
            foreach(var shop in Cat("shops").Entries)foreach(var offer in Get(shop.Value,"items").Items)if(Text(offer,"item")==id)return Tr(Text(shop.Value,"name",shop.Key.AsString()))+T(" · dorpswinkel\nMunten: "," · village shop\nCoins: ")+model.State.Coins+" / "+Number(offer,"price");
            foreach(var recipe in Cat("recipes").Entries)if(Text(recipe.Value,"output")==id)return RecipeText(recipe.Key.AsString(),recipe.Value);
            switch(id)
            {case "gear_ra_grip":return T("Beloning: breng de weerkaart terug naar het kamp in de Bergpas.","Reward: return the weather chart to the camp in Mountain Pass.");case "gear_ra_compass":return T("Beloning: orden de gebeurtenissen in het Rietarchief.","Reward: put the Reed Archive events in order.");case "gear_rf_keepsake":return T("Beloning: voltooi Wilfreds gedenksteen in de Ruïne.","Reward: complete Wilfred's memorial in the Ruins.");case "gear_rf_cord":return T("Vind de schuilplaats achter de klankschalen in de Echo-grot.","Find the shelter behind the singing bowls in Echo Cave.");case "gear_bastion_coat":return T("Beloning: verdedig de twee vuurkorven in IJsdal.","Reward: defend the two braziers in Icevale.");}
            return T("Vind of verdien dit voorwerp in de bestaande wereld.","Find or earn this item in the existing world.");
        }
        string OverviewText(int index)
        {
            if(index==0)
            {var weapon=Get(Cat("weapons"),model.State.Weapon);string next=WeaponTarget();return Name(Text(weapon,"item"))+"\n"+T("Schade: ","Damage: ")+Number(weapon,"damage")+T(" · bereik: "," · reach: ")+Number(weapon,"reach")+"\n"+T("Pantser: ","Armor: ")+model.Bonus("armor")+T(" · stamina: "," · stamina: ")+(100+model.Bonus("stamina_max"))+"\n\n"+(next==""?T("Het sterkste bestaande zwaard is actief.","The strongest existing sword is active."):T("Volgende upgrade: ","Next upgrade: ")+Name(Text(Get(Cat("weapons"),next),"item",next)))+"\n\n"+T("Houten → IJzeren → Kristal- → Sterrenzwaard. Zie Verbeteren voor de precieze kosten en locatie.\n\nHoofd, borst, handen, hals en ring verwissel je op Uitrusting. Levels geven munten en veranderen je schade niet automatisch.","Wood → Iron → Crystal → Star Sword. See Upgrades for exact costs and location.\n\nChange head, chest, hands, neck and ring on Equipment. Levels award coins and do not automatically increase damage.");}
            if(index==1)return (model.State.Count("boots")>0?T("Snelle laarzen actief: +18% lopen en rennen.","Fast boots active: +18% walking and sprinting."):T("Koop snelle laarzen bij Tobias in de dorpswinkel naast de smederij. Daarna zijn ze automatisch actief: +18% snelheid.","Buy fast boots from Tobias in the village shop beside the smithy. They then activate automatically: +18% speed."))+"\n\n"+SourceText("boots")+"\n\n"+T("Paden en rennen geven hun eigen snelheidsbonus bovenop je laarzen en gedragen set.","Paths and sprinting add their own speed bonuses to your boots and worn equipment.");
            if(index==2)return T("Leven: ","Health: ")+model.State.Hp+" / "+model.State.MaxHp+T(" · maximaal 8 hartjes.\n\nElke hartcontainer geeft blijvend één hartje. Verdien er één door Pims kat Muis thuis te brengen. Andere containers zitten in de noordoostelijke kist van de Echo-grot en de beloningskist van De Vergeten Wachter.\n\nDe Diepte opent nadat de Blauwe Kaart is hersteld."," · maximum 8 hearts.\n\nEach heart container permanently adds one heart. Earn one by returning Pim's cat Muis. Other containers are in Echo Cave's northeast chest and the Forgotten Guardian's reward chest.\n\nThe Depths open after the Blue Map is restored.");
            if(index==3)
            {var blocks=new List<string>{T("Gereedschap werkt automatisch en slijt niet.","Tools work automatically and do not wear out.")};foreach(string id in new[]{"prof_axe","prof_iron_axe","prof_pickaxe","prof_copper_pickaxe"})blocks.Add(Name(id)+(model.State.Count(id)>0?T(" · in bezit"," · owned"):T(" · niet in bezit"," · not owned"))+"\n"+SourceText(id));blocks.Add(T("Hengel: gratis van Joris aan het Zilvermeer. Boog: verkrijgbaar bij Tobias; zie het bestaande winkelgesprek.","Fishing rod: free from Joris at Silver Lake. Bow: available from Tobias through his existing shop dialogue."));return string.Join("\n\n",blocks);}
            string skill=SkillIds[Mathf.Clamp(index-4,0,SkillIds.Count-1)];var info=Get(Cat("skills"),skill);long xp=(long)Number(Get(model.State.Get("professions"),"xp"),skill);int level=1;while(level<10&&xp>=15*level*(level+1))level++;
            return T("Niveau ","Level ")+level+" / 10\n"+(level==10?T("Meester · maximaal niveau","Master · maximum level"):(xp-15*(level-1)*level)+" / "+(30*level)+" XP")+"\n\n"+Tr(Text(info,"desc"))+"\n\n"+T("Beroepen stijgen door verzamelen, vissen en maken. Hun eigen recepten en materialen blijven gekoppeld aan de bestaande wereld en werkbanken.","Professions grow through gathering, fishing and crafting. Their recipes and materials stay tied to the existing world and workbenches.");
        }
        bool Pointer(Rect rect)
        {bool old=GUI.enabled;GUI.enabled=old&&!controller;bool result=GUI.Button(rect,GUIContent.none,GUIStyle.none);GUI.enabled=old;return result;}
        void Description(Rect rect,string value)
        {var style=new GUIStyle(wrap){fontSize=15};float height=Math.Max(rect.height,style.CalcHeight(new GUIContent(value),rect.width-18));maxDetailsScroll=height-rect.height;detailScroll=Mathf.Clamp(detailScroll,0,maxDetailsScroll);bool old=GUI.enabled;GUI.enabled=old&&!controller;Vector2 next=GUI.BeginScrollView(rect,new Vector2(0,detailScroll),new Rect(0,0,rect.width-18,height),false,height>rect.height);GUI.enabled=old;detailScroll=next.y;Label(new Rect(0,0,rect.width-18,height),value,style);GUI.EndScrollView();}
        void DrawConfirmation()
        {
            Fill(new Rect(0,0,1152,648),new Color(0,0,0,.70f));Card(new Rect(304,204,544,320),true);
            Label(new Rect(328,224,496,32),T("Verbetering bevestigen","Confirm upgrade"),new GUIStyle(title){fontSize=21});
            var record=pendingKind=="weapon"?Get(Cat("weaponUpgrades"),pendingId):Get(Cat("upgradeRecipes"),pendingId);
            string item=pendingKind=="weapon"?Text(Get(Cat("weapons"),pendingId),"item",pendingId):Text(record,"output",pendingId);
            string costs=pendingKind=="weapon"?T("Munten: ","Coins: ")+Number(record,"coins")+"\n"+string.Join("\n",Get(record,"materials").Entries.Select(row=>Name(row.Key.AsString())+" ×"+row.Value.AsInt64())):string.Join("\n",Get(record,"inputs").Entries.Select(row=>Name(row.Key.AsString())+" ×"+row.Value.AsInt64()));
            string body=Name(item)+"\n\n"+T("Dit wordt verbruikt:\n","These costs are consumed:\n")+costs;
            Label(new Rect(328,270,496,176),body,new GUIStyle(wrap){fontSize=15});
            if(Button(new Rect(328,464,238,38),T("Verbeteren","Upgrade"),pendingConfirm))ConfirmUpgrade();
            if(Button(new Rect(586,464,238,38),T("Annuleren","Cancel"),!pendingConfirm))pendingKind="";
        }
    }
}
