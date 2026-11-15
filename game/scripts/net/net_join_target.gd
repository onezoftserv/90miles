class_name NetJoinTarget
extends RefCounted
## Where to join, opaque to the shell (net-platform "Platform backend"): an address and port for
## ENet, or a platform token (a Steam lobby id, an EOS product user id, a console session id).
## `label` is what the join screen shows while it connects.

var address: String = ""
var port: int = 0
var token: String = ""
var label: String = ""


## An ENet target; its label is "address:port".
static func at_address(host_address: String, host_port: int) -> NetJoinTarget:
	var target := NetJoinTarget.new()
	target.address = host_address.strip_edges()
	target.port = host_port
	target.label = "%s:%d" % [target.address, host_port]
	return target


## A platform target: the backend reads `platform_token`; the player sees `shown_label`.
static func with_token(platform_token: String, shown_label: String) -> NetJoinTarget:
	var target := NetJoinTarget.new()
	target.token = platform_token
	target.label = shown_label
	return target


## True for an address target (no platform token).
func is_address() -> bool:
	return token.is_empty()
