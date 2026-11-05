class_name SpawnEntryData
extends DataPart
## One weighted placement of an item, item tag, creature or NPC, with respawn and party and
## Experiencia scaling. Embedded in pois (loot, vaults), chains (ambient resources), set_pieces
## and weather loot; CREATURE and NPC only in SetPieceData.spawns. Sources: ISLANDS, GAME_DESIGN 10.

enum Kind {
	ITEM,
	ITEM_TAG,
	CREATURE,
	NPC,
}

## ITEM, ITEM_TAG (a random item with item_tag), CREATURE or NPC (the last two in set pieces only).
@export var kind: Kind = Kind.ITEM
## Item, creature or NPC id, by kind.
@export var ref_id: StringName = &""
## Tag for ITEM_TAG; the item is picked by ItemData.spawn_weight.
@export var item_tag: DataEnums.ItemTag = DataEnums.ItemTag.FOOD
## Min/max count (x = min, y = max).
@export var count: Vector2i = Vector2i(1, 1)
## Chance the entry spawns, 0..1.
@export_range(0.0, 1.0) var chance: float = 1.0
## Infinite harvest; the rate is a rule plus the Pescador modifier.
@export var unlimited: bool = false

@export_group("Conditions")
## Whether or when it spawns (TIDE_IS low, CHAIN_IS storm_resort).
@export var conditions: Array[ConditionData] = []
## Needed to collect it (fish: HAS_CAPABILITY SPEAR_FISH).
@export var harvest_conditions: Array[ConditionData] = []

@export_group("Respawn")
## When it refills.
@export var respawn: DataEnums.RespawnTrigger = DataEnums.RespawnTrigger.NEVER
## Extra units on respawn (driftwood +4 after a squall).
@export var respawn_bonus: int = 0
## Multiplier on respawn; the only home of the wreck field's x3 (WeatherData has no copy).
@export var respawn_multiplier: float = 1.0

@export_group("Scaling")
## Count factor per extra player: 0.8 for resources, 1.0 for unique items.
@export var party_scaling_per_extra_player: float = 1.0
## Extra units per Experiencia level (driftwood and coco: 1).
@export var experiencia_bonus_per_level: int = 0


## ref_id points at items, creatures or npcs depending on kind; ITEM_TAG has no id.
func get_reference_fields() -> Dictionary[StringName, StringName]:
	var folder: StringName = &""
	match kind:
		Kind.ITEM:
			folder = &"items"
		Kind.CREATURE:
			folder = &"creatures"
		Kind.NPC:
			folder = &"npcs"
	if folder.is_empty():
		return {}
	return {&"ref_id": folder}
