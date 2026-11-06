extends GutTest
## crafting-inventory "Host-authoritative crafting" over ENet on localhost (NetHarness): the
## host applies a client's request to that client's own inventory; forged requests do nothing.

const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _recipe() -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = &"fixture_net"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.inputs = {&"driftwood": 2} as Dictionary[StringName, int]
	recipe.time_s = 0.2
	recipe.output_item_id = &"dry_grass"
	return recipe


# Puts a workbench named Bench under the host session, on top of `peer`'s body, and registers
# the fixture recipe with that body.
func _prepare(host: CoopSession, peer: int) -> void:
	var bench := Workbench.new()
	bench.name = "Bench"
	host.add_child(bench)
	bench.global_position = host.body(peer).global_position
	host.body(peer).crafter.register(_recipe())


func test_a_clients_craft_request_is_applied_by_the_host() -> void:
	var host := net.add_host()
	var a := await net.join()
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	_prepare(host, a_id)
	host.body(a_id).inventory.add(&"driftwood", 3)
	a.craft(&"fixture_net", NodePath("Bench"))
	var crafted := func() -> bool:
		return host.body(a_id).inventory.count_id(&"dry_grass") == 1
	assert_true(await wait_until(crafted, TIMEOUT_S), "the host crafted it")
	assert_eq(host.body(a_id).inventory.count_id(&"driftwood"), 1)
	var synced := func() -> bool:
		return net.own_body(a).inventory.to_net() == host.body(a_id).inventory.to_net()
	assert_true(await wait_until(synced, TIMEOUT_S), "the client sees the same inventory")
	assert_eq(net.own_body(a).inventory.count_id(&"dry_grass"), 1)


func test_a_client_cannot_craft_without_the_inputs_or_from_another_players_inventory() -> void:
	var host := net.add_host()
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var b_id: int = net.peer_id(b)
	_prepare(host, a_id)
	host.body(b_id).global_position = host.body(a_id).global_position
	host.body(b_id).crafter.register(_recipe())
	host.body(a_id).inventory.add(&"driftwood", 2)
	var before: Array = host.body(a_id).inventory.to_net()
	b.craft(&"fixture_net", NodePath("Bench"))
	b.use_item(0, 0, a_id)
	await wait_seconds(0.5)
	assert_eq(host.body(b_id).inventory.count_id(&"dry_grass"), 0, "B holds no inputs")
	assert_eq(host.body(a_id).inventory.to_net(), before, "A's inventory is untouched")


func test_a_client_cannot_call_the_host_only_handlers_for_another_player() -> void:
	var host := net.add_host()
	var a := await net.join()
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	assert_false(host.craft_for(999, &"fixture_net", NodePath("Bench")), "no such player")
