class_name WorldItem
extends Node2D
## An item lying on the ground (crafting-inventory "Pick-up"). Interacting applies on the host
## (the player's interaction runs there): what fits goes in the player's inventory, the rest
## stays. Set item_id and count before it enters the tree. Its Look child draws it (art-pass,
## `art_view`).
##
## An item whose `conceal_radius_tiles` is above 0 lies concealed (secret-cay "Concealment",
## "Shimmer", "Concealed pick-up hold"): every peer works out alone, from the player positions it
## already has, whether any player is within that radius. Until one is, its look draws nothing but
## a short shimmer every shimmer period, from this item's own phase. Taking it needs the tuning's
## hold. Concealment never hides it from the host's pick-up rules.

## The host took it: `by` picked up `item_id` (emitted before it leaves).
signal taken(by: PlayerBody, item_id: StringName)

const DRAWN_NORMAL: StringName = &"normal"
const DRAWN_SHIMMER: StringName = &"shimmer"
const DRAWN_NOTHING: StringName = &"nothing"
const TILE_PX: float = 16.0

@export var item_id: StringName = &""
@export var count: int = 1
## Uses a tool still has; -1 means a fresh one.
var uses_left: int = -1
## The secret tuning: shimmer timing and the concealed pick-up hold.
var tuning: SecretTuning = SecretTuning.standard():
	set(value):
		tuning = value
		_apply_hold()
## Seconds added to this item's clock before its shimmer is timed; set from its name when it
## enters the tree, so pieces do not blink together. Peers need not agree on it.
var shimmer_phase_s: float = -1.0
## The item lies concealed (its reveal radius is above 0).
var concealed: bool = false
## A player is within the reveal radius now, on this peer.
var revealed: bool = false

var _radius_tiles: float = 0.0
var _clock_s: float = 0.0

@onready var interactable: Interactable = $Interactable
## Drawing only (art_view): a run with art stripped leaves a plain node here, which ignores what is
## set on it.
@onready var look: Node2D = $Look


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	_radius_tiles = item.conceal_radius_tiles if item != null else 0.0
	concealed = _radius_tiles > 0.0
	if shimmer_phase_s < 0.0:
		shimmer_phase_s = float(hash(String(name)) & 0xffff) / 65536.0 * tuning.shimmer_period_s
	_apply_hold()
	step(0.0)


func _process(delta: float) -> void:
	step(delta)


## Advances this item's clock by `delta` and works out what it draws now.
func step(delta: float) -> void:
	_clock_s += delta
	if not concealed:
		return
	revealed = _player_within()
	look.set(&"concealed", not revealed)
	look.set(&"shimmer", shimmering())


## Whether the concealed item shows its shimmer now.
func shimmering() -> bool:
	if not concealed or revealed or tuning.shimmer_length_s <= 0.0 or tuning.shimmer_period_s <= 0.0:
		return false
	return fposmod(_clock_s + shimmer_phase_s, tuning.shimmer_period_s) < tuning.shimmer_length_s


## What this peer draws for it now: DRAWN_NORMAL, DRAWN_SHIMMER or DRAWN_NOTHING.
func drawn_state() -> StringName:
	if not concealed or revealed:
		return DRAWN_NORMAL
	return DRAWN_SHIMMER if shimmering() else DRAWN_NOTHING


## The interact prompt names the item lying here.
func prompt_target(_by: Node, locale: String) -> String:
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	return item.get_display_name(locale) if item != null else ""


func _apply_hold() -> void:
	if interactable != null:
		interactable.hold_time_s = tuning.concealed_pickup_hold_s if concealed else 0.0


# Any player in play within the reveal radius, by straight-line distance in tiles: the session's
# players (host-simulated on the host, interpolated on a client), or every player without one.
func _player_within() -> bool:
	var reach_px: float = _radius_tiles * TILE_PX
	for player: PlayerBody in _players():
		if player.left_island:
			continue
		if player.global_position.distance_to(global_position) <= reach_px:
			return true
	return false


func _players() -> Array[PlayerBody]:
	var found: Array[PlayerBody] = []
	var session := CoopSession.of(self)
	if session != null:
		for peer_id: int in session.peer_ids():
			var player := session.body(peer_id)
			if is_instance_valid(player):
				found.append(player)
		return found
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.GROUP):
		if node is PlayerBody:
			found.append(node as PlayerBody)
	return found


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null:
		return
	var took: int = player.inventory.add(item_id, count, uses_left)
	if took <= 0:
		return
	var item := player.inventory.item_for(item_id)
	for effect: EffectData in item.pickup_effects:
		EffectApplier.apply(effect, player, null)
	count -= took
	if count <= 0:
		interactable.enabled = false
		taken.emit(player, item_id)
		queue_free()
