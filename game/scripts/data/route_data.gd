class_name RouteData
extends ContentData
## One escape-route type: party and rider requirements, capacity, default starter, discovery,
## start effects and the crossing risk profile the crossing scene reads. Files live in
## game/resources/routes/; chains tune them per chain with ChainRouteEntryData.
## Sources: GAME_DESIGN §7, escape-routes and crossing specs.

## How many riders the route takes.
enum CapacityMode {
	ALL,
	FIXED,
	PER_SWIMMER,
	VESSEL,
}

## What starts the route; decides which content type starter_id points at.
enum StarterKind {
	BUILD_SITE,
	POI,
	NPC,
	ITEM_USE,
}

## Crossing events that throw the riders into the water.
enum DumpTrigger {
	SEARCHLIGHT,
	SHARK_ATTACK,
	SQUALL,
}

@export_group("Text")
## Risk and needs blurb.
@export_multiline var description_es: String = ""
## English risk and needs blurb.
@export_multiline var description_en: String = ""

@export_group("Requirements")
## Party-level conditions (AND; OR via ANY_OF).
@export var requirements: Array[ConditionData] = []
## Checked for every boarding rider (scope EACH_RIDER).
@export var rider_requirements: Array[ConditionData] = []
## ALL, FIXED, PER_SWIMMER, or VESSEL (as many as the raft carries).
@export var capacity_mode: CapacityMode = CapacityMode.ALL
## Seats when capacity_mode is FIXED.
@export var capacity: int = 0

@export_group("Starter")
## What starts it: BUILD_SITE (recipe), POI, NPC or ITEM_USE (item).
@export var starter_kind: StarterKind = StarterKind.BUILD_SITE
## Default starter id (recipe, POI, NPC or item by starter_kind); chains may override it.
@export var starter_id: StringName = &""
## Known without discovery (raft).
@export var starts_discovered: bool = false
## Seen within this distance of the starter, in tiles (TBD).
@export var reveal_radius_tiles: int = 8
## Effects applied when the route starts.
@export var on_start_effects: Array[EffectData] = []

@export_group("Vessel")
## Vessel used in the crossing.
@export var vessel: DataEnums.Vessel = DataEnums.Vessel.RAFT
## Integrity of a provided vessel (repaired boat 200); crafted ones use RecipeData. 0 means none.
@export var vessel_integrity: int = 100
## The vessel is beached with its integrity; false for borrowed vessels and swimmers.
@export var vessel_kept_on_arrival: bool = true

@export_group("Crossing")
## Min/max base crossing length, in seconds.
@export var duration_s: Vector2 = Vector2(60, 120)
## Scroll speed factor.
@export var speed_multiplier: float = 1.0
## Threat roll factor.
@export var threat_multiplier: float = 1.0
## Shark spawn factor.
@export var shark_multiplier: float = 1.0
## Scales the squall integrity hit.
@export var squall_damage_multiplier: float = 1.0
## Drift factor.
@export var drift_multiplier: float = 1.0
## Drift in tiles that skips the party to a harder chain.
@export var overshoot_tiles: int = 40
## Riders are in the water for the whole crossing.
@export var riders_swim: bool = false
## Scales the 3/s swim energy drain during this crossing (TBD).
@export var swim_drain_multiplier: float = 1.0
## Events that throw the riders into the water.
@export var dump_triggers: Array[DumpTrigger] = []

@export_group("Outcome")
## Chance (0..1) that the carrier actually takes the party.
@export var success_chance: float = 1.0
## Chance (0..1) that starting the route alerts patrols.
@export var patrol_alert_chance: float = 0.0


func get_reference_fields() -> Dictionary[StringName, StringName]:
	match starter_kind:
		StarterKind.BUILD_SITE:
			return {&"starter_id": &"recipes"}
		StarterKind.POI:
			return {&"starter_id": &"pois"}
		StarterKind.NPC:
			return {&"starter_id": &"npcs"}
		StarterKind.ITEM_USE:
			return {&"starter_id": &"items"}
	return {}
