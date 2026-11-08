class_name CreatureSpawnRuleData
extends DataPart
## One placement rule in CreatureData.spawn_rules: the creature spawns if ANY rule matches,
## and each rule is an AND of its non-empty filters. Location passes if chain_families and
## chain_ids are both empty, or the island's family or variant id is listed.
## Sources: creatures-ai spawn rules, BESTIARY "Chain" column, ISLANDS variants.

## What the members are tied to. Enum values are saved as ints: append only.
enum Anchor {
	NONE,
	NEST_PALM,
}

@export_group("Location")
## ISLAND for the island generator, CROSSING for the crossing threat roll.
@export var context: DataEnums.SceneContext = DataEnums.SceneContext.ISLAND
## Chain families allowed; for CROSSING, the departing chain's family.
@export var chain_families: Array[DataEnums.ChainFamily] = []
## ChainData variant ids allowed, OR-ed with chain_families (variant threat mixes).
@export var chain_ids: Array[StringName] = []
## Distance bands allowed; empty means any band.
@export var distance_bands: Array[DataEnums.DistanceBand] = []

@export_group("Time and weather")
## Day phases when the rule fires; empty means any.
@export var phases: Array[DataEnums.DayPhase] = []
## Required WeatherData ids (remora: sargassum).
@export var weather_ids: Array[StringName] = []
## WeatherData ids that block the rule (squall: patrols stay in port).
@export var excluded_weather_ids: Array[StringName] = []
## Tide required.
@export var tide: DataEnums.Tide = DataEnums.Tide.ANY

@export_group("Placement")
## Spawn tile terrain; empty means any tile in the creature's domains.
@export var terrain: Array[DataEnums.Terrain] = []
## Anchor at one of these PoiData ids (the only place creatures are tied to POIs).
@export var poi_ids: Array[StringName] = []
## Limits the creature to one island feature (mangrove patrols: SAND_SPIT).
@export var zone_feature: DataEnums.TerrainFeature = DataEnums.TerrainFeature.NONE
## true means `count` is per beach (a 4-connected group of at least 8 beach cells), not per island.
@export var per_beach: bool = false
## NEST_PALM puts `count` members at each of the island's nest palms (IslandLayoutData.nest_palms).
@export var anchor: Anchor = Anchor.NONE

@export_group("Roll")
## Min/max group size, or tiles for a hazard cluster.
@export var count: Vector2i = Vector2i(1, 1)
## Members spawn within this radius in tiles; 0 means scattered.
@export var group_radius_tiles: float = 0.0
## Chance (0..1) the rule fires per island or crossing.
@export_range(0.0, 1.0) var chance: float = 1.0
## Minimum distance from the shoreline, in tiles.
@export var min_shore_distance_tiles: int = 0
## false means it spawns but ignores players (lighthouse dawn patrol).
@export var hostile: bool = true


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"chain_ids": &"chains",
		&"weather_ids": &"weather",
		&"excluded_weather_ids": &"weather",
		&"poi_ids": &"pois",
	}
