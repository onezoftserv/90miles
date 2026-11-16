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
## Seconds captives are held before the boat leaves. Unused: under guardacostas-capture decision 7a
## the squad leaves after search_duration_s and capture_grace_s instead. Kept, because saved data
## never loses a field.
@export var captive_hold_s: float = 0.0
## DialogueData played on a full-party capture (beat_la_captura); its states hold the outcomes.
@export var capture_dialogue_id: StringName = &""
## NpcData id aboard (rodriguez); NpcSpawnRuleData WITH_PATROL reads this field.
@export var commander_npc_id: StringName = &""

@export_group("Loop and light (guardacostas-stealth)")
## Seconds the boat spends on its visible lap (the period is route_period_s + 10 s per Experiencia level).
@export var route_lap_s: float = 0.0
## Tiles the loop keeps from the island's convex hull.
@export var route_offshore_tiles: float = 4.0
## Range in degrees over which the beam's centre swings (+/- half of it) round the island.
@export var searchlight_arc_deg: float = 0.0
## Spot meter seconds gained per second while lit and not hidden.
@export var spot_fill_per_s: float = 1.0
## Spot meter seconds lost per second otherwise.
@export var spot_drain_per_s: float = 0.5

@export_group("Alert (guardacostas-stealth)")
## Seconds an alert lasts with nobody locked.
@export var alert_s: float = 0.0
## Degrees either side of the aim the beam swings while searching.
@export var alert_sweep_deg: float = 0.0
## Loudhailer lines at the start of an alert (formal Spanish, picked by alert_serial mod size).
@export var alert_lines_es: PackedStringArray = PackedStringArray()
## The same lines in English.
@export var alert_lines_en: PackedStringArray = PackedStringArray()
## Loudhailer lines when the boat gives up.
@export var give_up_lines_es: PackedStringArray = PackedStringArray()
## The same lines in English.
@export var give_up_lines_en: PackedStringArray = PackedStringArray()

@export_group("Chase at sea (guardacostas-capture)")
## A chased swimmer within this many tiles of the boat is being hauled aboard.
@export var haul_tiles: float = 1.0
## Seconds within haul_tiles, without a break, that haul a swimmer aboard (a captive).
@export var haul_s: float = 2.0
## The chase breaks when the swimmer is more than this many tiles from the boat.
@export var chase_break_tiles: float = 10.0

@export_group("Squad (guardacostas-capture)")
## Tiles per second the dinghy rows between the boat and the landing beach.
@export var landing_speed_tiles_s: float = 2.0
## Seconds a soldier stands on a search point (a fire or a last known position).
@export var point_search_s: float = 3.0
## A soldier searching a point finds any hidden player within this many tiles of it.
@export var point_search_tiles: float = 2.0
## The squad never leaves sooner than this many seconds after its latest capture.
@export var capture_grace_s: float = 60.0
## The soldiers' sight cone by day: its full width in degrees and its length in tiles.
@export var soldier_day_sight_deg: float = 120.0
@export var soldier_day_sight_tiles: float = 6.0
## Their flashlight at night (the phases the boat's searchlight is on).
@export var soldier_night_sight_deg: float = 60.0
@export var soldier_night_sight_tiles: float = 5.0
## A soldier runs at a spotted player at this many tiles per second (it walks at its speed_tiles_s).
@export var soldier_chase_tiles_s: float = 5.0
## A soldier touching a player within this many tiles for capture_touch_s captures them.
@export var capture_touch_tiles: float = 1.0
## Seconds a free player holds interact on a captive to free them.
@export var free_hold_s: float = 1.0
## The squad's calls (formal Spanish: on duty), picked by the boat's squad_serial mod size, with the
## same lines in English: when it lands, when a soldier spots a player, and when it leaves.
@export var squad_land_lines_es: PackedStringArray = PackedStringArray()
@export var squad_land_lines_en: PackedStringArray = PackedStringArray()
@export var squad_spot_lines_es: PackedStringArray = PackedStringArray()
@export var squad_spot_lines_en: PackedStringArray = PackedStringArray()
@export var squad_leave_lines_es: PackedStringArray = PackedStringArray()
@export var squad_leave_lines_en: PackedStringArray = PackedStringArray()


## True when this patrol lands a squad on a land alert (it names a squad creature and a size). A
## patrol with no squad keeps the stealth slice's plain alert.
func has_squad() -> bool:
	return squad_size > 0 and not squad_creature_id.is_empty()


## The chase speed in tiles per second: chase_speed_mult times the speed chase_speed_ref names (the
## base swim speed for SWIMMER; `own_speed_tiles_s`, the boat's own, otherwise). 0 means no chase.
func chase_speed_tiles_s(own_speed_tiles_s: float) -> float:
	var base: float = MovementModel.SWIM_SPEED if chase_speed_ref == SpeedRef.SWIMMER else own_speed_tiles_s
	return maxf(chase_speed_mult * base, 0.0)


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"squad_creature_id": &"creatures",
		&"capture_dialogue_id": &"dialogue",
		&"commander_npc_id": &"npcs",
	}
