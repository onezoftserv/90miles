extends GutTest
## guardacostas-capture, group 2 (design.md §8, spec "Island history", main spec "Previous island after
## capture"): the run's island history as a pure list. The previous island is the last on-graph island
## before the current one with a lower index (island 1's is itself), the secret cay is never it, and
## the islands reached are the highest index, so a restart or a second arrival counts nothing twice.


func _history(steps: Array) -> IslandHistory:
	var history := IslandHistory.new()
	for step: Array in steps:
		history.arrive(step[0], step[1], step[2] if step.size() > 2 else false)
	return history


func test_a_new_history_starts_on_island_1() -> void:
	var history := IslandHistory.new()
	assert_eq(history.reached(), 1, "the starting island counts before it is recorded")
	assert_eq(history.current_index(), 1)
	history.arrive(&"sandbar", 1, false)
	assert_eq(history.current_id(), &"sandbar")
	assert_eq(history.current_index(), 1)
	assert_eq(history.reached(), 1)


func test_on_island_1_the_previous_island_is_island_1() -> void:
	var history := _history([[&"sandbar", 1]])
	assert_eq(history.previous(), &"sandbar")


func test_on_island_2_the_previous_island_is_island_1() -> void:
	var history := _history([[&"sandbar", 1], [&"coast_cay", 2]])
	assert_eq(history.previous(), &"sandbar")


func test_on_island_3_the_previous_island_is_island_2() -> void:
	var history := _history([[&"chain_a", 1], [&"chain_b", 2], [&"chain_c", 3]])
	assert_eq(history.previous(), &"chain_b")


# Main spec "Caught after the detour": island 4 → the secret cay → island 5, caught on 5, restarts 4.
func test_the_off_graph_cay_is_never_the_previous_island() -> void:
	var history := _history([[&"i1", 1], [&"i2", 2], [&"i3", 3], [&"i4", 4], [&"cayo_sin_norte", 4, true], [&"i5", 5]])
	assert_eq(history.previous(), &"i4", "the island the party left for the cay")
	assert_eq(history.reached(), 5, "the cay is not an island reached")


func test_after_a_restart_the_previous_island_steps_back_again() -> void:
	# Caught on island 3, restarted on island 2: island 2's previous island is island 1.
	var history := _history([[&"chain_a", 1], [&"chain_b", 2], [&"chain_c", 3], [&"chain_b", 2]])
	assert_eq(history.current_id(), &"chain_b")
	assert_eq(history.previous(), &"chain_a")


# Spec "Counted once": captured on island 3, restarted on island 2, arriving on island 3 again.
func test_islands_reached_is_the_highest_index_so_nothing_counts_twice() -> void:
	var history := _history([[&"chain_a", 1], [&"chain_b", 2], [&"chain_c", 3], [&"chain_b", 2]])
	assert_eq(history.reached(), 3)
	history.arrive(&"chain_c", history.next_index(false), false)
	assert_eq(history.current_index(), 3, "island 3 again")
	assert_eq(history.reached(), 3, "counted once")


func test_the_next_index_counts_on_graph_islands_only() -> void:
	var history := _history([[&"sandbar", 1]])
	assert_eq(history.next_index(false), 2)
	assert_eq(history.next_index(true), 1, "an off-graph cay keeps the index of the island it was reached from")
	history.arrive(&"cayo_sin_norte", history.next_index(true), true)
	assert_eq(history.next_index(false), 2, "the island after the cay is island 2")


func test_a_restart_on_island_1_keeps_counting_1() -> void:
	var history := _history([[&"sandbar", 1], [&"sandbar", 1]])
	assert_eq(history.reached(), 1)
	assert_eq(history.previous(), &"sandbar")
	assert_eq(history.entries.size(), 2, "both stays are in the history, in order")
