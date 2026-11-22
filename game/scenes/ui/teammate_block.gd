class_name TeammateBlock
extends VBoxContainer
## One teammate in the HUD's top-right list (ui-shell "HUD layout", "Teammate state word";
## hud-window-kit design D7, owner answer B1): a 128x20 block of two 10 px lines. The first line is
## the teammate's name, whole (16 glyphs fit); the second a 6x6 chip in the teammate's clothing base
## colour, a 22x6 health bar on the Salud ramp and the state word ("Caído" and "Muerto" in the alert
## red, "Desconectado" in grey). Brogue's sidebar gives every ally the player's health row and a state
## line (`printMonsterInfo`); SPD's `HealthBar.level` rounds a sliver of health up to a whole pixel.
## It only shows what RunHud hands it; it never reads the session.

## The clothing ramps: row 0 the key ramp, row n + 1 look slot n; column 1 the base shade.
const PLAYER_RAMPS: Texture2D = preload("res://assets/art/palette/player_ramps.png")
const BASE_SHADE: int = 1
## "Desconectado" in the kit's grey (#9badb7, 6.84:1 on the dark window).
const DROPPED_COLOR: Color = Color(0.60784314, 0.67843137, 0.71764706)
const DROPPED_WORD: String = "Desconectado"

static var _ramps: Image = null

## The teammate's name, health and state word as shown, for tests and for `RunHud.teammate_rows`.
var teammate_name: String = ""
var health: float = 0.0
var state: String = ""

@onready var name_label: Label = $Name
@onready var chip: ColorRect = $Row/ChipCell/Ring/Chip
@onready var bar: ProgressBar = $Row/BarCell/Bar
@onready var state_label: Label = $Row/State


## The base shade of look slot `slot`'s clothing ramp.
static func chip_color(slot: int) -> Color:
	if _ramps == null:
		_ramps = PLAYER_RAMPS.get_image()
	if _ramps == null:
		return HudStyle.CREAM
	var row: int = clampi(slot + 1, 1, _ramps.get_height() - 1)
	var color: Color = _ramps.get_pixel(BASE_SHADE, row)
	color.a = 1.0
	return color


## Shows one teammate: their name, health (0-100), state word ("" for none) and look slot.
func show_teammate(shown_name: String, shown_health: float, shown_state: String, look_slot: int) -> void:
	teammate_name = shown_name
	health = shown_health
	state = shown_state
	name_label.text = shown_name
	chip.color = chip_color(look_slot)
	# A sliver of health never reads as empty: at least one whole pixel of fill (SPD HealthBar.level).
	var shown: float = shown_health
	if shown_health > 0.0:
		shown = maxf(shown_health, 100.0 / bar.size.x if bar.size.x > 0.0 else 5.0)
	bar.value = shown
	state_label.text = shown_state
	if shown_state.is_empty():
		state_label.theme_type_variation = &""
		state_label.remove_theme_color_override(&"font_color")
	elif shown_state == DROPPED_WORD:
		state_label.theme_type_variation = &""
		state_label.add_theme_color_override(&"font_color", DROPPED_COLOR)
	else:
		state_label.remove_theme_color_override(&"font_color")
		state_label.theme_type_variation = &"AlertLabel"


## "<name> <health> <state>", the row text the tests read.
func summary() -> String:
	return ("%s %d %s" % [teammate_name, roundi(health), state]).strip_edges()
