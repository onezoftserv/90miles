class_name PlayerLook
extends Node2D
## How a player is drawn (art-pass "Player frames and anchor", "Player poses", "Player facing",
## "Swimmers at the water line", "Clothing colours", "Player look slots"; design.md D1-D3, D6, D19,
## C1, C2): the composite of its look slot's look on `Sprite`, in the pose its body's states pick,
## turned by its drawn motion; the dive ripple on `Ripple`; the swim ring on `SwimRing` (art-sprite-
## polish D1), centred on the water line the body is cut at; the shadow; and the hurt blink on a hit
## (survival-meters "Hurt cue on the body"; damage-feedback design D4), from the health this peer
## holds for the body. Drawing only (`art_view`,
## set in the scene): every frame it reads the body's states and position and writes nothing back.
## `step(delta)` is one frame; `_process` calls it and the tests drive it.

const RIPPLE_ANIMATION: StringName = &"dive"
const SWIM_RING_ANIMATION: StringName = &"swim"
## art-sprite-polish D5 ("Cover over a crouched body"): the rows of a Brush tile that hold the bush's
## front, drawn over the body so a crouched player is covered to about the chin and a standing one
## to mid-thigh; the rows above stay behind it.
const BUSH_FRONT_TOP: int = 4
const BUSH_FRONT_ROWS: int = 11
const TILE_PX: float = 16.0
## art-sprite-polish D2 ("A swimmer north of the deck goes under it"): the look's z while it swims
## just north of a drawn deck or board, between the crossing's sea (-40) and its deck (-20), so the
## planks hide the body under them and only the head shows above; 0 everywhere else.
const UNDER_DECK_Z: int = -21

## The pose drawn now.
var pose: PlayerPose.Pose = PlayerPose.Pose.STANDING
## The look of the body's slot, and its composite.
var look_data: PlayerLookData = null
var composed: ComposedLook = null
var facing: Facing = Facing.new()
var _art: BodyArt = null
var _slot: int = -1
var _material: ShaderMaterial = null
var _tuning: HurtCueTuning = HurtCues.tuning()
var _health_watch: MeterWatch = MeterWatch.new(_tuning.change_margin, _tuning.steady_forget_s)
var _blink: HurtBlink = HurtBlink.new(_tuning.blink_s, _tuning.blink_hz)
## The Brush tile the bush front copies now, [source, atlas coords, alternative]; [] while hidden.
var bush_tile: Array = []
var _brush: TileMapLayer = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var ripple: AnimatedSprite2D = $Ripple
@onready var swim_ring: AnimatedSprite2D = $SwimRing
@onready var shadow: DropShadow = $Shadow
@onready var bush_front: Sprite2D = $BushFront


func _ready() -> void:
	_art = BodyArt.standard()
	_material = sprite.material as ShaderMaterial
	var frame_top: int = _art.feet_y - _art.feet_row - 1
	var water_line_y: float = float(_art.water_row + frame_top + _art.swim_drop_px)
	if _material != null:
		_material.set_shader_parameter(&"water_line_y", water_line_y)
	# The ring's middle row on the line the body is cut at (its offset centres it, in the scene).
	swim_ring.position = Vector2(0.0, water_line_y)
	step(0.0)


func _process(delta: float) -> void:
	step(delta)


## One frame: follows the body's slot, drawn position and states now.
func step(delta: float) -> void:
	var body := get_parent() as PlayerBody
	if body == null:
		return
	if body.look_slot != _slot:
		_show_slot(body.look_slot)
	facing.observe(body.global_position, delta)
	var meters := body.get_node_or_null(^"SurvivalMeters") as SurvivalMeters
	var dead: bool = meters != null and meters.dead
	pose = PlayerPose.pick(body.movement_state, body.stealth_state, body.downed, dead, facing.moving())
	_draw_pose()
	z_index = UNDER_DECK_Z if _north_of_a_deck(body) else 0
	_draw_bush_front(body)
	_draw_hurt(meters, delta)


# Composes (or takes from the cache) the slot's look and colours the clothing in the slot's row.
func _show_slot(slot: int) -> void:
	_slot = slot
	look_data = _art.look_for_slot(slot)
	composed = LookComposer.compose(look_data)
	sprite.sprite_frames = composed.frames
	if _material != null:
		# Row 0 of player_ramps.png is the key ramp.
		_material.set_shader_parameter(&"slot_row", clampi(slot, 0, NetPeers.MAX_PLAYERS - 1) + 1)


func _draw_pose() -> void:
	var body_shown: bool = PlayerPose.shows_body(pose)
	sprite.visible = body_shown
	shadow.visible = PlayerPose.shows_shadow(pose)
	var shadow_size: DropShadow.Size = DropShadow.Size.LYING if PlayerPose.lies(pose) else DropShadow.Size.LARGE
	if shadow.size != shadow_size:
		shadow.size = shadow_size
	_show_ripple(PlayerPose.shows_ripple(pose))
	_show_swim_ring(PlayerPose.shows_swim_ring(pose))
	if _material != null:
		_material.set_shader_parameter(&"water_line_on", PlayerPose.shows_water_line(pose))
	if not body_shown or sprite.sprite_frames == null:
		return
	var animation: StringName = PlayerPose.animation(pose, facing.dir)
	if not sprite.sprite_frames.has_animation(animation):
		return
	sprite.offset = PlayerPose.sprite_offset(pose)
	sprite.flip_h = PlayerPose.flip_h(pose, facing.dir, facing.last_side)
	var fps: float = PlayerPose.fps(pose, facing.moving())
	if fps <= 0.0:
		if sprite.is_playing() or sprite.animation != animation:
			sprite.stop()
			sprite.animation = animation
		sprite.frame = PlayerPose.still_frame(pose)
		return
	sprite.speed_scale = fps / maxf(sprite.sprite_frames.get_animation_speed(animation), 0.001)
	if not sprite.is_playing() or sprite.animation != animation:
		sprite.play(animation)


# The island Brush layer's tile at the body's cell, its front rows only, at the cell (not on the
# body, so the bush does not walk with the player), while the body is drawn on land. The cell is
# the layer's own cell under the body's drawn position: `body.cell()` on an island at the origin.
func _draw_bush_front(body: PlayerBody) -> void:
	bush_tile = []
	var brush := _brush_layer(body)
	if brush != null and PlayerPose.shows_body(pose) and not PlayerPose.shows_water_line(pose):
		var cell: Vector2i = brush.local_to_map(brush.to_local(body.global_position))
		var source: int = brush.get_cell_source_id(cell)
		var atlas_source := brush.tile_set.get_source(source) as TileSetAtlasSource if source >= 0 else null
		if atlas_source != null:
			var atlas: Vector2i = brush.get_cell_atlas_coords(cell)
			bush_tile = [source, atlas, brush.get_cell_alternative_tile(cell)]
			bush_front.texture = atlas_source.texture
			bush_front.region_rect = Rect2(Vector2(atlas) * TILE_PX + Vector2(0.0, BUSH_FRONT_TOP), Vector2(TILE_PX, BUSH_FRONT_ROWS))
			var top_left: Vector2 = brush.to_global(brush.map_to_local(cell)) - Vector2(TILE_PX, TILE_PX) / 2.0
			bush_front.global_position = top_left + Vector2(0.0, BUSH_FRONT_TOP)
	bush_front.visible = not bush_tile.is_empty()


# The Brush layer of the island this body is on: the `Terrain` view of a node beside one of the
# body's ancestors (the island sits beside the session in the shell and the tests), found once.
# art-sprite-polish D2: true while the pose is wet (SWIM or FLOAT), the body rides a running crossing
# with a drawn deck or board, and it is north of that deck's or board's top edge within its x span
# widened by the sprite's half-width. Swimmers are drawn SWIM_DROP_PX lower than their feet, so a
# swimmer just north of the top edge would otherwise be drawn over the deck's top rows.
func _north_of_a_deck(body: PlayerBody) -> bool:
	if not PlayerPose.shows_swim_ring(pose):
		return false
	var session := CoopSession.of(body)
	if session == null:
		return false
	var reach: float = 0.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		reach = sprite.sprite_frames.get_frame_texture(sprite.animation, 0).get_size().x / 2.0
	for child: Node in session.get_children():
		var crossing := child as Crossing
		if crossing == null or crossing.finished or not crossing.peers().has(crossing.peer_of(body)):
			continue
		var at: Vector2 = crossing.to_local(body.global_position)
		for deck: Rect2 in CrossingArt.drawn_decks(crossing):
			if at.y < deck.position.y and at.x >= deck.position.x - reach and at.x <= deck.end.x + reach:
				return true
	return false


func _brush_layer(body: PlayerBody) -> TileMapLayer:
	if is_instance_valid(_brush):
		return _brush
	_brush = null
	var at: Node = body.get_parent()
	while at != null and _brush == null:
		for child: Node in at.get_children():
			var view := child as TerrainView
			if view == null:
				view = child.get_node_or_null(^"Terrain") as TerrainView
			if view != null:
				_brush = view.get_node_or_null(^"Brush") as TileMapLayer
				break
		at = at.get_parent()
	return _brush


## The body's hurt blink (a hit starts it again).
func hurt_blink() -> HurtBlink:
	return _blink


# A hit on this peer's copy of the body starts the blink; the frame is drawn, then the blink moves on.
func _draw_hurt(meters: SurvivalMeters, delta: float) -> void:
	if meters != null and _health_watch.observe(meters.health, meters.dead, delta) == MeterWatch.Change.HIT:
		_blink.start()
	if _material != null:
		var reduce: bool = HurtCues.reduce_flashes
		_material.set_shader_parameter(&"hurt_white", _blink.white(reduce))
		_material.set_shader_parameter(&"hurt_hidden", _blink.hidden(reduce))
		_material.set_shader_parameter(&"hurt_tint", _tuning.tint_color if _blink.tinted(reduce) else Color(0.0, 0.0, 0.0, 0.0))
	_blink.advance(delta)


func _show_swim_ring(shown: bool) -> void:
	swim_ring.visible = shown
	if shown and not swim_ring.is_playing():
		swim_ring.play(SWIM_RING_ANIMATION)
	elif not shown and swim_ring.is_playing():
		swim_ring.stop()


func _show_ripple(shown: bool) -> void:
	ripple.visible = shown
	if shown and not ripple.is_playing():
		ripple.play(RIPPLE_ANIMATION)
	elif not shown and ripple.is_playing():
		ripple.stop()
