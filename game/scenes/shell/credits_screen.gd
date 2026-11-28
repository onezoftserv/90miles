class_name CreditsScreen
extends Control
## art-pass "Credits screen" (design.md D10, K20): every entry of the credits data in Spanish, the
## CC BY packs first, each with its licence's address as plain text (CREDITS.md and License.txt do
## not ship in an exported build), then the courtesy lines (the CC0 packs and the palette) and the
## OFL fonts, in a list that scrolls. It reads only the credits data and needs no network; the
## shell decides where "Volver" and Esc go.

signal back_requested

## Marks an entry whose files were changed (recoloured, cut, edited).
const MODIFIED_MARK: String = " (modificado)"
## The second line of a CC BY entry: the licence's address, CC BY 4.0 §3(a)(1).
const LICENCE_LINE: String = "Licencia: %s"
## The CC BY group's heading, with the licence's address once under it (menu-clarity design D9).
const ATTRIBUTION_HEADING: String = "Con licencia CC BY 4.0"
## Under the list while more of it lies below.
const MORE_BELOW: String = "▼ Más abajo"
## How far one press of up or down moves the list.
const SCROLL_STEP_PX: int = 24

var credits: ArtCredits

@onready var scroll: ScrollContainer = %Scroll
@onready var back_button: Button = %Back
@onready var more: Label = %More
@onready var _list: VBoxContainer = %List
## One list per ArtCredit.Group, in the screen's order, each under its heading.
@onready var _groups: Array[VBoxContainer] = [%Attribution as VBoxContainer, %Courtesy as VBoxContainer, %Fonts as VBoxContainer]
@onready var _headings: Array[Label] = [%AttributionHeading as Label, %CourtesyHeading as Label, %FontsHeading as Label]


## The text the screen shows for `entry`: its Spanish line, marked when modified. A CC BY pack's
## licence address is given once, under its group's heading (menu-clarity design D9).
static func entry_text(entry: ArtCredit) -> String:
	var text: String = entry.line_es
	if entry.modified:
		text += MODIFIED_MARK
	return text


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
	more.text = MORE_BELOW
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _show_more())
	_list.resized.connect(_show_more)
	scroll.resized.connect(_show_more)
	back_button.grab_focus()


## Lists `shown`'s entries in screen order (ArtCredits.in_screen_order), each group under its
## heading; a group with no entry hides its heading.
func show_credits(shown: ArtCredits) -> void:
	credits = shown
	for group: VBoxContainer in _groups:
		for old: Node in group.get_children():
			group.remove_child(old)
			old.queue_free()
	for entry: ArtCredit in shown.in_screen_order():
		_groups[entry.group()].add_child(_entry_label(entry))
	for i: int in _groups.size():
		_headings[i].visible = _groups[i].get_child_count() > 0
		_groups[i].visible = _headings[i].visible
	_headings[0].text = ATTRIBUTION_HEADING
	for entry: ArtCredit in shown.in_screen_order():
		if entry.attribution_required and not entry.licence_url.is_empty():
			_headings[0].text = "%s\n%s" % [ATTRIBUTION_HEADING, entry.licence_url]
			break
	_show_more.call_deferred()


## Whether more of the list lies below the view.
func more_below() -> bool:
	return float(scroll.scroll_vertical) + scroll.size.y < _list.size.y - 1.0


func _show_more() -> void:
	if is_node_ready():
		more.visible = more_below()


## The entry labels, top to bottom.
func entry_labels() -> Array[Label]:
	var found: Array[Label] = []
	for group: VBoxContainer in _groups:
		for child: Node in group.get_children():
			var label := child as Label
			if label != null:
				found.append(label)
	return found


## Every line the list shows, headings included, top to bottom.
func list_texts() -> Array[String]:
	var texts: Array[String] = []
	for i: int in _groups.size():
		if _headings[i].visible:
			texts.append(_headings[i].text)
		for child: Node in _groups[i].get_children():
			texts.append((child as Label).text)
	return texts


## The entries' texts, top to bottom.
func entry_texts() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in entry_labels():
		texts.append(label.text)
	return texts


## The whole list's height, which the view scrolls through when it is taller.
func list_height() -> float:
	return _list.size.y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
	elif event.is_action_pressed(&"ui_down", true):
		scroll.scroll_vertical += SCROLL_STEP_PX
	elif event.is_action_pressed(&"ui_up", true):
		scroll.scroll_vertical -= SCROLL_STEP_PX
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _entry_label(entry: ArtCredit) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"CreditsLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = entry_text(entry)
	return label
