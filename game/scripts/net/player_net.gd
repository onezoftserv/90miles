class_name PlayerNet
extends Node
## A player's networking component (coop-networking "Host authority"), a child of PlayerBody.
## Inert until the session attaches it; then it steps, predicts or draws the body by role:
## - HOST (every body on the host): steps the body once per queued intent, with the intent's
##   own time step, and writes the shadow fields the StateSync synchronizer sends at 20 Hz.
## - PREDICTED (a client's own body): steps the body from local input at once (no
##   interactions), sends each intent to the host, and on each host state resets to it and
##   replays the intents the host has not processed yet.
## - REMOTE (other bodies on a client): never simulates; draws the body DELAY_S behind the
##   newest host state.
## A downed body is never predicted: its owner draws it like a remote one and sends nothing.

enum Role {
	INACTIVE,
	HOST,
	PREDICTED,
	REMOTE,
}

## Intents the host steps for one body in one physics frame; the rest wait for the next frame.
const MAX_STEPS_PER_FRAME: int = 8
## Intents the host holds for one body; older ones are dropped (the rate limits keep the
## queue far below this).
const MAX_QUEUED: int = 60

var role: Role = Role.INACTIVE
## The peer whose player this is.
var owner_peer: int = 1
## Local time in seconds, used to time host states for interpolation. Tests replace it.
var clock: Callable

# Shadow fields: written on the host, replicated by StateSync, read on clients.
var net_position: Vector2 = Vector2.ZERO
var net_energy: float = SurvivalMeters.MAX_ENERGY
var net_ack_seq: int = 0
var net_model_state: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var net_movement: int = MovementStep.Move.WALK
var net_stealth: int = MovementStep.Stealth.VISIBLE
var net_downed: bool = false
## The player's inventory as Inventory.to_net() writes it: the host's, shown on every peer.
var net_inventory: Array = []

## The client's unacknowledged intents (PREDICTED).
var buffer: PredictionBuffer = PredictionBuffer.new()
## Host states of this body, for drawing it (REMOTE, or PREDICTED while downed).
var interpolator: SnapshotInterpolator = SnapshotInterpolator.new()

# send_intent(seq: int, intent: MoveIntent, delta: float): hands an intent to the session.
var _send: Callable
var _queue: Array[PendingIntent] = []
var _last_queued_seq: int = 0
var _sent_seq: int = 0


func _init() -> void:
	# After PlayerInput (-10), so the intent is this frame's; before the body (0).
	process_physics_priority = -5
	clock = _ticks_s


func _ready() -> void:
	var sync := get_parent().get_node_or_null(^"StateSync") as MultiplayerSynchronizer
	if sync != null:
		sync.synchronized.connect(apply_host_state)


## Which role a body gets on this peer.
static func role_for(is_server: bool, local_peer: int, owner: int) -> Role:
	if is_server:
		return Role.HOST
	if owner == local_peer:
		return Role.PREDICTED
	return Role.REMOTE


## Hands the body to the network. Call on every peer before the body enters the tree: the
## body belongs to `peer_id` (so is_multiplayer_authority() means "my player"), while its
## StateSync stays with the host. `send` is the session's send_intent.
func attach(peer_id: int, net_role: Role, send: Callable) -> void:
	owner_peer = peer_id
	role = net_role
	_send = send
	var body := _body()
	body.auto_advance = false
	# A fresh body's state, so a host state sent before the host's first frame is right.
	net_position = body.position
	body.set_multiplayer_authority(peer_id)
	var sync := body.get_node_or_null(^"StateSync") as MultiplayerSynchronizer
	if sync != null:
		sync.set_multiplayer_authority(1, false)


## Host: queues an intent from this body's peer. Refuses one that is not newer than the last.
func enqueue(seq: int, intent: MoveIntent, delta: float) -> bool:
	if role != Role.HOST or seq <= _last_queued_seq:
		return false
	_last_queued_seq = seq
	_queue.append(PendingIntent.create(seq, intent, delta))
	while _queue.size() > MAX_QUEUED:
		_queue.pop_front()
	return true


## Client: takes the host state just received (StateSync.synchronized). A state that is not
## finite is ignored.
func apply_host_state() -> void:
	if not net_position.is_finite() or not is_finite(net_energy):
		return
	_body().inventory.from_net(net_inventory)
	match role:
		Role.PREDICTED:
			if net_downed:
				# Nothing to replay once the player is down: the host acks only what it queued.
				buffer.clear()
				_take_drawn_state()
			else:
				if _body().downed:
					_body().set_downed(false)
					interpolator.clear()
				_reconcile()
		Role.REMOTE:
			_take_drawn_state()


## Client: moves a drawn body to where the host states put it at local time `now_s`.
func update_drawn_position(now_s: float) -> void:
	var body := _body()
	body.position = interpolator.sample_delayed(now_s, body.position)


func _physics_process(delta: float) -> void:
	match role:
		Role.HOST:
			if owner_peer == multiplayer.get_unique_id():
				_sent_seq += 1
				_send_intent(_sent_seq, _body().intent, delta)
			_step_host(delta)
			_write_shadow()
		Role.PREDICTED:
			if not _body().downed:
				_predict(delta)


func _process(_delta: float) -> void:
	if role == Role.REMOTE or (role == Role.PREDICTED and _body().downed):
		update_drawn_position(clock.call())


func _step_host(delta: float) -> void:
	var body := _body()
	if body.downed:
		# Intents are acknowledged but not applied; the body still moves when dragged.
		if not _queue.is_empty():
			net_ack_seq = _queue[_queue.size() - 1].seq
			_queue.clear()
		body.advance(delta)
		return
	var steps: int = 0
	while not _queue.is_empty() and steps < MAX_STEPS_PER_FRAME:
		var pending: PendingIntent = _queue.pop_front()
		body.intent = pending.intent
		body.advance(pending.delta)
		net_ack_seq = pending.seq
		steps += 1


func _write_shadow() -> void:
	var body := _body()
	net_position = body.position
	net_energy = body.meters.energy
	net_model_state = body.model.get_state()
	net_movement = body.movement_state
	net_stealth = body.stealth_state
	net_downed = body.downed
	var inventory_state: Array = body.inventory.to_net()
	if inventory_state != net_inventory:
		net_inventory = inventory_state


func _predict(delta: float) -> void:
	var body := _body()
	var seq := buffer.push(body.intent, delta)
	_send_intent(seq, body.intent, delta)
	body.advance(delta, false)


func _reconcile() -> void:
	var body := _body()
	buffer.acknowledge(net_ack_seq)
	var current := body.intent
	body.position = net_position
	body.meters.energy = net_energy
	body.model.set_state(net_model_state)
	for pending: PendingIntent in buffer.pending():
		body.intent = pending.intent
		body.advance(pending.delta, false)
	body.intent = current


func _take_drawn_state() -> void:
	var body := _body()
	if body.downed != net_downed:
		body.set_downed(net_downed)
	interpolator.push(clock.call(), net_position)
	body.meters.energy = net_energy
	body.movement_state = net_movement as MovementStep.Move
	body.stealth_state = net_stealth as MovementStep.Stealth


func _send_intent(seq: int, intent: MoveIntent, delta: float) -> void:
	if _send.is_valid():
		_send.call(seq, intent, delta)


func _body() -> PlayerBody:
	return get_parent() as PlayerBody


func _ticks_s() -> float:
	return Time.get_ticks_usec() / 1000000.0
