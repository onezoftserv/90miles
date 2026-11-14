class_name JoinScreen
extends Control
## ui-shell "Join screen": the host's address with an optional :port (7777 by default). A bad
## address is refused here, before anything connects. A join from outside the game shows its
## target's label, which cannot be edited while it connects; a failure shows the reason's line and
## the screen stays open for another try. "Volver" asks the shell, which cancels a join under way.

signal connect_requested(address: String, port: int)
signal back_requested

const CONNECTING: String = "Conectando…"
const FAILED: String = "No se pudo conectar."

@onready var address_field: LineEdit = %Address
@onready var connect_button: Button = %Connect
@onready var back_button: Button = %Back
@onready var status: Label = %Status


## {address, port, error}: error is "" when the address can be tried.
static func parse_address(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	var address := trimmed
	var port: int = NetPeers.DEFAULT_PORT
	if trimmed.contains(":"):
		address = trimmed.get_slice(":", 0).strip_edges()
		var port_text := trimmed.get_slice(":", 1).strip_edges()
		if not port_text.is_valid_int() or port_text.to_int() < 1 or port_text.to_int() > NetPeers.MAX_PORT:
			return {"address": address, "port": port, "error": "El puerto debe ser un número del 1 al 65535."}
		port = port_text.to_int()
	if address.is_empty():
		return {"address": "", "port": port, "error": "Escribe la IP del anfitrión."}
	return {"address": address, "port": port, "error": ""}


func _ready() -> void:
	connect_button.pressed.connect(_try)
	address_field.text_submitted.connect(func(_text: String) -> void: _try())
	back_button.pressed.connect(back_requested.emit)
	address_field.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


## The join failed: `text` is the reason's line (FAILED when blank). The field can be edited again
## and "Conectar" tries again.
func show_failed(text: String = FAILED) -> void:
	status.text = text if not text.is_empty() else FAILED
	address_field.editable = true
	connect_button.disabled = false


## A join from outside the game: the field shows the target's `label` and cannot be edited, and
## the status reads CONNECTING, until it fails or the lobby or run shows.
func show_connecting(label: String) -> void:
	address_field.text = label
	address_field.editable = false
	connect_button.disabled = true
	status.text = CONNECTING


func _try() -> void:
	if connect_button.disabled:
		return
	var parsed := parse_address(address_field.text)
	if not String(parsed["error"]).is_empty():
		status.text = parsed["error"]
		return
	status.text = CONNECTING
	connect_button.disabled = true
	connect_requested.emit(parsed["address"], parsed["port"])
