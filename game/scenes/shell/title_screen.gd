class_name TitleScreen
extends Control
## ui-shell "Title screen": the logo over an animated sea, a vertical menu (Shattered Pixel
## Dungeon's title), one panel that describes the focused option (DCSS's main menu) and the
## version. It only asks: the shell decides what each choice does.

signal solo_requested
signal host_requested
signal join_requested
signal settings_requested
signal credits_requested
signal quit_requested

## One per menu button, in order.
const DESCRIPTIONS: Array[String] = [
	"Una persona, sin red: nadie espera a nadie. Sobrevive y busca cómo salir de la isla.",
	"Abre una partida para hasta 4 jugadores. Los demás se unen por IP en el puerto UDP 7777.",
	"Entra a la partida de un amigo con su dirección IP.",
	"Tu nombre, pantalla completa y escala.",
	"Quién hizo el arte y las fuentes del juego, y con qué licencias.",
	"Cierra el juego.",
]

@onready var sea: ColorRect = %Sea
@onready var logo: Label = %Logo
@onready var flavour: Label = %Flavour
@onready var description: Label = %Description
@onready var version: Label = %Version
@onready var _menu: VBoxContainer = %Menu


func _ready() -> void:
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	var requests: Array[Signal] = [solo_requested, host_requested, join_requested, settings_requested, credits_requested, quit_requested]
	var menu := buttons()
	for i: int in menu.size():
		menu[i].pressed.connect(requests[i].emit)
		menu[i].focus_entered.connect(_describe.bind(i))
		menu[i].mouse_entered.connect(menu[i].grab_focus)
	menu[0].grab_focus()
	_describe(0)


## The menu buttons, top to bottom.
func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _menu.get_children():
		var button := child as Button
		if button != null:
			found.append(button)
	return found


func _describe(index: int) -> void:
	description.text = DESCRIPTIONS[index]
