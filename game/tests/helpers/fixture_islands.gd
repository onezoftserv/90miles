class_name FixtureIslands
extends RefCounted
## Test-only islands (guardacostas-capture tasks.md 1.3): a chain of three tiny cays (chain_a →
## chain_b → chain_c, the last naming no next island), a tiny off-graph cay and a tiny REEF cay.
## They live in tests/fixtures/content/islands/; `put_in` places them in `GameState.content`'s cache
## by id so travel and `get_entry(&"islands", id)` find them, and `take_out` removes them again.
## Call `take_out` in `after_each` so no other test or the content check sees them.

const DIR := "res://tests/fixtures/content/islands"
const IDS: Array[StringName] = [&"chain_a", &"chain_b", &"chain_c", &"chain_off", &"reef_test"]


## Every fixture island, freshly loaded and in the cache, by id.
static func put_in() -> Dictionary[StringName, IslandLayoutData]:
	var islands: Dictionary[StringName, IslandLayoutData] = {}
	for id: StringName in IDS:
		var layout := (load("%s/%s.tres" % [DIR, id]) as IslandLayoutData).duplicate(true) as IslandLayoutData
		GameState.content._cache["islands/%s" % id] = layout
		islands[id] = layout
	return islands


static func take_out() -> void:
	for id: StringName in IDS:
		GameState.content._cache.erase("islands/%s" % id)
