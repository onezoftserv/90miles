extends Node
## AudioManager autoload (core-services spec; sound-pass design D4): plays the game's sounds by id.
## Thin on purpose: the sounds and their levels are content (SoundBank, res://resources/sound_bank.tres)
## and every rule about when to play is in RunSounds and the HUD's cues. It holds a pool of voices for
## one-shots, one player per loop that fades to the level asked for, and the volume setting on the
## Master bus. It reports every sound it plays (sfx_played, loop_level_set), so checks read what was
## asked for without an audio device. It never reads or writes game state, and its random pitch has
## its own generator. Its players keep the default pausable mode, so the solo pause freezes the sea
## with the world.

## A one-shot was played.
signal sfx_played(id: StringName)
## A loop was asked for a new level (0 to 1).
signal loop_level_set(id: StringName, level: float)

## The sound bank; loaded from SoundBank.STANDARD_PATH at start unless set first (tests).
var bank: SoundBank = null
## Seconds, for the repeat guard; tests replace it.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _rng := RandomNumberGenerator.new()
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_voice: AudioStreamPlayer = null
var _last_played_s: Dictionary[StringName, float] = {}
var _warned: Array[StringName] = []
var _loops: Dictionary[StringName, AudioStreamPlayer] = {}
var _loop_level: Dictionary[StringName, float] = {}
var _loop_target: Dictionary[StringName, float] = {}
var _volume: float = 1.0


func _ready() -> void:
	AudioBuses.ensure()
	if bank == null:
		bank = load(SoundBank.STANDARD_PATH) as SoundBank
	_rng.randomize()


func _process(delta: float) -> void:
	step_loops(delta)


## Plays the one-shot `id` at its bank level plus `db_offset`. An empty id does nothing; an id the
## bank does not list, or a loop's id, does nothing and warns once. Requests inside the id's repeat
## interval play once.
func play_sfx(id: StringName, db_offset: float = 0.0) -> void:
	if id == &"":
		return
	var sound: SoundData = bank.entry(id) if bank != null else null
	if sound == null or sound.stream == null or sound.loop:
		_warn_once(id, "is not a one-shot in the sound bank")
		return
	var now: float = clock.call()
	if _last_played_s.has(id) and now - _last_played_s[id] < sound.min_interval_s:
		return
	_last_played_s[id] = now
	var voice: AudioStreamPlayer = _take_voice()
	voice.stream = sound.stream
	voice.bus = AudioBuses.name_of(sound.bus)
	voice.volume_db = sound.volume_db + db_offset
	voice.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_spread, sound.pitch_spread)
	voice.play()
	_last_voice = voice
	sfx_played.emit(id)


## Asks the loop `id` for `level` (0 to 1, on top of its bank level). It starts silent and fades
## toward the level over its fade time; at 0 it fades out and stops.
func set_loop_level(id: StringName, level: float) -> void:
	var sound: SoundData = bank.entry(id) if bank != null else null
	if sound == null or sound.stream == null or not sound.loop:
		_warn_once(id, "is not a loop in the sound bank")
		return
	var target: float = clampf(level, 0.0, 1.0)
	if target < AudioBuses.SILENT:
		target = 0.0
	if _loop_target.get(id, -1.0) == target:
		return
	_loop_target[id] = target
	loop_level_set.emit(id, target)
	if target > 0.0 and not _loops.has(id):
		var player := AudioStreamPlayer.new()
		player.name = "Loop_%s" % id
		player.stream = sound.stream
		player.bus = AudioBuses.name_of(sound.bus)
		player.volume_db = linear_to_db(AudioBuses.SILENT) + sound.volume_db
		add_child(player)
		player.play()
		_loops[id] = player
		_loop_level[id] = 0.0


## Moves every loop toward its level by `delta` seconds of fade; stops the ones that reach silence.
func step_loops(delta: float) -> void:
	for id: StringName in _loops.keys():
		var sound: SoundData = bank.entry(id)
		var target: float = _loop_target.get(id, 0.0)
		var level: float = move_toward(_loop_level[id], target, delta / maxf(sound.fade_s, 0.001))
		_loop_level[id] = level
		var player: AudioStreamPlayer = _loops[id]
		if level <= 0.0 and target <= 0.0:
			_drop_loop(id)
		else:
			player.volume_db = sound.volume_db + linear_to_db(maxf(level, AudioBuses.SILENT))


## Stops every loop at once, with no fade (a run ending).
func stop_loops() -> void:
	for id: StringName in _loops.keys():
		_drop_loop(id)
	_loop_target.clear()


## Sets the volume setting (0 to 1) on the Master bus; 0 mutes.
func set_volume(level: float) -> void:
	_volume = clampf(level, 0.0, 1.0)
	AudioServer.set_bus_mute(0, _volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, AudioBuses.SILENT)) if _volume < 1.0 else 0.0)


func volume() -> float:
	return _volume


## Forgets when each id last played, so the next request plays (tests that share this autoload).
func reset_guard() -> void:
	_last_played_s.clear()


# --- for checks ----------------------------------------------------------------------------------

## The loop's current level (0 to 1), 0 when it is not playing.
func loop_level(id: StringName) -> float:
	return _loop_level.get(id, 0.0)


## The level the loop was last asked for.
func loop_target(id: StringName) -> float:
	return _loop_target.get(id, 0.0)


func loop_playing(id: StringName) -> bool:
	return _loops.has(id)


func loop_player(id: StringName) -> AudioStreamPlayer:
	return _loops.get(id, null)


func playing_loops() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_loops.keys())
	return ids


func last_voice() -> AudioStreamPlayer:
	return _last_voice


func voice_count() -> int:
	return _voices.size()


func warned_ids() -> Array[StringName]:
	return _warned.duplicate()


# --- inside ----------------------------------------------------------------------------------------

func _take_voice() -> AudioStreamPlayer:
	if _voices.size() < AudioBuses.VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % _voices.size()
		add_child(voice)
		_voices.append(voice)
		return voice
	var reused: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % AudioBuses.VOICES
	reused.stop()
	return reused


func _drop_loop(id: StringName) -> void:
	var player: AudioStreamPlayer = _loops[id]
	player.stop()
	remove_child(player)
	player.free()
	_loops.erase(id)
	_loop_level.erase(id)


func _warn_once(id: StringName, why: String) -> void:
	if _warned.has(id):
		return
	_warned.append(id)
	push_warning("AudioManager: %s %s" % [id, why])
