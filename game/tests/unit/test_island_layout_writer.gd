extends GutTest
## island-generator design §2: the canonical text, the island hash and the guarded parse.

## Island 3 of reef_traps for run seed 1. Re-record only on purpose, when the template or the
## algorithm changes, and say so in the commit; CI on Linux must pass it unchanged.
const RECORDED_HASH: String = "cbac9cd5e6c91bab3a6d5d8237c8fd78c74d2d6424554604cad0bb668813b9ef"

var island: GeneratedIsland


func before_all() -> void:
	island = ReefSamples.island(1)


func test_write_parse_write_gives_the_same_text() -> void:
	var text: String = IslandLayoutWriter.write(island.layout)
	var parsed: IslandLayoutData = IslandLayoutWriter.parse(text, GameState.content)
	assert_not_null(parsed, "the writer's own text parses")
	if parsed == null:
		return
	assert_eq(IslandLayoutWriter.write(parsed), text)
	assert_eq(parsed.id, island.layout.id)
	assert_eq(parsed.rows, island.layout.rows)
	assert_eq(parsed.name_es, island.layout.name_es)
	assert_eq(parsed.climb_effects.size(), island.layout.climb_effects.size())
	assert_eq(IslandLayout.build(parsed).pickups, island.built.pickups)


func test_the_island_hash_is_the_sha256_of_the_text() -> void:
	var text: String = IslandLayoutWriter.write(island.layout)
	assert_eq(island.island_hash, text.sha256_text())
	assert_eq(island.island_hash.length(), 64)
	assert_eq(island.island_hash, island.island_hash.to_lower())


func test_the_same_island_twice() -> void:
	var again: GeneratedIsland = IslandGenerator.generate(1, 3, ReefSamples.chain())
	assert_eq(IslandLayoutWriter.write(again.layout), IslandLayoutWriter.write(island.layout))
	assert_eq(again.island_hash, island.island_hash)


func test_the_recorded_hash() -> void:
	assert_eq(island.island_hash, RECORDED_HASH, "island 3 of reef_traps, run seed 1")


func test_another_run_seed_gives_another_island() -> void:
	assert_ne(ReefSamples.island(2).island_hash, island.island_hash)


func _text_with(rows: PackedStringArray) -> String:
	var lines: PackedStringArray = IslandLayoutWriter.write(island.layout).split("\n")
	var legend: int = lines.find(IslandLayoutWriter.LEGEND)
	var out := PackedStringArray(rows)
	out.append_array(lines.slice(legend))
	return "\n".join(out)


func test_parse_refuses_a_map_over_128_by_128() -> void:
	var rows := PackedStringArray()
	for y: int in 129:
		rows.append("~".repeat(10))
	assert_null(IslandLayoutWriter.parse(_text_with(rows), GameState.content), "129 rows")
	var wide := PackedStringArray(island.layout.rows)
	wide[0] = "~".repeat(129)
	assert_null(IslandLayoutWriter.parse(_text_with(wide), GameState.content), "129 columns")


func test_parse_refuses_a_glyph_outside_the_alphabet() -> void:
	var rows := PackedStringArray(island.layout.rows)
	rows[0] = "Ñ" + rows[0].substr(1)
	assert_null(IslandLayoutWriter.parse(_text_with(rows), GameState.content))


func test_parse_refuses_a_legend_that_reads_with_problems() -> void:
	var text: String = IslandLayoutWriter.write(island.layout)
	assert_null(IslandLayoutWriter.parse(text.replace("\nsolo 1", "\nsolo Z"), GameState.content), "no solo spawn")
	assert_null(IslandLayoutWriter.parse(text.replace("\nterrain ~ 0", ""), GameState.content), "a glyph with no terrain")
	assert_null(IslandLayoutWriter.parse(text + "\nnonsense 1", GameState.content), "an unknown line")
	assert_null(IslandLayoutWriter.parse("", GameState.content), "empty text")
