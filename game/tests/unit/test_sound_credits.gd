extends GutTest
## sound-pass audio "Generated sounds are reproducible and credited" (design D2): every sound file
## the game ships is named in its folder's License.txt and in CREDITS.md, and the checks fail on a
## folder that misses one.

const CREDITS_MD: String = "res://assets/CREDITS.md"


func _credits_md() -> String:
	return FileAccess.get_file_as_string(CREDITS_MD)


func test_every_tracked_sound_is_credited() -> void:
	for folder: String in [SoundBank.SFX_FOLDER, SoundBank.LOOPS_FOLDER]:
		assert_eq(SoundCreditChecks.check_folder(folder.trim_suffix("/"), _credits_md()), PackedStringArray(), folder)


func test_every_recording_has_its_author_cc0_and_source() -> void:
	assert_eq(SoundCreditChecks.check_recordings(load(SoundBank.STANDARD_PATH) as SoundBank), PackedStringArray())


func test_the_three_recordings_are_checked() -> void:
	var recorded: PackedStringArray = []
	for entry: SoundData in (load(SoundBank.STANDARD_PATH) as SoundBank).entries:
		if not entry.generated:
			recorded.append(entry.stream.resource_path.get_file())
	recorded.sort()
	assert_eq(recorded, PackedStringArray(["sea.wav", "thunder.wav", "wind.wav"]))


func test_a_recording_claimed_as_own_work_fails() -> void:
	var folder: String = UserTmp.path("test_sound_credits_claimed")
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("License.txt"), "Pack: Rain\nAuthor: someone\nLicence: CC0 1.0\nSource: https://example.org/rain\nFiles: rain.wav\n\nWork: 90 Millas\nAuthor: 90 Millas\nFiles: rain.wav, drip.wav\n")
	var stream := AudioStreamWAV.new()
	stream.take_over_path(folder.path_join("rain.wav"))
	var entry := SoundData.new()
	entry.id = &"rain"
	entry.stream = stream
	entry.generated = false
	var bank := SoundBank.new()
	bank.entries = [entry]
	assert_string_contains("\n".join(SoundCreditChecks.check_recordings(bank)), "names it as own work")


func test_an_uncredited_file_fails_and_is_named() -> void:
	var folder: String = UserTmp.path("test_sound_credits_folder")
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("credited.wav"), "x")
	_write(folder.path_join("stray.wav"), "x")
	_write(folder.path_join("License.txt"), "Work: test\nAuthor: 90 Millas\nLicence: All rights reserved\nSource: 90 Millas (own work)\nFiles: credited.wav\n")
	var failures: String = "\n".join(SoundCreditChecks.check_folder(folder, "| x | `credited.wav` |"))
	assert_string_contains(failures, "stray.wav is not named in")
	assert_string_contains(failures, "stray.wav has no row in CREDITS.md")
	assert_false(failures.contains("credited.wav"), "the credited file passes")


func test_a_folder_without_a_licence_fails() -> void:
	var folder: String = UserTmp.path("test_sound_credits_bare")
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("lonely.wav"), "x")
	assert_string_contains("\n".join(SoundCreditChecks.check_folder(folder, "")), "has no License.txt")


func test_a_name_inside_another_name_does_not_count() -> void:
	var folder: String = UserTmp.path("test_sound_credits_words")
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("sea.wav"), "x")
	_write(folder.path_join("License.txt"), "Work: t\nFiles: overseas.wav\n")
	assert_string_contains("\n".join(SoundCreditChecks.check_folder(folder, "overseas.wav")), "sea.wav is not named")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
