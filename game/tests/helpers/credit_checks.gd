class_name CreditChecks
extends RefCounted
## The credits checks of task 1.7 (art-pass "Credits list every pack used"; design.md D10, K15):
## the credits data (ArtCredits), game/assets/CREDITS.md and the License.txt pack blocks agree. A
## pack is matched by its author, licence and source page, never by its name, whose dashes and
## wording differ between the three. Every check returns its failures, each naming the pack, and an
## empty array when the rule holds.

const CC_BY: String = "CC BY 4.0"
const CC_BY_URL: String = "https://creativecommons.org/licenses/by/4.0/"
const DASHES: PackedStringArray = ["–", "—"]


## A licence that names CC BY, however it is written ("CC-BY 4.0", "CC BY 4.0 (…)").
static func is_cc_by(licence: String) -> bool:
	return _licence_key(licence).contains("cc by")


## Every License.txt under `root` (recursively), by path.
static func licence_texts_under(root: String) -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for path: String in ArtChecks.files_under(root, ["txt"]):
		if path.get_file() == ArtChecks.LICENCE_FILE:
			texts[path] = FileAccess.get_file_as_string(path)
	return texts


## "Every CC-BY pack credited": each CC-BY pack block has a CC BY entry by its author and source,
## and a CREDITS.md row with its author, "CC BY 4.0" and its source.
static func check_cc_by_credited(licences: Dictionary[String, String], credits: ArtCredits, credits_md: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	for block: Dictionary in _pack_blocks(licences):
		if not is_cc_by(_licence_of(block)):
			continue
		var entry: ArtCredit = _matching_entry(credits, block, true)
		if entry == null:
			failures.append("%s has no CC BY 4.0 entry in %s by its author and source" % [_label(block), ArtCredits.STANDARD_PATH])
		var authors: PackedStringArray = [block.get("Author", "")]
		if entry != null:
			authors.append(entry.author)
		if not _has_row(credits_md, authors, CC_BY, block.get("Source", "")):
			failures.append("%s has no row in CREDITS.md with its author, %s and its source" % [_label(block), CC_BY])
	return failures


## "Credits list every pack used": each tracked pack block, whatever its licence, has an entry and
## a CREDITS.md row by its author and source.
static func check_packs_credited(licences: Dictionary[String, String], credits: ArtCredits, credits_md: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	for block: Dictionary in _pack_blocks(licences):
		var entry: ArtCredit = _matching_entry(credits, block, false)
		if entry == null:
			failures.append("%s has no entry in %s by its author and source" % [_label(block), ArtCredits.STANDARD_PATH])
		var authors: PackedStringArray = [block.get("Author", "")]
		if entry != null:
			authors.append(entry.author)
		if not _has_row(credits_md, authors, "", block.get("Source", "")):
			failures.append("%s has no row in CREDITS.md with its author and source" % _label(block))
	return failures


## Every CC BY entry carries the licence's address, a source page that is not a licence deed, a
## line that shows that page, and its CREDITS.md row.
static func check_cc_by_entries(credits: ArtCredits, credits_md: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	for entry: ArtCredit in credits.entries:
		if not is_cc_by(entry.licence):
			continue
		var label: String = "%s entry '%s'" % [ArtCredits.STANDARD_PATH, entry.pack]
		if entry.licence_url != CC_BY_URL:
			failures.append("%s gives '%s' as the licence's address, not %s" % [label, entry.licence_url, CC_BY_URL])
		if not entry.source.begins_with("https://") or ArtChecks.is_licence_deed(entry.source):
			failures.append("%s gives '%s' as its source, not the pack's page" % [label, entry.source])
		elif not entry.line_es.contains(entry.source.trim_prefix("https://")):
			failures.append("%s: its line does not show its source page %s" % [label, entry.source])
		if not _has_row(credits_md, [entry.author], CC_BY, entry.source):
			failures.append("%s has no row in CREDITS.md with its author, %s and its source" % [label, CC_BY])
	return failures


static func _pack_blocks(licences: Dictionary[String, String]) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var paths: Array[String] = []
	paths.assign(licences.keys())
	paths.sort()
	for path: String in paths:
		for block: Dictionary in ArtChecks.licence_blocks(licences[path]):
			if block["kind"] == "Pack":
				var located: Dictionary = block.duplicate()
				located["path"] = path
				blocks.append(located)
	return blocks


static func _licence_of(block: Dictionary) -> String:
	return block.get("Licence", block.get("License", ""))


static func _label(block: Dictionary) -> String:
	return "%s: pack '%s' (%s, %s)" % [block["path"], block["Pack"], block.get("Author", ""), block.get("Source", "")]


## The entry with the block's source and author (and, if `cc_by`, a CC BY licence), or null.
static func _matching_entry(credits: ArtCredits, block: Dictionary, cc_by: bool) -> ArtCredit:
	var source: String = _url_key(block.get("Source", ""))
	for entry: ArtCredit in credits.entries:
		if cc_by and not is_cc_by(entry.licence):
			continue
		if _url_key(entry.source) == source and _names_match(entry.author, block.get("Author", "")):
			return entry
	return null


## A table row of `credits_md` holding the source, one of `authors` and, unless empty, `licence`.
static func _has_row(credits_md: String, authors: PackedStringArray, licence: String, source: String) -> bool:
	var source_key: String = _url_key(source)
	if source_key.is_empty():
		return false
	for line: String in credits_md.split("\n"):
		if not line.strip_edges().begins_with("|"):
			continue
		var row: String = _text_key(line)
		if not row.contains(source_key):
			continue
		if not licence.is_empty() and not _licence_key(line).contains(_licence_key(licence)):
			continue
		for author: String in authors:
			if not _text_key(author).is_empty() and row.contains(_text_key(author)):
				return true
	return false


## One author name holds the other ("Kenney (kenney.nl)" in "Kenney Vleugels for Kenney (kenney.nl)").
static func _names_match(a: String, b: String) -> bool:
	var key_a: String = _text_key(a)
	var key_b: String = _text_key(b)
	return not key_a.is_empty() and not key_b.is_empty() and (key_a.contains(key_b) or key_b.contains(key_a))


## Lower case, en and em dashes as hyphens, runs of white space as one space.
static func _text_key(text: String) -> String:
	var key: String = text.to_lower()
	for dash: String in DASHES:
		key = key.replace(dash, "-")
	var spaces: RegEx = RegEx.create_from_string("\\s+")
	return spaces.sub(key, " ", true).strip_edges()


## As _text_key, with hyphens as spaces, so "CC-BY 4.0" reads as "cc by 4.0".
static func _licence_key(text: String) -> String:
	return _text_key(_text_key(text).replace("-", " "))


## A page address without scheme, "www." or a trailing slash, in lower case.
static func _url_key(url: String) -> String:
	var key: String = url.strip_edges().to_lower()
	for prefix: String in ["https://", "http://"]:
		key = key.trim_prefix(prefix)
	return key.trim_prefix("www.").trim_suffix("/")
