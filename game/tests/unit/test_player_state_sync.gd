extends GutTest
## coop-networking "Host authority": each player's host state reaches clients 20 times per
## second through one synchronizer owned by the host, while the body belongs to its peer.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SHADOW_FIELDS: Array[String] = [
	"PlayerNet:net_ack_seq",
	"PlayerNet:net_downed",
	"PlayerNet:net_energy",
	"PlayerNet:net_model_state",
	"PlayerNet:net_movement",
	"PlayerNet:net_position",
	"PlayerNet:net_stealth",
	# survival-meters values the client only shows (energy travels as net_energy, because the
	# client's prediction spends it).
	"SurvivalMeters:dead",
	"SurvivalMeters:downed",
	"SurvivalMeters:downed_time_left_s",
	"SurvivalMeters:hallucinating",
	"SurvivalMeters:health",
	"SurvivalMeters:heat",
	"SurvivalMeters:hunger",
	"SurvivalMeters:last_stand",
	"SurvivalMeters:morale",
	"SurvivalMeters:sunstroke",
	"SurvivalMeters:thirst",
]


func _sync_of(body: PlayerBody) -> MultiplayerSynchronizer:
	return body.get_node(^"StateSync") as MultiplayerSynchronizer


func test_state_sync_runs_at_20_hz() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	var sync := _sync_of(body)
	assert_not_null(sync)
	assert_eq(sync.replication_interval, 0.05)


func test_state_sync_replicates_the_shadow_fields_always_and_at_spawn() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	var config := _sync_of(body).replication_config
	var paths: Array[String] = []
	for path: NodePath in config.get_properties():
		paths.append(String(path))
	paths.sort()
	assert_eq(paths, SHADOW_FIELDS)
	for path: NodePath in config.get_properties():
		assert_true(config.property_get_spawn(path), "%s sent at spawn" % path)
		assert_eq(config.property_get_replication_mode(path), SceneReplicationConfig.REPLICATION_MODE_ALWAYS, "%s" % path)


func test_every_replicated_field_exists() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	for path: String in SHADOW_FIELDS:
		var node_path := NodePath(path)
		var node := body.get_node(NodePath(node_path.get_concatenated_names()))
		assert_true(node.get(node_path.get_concatenated_subnames()) != null, path)


func test_attach_gives_the_body_to_its_peer_and_the_state_to_the_host() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	(body.get_node(^"PlayerNet") as PlayerNet).attach(5, PlayerNet.Role.REMOTE, func(_s: int, _i: MoveIntent, _d: float) -> void: pass)
	add_child_autofree(body)
	assert_eq(body.get_multiplayer_authority(), 5)
	assert_eq(body.net.get_multiplayer_authority(), 5)
	assert_eq(_sync_of(body).get_multiplayer_authority(), 1)


func test_a_body_owned_by_another_peer_has_no_camera_or_input() -> void:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	(body.get_node(^"PlayerNet") as PlayerNet).attach(5, PlayerNet.Role.REMOTE, func(_s: int, _i: MoveIntent, _d: float) -> void: pass)
	add_child_autofree(body)
	assert_false(body.camera.enabled)
	assert_false(body.player_input.enabled)
