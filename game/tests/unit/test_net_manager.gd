extends GutTest
## coop-networking "Host and join": NetManager creates the transport (ENet behind one
## factory) and sets the game's peer for hosting, joining and solo.


func after_each() -> void:
	NetManager.leave()


func test_default_port_is_7777() -> void:
	assert_eq(NetManager.DEFAULT_PORT, 7777)


func test_four_players_at_most() -> void:
	assert_eq(NetManager.MAX_PLAYERS, 4)


func test_solo_uses_the_offline_peer_and_opens_no_port() -> void:
	NetManager.start_solo()
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	assert_true(NetManager.multiplayer.is_server())
	assert_eq(NetManager.multiplayer.get_unique_id(), 1)
	assert_false(NetManager.is_online())


func test_a_server_peer_binds_the_requested_port() -> void:
	var probe := NetManager.create_server_peer(0)
	assert_not_null(probe)
	var free_port: int = NetManager.bound_port(probe)
	assert_gt(free_port, 0)
	probe.close()
	var peer := NetManager.create_server_peer(free_port)
	assert_not_null(peer)
	assert_eq(NetManager.bound_port(peer), free_port)
	peer.close()


func test_hosting_sets_the_peer_turns_relay_off_and_reports_the_port() -> void:
	watch_signals(NetManager)
	assert_eq(NetManager.host(0), OK)
	var peer := NetManager.multiplayer.multiplayer_peer
	assert_true(peer is ENetMultiplayerPeer)
	assert_true(NetManager.multiplayer.is_server())
	assert_true(NetManager.is_online())
	assert_false((NetManager.multiplayer as SceneMultiplayer).server_relay)
	assert_signal_emitted_with_parameters(NetManager, "hosted", [NetManager.bound_port(peer)])


func test_joining_needs_an_address_and_a_valid_port() -> void:
	assert_eq(NetManager.join("", NetManager.DEFAULT_PORT), ERR_INVALID_PARAMETER)
	assert_eq(NetManager.join("   ", NetManager.DEFAULT_PORT), ERR_INVALID_PARAMETER)
	assert_eq(NetManager.join("127.0.0.1", 0), ERR_INVALID_PARAMETER)
	assert_eq(NetManager.join("127.0.0.1", 65536), ERR_INVALID_PARAMETER)
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "nothing changed")


func test_joining_starts_connecting_as_a_client() -> void:
	assert_eq(NetManager.join("127.0.0.1", NetManager.DEFAULT_PORT), OK)
	var peer := NetManager.multiplayer.multiplayer_peer
	assert_true(peer is ENetMultiplayerPeer)
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTING)
	assert_false((NetManager.multiplayer as SceneMultiplayer).server_relay)


func test_leaving_returns_to_offline() -> void:
	NetManager.host(0)
	NetManager.leave()
	assert_true(NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	assert_false(NetManager.is_online())
