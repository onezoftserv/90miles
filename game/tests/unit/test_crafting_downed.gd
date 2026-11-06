extends GutTest
## crafting-inventory "A downed player cannot craft, deposit or use items": downed means
## immobile; only a teammate can revive them, and a solo player in a last stand may drink a
## reviving cup they carry.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const CLIENT_ID: int = 7
const REVIVE_USE: int = 1

var session: CoopSession


func before_each() -> void:
	NetManager.start_solo()
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	session.body(CoopSession.HOST_ID).player_input.enabled = false


# A second, downed player standing on the host's body, with a bench under them.
func _downed_client() -> PlayerBody:
	session._add_player(CLIENT_ID)
	var client := session.body(CLIENT_ID)
	client.player_input.enabled = false
	client.global_position = session.body(CoopSession.HOST_ID).global_position
	client.meters.health = 0.0
	client.meters.downed = true
	return client


func _bench_for(body: PlayerBody) -> void:
	var bench := Workbench.new()
	bench.name = "Bench"
	session.add_child(bench)
	bench.global_position = body.global_position
	var recipe := RecipeData.new()
	recipe.id = &"fixture_downed"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.inputs = {&"driftwood": 1} as Dictionary[StringName, int]
	recipe.time_s = 0.1
	recipe.output_item_id = &"dry_grass"
	body.crafter.register(recipe)


func _fire_site(body: PlayerBody) -> BuildSite:
	var recipe := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	return body.crafter.place_site(recipe, body.global_position, session)


func _last_stand(body: PlayerBody) -> void:
	body.meters.health = 0.0
	body.meters.last_stand = true


func test_a_downed_player_cannot_craft() -> void:
	var client := _downed_client()
	_bench_for(client)
	client.inventory.add(&"driftwood", 1)
	assert_false(session.craft_for(CLIENT_ID, &"fixture_downed", NodePath("Bench")))
	assert_false(client.crafter.is_crafting())
	assert_eq(client.inventory.count_id(&"driftwood"), 1, "nothing consumed")


func test_a_downed_player_cannot_deposit_into_a_build_site() -> void:
	var client := _downed_client()
	client.inventory.add(&"driftwood", 3)
	var before: Array = client.inventory.to_net()
	var site := _fire_site(client)
	assert_false(session.deposit_for(CLIENT_ID, site.get_path()))
	assert_eq(client.inventory.to_net(), before, "nothing deposited")


func test_a_downed_player_cannot_use_items_on_themself() -> void:
	var client := _downed_client()
	client.inventory.add(&"rain_cup", 1)
	client.meters.thirst = 10.0
	assert_false(session.use_for(CLIENT_ID, 0, 0, 0), "not even to drink")
	assert_false(session.use_for(CLIENT_ID, 0, REVIVE_USE, 0), "nor to stand themself up")
	assert_true(client.meters.downed)
	assert_eq(client.inventory.count_id(&"rain_cup"), 1)
	assert_eq(client.meters.thirst, 10.0)


func test_a_teammate_revives_a_downed_player_with_a_rain_cup() -> void:
	var client := _downed_client()
	var host := session.body(CoopSession.HOST_ID)
	host.inventory.add(&"rain_cup", 1)
	assert_true(session.use_for(CoopSession.HOST_ID, 0, REVIVE_USE, CLIENT_ID))
	assert_false(client.meters.downed)
	assert_eq(host.inventory.count_id(&"rain_cup"), 0)


func test_a_teammate_revives_a_downed_player_with_a_coconut_and_a_knife() -> void:
	var client := _downed_client()
	var host := session.body(CoopSession.HOST_ID)
	host.inventory.add(&"knife", 1)
	host.inventory.add(&"coco", 1)
	assert_true(session.use_for(CoopSession.HOST_ID, 1, REVIVE_USE, CLIENT_ID), "the coconut is slot 1")
	assert_false(client.meters.downed)


func test_a_solo_player_in_a_last_stand_drinks_a_reviving_cup() -> void:
	var host := session.body(CoopSession.HOST_ID)
	host.inventory.add(&"rain_cup", 1)
	_last_stand(host)
	assert_true(session.use_for(CoopSession.HOST_ID, 0, REVIVE_USE, 0))
	assert_false(host.meters.last_stand)
	assert_eq(host.inventory.count_id(&"rain_cup"), 0)


func test_a_solo_player_in_a_last_stand_cannot_craft_or_deposit_or_just_drink() -> void:
	var host := session.body(CoopSession.HOST_ID)
	_bench_for(host)
	host.inventory.add(&"driftwood", 3)
	host.inventory.add(&"rain_cup", 1)
	var site := _fire_site(host)
	_last_stand(host)
	var before: Array = host.inventory.to_net()
	assert_false(session.craft_for(CoopSession.HOST_ID, &"fixture_downed", NodePath("Bench")))
	assert_false(session.deposit_for(CoopSession.HOST_ID, site.get_path()))
	assert_false(session.use_for(CoopSession.HOST_ID, 1, 0, 0), "a plain drink is not a revive")
	assert_eq(host.inventory.to_net(), before, "nothing consumed")
	assert_true(host.meters.last_stand)
