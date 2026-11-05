class_name RunHud
extends CanvasLayer
## ui-shell "HUD layout": the run's HUD inside a 640×360 budget. Meters top-left (labels inside
## the bars, Brogue), the day phase top-centre, teammates top-right in co-op only (Brogue's
## sidebar, teammates first), a name tag over each teammate, the pause menu (solo only, it
## refuses in co-op) and, in co-op only, the quick-chat wheel. The bottom band stays free for
## the inventory.

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

var session: CoopSession
var local_peer: int = CoopSession.HOST_ID
var solo: bool = true
## The quick-chat wheel, or null in solo.
var wheel: QuickChatWheel
var pause_menu: PauseMenu

@onready var meters: MetersHud = %Meters
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
	for peer_id: int in session.peer_ids():
		_follow(peer_id)
	refresh()


func _process(_delta: float) -> void:
	if session != null:
		refresh()


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
		meters.bind(player.meters)
		return
	if player.has_node(NodePath(TAG_NAME)):
		return
	var tag := NAME_TAG_SCENE.instantiate() as NameTag
	tag.name = TAG_NAME
	tag.player_name = session.player_name(peer_id)
	tag.meters = player.meters
	player.add_child(tag)
