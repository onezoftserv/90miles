extends GutTest
## inventory-hud "Uses that would do nothing" and "Effect line", crafting-inventory "A use that
## changes nothing is refused" (damage-feedback design D11, D12), with exactly 1 player, offline: a
## use refused only when no effect would change anything for whoever it goes on, spending nothing,
## with a Cuban reason on the notice row; and the effect line on that row, which a refusal takes for
## 2 s.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const R := ItemUser.Reason
const K := EffectData.Kind
const M := DataEnums.Meter
const ST := DataEnums.Status

var session: CoopSession
var me: PlayerBody
var words: HudText


func before_each() -> void:
	NetManager.start_solo()
	words = HudText.load_default()
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	me = session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()


func after_each() -> void:
	Input.action_release(InventoryStrip.USE_ACTION)
	NetManager.leave()


func _slot_of(item_id: StringName) -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == item_id:
			return i
	return -1


func _effect(kind: EffectData.Kind, meter: DataEnums.Meter = M.NONE, amount: float = 0.0, status: DataEnums.Status = ST.NONE) -> EffectData:
	var effect := EffectData.new()
	effect.kind = kind
	effect.meter = meter
	effect.amount = amount
	effect.status = status
	return effect


func _action(effects: Array[EffectData]) -> ItemUseData:
	var action := ItemUseData.new()
	action.effects = effects
	return action


func _full(body: PlayerBody) -> void:
	for meter: DataEnums.Meter in [M.THIRST, M.HUNGER, M.ENERGY, M.MORALE, M.HEALTH]:
		body.meters.set_value(meter, 100.0)


# --- the check the host and the HUD share -------------------------------------------------------

func test_sabila_with_nothing_to_cure_is_nothing_to_do() -> void:
	me.inventory.add(&"aloe", 1)
	assert_eq(ItemUser.check(me, _slot_of(&"aloe"), 0), R.NOTHING_TO_DO)
	me.meters.set_status(ST.BLEEDING, true)
	assert_eq(ItemUser.check(me, _slot_of(&"aloe"), 0), R.OK, "bleeding: it has something to cure")


func test_a_coconut_with_everything_full_is_nothing_to_do() -> void:
	_full(me)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	assert_eq(ItemUser.check(me, _slot_of(&"coco"), 0), R.NOTHING_TO_DO)


func test_a_coconut_that_still_feeds_is_fine() -> void:
	_full(me)
	me.meters.hunger = 80.0
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	assert_eq(ItemUser.check(me, _slot_of(&"coco"), 0), R.OK, "full thirst, hunger 80: it still feeds")
	assert_true(session.use_for(CoopSession.HOST_ID, _slot_of(&"coco"), 0, 0))
	assert_almost_eq(me.meters.hunger, 85.0, 0.001)
	assert_eq(_slot_of(&"coco"), -1, "the coconut is gone")


func test_a_meal_that_only_restores_energy_is_fine() -> void:
	_full(me)
	me.meters.energy = 50.0
	assert_false(UseOutcome.changes_nothing(_action([_effect(K.METER_ADD, M.HUNGER, 5.0)]), me, null), "the meal's energy still helps")


func test_any_other_kind_of_effect_is_doing_something() -> void:
	_full(me)
	var delayed := _effect(K.METER_ADD, M.THIRST, 15.0)
	delayed.delay_s = 30.0
	var over_time := _effect(K.METER_ADD, M.THIRST, 15.0)
	over_time.duration_s = 30.0
	var give := _effect(K.GIVE_ITEM)
	give.ref_id = &"driftwood"
	var cases: Array[EffectData] = [
		_effect(K.REVIVE), give, _effect(K.START_ROUTE), _effect(K.SET_FLAG), delayed, over_time,
		_effect(K.METER_ADD, M.HEALTH, -10.0), _effect(K.APPLY_STATUS, M.HEALTH, -20.0, ST.POISON),
	]
	for effect: EffectData in cases:
		var effects: Array[EffectData] = [_effect(K.METER_ADD, M.THIRST, 15.0), effect]
		assert_false(UseOutcome.changes_nothing(_action(effects), me, null), "kind %s" % K.keys()[effect.kind])


func test_checking_changes_nothing_on_the_real_meters() -> void:
	_full(me)
	me.inventory.add(&"aloe", 1)
	ItemUser.check(me, _slot_of(&"aloe"), 0)
	assert_eq(me.meters.thirst, 100.0)
	assert_eq(me.meters.status_flags, 0)


func test_a_forged_wasted_use_changes_and_spends_nothing() -> void:
	_full(me)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	var before: Array = me.inventory.to_net()
	assert_false(session.use_for(CoopSession.HOST_ID, _slot_of(&"coco"), 0, 0), "the host refuses it")
	assert_eq(me.inventory.to_net(), before, "the coconut and the knife's uses stay")
	assert_eq(me.meters.thirst, 100.0)


# --- the reason ---------------------------------------------------------------------------------

func test_the_reason_names_the_first_meter_or_the_one_status() -> void:
	_full(me)
	var coconut := (GameState.content.get_entry(&"items", &"coco") as ItemData).uses[0]
	assert_eq(InventoryStrip.wasted_line(coconut, me, null, "", words), "No tienes sed.")
	var bandage := _action([_effect(K.CURE_STATUS, M.NONE, 0.0, ST.BLEEDING)] as Array[EffectData])
	assert_eq(InventoryStrip.wasted_line(bandage, me, null, "", words), "No 'tás sangrando.")
	var sabila := (GameState.content.get_entry(&"items", &"aloe") as ItemData).uses[0]
	assert_eq(InventoryStrip.wasted_line(sabila, me, null, "", words), "No hay na' que curar.", "two statuses")
	var mate := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(mate)
	assert_eq(InventoryStrip.wasted_line(sabila, me, mate, "Papo", words), "A Papo no le hace falta.")


# --- on the strip -------------------------------------------------------------------------------

func _hud() -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	return hud


func _press_f(hud: RunHud) -> void:
	Input.action_press(InventoryStrip.USE_ACTION)
	hud.strip._process(0.1)
	Input.action_release(InventoryStrip.USE_ACTION)
	hud.strip._process(0.1)


func test_solo_sabila_with_nothing_to_cure_is_refused_on_the_strip() -> void:
	me.inventory.add(&"aloe", 1)
	var hud := _hud()
	hud.strip.select(_slot_of(&"aloe"))
	hud.strip._process(0.1)
	assert_eq(hud.notice.rest_text(), "Cura quemadura y sangrado", "the effect line before the press")
	watch_signals(hud.strip)
	_press_f(hud)
	assert_eq(hud.notice.shown_text(), "No hay na' que curar.")
	assert_signal_not_emitted(hud.strip, "use_sent", "nothing is sent")
	assert_eq(_slot_of(&"aloe") >= 0, true, "the sábila stays")
	for i: int in 21:
		hud.strip._process(0.1)
		hud.notice._process(0.1)
	assert_eq(hud.notice.shown_text(), "", "the refusal goes after 2 s")
	assert_eq(hud.notice.rest_text(), "Cura quemadura y sangrado", "and the effect line comes back")


func test_the_effect_line_follows_the_selection() -> void:
	me.meters.thirst = 50.0
	me.meters.hunger = 50.0
	me.meters.energy = 50.0
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	me.inventory.add(&"driftwood", 1)
	var hud := _hud()
	hud.strip.select(_slot_of(&"coco"))
	hud.strip._process(0.1)
	assert_eq(hud.notice.rest_text(), "Sed +15 · Hambre +5 · Energía +10")
	hud.strip.select(_slot_of(&"driftwood"))
	hud.strip._process(0.1)
	assert_eq(hud.notice.rest_text(), "", "driftwood has no use")


func test_a_conch_still_leaves_its_horn_at_full_hunger() -> void:
	_full(me)
	me.inventory.add(&"conch", 1)
	assert_eq(ItemUser.check(me, _slot_of(&"conch"), 0), R.OK, "the horn it leaves is something")
	assert_true(session.use_for(CoopSession.HOST_ID, _slot_of(&"conch"), 0, 0))
	assert_eq(me.inventory.count_id(&"conch"), 0)
	assert_eq(me.inventory.count_id(&"conch_horn"), 1)


func test_nearly_full_is_full() -> void:
	_full(me)
	me.meters.thirst = 99.9
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	assert_eq(ItemUser.check(me, _slot_of(&"coco"), 0), R.NOTHING_TO_DO, "a hair drained off is still full")
	me.meters.thirst = 98.9
	assert_eq(ItemUser.check(me, _slot_of(&"coco"), 0), R.OK, "a whole point to gain is something")
