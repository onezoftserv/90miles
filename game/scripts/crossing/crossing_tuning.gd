class_name CrossingTuning
extends Resource
## Every crossing number, only in res://resources/crossing_tuning.tres (the script has no
## defaults, like DayCycleTuning). Hits, holds and the squall's warning come from the specs and
## docs; the rest is provisional until the Milestone B playtest.

const STANDARD_PATH: String = "res://resources/crossing_tuning.tres"
## The flotsam table's id for a plank, which is lashed on at once instead of carried.
const PLANK_ID: StringName = &"plank"

## Vessel integrity lost to a squall (times the route's squall factor), a shark hit and a rock.
@export var squall_hit: float
@export var shark_hit: float
@export var rock_hit: float
## Energy a fall into the water costs.
@export var fall_in_energy: float
## Energy per second a swimmer pays to keep up with the vessel (times the route's drain factor).
@export var pace_drain_per_s: float
## Health per second lost by a swimmer with no energy.
@export var drown_health_per_s: float
## Seconds of holding to tie down, pull a swimmer aboard and climb aboard alone.
@export var tie_hold_s: float
@export var pull_hold_s: float
@export var climb_hold_s: float
## How close, in tiles, a puller or a climber must be.
@export var reach_tiles: float
## A crossing launched during a running squall meets its hit this many seconds in.
@export var running_squall_grace_s: float
## Shark bite on a swimmer, and the energy below which a swimmer is the preferred prey.
@export var shark_swimmer_damage: float
@export var shark_energy_threshold: float
## Visual scroll of the sea, in tiles per second (times the route's speed factor).
@export var scroll_tiles_per_s: float
## Chance per crossing of a shark pass, by DataEnums.DistanceBand (times route factors).
@export var shark_chance: Dictionary[int, float]
## Events never fall in the first or last seconds of a crossing.
@export var event_margin_s: float
## At most this many rolled creatures ride along with one crossing; chance-1.0 ones are not counted
## (creature-perch-ride "Crossing creature roll").
@export var max_rolled_creatures: int

@export_group("Telegraphs")
## A rock, debris or flotsam shows at the sea's north edge this long before it reaches the deck.
@export var hazard_lead_s: float
## The shark's fin circles its side this long before it strikes.
@export var shark_lead_s: float

@export_group("Paddling")
## Tiles per second one rider paddling moves the vessel, and two or more on the same side.
@export var paddle_tiles_per_s: float
@export var paddle_crew_tiles_per_s: float
## Tiles per second the current pulls an unpaddled vessel back to the line.
@export var pull_back_tiles_per_s: float
## The vessel stays within this many tiles of the line.
@export var max_offset_tiles: float

@export_group("Hazards")
## Widths in tiles: a rock, debris, and a shared vessel (raft, car).
@export var rock_width_tiles: float
@export var debris_width_tiles: float
@export var vessel_width_tiles: float
## Integrity lost to debris, and what each open leak drains a second.
@export var debris_hit: float
@export var leak_drain_per_s: float
## Seconds of holding to plug a leak; at most this many leaks are open on one vessel.
@export var plug_hold_s: float
@export var max_leaks: int
## Integrity a plank lashed on gives back.
@export var plank_repair: float
## Health a swimmer loses to a rock passing over them (and starts bleeding), and to debris.
@export var rock_cut_health: float
@export var debris_cut_health: float

@export_group("Jobs")
## Seconds of holding to take a passing piece, and to shoo the shark's fin.
@export var grab_hold_s: float
@export var shoo_hold_s: float
## Picker priorities of the crossing's points (crossing "Which job a press takes"); paddles, the
## lashing and climb points keep 0, a perched creature's shoo −1.
@export var shoo_priority: int
@export var pull_priority: int
@export var grab_priority: int
@export var plug_priority: int

@export_group("Squall")
## The squall's blow: the seconds after its hit when paddling slows and no beat is rolled.
@export var squall_blow_s: float
@export var blow_paddle_factor: float
## A rock or debris falls in the `pre_squall_window_s` before a squall's hit at
## `pre_squall_min_hit_s` or later; one is put `pre_squall_s` before the hit when none falls there.
@export var pre_squall_window_s: float
@export var pre_squall_s: Vector2
@export var pre_squall_min_hit_s: float

@export_group("Pacing")
## No beat is rolled before this time; the first falls within the spread after it.
@export var calm_start_s: float
@export var first_beat_spread_s: float
## The aimed-for gap between beats, how far each may be moved, and the hard limits; the gaps
## shrink by `rider_gap_factor` for each rider past the first (the minimum does not).
@export var target_gap_s: float
@export var gap_jitter_s: float
@export var max_gap_s: float
@export var min_gap_s: float
@export var rider_gap_factor: float
## The reef line comes this long before the end: two rocks this many tiles either side of its
## gap, the gap's lane within ±`reef_gap_lane_max`.
@export var reef_before_end_s: float
@export var reef_half_gap_tiles: int
@export var reef_gap_lane_max: int
## Weights of a beat being a rock, debris or flotsam, by DataEnums.DistanceBand (rock and debris
## times the route's threat factor).
@export var rock_weight: Dictionary[int, float]
@export var debris_weight: Dictionary[int, float]
@export var flotsam_weight: Dictionary[int, float]
## Lanes: hazards within ±`hazard_lane_max`, flotsam `flotsam_lanes.x`–`.y` tiles either side.
@export var hazard_lane_max: int
@export var flotsam_lanes: Vector2i

@export_group("Flotsam")
## What drifts by, and how often: item ids (PLANK_ID for a plank) with their weights.
@export var flotsam_items: Array[StringName]
@export var flotsam_weights: Array[float]


static func standard() -> CrossingTuning:
	return load(STANDARD_PATH) as CrossingTuning


## The weight of `kind` (ROCK, DEBRIS or FLOTSAM) on `band`.
func beat_weight(kind: CrossingBeat.Kind, band: DataEnums.DistanceBand) -> float:
	match kind:
		CrossingBeat.Kind.ROCK:
			return rock_weight.get(band, 0.0)
		CrossingBeat.Kind.DEBRIS:
			return debris_weight.get(band, 0.0)
		CrossingBeat.Kind.FLOTSAM:
			return flotsam_weight.get(band, 0.0)
	return 0.0


## The flotsam piece at `index`, or &"" outside the table.
func flotsam_piece(index: int) -> StringName:
	return flotsam_items[index] if index >= 0 and index < flotsam_items.size() else &""
