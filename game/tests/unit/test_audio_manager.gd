extends GutTest
## sound-pass audio "Playing a one-shot by id", "Loops are set by level", "Volume level" (design D4):
## the AudioManager service against a fresh instance with a fixture bank and a fake clock. Checks
## read the manager's own reports (signals, levels), never what an audio device did: headless runs
## use the dummy driver.

const MANAGER_SCRIPT: Script = preload("res://scripts/autoload/audio_manager.gd")

var manager: Node
var bank: SoundBank
var now_s: float = 100.0


func before_each() -> void:
	var real := load(SoundBank.STANDARD_PATH) as SoundBank
	bank = SoundBank.new()
	bank.entries = [
		_entry(&"blip", real.entry(&"pickup").stream, false, -10.0, 0.1, 0.08, 1.0),
		_entry(&"bed", real.entry(&"sea").stream, true, -12.0, 0.0, 0.0, 2.0),
	]
	now_s = 100.0
	manager = MANAGER_SCRIPT.new()
	manager.bank = bank
	manager.clock = func() -> float: return now_s
	add_child_autofree(manager)
	watch_signals(manager)


func after_each() -> void:
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_mute(0, false)


func test_empty_and_unknown_ids_are_silent() -> void:
	manager.play_sfx(&"")
	manager.play_sfx(&"no_such_sound")
	manager.play_sfx(&"no_such_sound")
	assert_signal_not_emitted(manager, "sfx_played")
	assert_eq(manager.warned_ids(), [&"no_such_sound"] as Array[StringName], "the unknown id warns once")


func test_a_one_shot_plays_and_is_reported() -> void:
	manager.play_sfx(&"blip")
	assert_signal_emit_count(manager, "sfx_played", 1)
	assert_signal_emitted_with_parameters(manager, "sfx_played", [&"blip"])
	var voice: AudioStreamPlayer = manager.last_voice()
	assert_eq(voice.stream, bank.entry(&"blip").stream)
	assert_eq(voice.bus, AudioBuses.SFX)
	assert_almost_eq(voice.volume_db, -10.0, 0.001)


func test_requests_inside_the_repeat_interval_play_once() -> void:
	manager.play_sfx(&"blip")
	manager.play_sfx(&"blip")
	now_s += 0.05
	manager.play_sfx(&"blip")
	assert_signal_emit_count(manager, "sfx_played", 1, "three requests inside 0.08 s")
	now_s += 0.1
	manager.play_sfx(&"blip")
	assert_signal_emit_count(manager, "sfx_played", 2, "once the interval has passed")


func test_pitch_stays_within_the_spread() -> void:
	var lowest: float = 9.0
	var highest: float = 0.0
	for i: int in 200:
		now_s += 1.0
		manager.play_sfx(&"blip")
		var pitch: float = manager.last_voice().pitch_scale
		lowest = minf(lowest, pitch)
		highest = maxf(highest, pitch)
	assert_true(lowest >= 0.9 - 0.0001 and highest <= 1.1 + 0.0001, "%s..%s within 1 ± 0.1" % [lowest, highest])
	assert_lt(lowest, 0.97, "the pitch moves")
	assert_gt(highest, 1.03)


func test_a_db_offset_lowers_the_voice() -> void:
	manager.play_sfx(&"blip", -12.0)
	assert_almost_eq(manager.last_voice().volume_db, -22.0, 0.001)


func test_voices_are_a_pool_of_eight() -> void:
	for i: int in 12:
		now_s += 1.0
		manager.play_sfx(&"blip")
	assert_eq(manager.voice_count(), AudioBuses.VOICES)


func test_a_loop_id_is_not_a_one_shot() -> void:
	manager.play_sfx(&"bed")
	assert_signal_not_emitted(manager, "sfx_played")


func test_a_loop_fades_up_holds_and_stops() -> void:
	manager.set_loop_level(&"bed", 1.0)
	assert_signal_emitted_with_parameters(manager, "loop_level_set", [&"bed", 1.0])
	assert_true(manager.loop_playing(&"bed"))
	assert_eq(manager.loop_level(&"bed"), 0.0, "it starts silent")
	manager.step_loops(1.0)
	assert_almost_eq(manager.loop_level(&"bed"), 0.5, 0.001, "half way after half its 2 s fade")
	manager.step_loops(5.0)
	assert_eq(manager.loop_level(&"bed"), 1.0)
	var player: AudioStreamPlayer = manager.loop_player(&"bed")
	assert_almost_eq(player.volume_db, -12.0, 0.001, "at full: its bank level")
	assert_eq(player.bus, AudioBuses.AMBIENCE)
	manager.set_loop_level(&"bed", 0.0)
	manager.step_loops(1.0)
	assert_true(manager.loop_playing(&"bed"), "still fading out")
	manager.step_loops(1.5)
	assert_false(manager.loop_playing(&"bed"), "stopped at silence")
	assert_eq(manager.loop_level(&"bed"), 0.0)


func test_setting_the_same_level_again_reports_once() -> void:
	manager.set_loop_level(&"bed", 0.5)
	manager.set_loop_level(&"bed", 0.5)
	assert_signal_emit_count(manager, "loop_level_set", 1)


func test_silence_for_a_loop_that_is_not_playing_starts_nothing() -> void:
	manager.set_loop_level(&"bed", 0.0)
	assert_false(manager.loop_playing(&"bed"))


func test_a_one_shot_id_is_not_a_loop() -> void:
	manager.set_loop_level(&"blip", 1.0)
	assert_false(manager.loop_playing(&"blip"))


func test_stop_loops_stops_every_loop_at_once() -> void:
	manager.set_loop_level(&"bed", 1.0)
	manager.step_loops(3.0)
	manager.stop_loops()
	assert_false(manager.loop_playing(&"bed"))
	assert_eq(manager.loop_target(&"bed"), 0.0)
	assert_eq(manager.playing_loops(), [] as Array[StringName])


func test_volume_sets_the_master_bus() -> void:
	manager.set_volume(0.3)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.3), 0.001)
	assert_almost_eq(manager.volume(), 0.3, 0.0001)
	assert_false(AudioServer.is_bus_mute(0))
	manager.set_volume(0.0)
	assert_true(AudioServer.is_bus_mute(0), "0 silences the game")
	manager.set_volume(1.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), 0.0, 0.001)
	assert_false(AudioServer.is_bus_mute(0))


func test_the_two_buses_exist_once() -> void:
	AudioBuses.ensure()
	AudioBuses.ensure()
	var names: Array[String] = []
	for i: int in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	assert_eq(names.count(String(AudioBuses.SFX)), 1)
	assert_eq(names.count(String(AudioBuses.AMBIENCE)), 1)
	var sfx: int = AudioServer.get_bus_index(AudioBuses.SFX)
	assert_eq(AudioServer.get_bus_send(sfx), &"Master")


func test_freeing_the_manager_leaves_no_player_behind() -> void:
	manager.set_loop_level(&"bed", 1.0)
	manager.play_sfx(&"blip")
	var player: AudioStreamPlayer = manager.loop_player(&"bed")
	manager.free()
	assert_false(is_instance_valid(player))


func _entry(id: StringName, stream: AudioStream, loop: bool, volume_db: float, spread: float, interval: float, fade: float) -> SoundData:
	var sound := SoundData.new()
	sound.id = id
	sound.stream = stream
	sound.loop = loop
	sound.bus = SoundData.Bus.AMBIENCE if loop else SoundData.Bus.SFX
	sound.volume_db = volume_db
	sound.pitch_spread = spread
	sound.min_interval_s = interval
	sound.fade_s = fade
	return sound
