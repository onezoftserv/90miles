class_name SurvivalRules
extends RefCounted
## The survival-meters drain and restore rules as pure functions: a context and the tuning in,
## a per-second rate or the next value out. SurvivalMeters applies them. Never instantiated.


## Thirst lost per second. Swimming replaces the sun factor; night multiplies either.
static func thirst_drain(context: MeterContext, tuning: SurvivalTuning) -> float:
	var rate: float = tuning.thirst_per_s
	if context.swimming:
		rate *= tuning.thirst_swim_factor
	elif context.in_direct_sun():
		rate *= tuning.thirst_sun_factor
	if context.phase == DataEnums.DayPhase.NIGHT:
		rate *= tuning.thirst_night_factor
	return rate


## Hunger lost per second.
static func hunger_drain(context: MeterContext, tuning: SurvivalTuning) -> float:
	if context.crafting or context.swimming:
		return tuning.hunger_per_s * tuning.hunger_work_factor
	return tuning.hunger_per_s


## Heat after `delta` seconds: 0 at night, rising in direct midday sun, falling anywhere else.
static func next_heat(heat: float, context: MeterContext, tuning: SurvivalTuning, delta: float) -> float:
	if context.phase == DataEnums.DayPhase.NIGHT:
		return 0.0
	if context.midday and context.in_direct_sun():
		return heat + tuning.heat_rise_per_s * context.heat_factor * delta
	return heat - tuning.heat_fall_per_s * delta


## Morale change per second: company restores, being alone at night drains.
static func morale_rate(context: MeterContext, tuning: SurvivalTuning) -> float:
	if context.teammate_nearby:
		return tuning.morale_company_per_s
	if context.phase == DataEnums.DayPhase.NIGHT:
		return -tuning.morale_alone_night_per_s
	return 0.0
