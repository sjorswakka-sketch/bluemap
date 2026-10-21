using System;
using System.Collections.Generic;
using System.Linq;
using BlueMapMigration.Combat;
using BlueMapMigration.Foundation;
using UnityEngine;
namespace BlueMapMigration.Route
{
    public sealed partial class RouteWorldController
    {
        private readonly HashSet<string> practiceRead=new HashSet<string>(StringComparer.Ordinal);
        private readonly List<EncounterActor> practiceFoes=new List<EncounterActor>();
        private int practiceLesson;private double practiceCountdown;
        public bool PracticeRunning {get;private set;}
        static readonly string[][] PracticeLessons={new[]{"cv_ram"},new[]{"cv_slinger"},new[]{"cv_ram","cv_slinger","lw_warden"}};
        static readonly Vector2[] PracticeSpawns={new Vector2(8.5f,7.5f)*32,new Vector2(17.5f,7.5f)*32,new Vector2(14.5f,5.5f)*32};
        private bool InteractCombatPost(RouteTarget target)
        {
            if(!CombatSimulationEnabled)return false;var obj=target.Fields.Require("obj");string kind=obj.Require("kind").AsString();if(kind=="rack")return false;
            if(kind!="entrance"&&PracticeRunning){StopPractice();ShowMessage(Translate("Oefening gestopt. Je kunt meteen opnieuw beginnen."));return true;}
            if(kind=="entrance"||!practiceRead.Contains(target.Address))
            {
                practiceRead.Add(target.Address);string[] lines=kind=="entrance"?new[]{Translate("Het verlichte pad naast dit vaandel leidt naar het oefenerf. Probeer technieken en leer aanvalssignalen lezen. De uitgang blijft open.")}:new[]{
                    T("Houd "+BindingLabel("technique")+" vast + "+BindingLabel("attack")+" voor een zwaardtechniek, of "+BindingLabel("bow")+" voor een precisieschot.","Hold "+BindingLabel("technique")+" + "+BindingLabel("attack")+" for a sword technique, or "+BindingLabel("bow")+" for a precise shot."),
                    Translate("Hout: snelle steek, 16 stamina. IJzer: brede breekslag, 28. Kristal: verre smalle steek, 24. Alle technieken openen een schild. Precisieschot: 20 stamina, 1 pijl, langere voorbereiding en groter bereik."),
                    Translate("Tijdens voorbereiding loop je langzaam. Rollen, een treffer of een menu onderbreekt de techniek; bestede stamina komt vanzelf terug. De pijl wordt pas bij het schot verbruikt."),
                    Translate("Gebruik dit vaandel opnieuw: eerst de keiram, dan de doornschutter, daarna samen met een schildwachter. Aanvallen doen echte schade. Gebruik het vaandel om te stoppen. Geen buit of XP; de uitgang blijft vrij.")};Combat.Cancel();work=null;bool shown=Gameplay.ShowSourceLines("combat-practice:"+target.Address,Translate("Oefenerf"),lines);SyncDialogue();return shown;
            }
            PracticeRunning=true;practiceCountdown=2.5;ShowMessage(T("Oefening ","Practice ")+(practiceLesson+1)+" / 3: "+T("houd de oranje banen in de gaten.","watch the orange lanes."));return true;
        }
        public void StopPractice()
        {foreach(var e in practiceFoes){e.Dead=true;e.Finished=true;}practiceFoes.Clear();if(Encounter!=null)foreach(var p in Encounter.Projectiles)if(!p.PlayerOwned)p.Dead=true;PracticeRunning=false;practiceCountdown=0;}
        private void TickPractice(double delta)
        {
            if(!PracticeRunning||Gameplay.State.InputLocked)return;
            if(practiceCountdown>0){practiceCountdown-=delta;if(practiceCountdown>0)return;for(int i=0;i<PracticeLessons[practiceLesson].Length;i++)if(Vector2.Distance(World.Position,PracticeSpawns[i])<65){practiceCountdown=.2;return;}
                for(int i=0;i<PracticeLessons[practiceLesson].Length;i++){var enemy=Encounter.Spawn(PracticeLessons[practiceLesson][i],PracticeSpawns[i]);enemy.Practice=true;enemy.StateTime=0;practiceFoes.Add(enemy);}return;}
            practiceFoes.RemoveAll(e=>e.Dead||e.Finished);if(practiceFoes.Count>0)return;PracticeRunning=false;practiceLesson=(practiceLesson+1)%3;ShowMessage(Translate("Goed geoefend. Bij het vaandel kun je de volgende oefening starten."));OnSound("quest");
        }
    }
}
