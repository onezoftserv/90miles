class_name SummaryRow
extends VBoxContainer
## One player's row on the run summary (endings-progression "Cause of death on the run summary"):
## the fate ("Balsero: Murió (sed)"), the Cuban one-liner under it, and a tip line that stays
## empty and hidden until something sets it (`set_tip`, the controls-onboarding change). Built in
## code, like the rest of the summary's labels.

var fate: Label
var line: Label
var tip: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fate = _make_label("Fate")
	line = _make_label("Line")
	tip = _make_label("Tip")


## Shows a RunSummary entry: fate, one-liner (hidden when there is none) and an untouched tip.
func show_entry(entry: Dictionary) -> void:
	var player_name: String = entry.get("name", GameSettings.DEFAULT_NAME)
	if entry.get("dead", false):
		fate.text = "%s: Murió (%s)" % [player_name, entry.get("cause_label", "")]
	else:
		fate.text = "%s: Sobrevivió" % player_name
		if entry.has("route"):
			fate.text += " (se fue en: %s)" % entry["route"]
	line.text = entry.get("line", "")
	line.visible = not line.text.is_empty()


## Shows `text` under the one-liner; an empty text hides the line again.
func set_tip(text: String) -> void:
	tip.text = text
	tip.visible = not text.is_empty()


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.theme_type_variation = &"PanelLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if label_name != "Fate":
		label.visible = false
	add_child(label)
	return label
