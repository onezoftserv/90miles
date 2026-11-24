class_name ObjectiveRow
extends PanelContainer
## hud-clarity, ui-shell "Objective row": one thin dark row under the clock row naming the local
## player's goal (Objective), sized to its line and centred under the clock, inside BAND. An empty
## line hides it. RunHud decides the line each frame and when the row yields (a sign note, a screen);
## the row only redraws when its line changes. Drawing only.

## The row's whole band: x 152 to 380 under the clock row, y 20 to 30.
const BAND: Rect2 = Rect2(152.0, 20.0, 228.0, 10.0)

@onready var label: Label = $Line


## Shows `line`, or hides the row when it is empty.
func show_line(line: String) -> void:
	visible = not line.is_empty()
	if line == label.text:
		return
	label.text = line
	if line.is_empty():
		return
	var margins: Vector2 = get_theme_stylebox(&"panel").get_minimum_size()
	var width: float = minf(label.get_minimum_size().x + margins.x, BAND.size.x)
	size = Vector2(width, BAND.size.y)
	position = Vector2(BAND.position.x + floorf((BAND.size.x - width) / 2.0), BAND.position.y)
