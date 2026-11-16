class_name RunHud
extends CanvasLayer
## ui-shell "HUD layout": the run's HUD inside a 640×360 budget. Meters top-left (labels inside
## the bars, Brogue), the day phase top-centre, teammates top-right in co-op only (Brogue's
## sidebar, teammates first), a name tag over each teammate, the pause menu (solo only, it
## refuses in co-op) and, in co-op only, the quick-chat wheel. The bottom band holds the local
## player's inventory strip with its lines (inventory-hud), bound to the local body in one place,
## `_bind_local`, so a rejoined client's reclaimed body gets it too, as does the interact prompt
## over what the local player can reach, mapped from the world view into the HUD (`world_to_hud`)
## and kept off every HUD panel (`panel_rects`). Key labels follow the last device the player used
## (`device`). While the pause menu, the run summary or the host-lost screen is up, the HUD takes
## no input (`input_open`); the shell says when a screen shows. The local player's press on a
## workbench opens the crafting list (`craft_list`), and on a flavour sign the sign note (`sign_note`);
## each holds the input while open. A closed-eye
## mark shows over every hidden player (`marks`), placed like the prompt, and an open one over every lit
## player whose spot meter is above 0. While a patrol boat is on the horizon, a light or hull shows on
## the horizon band (`patrol_horizon`). Under the day phase, the
## broken compass's needle (`needle`, secret-cay) shows while the local player carries it, and
## under it the note label (`note_label`) shows the chest's note and the map's text for a while.
## In co-op, a local player who is dead or waits on the shore watches a living teammate
## (`spectate`, ui-shell "Spectating a teammate"): the bottom band's `watching_panel` names them
## with the switch keys, the meters panel shows their meters and the strip hides; the step keys
## (`SPECTATE_PREV`, `SPECTATE_NEXT`) move between teammates. Solo never watches.

const WHEEL_SCENE: PackedScene = preload("res://scenes/ui/quick_chat_wheel.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const NAME_TAG_SCENE: PackedScene = preload("res://scenes/ui/name_tag.tscn")
const TEAMMATE_SCENE: PackedScene = preload("res://scenes/ui/teammate_block.tscn")
const PHASE_NAMES: Dictionary[DataEnums.DayPhase, String] = {
	DataEnums.DayPhase.DAWN: "Amanecer",
	DataEnums.DayPhase.DAY: "Día",
	DataEnums.DayPhase.DUSK: "Atardecer",
	DataEnums.DayPhase.NIGHT: "Noche",
}
const TAG_NAME: StringName = &"NameTag"
const HUD_PANEL: StringName = &"HudPanel"
## Every HUD window variation the prompt keeps clear of: the dark window, its thin rows and the
## strip's backdrop (hud-window-kit design D8).
const HUD_PANELS: Array[StringName] = [&"HudPanel", &"HudPanelThin", &"HudPanelTight", &"HudStripBack"]
## HUD pieces that are not HUD panels but that the interact prompt keeps clear of too (secret-cay's
## needle and note join it).
const AVOID_GROUP: StringName = &"hud_avoid"
## The keys that step a spectator's view (ui-shell "Switching the watched teammate"): the walk keys
## A and D, the arrows (the engine's ui_left and ui_right), the D-pad and the mouse wheel. Each is
## an action that does nothing else for a dead or waiting player, so no input is bound twice
## (inventory-hud "Inputs do not collide"). A stick is not a step: it repeats while held.
const SPECTATE_PREV: Array[StringName] = [&"move_left", &"ui_left", &"slot_prev"]
const SPECTATE_NEXT: Array[StringName] = [&"move_right", &"ui_right", &"slot_next"]

var session: CoopSession
var local_peer: int = CoopSession.HOST_ID
var solo: bool = true
## The quick-chat wheel, or null in solo.
var wheel: QuickChatWheel
var pause_menu: PauseMenu
## The last device the local player used; the HUD's key labels follow it.
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## The refusal line above the strip.
var notice: HudNotice
## The run summary or the host-lost screen is over the run (GameShell sets it).
var screen_shown: bool = false
## The crafting list or the sign note is open and holds the input: the use button does nothing
## meanwhile.
var list_open: bool = false
## The world's view (GameShell's WorldView), which world-anchored marks are mapped through; null
## draws them at the world canvas's own pixels.
var world_view: Control = null
## Whom the local player watches while dead or waiting (ui-shell "Spectating a teammate").
var spectate: SpectateView = SpectateView.new()
## The local player's body, or null before it spawns.
var _local_body: PlayerBody = null
var _text: HudText = HudText.load_default()

@onready var meters: MetersHud = %Meters
@onready var strip: InventoryStrip = %Strip
@onready var prompt: InteractPrompt = %Prompt
@onready var craft_list: CraftList = %CraftList
@onready var sign_note: SignNote = %SignNote
@onready var needle: CompassNeedle = %Needle
@onready var note_label: NoteLabel = %NoteLabel
@onready var marks: BodyMarks = %Marks
@onready var patrol_horizon: PatrolHorizon = %PatrolHorizon
## damage-feedback: the change floats over every player (survival-meters "Change floats over the
## body"), made here beside the marks.
var floats: ChangeFloats = ChangeFloats.new()
## guardacostas-capture: the scene panel (la_captura's speaker and line), made here and bound to the
## session's capture scene.
var scene_panel: ScenePanel = null
@onready var phase_label: Label = %Phase
@onready var teammates_panel: Control = %TeammatesPanel
@onready var watching_panel: PanelContainer = %WatchingPanel
@onready var watching_label: Label = %Watching
@onready var _teammates: VBoxContainer = %Teammates


## "Mediodía" for the day's 10:00-16:00 window, else the phase's Spanish name.
static func phase_name(climate: ClimateState) -> String:
	if climate.phase == DataEnums.DayPhase.DAY and climate.midday:
		return "Mediodía"
	return PHASE_NAMES.get(climate.phase, "")


## "Muerto", "Desconectado", "Caído" or "" for a teammate.
static func state_word(player: PlayerBody, dropped: bool) -> String:
	if player.meters.dead:
		return "Muerto"
	if dropped:
		return "Desconectado"
	if player.downed:
		return "Caído"
	return ""


func bind(run_session: CoopSession, local_peer_id: int, is_solo: bool) -> void:
	session = run_session
	local_peer = local_peer_id
	solo = is_solo
	spectate.bind(session, local_peer, solo)
	teammates_panel.visible = not solo
	if not solo:
		wheel = WHEEL_SCENE.instantiate() as QuickChatWheel
		wheel.phrases = session.phrases
		add_child(wheel)
		wheel.rebuild()
		wheel.phrase_picked.connect(session.say)
	pause_menu = PAUSE_SCENE.instantiate() as PauseMenu
	pause_menu.session = session
	add_child(pause_menu)
	session.player_spawned.connect(func(peer_id: int, _body: PlayerBody) -> void: _follow(peer_id))
	session.roster_updated.connect(_rename_tags)
	session.player_rebound.connect(_on_player_rebound)
	marks.bind(session)
	patrol_horizon.bind(session, local_peer_id)
	floats.locale = CoopSession.locale_of(session)
	floats.bind(session)
	scene_panel = ScenePanel.new()
	add_child(scene_panel)
	scene_panel.bind(session)
	for peer_id: int in session.peer_ids():
		_follow(peer_id)
	refresh()


func _ready() -> void:
	notice = strip.notice
	strip.input_open = input_open
	strip.list_open = func() -> bool: return list_open
	prompt.input_open = input_open
	prompt.list_open = func() -> bool: return list_open
	prompt.to_hud = world_to_hud
	prompt.avoid = panel_rects
	prompt.marks = marks
	craft_list.notice = notice
	craft_list.input_open = input_open
	craft_list.opened.connect(func() -> void: list_open = true)
	craft_list.closed.connect(func() -> void: list_open = false)
	prompt.bench_pressed.connect(craft_list.open)
	sign_note.input_open = input_open
	sign_note.opened.connect(func() -> void: list_open = true)
	sign_note.closed.connect(func() -> void: list_open = false)
	prompt.sign_pressed.connect(sign_note.open)
	marks.to_hud = world_to_hud
	floats.name = &"Floats"
	add_child(floats)
	move_child(floats, marks.get_index() + 1)
	floats.to_hud = world_to_hud


func _process(_delta: float) -> void:
	if session != null:
		refresh()


# Before the GUI: the last device, and the wheel, which a slot under the pointer would swallow.
func _input(event: InputEvent) -> void:
	var next: InputLabels.Device = InputLabels.device_after(event, device)
	if next != device:
		device = next
		strip.set_device(device)
		prompt.set_device(device)
		sign_note.set_device(device)
	if _step_spectate(event):
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var direction: int = 0
	if event.is_action_pressed(InventoryStrip.NEXT_ACTION):
		direction = 1
	elif event.is_action_pressed(InventoryStrip.PREV_ACTION):
		direction = -1
	if direction == 0:
		return
	# The wheel moves the crafting list while it is open, the strip's selection otherwise.
	if craft_list.is_open():
		if craft_list.accepts_input():
			craft_list.step(direction)
			get_viewport().set_input_as_handled()
	elif strip.accepts_input():
		strip.step(direction)
		get_viewport().set_input_as_handled()


## Whether the HUD takes input now: no screen over the run and no pause.
func input_open() -> bool:
	if screen_shown or not is_inside_tree() or get_tree().paused:
		return false
	return pause_menu == null or not pause_menu.visible


## The run summary or the host-lost screen shows (true) or went away: the HUD hides its strip and
## takes no input meanwhile.
func set_screen_shown(value: bool) -> void:
	screen_shown = value
	strip.set_screen_shown(value)
	prompt.screen_shown = value
	craft_list.set_screen_shown(value)
	sign_note.set_screen_shown(value)
	marks.screen_shown = value
	patrol_horizon.screen_shown = value
	floats.screen_shown = value
	if scene_panel != null:
		scene_panel.screen_shown = value
	refresh_watching()


## A point of the world's canvas (the world view's pixels, camera applied) in HUD pixels.
func world_to_hud(point: Vector2) -> Vector2:
	if is_instance_valid(world_view):
		return world_view.get_global_transform() * point
	return point


## The rects of every HUD panel on show and every piece of AVOID_GROUP, which world-anchored
## marks keep clear of; the prompt's own panel is not one.
func panel_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	_collect_panels(self, rects)
	for node: Node in get_tree().get_nodes_in_group(AVOID_GROUP):
		var piece := node as Control
		if piece != null and is_ancestor_of(piece) and piece.is_visible_in_tree():
			rects.append(piece.get_global_rect())
	return rects


func _collect_panels(node: Node, into: Array[Rect2]) -> void:
	for child: Node in node.get_children():
		if child == prompt or child == craft_list or child == sign_note:
			continue
		var box := child as PanelContainer
		if box != null and HUD_PANELS.has(box.theme_type_variation) and box.is_visible_in_tree():
			into.append(box.get_global_rect())
		_collect_panels(child, into)


func refresh() -> void:
	phase_label.text = phase_name(session.climate)
	refresh_watching()
	if solo:
		return
	var others: Array[int] = []
	for peer_id: int in session.peer_ids():
		if peer_id != local_peer:
			others.append(peer_id)
	# A host playing alone has no teammate yet: no empty window in the corner.
	teammates_panel.visible = not others.is_empty()
	while _teammates.get_child_count() > others.size():
		var extra := _teammates.get_child(_teammates.get_child_count() - 1)
		_teammates.remove_child(extra)
		extra.queue_free()
	while _teammates.get_child_count() < others.size():
		_teammates.add_child(TEAMMATE_SCENE.instantiate())
	for i: int in others.size():
		var player := session.body(others[i])
		var state := state_word(player, session.is_dropped(others[i]))
		(_teammates.get_child(i) as TeammateBlock).show_teammate(session.player_name(others[i]), player.meters.health, state, player.look_slot)


## The teammate rows, top to bottom ("Papo 0 Caído"): each block's name, health and state word.
func teammate_rows() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _teammates.get_children():
		texts.append((child as TeammateBlock).summary())
	return texts


## The teammate blocks, top to bottom (hud-window-kit design D7).
func teammate_blocks() -> Array[TeammateBlock]:
	var blocks: Array[TeammateBlock] = []
	for child: Node in _teammates.get_children():
		blocks.append(child as TeammateBlock)
	return blocks


## Whom the local player watches, worked out again, and the HUD that goes with it: the line in the
## bottom band, the watched teammate's meters, the strip hidden. Back to the own meters and strip
## when watching ends.
func refresh_watching() -> void:
	if session == null:
		return
	spectate.update()
	var target: PlayerBody = spectate.watched()
	var shown: SurvivalMeters = target.meters if target != null else (_local_body.meters if is_instance_valid(_local_body) else null)
	if shown != null and meters.shown() != shown:
		meters.bind(shown)
	strip.set_watching(target != null)
	watching_panel.visible = target != null and not screen_shown
	if target != null:
		var locale: String = CoopSession.locale_of(session)
		watching_label.text = watching_text(_text, session.player_name(session.peer_of(target)), spectate.watched_dropped(), device, locale)


## The spectator's line: "Mirando a: Papo  [A] [D] Cambiar", the keys for `input_device`, and
## "(desconectado)" after a disconnected teammate's name.
static func watching_text(text: HudText, watched_name: String, dropped: bool, input_device: InputLabels.Device, locale: String = "es") -> String:
	var who: String = text.line(&"watching_dropped" if dropped else &"watching", locale) % watched_name
	# The walk keys on a keyboard, the D-pad on a gamepad (the walk actions name the stick there).
	var keyboard: bool = input_device == InputLabels.Device.KEYBOARD
	var keys: String = text.line(&"watch_keys", locale) % [
		InputLabels.label_for(SPECTATE_PREV[0] if keyboard else SPECTATE_PREV[2], input_device, text, locale),
		InputLabels.label_for(SPECTATE_NEXT[0] if keyboard else SPECTATE_NEXT[2], input_device, text, locale),
	]
	return "%s  %s" % [who, keys]


## +1 when `event` presses a "step to the next teammate" key, -1 for "previous", else 0. Stick
## motion never counts.
static func spectate_step(event: InputEvent) -> int:
	if event is InputEventJoypadMotion:
		return 0
	for action: StringName in SPECTATE_NEXT:
		if event.is_action_pressed(action):
			return 1
	for action: StringName in SPECTATE_PREV:
		if event.is_action_pressed(action):
			return -1
	return 0


# A spectate key steps the view while the local player watches; true when it did.
func _step_spectate(event: InputEvent) -> bool:
	if not spectate.active() or not input_open():
		return false
	var direction: int = spectate_step(event)
	if direction == 0:
		return false
	spectate.cycle(direction)
	refresh_watching()
	return true


# A rejoined player took back its body (coop-reconnect): if that is this peer, it is now the
# local player, with no tag and its meters in the panel. A watched teammate's rebind turned its
# camera off: the view turns it on again at once.
func _on_player_rebound(_old_peer: int, new_peer: int, player: PlayerBody) -> void:
	if new_peer != local_peer:
		refresh_watching()
		return
	var tag := player.get_node_or_null(NodePath(TAG_NAME))
	if tag != null:
		player.remove_child(tag)
		tag.queue_free()
	_bind_local(player)
	# A body that died while its player was away: they watch at once.
	refresh_watching()


# Everything that shows or acts for the local player follows `player` from now on.
func _bind_local(player: PlayerBody) -> void:
	_local_body = player
	spectate.set_own(player)
	meters.bind(player.meters)
	strip.bind(player, session)
	prompt.bind(player, session)
	craft_list.bind(player, session)
	sign_note.bind(player, session)
	needle.bind(player, session)
	note_label.bind(session)


# A name can arrive after its player spawned (a join during the run): the tags follow the roster.
func _rename_tags() -> void:
	for peer_id: int in session.peer_ids():
		var player := session.body(peer_id)
		var tag := player.get_node_or_null(NodePath(TAG_NAME)) as NameTag if player != null else null
		if tag != null:
			tag.player_name = session.player_name(peer_id)


# The local player's meters fill the meters panel; every other player gets a name tag.
func _follow(peer_id: int) -> void:
	var player := session.body(peer_id)
	if player == null:
		return
	if peer_id == local_peer:
		_bind_local(player)
		return
	if player.has_node(NodePath(TAG_NAME)):
		return
	var tag := NAME_TAG_SCENE.instantiate() as NameTag
	tag.name = TAG_NAME
	tag.player_name = session.player_name(peer_id)
	tag.meters = player.meters
	player.add_child(tag)
