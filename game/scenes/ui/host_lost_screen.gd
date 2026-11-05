class_name HostLostScreen
extends CanvasLayer
## The "host lost" screen (coop-networking "Disconnect handling"): shown on a client when the
## host goes away. The level decides where "Volver" leads (the title or the lobby, once one
## exists).

## The player asked to leave the screen.
signal back_requested

@onready var message: Label = %Message
@onready var back_button: Button = %Back


func _ready() -> void:
	back_button.pressed.connect(back_requested.emit)
