class_name SpeechBubble
extends Node2D
## A quick-chat phrase over its speaker (coop-networking "Quick chat"): a label above the
## player for SHOW_S, and the phrase's voice clip when one exists. Added as a child of the
## speaker's body by CoopSession, so it follows the player.

const SHOW_S: float = 2.5
## Above a 16×16 character.
const OFFSET: Vector2 = Vector2(0.0, -14.0)

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


func _process(delta: float) -> void:
	_left_s -= delta
	if _left_s <= 0.0:
		queue_free()
