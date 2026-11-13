class_name PlayerLook
extends Node2D
## How a player is drawn (art-pass "Player frames and anchor", "Player poses", "Player facing",
## "Swimmers at the water line", "Clothing colours", "Player look slots"; design.md D1-D3, D6, D19,
## C1, C2): the composite of its look slot's look on `Sprite`, in the pose its body's states pick,
## turned by its drawn motion; the dive ripple on `Ripple`; the shadow. Drawing only (`art_view`,
## set in the scene): every frame it reads the body's states and position and writes nothing back.
## `step(delta)` is one frame; `_process` calls it and the tests drive it.

const RIPPLE_ANIMATION: StringName = &"dive"

## The pose drawn now.
var pose: PlayerPose.Pose = PlayerPose.Pose.STANDING
## The look of the body's slot, and its composite.
var look_data: PlayerLookData = null
var composed: ComposedLook = null
var facing: Facing = Facing.new()
var _art: BodyArt = null
var _slot: int = -1
var _material: ShaderMaterial = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var ripple: AnimatedSprite2D = $Ripple
@onready var shadow: DropShadow = $Shadow


func _ready() -> void:
	_art = BodyArt.standard()
	_material = sprite.material as ShaderMaterial
	if _material != null:
		var frame_top: int = _art.feet_y - _art.feet_row - 1
		_material.set_shader_parameter(&"water_line_y", float(_art.water_row + frame_top + _art.swim_drop_px))
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
	_show_ripple(PlayerPose.shows_ripple(pose))
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


func _show_ripple(shown: bool) -> void:
	ripple.visible = shown
	if shown and not ripple.is_playing():
		ripple.play(RIPPLE_ANIMATION)
	elif not shown and ripple.is_playing():
		ripple.stop()
