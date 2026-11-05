class_name GrabData
extends DataPart
## Parameters for the grab_drag sub-machine that hidden_ambush hands off to after a hit
## (crocodile, old crocodile, boa). Embedded in CreatureData.grab; holds no references.
## Sources: creatures-ai "Grab and rescue", BESTIARY crocodile and boa entries.

## Speed the victim is dragged, in tiles/s; 0 means held in place (constrict).
@export var drag_speed_tiles_s: float = 0.0
## The drag heads for the nearest deep-water tile.
@export var drags_to_deep_water: bool = false
## Health lost per second while held.
@export var damage_per_s: float = 0.0
## Automatic release after this many seconds; 0 means held until freed.
@export var max_duration_s: float = 0.0
## Teammate weapon hits needed to free the victim.
@export var release_hits: int = 0
## Window in seconds in which the release hits must land; 0 means no window.
@export var release_window_s: float = 0.0
## Chance per second (0..1) that mashing frees the victim alone.
@export_range(0.0, 1.0) var solo_escape_chance_per_s: float = 0.0
## Health cost per second of mashing to escape alone.
@export var solo_escape_health_cost_per_s: float = 0.0
