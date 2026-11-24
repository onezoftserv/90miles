class_name SummaryScreen
extends Control
## ui-shell "Run summary", grown by endings-progression: the run's totals (islands reached, days,
## length, companions, texts) and one row per player with the fate, the cause of death and a Cuban
## one-liner, like the end-of-run cards of DCSS and Brogue CE. Solo and a co-op host get "Otra vez"
## beside "Volver al inicio"; a co-op client gets only "Volver al inicio" and a note that it waits
## for the host (endings-progression "Rematch from a co-op summary"), and a client whose host left
## sees that note instead.
## menu-clarity: the heading follows this peer's own fate ("Llegaste" or "Fin del viaje"), empty
## totals hide, the list's inset fits its rows, and for 0.8 s after it shows no press of any device
## reaches its buttons, so a button still held from the run cannot skip it (design D3-D5).

signal home_requested
signal restart_requested

const HOST_LEFT_NOTE: String = "El anfitrión cerró la partida."
## A co-op client's note: only the host can start again. The same words as the client's lobby.
const WAITING_NOTE: String = "Esperando al anfitrión…"
## The heading for a player who left by a route alive, and for one who did not.
const ARRIVED_HEADING: String = "Llegaste"
const ENDED_HEADING: String = "Fin del viaje"
## No press reaches the buttons for this long after the summary shows.
const ACCEPT_DELAY_S: float = 0.8
## The list's inset grows with its rows up to this height, then scrolls.
const INSET_CAP_PX: float = 200.0

## The RunSummary on show, or null before show_summary.
var summary: RunSummary
## Seconds now; the shell hands over its own clock, tests a fake one.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## When the summary showed, on `clock`.
var shown_at_s: float = 0.0

@onready var panel: PanelContainer = $Panel
@onready var heading: Label = %Heading
@onready var extras: HBoxContainer = %ExtrasRow
@onready var scroll: ScrollContainer = %Scroll
@onready var islands: Label = %Islands
@onready var days: Label = %Days
@onready var run_length: Label = %Length
@onready var companions: Label = %Companions
@onready var texts: Label = %Texts
@onready var note: Label = %Note
@onready var restart_button: Button = %Restart
@onready var home_button: Button = %Home
@onready var _rows: VBoxContainer = %Rows


## "m:ss" for a run length in seconds (never negative).
static func format_length(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%d:%02d" % [floori(total / 60.0), total % 60]


## "ninguno" until companions exist, else how many were saved and lost.
static func format_companions(saved: int, lost: int) -> String:
	if saved == 0 and lost == 0:
		return "ninguno"
	return "%d salvados, %d perdidos" % [saved, lost]


## "ninguno" until found texts exist, else how many.
static func format_texts(found: int) -> String:
	return "ninguno" if found <= 0 else str(found)


func _ready() -> void:
	home_button.pressed.connect(_on_home)
	restart_button.pressed.connect(_on_restart)
	shown_at_s = clock.call()
	_hold_buttons(true)
	home_button.grab_focus()


## Whether the buttons take presses yet (ACCEPT_DELAY_S after the summary showed).
func accepts_presses() -> bool:
	return clock.call() - shown_at_s >= ACCEPT_DELAY_S


func _process(_delta: float) -> void:
	if home_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and accepts_presses():
		_hold_buttons(false)
	# Wrapped one-liners know their height only once laid out at the inset's width.
	_fit_inset()


# An accept press or release during the gate is dropped here, before the focused button sees it,
# so nothing is kept for later.
func _input(event: InputEvent) -> void:
	if accepts_presses() or not is_inside_tree():
		return
	if event.is_action(&"ui_accept") or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _on_home() -> void:
	if accepts_presses():
		home_requested.emit()


func _on_restart() -> void:
	if accepts_presses():
		restart_requested.emit()


# The pointer passes through the buttons during the gate; the focus stays where it is.
func _hold_buttons(held: bool) -> void:
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_IGNORE if held else Control.MOUSE_FILTER_STOP
	home_button.mouse_filter = filter
	restart_button.mouse_filter = filter


## Shows `shown`: the heading for `local_peer`'s own fate, the totals, a row per entry, and "Otra
## vez" (focused) when `restart_text` is not empty, else only "Volver al inicio". The gate starts.
func show_summary(shown: RunSummary, restart_text: String = "", local_peer: int = 1) -> void:
	summary = shown
	shown_at_s = clock.call()
	_hold_buttons(true)
	heading.text = heading_for(shown, local_peer)
	islands.text = "Islas: %d" % shown.islands_reached
	days.text = "Días: %d" % shown.days
	run_length.text = format_length(shown.length_s)
	companions.text = "Compañeros: %s" % format_companions(shown.companions_saved, shown.companions_lost)
	texts.text = "Textos: %s" % format_texts(shown.texts_found)
	# endings-progression "Run summary totals": each shows only once there is something to count.
	companions.visible = shown.companions_saved > 0 or shown.companions_lost > 0
	texts.visible = shown.texts_found > 0
	extras.visible = companions.visible or texts.visible
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for entry: Dictionary in shown.entries:
		var row := SummaryRow.new()
		_rows.add_child(row)
		row.show_entry(entry)
	restart_button.visible = not restart_text.is_empty()
	restart_button.text = restart_text
	(restart_button if restart_button.visible else home_button).grab_focus()
	_fit_inset()


## "Llegaste" when `local_peer`'s entry is alive and left by a route, else "Fin del viaje" (also
## for a peer with no entry, such as a removed client).
static func heading_for(shown: RunSummary, local_peer: int) -> String:
	for entry: Dictionary in shown.entries:
		if entry.get("peer", 0) == local_peer and local_peer != 0:
			return ARRIVED_HEADING if not entry.get("dead", false) and entry.has("route") else ENDED_HEADING
	return ENDED_HEADING


# The inset is as tall as its rows, up to INSET_CAP_PX; beyond that it scrolls.
func _fit_inset() -> void:
	if not is_node_ready():
		return
	# The inset's own border sits inside its size, so the rows get its height less the border.
	var border: float = scroll.get_theme_stylebox(&"panel").get_minimum_size().y
	var fitted: float = minf(_rows.get_combined_minimum_size().y + border, INSET_CAP_PX)
	if not is_equal_approx(scroll.custom_minimum_size.y, fitted):
		scroll.custom_minimum_size.y = fitted


## A co-op client's summary: only the host can pick "Otra vez", so the note says it waits for them.
func show_waiting_for_host() -> void:
	note.text = WAITING_NOTE
	note.visible = true


## A client whose host left after the run: the summary stays, with a note and only the way home.
func show_host_left() -> void:
	note.text = HOST_LEFT_NOTE
	note.visible = true
	restart_button.visible = false
	home_button.grab_focus()


## The fate of each player, top to bottom.
func rows() -> Array[String]:
	var found: Array[String] = []
	for child: Node in _rows.get_children():
		found.append((child as SummaryRow).fate.text)
	return found


## Each row's one-liner ("" for a survivor).
func one_liners() -> Array[String]:
	var found: Array[String] = []
	for child: Node in _rows.get_children():
		found.append((child as SummaryRow).line.text)
	return found


## Each row's tip line ("" until something sets it).
func tips() -> Array[String]:
	var found: Array[String] = []
	for child: Node in _rows.get_children():
		found.append((child as SummaryRow).tip.text)
	return found


## The row at `index`, or null.
func row(index: int) -> SummaryRow:
	if index < 0 or index >= _rows.get_child_count():
		return null
	return _rows.get_child(index) as SummaryRow
