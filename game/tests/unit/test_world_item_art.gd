extends GutTest
## art-pass "Item icons" and "Drop shadows" for pick-ups (task 7.2; design.md D17, K6, K7, K8): a
## pick-up's look draws its item's 16x16 icon centred on the pick-up's position and raised 3 px
## (5 px for an icon under 8 px tall), below the interact prompt, over the 8x4 shadow, and the
## strip shows the same texture once a solo player picks it up. A look marked concealed draws
## neither icon nor shadow; Interactable.hides_contents alone changes nothing drawn. The look is
## read by node path and duck typing so this test compiles before it exists.

const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/items/world_item.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SHORT_ICON: String = "res://tests/fixtures/art/items/short.png"
const ART_GROUP: StringName = &"art_view"
const SHADOW_SIZE: Vector2 = Vector2(8.0, 4.0)
const PICKUP_SHADOW: int = 1
const HERE: Vector2 = Vector2(100.0, 100.0)

var _swapped: ItemData = null
var _swapped_sprite: Texture2D = null


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	if _swapped != null:
		_swapped.sprite = _swapped_sprite
		_swapped = null


func _item_data(id: StringName) -> ItemData:
	return GameState.content.get_entry(&"items", id) as ItemData


func _pick_up(id: StringName, at: Vector2 = HERE) -> Node2D:
	var item := WORLD_ITEM_SCENE.instantiate() as Node2D
	item.set("item_id", id)
	item.position = at
	add_child_autofree(item)
	return item


func _look(item: Node2D) -> Node2D:
	var look := item.get_node_or_null(^"Look") as Node2D
	assert_not_null(look, "the pick-up has a Look")
	return look


func _icon(item: Node2D) -> Sprite2D:
	var icon := item.get_node_or_null(^"Look/Icon") as Sprite2D
	assert_not_null(icon, "the look draws its icon with a Sprite2D at Look/Icon")
	return icon


func _shadow(item: Node2D) -> Sprite2D:
	var shadow := item.get_node_or_null(^"Look/Shadow") as Sprite2D
	assert_not_null(shadow, "the look has its shadow at Look/Shadow")
	return shadow


## Where `sprite` draws, in the pick-up's own space.
func _drawn(sprite: Sprite2D, item: Node2D) -> Rect2:
	return item.get_global_transform().affine_inverse() * sprite.get_global_transform() * sprite.get_rect()


func _opaque_bottom(texture: Texture2D) -> int:
	return ArtChecks.read_png(texture.resource_path).get_used_rect().end.y


func test_the_look_draws_only_in_art_view() -> void:
	var item := _pick_up(&"coco")
	var look := _look(item)
	if look == null:
		return
	assert_true(look.is_in_group(ART_GROUP), "the look is art")
	assert_false(item.is_in_group(ART_GROUP), "the pick-up itself is simulation")
	var methods: PackedStringArray = []
	for method: Dictionary in (item.get_script() as Script).get_script_method_list():
		methods.append(method["name"])
	assert_false(methods.has("_draw"), "WorldItem._draw is gone")


func test_a_coconut_draws_its_icon_raised_3_px_over_the_shadow() -> void:
	var item := _pick_up(&"coco")
	await wait_frames(2)
	var icon := _icon(item)
	var shadow := _shadow(item)
	if icon == null or shadow == null:
		return
	var coco := _item_data(&"coco")
	assert_not_null(coco.sprite, "coco has an icon")
	assert_eq(icon.texture, coco.sprite, "the coconut's own icon")
	assert_true(icon.is_visible_in_tree())
	var frame: Rect2 = _drawn(icon, item)
	assert_eq(frame, Rect2(-8.0, -11.0, 16.0, 16.0), "16x16, centred and raised 3 px: top edge at -11")
	assert_gt(frame.position.y, -InteractPrompt.RISE_PX, "below the prompt's bottom edge")
	# The 8x4 pick-up shadow, centred under the icon at its foot and drawn beneath it.
	assert_eq(shadow.get("size"), PICKUP_SHADOW, "the pick-up size")
	assert_eq(shadow.texture.get_size(), SHADOW_SIZE)
	assert_true(shadow.is_visible_in_tree())
	assert_eq(shadow.z_index, -1)
	assert_true(shadow.z_as_relative)
	assert_eq(icon.z_index, 0)
	var under: Rect2 = _drawn(shadow, item)
	assert_eq(under.get_center().x, 0.0, "centred under the icon")
	var foot: float = frame.position.y + _opaque_bottom(coco.sprite)
	assert_gt(under.end.y, foot, "the shadow shows below the coconut")
	assert_lt(under.position.y, foot, "and touches its foot")


func test_an_icon_under_8_px_tall_is_raised_5_px() -> void:
	var nails := _item_data(&"nails")
	_swapped = nails
	_swapped_sprite = nails.sprite
	nails.sprite = load(SHORT_ICON) as Texture2D
	var item := _pick_up(&"nails")
	await wait_frames(2)
	var icon := _icon(item)
	if icon == null:
		return
	assert_eq(icon.texture, nails.sprite)
	assert_eq(_drawn(icon, item), Rect2(-8.0, -13.0, 16.0, 16.0), "raised 5 px: top edge at -13")
	var top: float = _drawn(icon, item).position.y + ArtChecks.read_png(SHORT_ICON).get_used_rect().position.y
	assert_gt(top, -InteractPrompt.RISE_PX, "the short item itself stays below the prompt")


func test_a_solo_pick_up_shows_the_same_texture_in_the_strip() -> void:
	var session := SESSION_SCENE.instantiate() as CoopSession
	session.local_name = "Yuni"
	add_child_autofree(session)
	session.start()
	var body: PlayerBody = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.global_position = HERE
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	var item := _pick_up(&"coco")
	await wait_frames(2)
	var icon := _icon(item)
	if icon == null:
		return
	var drawn: Texture2D = icon.texture
	assert_not_null(drawn, "drawn on the beach first")
	(item.get_node(^"Interactable") as Interactable).use(body)
	hud.strip.refresh()
	var slot: StripSlot = hud.strip.slot_view(0)
	assert_eq(body.inventory.slots[0].item_id, &"coco")
	assert_eq(slot.icon.texture, drawn, "the same texture in the strip slot")
	assert_true(slot.icon.visible)


func test_a_concealed_pick_up_draws_neither_icon_nor_shadow() -> void:
	var item := _pick_up(&"coco")
	await wait_frames(2)
	var look := _look(item)
	var icon := _icon(item)
	var shadow := _shadow(item)
	if look == null or icon == null or shadow == null:
		return
	assert_true(&"concealed" in look, "the look has a concealed flag")
	assert_eq(look.get("concealed"), false, "not concealed by default")
	look.set("concealed", true)
	await wait_frames(2)
	assert_false(icon.is_visible_in_tree(), "no icon while concealed")
	assert_false(shadow.is_visible_in_tree(), "no shadow while concealed")
	look.set("concealed", false)
	await wait_frames(2)
	assert_true(icon.is_visible_in_tree(), "the icon returns")
	assert_true(shadow.is_visible_in_tree(), "the shadow returns")
	assert_eq(icon.texture, _item_data(&"coco").sprite)


func test_hides_contents_alone_changes_nothing_drawn() -> void:
	var item := _pick_up(&"coco")
	await wait_frames(2)
	var icon := _icon(item)
	var shadow := _shadow(item)
	if icon == null or shadow == null:
		return
	var frame: Rect2 = _drawn(icon, item)
	var under: Rect2 = _drawn(shadow, item)
	(item.get_node(^"Interactable") as Interactable).hides_contents = true
	await wait_frames(2)
	assert_true(icon.is_visible_in_tree())
	assert_true(shadow.is_visible_in_tree())
	assert_eq(icon.texture, _item_data(&"coco").sprite)
	assert_eq(_drawn(icon, item), frame)
	assert_eq(_drawn(shadow, item), under)
