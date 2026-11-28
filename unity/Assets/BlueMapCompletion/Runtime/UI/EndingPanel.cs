using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Phase6;
using BlueMapMigration.Player;
using BlueMapMigration.Story;
using UnityEngine;
namespace BlueMapMigration.Completion
{
 /// <summary>The ending: the king falls, the village speaks, your adventure in numbers, the credits and a thank you.</summary>
 public sealed class EndingPanel
 {
  public sealed class Page{public string Type,Speaker;public string[] Lines;}
  /// <summary>The credits of scripts/data/credits.gd: style and text, in order.</summary>
  public static readonly (string style,string text)[] Credits={
   ("title","Bluemap Quest"),("",""),("heading","Een spel voor de WTP-community"),("",""),("heading","Bedacht door"),("text","de eigenaar van WTP"),("",""),
   ("heading","Gebouwd met"),("text","Claude (Anthropic)"),("",""),("heading","Verhaal en personages"),("text","Oudste Bram, Greta, Tobias, Mila, Pim,"),
   ("text","Wachter Hein, Anja, Joost, Tessa, Wilfred en Muis"),("",""),("heading","Pixel art"),("text","Zelf getekend met code (tools/make_art.py)"),("",""),
   ("heading","Muziek en geluid"),("text","Zelf gesynthetiseerd (tools/make_audio.py)"),("",""),("heading","Techniek"),("text","Godot Engine 4 (MIT-licentie)"),
   ("text","Python, Pillow en NumPy"),("",""),("heading","Diep onder de tempel..."),("text","...slaapt De Vergeten Wachter nog. Voorlopig."),("",""),("",""),
   ("heading","Speciale dank"),("text","Aan jou, voor het spelen!")};
  public const float TypeSpeed=45,CreditsSpeed=46,CreditsLine=40;
  readonly Phase6Catalog catalog;readonly Func<string,string> translate,binding;readonly Func<string,string,string> bilingual;
  readonly List<Page> pages=new List<Page>();InputFrame lastHandled,openingFrame;double typed,scroll,time;int line;
  public bool IsOpen {get;private set;} public int PageIndex {get;private set;} public int Draws {get;private set;} public bool LayoutFits {get;private set;}=true;
  public IReadOnlyList<Page> Pages=>pages;public Page Current=>IsOpen&&PageIndex<pages.Count?pages[PageIndex]:null;
  public IReadOnlyList<(string label,string value)> Stats {get;private set;}=Array.Empty<(string,string)>();
  public double CreditsHeight=>Credits.Length*CreditsLine+648;public bool CreditsDone=>scroll>=CreditsHeight;
  public event Action Finished;
  public EndingPanel(Phase6Catalog sourceCatalog,Func<string,string> translator,Func<string,string,string> textTranslator,Func<string,string> bindingLabel)
  {catalog=sourceCatalog;translate=translator??(s=>s);bilingual=textTranslator??((nl,en)=>nl);binding=bindingLabel??(s=>s);}
  public void Open(IReadOnlyList<(string label,string value)> stats)
  {
   Stats=stats??Array.Empty<(string,string)>();pages.Clear();
   pages.Add(new Page{Type="text",Speaker="",Lines=new[]{"Met een enorme plof zakt de Slijmkoning in elkaar.","Het groene gel trekt weg uit de tempel, sijpelt als een rivier door het land... en verdwijnt.","Het wordt heel stil in de Kristaltempel."}});
   pages.Add(new Page{Type="text",Speaker="",Lines=new[]{"De Blauwe Kaart is weer heel."}});
   pages.Add(new Page{Type="text",Speaker="Oudste Bram",Lines=new[]{"Dankzij jou is Azura weer veilig. De Blauwe Kaart laat weer zien waar het land rustig is."}});
   pages.Add(new Page{Type="text",Speaker="Greta",Lines=new[]{"Ik smeed vanaf nu zwaarden voor op het feest. Nou ja, voor het snijden van de taart."}});
   pages.Add(new Page{Type="text",Speaker="Tobias",Lines=new[]{"Mijn winkel draait beter dan ooit! De eerste helddrank van de week is voor jou. Gratis. Ehm... bijna gratis."}});
   pages.Add(new Page{Type="text",Speaker="Mila",Lines=new[]{"De herberg zit vol. Iedereen wil de held van Dageraadsdorp zien."}});
   pages.Add(new Page{Type="text",Speaker="Pim",Lines=new[]{"Muis en ik gaan ook slijmen verslaan. Als ze groter worden dan Muis, rennen we weg."}});
   pages.Add(new Page{Type="stats"});pages.Add(new Page{Type="credits"});pages.Add(new Page{Type="end"});
   IsOpen=true;PageIndex=0;line=0;typed=0;scroll=0;time=0;
  }
  public void NotifyOpened(InputFrame frame){openingFrame=frame;lastHandled=null;}
  public void Close(){IsOpen=false;}
  string LineText=>Current?.Type=="text"?translate(Current.Lines[line]):"";
  public bool LineComplete=>Current?.Type!="text"||typed>=StoryUi.RuneCount(LineText);
  public void Tick(double delta)
  {
   if(!IsOpen||!(delta>0))return;time+=delta;
   if(Current.Type=="text")typed=Math.Min(StoryUi.RuneCount(LineText),typed+delta*TypeSpeed);
   else if(Current.Type=="credits"){scroll+=delta*CreditsSpeed;if(CreditsDone)NextPage();}
  }
  void NextPage(){if(PageIndex>=pages.Count-1){IsOpen=false;Finished?.Invoke();return;}PageIndex++;line=0;typed=0;scroll=0;time=0;}
  /// <summary>One press: finish the line, go to the next line or page; on the last page it closes the ending.</summary>
  public void Advance()
  {
   if(!IsOpen)return;
   if(Current.Type=="text"){if(!LineComplete){typed=StoryUi.RuneCount(LineText);return;}if(line<Current.Lines.Length-1){line++;typed=0;return;}}
   NextPage();
  }
  public void HandleInput(InputFrame frame)
  {
   if(!IsOpen||frame==null||ReferenceEquals(lastHandled,frame))return;lastHandled=frame;if(ReferenceEquals(openingFrame,frame))return;
   if(frame.Pressed("ui_accept")||frame.Pressed("interact")||frame.Pressed("attack"))Advance();
  }
  public void Draw()
  {
   if(!IsOpen)return;Draws++;var e=Event.current;if(e.type==EventType.MouseUp&&e.button==0){e.Use();Advance();if(!IsOpen)return;}
   var screen=new Rect(0,0,1152,648);StoryUi.Fill(screen,new Color(.03f,.05f,.11f,.97f));var page=Current;bool fits=true;
   GUIStyle Centered(int size,Color color,bool wrap=false){var style=StoryUi.Text(catalog,size,wrap);style.alignment=TextAnchor.MiddleCenter;style.normal.textColor=color;return style;}
   if(page.Type=="text")
   {
    var box=new Rect(126,224,900,200);StoryUi.Panel(box);
    if(page.Speaker!=""){var name=StoryUi.Text(catalog,22);name.normal.textColor=StoryUi.Gold;GUI.Label(new Rect(box.x+24,box.y+14,box.width-48,32),translate(page.Speaker),name);}
    var body=StoryUi.Text(catalog,24,true);var area=new Rect(box.x+24,box.y+(page.Speaker!=""?54:24),box.width-48,box.height-(page.Speaker!=""?78:48));string full=LineText;
    while(body.fontSize>15&&body.CalcHeight(new GUIContent(full),area.width)>area.height)body.fontSize--;fits=body.CalcHeight(new GUIContent(full),area.width)<=area.height+.5f;
    GUI.Label(area,StoryUi.Prefix(full,(int)typed),body);
   }
   else if(page.Type=="stats")
   {
    GUI.Label(new Rect(0,84,1152,70),translate("Jouw avontuur"),Centered(50,new Color(.7f,.92f,1)));var box=new Rect(296,188,560,Stats.Count*46+36);StoryUi.Panel(box);fits=StoryUi.Contains(screen,box)&&box.yMax<=560;
    for(int i=0;i<Stats.Count;i++)
    {
     var left=StoryUi.Text(catalog,22);left.normal.textColor=new Color(.85f,.9f,1);GUI.Label(new Rect(box.x+30,box.y+18+i*46,300,40),Stats[i].label,left);
     var right=StoryUi.Text(catalog,22);right.alignment=TextAnchor.MiddleRight;right.normal.textColor=StoryUi.Gold;GUI.Label(new Rect(box.x+250,box.y+18+i*46,280,40),Stats[i].value,right);
    }
   }
   else if(page.Type=="credits")
   {
    for(int i=0;i<Credits.Length;i++)
    {
     float y=648-(float)scroll+i*CreditsLine;if(y<-70||y>660||Credits[i].text=="")continue;string text=translate(Credits[i].text);
     if(Credits[i].style=="title")GUI.Label(new Rect(0,y-30,1152,72),text,Centered(56,new Color(.7f,.92f,1)));
     else if(Credits[i].style=="heading")GUI.Label(new Rect(0,y,1152,36),text,Centered(26,new Color(1,.88f,.5f)));
     else GUI.Label(new Rect(0,y,1152,34),text,Centered(22,new Color(.9f,.95f,1)));
    }
   }
   else
   {
    GUI.Label(new Rect(0,250,1152,80),translate("Bedankt voor het spelen!"),Centered(54,new Color(.7f,.92f,1)));
    GUI.Label(new Rect(126,340,900,40),translate("Je voortgang is bewaard: je kunt verder in het dorp."),Centered(22,new Color(.85f,.9f,1)));
    GUI.Label(new Rect(126,386,900,60),bilingual("Vanuit \"Opslaan en naar profielen\" in het pauzemenu begin je een Nieuw spel+ met je beste spullen.","From \"Save and return to profiles\" in the pause menu you can start a New Game+ with your best gear."),Centered(18,StoryUi.Quiet,true));
   }
   if(page.Type!="credits"||time>1.5)
   {var hint=Centered(17,new Color(1,1,1,.55f+.35f*Mathf.Sin((float)time*3)));GUI.Label(new Rect(0,592,1152,30),binding("ui_accept")+bilingual(page.Type=="end"?" verder in het dorp":page.Type=="credits"?" overslaan":" verder",page.Type=="end"?" continue in the village":page.Type=="credits"?" skip":" continue"),hint);}
   LayoutFits=fits;
  }
 }
}
