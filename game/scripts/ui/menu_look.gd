class_name MenuLook
extends RefCounted
## The dark run look for a menu screen built on paper (run-menu design D4; the Fable review's MN-01):
## inside a run, the settings screen, the Controles card and a question are drawn as HUD windows,
## from the same scenes the title shows on paper. One walk swaps the paper theme variations for
## their run ones, so the two looks never drift apart.

## Paper variation (by node class) → run variation. A PanelContainer with no variation is paper.
const LABELS: Dictionary[StringName, StringName] = {
	&"PanelLabel": &"",
	&"PanelHeading": &"HeadingLabel",
}
const PANEL: StringName = &"HudPanel"
const INSET: StringName = &"HudPanelTight"
const CHECK_BOX: StringName = &"HudCheckBox"


## Turns `root` and everything under it to the run look.
static func to_run(root: Node) -> void:
	_swap(root)
	for node: Node in root.find_children("*", "", true, false):
		_swap(node)


static func _swap(node: Node) -> void:
	var label := node as Label
	if label != null:
		if LABELS.has(label.theme_type_variation):
			label.theme_type_variation = LABELS[label.theme_type_variation]
		return
	var check := node as CheckBox
	if check != null:
		if check.theme_type_variation == &"":
			check.theme_type_variation = CHECK_BOX
		return
	var panel := node as PanelContainer
	if panel != null:
		if panel.theme_type_variation == &"" or panel.theme_type_variation == &"PanelContainer":
			panel.theme_type_variation = PANEL
		return
	var scroll := node as ScrollContainer
	if scroll != null and scroll.theme_type_variation == &"PaperInset":
		scroll.theme_type_variation = INSET
