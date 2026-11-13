class_name SpeechBubble
extends Node2D
## A quick-chat phrase over its speaker (coop-networking "Quick chat"): a label above the
## player for SHOW_S, and the phrase's voice clip when one exists. Added as a child of the
## speaker's body by CoopSession, so it follows the player. Over a player it follows the head
## (art-pass "Head anchor"; design.md P6, P11): its label's bottom on the head anchor, or above the
## name tag's label while the tag shows, and 3 px above the hidden mark and the interact prompt
## when they show over the same player. Island signs speak through it too, at OFFSET.

const SHOW_S: float = 2.5
## Over a speaker that is not a player: the top of the 16×16 sign post.
const OFFSET: Vector2 = Vector2(0.0, -16.0)
## Space left above a mark or a prompt below it (HUD px).
const STACK_GAP_PX: float = 3.0
const LOOK_NAME: StringName = &"BodyLook"
const TAG_NAME: StringName = &"NameTag"

## Set before the bubble enters the tree.
var text: String = ""
## The phrase's voice clip, or null while none has been recorded.
var voice: AudioStream = null
var _left_s: float = SHOW_S

@onready var label: Label = $Label
@onready var voice_player: AudioStreamPlayer2D = $Voice


func _ready() -> void:
	position = OFFSET
	label.text = text
	if voice != null:
		voice_player.stream = voice
		voice_player.play()
	refresh()


func _process(delta: float) -> void:
	refresh()
	_left_s -= delta
	if _left_s <= 0.0:
		queue_free()


## Places the bubble over its speaker now.
func refresh() -> void:
	var player := get_parent() as PlayerBody
	if player == null:
		position = OFFSET
		return
	var look := player.get_node_or_null(NodePath(LOOK_NAME)) as BodyLook
	var bottom: float = look.head_anchor_y() if look != null else OFFSET.y
	var tag := player.get_node_or_null(NodePath(TAG_NAME)) as NameTag
	if tag != null and tag.visible and tag.label != null:
		bottom = minf(bottom, tag.position.y + tag.label.position.y)
	# The HUD's pieces over the same player, below the bubble (design.md P11).
	for node: Node in get_tree().get_nodes_in_group(BodyMarks.GROUP):
		var marks := node as BodyMarks
		if marks != null and marks.has_mark(player):
			bottom = minf(bottom, _from_hud(player, marks.to_hud, marks.mark_rect(player).position.y - STACK_GAP_PX))
	for node: Node in get_tree().get_nodes_in_group(InteractPrompt.GROUP):
		var prompt := node as InteractPrompt
		if prompt != null and prompt.visible and prompt.over_player() == player:
			bottom = minf(bottom, _from_hud(player, prompt.to_hud, prompt.prompt_rect().position.y - STACK_GAP_PX))
	position = Vector2(0.0, bottom - (label.position.y + label.size.y))


# A HUD y as a y in `player`'s own pixels, through `to_hud` (the world view's mapping, which only
# moves and scales).
static func _from_hud(player: PlayerBody, to_hud: Callable, hud_y: float) -> float:
	var canvas: Transform2D = player.get_global_transform_with_canvas()
	var top: float = (to_hud.call(canvas * Vector2.ZERO) as Vector2).y
	var below: float = (to_hud.call(canvas * Vector2.DOWN) as Vector2).y
	if is_equal_approx(top, below):
		return hud_y - top
	return (hud_y - top) / (below - top)
