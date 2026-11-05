class_name CreatureData
extends ContentData
## A threat from BESTIARY.md (sea, land, human, bodied boss or boss proxy), one file per id in
## game/resources/creatures/. Read by the generic creature scene and game/scripts/ai/. Its spawn
## rules are the only source of where it appears; its counters hold every player counter.
## Sources: BESTIARY, creatures-ai spec, guardacostas-stealth spec, CONTENT_MANIFEST creatures.

## Codex section. Enum values are saved as ints: append only.
enum Category {
	SEA,
	LAND,
	HUMAN,
	ENVIRONMENT,
}

## Where a creature can move: picks the land or water AStarGrid2D; AIR ignores terrain.
enum Domain {
	LAND,
	SHALLOW,
	DEEP,
	AIR,
	VESSEL,
}

## Primary reusable state machine, game/scripts/ai/<snake_case>.gd.
enum Behavior {
	NONE,
	PATROL_CIRCLE_STRIKE,
	HIDDEN_AMBUSH,
	PACK_SWARM,
	DRIFT_TRAP,
	NIGHT_THIEF,
	SWOOP_STEAL,
	GAS_CLOUD,
	STATIC_HAZARD,
	PASSIVE_FLEE,
	PATROL_ROUTE,
	SEARCH_CAPTURE,
	AMBIENT,
	TRADE_OR_ROB,
}

## How it treats players.
enum Disposition {
	HOSTILE,
	DEFENSIVE,
	PASSIVE,
	NEUTRAL,
}

## What starts an attack or effect.
enum AttackTrigger {
	PURSUE,
	STEP_ON,
	ADJACENT,
	CONTACT,
	INTERACT,
	AREA,
	LIGHT_SOURCE,
}

## Whether players can see it before it acts.
enum Visibility {
	VISIBLE,
	HIDDEN,
	DISGUISED,
}

## A property of a target that makes it a valid strike target.
enum TargetCondition {
	BLEEDING,
	LOW_ENERGY,
	ALONE,
	CARRYING_TAG,
	IN_WATER,
	IN_DEEP_WATER,
	PARALYZED,
	CORNERED,
	NEAR_TERRITORY,
}

## Where a thief takes items from.
enum StealSource {
	STASH_UNSEALED,
	GROUND,
	HELD,
	FISHING_CATCH,
	VESSEL_STORES,
	INVENTORY,
}

## Boss role. WEATHER and CROSSING are proxies whose mechanics live in WeatherData or ChainData.
enum BossKind {
	NONE,
	CREATURE,
	WEATHER,
	CROSSING,
}

@export_group("Codex")
## Spanish codex lore (the docs are English only, so it is translated during data entry).
@export_multiline var description_es: String = ""
## English codex lore.
@export_multiline var description_en: String = ""
## Codex counter text in Spanish (same name as WeatherData.hint_es).
@export_multiline var hint_es: String = ""
## Codex counter text in English.
@export_multiline var hint_en: String = ""
## Codex section.
@export var category: Category = Category.SEA
## Codex sort order; expansion entries use the bestiary # (16-35).
@export var codex_order: int = 0
## SHARK or PATROL; read by dolphin repel, Yunior's panic, the shark unlock and patrol rules.
@export var creature_tags: Array[DataEnums.CreatureTag] = []
## Animation frames (art is a direct asset reference, not an id). Null for boss proxies.
@export var sprite_frames: SpriteFrames = null

@export_group("Combat")
## Hit points; 0 means it cannot be killed (bosses, patrols, clouds, trees), hits still fire counters.
@export var health: int = 0
## Base speed in tiles/s; 0 means stationary. The player walks 4 and swims 3.
@export var speed_tiles_s: float = 0.0
## Health removed per attack or contact. Statuses go in contact_effects.
@export var damage: float = 0.0
## Minimum seconds between attacks by one individual.
@export var attack_cooldown_s: float = 1.0
## Reach of the attack or lunge, in tiles.
@export var attack_range_tiles: float = 1.0
## Integrity removed from a raft or boat per hit or wake.
@export var vessel_damage: float = 0.0

@export_group("Behavior")
## Where it can move; VESSEL means attached to the party's vessel.
@export var domains: Array[Domain] = []
## Primary state machine. grab_drag is entered through grab, not set here.
@export var behavior: Behavior = Behavior.NONE
## HOSTILE hunts, DEFENSIVE attacks only when provoked, PASSIVE never attacks, NEUTRAL is an encounter.
@export var disposition: Disposition = Disposition.HOSTILE
## What starts an attack or effect; more than one is allowed.
@export var triggers: Array[AttackTrigger] = []
## HIDDEN until triggered or revealed; DISGUISED looks harmless until a REVEAL counter fires.
@export var visibility: Visibility = Visibility.VISIBLE

@export_group("Activity")
## Aggressive during these phases (OR with active_weather_ids); both empty means always active.
@export var active_phases: Array[DataEnums.DayPhase] = []
## WeatherData ids that make it active (OR with active_phases).
@export var active_weather_ids: Array[StringName] = []
## Live instances leave when one of these phases starts.
@export var despawn_phases: Array[DataEnums.DayPhase] = []
## Moves with WeatherManager wind instead of pathing.
@export var drifts_with_wind: bool = false
## Escorts or attaches to the vessel for the whole crossing.
@export var follows_vessel: bool = false
## Radius in tiles of an AREA trigger or aura (cloud, canopy). TBD: the docs give no sizes.
@export var area_radius_tiles: float = 0.0
## Min (x) and max (y) circling time in seconds before it strikes or leaves.
@export var circle_time_s: Vector2 = Vector2.ZERO
## Seconds it disengages or hides after a hit.
@export var retreat_time_s: float = 0.0
## The group flees once this many members have died; 0 means never.
@export var flee_after_group_deaths: int = 0

@export_group("Territory")
## PoiData id it lives at or guards; empty means the POI it spawned at.
@export var territory_poi_id: StringName = &""
## Phases when it leaves territory_poi_id to hunt.
@export var lair_leave_phases: Array[DataEnums.DayPhase] = []
## Seconds it stays away from the lair.
@export var lair_absence_s: float = 0.0

@export_group("Targeting")
## A target qualifies if ANY condition holds; empty means any target in reach.
@export var strike_conditions: Array[TargetCondition] = []
## LOW_ENERGY holds when the target's energy is below this.
@export var low_energy_threshold: float = 20.0
## ALONE holds when no teammate is within this radius in tiles (borrowed from the morale rule).
@export var alone_radius_tiles: float = 5.0
## Item tags that make CARRYING_TAG true (barracuda: SHINY).
@export var target_item_tags: Array[DataEnums.ItemTag] = []
## Chance per minute that an attack happens while the trigger holds; 0 means deterministic.
@export var attack_chance_per_min: float = 0.0

@export_group("Senses")
## World-bus events it reacts to; WeatherData.disabled_senses can switch some off.
@export var senses: Array[DataEnums.Sense] = []
## Range in tiles for SIGHT checks. TBD.
@export var sight_radius_tiles: float = 0.0
## Maximum distance in tiles at which noise or splashes are investigated.
@export var hearing_radius_tiles: float = 0.0
## Maximum distance in tiles at which blood(pos) events are investigated. TBD.
@export var smell_radius_tiles: float = 0.0
## Radius in tiles of the constant noise it gives off (jet ski: 20).
@export var emitted_noise_radius_tiles: float = 0.0

@export_group("Theft")
## Where it takes items from.
@export var steal_from: Array[StealSource] = []
## Item tags it takes (FOOD, MEAT).
@export var steal_item_tags: Array[DataEnums.ItemTag] = []
## Specific ItemData ids it takes (remora: fish_raw).
@export var steal_item_ids: Array[StringName] = []
## Items taken per theft; -1 means everything.
@export var steal_count: int = 1
## Seconds between thefts by one individual; 0 means once per opportunity.
@export var steal_interval_s: float = 0.0
## Chance (0..1) that a theft attempt succeeds.
@export_range(0.0, 1.0) var steal_chance: float = 1.0
## Leaves after a successful theft.
@export var flees_after_steal: bool = false

@export_group("Effects")
## Applied to the victim (target ACTOR) on a hit, touch, step or area entry.
@export var contact_effects: Array[EffectData] = []
## Applied each second inside area_radius_tiles; METER_ADD amounts are per second.
@export var aura_effects: Array[EffectData] = []
## Applied once to each player who sees it.
@export var sighting_effects: Array[EffectData] = []

@export_group("Counters and encounter")
## If set, a successful hit hands off to the grab_drag sub-machine.
@export var grab: GrabData = null
## Trigger-to-response rules: decoys, drive-offs, immunity (sandals), reveals, Rodríguez's pass.
@export var counters: Array[CreatureCounterData] = []
## Guardacostas parameters. Set only on PATROL-tagged creatures.
@export var patrol: PatrolData = null
## RouteData id the encounter can start (smugglers -> smugglers_boat).
@export var offers_route_id: StringName = &""

@export_group("Spawning and loot")
## OR-list of placement rules; empty means only spawned by a set piece, a patrol squad or a chain boss.
@export var spawn_rules: Array[CreatureSpawnRuleData] = []
## Count/rate multiplier for each player beyond the first.
@export var party_rate_mult_per_extra_player: float = 1.2
## +1 instance per this many players (patrols: 2); 0 means off.
@export var party_extra_count_every_n_players: int = 0
## Run-wide encounter cap; 0 means unlimited.
@export var max_per_run: int = 0
## CreatureData ids suppressed on an island where this one spawns.
@export var replaces_creature_ids: Array[StringName] = []
## ItemData id -> count dropped when killed, trapped or caught.
@export var loot: Dictionary[StringName, int] = {}

@export_group("Boss")
## CREATURE is a bodied boss; WEATHER and CROSSING are proxies. The chain's boss is ChainData.boss_id.
@export var boss_kind: BossKind = BossKind.NONE
## WEATHER proxies only: the WeatherData id that runs the fight (hurricane).
@export var boss_weather_id: StringName = &""
## DialogueData id played at the encounter (beat_boss_<id>).
@export var story_beat_id: StringName = &""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"active_weather_ids": &"weather",
		&"territory_poi_id": &"pois",
		&"steal_item_ids": &"items",
		&"offers_route_id": &"routes",
		&"replaces_creature_ids": &"creatures",
		&"loot": &"items",
		&"boss_weather_id": &"weather",
		&"story_beat_id": &"dialogue",
	}
