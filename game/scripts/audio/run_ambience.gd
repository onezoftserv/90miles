class_name RunAmbience
extends RefCounted
## sound-pass audio "Ambience follows place, time and weather" (design D5): the levels (0 to 1, on
## top of each loop's bank level) of the sea, wind and night loops for one player.
## - sea: always, louder while riding a crossing;
## - wind: while riding a crossing, and in a squall (louder), whichever is more;
## - night: during the night phase on an island only.


static func levels(riding: bool, phase: DataEnums.DayPhase, squall: bool, bank: SoundBank) -> Dictionary[StringName, float]:
	var wind: float = 0.0
	if riding:
		wind = bank.wind_crossing
	if squall:
		wind = maxf(wind, bank.wind_squall)
	return {
		&"sea": bank.sea_crossing if riding else bank.sea_island,
		&"wind": wind,
		&"night": bank.night_level if not riding and phase == DataEnums.DayPhase.NIGHT else 0.0,
	}


## True when `weather_id` is one the bank says blows (thunder, and the wind at its squall level).
static func is_squall(weather_id: StringName, bank: SoundBank) -> bool:
	return weather_id != &"" and bank.squall_weathers.has(weather_id)
