class_name PoiData
extends ContentData
## One point-of-interest type placed by the island generator: placement rule, loot and vault,
## water service, features, vantage and gates. Files live in game/resources/pois/; the id is
## the 'kind' for the no-duplicates rule. Sources: ISLANDS POI tables, island-generation spec.
## Creature and NPC spawns live on CreatureSpawnRuleData.poi_ids and NpcSpawnRuleData.poi_id.

## Map icon family.
enum Category {
	RESOURCE,
	WATER,
	SHELTER,
	NPC_CAMP,
	WRECK,
	LANDMARK,
}

## How a water source refills.
enum WaterRefill {
	NONE,
	CONTINUOUS,
	DAILY,
	RAIN,
}

## Services a POI offers.
enum Feature {
	WORKBENCH,
	SHADE,
	STRUCTURE,
	HIDING_SPOT,
	PATROL_SAFE,
	DRY_CAMPSITE,
	BED,
	STORM_SHELTER,
	SEALED_STORAGE,
	RAFT_BUILD_SITE,
	MOORING,
	FISHING_SPOT,
}

## What can be spotted from the POI.
enum Vantage {
	NONE,
	NEXT_ISLAND,
	ALL_CHAIN_ISLANDS,
}

@export_group("Text")
## Tooltip text.
@export_multiline var description_es: String = ""
## English tooltip text.
@export_multiline var description_en: String = ""

@export_group("Placement")
## Map icon family.
@export var category: Category = Category.RESOURCE
## Where the generator may place it.
@export var placement: DataEnums.Placement = DataEnums.Placement.ANY_LAND
## Must touch navigable water (boats, wrecks).
@export var needs_shoreline_access: bool = false
## Island features that must exist for it to be placed.
@export var required_terrain: Array[DataEnums.TerrainFeature] = []
## Minimum distance to other POIs, in tiles.
@export var min_distance_tiles: int = 12
## Repeated objects inside (6 palms, 6 lobster traps, 3 rock bowls).
@export var object_count: int = 1

@export_group("Look")
## Prefab with the component objects (asset).
@export var scene: PackedScene = null
## Map-knowledge icon (asset).
@export var map_icon: Texture2D = null

@export_group("Access")
## Tide needed to use it.
@export var tide_access: DataEnums.Tide = DataEnums.Tide.ANY
## The POI stays hidden until these pass (Navigation ≥1 to notice).
@export var notice_conditions: Array[ConditionData] = []
## Needed for the main service (lamp needs kerosene, pump broken).
@export var use_conditions: Array[ConditionData] = []

@export_group("Loot")
## Items, tags and texts placed or harvestable here; the only home of text placement.
@export var loot: Array[SpawnEntryData] = []
## Vault entries: taking vault_pick_count of them locks the rest.
@export var vault_loot: Array[SpawnEntryData] = []
## How many vault entries may be taken.
@export var vault_pick_count: int = 0
## Dives needed to recover the loot; 0 means no diving.
@export var dive_count: int = 0
## Costs that belong to the place (palm climbing energy); item harm stays on ItemData.
@export var harvest_effects: Array[EffectData] = []

@export_group("Water")
## Item id drawn per cup; empty means no water.
@export var water_item_id: StringName = &""
## Cups held; 0 with a water item means unlimited.
@export var water_capacity_cups: int = 0
## How the water refills.
@export var water_refill: WaterRefill = WaterRefill.NONE
## Cups added per refill.
@export var water_refill_cups: int = 0
## Seconds to draw one cup.
@export var seconds_per_cup: float = 0.0
## The water must be boiled before drinking.
@export var water_needs_boiling: bool = false

@export_group("Services")
## Services offered; STORM_SHELTER is the only home of hurricane shelter.
@export var features: Array[Feature] = []
## What can be spotted from it.
@export var vantage: Vantage = Vantage.NONE
## Scales noise made inside (cave echoes ×2).
@export var noise_multiplier: float = 1.0
## Effects of the main interaction (a bed costs a day and restores everything).
@export var interact_effects: Array[EffectData] = []
## Local environmental hazards (reef_flats RIP_CURRENT).
@export var hazards: Array[DataEnums.EnvHazard] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"water_item_id": &"items",
	}
