extends GutTest
## sound-pass audio "Sounds are data" (design D3): every sound the game plays is an entry of
## res://resources/sound_bank.tres, every id resolves to a tracked file that loads, the loops loop
## and the one-shots do not, and the cue numbers live beside them.

const SPEC_IDS: PackedStringArray = [
	"arrival", "compass_rattle", "hurt_big", "hurt_drain", "hurt_hit", "loudhailer", "night",
	"patrol_motor", "pickup", "raft_hit", "sea", "thirst_low", "thunder", "use_done", "wind",
]
const LOOP_IDS: PackedStringArray = ["night", "patrol_motor", "sea", "wind"]
## The owner's approved CC0 recordings (owner Q2 B); every other id comes from tools/audio/sfx.py.
const RECORDING_IDS: PackedStringArray = ["sea", "thunder", "wind"]

var bank: SoundBank


func before_each() -> void:
	bank = load(SoundBank.STANDARD_PATH) as SoundBank


func test_the_bank_loads_with_no_problems() -> void:
	assert_not_null(bank)
	assert_eq(bank.problems(), PackedStringArray())


func test_the_bank_has_the_fifteen_ids() -> void:
	var ids: PackedStringArray = []
	for id: StringName in bank.ids():
		ids.append(String(id))
	ids.sort()
	assert_eq(ids, SPEC_IDS)


func test_every_id_resolves_to_a_tracked_file_that_loads() -> void:
	for entry: SoundData in bank.entries:
		var path: String = entry.stream.resource_path if entry.stream != null else ""
		var folder: String = SoundBank.LOOPS_FOLDER if entry.loop else SoundBank.SFX_FOLDER
		assert_true(path.begins_with(folder), "%s lives in %s: %s" % [entry.id, folder, path])
		assert_eq(path.get_file(), "%s.wav" % entry.id, "%s's file is named by its id" % entry.id)
		assert_true(FileAccess.file_exists(path), "%s's file is tracked: %s" % [entry.id, path])
		assert_false(path.contains("audio/ambience/"), "the git-ignored downloads folder is never named")


func test_the_loops_loop_and_the_one_shots_do_not() -> void:
	for entry: SoundData in bank.entries:
		var wav := entry.stream as AudioStreamWAV
		assert_not_null(wav, "%s is a WAV stream" % entry.id)
		if wav == null:
			continue
		assert_eq(entry.loop, LOOP_IDS.has(String(entry.id)), "%s's loop flag" % entry.id)
		if entry.loop:
			assert_ne(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s loops after import" % entry.id)
		else:
			assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s plays once" % entry.id)


func test_loops_are_ambience_and_effects_are_effects_but_the_motor_warns() -> void:
	for entry: SoundData in bank.entries:
		var expected: SoundData.Bus = SoundData.Bus.AMBIENCE if entry.loop and entry.id != &"patrol_motor" else SoundData.Bus.SFX
		assert_eq(entry.bus, expected, "%s's bus" % entry.id)


func test_every_entry_has_sane_numbers() -> void:
	for entry: SoundData in bank.entries:
		assert_between(entry.volume_db, -40.0, 0.0, "%s level" % entry.id)
		assert_between(entry.pitch_spread, 0.0, 0.2, "%s pitch spread" % entry.id)
		assert_true(entry.min_interval_s >= 0.0, "%s repeat guard" % entry.id)
		assert_true(entry.fade_s > 0.0, "%s fade" % entry.id)
		assert_eq(entry.generated, not RECORDING_IDS.has(String(entry.id)), "%s's generated flag" % entry.id)


func test_the_low_thirst_step_is_the_sed_bars_pulse_step() -> void:
	assert_eq(bank.thirst_low_at, MeterBar.CRITICAL_LOW)
	assert_gt(bank.thirst_rearm_above, bank.thirst_low_at)


func test_the_cue_numbers() -> void:
	assert_lt(bank.motor_low_db, bank.motor_high_db, "the motor swells up")
	assert_lt(bank.motor_far_db, bank.motor_high_db)
	assert_lt(bank.motor_near_tiles, bank.motor_far_tiles)
	assert_lt(bank.thunder_gap_min_s, bank.thunder_gap_max_s)
	assert_lt(bank.thunder_far_db, 0.0, "a warned squall's thunder is quieter")
	assert_true(bank.squall_weathers.has(&"squall"))
	assert_true(GameState.content.get_entry(&"weather", &"squall") != null, "the squall weather exists")
	assert_lt(bank.sea_island, bank.sea_crossing, "the sea is louder at sea")
	assert_lt(bank.wind_crossing, bank.wind_squall, "the wind is louder in a squall")


func test_entry_finds_by_id_and_misses_are_null() -> void:
	assert_eq(bank.entry(&"pickup").id, &"pickup")
	assert_null(bank.entry(&"no_such_sound"))
	assert_null(bank.entry(&""))


func test_problems_name_an_entry_without_a_file_and_a_repeated_id() -> void:
	var broken := SoundBank.new()
	var missing := SoundData.new()
	missing.id = &"missing_file"
	var first := SoundData.new()
	first.id = &"twice"
	first.stream = bank.entry(&"pickup").stream
	var second := SoundData.new()
	second.id = &"twice"
	second.stream = bank.entry(&"pickup").stream
	var looped := SoundData.new()
	looped.id = &"not_a_loop"
	looped.loop = true
	looped.stream = bank.entry(&"pickup").stream
	broken.entries = [missing, first, second, looped]
	var problems: String = "\n".join(broken.problems())
	assert_string_contains(problems, "missing_file")
	assert_string_contains(problems, "twice")
	assert_string_contains(problems, "not_a_loop")
