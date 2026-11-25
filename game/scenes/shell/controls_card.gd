class_name ControlsCard
extends Control
## ui-shell "Controles card" (run-menu design D6): each control with its keyboard key and its
## gamepad button, read from the input map when the card opens, so a rebinding shows at once (the
## idea of DCSS's help screens, which print each command's current key). Built on paper for the
## title; MenuLook.to_run turns it dark inside a run. Esc, the gamepad back button and "Volver" close
## it.

signal back_requested

const KEYBOARD_HEADING: String = "Teclado"
const GAMEPAD_HEADING: String = "Mando"
const NO_BUTTON: String = "—"
## Several bindings of one action are joined by this; several actions' keys by a space.
const JOIN: String = " / "
const RANGE_JOIN: String = " … "
const GROUP_MARK: String = " (en grupo)"
## The rows, top to bottom. `keys`: the actions whose keyboard keys the row shows (one action: all
## its keys; several: the first key of each). `range`: the first and last of a run of actions.
## `pad`: the actions whose gamepad buttons the row shows. `group`: only played with others.
const ROWS: Array[Dictionary] = [
	{"id": &"move", "label": "Moverse", "keys": [&"move_up", &"move_left", &"move_down", &"move_right"], "pad": [&"move_up", &"move_left", &"move_down", &"move_right"]},
	{"id": &"run", "label": "Correr", "keys": [&"run"], "pad": [&"run"]},
	{"id": &"crouch", "label": "Agacharse, bucear", "keys": [&"crouch"], "pad": [&"crouch"]},
	{"id": &"interact", "label": "Interactuar", "keys": [&"interact"], "pad": [&"interact"]},
	{"id": &"use_item", "label": "Usar objeto", "keys": [&"use_item"], "pad": [&"use_item"]},
	{"id": &"pick_item", "label": "Elegir objeto", "range": [&"slot_1", &"slot_12"], "pad": [&"slot_prev", &"slot_next"]},
	{"id": &"craft_list", "label": "Lista de fabricar", "keys": [&"list_up", &"list_down"], "pad": [&"list_up", &"list_down"]},
	{"id": &"quick_chat", "label": "Chat rápido", "keys": [&"quick_chat"], "pad": [&"quick_chat"], "group": true},
	{"id": &"pause", "label": "Menú", "keys": [&"pause"], "pad": [&"pause"]},
	{"id": &"fullscreen", "label": "Pantalla completa", "keys": [&"toggle_fullscreen"], "pad": []},
]
## Named keys in words that fit the card; a printed key reads as the keyboard layout prints it.
const KEY_WORDS: Dictionary[int, String] = {
	KEY_ESCAPE: "Esc",
	KEY_SHIFT: "Mayús",
	KEY_CTRL: "Ctrl",
	KEY_ALT: "Alt",
	KEY_ENTER: "Intro",
	KEY_SPACE: "Espacio",
	KEY_TAB: "Tab",
}
## The arrow keys, and their words for a font that lacks the glyph.
const ARROWS: Dictionary[int, String] = {
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
}
const ARROW_WORDS: Dictionary[int, String] = {
	KEY_UP: "Arriba",
	KEY_DOWN: "Abajo",
	KEY_LEFT: "Izquierda",
	KEY_RIGHT: "Derecha",
}

## The row labels and keys shown, by row id, for the tests and the shell.
var shown: Dictionary[StringName, PackedStringArray] = {}
var _in_run: bool = false
var _solo: bool = false

@onready var grid: GridContainer = %Grid
@onready var back_button: Button = %Back


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	refresh()
	back_button.grab_focus()


## Inside a run: a solo run has no quick chat row; a co-op run's needs no "(en grupo)".
func for_run(solo: bool) -> void:
	_in_run = true
	_solo = solo
	refresh()


## Reads the input map again and rebuilds the rows.
func refresh() -> void:
	if grid == null:
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	shown.clear()
	_add_cells(["", KEYBOARD_HEADING, GAMEPAD_HEADING])
	var text := HudText.load_default()
	for row: Dictionary in ROWS:
		var group: bool = row.get("group", false)
		if group and _in_run and _solo:
			continue
		var label: String = row["label"] + (GROUP_MARK if group and not _in_run else "")
		var keys: String = keyboard_text(row)
		var pad: String = gamepad_text(row, text)
		shown[row["id"]] = PackedStringArray([label, keys, pad])
		_add_cells([label, keys, pad])


func _add_cells(texts: Array[String]) -> void:
	for cell: String in texts:
		var label := Label.new()
		label.text = cell
		label.theme_type_variation = &"PanelLabel"
		grid.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## The keyboard column of `row`.
static func keyboard_text(row: Dictionary) -> String:
	if row.has("range"):
		var ends: Array = row["range"]
		return "%s%s%s" % [_first_key(ends[0]), RANGE_JOIN, _first_key(ends[ends.size() - 1])]
	var actions: Array = row.get("keys", [])
	if actions.size() == 1:
		var all: PackedStringArray = _keys(actions[0])
		return JOIN.join(all) if not all.is_empty() else NO_BUTTON
	var firsts := PackedStringArray()
	for action: StringName in actions:
		var first: String = _first_key(action)
		if not first.is_empty():
			firsts.append(first)
	return " ".join(firsts) if not firsts.is_empty() else NO_BUTTON


## The gamepad column of `row`: one label per action, the same one once, and a shared first word
## ("Cruz ↑", "Cruz ↓") written once ("Cruz ↑ ↓").
static func gamepad_text(row: Dictionary, text: HudText) -> String:
	var labels := PackedStringArray()
	for action: StringName in row.get("pad", []):
		var label: String = InputLabels.label_for(action, InputLabels.Device.GAMEPAD, text)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	if labels.is_empty():
		return NO_BUTTON
	if labels.size() == 1:
		return labels[0]
	var word: String = labels[0].get_slice(" ", 0)
	for label: String in labels:
		if label.get_slice(" ", 0) != word or label.get_slice_count(" ") < 2:
			return " ".join(labels)
	var rests := PackedStringArray()
	for label: String in labels:
		rests.append(label.substr(word.length() + 1))
	return "%s %s" % [word, " ".join(rests)]


## Every key bound to `action`, in its order, with Alt and Ctrl written before a modified key.
static func _keys(action: StringName) -> PackedStringArray:
	var found := PackedStringArray()
	if not InputMap.has_action(action):
		return found
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var name: String = key_word(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
		if key.alt_pressed:
			name = "Alt+" + name
		if key.ctrl_pressed:
			name = "Ctrl+" + name
		found.append(name)
	return found


static func _first_key(action: StringName) -> String:
	var all: PackedStringArray = _keys(action)
	return all[0] if not all.is_empty() else ""


## How the card names `physical`: a short word for a named key, an arrow (or its word when the
## body font lacks it), else what the keyboard layout prints.
static func key_word(physical: Key) -> String:
	if KEY_WORDS.has(physical):
		return KEY_WORDS[physical]
	if ARROWS.has(physical):
		return ARROWS[physical] if body_font_has(ARROWS[physical]) else ARROW_WORDS[physical]
	return InputLabels.key_label(physical)


## Whether the body font (the theme's default, Press Start 2P) draws `glyph`.
static func body_font_has(glyph: String) -> bool:
	var theme: Theme = ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null else null
	return font != null and font.has_char(glyph.unicode_at(0))
