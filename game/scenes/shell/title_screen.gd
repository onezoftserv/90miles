class_name TitleScreen
extends Control
## ui-shell "Title screen": the logo over an animated sea, a vertical menu (Shattered Pixel
## Dungeon's title), one panel that describes the focused option (DCSS's main menu) and the
## version. It only asks: the shell decides what each choice does.

signal solo_requested
signal host_requested
signal join_requested
signal settings_requested
signal controls_requested
signal credits_requested
signal quit_requested

## One per menu button, in order.
const DESCRIPTIONS: Array[String] = [
	"Una persona, sin red: nadie espera a nadie. Sobrevive y busca cómo salir de la isla.",
	"Abre una partida para hasta 4 jugadores. Los demás se unen por IP en el puerto UDP 7777.",
	"Entra a la partida de un amigo con su dirección IP.",
	"Tu nombre, la pantalla, la escala y el volumen.",
	"Las teclas y los botones del mando para cada cosa.",
	"Quién hizo el arte y las fuentes del juego, y con qué licencias.",
	"Cierra el juego.",
]

const NAME_PROMPT_SCENE: PackedScene = preload("res://scenes/shell/name_prompt.tscn")

## The first-launch name window while it is open (run-menu design D7), else null.
var name_prompt: NamePrompt = null

@onready var sea: ColorRect = %Sea
@onready var logo: Label = %Logo
@onready var flavour: Label = %Flavour
@onready var description: Label = %Description
@onready var version: Label = %Version
## A failure to host, on a red band under the description; hidden until show_error (design D6).
@onready var status: Label = %Status
@onready var _menu: VBoxContainer = %Menu


func _ready() -> void:
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	var requests: Array[Signal] = [solo_requested, host_requested, join_requested, settings_requested, controls_requested, credits_requested, quit_requested]
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


## Shows `text` on the red band under the description panel, until the title is left. Moving the
## focus or the pointer changes only the description.
func show_error(text: String) -> void:
	status.text = text
	status.visible = not text.is_empty()


## Opens the first-launch name window over the menu: the buttons give up the focus until it
## closes, then "Jugar solo" takes it.
func ask_name(source: GameSettings) -> void:
	if name_prompt != null:
		return
	for button: Button in buttons():
		button.focus_mode = Control.FOCUS_NONE
	name_prompt = NAME_PROMPT_SCENE.instantiate() as NamePrompt
	add_child(name_prompt)
	name_prompt.closed.connect(_on_name_given)
	name_prompt.ask(source)


func _on_name_given() -> void:
	if name_prompt != null:
		name_prompt.queue_free()
		name_prompt = null
	var menu := buttons()
	for button: Button in menu:
		button.focus_mode = Control.FOCUS_ALL
	menu[0].grab_focus()


## Puts the focus on the button named `node_name` (as in the scene: "Settings", "Controls"), as
## when a screen it opened closes.
func focus_button(node_name: StringName) -> void:
	var button := _menu.get_node_or_null(NodePath(String(node_name))) as Button
	if button != null:
		button.grab_focus()


func _describe(index: int) -> void:
	description.text = DESCRIPTIONS[index]
