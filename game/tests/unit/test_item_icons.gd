extends GutTest
## art-pass "Item icons" and "Art coverage" for items (task 7.1; design.md D17, D21): every item in
## game/resources/items/ (14 today) has a 16x16 icon with the item inside the 14x14 box one pixel
## in from each edge and its closed outline, no two icons share a silhouette, and an item file
## without an icon fails naming the file. A solo player sees each icon in the strip.

const ITEMS_DIR: String = "res://resources/items"
const NO_ICON_FIXTURE: String = "res://tests/fixtures/art/items/no_icon.tres"
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")


func _item_files() -> PackedStringArray:
	return ArtChecks.files_under(ITEMS_DIR, ["tres"])


func _outline() -> Dictionary:
	return ArtChecks.palette_from_colors(ArtTuning.standard().outline_colors)


func test_every_item_file_is_checked() -> void:
	var files: PackedStringArray = _item_files()
	assert_gte(files.size(), 14, "the 14 items of today, at least")
	assert_has(files, ITEMS_DIR + "/coco.tres")


func test_every_item_has_a_16x16_icon_inside_the_box_with_its_outline() -> void:
	var outline: Dictionary = _outline()
	var failures: PackedStringArray = []
	for path: String in _item_files():
		failures.append_array(ArtChecks.check_item_icon(path, load(path) as ItemData, outline))
	assert_eq(failures, PackedStringArray())


func test_no_two_items_share_a_silhouette() -> void:
	var icons: Dictionary[String, Image] = {}
	for path: String in _item_files():
		var item := load(path) as ItemData
		if item == null or item.sprite == null:
			fail_test("%s has no icon to compare" % path)
			continue
		icons[path.get_file().get_basename()] = ArtChecks.read_png(item.sprite.resource_path)
	assert_eq(ArtChecks.check_silhouettes(icons), PackedStringArray())


func test_an_item_without_an_icon_fails_naming_the_file() -> void:
	var item := load(NO_ICON_FIXTURE) as ItemData
	assert_not_null(item, "the fixture is a valid item")
	var failures: PackedStringArray = ArtChecks.check_item_icon(NO_ICON_FIXTURE, item, _outline())
	assert_eq(failures.size(), 1)
	if failures.size() == 1:
		assert_string_contains(failures[0], NO_ICON_FIXTURE)


func test_a_solo_player_sees_each_icon_in_the_strip() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	var body: PlayerBody = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	var shown: int = 0
	for path: String in _item_files():
		var item := load(path) as ItemData
		body.inventory.slots[0].clear()
		if body.inventory.add(item.id, 1) != 1:
			continue
		hud.strip.refresh()
		var slot: StripSlot = hud.strip.slot_view(0)
		assert_not_null(item.sprite, "%s has an icon" % item.id)
		assert_eq(slot.icon.texture, item.sprite, "%s shows its icon" % item.id)
		assert_true(slot.icon.visible, "%s's icon is visible" % item.id)
		shown += 1
	assert_gte(shown, 14, "every item went through the strip")
