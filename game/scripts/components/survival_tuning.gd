class_name SurvivalTuning
extends Resource
## Every survival-meters rate and threshold, in real seconds (one in-game hour is 30 s). The
## numbers live only in res://resources/survival_tuning.tres; the script has no defaults so a
## value can never come from two places. All are provisional until the Milestone A playtest
## (openspec change survival-meters, proposal.md).

@export_group("Thirst")
## Drain at rest, per real second.
@export var thirst_per_s: float
## In direct sun: the day phase, on land, not in shade.
@export var thirst_sun_factor: float
## While swimming; replaces the sun factor.
@export var thirst_swim_factor: float
## At night; multiplies whatever else applies.
@export var thirst_night_factor: float
## Health lost per second while thirst is empty.
@export var dry_health_per_s: float

@export_group("Hunger")
@export var hunger_per_s: float
## While crafting or swimming.
@export var hunger_work_factor: float
## Highest energy while hunger is empty.
@export var starving_energy_cap: float

@export_group("Heat")
## Rise per second in direct sun between 10:00 and 16:00, before the weather's heat factor.
@export var heat_rise_per_s: float
## Fall per second anywhere else; heat is 0 at night.
@export var heat_fall_per_s: float
@export var sunstroke_at: float
## Sunstroke lasts until heat drops below this.
@export var sunstroke_ends_below: float
## Speed multiplier during sunstroke.
@export var sunstroke_speed_factor: float

@export_group("Energy")
## Energy from a meal: anything that restores hunger.
@export var meal_energy: float
## Energy from a full night in shelter.
@export var sleep_energy: float

@export_group("Morale")
@export var morale_alone_night_per_s: float
@export var morale_company_per_s: float
## A teammate this close (tiles) counts as company.
@export var company_radius_tiles: float
@export var morale_ally_died: float
@export var morale_squall: float
@export var morale_fire_lit: float
@export var morale_song: float
@export var morale_text_read: float
## Hallucinating while morale is below this.
@export var hallucinate_below: float

@export_group("Health")
## Seconds a downed co-op player waits for a revive before dying, before downed-timer bonuses.
@export var downed_s: float
@export var revive_health: float
## Seconds a solo player's last stand lasts before downed-timer bonuses (0: death at once).
@export var solo_last_stand_s: float
