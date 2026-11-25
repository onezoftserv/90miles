class_name IslandGenerator
extends RefCounted
## island-generator: builds a chain's island from its template (ChainData), the run seed and the
## island index, the same on every peer (design §4–§6). Attempts run 0 to max_attempts − 1, each
## with its own seeds; the last `relaxed_attempts` skip rolled POIs; when none passes, the chain's
## fallback island (the first valid attempt for its fallback seed and index 0) is used.

## Layout rule -> painter (a class with a static `paint`). A new chain with an existing painter is
## data only.
const PAINTERS: Dictionary[ChainData.LayoutRule, GDScript] = {
	ChainData.LayoutRule.REEF_RING: preload("res://scripts/levels/generation/reef_ring_painter.gd"),
}
const STAGES: Array[StringName] = [&"land", &"bands", &"landing", &"pois", &"pickups", &"routes"]


## The island for (`run_seed`, `index`) of `chain`. `extra_check`, for tests only, takes the
## candidate GeneratedIsland and returns failure messages, run after the built-in checks.
static func generate(run_seed: int, index: int, chain: ChainData, catalog: ContentCatalog = null, extra_check: Callable = Callable()) -> GeneratedIsland:
	var content: ContentCatalog = catalog if catalog != null else GameState.content
	var started: int = Time.get_ticks_usec()
	var result: GeneratedIsland = _search(run_seed, index, chain, content, extra_check)
	if result.fallback:
		var spare: GeneratedIsland = _search(chain.fallback_seed, 0, chain, content, Callable())
		if spare.fallback:
			push_error("island-generator: the fallback island of %s fails its checks" % chain.id)
		var attempts: Array = result.report["attempts"]
		result = _renamed(spare, chain, index, content)
		result.fallback = true
		result.attempts = attempts.size()
		result.report["attempts"] = attempts
	result.report["generation_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	return result


# Every attempt in turn; the first that passes, or the last one marked as the fallback.
static func _search(run_seed: int, index: int, chain: ChainData, catalog: ContentCatalog, extra_check: Callable) -> GeneratedIsland:
	var attempts: Array[Dictionary] = []
	var last: GeneratedIsland = null
	var count: int = maxi(1, chain.max_attempts)
	for attempt: int in count:
		var relaxed: bool = attempt >= count - chain.relaxed_attempts
		var island: GeneratedIsland = attempt_island(run_seed, index, chain, catalog, attempt, relaxed)
		var failures: PackedStringArray = island.report["failures"]
		if failures.is_empty() and extra_check.is_valid():
			failures.append_array(extra_check.call(island))
		attempts.append({
			"failures": failures, "pois": island.pois, "terrain": island.report["terrain"],
			"land_count": island.report["land_count"], "shore_width": island.report["shore_width"],
			"relaxed": relaxed,
		})
		last = island
		if failures.is_empty():
			island.attempts = attempt + 1
			island.report["attempts"] = attempts
			return island
	last.fallback = true
	last.attempts = count
	last.report["attempts"] = attempts
	return last


## One attempt, checked: report has failures (empty when it passes), terrain, land_count and
## shore_width.
static func attempt_island(run_seed: int, index: int, chain: ChainData, catalog: ContentCatalog, attempt: int, relaxed: bool) -> GeneratedIsland:
	var rngs: Dictionary[StringName, RandomNumberGenerator] = {}
	for stage: StringName in STAGES:
		rngs[stage] = IslandSeeds.rng_for(run_seed, index, chain.id, attempt, stage)
	var island := GeneratedIsland.new()
	var painter: GDScript = PAINTERS.get(chain.layout_rule)
	if painter == null:
		island.report = {"failures": PackedStringArray(["painter: no painter for rule %d" % chain.layout_rule]), "terrain": PackedInt32Array(), "land_count": 0, "shore_width": 0}
		return island
	var painted: Dictionary = painter.call(&"paint", chain, rngs[&"land"], rngs[&"bands"])
	var placer := PoiPlacer.new(chain, catalog, painted)
	placer.place(rngs[&"landing"], rngs[&"pois"], rngs[&"pickups"], rngs[&"routes"], relaxed)
	var failures := PackedStringArray(painted["failures"])
	failures.append_array(placer.failures)
	island.pois = placer.pois
	island.report = {
		"failures": failures, "terrain": painted["terrain"], "land_count": painted["land_count"],
		"shore_width": painted["shore_width"], "land_target": painted["land_target"], "relaxed": relaxed, "spine_tiles": painted["spine_tiles"], "rolled_tiles": painted["rolled_tiles"],
	}
	if not placer.landing.is_empty():
		island.layout = IslandLayoutWriter.emit(chain, index, placer, catalog)
		island.built = IslandLayout.build(island.layout)
		island.island_hash = IslandLayoutWriter.digest(island.layout)
		failures.append_array(IslandValidator.check(chain, island.built, island.pois, catalog))
	island.report["failures"] = failures
	return island


# The fallback island under the requested island's id.
static func _renamed(spare: GeneratedIsland, chain: ChainData, index: int, catalog: ContentCatalog) -> GeneratedIsland:
	var island := GeneratedIsland.new()
	island.pois = spare.pois
	island.report = spare.report
	if spare.layout == null:
		return island
	var text: String = IslandLayoutWriter.write(spare.layout)
	var renamed: IslandLayoutData = IslandLayoutWriter.parse(text, catalog)
	if renamed == null:
		renamed = spare.layout
	renamed.id = StringName("%s_%d" % [chain.id, index])
	island.layout = renamed
	island.built = IslandLayout.build(renamed)
	island.island_hash = IslandLayoutWriter.digest(renamed)
	return island
