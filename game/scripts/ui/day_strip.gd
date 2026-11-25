class_name DayStrip
extends RefCounted
## hud-clarity, ui-shell "Clock strip", "Time left before dark" and "Phase words": the clock row's
## pure sums. One day, dawn to dawn (DayClock's 720 s), maps onto STRIP_PX pixels in parts coloured
## by phase, with the midday stretch inside the day; a marker stands at the time of day. The time
## left counts to night (20:00) by day and to dawn (06:00) at night, in in-game hours rounded up,
## or in minutes under one hour. Drawing only: nothing here changes the clock.

## The strip's inner width: the 56 px box less its 1 px outline.
const STRIP_PX: int = 54
## Each part's colour, by key (the master palette): dawn rose, day sand, midday sun-orange, dusk
## orange-red, night the dark sea.
const COLORS: Dictionary[StringName, Color] = {
	&"dawn": Color("d77bba"),
	&"day": Color("d9a066"),
	&"midday": Color("df7126"),
	&"dusk": Color("ac3232"),
	&"night": Color("3f3f74"),
}
## Where each phase word starts, in seconds since dawn (08:00 is 60 s, 10:00 120 s, 16:00 300 s).
const WORD_STARTS: Array[float] = [0.0, DayClock.DAY_START_S, DayClock.MIDDAY_START_S, DayClock.MIDDAY_END_S, DayClock.DUSK_START_S, DayClock.NIGHT_START_S]
const WORD_KEYS: Array[StringName] = [&"dawn", &"morning", &"midday", &"afternoon", &"dusk", &"night"]


## A stretch of the strip: its colour key and its pixels [from_px, to_px).
class Part:
	var key: StringName
	var from_px: int
	var to_px: int

	func _init(part_key: StringName, from: int, to: int) -> void:
		key = part_key
		from_px = from
		to_px = to


## The strip's parts, left to right: dawn, day, midday, day, dusk, night.
static func parts() -> Array[Part]:
	var edges: Array[float] = [0.0, DayClock.DAY_START_S, DayClock.MIDDAY_START_S, DayClock.MIDDAY_END_S, DayClock.DUSK_START_S, DayClock.NIGHT_START_S, DayClock.DAY_S]
	var keys: Array[StringName] = [&"dawn", &"day", &"midday", &"day", &"dusk", &"night"]
	var out: Array[Part] = []
	for i: int in keys.size():
		out.append(Part.new(keys[i], px_at(edges[i]), px_at(edges[i + 1])))
	return out


## The strip column of `seconds` since dawn, floored.
static func px_at(seconds: float) -> int:
	return clampi(floori(seconds / DayClock.DAY_S * float(STRIP_PX)), 0, STRIP_PX)


## The marker's column at `seconds` since dawn, in [0, STRIP_PX - 1].
static func marker_px(seconds: float) -> int:
	return mini(px_at(seconds), STRIP_PX - 1)


## Whether the time left counts to dawn (at night, the sun mark) rather than to dark (the moon mark).
static func counts_to_dawn(seconds: float) -> bool:
	return seconds >= DayClock.NIGHT_START_S


## Seconds left before night begins, or at night before dawn.
static func seconds_left(seconds: float) -> float:
	var end: float = DayClock.DAY_S if counts_to_dawn(seconds) else DayClock.NIGHT_START_S
	return maxf(end - seconds, 0.0)


## Whether the time left shows orange: from dusk (18:00) until night.
static func is_warning(seconds: float) -> bool:
	return seconds >= DayClock.DUSK_START_S and seconds < DayClock.NIGHT_START_S


## The time left as the row shows it: in-game hours rounded up ("11h"), or minutes rounded up under
## one hour ("40m").
static func left_text(seconds: float, text: HudText, locale: String) -> String:
	var left: float = seconds_left(seconds)
	if left >= DayClock.HOUR_S:
		return text.clock_word(&"hours", locale) % ceili(left / DayClock.HOUR_S - 0.000001)
	return text.clock_word(&"minutes", locale) % ceili(left * 60.0 / DayClock.HOUR_S - 0.000001)


## The phase word's key at `seconds` since dawn: dawn, morning (08-10), midday (10-16), afternoon
## (16-18), dusk or night.
static func phase_key(seconds: float) -> StringName:
	var key: StringName = WORD_KEYS[0]
	for i: int in WORD_STARTS.size():
		if seconds >= WORD_STARTS[i]:
			key = WORD_KEYS[i]
	return key
