class_name ChainData
extends ContentData
## One playable island layout (a chain variant): family, band, run slot, landmass and layout
## rule, POI and route tables, boss, hazards, ambient items, texts and the crossing out.
## Files live in game/resources/chains/. Sources: ISLANDS, island-generation and crossing specs.
## Creature lists, weather weights and NPC exclusions live on the spawn rules and WeatherData.

## Fixed position of the chain in a run.
enum RunSlot {
	BRANCH,
	FIRST,
	SECOND,
	LAST,
}

## Generator painter (code) that builds the layout.
enum LayoutRule {
	CRESCENT,
	TWIN_BARS,
	BUNKER_POINT,
	VILLAGE,
	MANGROVE_MAZE,
	RIVER_MOUTH,
	REEF_RING,
	BLUE_HOLE,
	BIRD_CLIFFS,
	QUARRY,
	LIGHTHOUSE_ISLAND,
	DUNE_KEY,
	RESORT,
	FREIGHTER,
	YACHT_FLAT,
	TIDAL_SANDBAR,
	BUOY,
}

## Where the chain's boss is fought.
enum BossStage {
	NONE,
	ISLAND,
	CROSSING_OUT,
}

## Scripted events on the crossing out of this chain.
enum CrossingEvent {
	SHARK_PASS,
	SQUALL_LINE,
	SEARCHLIGHT,
	CUTTER_CHASE,
	TIGER_SHARK,
	LIGHTHOUSE_BEAM,
	MIAMI_FISHERMAN,
	LAST_PATROL,
}

@export_group("Text")
## Lore for the arrival card.
@export_multiline var description_es: String = ""
## English lore for the arrival card.
@export_multiline var description_en: String = ""

@export_group("Run")
## Chain family shared by both variants; used by the run graph, filters and carry-over.
@export var family: DataEnums.ChainFamily = DataEnums.ChainFamily.SANDBAR
## Weight when picking a variant of the family.
@export var variant_weight: float = 1.0
## Distance band of the chain.
@export var distance_band: DataEnums.DistanceBand = DataEnums.DistanceBand.MID
## FIRST (sandbar), SECOND (coast), LAST (final) or BRANCH.
@export var fixed_slot: RunSlot = RunSlot.BRANCH

@export_group("Layout")
## Generator painter (code).
@export var layout_rule: LayoutRule = LayoutRule.CRESCENT
## Tileset used to paint the island (asset).
@export var tileset: TileSet = null
## Min/max land share of the 96×64 grid (0..1).
@export var land_fraction: Vector2 = Vector2(0.2, 0.4)
## Separate land bodies (twin bars 2, buoy 0).
@export var landmass_count: int = 1
## Max distance in tiles from any land tile to water; 0 means no limit (sandbar 6).
@export var max_inland_distance_tiles: int = 0
## Min/max width of the shallows band, in tiles.
@export var shallows_width_tiles: Vector2i = Vector2i(1, 2)
## Min/max width of the beach band, in tiles.
@export var beach_width_tiles: Vector2i = Vector2i(2, 4)
## Interior terrain -> share of the land (0..1).
@export var biome_weights: Dictionary[DataEnums.Terrain, float] = {}
## Terrain features the layout must carve.
@export var terrain_features: Array[DataEnums.TerrainFeature] = []
## Land exists only at low tide.
@export var submerged_at_high_tide: bool = false
## Forced departure after this many seconds; 0 means none (final 360 = one tide).
@export var time_limit_s: float = 0.0
## Min/max arrival spacing between players, in tiles (replaces the 'Scattered landing' POI).
@export var spawn_scatter_tiles: Vector2i = Vector2i(0, 5)
## Players may start on different landmasses.
@export var spawn_split_across_landmasses: bool = false

@export_group("Generation")
## Columns and rows of the generated grid.
@export var grid_size: Vector2i = Vector2i(96, 64)
## Tiles along every edge that stay water.
@export var edge_margin_tiles: int = 8
## Min/max land cells; (0, 0) means land_fraction alone bounds the land.
@export var land_cells: Vector2i = Vector2i.ZERO
## The shore band's terrain away from the lee.
@export var shore_terrain: DataEnums.Terrain = DataEnums.Terrain.BEACH
## The shore band's terrain on the lee coast.
@export var lee_terrain: DataEnums.Terrain = DataEnums.Terrain.BEACH
## Outward direction of the lee coast (west is (-1, 0)).
@export var lee_facing: Vector2i = Vector2i(-1, 0)
## Painter parameters: spine length in tiles (min, max).
@export var shape_length_tiles: Vector2i = Vector2i(40, 60)
## Painter parameters: total bend of the spine in degrees (min, max).
@export var shape_bend_degrees: Vector2i = Vector2i(0, 60)
## Painter parameters: half-width of the land round the spine in tiles (min, max).
@export var shape_half_width_tiles: Vector2i = Vector2i(6, 10)
## Beach cells where arrivals land.
@export var landing_cell_count: int = 4
## Largest distance in tiles between any two landing cells.
@export var landing_spread_tiles: int = 5
## Seconds a lone arrival walks to the raft site (min, max).
@export var raft_site_walk_s: Vector2 = Vector2(0.5, 3.0)
## Seconds a lone arrival walks to the farthest land (min, max).
@export var far_end_walk_s: Vector2 = Vector2(0.0, 60.0)
## POI id -> seconds a lone arrival walks to its anchor (min, max).
@export var poi_walk_s: Dictionary[StringName, Vector2] = {}
## Attempts before the fallback island.
@export var max_attempts: int = 50
## The last attempts that skip rolled POIs.
@export var relaxed_attempts: int = 5
## Run seed of the fallback island (index 0).
@export var fallback_seed: int = 0

@export_group("POIs")
## Min/max POIs placed, including forced route starters and NPC camps.
@export var poi_count: Vector2i = Vector2i(3, 6)
## POI id -> inclusion chance (0..1). Excludes NPC camps and route starters, which are forced in.
@export var poi_chances: Dictionary[StringName, float] = {}
## POI ids always placed.
@export var guaranteed_poi_ids: Array[StringName] = []
## POI id of the variant's signature; also guaranteed.
@export var signature_poi_id: StringName = &""

@export_group("Routes")
## Min/max escape routes exposed.
@export var route_count: Vector2i = Vector2i(2, 3)
## Allowed routes with per-chain overrides.
@export var routes: Array[ChainRouteEntryData] = []

@export_group("Threats")
## Chance (0..1) of one set piece on the island (TBD).
@export var set_piece_chance: float = 0.5
## Min/max creature types rolled from the creatures whose spawn rules match this chain.
@export var creature_types_per_island: Vector2i = Vector2i(3, 5)
## Creature id of the chain's single boss.
@export var boss_id: StringName = &""
## ISLAND or CROSSING_OUT; NONE when the chain has no boss.
@export var boss_stage: BossStage = BossStage.NONE
## Island-wide environmental hazards.
@export var hazards: Array[DataEnums.EnvHazard] = []

@export_group("Resources")
## Items placed outside POIs (night crabs are a creature rule).
@export var ambient_resources: Array[SpawnEntryData] = []
## Min/max bottle notes on the beaches.
@export var bottle_note_count: Vector2i = Vector2i(1, 3)
## Important texts picked from the POI loot.
@export var important_text_count: int = 1

@export_group("Crossing out")
## Scripted events on the crossing out, in spec order.
@export var crossing_events: Array[CrossingEvent] = []
## Gulf Stream push east on the crossing out, in tiles/s.
@export var current_push_tiles_per_s: float = 0.0

@export_group("Arrival")
## Run flags set on arrival (flag names, not content ids).
@export var flags_on_enter: Array[StringName] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"poi_chances": &"pois",
		&"guaranteed_poi_ids": &"pois",
		&"signature_poi_id": &"pois",
		&"boss_id": &"creatures",
		&"poi_walk_s": &"pois",
	}
