class_name CraftList
extends Control
## The workbench crafting list (inventory-hud "Workbench crafting list", "Crafting list contents",
## "Choosing a recipe"; design D2, D7): opened by the local player's interact press on a bench, at
## the left edge above the strip's lines (4,162 to 244,302) on a HUD panel. It never pauses. It
## lists, sorted by Spanish name, every known workbench recipe that makes an item and every known
## build-site recipe whose output is a structure, read from the recipe files and the player's
## crafter, so a new recipe file shows with no script change; the highlighted one lists each input
## and tag as carried/needed, each required tool as "Con qué <tool phrase>" and the speed-up tool as
## "Más rápido: <tool phrase>". What is carried short is dimmed, the speed-up tool never; a
## workbench row missing anything is dimmed, a build-site row never. Rows and the highlighted
## recipe's lines stay inside the panel: a list too long for it scrolls, keeping the highlighted
## row on show. The arrows, D-pad up and
## down, the wheel (routed from RunHud) and the pointer move the highlight; interact (E, A) or a
## click chooses. A choice this peer can see is refused (a dimmed row, or a site of that recipe
## still unfinished) shows its line and keeps the list open; otherwise the craft request goes to
## the host (`CoopSession.craft`, which starts the craft or places the site) and the list closes.
## It also closes when the player leaves the bench's reach, goes down or leaves, a screen shows,
## or pause is pressed, which it takes before the pause menu can. While it is open, and until
## interact is let go after it closes, the player's intent carries no interact press
## (`PlayerBody.hud_holds_interact`), so the host never sees a press meant for the list.

## A craft request went to the host: the recipe and the bench's path in the session.
signal craft_sent(recipe_id: StringName, station_path: NodePath)
signal opened
signal closed

const RECT: Rect2 = Rect2(4.0, 162.0, 240.0, 140.0)
## Lines start inside the panel's edge.
const PADDING: Vector2 = Vector2(4.0, 3.0)
const LINE_HEIGHT: float = 10.0
## Glyphs of the HUD's font that fit a row inside the padding: 29.
const ROW_MAX_CHARS: int = floori((RECT.size.x - 2.0 * PADDING.x) / HudStyle.GLYPH_PX)
## The highlighted recipe's lines start this far below the last row.
const DETAIL_GAP: float = 4.0
const DETAIL_INDENT: float = 8.0
## Lines the panel holds, rows and the highlighted recipe's lines together, inside its padding and
## below the gap: 13.
const PANEL_LINES: int = floori((RECT.size.y - 2.0 * PADDING.y - DETAIL_GAP) / LINE_HEIGHT)
const DIM: Color = Color(1.0, 1.0, 1.0, 0.4)
const FULL: Color = Color(1.0, 1.0, 1.0, 1.0)
## The highlighted row, in the selection's sun yellow; the others keep the theme's label colour.
const HIGHLIGHT: Color = HudStyle.SUN
const INTERACT_ACTION: StringName = &"interact"
const PAUSE_ACTION: StringName = &"pause"
const UP_ACTION: StringName = &"list_up"
const DOWN_ACTION: StringName = &"list_down"

## The local player, or null.
var body: PlayerBody = null
var session: CoopSession = null
var text: HudText = HudText.load_default()
## Where a refusal shows; RunHud sets it.
var notice: HudNotice = null
## Whether the HUD takes input now (no pause menu, summary or host-lost screen); RunHud answers.
var input_open: Callable = func() -> bool: return true
var screen_shown: bool = false
## The bench the list is open at, or null.
var bench: Workbench = null
var highlighted: int = 0
var _open: bool = false
var _recipes: Array[RecipeData] = []
# One label per row on show: row label k shows recipe _first_row + k.
var _rows: Array[Label] = []
var _first_row: int = 0
var _details: Array[Label] = []
# The body whose interact press this list holds, until interact is let go.
var _held_body: PlayerBody = null

@onready var panel: PanelContainer = $Panel


## Whether the list offers `recipe`: a known workbench recipe that makes an item, or a known
## build-site recipe whose output is a structure (vessels stay with their routes); a site the
## host places by the same rule (`SitePlacer.places`).
static func offers(recipe: RecipeData) -> bool:
	if recipe == null or recipe.availability != RecipeData.Availability.KNOWN:
		return false
	if recipe.build_site:
		return SitePlacer.places(recipe)
	return recipe.station == RecipeData.Station.WORKBENCH and recipe.output_kind == RecipeData.OutputKind.ITEM


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs while the solo pause freezes the run, so a held interact is let go of there too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.position = RECT.position
	panel.size = RECT.size
	visible = false


## Follows `player` from now on; an open list closes.
func bind(player: PlayerBody, run_session: CoopSession = null) -> void:
	close()
	_let_go()
	body = player
	session = run_session


func set_screen_shown(value: bool) -> void:
	screen_shown = value
	if value:
		close()


func is_open() -> bool:
	return _open


## Opens the list at `at` for the bound player.
func open(at: Workbench) -> void:
	if not is_instance_valid(body) or not is_instance_valid(at) or screen_shown or not input_open.call():
		return
	bench = at
	_recipes = _offered()
	highlighted = 0
	_first_row = 0
	_hold()
	_open = true
	visible = true
	_show()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	bench = null
	closed.emit()


## Whether a list input counts now: the list is open, the HUD takes input, and no text field is
## being typed in.
func accepts_input() -> bool:
	if not _open or not input_open.call():
		return false
	return get_viewport() == null or not get_viewport().gui_get_focus_owner() is LineEdit


## Moves the highlight one row down (1) or up (-1), wrapping round.
func step(direction: int) -> void:
	if _recipes.is_empty():
		return
	highlight(posmod(highlighted + direction, _recipes.size()))


func highlight(index: int) -> void:
	if index < 0 or index >= _recipes.size() or index == highlighted:
		return
	highlighted = index
	_show()


## Chooses row `index`: refused with its line, the list staying open, or sent to the host, the
## list closing. Returns whether it was sent.
func choose(index: int) -> bool:
	if not _open or index < 0 or index >= _recipes.size():
		return false
	var recipe := _recipes[index]
	var refusal: StringName = &""
	if not recipe.build_site and not body.crafter.can_craft(recipe):
		refusal = &"missing_materials"
	elif recipe.build_site and has_unfinished_site(recipe.id):
		refusal = &"in_progress"
	if not refusal.is_empty():
		if notice != null:
			notice.show_line(text.refusal(refusal, _locale()))
		return false
	var station_path: NodePath = session.get_path_to(bench) if is_instance_valid(session) else NodePath()
	if is_instance_valid(session):
		session.craft(recipe.id, station_path)
	craft_sent.emit(recipe.id, station_path)
	close()
	return true


## Whether a site of `recipe_id` stands unfinished in the session, as this peer has it.
func has_unfinished_site(recipe_id: StringName) -> bool:
	return is_instance_valid(session) and session.has_unfinished_site(recipe_id)


## How many recipes the list offers, on show or scrolled out of it.
func recipe_count() -> int:
	return _recipes.size()


## The texts of the rows on show, top first.
func row_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in _rows:
		if label.visible:
			texts.append(label.text)
	return texts


## The label showing recipe `index`, or null while it is scrolled out of the panel.
func row_label(index: int) -> Label:
	var at: int = index - _first_row
	return _rows[at] if at >= 0 and at < _rows.size() and _rows[at].visible else null


## Whether recipe `index`'s row is dimmed: a workbench recipe missing something.
func row_dimmed(index: int) -> bool:
	return index >= 0 and index < _recipes.size() and _is_dimmed(_recipes[index])


## The highlighted recipe's lines: its inputs, tags and tools.
func detail_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in _details:
		if label.visible:
			texts.append(label.text)
	return texts


func detail_dimmed(index: int) -> bool:
	return _details[index].modulate.a < 1.0


# Pause first, before the pause menu's _unhandled_input; then the list's own keys and buttons.
func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	if event.is_action_pressed(PAUSE_ACTION):
		close()
		get_viewport().set_input_as_handled()
		return
	if not accepts_input():
		return
	if event.is_action_pressed(UP_ACTION):
		step(-1)
	elif event.is_action_pressed(DOWN_ACTION):
		step(1)
	elif event.is_action_pressed(INTERACT_ACTION):
		choose(highlighted)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _open and not _may_stay_open():
		close()
	elif _open:
		_show()
	if _held_body != null and not _open and not Input.is_action_pressed(INTERACT_ACTION):
		_let_go()


func _may_stay_open() -> bool:
	if not is_instance_valid(body) or not is_instance_valid(bench) or screen_shown or not input_open.call():
		return false
	if body.downed or body.left_island:
		return false
	return body.global_position.distance_to(bench.global_position) <= PlayerBody.HOLD_REACH_PX


func _hold() -> void:
	if _held_body != body:
		_let_go()
	_held_body = body
	body.hud_holds_interact = true


func _let_go() -> void:
	if is_instance_valid(_held_body):
		_held_body.hud_holds_interact = false
	_held_body = null


func _offered() -> Array[RecipeData]:
	var found: Array[RecipeData] = []
	for recipe: RecipeData in body.crafter.known_recipes():
		if offers(recipe):
			found.append(recipe)
	found.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.name_es < b.name_es)
	return found


# Rows, then the highlighted recipe's lines, from the bound player's inventory as this peer has it.
# The rows on show are the window of them that fits beside those lines and holds the highlight.
func _show() -> void:
	var locale := _locale()
	var lines: Array[Array] = []
	if not _recipes.is_empty():
		lines = _detail_lines(_recipes[highlighted])
		lines.resize(mini(lines.size(), PANEL_LINES - 1))
	var shown: int = mini(_recipes.size(), PANEL_LINES - lines.size())
	_first_row = clampi(_first_row, highlighted - shown + 1, highlighted)
	_first_row = clampi(_first_row, 0, _recipes.size() - shown)
	_rows = _pool(_rows, shown, true)
	for slot: int in shown:
		var index: int = _first_row + slot
		var recipe := _recipes[index]
		var row := _rows[slot]
		row.text = InventoryStrip.cut(recipe.get_display_name(locale), ROW_MAX_CHARS)
		row.position = RECT.position + PADDING + Vector2(0.0, slot * LINE_HEIGHT)
		row.modulate = DIM if _is_dimmed(recipe) else FULL
		if index == highlighted:
			row.add_theme_color_override(&"font_color", HIGHLIGHT)
		else:
			row.remove_theme_color_override(&"font_color")
	_details = _pool(_details, lines.size(), false)
	var top: float = RECT.position.y + PADDING.y + shown * LINE_HEIGHT + DETAIL_GAP
	for i: int in lines.size():
		var label := _details[i]
		label.text = InventoryStrip.cut(lines[i][0], ROW_MAX_CHARS - 1)
		label.position = Vector2(RECT.position.x + PADDING.x + DETAIL_INDENT, top + i * LINE_HEIGHT)
		label.modulate = DIM if lines[i][1] else FULL


# A workbench recipe missing an input or a tool; a build-site row never is.
func _is_dimmed(recipe: RecipeData) -> bool:
	return not recipe.build_site and not body.crafter.can_craft(recipe)


# Each line of `recipe` as [text, dimmed]: inputs and tags as carried/needed, tools, the speed-up.
func _detail_lines(recipe: RecipeData) -> Array[Array]:
	var locale := _locale()
	var inventory := body.inventory
	var lines: Array[Array] = []
	var carried_format: String = text.line(&"carried", locale)
	for id: StringName in recipe.inputs:
		var have: int = inventory.count_id(id)
		lines.append([carried_format % [have, recipe.inputs[id], HudText.item_name(id, locale)], have < recipe.inputs[id]])
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var carried: int = inventory.count_tag(tag)
		lines.append([carried_format % [carried, recipe.input_tags[tag], text.tag_name(tag, locale)], carried < recipe.input_tags[tag]])
	for capability: DataEnums.Capability in recipe.tools:
		lines.append([text.line(&"needs_tool", locale) % text.tool_phrase(capability, locale), inventory.capability_slot(capability) < 0])
	if recipe.fast_tool != DataEnums.Capability.NONE:
		lines.append([text.line(&"faster", locale) % text.tool_phrase(recipe.fast_tool, locale), false])
	return lines


# `labels` with exactly `count` shown, made as needed, each as wide as the panel leaves it (a
# detail line is indented); rows take clicks and the pointer, never focus.
func _pool(labels: Array[Label], count: int, as_rows: bool) -> Array[Label]:
	while labels.size() < count:
		var label := Label.new()
		var width: float = RECT.size.x - 2.0 * PADDING.x - (0.0 if as_rows else DETAIL_INDENT)
		label.size = Vector2(width, LINE_HEIGHT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.focus_mode = Control.FOCUS_NONE
		label.mouse_filter = Control.MOUSE_FILTER_STOP if as_rows else Control.MOUSE_FILTER_IGNORE
		if as_rows:
			var slot: int = labels.size()
			label.mouse_entered.connect(_on_row_pointed.bind(slot))
			label.gui_input.connect(_on_row_input.bind(slot))
		add_child(label)
		labels.append(label)
	for i: int in labels.size():
		labels[i].visible = i < count
	return labels


# The pointer entered row label `slot`, which shows recipe _first_row + slot.
func _on_row_pointed(slot: int) -> void:
	if accepts_input():
		highlight(_first_row + slot)


func _on_row_input(event: InputEvent, slot: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if accepts_input():
		var index: int = _first_row + slot
		highlight(index)
		choose(index)


func _locale() -> String:
	return CoopSession.locale_of(session)
