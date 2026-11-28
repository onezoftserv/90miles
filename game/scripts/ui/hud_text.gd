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
## damage-feedback adds a use that would do nothing (inventory-hud "Uses that would do nothing"):
## several statuses to cure and none present, and a teammate who does not need it ("%s" is the
## name). One meter or one status has its own line (wasted_meters, wasted_statuses).
const REFUSALS: Array[StringName] = [&"empty", &"no_use", &"down", &"at_sea", &"condition", &"not_now", &"missing_materials", &"in_progress", &"wasted_cures", &"wasted_other"]
## The fixed lines: a required tool ("%s" is its phrase), the speed-up tool (the same), the
## head of a build site's missing inputs, the weight readout's label, a missing input with its
## count ("%s x%d"), a build's progress ("%d %%"), what the list says is carried of an input
## ("%d/%d %s": carried, needed, name), the weight readout ("%s %s/%s": label, carried, limit),
## the decimal separator its numbers use, and the spectator's line (ui-shell "The HUD while
## watching"): whom they watch ("%s" is the name), the same for a disconnected teammate, and the
## two switch keys ("%s" previous, "%s" next).
## damage-feedback adds a cure's float ("Sin %s": the status word) and the effect line's parts
## (inventory-hud "Effect line"): statuses cured ("Cura %s"), the word joining them, a revive,
## a change over time ("%s en %d s": the change, the seconds), a delay ("%s a los %d s"), what is
## useful of a gain ("%s (+%d útil)"), an item given or spent ("%s" its name), a route started
## ("%s" its name), a noise and smoke (guardacostas-stealth's NOISE and SMOKE).
## island-pressure adds a staged build's stage line ("Etapa %d/%d: %s": the stage, the count, its
## name), a build that costs energy worked with none, and the launch warnings: the day's two lines and
## the night's.
const LINES: Array[StringName] = [&"needs_tool", &"faster", &"missing", &"weight", &"count", &"percent", &"carried", &"weight_readout", &"decimal_point", &"close_note", &"watching", &"watching_dropped", &"watch_keys", &"cured", &"effect_cure", &"effect_and", &"effect_revive", &"effect_over", &"effect_delay", &"effect_useful", &"effect_give", &"effect_take", &"effect_route", &"effect_noise", &"effect_smoke", &"stage", &"no_strength", &"launch_day", &"launch_day_hint", &"launch_night"]
## The clock row's words (hud-clarity, ui-shell "Clock strip" and "Phase words"): the phase words
## ("Amanecer", "Mañana" 08-10, "Mediodía" 10-16, "Tarde" 16-18, "Atardecer", "Noche"), the day
## count ("Día %d") and the time left in in-game hours and minutes ("%dh", "%dm").
const CLOCK_WORDS: Array[StringName] = [&"dawn", &"morning", &"midday", &"afternoon", &"dusk", &"night", &"day", &"hours", &"minutes"]
## The objective row's lines (ui-shell "Objective row"), each at most 27 glyphs once filled: a count
## ("Arma la balsa: %d/%d %s": have, need, the item's short name), take it all to the raft, work it
## ("Dale a la balsa: %d%%"), wait for the dark, the default launch line and at sea.
const OBJECTIVE_LINES: Array[StringName] = [&"gather", &"deliver", &"work", &"wait_dark", &"launch_default", &"at_sea"]

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
## The word for each meter in a float and the effect line, as its HUD bar names it: "Sed".
@export var meter_words: Dictionary[DataEnums.Meter, PackedStringArray] = {}
## The word for each status in a cure's float and the effect line: "sangrado".
@export var status_words: Dictionary[DataEnums.Status, PackedStringArray] = {}
## The refusal when a use would raise only full meters, by the first meter it raises: "No tienes sed."
@export var wasted_meters: Dictionary[DataEnums.Meter, PackedStringArray] = {}
## The refusal when a use would cure one status the player does not have: "No 'tás sangrando."
@export var wasted_statuses: Dictionary[DataEnums.Status, PackedStringArray] = {}
## The clock row's words by key (CLOCK_WORDS).
@export var clock_words: Dictionary[StringName, PackedStringArray] = {}
## The objective row's lines by key (OBJECTIVE_LINES).
@export var objective_lines: Dictionary[StringName, PackedStringArray] = {}


## The project's HUD text file.
static func load_default() -> HudText:
	return load(PATH) as HudText


## The text of `pair` in `locale`: English when the locale is English and the text exists,
## else Spanish; "" when there is none.
static func pick(pair: PackedStringArray, locale: String) -> String:
	if locale.begins_with("en") and pair.size() > 1 and not pair[1].is_empty():
		return pair[1]
	return pair[0] if pair.size() > 0 else ""


## The content's name for item `id` in `locale`, which the HUD shows; "" for an id the content
## does not have (the content validator keeps recipes from naming one), never the raw id.
static func item_name(id: StringName, locale: String) -> String:
	var item := GameState.content.get_entry(&"items", id) as ItemData
	return item.get_display_name(locale) if item != null else ""


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


func meter_word(meter: DataEnums.Meter, locale: String = "es") -> String:
	return pick(meter_words.get(meter, PackedStringArray()), locale)


func status_word(status: DataEnums.Status, locale: String = "es") -> String:
	return pick(status_words.get(status, PackedStringArray()), locale)


func wasted_meter(meter: DataEnums.Meter, locale: String = "es") -> String:
	return pick(wasted_meters.get(meter, PackedStringArray()), locale)


func wasted_status(status: DataEnums.Status, locale: String = "es") -> String:
	return pick(wasted_statuses.get(status, PackedStringArray()), locale)


func clock_word(key: StringName, locale: String = "es") -> String:
	return pick(clock_words.get(key, PackedStringArray()), locale)


func objective_line(key: StringName, locale: String = "es") -> String:
	return pick(objective_lines.get(key, PackedStringArray()), locale)
