class_name SummaryScreen
extends Control
## ui-shell "Run summary", grown by endings-progression: the run's totals (islands reached, days,
## length, companions, texts) and one row per player with the fate, the cause of death and a Cuban
## one-liner, like the end-of-run cards of DCSS and Brogue CE. Solo gets "Otra vez" beside "Volver
## al inicio"; co-op gets only "Volver al inicio", and a client whose host left sees a note.

signal home_requested
signal restart_requested

const HOST_LEFT_NOTE: String = "El anfitrión cerró la partida."

## The RunSummary on show, or null before show_summary.
var summary: RunSummary

@onready var panel: PanelContainer = $Panel
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
	home_button.pressed.connect(home_requested.emit)
	restart_button.pressed.connect(restart_requested.emit)
	home_button.grab_focus()


## Shows `shown`: the totals, a row per entry, and "Otra vez" (focused) when `restart_text` is not
## empty, else only "Volver al inicio".
func show_summary(shown: RunSummary, restart_text: String = "") -> void:
	summary = shown
	islands.text = "Islas: %d" % shown.islands_reached
	days.text = "Días: %d" % shown.days
	run_length.text = format_length(shown.length_s)
	companions.text = "Compañeros: %s" % format_companions(shown.companions_saved, shown.companions_lost)
	texts.text = "Textos: %s" % format_texts(shown.texts_found)
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
