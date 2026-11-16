class_name HurtCueTuning
extends Resource
## The numbers of the hit, drain and change cues (damage-feedback design D3 to D10), in
## game/resources/hurt_cue_tuning.tres so tuning them needs no script edit. Feedback only: none of
## them changes the simulation.

@export_group("Watch")
## How far past the steady change a change must go to count as at once (a hit or a jump).
@export var change_margin: float = 3.0
## Seconds without a change in one direction before its steady rate is forgotten.
@export var steady_forget_s: float = 1.0

@export_group("Body blink")
## How long the hurt blink lasts.
@export var blink_s: float = 0.6
## Blinks per second (each one hidden then shown).
@export var blink_hz: float = 10.0
## The steady tint that stands in for the blink with reduce flashes on.
@export var tint_color: Color = Color(1.0, 0.35, 0.3)

@export_group("Edge flash")
## Seconds the screen-edge flash takes to fade.
@export var flash_s: float = 0.4
## The strength of the smallest hit's flash, from 0 to 1.
@export var flash_floor: float = 0.5
## A hit this big or bigger flashes at full strength and asks for the big hurt sound.
@export var big_hit: float = 25.0
## The edge's alpha at full strength.
@export var flash_alpha: float = 0.45
## A hit sooner than this after the last flash only raises it.
@export var flash_min_gap_s: float = 0.33
## How deep the red band reaches in from each edge, in HUD pixels.
@export var edge_px: float = 24.0
@export var flash_color: Color = Color(0.85, 0.08, 0.08)

@export_group("Bars")
## A lost slice holds this long, then shrinks over loss_drain_s.
@export var loss_hold_s: float = 0.4
@export var loss_drain_s: float = 0.5
@export var loss_color: Color = Color(1.0, 0.62, 0.58)
## A hit shakes the health bar sideways this far for this long.
@export var shake_px: float = 1.0
@export var shake_s: float = 0.2
## The drain glow stays this long after the last loss.
@export var glow_linger_s: float = 1.0
@export var glow_color: Color = Color(0.75, 0.12, 0.1, 0.85)
## A gained slice holds this long, then blends into the fill over gain_fade_s.
@export var gain_hold_s: float = 0.6
@export var gain_fade_s: float = 0.4
## How long a bar flashes when its meter jumps up.
@export var gain_flash_s: float = 0.1
## How much a gained slice lightens its bar's colour, 0 to 1.
@export var gain_lighten: float = 0.55

@export_group("Floats")
@export var float_s: float = 1.0
@export var float_rise_px: float = 12.0
## The gap between floats made at once over one body.
@export var float_stack_px: float = 9.0
## Each meter's float colour (DataEnums.Meter → Color), equal to its HUD bar's fill colour.
@export var meter_colors: Dictionary[int, Color] = {}
## A cure's float colour.
@export var cure_color: Color = HudStyle.CREAM
