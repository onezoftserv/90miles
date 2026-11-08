class_name HudText
extends Resource
## Every player-facing word the run HUD adds (inventory-hud "HUD text is data"), in one file,
## game/resources/hud_text.tres: use verbs, prompt verbs and labels, tag names, tool phrases,
## refusal lines, the crafting list's lines, the weight label and the gamepad and mouse button
## names. Each entry is Spanish first with English beside it: [es, en]. An empty English text
## shows the Spanish one. Item, recipe and creature names come from their content files, never
## from here. A writer rewords any line here with no script change.

const PATH: String = "res://resources/hud_text.tres"
## Every refusal line the HUD can show: an empty slot, an item with no use, a player who is down,
## a player on a crossing, a missing tool ("%s" is its phrase), the generic "not now", missing
## materials and a build site already under way.
const REFUSALS: Array[StringName] = [&"empty", &"no_use", &"down", &"at_sea", &"condition", &"not_now", &"missing_materials", &"in_progress"]
## The fixed lines: a required tool ("%s" is its phrase), the speed-up tool (the same), the
## head of a build site's missing inputs, the weight readout's label, a missing input with its
## count ("%s x%d") and a build's progress ("%d %%").
const LINES: Array[StringName] = [&"needs_tool", &"faster", &"missing", &"weight", &"count", &"percent"]

## Verb per ItemUseData.UseAction ("Beber").
@export var use_verbs: Dictionary[ItemUseData.UseAction, PackedStringArray] = {}
## Verb per prompt id (`Interactable.prompt_id`): "Recoger".
@export var prompt_verbs: Dictionary[StringName, PackedStringArray] = {}
## Target per prompt id where no content name applies: "Mata de coco".
@export var prompt_labels: Dictionary[StringName, PackedStringArray] = {}
## Name per item tag a recipe takes: "Yesca".
@export var tag_names: Dictionary[DataEnums.ItemTag, PackedStringArray] = {}
## What a tool lets you do, per capability: "abrir el coco".
@export var tool_phrases: Dictionary[DataEnums.Capability, PackedStringArray] = {}
## Refusal lines by key (REFUSALS).
@export var refusals: Dictionary[StringName, PackedStringArray] = {}
## Fixed lines by key (LINES).
@export var lines: Dictionary[StringName, PackedStringArray] = {}
## Gamepad button names by JoyButton index (Xbox names until a glyph set exists).
@export var joy_buttons: Dictionary[int, PackedStringArray] = {}
## Gamepad axis names by JoyAxis index.
@export var joy_axes: Dictionary[int, PackedStringArray] = {}
## Mouse button names by MouseButton index.
@export var mouse_buttons: Dictionary[int, PackedStringArray] = {}


## The project's HUD text file.
static func load_default() -> HudText:
	return load(PATH) as HudText


## The text of `pair` in `locale`: English when the locale is English and the text exists,
## else Spanish; "" when there is none.
static func pick(pair: PackedStringArray, locale: String) -> String:
	if locale.begins_with("en") and pair.size() > 1 and not pair[1].is_empty():
		return pair[1]
	return pair[0] if pair.size() > 0 else ""


func use_verb(action: ItemUseData.UseAction, locale: String = "es") -> String:
	return pick(use_verbs.get(action, PackedStringArray()), locale)


func prompt_verb(prompt_id: StringName, locale: String = "es") -> String:
	return pick(prompt_verbs.get(prompt_id, PackedStringArray()), locale)


func prompt_label(prompt_id: StringName, locale: String = "es") -> String:
	return pick(prompt_labels.get(prompt_id, PackedStringArray()), locale)


func tag_name(tag: DataEnums.ItemTag, locale: String = "es") -> String:
	return pick(tag_names.get(tag, PackedStringArray()), locale)


func tool_phrase(capability: DataEnums.Capability, locale: String = "es") -> String:
	return pick(tool_phrases.get(capability, PackedStringArray()), locale)


func refusal(key: StringName, locale: String = "es") -> String:
	return pick(refusals.get(key, PackedStringArray()), locale)


func line(key: StringName, locale: String = "es") -> String:
	return pick(lines.get(key, PackedStringArray()), locale)


func joy_button(index: int, locale: String = "es") -> String:
	return pick(joy_buttons.get(index, PackedStringArray()), locale)


func joy_axis(axis: int, locale: String = "es") -> String:
	return pick(joy_axes.get(axis, PackedStringArray()), locale)


func mouse_button(index: int, locale: String = "es") -> String:
	return pick(mouse_buttons.get(index, PackedStringArray()), locale)
