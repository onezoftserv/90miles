class_name SoundCreditChecks
extends RefCounted
## sound-pass audio "Generated sounds are reproducible and credited" (design D2): every WAV in a
## sound folder is named in that folder's License.txt and in the "Sound" table of CREDITS.md, and a
## recording (a bank entry that is not generated, owner Q2 B) has a Pack: block with its author,
## a CC0 licence and a source page, and no Work: block claims it as own work. Each check returns
## its failures, naming the file; empty when the rule holds.

const LICENCE_FILE: String = "License.txt"


## Every WAV in `folder` named in its License.txt's Files: lines and somewhere in `credits_md`.
static func check_folder(folder: String, credits_md: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var licence_path: String = folder.path_join(LICENCE_FILE)
	var licence: String = FileAccess.get_file_as_string(licence_path) if FileAccess.file_exists(licence_path) else ""
	if licence.is_empty():
		failures.append("%s has no %s" % [folder, LICENCE_FILE])
	var listed: String = _files_lines(licence)
	for path: String in ArtChecks.files_under(folder, ["wav"]):
		var file: String = path.get_file()
		if not _names(listed, file):
			failures.append("%s is not named in %s" % [path, licence_path])
		if not _names(credits_md, file):
			failures.append("%s has no row in CREDITS.md" % path)
	return failures


## Each recording of `bank` has a Pack: block naming its file, with an author, a CC0 licence and
## a source page, and no Work: block names it.
static func check_recordings(bank: SoundBank) -> PackedStringArray:
	var failures: PackedStringArray = []
	for entry: SoundData in bank.entries:
		if entry.generated or entry.stream == null:
			continue
		var path: String = entry.stream.resource_path
		var licence_path: String = path.get_base_dir().path_join(LICENCE_FILE)
		var text: String = FileAccess.get_file_as_string(licence_path) if FileAccess.file_exists(licence_path) else ""
		var found := false
		for block: Dictionary in ArtChecks.licence_blocks(text):
			if not _names(String(block.get("Files", "")), path.get_file()):
				continue
			if block["kind"] == "Work":
				failures.append("%s is a recording but a Work: block in %s names it as own work" % [path, licence_path])
				continue
			if block["kind"] != "Pack":
				continue
			found = true
			var licence: String = String(block.get("Licence", block.get("License", "")))
			if String(block.get("Author", "")).strip_edges().is_empty():
				failures.append("%s's block has no author" % path)
			if not licence.contains("CC0"):
				failures.append("%s is not CC0: %s" % [path, licence])
			if not String(block.get("Source", "")).begins_with("https://"):
				failures.append("%s's block has no source page" % path)
		if not found:
			failures.append("%s is a recording with no Pack: block in %s" % [path, licence_path])
	return failures


static func _files_lines(licence: String) -> String:
	var lines: PackedStringArray = []
	for line: String in licence.split("\n"):
		if line.begins_with("Files:"):
			lines.append(line)
	return "\n".join(lines)


# True when `text` names `file` as a whole word (sea.wav, not overseas.wav).
static func _names(text: String, file: String) -> bool:
	var regex := RegEx.create_from_string("(^|[^A-Za-z0-9_./])%s($|[^A-Za-z0-9_])" % file.replace(".", "\\."))
	return regex.search(text) != null
