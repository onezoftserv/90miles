class_name CrossingTuning
extends Resource
## Every crossing number, only in res://resources/crossing_tuning.tres (the script has no
## defaults, like DayCycleTuning). Hits, holds and the squall's warning come from the specs and
## docs; the rest is provisional until the Milestone B playtest.

const STANDARD_PATH: String = "res://resources/crossing_tuning.tres"

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
## Chance per crossing of a shark pass and of a rock, by DataEnums.DistanceBand (times route factors).
@export var shark_chance: Dictionary[int, float]
@export var rock_chance: Dictionary[int, float]
## Events never fall in the first or last seconds of a crossing.
@export var event_margin_s: float
## At most this many rolled creatures ride along with one crossing; chance-1.0 ones are not counted
## (creature-perch-ride "Crossing creature roll").
@export var max_rolled_creatures: int


static func standard() -> CrossingTuning:
	return load(STANDARD_PATH) as CrossingTuning
