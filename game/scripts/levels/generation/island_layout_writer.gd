class_name IslandLayoutWriter
extends RefCounted
## island-generator design §2: turns a generated grid and its placements into an in-memory
## IslandLayoutData, writes any such layout as one canonical text (its SHA-256 is the island
## hash) and parses that text back, refusing anything the writer would not have written.

const T := DataEnums.Terrain
const LEGEND: String = "legend"
const TERRAIN_GLYPHS: Dictionary[int, String] = {
	T.DEEP: "~", T.SHALLOWS: "-", T.BEACH: ".", T.ROCK: "^", T.SCRUB: ",",
}
const LANDING_GLYPHS: String = "1234"
const RAFT_GLYPH: String = "B"
const PALM_GLYPH: String = "P"
## One glyph per distinct (terrain, shaded, item, units, respawn, group, scaling), in this order.
const POOL: String = "abcdefghijklmnopqrstuvwxyzACDEFGHIJKLMNOQRSTUVWXYZ056789!#$%&*+?@"
const MAX_CELLS: int = 128
## Metadata the layout carries for the text: its chain and the POI whose palms these are.
const CHAIN_META: StringName = &"chain_id"
const CLIMB_META: StringName = &"climb_poi"
const CLIMB_HOLD_S: float = 2.0


## The full alphabet: every glyph the writer may put in a row.
static func alphabet() -> String:
	var glyphs: String = ""
	for glyph: String in TERRAIN_GLYPHS.values():
		glyphs += glyph
	return glyphs + LANDING_GLYPHS + RAFT_GLYPH + PALM_GLYPH + POOL


## The layout of a placed island: id `<chain id>_<index>`, names from the chain, no next island.
static func emit(chain: ChainData, index: int, placer: PoiPlacer, catalog: ContentCatalog) -> IslandLayoutData:
	var grid: IslandGrid = placer.grid
	var marks: Dictionary[int, String] = {}
	for k: int in placer.landing.size():
		marks[grid.index_of(placer.landing[k])] = LANDING_GLYPHS[k]
	if placer.raft_site.x >= 0:
		marks[grid.index_of(placer.raft_site)] = RAFT_GLYPH
	for cell: Vector2i in placer.palms:
		marks[grid.index_of(cell)] = PALM_GLYPH
	var shade: Dictionary[int, bool] = {}
	for cell: Vector2i in placer.shaded:
		shade[grid.index_of(cell)] = true
	var items: Dictionary[int, Dictionary] = {}
	for pickup: Dictionary in placer.pickups:
		items[grid.index_of(pickup["cell"])] = pickup
	var layout := IslandLayoutData.new()
	var glyph_of: Dictionary[String, String] = {}
	var glyph_terrain: Dictionary[String, DataEnums.Terrain] = {}
	for terrain_id: int in TERRAIN_GLYPHS:
		glyph_terrain[TERRAIN_GLYPHS[terrain_id]] = terrain_id as DataEnums.Terrain
	for glyph: String in LANDING_GLYPHS + RAFT_GLYPH + PALM_GLYPH:
		glyph_terrain[glyph] = T.BEACH
	var shade_glyphs: String = ""
	var pickups: Array[IslandGlyphData] = []
	var rows := PackedStringArray()
	for y: int in grid.height:
		var row: String = ""
		for x: int in grid.width:
			var i: int = y * grid.width + x
			if marks.has(i):
				row += marks[i]
				continue
			if not shade.has(i) and not items.has(i):
				row += TERRAIN_GLYPHS[placer.terrain[i]]
				continue
			var pickup: Dictionary = items.get(i, {})
			var key: String = "%d|%d|%s|%d|%d|%s|%.4f" % [
				placer.terrain[i], 1 if shade.has(i) else 0, pickup.get("item_id", &""), pickup.get("count", 0),
				pickup.get("respawn", 0), pickup.get("group", &""), pickup.get("scaling", 1.0),
			]
			if not glyph_of.has(key):
				var glyph: String = POOL[glyph_of.size()]
				glyph_of[key] = glyph
				glyph_terrain[glyph] = placer.terrain[i] as DataEnums.Terrain
				if shade.has(i):
					shade_glyphs += glyph
				if not pickup.is_empty():
					var entry := IslandGlyphData.new()
					entry.glyph = glyph
					entry.item_id = pickup["item_id"]
					entry.count = pickup["count"]
					entry.respawn = pickup["respawn"]
					entry.group = pickup["group"]
					entry.party_scaling_per_extra_player = pickup["scaling"]
					pickups.append(entry)
			row += glyph_of[key]
		rows.append(row)
	layout.id = StringName("%s_%d" % [chain.id, index])
	layout.rows = rows
	layout.terrain_glyphs = glyph_terrain
	layout.shade_glyphs = shade_glyphs
	layout.palm_glyph = PALM_GLYPH if not placer.palms.is_empty() else ""
	layout.coconut_total = placer.coconuts
	layout.solo_spawn_glyph = LANDING_GLYPHS[0]
	layout.coop_spawn_glyphs = LANDING_GLYPHS.substr(0, placer.landing.size())
	layout.raft_site_glyph = RAFT_GLYPH if placer.raft_site.x >= 0 else ""
	layout.route_ids = placer.routes.duplicate()
	layout.pickups = pickups
	layout.chain_family = chain.family
	layout.set_meta(CHAIN_META, chain.id)
	layout.set_meta(CLIMB_META, placer.climb_poi)
	_dress(layout, catalog)
	return layout


# Names, lore and the climb, all read from the chain and the palms' POI.
static func _dress(layout: IslandLayoutData, catalog: ContentCatalog) -> bool:
	var chain := catalog.get_entry(&"chains", layout.get_meta(CHAIN_META, &"")) as ChainData
	if chain == null:
		return false
	layout.name_es = chain.name_es
	layout.name_en = chain.name_en
	layout.description_es = chain.description_es
	layout.description_en = chain.description_en
	layout.next_island = &""
	layout.climb_hold_s = CLIMB_HOLD_S
	var climb_id: StringName = layout.get_meta(CLIMB_META, &"")
	if not climb_id.is_empty():
		var poi := catalog.get_entry(&"pois", climb_id) as PoiData
		if poi == null:
			return false
		layout.climb_effects = poi.harvest_effects
	return true


## The canonical text: the rows, then the legend and every marker field in a fixed order.
static func write(layout: IslandLayoutData) -> String:
	var lines := PackedStringArray(layout.rows)
	lines.append(LEGEND)
	var glyphs: Array[String] = []
	glyphs.assign(layout.terrain_glyphs.keys())
	glyphs.sort()
	for glyph: String in glyphs:
		lines.append("terrain %s %d" % [glyph, layout.terrain_glyphs[glyph]])
	lines.append("shade %s" % layout.shade_glyphs)
	lines.append("palm %s" % layout.palm_glyph)
	lines.append("coconuts %d" % layout.coconut_total)
	lines.append("climb %s" % layout.get_meta(CLIMB_META, &""))
	lines.append("solo %s" % layout.solo_spawn_glyph)
	lines.append("coop %s" % layout.coop_spawn_glyphs)
	lines.append("raft %s" % layout.raft_site_glyph)
	var entries: Array[IslandGlyphData] = layout.pickups.duplicate()
	entries.sort_custom(func(a: IslandGlyphData, b: IslandGlyphData) -> bool: return a.glyph < b.glyph)
	for entry: IslandGlyphData in entries:
		lines.append("pickup %s %s %d %d %s %.4f" % [entry.glyph, entry.item_id, entry.count, entry.respawn, entry.group, entry.party_scaling_per_extra_player])
	lines.append("routes %s" % ",".join(PackedStringArray(layout.route_ids)))
	lines.append("family %d" % layout.chain_family)
	lines.append("chain %s" % layout.get_meta(CHAIN_META, &""))
	lines.append("id %s" % layout.id)
	return "\n".join(lines)


## The island hash: the SHA-256 of the canonical text, 64 lowercase hex characters.
static func digest(layout: IslandLayoutData) -> String:
	return write(layout).sha256_text()


## The layout a canonical text describes, or null when the text is over 128×128 cells, uses a
## glyph outside the writer's alphabet, is malformed, or its legend reads with problems.
static func parse(text: String, catalog: ContentCatalog) -> IslandLayoutData:
	var lines: PackedStringArray = text.split("\n")
	var legend: int = lines.find(LEGEND)
	if legend <= 0 or legend > MAX_CELLS:
		return null
	var allowed: String = alphabet()
	var rows := PackedStringArray()
	for y: int in legend:
		var row: String = lines[y]
		if row.is_empty() or row.length() > MAX_CELLS:
			return null
		for k: int in row.length():
			if not allowed.contains(row[k]):
				return null
		rows.append(row)
	var layout := IslandLayoutData.new()
	layout.rows = rows
	var glyph_terrain: Dictionary[String, DataEnums.Terrain] = {}
	var pickups: Array[IslandGlyphData] = []
	var routes: Array[StringName] = []
	var seen: Dictionary[String, bool] = {}
	for k: int in range(legend + 1, lines.size()):
		var line: String = lines[k]
		var key: String = line.get_slice(" ", 0)
		var value: String = line.substr(key.length() + 1) if line.length() > key.length() else ""
		var parts: PackedStringArray = value.split(" ")
		match key:
			"terrain":
				if parts.size() != 2 or parts[0].length() != 1 or not allowed.contains(parts[0]) or not parts[1].is_valid_int():
					return null
				var terrain_id: int = parts[1].to_int()
				if not TERRAIN_GLYPHS.has(terrain_id):
					return null
				glyph_terrain[parts[0]] = terrain_id as DataEnums.Terrain
			"shade":
				layout.shade_glyphs = value
			"palm":
				layout.palm_glyph = value
			"coconuts":
				if not value.is_valid_int():
					return null
				layout.coconut_total = value.to_int()
			"climb":
				layout.set_meta(CLIMB_META, StringName(value))
			"solo":
				layout.solo_spawn_glyph = value
			"coop":
				layout.coop_spawn_glyphs = value
			"raft":
				layout.raft_site_glyph = value
			"pickup":
				if parts.size() != 6 or not parts[2].is_valid_int() or not parts[3].is_valid_int() or not parts[5].is_valid_float():
					return null
				var entry := IslandGlyphData.new()
				entry.glyph = parts[0]
				entry.item_id = StringName(parts[1])
				entry.count = parts[2].to_int()
				entry.respawn = parts[3].to_int() as DataEnums.RespawnTrigger
				entry.group = StringName(parts[4])
				entry.party_scaling_per_extra_player = parts[5].to_float()
				pickups.append(entry)
			"routes":
				for route_id: String in value.split(",", false):
					routes.append(StringName(route_id))
			"family":
				if not value.is_valid_int():
					return null
				layout.chain_family = value.to_int() as DataEnums.ChainFamily
			"chain":
				layout.set_meta(CHAIN_META, StringName(value))
			"id":
				layout.id = StringName(value)
			_:
				return null
		if key != "terrain" and key != "pickup":
			if seen.has(key):
				return null
			seen[key] = true
	layout.terrain_glyphs = glyph_terrain
	layout.pickups = pickups
	layout.route_ids = routes
	if not _dress(layout, catalog):
		return null
	if not IslandLayout.build(layout).problems().is_empty():
		return null
	return layout
