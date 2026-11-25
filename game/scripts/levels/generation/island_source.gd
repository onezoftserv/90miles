class_name IslandSource
extends RefCounted
## island-generator design §6: what an island id names. An id in `islands/` is a handmade layout;
## an id in `chains/` is generated from the run seed and the island index, the same on every peer.
## Generated islands are cached per run seed, chain and index, so a restart or a joiner's follow
## costs nothing.

## The cache holds this many islands; older ones go first.
const CACHE_SIZE: int = 8
## The layout meta that holds a generated island's hash, also its art key.
const ART_KEY_META: StringName = &"island_hash"

static var _cache: Dictionary[String, GeneratedIsland] = {}
static var _order: Array[String] = []


## {layout: IslandLayoutData, island_hash: String (empty for a handmade layout), chain: bool}, or
## {} when the id names neither. `chains`, for tests only, replaces a chain's template by id (a
## peer given a tampered copy builds another island).
static func resolve(island_id: StringName, index: int, run_seed: int, catalog: ContentCatalog = null, chains: Dictionary[StringName, ChainData] = {}) -> Dictionary:
	var content: ContentCatalog = catalog if catalog != null else GameState.content
	var handmade := content.get_entry(&"islands", island_id) as IslandLayoutData
	if handmade != null:
		return {"layout": handmade, "island_hash": "", "chain": false}
	var chain: ChainData = chains.get(island_id, content.get_entry(&"chains", island_id) as ChainData)
	if chain == null:
		return {}
	var generated: GeneratedIsland = generated_island(chain, index, run_seed, content)
	return {"layout": generated.layout, "island_hash": generated.island_hash, "chain": true}


## Whether `island_id` names a chain (a generated island).
static func is_chain(island_id: StringName, catalog: ContentCatalog = null) -> bool:
	var content: ContentCatalog = catalog if catalog != null else GameState.content
	return content.get_entry(&"islands", island_id) == null and content.get_entry(&"chains", island_id) is ChainData


## The id that names the island `layout` was built from: its chain for a generated island, its own
## id for a handmade one.
static func source_id(layout: IslandLayoutData) -> StringName:
	if layout == null:
		return &""
	return layout.get_meta(IslandLayoutWriter.CHAIN_META, layout.id)


## The island hash a layout carries; empty for a handmade one.
static func hash_of(layout: IslandLayoutData) -> String:
	if layout == null:
		return ""
	return String(layout.get_meta(ART_KEY_META, &""))


## The key cosmetic variants are drawn from (art-pass): a generated island's hash, so two seeds look
## different and every peer the same; a handmade layout's id.
static func art_key(layout: IslandLayoutData) -> StringName:
	if layout == null:
		return &""
	return layout.get_meta(ART_KEY_META, layout.id)



## The generated island for (`chain`, `index`, `run_seed`), from the cache when it is there.
static func generated_island(chain: ChainData, index: int, run_seed: int, catalog: ContentCatalog) -> GeneratedIsland:
	var key: String = "%d|%s|%d|%d" % [run_seed, chain.id, index, chain.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	var generated: GeneratedIsland = IslandGenerator.generate(run_seed, index, chain, catalog)
	remember(key, generated)
	return generated


## Keeps `generated` under `key`, dropping the oldest island past CACHE_SIZE.
static func remember(key: String, generated: GeneratedIsland) -> void:
	if not _cache.has(key):
		_order.append(key)
	_cache[key] = generated
	while _order.size() > CACHE_SIZE:
		_cache.erase(_order.pop_front())


## Forgets every cached island (the dev playground's regenerate key).
static func clear_cache() -> void:
	_cache.clear()
	_order.clear()


## A well-formed island hash: 64 lowercase hex characters.
static func is_digest(text: String) -> bool:
	if text.length() != 64:
		return false
	for k: int in text.length():
		if not "0123456789abcdef".contains(text[k]):
			return false
	return true
