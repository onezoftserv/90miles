class_name CompanionData
extends DataPart
## Party-member block embedded in NpcData.companion: simplified meters, movement limits, seats,
## vessel whitelist, passive modifiers, background stand-in, abilities and statuses.
## Companion-only crafts are RecipeData.npc_id. See npcs-dialogue Companions, CHARACTERS.

## Who the companion follows.
enum FollowMode {
	NEAREST_PLAYER,
	FIRST_FEEDER,
}

## Abilities that components interpret.
enum Ability {
	ROPE_THROW,
	REVEAL_ROUTES_ON_ARRIVAL,
	PREDICT_PATROL_LOOP,
}

@export_group("Meters")
## Who it follows (Yunior: whoever feeds him first).
@export var follow_mode: FollowMode = FollowMode.NEAREST_PLAYER
## Simplified thirst and health meters; false for vieja_turtle.
@export var has_meters: bool = true
## Health cap.
@export var max_health: float = 100.0
## Thirst drain factor (Marisol x1.5, Tomas x1.3).
@export var thirst_drain_mult: float = 1.0
## Share of a normal ration (Yunior 0.5).
@export var consumption_mult: float = 1.0

@export_group("Movement")
## Base walk speed factor (Tomas 0.5).
@export var walk_speed_mult: float = 1.0
## false for alfredo.
@export var can_run: bool = true
## false also rules out the SWIMMERS and DOLPHIN_POD vessels.
@export var can_swim: bool = true
## Longest swim in tiles; -1 means unlimited.
@export var max_swim_tiles: int = -1
## false for marisol.
@export var can_climb: bool = true

@export_group("Crossing")
## Route capacity used (yunior 0).
@export var seats: int = 1
## Vessels it may cross on; empty means any its movement allows.
@export var allowed_vessels: Array[DataEnums.Vessel] = []

@export_group("Skills")
## Passive skill effects while in the party and alive.
@export var modifiers: Array[ModifierData] = []
## Counts as these background ids for BACKGROUND_PRESENT (party scope) and grants their perks.
@export var acts_as_background_ids: Array[StringName] = []
## Abilities that components interpret.
@export var abilities: Array[Ability] = []
## Range in tiles for ROPE_THROW.
@export var ability_range_tiles: float = 0.0

@export_group("Statuses")
## Local status ids (from statuses) active when met.
@export var initial_status_ids: Array[StringName] = []
## Definitions of the statuses it can have.
@export var statuses: Array[CompanionStatusData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {&"acts_as_background_ids": &"backgrounds"}
