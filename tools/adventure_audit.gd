extends SceneTree
## Reproducible measurements, never a speed assertion. Use audit_adventure.py.
const Maps:=preload("res://scripts/maps/registry.gd")
var gs: Node
var world: Node2D
var report: Dictionary={}
func _initialize():run.call_deferred()
func frames(n:=4):
 for i in n:await process_frame
func memory() -> Dictionary:
 return {"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
func summary(values: Array) -> Dictionary:
 values.sort()
 return {"median_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(values.size()*.95))],"max_ms":values.back()}
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 gs=root.get_node("GameState")
 report={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"audio":AudioServer.get_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1152,648],"startup_ticks_ms":Time.get_ticks_msec(),"startup_memory":memory(),"tracks":{},"maps":[],"scenarios":[],"cycles":[]}
 root.size=Vector2i(1152,648)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var sound:=root.get_node("Sound")
 for key: String in sound.tracks:
  var wav: AudioStreamWAV=sound.tracks[key]
  report.tracks[key]={"seconds":wav.get_length(),"loop_seconds":wav.loop_end/float(wav.mix_rate),"encoded_bytes":wav.data.size(),"format":wav.format}
 print("AUDIT_STARTUP_READY")
 var start:=Time.get_ticks_usec()
 var title: Control=load("res://scenes/title.tscn").instantiate();root.add_child(title);await frames(10)
 report["title_ms"]=(Time.get_ticks_usec()-start)/1000.0
 title.free();await frames(3)
 gs.new_game();gs.in_game=true
 start=Time.get_ticks_usec();world=load("res://scenes/main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(5)
 report["first_world_ms"]=(Time.get_ticks_usec()-start)/1000.0
 for id: String in Maps.MAPS:
  start=Time.get_ticks_usec();world.load_map(id,"start")
  var sync_ms: float=(Time.get_ticks_usec()-start)/1000.0
  await frames(5)
  report.maps.append({"id":id,"sync_ms":sync_ms,"settled_ms":(Time.get_ticks_usec()-start)/1000.0,"memory":memory()})
 for spec in [["village",.5,0],["village",.9,3],["forest",.5,2],["kruipmoeras",.7,0],["harbor",.5,0],["harbor",.9,3],["headland",.9,0],["tidal_hollow",.5,0],["coast_workshop",.5,0]]:
  gs.day_time=spec[1];gs.day_count=spec[2];world.load_map(spec[0],"start");world.fader.set_alpha(0)
  world.player.invuln=1000;gs.hp=gs.max_hp();await frames(35)
  var wall: Array=[];var process: Array=[];var physics: Array=[]
  var previous:=Time.get_ticks_usec()
  for i in 180:
   await process_frame
   var now:=Time.get_ticks_usec();wall.append((now-previous)/1000.0);previous=now
   process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
  report.scenarios.append({"map":spec[0],"time":spec[1],"day":spec[2],"wall":summary(wall),"process":summary(process),"physics":summary(physics),"memory":memory()})
 for cycle in 4:
  for id: String in ["village","lake","coast","gull_island","tide_cove","river_mouth","tidal_hollow","harbor","coast_workshop","headland","smithy","library","inn"]:
   world.load_map(id,"start");await frames(5)
  world.load_map("village","start");await frames(10)
  report.cycles.append(memory())
 world.queue_free();world=null;await frames(10)
 report["after_world_free"]=memory()
 var f:=FileAccess.open("res://adventure_audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("ADVENTURE AUDIT OK");quit()
