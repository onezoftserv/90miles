class_name ClockStrip
extends HBoxContainer
## hud-clarity, ui-shell "Clock strip": the clock row inside the day phase window, left to right the
## day count ("Día 2"), the day strip with its marker (`strip`), the time left beside a moon mark (to
## dark) or a sun mark (to dawn, at night), cream and orange from dusk, and the phase word (RunHud's
## %Phase). It reads the session's climate, which the host's sky writes and every client's follows,
## so the row is the same on every peer to within one resync. Drawing only.

## The 5×5 kit marks beside the time left (set in run_hud.tscn): the moon counts to dark, the sun to dawn.
@export var moon_mark: Texture2D = null
@export var sun_mark: Texture2D = null

## Whether the time left counts to dawn (the sun mark) rather than to dark (the moon mark).
var counts_to_dawn: bool = false

@onready var day_label: Label = $Day
@onready var strip: DayStripView = $Strip
@onready var mark: TextureRect = $Left/Mark
@onready var left_label: Label = $Left/Time


## Shows `climate`'s day and time in `locale`, with the phase word in `phase_label`.
func show_climate(climate: ClimateState, text: HudText, locale: String, phase_label: Label) -> void:
	var seconds: float = climate.time_of_day_s
	day_label.text = text.clock_word(&"day", locale) % climate.day
	strip.show_time(seconds)
	counts_to_dawn = DayStrip.counts_to_dawn(seconds)
	mark.texture = sun_mark if counts_to_dawn else moon_mark
	left_label.text = DayStrip.left_text(seconds, text, locale)
	left_label.add_theme_color_override(&"font_color", HudStyle.ORANGE if DayStrip.is_warning(seconds) else HudStyle.CREAM)
	phase_label.text = RunHud.phase_name(climate, locale)
