class_name PatrolData
extends DataPart
## Guardacostas parameters (loop, searchlight, spotting, chase, squad, search, capture).
## Embedded in CreatureData.patrol on PATROL-tagged creatures; where patrols spawn is
## CreatureSpawnRuleData. Sources: guardacostas-stealth spec, BESTIARY patrol entries.

## What chase_speed_mult multiplies.
enum SpeedRef {
	SELF,
	SWIMMER,
	VESSEL,
}

## One step of the squad's search priority.
enum SearchTarget {
	FIRE,
	LAST_KNOWN_POSITION,
	RANDOM_WALK,
}

@export_group("Route")
## Loop period in seconds before Experiencia (code adds +10 s per level); 0 means no loop.
@export var route_period_s: float = 0.0
## Seconds it is visible on the horizon before passing.
@export var horizon_warning_s: float = 0.0

@export_group("Spotting")
## Seconds an unhidden player must stay seen to be spotted (Stealth adds time player-side).
@export var spot_time_s: float = 2.0
## Searchlight cone angle in degrees; 0 means no searchlight.
@export var searchlight_cone_deg: float = 0.0
## Searchlight cone length in tiles.
@export var searchlight_range_tiles: float = 0.0
## Searchlight sweep speed in degrees/s.
@export var searchlight_sweep_deg_s: float = 0.0
## Day phases when the searchlight is on.
@export var searchlight_phases: Array[DataEnums.DayPhase] = []
## A swimmer within this radius in tiles is spotted.
@export var water_spot_radius_tiles: float = 0.0
## Spots the vessel automatically after this many seconds of the crossing; 0 means off.
@export var auto_spot_after_s: float = 0.0
## A night fire within this many tiles of open shore raises a smoke alert.
@export var smoke_shore_tiles_night: float = 2.0
## A day fire within this many tiles of the shoreline raises a smoke alert.
@export var smoke_shore_tiles_day: float = 6.0
## Shore noise events with at least this radius in tiles raise an alert.
@export var noise_alert_min_radius_tiles: float = 8.0

@export_group("Chase")
## Multiplier applied to the speed chase_speed_ref names (2.0 = twice swim speed).
@export var chase_speed_mult: float = 1.0
## Which speed chase_speed_mult applies to.
@export var chase_speed_ref: SpeedRef = SpeedRef.SELF

@export_group("Squad and search")
## CreatureData id landed when the party is spotted on land (shore_soldier).
@export var squad_creature_id: StringName = &""
## Squad members landed.
@export var squad_size: int = 0
## How long the squad searches, in seconds.
@export var search_duration_s: float = 0.0
## Search priority, in order.
@export var search_order: Array[SearchTarget] = []

@export_group("Capture")
## Continuous touch time in seconds needed to capture a player.
@export var capture_touch_s: float = 0.0
## A captive can be freed only when no guard is within this radius in tiles.
@export var free_guard_radius_tiles: float = 0.0
## Seconds captives are held before the boat leaves.
@export var captive_hold_s: float = 0.0
## DialogueData played on a full-party capture (beat_la_captura); its states hold the outcomes.
@export var capture_dialogue_id: StringName = &""
## NpcData id aboard (rodriguez); NpcSpawnRuleData WITH_PATROL reads this field.
@export var commander_npc_id: StringName = &""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"squad_creature_id": &"creatures",
		&"capture_dialogue_id": &"dialogue",
		&"commander_npc_id": &"npcs",
	}
