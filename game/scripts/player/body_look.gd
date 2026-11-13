class_name BodyLook
extends Node
## Where the player's drawn head is (art-pass "Head anchor"; design.md D20, P2): the head-anchor
## component the name tag, the hidden mark (BodyMarks), the interact prompt and the speech bubble
## place themselves by. The top of the head comes from the pose its states pick (`PlayerPose`), the
## head tops measured on its look slot's composed look (`LookComposer`, cached) and
## balsero_art.tres. It reads only the body's states and that data, never the `Look` node, and is
## not drawing (`art_view`), so it works the same when the art is stripped. It reads the states
## every time it is asked, on every peer: the host's own simulation, a client's prediction of its
## own player, or the states the host replicates for everyone else.

## The pose the body's states pick now, as of the last `refresh()`.
var pose: PlayerPose.Pose = PlayerPose.Pose.STANDING
var _art: BodyArt = null


func _ready() -> void:
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Follows the body's states now.
func refresh() -> void:
	pose = _pose_now()


## The top of the drawn head in the current pose, in the body's own pixels (negative is above its
## origin).
func head_y() -> float:
	return head_anchor_y() + float(_body_art().head_gap_px)


## The head anchor: 1 px above the drawn head in the current pose, in the body's own pixels.
func head_anchor_y() -> float:
	var body := get_parent() as PlayerBody
	var slot: int = body.look_slot if body != null else 0
	var composed: ComposedLook = LookComposer.compose(_body_art().look_for_slot(slot))
	return float(composed.head_anchor(PlayerPose.family(_pose_now())))


func _pose_now() -> PlayerPose.Pose:
	var body := get_parent() as PlayerBody
	if body == null:
		return PlayerPose.Pose.STANDING
	var meters := body.get_node_or_null(^"SurvivalMeters") as SurvivalMeters
	var dead: bool = meters != null and meters.dead
	# Whether the body moves does not change the head's family (standing and walking share it).
	return PlayerPose.pick(body.movement_state, body.stealth_state, body.downed, dead, false)


func _body_art() -> BodyArt:
	if _art == null:
		_art = BodyArt.standard()
	return _art
