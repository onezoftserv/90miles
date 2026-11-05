extends GutTest
## coop-networking: a client replays intents from the host's model state, so the dive
## bookkeeping must survive a save and restore exactly.

const DT: float = 1.0 / 60.0
const T := DataEnums.Terrain
const CURRENT := TerrainQuery.DEFAULT_CURRENT


func _steps(model: MovementModel, intent: MoveIntent, count: int, energy: float) -> Array[MovementStep]:
	var out: Array[MovementStep] = []
	var left: float = energy
	for i: int in count:
		var step := model.step(T.DEEP, CURRENT, left, intent, DT)
		left -= step.energy_spent
		out.append(step)
	return out


func test_a_restored_model_continues_a_dive_exactly() -> void:
	var original := MovementModel.new()
	var dive := MoveIntent.create(Vector2.RIGHT, false, true)
	_steps(original, dive, 120, 80.0)
	var restored := MovementModel.new()
	assert_true(restored.set_state(original.get_state()))
	# 5 s dive limit: 120 frames in, 180 more cross the end of the dive.
	var a := _steps(original, dive, 240, 50.0)
	var b := _steps(restored, dive, 240, 50.0)
	for i: int in a.size():
		assert_eq(b[i].movement, a[i].movement, "frame %d" % i)
		assert_eq(b[i].stealth, a[i].stealth, "frame %d" % i)
		assert_eq(b[i].energy_spent, a[i].energy_spent, "frame %d" % i)
	assert_eq(a[0].movement, MovementStep.Move.DIVE, "still diving after the restore")
	assert_eq(a[a.size() - 1].movement, MovementStep.Move.SWIM, "the dive ended")


func test_a_fresh_model_would_start_a_new_dive_instead() -> void:
	var original := MovementModel.new()
	var dive := MoveIntent.create(Vector2.RIGHT, false, true)
	_steps(original, dive, 120, 80.0)
	var fresh := MovementModel.new()
	var spent_fresh: float = fresh.step(T.DEEP, CURRENT, 50.0, dive, DT).energy_spent
	var spent_original: float = original.step(T.DEEP, CURRENT, 50.0, dive, DT).energy_spent
	assert_ne(spent_fresh, spent_original, "the state is what makes the replay match")


func test_a_locked_dive_stays_locked_after_restore() -> void:
	var original := MovementModel.new()
	var dive := MoveIntent.create(Vector2.ZERO, false, true)
	_steps(original, dive, 360, 80.0)
	var restored := MovementModel.new()
	restored.set_state(original.get_state())
	assert_eq(restored.step(T.DEEP, CURRENT, 50.0, dive, DT).movement, MovementStep.Move.SWIM)


func test_state_round_trips() -> void:
	var original := MovementModel.new()
	_steps(original, MoveIntent.create(Vector2.RIGHT, false, true), 30, 80.0)
	var restored := MovementModel.new()
	restored.set_state(original.get_state())
	assert_eq(restored.get_state(), original.get_state())


func test_a_malformed_state_is_refused() -> void:
	var model := MovementModel.new()
	var before := model.get_state()
	assert_false(model.set_state(PackedFloat64Array([1.0])))
	assert_false(model.set_state(PackedFloat64Array([1.0, NAN, 0.0])))
	assert_eq(model.get_state(), before)
