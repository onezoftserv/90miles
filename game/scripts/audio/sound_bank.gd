class_name SoundBank
extends Resource
## The sound bank (sound-pass design D3), res://resources/sound_bank.tres: every sound the game
## plays by id, and the numbers its cues read (the patrol motor's swell, the low-thirst step, the
## thunder, the ambience levels). Adding, replacing or retuning a sound edits only this file.
## Callers load STANDARD_PATH themselves (no static loader beside the typed entries array: art-pass
## K26 saw that leak scripts at exit).

const STANDARD_PATH: String = "res://resources/sound_bank.tres"
const SFX_FOLDER: String = "res://assets/audio/sfx/"
const LOOPS_FOLDER: String = "res://assets/audio/loops/"

@export var entries: Array[SoundData] = []

@export_group("Patrol motor")
## The motor's level as a boat's horizon warning starts, in dB under its bank level.
@export var motor_low_db: float = -24.0
## Its level as the warning ends, and while a boat in sight is within motor_near_tiles.
@export var motor_high_db: float = 0.0
## Tiles from the view within which a boat in sight is at motor_high_db.
@export var motor_near_tiles: float = 8.0
## Tiles at which a boat in sight has faded to motor_far_db; beyond twice this it is silent.
@export var motor_far_tiles: float = 28.0
@export var motor_far_db: float = -18.0

@export_group("Low thirst")
## thirst_low plays when thirst falls to this or less: the Sed bar's pulse step (MeterBar.CRITICAL_LOW).
@export var thirst_low_at: float = 25.0
## It plays again only after thirst has been above this.
@export var thirst_rearm_above: float = 30.0

@export_group("Thunder")
## Seconds between rolls while a squall blows, picked at random by the audio, never the game.
@export var thunder_gap_min_s: float = 9.0
@export var thunder_gap_max_s: float = 22.0
## A warned squall's thunder, in dB under the bank level: it is still far off.
@export var thunder_far_db: float = -12.0
## Weathers that blow: thunder, and the wind at its squall level.
@export var squall_weathers: Array[StringName] = [&"squall"]

@export_group("Ambience")
## Loop levels (0 to 1, on top of each loop's bank level).
@export var sea_island: float = 0.55
@export var sea_crossing: float = 1.0
@export var wind_crossing: float = 0.6
@export var wind_squall: float = 1.0
@export var night_level: float = 1.0


## The entry for `id`, or null (an empty id included).
func entry(id: StringName) -> SoundData:
	if id == &"":
		return null
	for sound: SoundData in entries:
		if sound != null and sound.id == id:
			return sound
	return null


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for sound: SoundData in entries:
		if sound != null:
			found.append(sound.id)
	return found


## What is wrong with the bank, each line naming the id: an empty or repeated id, no file, or a
## loop flag its file does not match.
func problems() -> PackedStringArray:
	var found: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for i: int in entries.size():
		var sound: SoundData = entries[i]
		if sound == null:
			found.append("entry %d is empty" % i)
			continue
		if sound.id == &"":
			found.append("entry %d has no id" % i)
		elif seen.has(sound.id):
			found.append("%s is listed twice" % sound.id)
		seen[sound.id] = true
		if sound.stream == null:
			found.append("%s has no file" % sound.id)
			continue
		var wav := sound.stream as AudioStreamWAV
		if wav != null and sound.loop != (wav.loop_mode != AudioStreamWAV.LOOP_DISABLED):
			found.append("%s's loop flag is %s but its file %s" % [sound.id, sound.loop, "loops" if sound.loop == false else "does not loop"])
	return found
