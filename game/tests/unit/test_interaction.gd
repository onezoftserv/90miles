extends GutTest
## player-movement: Interactable, InteractionPicker and InteractionHold.

const TILE: float = 16.0


func _interactable(at: Vector2, hold_time: float = 0.0) -> Interactable:
	var node := Interactable.new()
	node.hold_time_s = hold_time
	node.position = at
	add_child_autofree(node)
	return node


func _candidates(items: Array[Interactable]) -> Array[Interactable]:
	return items


# --- picker ------------------------------------------------------------------------------

func test_nearest_interactable_wins() -> void:
	var crate := _interactable(Vector2(0.9 * TILE, 0.0))
	var coconut := _interactable(Vector2(0.0, 0.5 * TILE))
	var picked := InteractionPicker.pick(Vector2.ZERO, _candidates([crate, coconut]))
	assert_eq(picked, coconut)


func test_the_nearest_one_is_used_and_the_other_is_not() -> void:
	var coconut := _interactable(Vector2(0.5 * TILE, 0.0))
	var crate := _interactable(Vector2(0.9 * TILE, 0.0))
	watch_signals(coconut)
	watch_signals(crate)
	var hold := InteractionHold.new()
	var picked := InteractionPicker.pick(Vector2.ZERO, _candidates([crate, coconut]))
	hold.update(true, 0.1, null, picked)
	assert_signal_emitted(coconut, "interacted")
	assert_signal_not_emitted(crate, "interacted")


func test_nothing_farther_than_one_tile_is_picked() -> void:
	var far := _interactable(Vector2(TILE + 0.5, 0.0))
	assert_null(InteractionPicker.pick(Vector2.ZERO, _candidates([far])))


func test_exactly_one_tile_away_is_in_reach() -> void:
	var edge := _interactable(Vector2(TILE, 0.0))
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([edge])), edge)


func test_disabled_interactables_are_skipped() -> void:
	var near := _interactable(Vector2(2.0, 0.0))
	var farther := _interactable(Vector2(10.0, 0.0))
	near.enabled = false
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([near, farther])), farther)


# art-pass-followups D1: the highest priority in reach wins, then the nearest.
func test_a_higher_priority_in_reach_beats_a_nearer_one() -> void:
	var coconut := _interactable(Vector2(0.2 * TILE, 0.0))
	var gull := _interactable(Vector2(0.8 * TILE, 0.0))
	gull.priority = 1
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([coconut, gull])), gull)


func test_a_higher_priority_on_the_same_spot_wins_whichever_comes_first() -> void:
	var palm := _interactable(Vector2(0.5 * TILE, 0.0))
	var gull := _interactable(Vector2(0.5 * TILE, 0.0))
	gull.priority = 1
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([palm, gull])), gull)
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([gull, palm])), gull)


func test_equal_priorities_keep_nearest_wins() -> void:
	var far := _interactable(Vector2(0.8 * TILE, 0.0))
	var near := _interactable(Vector2(0.3 * TILE, 0.0))
	far.priority = 1
	near.priority = 1
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([far, near])), near)


func test_a_higher_priority_out_of_reach_loses() -> void:
	var coconut := _interactable(Vector2(0.5 * TILE, 0.0))
	var gull := _interactable(Vector2(1.5 * TILE, 0.0))
	gull.priority = 1
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([coconut, gull])), coconut)


func test_a_disabled_higher_priority_is_skipped() -> void:
	var coconut := _interactable(Vector2(0.5 * TILE, 0.0))
	var gull := _interactable(Vector2(0.2 * TILE, 0.0))
	gull.priority = 1
	gull.enabled = false
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([coconut, gull])), coconut)


func test_things_have_the_base_priority() -> void:
	assert_eq(_interactable(Vector2.ZERO).priority, 0)


func test_empty_candidates_pick_nothing() -> void:
	assert_null(InteractionPicker.pick(Vector2.ZERO, _candidates([])))


func test_children_of_the_excluded_node_are_skipped() -> void:
	var owner_node := Node2D.new()
	add_child_autofree(owner_node)
	var own := Interactable.new()
	owner_node.add_child(own)
	var other := _interactable(Vector2(12.0, 0.0))
	assert_eq(InteractionPicker.pick(Vector2.ZERO, _candidates([own, other]), owner_node), other)


# --- interactable ------------------------------------------------------------------------

func test_default_hold_time_is_2_seconds() -> void:
	assert_eq(autofree(Interactable.new()).hold_time_s, 2.0)
	assert_eq(Interactable.DEFAULT_HOLD_TIME_S, 2.0)


func test_interactables_register_in_the_interactables_group() -> void:
	var item := _interactable(Vector2.ZERO)
	assert_true(item.is_in_group(Interactable.GROUP))


func test_disabled_interactable_ignores_use() -> void:
	var item := _interactable(Vector2.ZERO)
	item.enabled = false
	watch_signals(item)
	item.use(null)
	assert_signal_not_emitted(item, "interacted")


# --- hold --------------------------------------------------------------------------------

func test_instant_interactable_is_used_on_the_first_held_frame() -> void:
	var item := _interactable(Vector2.ZERO, 0.0)
	watch_signals(item)
	var hold := InteractionHold.new()
	assert_true(hold.update(true, 0.016, null, item))
	assert_signal_emit_count(item, "interacted", 1)


func test_holding_on_does_not_repeat_an_instant_use() -> void:
	var item := _interactable(Vector2.ZERO, 0.0)
	watch_signals(item)
	var hold := InteractionHold.new()
	for i: int in 10:
		hold.update(true, 0.016, null, item)
	assert_signal_emit_count(item, "interacted", 1)
	hold.update(false, 0.016, null, item)
	hold.update(true, 0.016, null, item)
	assert_signal_emit_count(item, "interacted", 2, "a new press uses it again")


func test_timed_interactable_completes_after_its_hold_time() -> void:
	var net := _interactable(Vector2.ZERO, 2.0)
	watch_signals(net)
	var hold := InteractionHold.new()
	for i: int in 3:
		assert_false(hold.update(true, 0.5, null, net))
	assert_signal_not_emitted(net, "interacted")
	assert_almost_eq(hold.progress_s, 1.5, 0.0001)
	assert_true(hold.update(true, 0.5, null, net), "completes at 2 s")
	assert_signal_emit_count(net, "interacted", 1)


func test_releasing_early_cancels_and_holding_again_starts_from_zero() -> void:
	var net := _interactable(Vector2.ZERO, 2.0)
	watch_signals(net)
	var hold := InteractionHold.new()
	for i: int in 3:
		hold.update(true, 0.5, null, net)
	hold.update(false, 0.5, null, net)
	assert_eq(hold.progress_s, 0.0)
	assert_signal_not_emitted(net, "interacted")
	for i: int in 3:
		hold.update(true, 0.5, null, net)
	assert_signal_not_emitted(net, "interacted", "1.5 s again is still not enough")
	assert_almost_eq(hold.progress_s, 1.5, 0.0001)


func test_hold_time_is_per_interactable() -> void:
	var quick := _interactable(Vector2.ZERO, 0.5)
	var hold := InteractionHold.new()
	assert_false(hold.update(true, 0.25, null, quick))
	assert_true(hold.update(true, 0.25, null, quick))


func test_the_target_is_locked_when_the_press_starts() -> void:
	var first := _interactable(Vector2.ZERO, 2.0)
	var second := _interactable(Vector2(1.0, 0.0), 2.0)
	watch_signals(second)
	var hold := InteractionHold.new()
	hold.update(true, 1.0, null, first)
	hold.update(true, 1.0, null, second)
	assert_eq(hold.target, first)
	assert_signal_not_emitted(second, "interacted")


func test_pressing_with_nothing_in_reach_does_nothing() -> void:
	var hold := InteractionHold.new()
	assert_false(hold.update(true, 1.0, null, null))
	assert_eq(hold.progress_s, 0.0)


func test_target_disabled_mid_hold_cancels() -> void:
	var net := _interactable(Vector2.ZERO, 2.0)
	watch_signals(net)
	var hold := InteractionHold.new()
	hold.update(true, 1.0, null, net)
	net.enabled = false
	assert_false(hold.update(true, 1.5, null, net))
	assert_eq(hold.progress_s, 0.0)
	assert_signal_not_emitted(net, "interacted")


func test_freed_target_cancels_without_error() -> void:
	var net := Interactable.new()
	net.hold_time_s = 2.0
	add_child(net)
	var hold := InteractionHold.new()
	hold.update(true, 1.0, null, net)
	net.free()
	assert_false(hold.update(true, 1.0, null, null))
	assert_eq(hold.progress_s, 0.0)


func test_interacted_reports_who_used_it() -> void:
	var item := _interactable(Vector2.ZERO)
	var user := Node.new()
	add_child_autofree(user)
	watch_signals(item)
	InteractionHold.new().update(true, 0.1, user, item)
	assert_signal_emitted_with_parameters(item, "interacted", [user])
