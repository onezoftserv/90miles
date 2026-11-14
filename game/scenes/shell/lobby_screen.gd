class_name LobbyScreen
extends Control
## ui-shell "Lobby": who is aboard (the host first and marked), the host's start button and the
## addresses others join, or, on a client, that it waits for the host. While a slower backend
## opens the host's session it says OPENING and offers only Salir. Leaving goes back to the title
## (back_requested); the shell does the network side.

signal start_requested
signal back_requested

const HOST_TAG: String = " (anfitrión)"
## The host's lobby while the backend opens the session (show_opening()).
const OPENING: String = "Abriendo la partida…"

## Set before the screen enters the tree, or later (the buttons follow).
var is_host: bool = true:
	set(value):
		is_host = value
		_refresh_role()

# The host's session is still opening: no roster, no start, only Salir.
var _opening: bool = false

@onready var start_button: Button = %Start
@onready var leave_button: Button = %Leave
@onready var waiting: Label = %Waiting
@onready var note: Label = %Note
@onready var addresses: Label = %Addresses
@onready var _rows: VBoxContainer = %Rows


## The LAN IPv4 addresses worth showing (no loopback, no link-local), sorted: NetPeers.lan_addresses().
static func local_addresses(all: PackedStringArray) -> PackedStringArray:
	return NetPeers.lan_addresses(all)


func _ready() -> void:
	start_button.pressed.connect(start_requested.emit)
	leave_button.pressed.connect(back_requested.emit)
	_refresh_role()


# Esc leaves a client's lobby. The host's lobby closes for everyone, so only Salir does that.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not is_host:
		back_requested.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## One row per player: the host first, then the others in join order.
func show_roster(roster: Dictionary[int, String], host_id: int = CoopSession.HOST_ID) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if roster.has(host_id):
		_add_row(roster[host_id] + HOST_TAG)
	for peer_id: int in roster:
		if peer_id != host_id:
			_add_row(roster[peer_id])


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


func rows() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _rows.get_children():
		texts.append((child as Label).text)
	return texts


func _add_row(text: String) -> void:
	var row := Label.new()
	row.theme_type_variation = &"PanelLabel"
	row.text = text
	_rows.add_child(row)


func _refresh_role() -> void:
	if not is_node_ready():
		return
	var host_view: bool = is_host and not _opening
	start_button.visible = host_view
	note.visible = host_view
	addresses.visible = host_view
	waiting.visible = not host_view
	if _opening:
		waiting.text = OPENING
	(start_button if host_view else leave_button).grab_focus()
