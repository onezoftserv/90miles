class_name ItemData
extends ContentData
## Every inventory item, one .tres per id in game/resources/items/ (KeepsakeData and TextData
## extend it and live in the same folder). Holds identity, inventory rules, uses, equipment,
## weapon, fishing, container, identification and cooking. Where items come from is stored on
## the sources (POIs, chains, creatures, recipes...). Sources: ITEMS.md, crafting-inventory spec.

## Manifest line, used for UI sorting. KEEPSAKE only for KeepsakeData, TEXT only for TextData.
enum Category {
	WATER,
	FOOD,
	PLANT,
	TOOL,
	MATERIAL,
	WEARABLE,
	ODDITY,
	KEEPSAKE,
	TEXT,
}

## Body slot an item is worn in. NONE means it works while carried.
enum EquipSlot {
	NONE,
	HEAD,
	FACE,
	BODY,
	VEST,
	HANDS,
	FEET,
	WAIST,
}

## Attack style.
enum WeaponClass {
	NONE,
	BLADE,
	SPEAR,
	THROWN,
}

## What happens to a thrown item.
enum ThrowMode {
	NONE,
	LANDS,
	CONSUMED,
}

## Look pool for the identify game.
enum IdentifyGroup {
	NONE,
	FRUTA,
	HONGO,
	HIERBA,
}

## Spanish notes or lore; hidden while the item is unidentified.
@export_multiline var description_es: String = ""
## English notes or lore.
@export_multiline var description_en: String = ""
## 16x16 icon. Unidentified plants show the run's random look instead.
@export var sprite: Texture2D = null
## Manifest category (KEEPSAKE if and only if KeepsakeData, TEXT if and only if TextData).
@export var category: Category = Category.MATERIAL
## Tags other systems read (SHINY: barracuda, FOOD: theft, MEAT: dogs, UNKNOWN iff identify_group != NONE).
@export var tags: Array[DataEnums.ItemTag] = []

@export_group("Inventory")
## Max units per inventory slot (12 slots).
@export var stack_size: int = 1
## Weight against the carry limit of 30; above 15 while swimming, energy drains x2.
@export var weight: float = 1.0
## Weight when an ITEM_TAG spawn picks among tagged items. A SECRET item keeps 0 (the content
## validator rejects more), so no spawn can draw it (secret-cay).
@export var spawn_weight: float = 1.0
## Above 0, the item lies concealed on the ground until a player comes within this many tiles,
## and picking it up takes the secret tuning's hold (secret-cay "Concealment"). 0: an ordinary item.
@export var conceal_radius_tiles: float = 0.0
## false: used or read where it stands, or opened only by an effect (wall_slogan, la_lista).
@export var can_pick_up: bool = true
## Uses or servings; the item is removed at 0. 0 means no counter (unbreakable or a material).
@export var durability: int = 0
## Item id added when the last use is spent (conch -> shell horn).
@export var remainder_item_id: StringName = &""

@export_group("Uses and Effects")
## Player actions; the first is primary. Empty for texts (reading is built into TextData).
@export var uses: Array[ItemUseData] = []
## Applied when taken from the world (guao touch, oyster cuts); item harm lives here, not on POIs.
@export var pickup_effects: Array[EffectData] = []
## Applied to the creature hit (target USE_TARGET).
@export var hit_effects: Array[EffectData] = []

@export_group("Equipment")
## With a slot, capabilities and modifiers apply only while equipped; NONE: while carried.
@export var equip_slot: EquipSlot = EquipSlot.NONE
## What holding the item enables. Recipes, uses and routes ask for capabilities, not item ids.
@export var capabilities: Array[DataEnums.Capability] = []
## Seconds when used as a recipe fast_tool; -1 means the recipe's own time.
@export var tool_action_time_s: float = -1.0
## Passive stat changes.
@export var modifiers: Array[ModifierData] = []
## WeatherData ids that knock the equipped item off (straw hat in squalls).
@export var drops_in_weather_ids: Array[StringName] = []
## Sharks treat the carrier as BLEEDING.
@export var blood_scent_when_carried: bool = false

@export_group("Weapon")
## Attack style; THROWN gets Yusnavy's THROWN_DAMAGE bonus.
@export var weapon_class: WeaponClass = WeaponClass.NONE
## Damage per hit.
@export var weapon_damage: float = 0.0
## Melee reach in tiles (spear 2).
@export var weapon_reach_tiles: float = 1.0
## LANDS (becomes a pickup) or CONSUMED (the fish decoy).
@export var throw_mode: ThrowMode = ThrowMode.NONE

@export_group("Fishing and Traps")
## Fish caught per cast with a fishing capability.
@export var catch_per_use: int = 1
## Creature ids a placed trap catches overnight; it yields their loot. Only stored here.
@export var trap_catches: Array[StringName] = []

@export_group("Container")
## Units the container holds.
@export var container_slots: int = 0
## Item tags allowed inside.
@export var container_accepts_tags: Array[DataEnums.ItemTag] = []
## Contents are safe from theft.
@export var container_sealed: bool = false

@export_group("Identification")
## Look pool for the identify game; NONE means always known.
@export var identify_group: IdentifyGroup = IdentifyGroup.NONE
## Forces one look id (manzanillo: fruta_verde) instead of the random per-run look.
@export var fixed_unknown_look: StringName = &""
## Extra background ids that identify it on sight (the Medico's rule is Perk.IDENTIFIES_UNKNOWN_PLANTS).
@export var identified_on_sight_by: Array[StringName] = []

@export_group("Cooking")
## Item id it becomes at a fire.
@export var cooks_into: StringName = &""
## Seconds at a fire.
@export var cook_time_s: float = 0.0


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"remainder_item_id": &"items",
		&"drops_in_weather_ids": &"weather",
		&"trap_catches": &"creatures",
		&"identified_on_sight_by": &"backgrounds",
		&"cooks_into": &"items",
	}
