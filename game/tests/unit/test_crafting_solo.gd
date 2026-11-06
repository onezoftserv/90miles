extends GutTest
## crafting-inventory, solo (CLAUDE.md): one offline player does everything alone.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const STEP: float = 0.25


func before_each() -> void:
	NetManager.start_solo()


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


# An item id that carries `tag` or `capability`, from the real content.
func _item_with(tag: int, capability: int) -> StringName:
	for id: StringName in GameState.content.list_ids(&"items"):
		var item := GameState.content.get_entry(&"items", id) as ItemData
		if tag >= 0 and item.tags.has(tag) or capability > 0 and item.capabilities.has(capability):
			return id
	return &""


func _give_everything(body: PlayerBody, recipe: RecipeData) -> void:
	for id: StringName in recipe.inputs:
		body.inventory.add(id, recipe.inputs[id])
	for tag: DataEnums.ItemTag in recipe.input_tags:
		body.inventory.add(_item_with(tag, 0), recipe.input_tags[tag])
	for capability: DataEnums.Capability in recipe.tools:
		body.inventory.add(_item_with(-1, capability), 1)


func test_a_solo_player_completes_every_recipe_alone() -> void:
	var body := _body()
	var bench := Workbench.new()
	bench.position = Vector2(8, 0)
	add_child_autofree(bench)
	var ids: Array[StringName] = GameState.content.list_ids(&"recipes")
	assert_gt(ids.size(), 1)
	for id: StringName in ids:
		var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
		body.inventory.from_net([])
		_give_everything(body, recipe)
		var done: bool = false
		if recipe.build_site:
			var site := body.crafter.place_site(recipe, Vector2(8, 8), self)
			site.deposit(body)
			done = body.crafter.start_work(site)
		elif recipe.station == RecipeData.Station.WORKBENCH:
			done = body.crafter.start(recipe, bench)
		assert_true(done, "%s starts with one player" % id)
		body.crafter.advance(recipe.time_s + 1.0)
		assert_false(body.crafter.is_crafting(), "%s completes" % id)
	assert_eq(multiplayer.get_peers(), PackedInt32Array(), "no second peer")


func test_solo_night_by_own_fire() -> void:
	var body := _body()
	body.climate.phase = DataEnums.DayPhase.NIGHT
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	var recipe := GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	var site := body.crafter.place_site(recipe, Vector2(48, 0), self)
	site.deposit(body)
	body.crafter.start_work(site)
	body.crafter.advance(30.0)
	body.meters.morale = 50.0
	for i: int in roundi(180.0 / STEP):
		body._physics_process(STEP)
	assert_almost_eq(body.meters.morale, 50.0, 0.01, "the fire keeps them company")


func test_a_solo_session_crafts_through_the_same_code() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	var body := session.body(1)
	body.player_input.enabled = false
	var bench := Workbench.new()
	bench.name = "Bench"
	session.add_child(bench)
	bench.global_position = body.global_position
	var recipe := RecipeData.new()
	recipe.id = &"fixture_solo"
	recipe.station = RecipeData.Station.WORKBENCH
	recipe.inputs = {&"driftwood": 1} as Dictionary[StringName, int]
	recipe.time_s = 0.1
	recipe.output_item_id = &"dry_grass"
	body.crafter.register(recipe)
	body.inventory.add(&"driftwood", 1)
	session.craft(&"fixture_solo", NodePath("Bench"))
	body.crafter.advance(0.2)
	assert_eq(body.inventory.count_id(&"dry_grass"), 1)
