extends GutTest
## inventory-hud "Effect line" (damage-feedback design D11), with exactly 1 player, offline: what
## the use the button would send does, built from that use's own effects by the rules the host
## applies, waste included ("Sed +15 (+6 útil)"). Kinds the host does not apply are left out, and
## the kinds the line knows are exactly the kinds the host applies, so the two never drift.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var words: HudText
var user: PlayerBody
var mate: PlayerBody


func before_each() -> void:
	words = HudText.load_default()
	user = _body()
	mate = _body()


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _use(item_id: StringName, index: int = 0) -> ItemUseData:
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	return item.uses[index]


func _meters_at(body: PlayerBody, thirst: float, hunger: float, energy: float) -> void:
	body.meters.hunger = hunger
	body.meters.thirst = thirst
	body.meters.energy = energy


func test_a_coconut_reads_its_drink_and_its_meal() -> void:
	_meters_at(user, 50.0, 50.0, 50.0)
	assert_eq(EffectLine.text(_use(&"coco"), user, null, words), "Sed +15 · Hambre +5 · Energía +10")


func test_waste_shows_what_is_useful() -> void:
	_meters_at(user, 94.0, 50.0, 50.0)
	assert_eq(EffectLine.text(_use(&"coco"), user, null, words), "Sed +15 (+6 útil) · Hambre +5 · Energía +10")
	_meters_at(user, 50.0, 50.0, 100.0)
	assert_eq(EffectLine.text(_use(&"coco"), user, null, words), "Sed +15 · Hambre +5 · Energía +10 (+0 útil)", "full energy: the meal's energy is wasted")


func test_sabila_reads_its_cures_in_order() -> void:
	# The cures, then its heal (bleeding-and-sabila), which a player at full health would waste.
	assert_eq(EffectLine.text(_use(&"aloe"), user, null, words), "Cura quemadura y sangrado · Salud +5 (+0 útil)")


func test_a_drain_over_time() -> void:
	assert_eq(EffectLine.text(_use(&"manzanillo"), user, null, words), "Salud -50 en 60 s", "the thirst multiplier the host skips is left out")


func test_a_revive_on_a_downed_teammate() -> void:
	_meters_at(mate, 50.0, 50.0, 50.0)
	mate.meters.solo = false
	mate.meters.add(DataEnums.Meter.HEALTH, -mate.meters.health)
	assert_true(mate.meters.downed)
	assert_eq(EffectLine.text(_use(&"coco", 1), user, mate, words), "Levanta · Sed +15 · Hambre +5 · Energía +10")
	assert_true(mate.meters.downed, "the line changed nothing on the real teammate")


func test_a_revive_in_a_solo_last_stand() -> void:
	_meters_at(user, 50.0, 50.0, 50.0)
	user.meters.solo = true
	user.meters.downed_bonus_s = 15.0
	user.meters.add(DataEnums.Meter.HEALTH, -user.meters.health)
	assert_true(user.meters.last_stand)
	assert_eq(EffectLine.text(_use(&"coco", 1), user, user, words), "Levanta · Sed +15 · Hambre +5 · Energía +10")
	assert_true(user.meters.last_stand, "still in the last stand")


func test_nothing_to_use_reads_nothing() -> void:
	assert_eq(EffectLine.text(null, user, null, words), "")


func test_a_long_line_is_cut_at_50_characters() -> void:
	var action := ItemUseData.new()
	for meter: DataEnums.Meter in [DataEnums.Meter.THIRST, DataEnums.Meter.HUNGER, DataEnums.Meter.MORALE, DataEnums.Meter.HEALTH, DataEnums.Meter.HEAT]:
		var effect := EffectData.new()
		effect.kind = EffectData.Kind.METER_ADD
		effect.meter = meter
		effect.amount = -10.0
		effect.duration_s = 30.0
		action.effects.append(effect)
	var line: String = EffectLine.text(action, user, null, words)
	assert_eq(line.length(), EffectLine.MAX_CHARS)
	assert_true(line.ends_with("…"))


func test_the_line_knows_exactly_the_kinds_the_host_applies() -> void:
	for kind: int in EffectData.Kind.values():
		assert_eq(EffectLine.HANDLED.has(kind), EffectApplier.INTERPRETED.has(kind), "kind %s" % EffectData.Kind.keys()[kind])


# The kinds EffectApplier.apply_now's match names, read from its source: a kind added there without
# being listed in INTERPRETED (and so in the line) fails here.
func test_the_applier_lists_exactly_the_kinds_its_match_applies() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/crafting/effect_applier.gd")
	var body: String = source.get_slice("static func apply_now(", 1).get_slice("\n\n\n", 0)
	var regex := RegEx.create_from_string("EffectData\\.Kind\\.([A-Z_]+):")
	var matched: Array[String] = []
	for found: RegExMatch in regex.search_all(body):
		matched.append(found.get_string(1))
	matched.sort()
	var listed: Array[String] = []
	for kind: EffectData.Kind in EffectApplier.INTERPRETED:
		listed.append(EffectData.Kind.keys()[kind])
	listed.sort()
	assert_gt(matched.size(), 5, "read apply_now's match")
	assert_eq(listed, matched, "INTERPRETED is apply_now's match")


func test_noise_and_smoke_have_their_words() -> void:
	var action := ItemUseData.new()
	for kind: EffectData.Kind in [EffectData.Kind.NOISE, EffectData.Kind.SMOKE]:
		var effect := EffectData.new()
		effect.kind = kind
		action.effects.append(effect)
	assert_eq(EffectLine.text(action, user, null, words), "Hace ruido · Echa humo")


func test_every_item_builds_its_lines() -> void:
	var built: int = 0
	for item_id: StringName in GameState.content.list_ids(&"items"):
		var item := GameState.content.get_entry(&"items", item_id) as ItemData
		if item == null:
			continue
		for action: ItemUseData in item.uses:
			var line: String = EffectLine.text(action, user, mate if action.can_target_others else null, words)
			assert_false(line.contains("%"), "%s: %s" % [item.id, line])
			assert_false(line.contains("  "), "%s: no empty word in %s" % [item.id, line])
			assert_lte(line.length(), EffectLine.MAX_CHARS, item.id)
			built += 1
	assert_gt(built, 20, "every item use in the catalog")
