class_name EffectLine
extends RefCounted
## inventory-hud "Effect line" (damage-feedback design D11): what a use does, said before it is used,
## built from that use's own effects by the rules the host applies, so the text never drifts from
## them: "Sed +15 · Hambre +5 · Energía +10" (a hunger gain at once is a meal), "Sed +15 (+6 útil)"
## when only part fits (Brogue's food check), "Salud -50 en 60 s", "Cura quemadura y sangrado",
## "Levanta", "Hace ruido". It knows exactly the kinds EffectApplier interprets (HANDLED, kept equal by a test);
## flags say nothing, and kinds the host skips are left out. Words come from hud_text.tres.

## The notice row's width in the 8 px pixel font (400 px).
const MAX_CHARS: int = 50
const SEPARATOR: String = " · "
const ELLIPSIS: String = "…"
## Comma between all but the last two cured statuses.
const LIST_COMMA: String = ", "
const HANDLED: Array[EffectData.Kind] = [
	EffectData.Kind.METER_ADD, EffectData.Kind.CURE_STATUS, EffectData.Kind.REVIVE,
	EffectData.Kind.GIVE_ITEM, EffectData.Kind.TAKE_ITEM, EffectData.Kind.START_ROUTE,
	EffectData.Kind.SET_FLAG, EffectData.Kind.CLEAR_FLAG, EffectData.Kind.NOISE, EffectData.Kind.SMOKE,
]


## The line for `action` by `actor` on `target` (null: on themself), or "" with no action.
static func text(action: ItemUseData, actor: PlayerBody, target: PlayerBody, words: HudText, locale: String = "es") -> String:
	if action == null:
		return ""
	var gains: Array[Vector2] = UseOutcome.useful_gains(action, actor, target)
	var parts := PackedStringArray()
	var cures: Array[DataEnums.Status] = []
	var cure_at: int = -1
	for index: int in action.effects.size():
		var effect: EffectData = action.effects[index]
		if not HANDLED.has(effect.kind):
			continue
		match effect.kind:
			EffectData.Kind.METER_ADD:
				var gain: Vector2 = gains[index] if index < gains.size() else Vector2.ZERO
				parts.append(_meter_part(effect, gain.x, words, locale))
				if UseOutcome.tried(effect) and effect.meter == DataEnums.Meter.HUNGER:
					var subject := EffectApplier.subject_of(effect, actor, target)
					var meal: float = subject.meters.tuning.meal_energy if subject != null else 0.0
					parts.append(_change(DataEnums.Meter.ENERGY, meal, gain.y, words, locale))
			EffectData.Kind.CURE_STATUS:
				if not cures.has(effect.status):
					cures.append(effect.status)
				if cure_at < 0:
					cure_at = parts.size()
					parts.append("")
			EffectData.Kind.REVIVE:
				parts.append(words.line(&"effect_revive", locale))
			EffectData.Kind.GIVE_ITEM:
				parts.append(words.line(&"effect_give", locale) % _item(effect, words, locale))
			EffectData.Kind.TAKE_ITEM:
				parts.append(words.line(&"effect_take", locale) % _item(effect, words, locale))
			EffectData.Kind.NOISE:
				parts.append(words.line(&"effect_noise", locale))
			EffectData.Kind.SMOKE:
				parts.append(words.line(&"effect_smoke", locale))
			EffectData.Kind.START_ROUTE:
				var route := GameState.content.get_entry(&"routes", effect.ref_id)
				if route != null:
					parts.append(words.line(&"effect_route", locale) % route.get_display_name(locale))
	if cure_at >= 0:
		parts[cure_at] = words.line(&"effect_cure", locale) % _list(cures, words, locale)
	return cut(SEPARATOR.join(parts))


## `line` cut to MAX_CHARS, ending in "…" when cut.
static func cut(line: String) -> String:
	if line.length() <= MAX_CHARS:
		return line
	return line.substr(0, MAX_CHARS - ELLIPSIS.length()) + ELLIPSIS


static func _meter_part(effect: EffectData, useful: float, words: HudText, locale: String) -> String:
	var part: String
	if effect.duration_s > 0.0:
		part = words.line(&"effect_over", locale) % [_signed(effect.meter, effect.amount, words, locale), roundi(effect.duration_s)]
	elif UseOutcome.tried(effect):
		part = _change(effect.meter, effect.amount, useful, words, locale)
	else:
		part = _signed(effect.meter, effect.amount, words, locale)
	if effect.delay_s > 0.0:
		part = words.line(&"effect_delay", locale) % [part, roundi(effect.delay_s)]
	return part


# "Sed +15", with "(+6 útil)" when less than all of it would land.
static func _change(meter: DataEnums.Meter, amount: float, useful: float, words: HudText, locale: String) -> String:
	var part: String = _signed(meter, amount, words, locale)
	if roundi(useful) < roundi(amount):
		part = words.line(&"effect_useful", locale) % [part, maxi(roundi(useful), 0)]
	return part


static func _signed(meter: DataEnums.Meter, amount: float, words: HudText, locale: String) -> String:
	return "%s %+d" % [words.meter_word(meter, locale), roundi(amount)]


static func _item(effect: EffectData, words: HudText, locale: String) -> String:
	var name: String = HudText.item_name(effect.ref_id, locale)
	return words.line(&"count", locale) % [name, effect.count] if effect.count > 1 else name


# "quemadura y sangrado"; three or more: "a, b y c".
static func _list(statuses: Array[DataEnums.Status], words: HudText, locale: String) -> String:
	var names := PackedStringArray()
	for status: DataEnums.Status in statuses:
		names.append(words.status_word(status, locale))
	if names.size() <= 1:
		return "".join(names)
	return LIST_COMMA.join(names.slice(0, names.size() - 1)) + words.line(&"effect_and", locale) + names[names.size() - 1]
