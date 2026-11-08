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
## no input (`input_open`); the shell says when a screen shows.

const WHEEL_SCENE: PackedScene = preload("res://scenes/ui/quick_chat_wheel.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const NAME_TAG_SCENE: PackedScene = preload("res://scenes/ui/name_tag.tscn")
const PHASE_NAMES: Dictionary[DataEnums.DayPhase, String] = {
	DataEnums.DayPhase.DAWN: "Amanecer",
	DataEnums.DayPhase.DAY: "Día",
	DataEnums.DayPhase.DUSK: "Atardecer",
	DataEnums.DayPhase.NIGHT: "Noche",
}
const TAG_NAME: StringName = &"NameTag"
const HUD_PANEL: StringName = &"HudPanel"
## HUD pieces that are not HUD panels but that the interact prompt keeps clear of too (secret-cay's
## needle and note join it).
const AVOID_GROUP: StringName = &"hud_avoid"

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
## The crafting list is open and holds the input: the use button does nothing meanwhile.
var list_open: bool = false
## The world's view (GameShell's WorldView), which world-anchored marks are mapped through; null
## draws them at the world canvas's own pixels.
var world_view: Control = null

@onready var meters: MetersHud = %Meters
@onready var strip: InventoryStrip = %Strip
@onready var prompt: InteractPrompt = %Prompt
@onready var phase_label: Label = %Phase
@onready var teammates_panel: Control = %TeammatesPanel
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
	if not event is InputEventMouseButton or not strip.accepts_input():
		return
	if event.is_action_pressed(InventoryStrip.NEXT_ACTION) or event.is_action_pressed(InventoryStrip.PREV_ACTION):
		strip.step(1 if event.is_action_pressed(InventoryStrip.NEXT_ACTION) else -1)
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
		if child == prompt:
			continue
		var box := child as PanelContainer
		if box != null and box.theme_type_variation == HUD_PANEL and box.is_visible_in_tree():
			into.append(box.get_global_rect())
		_collect_panels(child, into)


func refresh() -> void:
	phase_label.text = phase_name(session.climate)
	if solo:
		return
	var others: Array[int] = []
	for peer_id: int in session.peer_ids():
		if peer_id != local_peer:
			others.append(peer_id)
	while _teammates.get_child_count() > others.size():
		var extra := _teammates.get_child(_teammates.get_child_count() - 1)
		_teammates.remove_child(extra)
		extra.queue_free()
	while _teammates.get_child_count() < others.size():
		var row := Label.new()
		_teammates.add_child(row)
	for i: int in others.size():
		var player := session.body(others[i])
		var state := state_word(player, session.is_dropped(others[i]))
		(_teammates.get_child(i) as Label).text = ("%s %d %s" % [session.player_name(others[i]), roundi(player.meters.health), state]).strip_edges()


## The teammate rows, top to bottom ("Papo 0 Caído").
func teammate_rows() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _teammates.get_children():
		texts.append((child as Label).text)
	return texts


# A rejoined player took back its body (coop-reconnect): if that is this peer, it is now the
# local player, with no tag and its meters in the panel.
func _on_player_rebound(_old_peer: int, new_peer: int, player: PlayerBody) -> void:
	if new_peer != local_peer:
		return
	var tag := player.get_node_or_null(NodePath(TAG_NAME))
	if tag != null:
		player.remove_child(tag)
		tag.queue_free()
	_bind_local(player)


# Everything that shows or acts for the local player follows `player` from now on.
func _bind_local(player: PlayerBody) -> void:
	meters.bind(player.meters)
	strip.bind(player, session)
	prompt.bind(player, session)


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
