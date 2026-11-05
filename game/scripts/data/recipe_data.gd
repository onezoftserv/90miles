class_name RecipeData
extends ContentData
## One craftable thing, one .tres per id in game/resources/recipes/: inputs, tools, station,
## shared build site, time, skill and output. Non-item outputs (structure, vessel, upgrade) are
## named by the recipe id (scene game/scenes/structures/<id>.tscn). NPC-only crafts live here.
## Sources: crafting-inventory spec, GAME_DESIGN.md section 6, ITEMS.md.

## Where the craft happens.
enum Station {
	NONE,
	WORKBENCH,
	FIRE,
}

## What the recipe produces.
enum OutputKind {
	ITEM,
	STRUCTURE,
	VESSEL,
	VESSEL_UPGRADE,
	VESSEL_REPAIR,
}

## Who can craft it.
enum Availability {
	KNOWN,
	TAUGHT_BY_NPC,
	NPC_CRAFTS,
}

## Spanish description.
@export_multiline var description_es: String = ""
## English description.
@export_multiline var description_en: String = ""
## Craft-list icon; may be null for ITEM outputs (the UI uses the output's sprite).
@export var icon: Texture2D = null

@export_group("Inputs and Tools")
## Item id -> count consumed. For items with durability > 1 the count spends uses.
@export var inputs: Dictionary[StringName, int] = {}
## Item tag -> count of any items with that tag, consumed the same way (fire: TINDER 1).
@export var input_tags: Dictionary[DataEnums.ItemTag, int] = {}
## Capabilities the crafter must carry; never consumed.
@export var tools: Array[DataEnums.Capability] = []
## Durability each required tool loses per craft.
@export var tool_wear: int = 1
## Optional speed-up: time becomes that item's tool_action_time_s and it spends 1 use.
@export var fast_tool: DataEnums.Capability = DataEnums.Capability.NONE
## VESSEL_UPGRADE recipe ids the target vessel must already have (sail needs mast).
@export var requires_upgrade_ids: Array[StringName] = []

@export_group("Crafting")
## NONE (placed in the world), WORKBENCH or FIRE.
@export var station: Station = Station.WORKBENCH
## Places a shared build site: anyone deposits, progress is shared, advances only while someone works.
@export var build_site: bool = false
## Work seconds at base speed.
@export var time_s: float = 0.0
## Skill that speeds the craft and earns XP.
@export var skill: DataEnums.Skill = DataEnums.Skill.NONE
## Speed multiplier when the crafter's background skill matches skill.
@export var skill_speed_multiplier: float = 1.0
## Skill XP on completion.
@export var skill_xp: int = 0
## Terrains where a STRUCTURE or VESSEL may be placed; empty means any land.
@export var placement_terrain: Array[DataEnums.Terrain] = []

@export_group("Output")
## ITEM, STRUCTURE, VESSEL, VESSEL_UPGRADE or VESSEL_REPAIR.
@export var output_kind: OutputKind = OutputKind.ITEM
## Item id produced; ITEM outputs only.
@export var output_item_id: StringName = &""
## Units produced for ITEM outputs.
@export var output_count: int = 1
## VESSEL: max and starting integrity (raft 100); overrides RouteData.vessel_integrity.
@export var vessel_integrity: float = 0.0
## VESSEL_UPGRADE: bonus to max integrity. VESSEL_REPAIR: integrity restored.
@export var integrity_delta: float = 0.0

@export_group("Structure Yield")
## Item id a STRUCTURE yields (solar still: still_cup).
@export var produces_item_id: StringName = &""
## Units per yield.
@export var produce_count: int = 0
## In-game hours between yields (1 h = 30 s real time); 0 means no timed yield.
@export var produce_every_game_hours: float = 0.0
## WeatherData id that triggers one yield (rain catcher: squall).
@export var produce_on_weather_id: StringName = &""

@export_group("Availability")
## KNOWN, TAUGHT_BY_NPC (kept by carry-over) or NPC_CRAFTS (only that companion crafts it).
@export var availability: Availability = Availability.KNOWN
## NPC id who teaches or crafts it.
@export var npc_id: StringName = &""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"inputs": &"items",
		&"requires_upgrade_ids": &"recipes",
		&"output_item_id": &"items",
		&"produces_item_id": &"items",
		&"produce_on_weather_id": &"weather",
		&"npc_id": &"npcs",
	}
