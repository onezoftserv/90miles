extends GutTest
## art-pass "Credits list every pack used" ("Every CC-BY pack credited", "A CC-BY pack without its
## credit") on res://assets/art/credits.tres, game/assets/CREDITS.md and every License.txt under
## res://assets/art (task 1.7; design.md D10, K15). Rows are matched by author, licence and source,
## never by pack name.

const ART_ROOT: String = "res://assets/art"
const CREDITS_MD: String = "res://assets/CREDITS.md"
const UNCREDITED_FIXTURE: String = "res://tests/fixtures/art/credits/uncredited"
const CC_BY: String = "CC BY 4.0"
const CC_BY_URL: String = "https://creativecommons.org/licenses/by/4.0/"
const CC0: String = "CC0 1.0"
const CC0_URL: String = "https://creativecommons.org/publicdomain/zero/1.0/"
const OFL: String = "SIL OFL 1.1"
## design.md D10's wording for the three CC-BY packs, by source page.
const CC_BY_LINES: Dictionary[String, String] = {
	"https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181": "DawnLike – 16x16 Universal Rogue-like tileset v1.81, de DragonDePlatino; paleta de DawnBringer (CC BY 4.0) – opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181",
	"https://thkaspar.itch.io/tth-animals": "Tiny, Tiny Heroes - Animals, de Kacper Woźniak (thkaspar) (CC BY 4.0) – thkaspar.itch.io/tth-animals",
	"https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack": "Kyrise's Free 16x16 RPG Icon Pack © 2018 Kyrise (CC BY 4.0) – kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack",
}
## design.md D10's CC0 courtesy lines: MetroCity, ArMM1998, Foozle and Pixel Carvel, Eldiran, Kenney.
const CC0_SOURCES: PackedStringArray = [
	"https://jik-a-4.itch.io/metrocity-free-topdown-character-pack",
	"https://opengameart.org/content/zelda-like-tilesets-and-sprites",
	"https://foozlecc.itch.io/scallywag-water-islands",
	"https://opengameart.org/node/144858",
	"https://kenney.nl/assets/pixel-ui-pack",
	"https://kenney.nl/assets/tiny-dungeon",
]
## Packs credited ahead of their files (design.md K20, K33): each leaves this list in the group that
## tracks its files (DawnLike and Tiny, Tiny Heroes - Animals in group 6, Kyrise in group 7), and a
## test fails while it names a pack that has a block. Zelda-like, Scallywag and Eldiran left it with
## the terrain art (task 4.4), Kyrise and DawnLike with the item icons (task 7.3).
const PENDING_SOURCES: PackedStringArray = [
	"https://thkaspar.itch.io/tth-animals",
]
const FONT_SOURCES: PackedStringArray = [
	"https://github.com/google/fonts/tree/main/ofl/pressstart2p",
	"https://github.com/google/fonts/tree/main/ofl/pixelifysans",
]
const FIXTURE_LICENCE: String = "Pack: Tiburones de Prueba (1.0)\nAuthor: A. Fixture\nLicence: CC-BY 4.0\nSource: https://www.example.com/tiburones-de-prueba/\nFiles: none\n"
const FIXTURE_ROW: String = "| Tiburones - de prueba | A. Fixture | CC BY 4.0 | https://example.com/tiburones-de-prueba | `x/` |"


func _credits() -> ArtCredits:
	return load(ArtCredits.STANDARD_PATH) as ArtCredits


func _credits_md() -> String:
	return FileAccess.get_file_as_string(CREDITS_MD)


func _entry(credits: ArtCredits, source: String) -> ArtCredit:
	for entry: ArtCredit in credits.entries:
		if entry.source == source:
			return entry
	return null


func _fixture_credits(licence_url: String = CC_BY_URL) -> ArtCredits:
	var entry: ArtCredit = ArtCredit.new()
	entry.pack = "Tiburones de prueba – otro nombre"
	entry.author = "A. Fixture"
	entry.licence = CC_BY
	entry.licence_url = licence_url
	entry.source = "https://example.com/tiburones-de-prueba"
	entry.attribution_required = true
	entry.line_es = "Tiburones de prueba, de A. Fixture (CC BY 4.0) – example.com/tiburones-de-prueba"
	var credits: ArtCredits = ArtCredits.new()
	credits.entries.append(entry)
	return credits


func _fixture_licences() -> Dictionary[String, String]:
	return {"res://fixture/License.txt": FIXTURE_LICENCE}


func test_a_solo_offline_game_reads_its_credits_from_the_data_alone() -> void:
	assert_false(multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network peer")
	var credits: ArtCredits = _credits()
	assert_not_null(credits, "%s loads as ArtCredits" % ArtCredits.STANDARD_PATH)
	if credits == null:
		return
	assert_gt(credits.entries.size(), 0)
	for entry: ArtCredit in credits.entries:
		assert_false(entry.pack.is_empty() or entry.author.is_empty() or entry.licence.is_empty(), "%s names pack, author and licence" % entry.source)
		assert_true(entry.source.begins_with("https://"), "%s: the source is a page" % entry.pack)
		assert_string_contains(entry.line_es, entry.source.trim_prefix("https://"), false)
		assert_eq(entry.attribution_required, CreditChecks.is_cc_by(entry.licence), "%s: attribution is required exactly for CC BY" % entry.pack)


func test_the_three_cc_by_packs_carry_their_required_wording() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits == null:
		return
	for source: String in CC_BY_LINES:
		var entry: ArtCredit = _entry(credits, source)
		assert_not_null(entry, "credits.tres has %s" % source)
		if entry == null:
			continue
		assert_eq(entry.line_es, CC_BY_LINES[source])
		assert_eq(entry.licence, CC_BY)
		assert_eq(entry.licence_url, CC_BY_URL)
		assert_true(entry.attribution_required)
		assert_true(entry.modified, "%s is recoloured to the master palette" % entry.pack)


func test_the_cc0_packs_and_the_fonts_have_courtesy_lines() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits == null:
		return
	for source: String in CC0_SOURCES:
		var entry: ArtCredit = _entry(credits, source)
		assert_not_null(entry, "credits.tres has %s" % source)
		if entry != null:
			assert_eq([entry.licence, entry.licence_url], [CC0, CC0_URL], source)
	for source: String in FONT_SOURCES:
		var entry: ArtCredit = _entry(credits, source)
		assert_not_null(entry, "credits.tres has %s" % source)
		if entry != null:
			assert_eq(entry.licence, OFL, source)


func test_every_cc_by_entry_carries_the_licence_address_its_source_page_and_its_row() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits != null:
		assert_eq(CreditChecks.check_cc_by_entries(credits, _credits_md()), PackedStringArray())


func test_every_cc_by_licence_under_the_art_is_credited_in_the_data_and_credits_md() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits != null:
		var licences: Dictionary[String, String] = CreditChecks.licence_texts_under(ART_ROOT)
		assert_gt(licences.size(), 0, "the art has licence files to check")
		assert_eq(CreditChecks.check_cc_by_credited(licences, credits, _credits_md()), PackedStringArray())


func test_every_tracked_pack_is_credited_in_the_data_and_credits_md() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits != null:
		assert_eq(CreditChecks.check_packs_credited(CreditChecks.licence_texts_under(ART_ROOT), credits, _credits_md()), PackedStringArray())


func test_every_entry_but_the_fonts_credits_a_pack_whose_files_are_tracked() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits != null:
		assert_eq(CreditChecks.check_entries_tracked(CreditChecks.licence_texts_under(ART_ROOT), credits, PENDING_SOURCES), PackedStringArray())


func test_each_pending_pack_is_credited_and_has_no_tracked_files_yet() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits == null:
		return
	var licences: Dictionary[String, String] = CreditChecks.licence_texts_under(ART_ROOT)
	for source: String in PENDING_SOURCES:
		var entry: ArtCredit = _entry(credits, source)
		assert_not_null(entry, "%s has an entry" % source)
		if entry == null:
			continue
		var alone: ArtCredits = ArtCredits.new()
		alone.entries.append(entry)
		var failures: PackedStringArray = CreditChecks.check_entries_tracked(licences, alone, PackedStringArray())
		assert_eq(failures.size(), 1, "%s still has no Pack: block under %s; once it has, drop it from PENDING_SOURCES" % [source, ART_ROOT])


func test_an_entry_whose_pack_has_no_tracked_files_fails_naming_it() -> void:
	var failures: PackedStringArray = CreditChecks.check_entries_tracked({}, _fixture_credits(), PackedStringArray())
	assert_eq(failures.size(), 1, "%s" % [failures])
	if failures.size() == 1:
		assert_string_contains(failures[0], "Tiburones de prueba – otro nombre")
		assert_string_contains(failures[0], "https://example.com/tiburones-de-prueba")
	assert_eq(CreditChecks.check_entries_tracked(_fixture_licences(), _fixture_credits(), PackedStringArray()), PackedStringArray(), "matched by source and author, not by name")
	var font: ArtCredits = _fixture_credits()
	font.entries[0].licence = OFL
	font.entries[0].attribution_required = false
	assert_eq(CreditChecks.check_entries_tracked({}, font, PackedStringArray()), PackedStringArray(), "fonts are not art packs")


func test_a_cc_by_licence_without_its_credit_fails_naming_the_pack() -> void:
	var licences: Dictionary[String, String] = CreditChecks.licence_texts_under(UNCREDITED_FIXTURE)
	assert_eq(licences.keys(), [UNCREDITED_FIXTURE.path_join("License.txt")])
	var credits: ArtCredits = _credits()
	if credits == null:
		credits = ArtCredits.new()
	var failures: PackedStringArray = CreditChecks.check_cc_by_credited(licences, credits, _credits_md())
	assert_eq(failures.size(), 2, "no entry and no CREDITS.md row: %s" % [failures])
	for failure: String in failures:
		assert_string_contains(failure, "Tiburones de Prueba (1.0)")
		assert_string_contains(failure, UNCREDITED_FIXTURE)


func test_a_cc_by_pack_is_matched_by_author_licence_and_source_not_by_name() -> void:
	assert_eq(CreditChecks.check_cc_by_credited(_fixture_licences(), _fixture_credits(), FIXTURE_ROW), PackedStringArray())
	assert_eq(CreditChecks.check_packs_credited(_fixture_licences(), _fixture_credits(), FIXTURE_ROW), PackedStringArray())


func test_a_cc_by_pack_with_another_author_or_licence_is_not_credited() -> void:
	var other_author: ArtCredits = _fixture_credits()
	other_author.entries[0].author = "B. Otro"
	var failures: PackedStringArray = CreditChecks.check_cc_by_credited(_fixture_licences(), other_author, FIXTURE_ROW)
	assert_eq(failures.size(), 1, "no entry by that author: %s" % [failures])
	var cc0_entry: ArtCredits = _fixture_credits()
	cc0_entry.entries[0].licence = CC0
	failures = CreditChecks.check_cc_by_credited(_fixture_licences(), cc0_entry, FIXTURE_ROW)
	assert_eq(failures.size(), 1, "no CC BY entry: %s" % [failures])


func test_a_credited_cc_by_pack_without_its_credits_md_row_fails_naming_the_pack() -> void:
	var failures: PackedStringArray = CreditChecks.check_cc_by_credited(_fixture_licences(), _fixture_credits(), "| Tiburones de Prueba | A. Fixture | CC0 1.0 | https://example.com/tiburones-de-prueba | `x/` |")
	assert_eq(failures.size(), 1, "%s" % [failures])
	if failures.size() == 1:
		assert_string_contains(failures[0], "Tiburones de Prueba (1.0)")
		assert_string_contains(failures[0], "CREDITS.md")


func test_a_tracked_pack_without_any_entry_fails_naming_the_pack() -> void:
	var cc0_licence: Dictionary[String, String] = {"res://fixture/License.txt": "Pack: Conchas Libres\nAuthor: C. Fixture\nLicence: CC0 1.0\nSource: https://example.com/conchas\nFiles: x\n"}
	var failures: PackedStringArray = CreditChecks.check_packs_credited(cc0_licence, ArtCredits.new(), "")
	assert_eq(failures.size(), 2, "no entry and no CREDITS.md row: %s" % [failures])
	for failure: String in failures:
		assert_string_contains(failure, "Conchas Libres")


func test_a_cc_by_entry_without_the_licence_address_fails_naming_the_pack() -> void:
	var failures: PackedStringArray = CreditChecks.check_cc_by_entries(_fixture_credits(""), FIXTURE_ROW)
	assert_eq(failures.size(), 1, "%s" % [failures])
	if failures.size() == 1:
		assert_string_contains(failures[0], "Tiburones de prueba – otro nombre")
		assert_string_contains(failures[0], CC_BY_URL)


func test_the_screen_order_is_cc_by_then_cc0_and_courtesy_then_fonts() -> void:
	var credits: ArtCredits = _credits()
	assert_not_null(credits)
	if credits == null:
		return
	var groups: Array[int] = []
	for entry: ArtCredit in credits.in_screen_order():
		groups.append(0 if CreditChecks.is_cc_by(entry.licence) else (2 if entry.licence == OFL else 1))
	var sorted_groups: Array[int] = groups.duplicate()
	sorted_groups.sort()
	assert_eq(groups, sorted_groups)
	assert_eq(groups.size(), credits.entries.size())
	assert_eq(groups.front(), 0)
	assert_eq(groups.back(), 2)
