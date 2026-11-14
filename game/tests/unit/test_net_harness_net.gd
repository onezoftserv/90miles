extends GutTest
## NetHarness itself, over ENet on localhost. Every peer runs in this one process, so an ENet round
## trip lasts until the other side's next frame: a loaded machine looks like a congested link. With
## ENet's packet throttle on, slow frames after a calm connect cut the host's unreliable
## synchronizer packets to 1 in 32 for seconds, and a test waiting on synced state times out (the
## rejoin test in test_interact_prompt_net.gd, 2026-11-13). The harness keeps the throttle open.

const TIMEOUT_S: float = 5.0
## A frame this slow is a round trip far above the calm connect's (a few ms) and over the
## synchronizers' 50 ms interval, so the host sends a sync every frame.
const STALL_MS: int = 120
const STALLED_FRAMES: int = 16
## Syncs the client must get in those frames: the host sends one a frame, minus slack for the
## frames around the stall's edges. A throttled link lets through about 1 in 32 once its
## throttle has fallen, which takes a few slow frames (5 of 16 got through with ENet's default).
const MIN_SYNCS: int = 12
## Calm frames before the stall, so ENet's round-trip baseline is a calm one, as for a rejoin.
const CALM_FRAMES: int = 5

var net: NetHarness


## Blocks every process frame for `ms` milliseconds: a loaded machine.
class FrameStall:
	extends Node
	var ms: int = 0

	func _process(_delta: float) -> void:
		if ms > 0:
			OS.delay_msec(ms)


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func test_slow_frames_leave_the_hosts_packet_throttle_open() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var id: int = net.peer_id(client)
	var to_client: ENetPacketPeer = (host.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id)
	await _frames(CALM_FRAMES)
	var stall := FrameStall.new()
	stall.ms = STALL_MS
	add_child(autofree(stall))
	for i: int in STALLED_FRAMES:
		# Reliable traffic, acknowledged a slow frame later: each ack is a long round trip.
		host.update_roster.rpc_id(id, host.roster)
		await _frames(1)
	stall.ms = 0
	var limit: int = to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT)
	assert_eq(to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE), limit, "every unreliable packet to the client still goes out")


func test_a_client_keeps_getting_the_hosts_syncs_while_the_frames_stall() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var id: int = net.peer_id(client)
	var hosts_body := client.body(CoopSession.HOST_ID)
	var synced: Array[int] = [0]
	(hosts_body.get_node(^"StateSync") as MultiplayerSynchronizer).synchronized.connect(func() -> void: synced[0] += 1)
	await _frames(CALM_FRAMES)
	var stall := FrameStall.new()
	stall.ms = STALL_MS
	add_child(autofree(stall))
	synced[0] = 0
	for i: int in STALLED_FRAMES:
		host.update_roster.rpc_id(id, host.roster)
		await _frames(1)
	stall.ms = 0
	assert_gte(synced[0], MIN_SYNCS, "the host's state kept arriving (%d syncs in %d slow frames)" % [synced[0], STALLED_FRAMES])


func test_the_client_side_of_a_harness_connection_is_unthrottled_too() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var to_host: ENetPacketPeer = (client.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(CoopSession.HOST_ID)
	var to_client: ENetPacketPeer = (host.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(net.peer_id(client))
	var configured := func() -> bool:
		return to_host.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION) == 0
	assert_eq(to_client.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION), 0, "the host's side never slows")
	assert_true(await wait_until(configured, TIMEOUT_S), "ENet sent the setting to the client: its intents stay unthrottled")
