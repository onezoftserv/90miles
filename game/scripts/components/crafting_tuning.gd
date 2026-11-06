class_name CraftingTuning
extends Resource
## Every number of crafting-inventory in one file (game/resources/crafting_tuning.tres), like
## SurvivalTuning. Provisional until playtests; sources: crafting-inventory spec, ITEMS.md.

## Carry limit; above 15 while swimming, energy drains x2 (swimming overload is a later change).
@export var weight_limit: float = 30.0
## Slots per player.
@export var slot_count: int = 12
## Seconds a fire burns: 12 in-game hours at 30 s each.
@export var fire_burn_s: float = 360.0
## Seconds the put-out interaction is held.
@export var fire_put_out_hold_s: float = 2.0
## Seconds of continuous rain before a rain catcher holds a cup.
@export var rain_fill_s: float = 30.0
## Solar still: in-game hours per still cup (the still itself is a later change).
@export var still_cup_every_game_hours: float = 12.0
## Host requests (use, craft, deposit) a peer may send: a burst, then per second.
@export var action_burst: float = 10.0
@export var actions_per_s: float = 10.0
