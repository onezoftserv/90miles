class_name NetRequest
extends RefCounted
## One host or join attempt (net-platform "Hosting and joining may finish later"). It is both the
## answer and the cancel token: once cancelled, a peer the backend still delivers is closed and
## never installed.
##
## The backend answers once, with succeed() or fail(), inside its call or later; `answered` tells
## NetManager, which installs the peer and then settles the request. The state stays PENDING until
## settle() or cancel(), so READY always means the peer is installed. Signals carry the request
## instead of a bound copy: a callable bound to this object and stored in its own signal would be
## a reference cycle and leak.

enum Kind { HOST, JOIN }
enum State { PENDING, READY, FAILED, CANCELLED }

## Backend -> NetManager only: the backend answered, with a peer or with a failure reason.
signal answered(request: NetRequest)
## Once, when the state leaves PENDING. READY is emitted only after the peer is installed.
signal settled(request: NetRequest)

var kind: Kind = Kind.HOST
var state: State = State.PENDING
var reason: NetFailure.Reason = NetFailure.Reason.NONE
## Format arguments for the reason's line ([port] for PORT_UNAVAILABLE).
var reason_args: Array = []
## HOST: the port asked for.
var port: int = 0
## JOIN: where to.
var target: NetJoinTarget
## HOST, on success: what the lobby shows.
var info: NetHostInfo
## The offered peer, until NetManager installs it.
var peer: MultiplayerPeer

var _answered: bool = false


func _init(request_kind: Kind = Kind.HOST, host_port: int = 0, join_target: NetJoinTarget = null) -> void:
	kind = request_kind
	port = host_port
	target = join_target


func is_pending() -> bool:
	return state == State.PENDING


## True once the backend has answered, with a peer or a failure.
func is_answered() -> bool:
	return _answered


## Backend, exactly once. Ignored after the first answer, and the offered peer is closed when the
## request is no longer pending or already answered. A null peer counts as an unsupported failure.
func succeed(offered: MultiplayerPeer, host_info: NetHostInfo = null) -> void:
	if offered == null:
		fail(NetFailure.Reason.UNSUPPORTED)
		return
	if _answered or not is_pending():
		if offered != peer:
			offered.close()
		return
	_answered = true
	peer = offered
	info = host_info
	answered.emit(self)


## Backend, exactly once. Ignored after the first answer. NONE is treated as UNSUPPORTED, so a
## failure never goes without a reason.
func fail(why: NetFailure.Reason, args: Array = []) -> void:
	if _answered or not is_pending():
		return
	_answered = true
	reason = NetFailure.Reason.UNSUPPORTED if why == NetFailure.Reason.NONE else why
	reason_args = args.duplicate()
	answered.emit(self)


## NetManager only: stops waiting. A peer offered but not yet installed is closed, and any peer
## delivered later is closed by succeed().
func cancel() -> void:
	if not is_pending():
		return
	if peer != null:
		peer.close()
		peer = null
	reason = NetFailure.Reason.CANCELLED
	settle(State.CANCELLED)


## NetManager only: the request leaves PENDING once, and `settled` fires.
func settle(final_state: State) -> void:
	if not is_pending() or final_state == State.PENDING:
		return
	state = final_state
	settled.emit(self)
