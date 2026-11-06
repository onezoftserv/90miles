class_name SummaryScreen
extends Control
## ui-shell "Run summary": one line per player (name, died or survived) and how long the run
## lasted, like DCSS's end-of-run card. The Cuban one-liner and the rest arrive with the
## Milestone B "death, run summary, restart" task.

signal home_requested

@onready var run_length: Label = %Length
@onready var home_button: Button = %Home
@onready var _rows: VBoxContainer = %Rows


## "m:ss" for a run length in seconds (never negative).
static func format_length(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%d:%02d" % [floori(total / 60.0), total % 60]


func _ready() -> void:
	home_button.pressed.connect(home_requested.emit)
	home_button.grab_focus()


## `entries` holds one {name: String, dead: bool} per player, plus route (its Spanish name)
## for a player who left the island by a route.
func show_summary(entries: Array[Dictionary], length_s: float) -> void:
	run_length.text = format_length(length_s)
	for child: Node in _rows.get_children():
		child.queue_free()
	for entry: Dictionary in entries:
		var row := Label.new()
		row.theme_type_variation = &"PanelLabel"
		row.text = "%s: %s" % [entry.get("name", GameSettings.DEFAULT_NAME), "Murió" if entry.get("dead", false) else "Sobrevivió"]
		if entry.has("route"):
			row.text += " (se fue en: %s)" % entry["route"]
		_rows.add_child(row)


## The player lines, top to bottom.
func rows() -> Array[String]:
	var texts: Array[String] = []
	for child: Node in _rows.get_children():
		var label := child as Label
		if label != null and not label.is_queued_for_deletion():
			texts.append(label.text)
	return texts
