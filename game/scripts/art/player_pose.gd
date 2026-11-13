class_name PlayerPose
extends RefCounted
## Which pose a player is drawn in (art-pass "Player poses", "Dead is not downed"; design.md D3 as
## amended by C1), picked from the states every peer already has and whether the drawn body
## moves. Static: the look and the head anchor (`BodyLook`) ask the same table.

enum Pose { STANDING, WALK, RUN, CROUCH, CRAWL, SWIM, FLOAT, DIVE, SUBMERGED, DOWNED, DRAGGED, DEAD }

## design.md C1 D1: frames drawn with centered off at this offset, so frame row 30 ends at +4.
const OFFSET: Vector2 = Vector2(-16.0, -27.0)
## Swimmers and floaters are drawn this much lower, through the sprite's offset (design.md D19).
const SWIM_DROP_PX: float = 12.0
const WALK_FPS: float = 8.0
const RUN_FPS: float = 12.0
const CROUCH_FPS: float = 4.0
const CRAWL_FPS: float = 2.0
const SWIM_FPS: float = 4.0
const DOWNED_FPS: float = 1.0


## The pose of a body: dead before downed, downed before every movement state, submerged before
## the dive state; a walk or run state that does not move is standing.
static func pick(movement: MovementStep.Move, stealth: MovementStep.Stealth, downed: bool, dead: bool, moving: bool) -> Pose:
	if dead:
		return Pose.DEAD
	if downed or movement == MovementStep.Move.DRAGGED:
		return Pose.DRAGGED if movement == MovementStep.Move.DRAGGED else Pose.DOWNED
	if stealth == MovementStep.Stealth.SUBMERGED:
		return Pose.SUBMERGED
	match movement:
		MovementStep.Move.CROUCH:
			return Pose.CROUCH
		MovementStep.Move.CRAWL:
			return Pose.CRAWL
		MovementStep.Move.SWIM:
			return Pose.SWIM
		MovementStep.Move.FLOAT:
			return Pose.FLOAT
		MovementStep.Move.DIVE:
			return Pose.DIVE
		MovementStep.Move.RUN:
			return Pose.RUN if moving else Pose.STANDING
	return Pose.WALK if moving else Pose.STANDING


## The template animation a pose plays facing `facing`; none for the dive (only the ripple shows).
static func animation(pose: Pose, facing: Facing.Dir) -> StringName:
	var row: String = String(Facing.row_name(facing))
	match pose:
		Pose.STANDING:
			return StringName("idle_" + row)
		Pose.WALK, Pose.RUN:
			return StringName("walk_" + row)
		Pose.CROUCH, Pose.CRAWL:
			return StringName("crouch_" + row)
		Pose.SWIM, Pose.FLOAT:
			return StringName("swim_" + row)
		Pose.DOWNED, Pose.DRAGGED:
			return &"downed"
		Pose.DEAD:
			return &"dead"
	return &""


## Where Look/Sprite draws its frame: swimmers lower, through the offset, never the node's position.
static func sprite_offset(pose: Pose) -> Vector2:
	return OFFSET + Vector2(0.0, SWIM_DROP_PX) if _wet(pose) else OFFSET


static func shows_body(pose: Pose) -> bool:
	return not _under(pose)


static func shows_water_line(pose: Pose) -> bool:
	return _wet(pose)


static func shows_shadow(pose: Pose) -> bool:
	return not _wet(pose) and not _under(pose)


static func shows_ripple(pose: Pose) -> bool:
	return _under(pose)


## The pose's speed in frames per second; 0 holds `still_frame(pose)`.
static func fps(pose: Pose, moving: bool) -> float:
	match pose:
		Pose.WALK:
			return WALK_FPS if moving else 0.0
		Pose.RUN:
			return RUN_FPS if moving else 0.0
		Pose.CROUCH:
			return CROUCH_FPS if moving else 0.0
		Pose.CRAWL:
			return CRAWL_FPS if moving else 0.0
		Pose.SWIM:
			return SWIM_FPS if moving else 0.0
		Pose.DOWNED, Pose.DRAGGED:
			return DOWNED_FPS
	return 0.0


## The frame a pose holds while it does not play.
static func still_frame(_pose: Pose) -> int:
	return 0


## Whether the frame is mirrored: left is the side frames mirrored; a lying pose facing up or down
## keeps the last side.
static func flip_h(pose: Pose, facing: Facing.Dir, last_side: Facing.Dir) -> bool:
	if _lying(pose) and facing != Facing.Dir.LEFT and facing != Facing.Dir.RIGHT:
		return last_side == Facing.Dir.LEFT
	return facing == Facing.Dir.LEFT


## The head-anchor family a pose's head top is measured over.
static func family(pose: Pose) -> StringName:
	match pose:
		Pose.CROUCH, Pose.CRAWL:
			return &"crouch"
		Pose.SWIM, Pose.FLOAT:
			return &"swim"
		Pose.DIVE, Pose.SUBMERGED:
			return &"dive"
		Pose.DOWNED, Pose.DRAGGED:
			return &"downed"
		Pose.DEAD:
			return &"dead"
	return &"walk"


static func _wet(pose: Pose) -> bool:
	return pose == Pose.SWIM or pose == Pose.FLOAT


static func _under(pose: Pose) -> bool:
	return pose == Pose.DIVE or pose == Pose.SUBMERGED


static func _lying(pose: Pose) -> bool:
	return pose == Pose.DOWNED or pose == Pose.DRAGGED or pose == Pose.DEAD
