extends GutTest
## art-pass "Drop shadows" (task 3.5; design.md D15, K6, K25): the shadow scene an actor's look puts
## at its feet. MetroCity's 12x7 ellipse and own-work 8x4 (pick-ups) and 6x3 versions, soft
## (partly transparent) in the palette's darkest colour, drawn at relative z -1 in the `art_view`
## group, so over every ground layer and under every actor. Placing shadows under players,
## creatures and pick-ups, and none under swimmers, is tested with their looks (tasks 5.4, 6.2, 7.2).
## The scene is read by path and duck typing so this test compiles before it exists.

const SHADOW_SCENE: String = "res://scenes/art/shadow.tscn"
const SHADOWS_DIR: String = "res://assets/art/shadows/"
const ART_GROUP: StringName = &"art_view"
## The scene's sizes, in order: 0 a player's, 1 a pick-up's (design.md K6), 2 the smallest.
const SIZES: Array[Vector2i] = [Vector2i(12, 7), Vector2i(8, 4), Vector2i(6, 3)]
const PICKUP_SIZE: int = 1
const GROUND_Z: int = -10


func _shadow() -> Sprite2D:
	var scene := load(SHADOW_SCENE) as PackedScene
	assert_not_null(scene, SHADOW_SCENE)
	if scene == null:
		return null
	var shadow := scene.instantiate() as Sprite2D
	assert_not_null(shadow, "the shadow is a Sprite2D")
	return shadow


func _image(texture: Texture2D) -> Image:
	return ArtChecks.read_png(texture.resource_path)


func _darkest() -> Color:
	var tuning := ArtTuning.standard()
	return ArtChecks.darkest(ArtChecks.palette_from_image(ArtChecks.read_png(tuning.master_palette.resource_path)))


func test_the_shadow_draws_at_relative_z_minus_1_in_art_view() -> void:
	var shadow := _shadow()
	if shadow == null:
		return
	add_child_autofree(shadow)
	assert_eq(shadow.z_index, -1)
	assert_true(shadow.z_as_relative)
	assert_true(shadow.is_in_group(ART_GROUP))
	assert_true(shadow.centered, "centred on the point it is placed at")


func test_each_size_is_a_soft_ellipse_in_the_darkest_colour() -> void:
	var shadow := _shadow()
	if shadow == null:
		return
	add_child_autofree(shadow)
	var darkest: String = ArtChecks.hex(_darkest())
	for index: int in SIZES.size():
		shadow.set("size", index)
		var texture: Texture2D = shadow.texture
		assert_not_null(texture, "size %d has a texture" % index)
		if texture == null:
			continue
		assert_true(texture.resource_path.begins_with(SHADOWS_DIR), "%s under shadows/" % texture.resource_path)
		var image := _image(texture)
		assert_eq(image.get_size(), SIZES[index], texture.resource_path)
		var soft: int = 0
		var other: PackedStringArray = []
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a8 == 0:
					continue
				if color.a8 < 255 and ArtChecks.hex(color) == darkest:
					soft += 1
				else:
					other.append("(%d, %d) %s@%d" % [x, y, ArtChecks.hex(color), color.a8])
		assert_gt(soft, 0, "%s has soft texels" % texture.resource_path)
		assert_eq(other, PackedStringArray(), "%s: every texel soft and %s" % [texture.resource_path, darkest])
		_assert_fills_its_box(image, texture.resource_path)
		_assert_mirrored(image, texture.resource_path)


# An ellipse touches every edge of its image.
func _assert_fills_its_box(image: Image, path: String) -> void:
	var used := image.get_used_rect()
	assert_eq(used, Rect2i(Vector2i.ZERO, image.get_size()), "%s fills its %s box" % [path, image.get_size()])


# And is the same mirrored left to right and top to bottom.
func _assert_mirrored(image: Image, path: String) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var odd: int = 0
	for y: int in h:
		for x: int in w:
			var a: int = image.get_pixel(x, y).a8
			if a != image.get_pixel(w - 1 - x, y).a8 or a != image.get_pixel(x, h - 1 - y).a8:
				odd += 1
	assert_eq(odd, 0, "%s is symmetric" % path)


func test_the_pickup_size_is_the_8_by_4_ellipse() -> void:
	var shadow := _shadow()
	if shadow == null:
		return
	add_child_autofree(shadow)
	shadow.set("size", PICKUP_SIZE)
	assert_eq(Vector2i(shadow.texture.get_size()), SIZES[PICKUP_SIZE])


func test_a_shadow_lies_over_the_ground_and_under_every_actor() -> void:
	var shadow := _shadow()
	if shadow == null:
		return
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child_autofree(world)
	var ground := Node2D.new()
	ground.z_index = GROUND_Z
	world.add_child(ground)
	var actor := Node2D.new()
	actor.position = Vector2(100.0, 100.0)
	world.add_child(actor)
	var north := Node2D.new()
	north.position = Vector2(100.0, 90.0)
	world.add_child(north)
	actor.add_child(shadow)
	assert_true(DrawOrder.drawn_after(actor, shadow), "under its own actor")
	assert_true(DrawOrder.drawn_after(north, shadow), "under an actor standing north of it")
	assert_true(DrawOrder.drawn_after(shadow, ground), "over the ground")
