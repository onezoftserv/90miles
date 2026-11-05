class_name LobbyScreen
extends Control
## ui-shell "Lobby": who is aboard (the host first and marked), the host's start button and the
## addresses others join, or, on a client, that it waits for the host. Leaving goes back to the
## title (back_requested); the shell does the network side.

signal start_requested
signal back_requested

const HOST_TAG: String = " (anfitrión)"

## Set before the screen enters the tree, or later (the buttons follow).
var is_host: bool = true:
	set(value):
		is_host = value
		_refresh_role()

@onready var start_button: Button = %Start
@onready var leave_button: Button = %Leave
@onready var waiting: Label = %Waiting
@onready var note: Label = %Note
@onready var addresses: Label = %Addresses
@onready var _rows: VBoxContainer = %Rows


## The LAN IPv4 addresses worth showing (no loopback, no link-local), sorted.
static func local_addresses(all: PackedStringArray) -> PackedStringArray:
	var shown: PackedStringArray = []
	for address: String in all:
		if address.is_valid_ip_address() and not address.contains(":") \
				and not address.begins_with("127.") and not address.begins_with("169.254."):
			shown.append(address)
	shown.sort()
	return shown


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
	start_button.visible = is_host
	note.visible = is_host
	addresses.visible = is_host
	waiting.visible = not is_host
	(start_button if is_host else leave_button).grab_focus()
