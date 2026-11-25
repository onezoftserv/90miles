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
	var next: float = heat - tuning.heat_fall_per_s * delta
	if context.midday and context.in_direct_sun():
		next = heat + tuning.heat_rise_per_s * context.heat_factor * delta
	if sea_heat_capped(context, tuning) and next > tuning.sea_heat_cap:
		# Never past the cap, and above it heat falls at the shade rate (no slower) down to it.
		return maxf(minf(next, heat - tuning.heat_fall_per_s * delta), tuning.sea_heat_cap)
	return next


## island-pressure D6: whether the sea cap holds `context`'s heat: a rider at sea, with the cap on. The
## one switch for it: the island-stop toldo turns it off here (or a negative `sea_heat_cap` turns it off
## for everyone).
static func sea_heat_capped(context: MeterContext, tuning: SurvivalTuning) -> bool:
	return context.at_sea and tuning.sea_heat_cap >= 0.0


## Morale change per second: a teammate restores; at night, having neither a teammate nor a lit
## fire nearby drains. A fire only stops the drain, so one player can hold morale alone.
static func morale_rate(context: MeterContext, tuning: SurvivalTuning) -> float:
	if context.teammate_nearby:
		return tuning.morale_company_per_s
	if context.phase == DataEnums.DayPhase.NIGHT and not context.near_fire:
		return -tuning.morale_alone_night_per_s
	return 0.0
