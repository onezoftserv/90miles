class_name SpectateView
extends RefCounted
## ui-shell "Spectating a teammate": whom the local player watches while they are dead or wait out of
## play on the shore, and the camera that shows it. A pure view: it reads only replicated state (the
## meters' `dead`, `left_island`, the drop flag, positions), sends nothing and changes nothing in the
## simulation, so the host, a client, a late joiner and a rejoiner all work it out the same way.
##
## The watched teammate's own body camera shows the view, because it already keeps to whatever that
## body is on: the island, the next island or a crossing's sea. It holds the body, not a peer id: a
## removal frees the body and a rejoin moves it to another peer. RunHud calls `update()` every frame,
## so a rejoiner who takes back a body that died while away watches at once, with no `died` signal.
## Solo never watches: a solo death goes straight to the run summary.

var session: CoopSession = null
var local_peer: int = CoopSession.HOST_ID
var solo: bool = true
## The local player's body (RunHud's `_bind_local`), or null before it spawns.
var own: PlayerBody = null
var _watched: PlayerBody = null
## The body whose camera this view turned on, or null.
var _camera_on: PlayerBody = null
## Where the last watched teammate stood, to pick the nearest one after they are lost.
var _view_at: Vector2 = Vector2.ZERO
var _watching: bool = false


func bind(run_session: CoopSession, local_peer_id: int, is_solo: bool) -> void:
	session = run_session
	local_peer = local_peer_id
	solo = is_solo


## The local player's body from now on (a rejoined client's reclaimed body, say).
func set_own(body: PlayerBody) -> void:
	if body == own:
		return
	_stop()
	own = body


## Whether the local player watches a teammate now.
func active() -> bool:
	return _watching and is_instance_valid(_watched)


## The watched teammate's body, or null.
func watched() -> PlayerBody:
	return _watched if active() else null


## Whether the watched teammate's client is disconnected (only watched when nobody connected is left).
func watched_dropped() -> bool:
	return active() and session.is_dropped(session.peer_of(_watched))


## Whether `body`'s player watches a teammate rather than their own body: dead, or waiting on the
## shore, and never in solo.
static func wants_to_watch(body: PlayerBody, is_solo: bool) -> bool:
	if is_solo or not is_instance_valid(body) or body.meters == null:
		return false
	return body.meters.dead or body.left_island


## Whom `body`'s player may watch, in the teammate list's order (peer id): teammates who are not dead
## and not waiting on the shore. Disconnected ones only when no connected one is left.
static func watchable(run_session: CoopSession, body: PlayerBody) -> Array[PlayerBody]:
	var connected: Array[PlayerBody] = []
	var dropped: Array[PlayerBody] = []
	for peer_id: int in run_session.peer_ids():
		var other := run_session.body(peer_id)
		if other == null or other == body or not other.is_inside_tree():
			continue
		if other.meters.dead or other.left_island:
			continue
		if run_session.is_dropped(peer_id):
			dropped.append(other)
		else:
			connected.append(other)
	return connected if not connected.is_empty() else dropped


## The body in `candidates` nearest `from`; ties go to list order. Null when there is none.
static func nearest(candidates: Array[PlayerBody], from: Vector2) -> PlayerBody:
	var best: PlayerBody = null
	var best_distance: float = INF
	for candidate: PlayerBody in candidates:
		var distance: float = from.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## The body `direction` steps (1 next, -1 previous) from `current` in `candidates`, wrapping round.
## A `current` that is not in the list steps from the start.
static func step(candidates: Array[PlayerBody], current: PlayerBody, direction: int) -> PlayerBody:
	if candidates.is_empty():
		return null
	var index: int = candidates.find(current)
	if index < 0:
		return candidates[0] if direction >= 0 else candidates[candidates.size() - 1]
	return candidates[posmod(index + signi(direction), candidates.size())]


## Works out whom to watch now and points the view there; called every frame.
func update() -> void:
	if session == null or not wants_to_watch(own, solo):
		_stop()
		return
	var candidates: Array[PlayerBody] = watchable(session, own)
	if candidates.is_empty():
		_stop()
		return
	if not is_instance_valid(_watched) or not candidates.has(_watched):
		# The first pick is nearest the dead player; after a loss, nearest the one just lost.
		_watched = nearest(candidates, _view_at if _watching else own.global_position)
	_watching = true
	_view_at = _watched.global_position
	_show()


## Steps the view to the next (1) or previous (-1) watchable teammate. Does nothing while not watching.
func cycle(direction: int) -> void:
	update()
	if not active():
		return
	var next: PlayerBody = step(watchable(session, own), _watched, direction)
	if next == null or next == _watched:
		return
	_watched = next
	_view_at = next.global_position
	_show()


# The watched body's camera on and current; the own camera and any camera left behind off. A camera
# found off again (rebind() runs refresh_local()) is turned back on.
func _show() -> void:
	if _camera_on != _watched:
		if is_instance_valid(_camera_on) and _camera_on != own:
			_camera_on.camera.enabled = false
		_camera_on = _watched
	if is_instance_valid(own) and own.camera.enabled:
		own.camera.enabled = false
	var camera: Camera2D = _watched.camera
	if not camera.enabled or (camera.is_inside_tree() and not camera.is_current()):
		camera.enabled = true
		if camera.is_inside_tree():
			camera.make_current()


# Back to the own body: the watched camera off, the own camera as the body sets it.
func _stop() -> void:
	if is_instance_valid(_camera_on) and _camera_on != own:
		_camera_on.camera.enabled = false
	var was_watching: bool = _watching
	_camera_on = null
	_watched = null
	_watching = false
	if was_watching and is_instance_valid(own):
		own.refresh_local()
		if own.camera.enabled and own.camera.is_inside_tree():
			own.camera.make_current()
