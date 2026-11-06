extends GutTest
## crafting-inventory "Shared builds": anyone deposits into a site, progress is shared, and one
## player can do it all.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var recipe: RecipeData
# Sites and the fires they become go here, so each test starts without leftovers.
var arena: Node2D


func before_each() -> void:
	recipe = GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	arena = Node2D.new()
	add_child_autofree(arena)


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _fires() -> Array[Node]:
	return get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP)


func test_crafting_fire_consumes_3_driftwood_and_dry_grass() -> void:
	var body := _body()
	body.inventory.add(&"driftwood", 4)
	body.inventory.add(&"dry_grass", 2)
	var site := body.crafter.place_site(recipe, Vector2(8, 0), arena)
	assert_not_null(site)
	assert_eq(site.deposit(body), 4, "3 driftwood and 1 dry grass")
	assert_true(site.inputs_complete())
	assert_true(body.crafter.start_work(site))
	body.crafter.advance(29.0)
	assert_eq(_fires().size(), 0)
	body.crafter.advance(1.0)
	assert_eq(body.inventory.count_id(&"driftwood"), 1)
	assert_eq(body.inventory.count_id(&"dry_grass"), 1)
	assert_eq(_fires().size(), 1, "a lit fire stands where the site was")
	assert_false(is_instance_valid(site) and site.is_inside_tree() and not site.is_queued_for_deletion())


func test_two_players_deposit_to_one_site() -> void:
	var a := _body()
	var b := _body()
	a.inventory.add(&"driftwood", 2)
	b.inventory.add(&"driftwood", 1)
	b.inventory.add(&"dry_grass", 1)
	var site := a.crafter.place_site(recipe, Vector2(8, 0), arena)
	site.deposit(a)
	assert_false(site.inputs_complete())
	site.deposit(b)
	assert_true(site.inputs_complete())
	assert_true(site.work(0.5))
	assert_almost_eq(site.progress(), 0.5, 0.001, "the same progress for everyone")


func test_work_does_not_advance_while_inputs_incomplete() -> void:
	var body := _body()
	body.inventory.add(&"driftwood", 1)
	var site := body.crafter.place_site(recipe, Vector2(8, 0), arena)
	site.deposit(body)
	assert_false(site.work(0.5))
	assert_eq(site.progress(), 0.0)


func test_lighter_capability_is_the_fast_tool() -> void:
	var lighter := ItemData.new()
	lighter.id = &"lighter_fixture"
	lighter.capabilities = [DataEnums.Capability.LIGHT_FIRE] as Array[DataEnums.Capability]
	lighter.tool_action_time_s = 0.0
	lighter.durability = 10
	var body := _body()
	body.inventory.register(lighter)
	body.inventory.add(&"lighter_fixture", 1)
	body.inventory.add(&"driftwood", 3)
	body.inventory.add(&"dry_grass", 1)
	var site := body.crafter.place_site(recipe, Vector2(8, 0), arena)
	site.deposit(body)
	body.crafter.start_work(site)
	body.crafter.advance(0.1)
	assert_eq(_fires().size(), 1)
	assert_eq(body.inventory.slots[0].uses_left, 9, "the lighter spent a use")
