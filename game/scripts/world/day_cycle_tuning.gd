class_name DayCycleTuning
extends Resource
## The day-night presentation numbers, only in res://resources/day_cycle.tres (the script has no
## defaults, like SurvivalTuning). The phase lengths themselves are fixed by the spec and live in
## DayClock. All are provisional until the Milestone A playtest.

## CanvasModulate colour of each phase.
@export var phase_tints: Dictionary[DataEnums.DayPhase, Color]
## Seconds a phase takes to blend from the previous phase's colour.
@export var blend_s: float
## Seconds between the host's clock messages to clients.
@export var resync_s: float
