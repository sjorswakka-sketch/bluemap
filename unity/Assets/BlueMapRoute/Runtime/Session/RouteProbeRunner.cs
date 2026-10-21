using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlueMapMigration.Foundation;
using BlueMapMigration.Persistence;
using BlueMapMigration.Player;
using BlueMapMigration.Probe;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace BlueMapMigration.Route
{
    public static class RouteProbeRunner
    {
        [Serializable] public sealed class Result
        {
            public int schemaVersion=1;
            public bool success,gameSaveAccessed=false;
            public BuildIdentity identity;
            public Phase2Probe.Check[] checks;
        }
        public static PersistenceCoordinator Fixture {get;private set;}
        private static int nativePortalEntries;
        public static Result Run(BuildIdentity identity,string output,PlayerWorld world,RouteWorldController route)
        {
            var checks=new List<Phase2Probe.Check>();
            void Check(string name,bool passed)
            {
                if(checks.Any(row=>row.name==name))throw new InvalidOperationException("Duplicate route proof: "+name);
                checks.Add(new Phase2Probe.Check{name=name,passed=passed});
                if(!passed)Debug.LogError("Route check failed: "+name);
            }
            var repository=FoundationWorldRepository.LoadRequired();
            string area=PersistencePaths.Checked(Path.Combine(output,"rf"));
            if(Directory.Exists(area))throw new IOException("Route fixture directory must be fresh.");
            Directory.CreateDirectory(area);
            void Group(string name,Action operation)
            {try{operation();}catch(Exception error){Debug.LogWarning("Route "+name+": "+error);Check("route_"+name+"_exception_free",false);}}
            Group("model",()=>RouteGameplayChecks.Verify(repository,Check));
            Group("presentation",()=>{RoutePresentationChecks.Verify(route.Catalog,repository,Check);RoutePresentationChecks.VerifyGpu(route.Catalog,Check);});
            Group("profiles",()=>VerifyProfiles(repository,Path.Combine(area,"p"),Check));
            Group("world",()=>VerifyWorld(repository,Path.Combine(area,"w"),world,route,Check));
            Check("route_no_real_saves_accessed",PersistencePaths.Within(PersistencePaths.Checked(output),area)&&!PersistencePaths.Within(PersistencePaths.LegacyDefault,area)&&!PersistencePaths.Within(PersistencePaths.UnityDefault,area));
            string[] required={"route_model_checks_ran","route_source_oracle_complete","route_world_checks_ran","route_village_home_forest_transitions","route_transition_state_preserved","route_inventory_ui_verified","route_dialogue_ui_verified","route_persistence_roundtrip","route_profiles_are_safe_copies","route_save_failure_preserves_progress","route_controller_navigation_verified"};
            return new Result{identity=identity,checks=checks.ToArray(),success=checks.Count>=53&&checks.All(row=>row.passed)&&required.All(name=>checks.Any(row=>row.name==name&&row.passed))};
        }
        private static void VerifyProfiles(FoundationWorldRepository repository,string area,Action<string,bool> check)
        {
            Directory.CreateDirectory(area);string target=Path.Combine(area,"u"),source=Path.Combine(area,"g");Directory.CreateDirectory(source);
            using(var input=new PlayerInputSource())using(var coordinator=new PersistenceCoordinator(repository,input,target))
            {
                var fresh=RouteGameplay.NewGame(repository);fresh.State.Set("future_route",FoundationJson.ParsePlain("{\"kind\":\"future_crop\",\"amount\":9007199254740993}"));
                bool started=coordinator.CreateRouteCopy(fresh.State.Snapshot(),false);
                if(!started)throw new IOException("Cannot create synthetic new route: "+coordinator.Status);
                var first=coordinator.Current;var store=new PersistenceStore(target);
                check("route_new_profile_origin_without_fabricated_godot_files",coordinator.IsRouteProfile&&first.Snapshot.Origin=="unity"&&first.Snapshot.CopyOriginals().Count==0&&first.Snapshot.State.Require("flags").Require("op_new_adventure").AsBool());
                fresh.State.Coins=17;fresh.State.PlayTime=10.125;
                bool saved=coordinator.SaveAdventure(fresh.State.Snapshot());var second=coordinator.Current;
                var loaded=store.Load(first.ProfileId);
                check("route_new_profile_all_fields_roundtrip",saved&&second.RevisionId!=first.RevisionId&&FoundationJson.StringifyPlain(loaded.Snapshot.State)==FoundationJson.StringifyPlain(fresh.State.Snapshot())&&loaded.Snapshot.State.Require("future_route").Require("amount").AsInt64()==9007199254740993L);
                int refused=0;
                foreach(PersistenceWriteStage stage in Enum.GetValues(typeof(PersistenceWriteStage)))
                {
                    fresh.State.Coins=80+(int)stage;
                    bool result=coordinator.SaveAdventure(fresh.State.Snapshot(),at=>{if(at==stage)throw new IOException("Injected route save failure");});
                    var previous=store.Load(first.ProfileId);
                    if(!result&&coordinator.Current.RevisionId==second.RevisionId&&previous.RevisionId==second.RevisionId&&previous.Snapshot.State.Require("coins").AsInt64()==17)refused++;
                }
                using(var staleInput=new PlayerInputSource())using(var stale=new PersistenceCoordinator(repository,staleInput,target))
                {
                    stale.OpenProfile(first.ProfileId);fresh.State.Coins=27;
                    bool latest=coordinator.SaveAdventure(fresh.State.Snapshot());string revision=coordinator.Current.RevisionId;
                    bool staleRefused=!stale.SaveAdventure(fresh.State.Snapshot());
                    check("route_save_failure_preserves_progress",refused==4&&latest&&staleRefused&&store.Load(first.ProfileId).RevisionId==revision&&store.Load(first.ProfileId).Snapshot.State.Require("coins").AsInt64()==27);
                }
                byte[] original=PersistencePaths.Utf8.GetBytes("{\"map\":\"forest\",\"pos\":[112,576],\"coins\":29,\"inventory\":{\"future_seed\":8},\"future_archive\":{\"kind\":\"preserved\",\"message\":\"🌱\"}}");
                File.WriteAllBytes(Path.Combine(source,"savegame.json"),original);
                File.WriteAllBytes(Path.Combine(source,"settings.cfg"),PersistencePaths.Utf8.GetBytes("; original comment\n[taal]\nlocale=\"en\"\n"));
                var before=LegacySourceSet.Read(source);foreach(string name in before.FileNames)File.SetAttributes(Path.Combine(source,name),FileAttributes.ReadOnly);
                bool imported=coordinator.ImportSource(source);if(!imported)throw new IOException("Cannot import synthetic route profile: "+coordinator.Status);
                var parent=coordinator.Current;string parentPointer=Path.Combine(target,parent.ProfileId,"current.json");string originalPointer=PersistencePaths.Hash(File.ReadAllBytes(parentPointer));
                string parentState=FoundationJson.StringifyPlain(parent.Snapshot.State);var copied=new FoundationGameState(parent.Snapshot.State);
                bool forked=coordinator.CreateRouteCopy(copied.Snapshot(),true);var fork=coordinator.Current;
                copied.Coins=31;bool forkSaved=coordinator.SaveAdventure(copied.Snapshot());before.VerifyUnchanged();
                bool originals=before.CopyFiles().All(pair=>fork.Snapshot.CopyOriginals().TryGetValue(pair.Key,out var bytes)&&bytes.SequenceEqual(pair.Value));
                check("route_profiles_are_safe_copies",forked&&forkSaved&&fork.ProfileId!=parent.ProfileId&&fork.Snapshot.Origin=="godot"&&originals&&PersistencePaths.Hash(File.ReadAllBytes(parentPointer))==originalPointer&&store.Load(parent.ProfileId).RevisionId==parent.RevisionId&&FoundationJson.StringifyPlain(store.Load(parent.ProfileId).Snapshot.State)==parentState&&File.ReadAllBytes(Path.Combine(source,"savegame.json")).SequenceEqual(original));
                check("route_imported_profile_provenance_retained",coordinator.Current.Snapshot.Preferences.Require("routeBranch").Require("parentProfile").AsString()==parent.ProfileId&&coordinator.Current.Snapshot.Preferences.Require("routeBranch").Require("parentRevision").AsString()==parent.RevisionId&&coordinator.Current.Snapshot.State.Require("future_archive").Require("kind").AsString()=="preserved");
            }
        }
        private static void VerifyWorld(FoundationWorldRepository repository,string area,PlayerWorld world,RouteWorldController route,Action<string,bool> check)
        {
            Fixture?.Dispose();Fixture=new PersistenceCoordinator(repository,world.InputSource,area);
            route.BeginNew(Fixture);
            if(route.Gameplay==null||route.Session==null)throw new InvalidOperationException("Native route did not start.");
            nativePortalEntries=0;var state=route.Gameplay.State;state.Set("future_live_route",FoundationJson.ParsePlain("{\"kind\":\"unmodified\",\"value\":9007199254740993}"));
            string unknown=FoundationJson.StringifyPlain(state.Get("future_live_route"));
            var oldMode=InputSystem.settings.updateMode;bool oldCursor=Cursor.visible;
            var devices=new List<InputDevice>();PlayerInputSource input=null;
            try
            {
                InputSystem.settings.updateMode=InputSettings.UpdateMode.ProcessEventsManually;
                var keyboard=InputSystem.AddDevice<Keyboard>("Phase10RouteKeyboard");devices.Add(keyboard);
                var gamepad=InputSystem.AddDevice<Gamepad>("Phase10RouteGamepad");devices.Add(gamepad);
                input=new PlayerInputSource(devices);input.SetContext(true,false);
                InputFrame Pad(GamepadState value)
                {InputSystem.QueueStateEvent(gamepad,value);InputSystem.Update();var result=input.Read();if(value.buttons!=0)Debug.Log("Route proof input: buttons="+value.buttons+" enabled="+gamepad.enabled+" active="+result.ControllerActive+" accept="+result.Pressed("ui_accept")+" interact="+result.Pressed("interact")+" down="+result.Pressed("ui_down")+" controls="+world.ControlsOpen);return result;}
                InputFrame Neutral()
                {InputSystem.QueueStateEvent(keyboard,new KeyboardState());return Pad(new GamepadState());}
                void Press(GamepadButton button)
                {Neutral();route.HandleFrame(Pad(new GamepadState().WithButton(button)));route.HandleFrame(Neutral());}
                void ReadDialogue()
                {for(int guard=0;guard<32&&route.Gameplay.DialogueOpen&&!route.Gameplay.Dialogue.ChoicesReady;guard++)Press(GamepadButton.South);}
                string Pim()=>FindNode(world.Snapshot,"/npc.gd","npc_id","pim");
                string pim=Pim();NearNode(world,pim);bool openedPim=route.InteractTarget(pim);Debug.Log("Route proof Pim: opened="+openedPim+" id="+(route.Gameplay.Dialogue?.Id??"closed")+" line="+route.DialogueLineIndex+" owners="+String.Join(",",state.UiOwners)+" targets="+route.Targets.Count+" map="+state.MapId+" position="+world.Position);
                bool dialogue=route.Gameplay.DialogueOpen&&route.Gameplay.Dialogue.Id=="pim_intro"&&route.DialogueLineIndex==0&&state.QuestState("kat")=="none"&&state.Paused;
                ReadDialogue();bool choices=route.Gameplay.Dialogue!=null&&route.Gameplay.Dialogue.ChoicesReady;Debug.Log("Route proof read Pim: id="+(route.Gameplay.Dialogue?.Id??"closed")+" line="+route.DialogueLineIndex+" choices="+choices+" selection="+route.Selection+" quest="+state.QuestState("kat"));
                Press(GamepadButton.South);ReadDialogue();Debug.Log("Route proof chose Pim: id="+(route.Gameplay.Dialogue?.Id??"closed")+" line="+route.DialogueLineIndex+" owners="+String.Join(",",state.UiOwners)+" quest="+state.QuestState("kat"));
                check("route_dialogue_ui_verified",dialogue&&choices&&state.QuestState("kat")=="active"&&!route.Gameplay.DialogueOpen&&!state.Paused);
                state.Coins=73;long coins=state.Coins;var inventory=state.Get("inventory");
                bool home=Travel(route,"player_home"),village=Travel(route,"village"),edge=Travel(route,"forest_edge"),forest=Travel(route,"forest");
                check("route_village_home_forest_transitions",home&&village&&edge&&forest&&world.Snapshot.MapId=="forest"&&world.RoutePresentation!=null&&route.Session.State.MapId==world.Snapshot.MapId);
                check("route_transition_state_preserved",ReferenceEquals(route.Session.State,state)&&state.Coins>=coins&&inventory.Entries.All(pair=>state.Count(pair.Key.AsString())>=pair.Value.AsInt64())&&state.QuestState("kat")=="active"&&FoundationJson.StringifyPlain(state.Get("future_live_route"))==unknown);
                var resource=route.Targets.First(target=>target.Kind=="resource_node"&&target.Id=="branches");
                NearNode(world,resource.Address);long previousBranches=state.Count("prof_branch");bool began=route.StartResource(resource.Address);
                world.Teleport(world.Position+new Vector2(6,0));world.Step(0,new MotionInput{Direction=Vector2.zero});route.Tick(.05);
                bool cancelled=began&&!route.Working&&state.Count("prof_branch")==previousBranches&&route.Gameplay.ResourceRemaining(resource.UniqueKey)==0;
                NearNode(world,resource.Address);bool restarted=route.StartResource(resource.Address);route.Tick(route.Gameplay.ResourceDuration(resource.Id)+.01);
                bool gathered=restarted&&!route.Working&&state.Count("prof_branch")==previousBranches+route.Gameplay.ResourceAmount(resource.Id)&&route.Gameplay.ResourceRemaining(resource.UniqueKey)>0&&!route.StartResource(resource.Address);
                check("route_live_harvest_interrupt_and_final_recheck",cancelled&&gathered);
                string cat=FindNode(world.Snapshot,"/npc.gd","npc_id","muis_bos");NearNode(world,cat);route.InteractTarget(cat);route.Tick(1);route.Tick(1.1);route.InteractTarget(cat);ReadDialogue();
                bool found=state.Flag("cat_found")&&state.QuestStep("kat")==1;
                bool returned=Travel(route,"forest_edge")&&Travel(route,"village");pim=Pim();NearNode(world,pim);route.InteractTarget(pim);ReadDialogue();
                check("route_live_cat_quest_full_return",found&&returned&&state.QuestState("kat")=="done"&&state.Flag("cat_home")&&state.Count("heart_container")==1&&state.Get("hero_xp").AsInt64()==40);
                check("route_portals_arm_and_enter_native",nativePortalEntries>=6);
                string retainedMap=state.MapId;bool contained=true;float mapWidth=world.Snapshot.Width*32,mapHeight=world.Snapshot.Height*32;
                foreach(var outsideEdge in new[]{new Vector2(Mathf.Min(640,mapWidth*.5f),mapHeight+4),new Vector2(-4,mapHeight*.5f),new Vector2(mapWidth+4,mapHeight*.5f),new Vector2(mapWidth*.5f,-4)})
                {
                    world.Teleport(outsideEdge);world.Step(0,new MotionInput{Direction=Vector2.zero});route.Tick(.02);
                    Vector2 bounded=world.Position;
                    contained&=state.MapId==retainedMap&&world.Snapshot.MapId==retainedMap&&bounded.x>=8&&bounded.x<=mapWidth-8&&bounded.y>=0&&bounded.y<=mapHeight-16;
                    contained&=Math.Abs(state.Position.Items[0].AsDouble()-bounded.x)<.001&&Math.Abs(state.Position.Items[1].AsDouble()-bounded.y)<.001;
                }
                check("route_unconnected_exit_keeps_player_inside_map",contained&&nativePortalEntries>=6);
                NearNode(world,pim);

                state.Set("inventory",FoundationJson.ParsePlain("{\"potion\":2,\"prof_branch\":4,\"prof_stone\":2,\"prof_herb\":2,\"prof_berry\":3,\"prof_mushroom\":2,\"hs_grape\":3,\"hs_seed\":1,\"hs_flower_seed\":1,\"trail_flower\":2,\"hs_honey\":1,\"prof_log\":2,\"gel\":2,\"heart_container\":1,\"future_seed\":3}"));
                var largeBag=state.Get("inventory").Entries.ToDictionary(p=>p.Key.AsString(),p=>p.Value,StringComparer.Ordinal);
                foreach(var item in route.Inventory.Items.Entries.Take(64))if(!largeBag.ContainsKey(item.Key.AsString()))largeBag[item.Key.AsString()]=FoundationValue.Integer(1);
                state.Set("inventory",FoundationValue.Object(largeBag));
                route.OpenInventory();double before=state.PlayTime;route.Session.Clock.Tick(1);route.Tick(1);
                check("route_inventory_ui_verified",route.Modal=="inventory"&&state.Paused&&state.PlayTime==before&&state.Count("potion")==2&&state.Count("future_seed")==3);
                int selected=route.InventoryIndex;Neutral();route.HandleFrame(Pad(new GamepadState().WithButton(GamepadButton.DpadDown)));route.HandleFrame(Neutral());bool navigated=route.InventoryIndex!=selected;
                for(int index=0;index<2;index++)Press(GamepadButton.DpadDown);
                int beforeStick=route.InventoryIndex;route.HandleFrame(Pad(new GamepadState{rightStick=new Vector2(0,-.9f)}));route.Tick(.11);route.HandleFrame(Neutral());
                bool scrolled=route.InventoryIndex>beforeStick&&route.InventoryPanel.Page>0&&route.InventoryPanel.SelectionVisible;
                check("route_inventory_controller_focus_and_right_stick_scroll",scrolled&&route.InventoryItems().Length>8);
                // A held stick produces many frames between focus steps. Its scroll must
                // never run ahead of the selected row while the repeat timer is waiting.
                route.OpenInventory();route.Tick(.12);Neutral();int heldStart=route.InventoryIndex,heldPrevious=heldStart;int heldPage=route.InventoryPanel.Page;bool heldVisible=true,heldMonotonic=true;
                for(int frameIndex=0;frameIndex<90;frameIndex++)
                {
                    route.HandleFrame(Pad(new GamepadState{rightStick=new Vector2(0,-.7f)}));route.Tick(1.0/60);
                    heldVisible&=route.InventoryPanel.SelectionVisible;
                    heldMonotonic&=route.InventoryIndex>=heldPrevious&&route.InventoryPanel.Page>=heldPage;
                    heldPrevious=route.InventoryIndex;heldPage=route.InventoryPanel.Page;
                }
                route.HandleFrame(Neutral());
                check("route_inventory_sustained_right_stick_keeps_focus",heldVisible&&heldMonotonic&&route.InventoryIndex>heldStart+8&&route.InventoryPanel.Page>0&&route.Modal=="inventory"&&state.Paused);
                Press(GamepadButton.East);bool closed=route.Modal==""&&!state.Paused;
                route.OpenPause();Press(GamepadButton.DpadDown);bool pauseNavigation=route.Modal=="pause"&&route.Selection>0;Press(GamepadButton.East);
                check("route_controller_navigation_verified",navigated&&scrolled&&closed&&pauseNavigation&&route.Modal==""&&!state.Paused&&devices.All(device=>device.added&&!device.native)&&typeof(InputSystem).Assembly.GetName().Name=="Unity.InputSystem");
                state.Coins=71;route.Save();var saved=Fixture.Current;state.Coins=1;route.Reload(false);
                check("route_persistence_roundtrip",Fixture.Current.Snapshot.State.Require("coins").AsInt64()==71&&saved.Snapshot.State.Require("coins").AsInt64()==71&&route.Gameplay.State.Coins==71&&route.Gameplay.State.Flag("cat_home")&&route.Gameplay.State.QuestState("kat")=="done"&&route.Gameplay.State.Get("future_live_route").Require("value").AsInt64()==9007199254740993L&&world.Snapshot.MapId==route.Gameplay.State.MapId&&Math.Abs(world.Position.x-(float)route.Gameplay.State.Position.Items[0].AsDouble())<.001);
                check("route_world_checks_ran",world.RouteMode&&world.RoutePresentation!=null&&world.Snapshot.MapId=="village"&&route.Gameplay.State.InGame);
            }
            finally
            {input?.Dispose();foreach(var device in devices)if(device.added)InputSystem.RemoveDevice(device);InputSystem.settings.updateMode=oldMode;Cursor.visible=oldCursor;route.CloseModal();}
        }
        private static bool Travel(RouteWorldController route,string target)
        {
            var portal=route.World.Snapshot.Root.Require("scene").Items.FirstOrDefault(node=>node.Require("script").AsString().EndsWith("/portal.gd",StringComparison.Ordinal)&&node.Require("fields").TryGet("target_map",out var map)&&map.AsString()==target);
            if(portal==null){Debug.Log("Route proof portal missing: "+route.Gameplay.State.MapId+" to "+target);return false;}
            var rect=portal.Require("fields").Require("rect");Vector2 origin=FoundationCoordinates.Vector(rect.Require("position")),size=FoundationCoordinates.Vector(rect.Require("size"));
            Vector2 outside=origin+new Vector2(size.x*.5f,size.y+4),inside=origin+new Vector2(size.x*.5f,size.y-4);
            string previous=route.World.Snapshot.MapId;
            route.World.Teleport(outside);route.World.Step(0,new MotionInput{Direction=Vector2.zero});route.Tick(.02);
            if(route.World.Snapshot.MapId!=previous){Debug.Log("Route proof outside portal changed map: "+previous+" to "+route.World.Snapshot.MapId);return false;}
            route.World.Teleport(inside);route.World.Step(0,new MotionInput{Direction=Vector2.zero});route.Tick(.02);
            bool entered=route.World.Snapshot.MapId==target&&route.Gameplay.State.MapId==target;
            Debug.Log("Route proof portal: "+previous+" to "+target+" entered="+entered+" current="+route.World.Snapshot.MapId+" locked="+route.Gameplay.State.InputLocked+" owners="+String.Join(",",route.Gameplay.State.UiOwners));if(entered)nativePortalEntries++;return entered;
        }
        private static string FindNode(FoundationWorldSnapshot snapshot,string suffix,string field,string id)
        {
            var node=snapshot.Root.Require("scene").Items.First(value=>value.Require("script").AsString().EndsWith(suffix,StringComparison.Ordinal)&&value.Require("fields").TryGet(field,out var found)&&found.AsString()==id);
            return RouteSourcePresentation.Address(node);
        }
        private static void NearNode(PlayerWorld world,string address)
        {
            var node=world.Snapshot.Root.Require("scene").Items.First(value=>RouteSourcePresentation.Address(value)==address);
            Vector2 at=FoundationCoordinates.Vector(node.Require("globalTransform").Require("origin"));world.Teleport(at+new Vector2(0,28));world.Step(1.0/60,new MotionInput{Direction=Vector2.zero});
        }
    }
}
