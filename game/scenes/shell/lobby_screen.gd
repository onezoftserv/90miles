class_name LobbyScreen
extends Control
## ui-shell "Lobby": who is aboard (the host first and marked), the host's start button and the
## addresses others join, or, on a client, that it waits for the host. While a slower backend
## opens the host's session it says OPENING and offers only Salir. Leaving goes back to the title
## (back_requested); the shell does the network side.
## menu-clarity design D7: four seats under "A bordo (n/4)", empty ones "Libre"; the host's own
## addresses first; a lobby opened by "Otra vez" says so; and the host's "Cerrar partida" asks first
## while anyone else is aboard, with "Cancelar" focused.

signal start_requested
signal back_requested

const HOST_TAG: String = " (anfitrión)"
## The host's lobby while the backend opens the session (show_opening()).
const OPENING: String = "Abriendo la partida…"
const SEATS: int = 4
const FREE_SEAT: String = "Libre"
const HEADING: String = "A bordo"
const HEADING_COUNT: String = "A bordo (%d/%d)"
const REMATCH_LINE: String = "Otro viaje con el mismo grupo."
const LEAVE_TEXT: String = "Salir"
const CLOSE_TEXT: String = "Cerrar partida"
const CLOSE_QUESTION: String = "¿Cerrar la partida?"
const CLOSE_LINE: String = "Los demás vuelven al inicio."
const CLOSE_ACTION: String = "Cerrar"
const CONFIRM_SCENE: PackedScene = preload("res://scenes/ui/confirm_box.tscn")

## Set before the screen enters the tree, or later (the buttons follow).
var is_host: bool = true:
	set(value):
		is_host = value
		_refresh_role()

## A lobby opened by "Otra vez" (the shell sets it): a line under the heading says so.
var rematch: bool = false:
	set(value):
		rematch = value
		if is_node_ready():
			rematch_line.visible = value
## The host's close question while it is open, else null.
var confirm: ConfirmBox = null

# The host's session is still opening: no roster, no start, only Salir.
var _opening: bool = false
# How many seats are filled.
var _aboard: int = 0

@onready var start_button: Button = %Start
@onready var leave_button: Button = %Leave
@onready var waiting: Label = %Waiting
@onready var note: Label = %Note
@onready var addresses: Label = %Addresses
@onready var heading: Label = %Heading
@onready var rematch_line: Label = %RematchLine
@onready var _rows: VBoxContainer = %Rows


## The LAN IPv4 addresses worth showing (no loopback, no link-local), sorted: NetPeers.lan_addresses().
static func local_addresses(all: PackedStringArray) -> PackedStringArray:
	return NetPeers.lan_addresses(all)


func _ready() -> void:
	start_button.pressed.connect(start_requested.emit)
	leave_button.pressed.connect(_on_leave)
	rematch_line.text = REMATCH_LINE
	rematch_line.visible = rematch
	_refresh_role()


# Esc leaves a client's lobby. The host's lobby closes for everyone, so only Salir does that.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not is_host:
		back_requested.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## Four seats: the host first, then the others in join order, then "Libre"; the heading counts
## who is aboard. While the session opens there are no seats.
func show_roster(roster: Dictionary[int, String], host_id: int = CoopSession.HOST_ID) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_aboard = 0
	if roster.has(host_id):
		_add_row(roster[host_id] + HOST_TAG)
	for peer_id: int in roster:
		if peer_id != host_id:
			_add_row(roster[peer_id])
	_aboard = _rows.get_child_count()
	if _opening:
		heading.text = HEADING
		return
	for i: int in range(_aboard, SEATS):
		_add_row(FREE_SEAT, true)
	heading.text = HEADING_COUNT % [_aboard, SEATS]


## The host's lobby while a slower backend opens the session: nobody listed, no "Empezar viaje",
## note or addresses, Waiting says OPENING and Salir (which cancels) has the focus. The shell shows
## a new lobby once hosting is ready.
func show_opening() -> void:
	_opening = true
	is_host = true
	if is_node_ready():
		show_roster({} as Dictionary[int, String])


func set_addresses(list: PackedStringArray) -> void:
	addresses.text = "Tu IP: %s" % ", ".join(list) if not list.is_empty() else ""


## The filled seats' names, top to bottom.
func rows() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _rows.get_children():
		if not child.has_meta(&"free"):
			texts.append((child as Label).text)
	return texts


## Every seat's text, filled or "Libre".
func seats() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _rows.get_children():
		texts.append((child as Label).text)
	return texts


# The host's "Cerrar partida" asks first while anyone else is aboard; a client's (or an opening
# lobby's) "Salir" leaves at once.
func _on_leave() -> void:
	if is_host and not _opening and _aboard > 1:
		ask_close()
	else:
		back_requested.emit()


## Opens the host's close question, "Cancelar" focused.
func ask_close() -> void:
	if confirm != null:
		return
	confirm = CONFIRM_SCENE.instantiate() as ConfirmBox
	add_child(confirm)
	confirm.ask(CLOSE_QUESTION, CLOSE_LINE, CLOSE_ACTION, true)
	confirm.confirmed.connect(func() -> void:
		_close_confirm()
		back_requested.emit())
	confirm.cancelled.connect(func() -> void:
		_close_confirm()
		leave_button.grab_focus())


func _close_confirm() -> void:
	if confirm != null:
		confirm.queue_free()
		confirm = null


func _add_row(text: String, free: bool = false) -> void:
	var row := Label.new()
	row.theme_type_variation = &"PanelLabel"
	row.text = text
	if free:
		row.set_meta(&"free", true)
	_rows.add_child(row)


func _refresh_role() -> void:
	if not is_node_ready():
		return
	var host_view: bool = is_host and not _opening
	start_button.visible = host_view
	note.visible = host_view
	addresses.visible = host_view
	waiting.visible = not host_view
	leave_button.text = CLOSE_TEXT if host_view else LEAVE_TEXT
	if _opening:
		waiting.text = OPENING
	(start_button if host_view else leave_button).grab_focus()
