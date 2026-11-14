class_name NetBackend
extends RefCounted
## net-platform "Platform backend": one way to reach other players (ENet now; Steam, EOS or a
## console later). NetManager owns the only live instance and alone installs peers: a backend
## hands back a MultiplayerPeer through its NetRequest and never touches `multiplayer`. Every
## method is a safe default, so a backend overrides only what it has (Brogue CE's optional
## console slots, SPD's PlatformSupport defaults).
##
## A backend script must compile with no SDK present (build-verification "No platform SDK
## needed"): it reaches platform classes only through Engine.get_singleton() and ClassDB, and
## never writes their names.

## An accepted invite or a platform "join game", at any time (even before the title shows).
signal join_requested(target: NetJoinTarget)

## Set by NetBackendTable.create(): the backend's tuning and text (capabilities stay in code).
var profile: NetBackendProfile


## Platform start-up (SDK init, sign-in), once at boot. NONE means ready; any other reason makes
## host and join fail with it, and solo never depends on it. Safe to call again.
func start(_args: PackedStringArray) -> NetFailure.Reason:
	return NetFailure.Reason.NONE


## OK if `target` names something this backend can try to join.
func check_target(_target: NetJoinTarget) -> Error:
	return ERR_INVALID_PARAMETER


## Must end with request.succeed() or request.fail() exactly once, possibly before returning.
func host(request: NetRequest, _port: int) -> void:
	request.fail(NetFailure.Reason.UNSUPPORTED)


## Joins request.target. Must end with request.succeed() or request.fail() exactly once,
## possibly before returning.
func join(request: NetRequest) -> void:
	request.fail(NetFailure.Reason.UNSUPPORTED)


## Leaves the platform session (lobby, presence) and drops its own pending work. Never closes the
## peer: NetManager does. Safe with nothing open.
func leave() -> void:
	pass


## A join target from the launch command line, or null.
func launch_target(_args: PackedStringArray) -> NetJoinTarget:
	return null


## Every frame, also while the game is paused (platform callbacks).
func poll(_delta: float) -> void:
	pass
