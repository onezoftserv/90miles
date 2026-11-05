class_name WeatherData
extends ContentData
## One sky state, multi-day island modifier or weather hazard, rolled or scripted by
## WeatherManager and the crossing; components read its typed effect fields. It owns the
## per-family roll weights, so a new weather is one file in game/resources/weather/.
## Sources: GAME_DESIGN §5, BESTIARY weather events, weather-daynight spec.

## STATE (the one sky state), MODIFIER (overlay) or HAZARD (spawned).
enum Kind {
	STATE,
	MODIFIER,
	HAZARD,
}

## How the weather starts.
enum Trigger {
	PHASE_ROLL,
	SCRIPTED,
	CHANCE,
	DURING_STATE,
}

## What the chance is rolled per.
enum ChanceScope {
	PER_RUN,
	PER_ISLAND_VISIT,
	PER_CROSSING,
	PER_PHASE,
	PER_PARENT_STATE,
}

## Warning cue shown before it starts.
enum Tell {
	NONE,
	WHITE_SKY,
	PALMS_LEAN,
	HORIZON_LINE,
	GRAY_EDGES,
	NPC_WARNING,
	WARNING_MARKER,
	SMELL,
}

## How binoculars work in this weather.
enum Optics {
	CLEAR,
	GLARE,
	BLOCKED,
}

## Behavior of a spawned weather hazard.
enum Hazard {
	NONE,
	MOVING_COLUMN,
	FLOATING_MAT,
	STRIKE_TALLEST,
}

@export_group("Text")
## Effect text.
@export_multiline var description_es: String = ""
## English effect text.
@export_multiline var description_en: String = ""
## Counter hint (same name as in CreatureData).
@export var hint_es: String = ""
## English counter hint, e.g. 'Tie down (rope), beach the raft'.
@export var hint_en: String = ""

@export_group("Kind")
## STATE (the one sky state), MODIFIER (overlay) or HAZARD (spawned).
@export var kind: Kind = Kind.STATE
## Where it applies.
@export var context: DataEnums.SceneContext = DataEnums.SceneContext.ISLAND
## Counts as a storm (morale hit, storm-season challenge).
@export var is_storm: bool = false
## Read by the WEATHER_IS_CLEAR condition (binoculars swim, dolphins).
@export var is_clear: bool = false

@export_group("Roll")
## How it starts.
@export var trigger: Trigger = Trigger.PHASE_ROLL
## Base per-phase roll weight (TBD).
@export var roll_weight: float = 0.0
## Chain family -> roll weight override; the only weather-weight table (ChainData has none).
@export var family_weights: Dictionary[DataEnums.ChainFamily, float] = {}
## Chain families where it can occur; empty means anywhere.
@export var chain_families: Array[DataEnums.ChainFamily] = []
## Distance bands where it can occur; empty means any band.
@export var distance_bands: Array[DataEnums.DistanceBand] = []
## Day phases it may start in.
@export var allowed_phases: Array[DataEnums.DayPhase] = []
## Weather ids of the parent states, for DURING_STATE.
@export var requires_weather_ids: Array[StringName] = []
## Weather id of the state a MODIFIER locks the manager to.
@export var forces_weather_id: StringName = &""
## Chance (0..1), for CHANCE and DURING_STATE.
@export var chance: float = 0.0
## What the chance is rolled per.
@export var chance_scope: ChanceScope = ChanceScope.PER_RUN
## Length in seconds; 0 means until the next roll (a day is 720 s).
@export var duration_s: float = 0.0
## Weather id of the state forced when this one ends.
@export var followed_by_weather_id: StringName = &""

@export_group("Warning")
## Warning cue.
@export var tell: Tell = Tell.NONE
## Advance warning, in seconds.
@export var warning_lead_s: float = 0.0

@export_group("Presentation")
## Multiplied into the CanvasModulate.
@export var canvas_tint: Color = Color(1, 1, 1, 1)
## Rain or fog overlay (asset).
@export var vfx_scene: PackedScene = null
## Ambience loop (asset).
@export var ambient_loop: AudioStream = null

@export_group("Survival")
## Heat-rise factor.
@export var heat_gain_mult: float = 1.0
## Thirst-drain factor.
@export var thirst_drain_mult: float = 1.0
## Outdoors counts as direct sun.
@export var direct_sun: bool = true
## One-time morale change for everyone when it starts.
@export var morale_on_start: float = 0.0

@export_group("Wind and sea")
## Sails give propulsion.
@export var sails_work: bool = false
## Drift of an unsteered vessel, in tiles/s (TBD).
@export var unsteered_drift: Vector2 = Vector2.ZERO
## Push on outdoor entities, in tiles/s.
@export var wind_push: Vector2 = Vector2.ZERO
## Integrity hit to vessels not tied down, when it starts.
@export var vessel_damage_on_start: int = 0
## Only a compass with charts can steer.
@export var navigation_needs_instruments: bool = false

@export_group("Visibility")
## Visibility in tiles; 0 means unlimited.
@export var visibility_tiles: int = 0
## No islands on the horizon.
@export var islands_hidden: bool = false
## CLEAR, GLARE (needs GLARE_PROTECTION) or BLOCKED; the only binocular rule.
@export var binoculars: Optics = Optics.CLEAR
## Senses no creature can use (fog: SIGHT, so searchlights fail and players are hidden).
@export var disabled_senses: Array[DataEnums.Sense] = []

@export_group("Island")
## Unsheltered fires go out within this many seconds; -1 means unaffected.
@export var fire_extinguish_s: float = -1.0
## Patrol loops pause.
@export var patrols_in_port: bool = false
## Rain falls: catchers and cisterns fill, manchineel burns those under it.
@export var rain: bool = false
## Respawn hook fired when it ends (SQUALL, HURRICANE).
@export var respawn_trigger: DataEnums.RespawnTrigger = DataEnums.RespawnTrigger.NEVER
## How far the shoreline moves inland, in tiles.
@export var water_rise_tiles: int = 0
## Time over which the water rises, in seconds.
@export var water_rise_s: float = 0.0
## All land becomes shallows.
@export var floods_island: bool = false
## Destroyed things, bit flags: 1 unsecured structures, 2 loose items, 4 unsealed stashes, 8 sealed stashes.
@export var destroy_flags: int = 0
## Damage per second outside a STORM_SHELTER POI (TBD).
@export var exposed_damage_per_s: float = 0.0

@export_group("Hazard")
## Hazard behavior.
@export var hazard: Hazard = Hazard.NONE
## Scene spawned for the hazard (asset).
@export var hazard_scene: PackedScene = null
## Damage when hit (TBD for lightning).
@export var hazard_damage: int = 0
## Seconds between strikes (TBD).
@export var hazard_interval_s: float = 0.0
## Speed of a moving hazard, in tiles/s (TBD).
@export var hazard_speed_tiles_s: float = 0.0
## Integrity hit when a vessel touches it (raft −60).
@export var vessel_contact_damage: int = 0
## Vessel speed factor inside the hazard (sargassum 0.5).
@export var vessel_speed_mult: float = 1.0
## Item id -> count gatherable from the hazard.
@export var hazard_loot: Dictionary[StringName, int] = {}


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"requires_weather_ids": &"weather",
		&"forces_weather_id": &"weather",
		&"followed_by_weather_id": &"weather",
		&"hazard_loot": &"items",
	}
