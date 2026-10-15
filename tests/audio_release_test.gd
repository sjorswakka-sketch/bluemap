extends SceneTree
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
 print("  ok   " if ok else "  FAIL ",message)
 if not ok:failures+=1
func run():
 if not OS.get_user_data_dir().get_file().begins_with("Bluemap-Codex-Tests-"):quit(1);return
 var sound:=root.get_node("Sound")
 for id: String in sound.TRACKS:
  var track: AudioStreamWAV=sound.tracks[id]
  var length:=track.get_length()
  check(track.loop_mode==AudioStreamWAV.LOOP_FORWARD and absf(track.loop_end/float(track.mix_rate)-length)<1.0/track.mix_rate,"whole imported music loops: "+id+" length="+str(length))
  sound.play_music(id)
  check(sound.current_track==id and sound._music.stream==track and sound._music.playing,"actual player selects "+id)
  sound._music.seek(maxf(0,length-.1))
  var until:=Time.get_ticks_msec()+300
  while Time.get_ticks_msec()<until:await process_frame
  check(sound._music.playing and sound._music.get_playback_position()<1,"playback really passes full end and loops "+id)
 sound.play_music("unknown")
 check(sound.current_track=="forest","unknown track retains safe forest fallback")
 var stream: AudioStream=sound._music.stream
 sound.play_music("forest")
 check(sound._music.stream==stream,"same track retains the playing stream")
 sound.stop_music();await process_frame
 check(not sound._music.playing and sound.current_track=="","explicit stop clears playback")
 print("AUDIO RELEASE OK" if failures==0 else "AUDIO RELEASE FAILED "+str(failures));quit(0 if failures==0 else 1)
