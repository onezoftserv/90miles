extends GutTest
## coop-reconnect "Reclaiming a player": the host's map of player ids for a run. A player's id
## with its secret reclaims it: one who dropped, or one whose old connection is still open (a
## takeover). A wrong secret, no id, or the host's own id joins as a guest (a new player whose
## identity is not kept). Offline.

var registry: IdentityRegistry
var papo: PlayerIdentity
var dropped: Array[int] = []


func before_each() -> void:
	registry = IdentityRegistry.new()
	papo = PlayerIdentity.create()
	dropped = []


func _is_dropped(peer_id: int) -> bool:
	return dropped.has(peer_id)


func test_a_new_id_is_kept_for_its_peer() -> void:
	var outcome := registry.claim(papo.id, papo.secret, 5, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.NEW)
	assert_eq(registry.peer_for(papo.id), 5)


func test_a_dropped_players_id_and_secret_reclaim_it() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	dropped = [5]
	var outcome := registry.claim(papo.id, papo.secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.RECLAIM)
	assert_eq(outcome.old_peer, 5)
	assert_eq(registry.peer_for(papo.id), 9, "the id now belongs to the new peer")


func test_a_connected_players_id_and_secret_take_it_over() -> void:
	# Papo's client crashed and came back before the host noticed the old connection was dead.
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	var outcome := registry.claim(papo.id, papo.secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.TAKEOVER)
	assert_eq(outcome.old_peer, 5)
	assert_eq(registry.peer_for(papo.id), 9)


func test_an_id_in_use_with_a_wrong_secret_is_a_guest() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	var outcome := registry.claim(papo.id, PlayerIdentity.create().secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.peer_for(papo.id), 5, "Papo keeps his id")


func test_the_hosts_own_player_is_never_claimed() -> void:
	# A host and a client from one install share the id; the client joins as a new player.
	registry.reserve(papo.id, papo.secret, IdentityRegistry.HOST_PEER)
	var outcome := registry.claim(papo.id, papo.secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.peer_for(papo.id), IdentityRegistry.HOST_PEER)


func test_the_host_reserves_its_id_even_if_a_client_claimed_it_first() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	registry.reserve(papo.id, papo.secret, IdentityRegistry.HOST_PEER)
	assert_eq(registry.peer_for(papo.id), IdentityRegistry.HOST_PEER)


func test_a_wrong_secret_is_a_guest() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	dropped = [5]
	var outcome := registry.claim(papo.id, PlayerIdentity.create().secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.peer_for(papo.id), 5, "Papo's body still waits for Papo")


func test_no_id_or_a_malformed_one_is_a_guest() -> void:
	assert_eq(registry.claim("", "", 9, _is_dropped).kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.claim("zz", papo.secret, 9, _is_dropped).kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.claim(papo.id, "short", 9, _is_dropped).kind, IdentityRegistry.Claim.GUEST)
	assert_eq(registry.peer_for(papo.id), 0, "nothing kept")


func test_a_released_player_comes_back_as_new() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	registry.release_peer(5)
	assert_eq(registry.peer_for(papo.id), 0)
	var outcome := registry.claim(papo.id, papo.secret, 9, _is_dropped)
	assert_eq(outcome.kind, IdentityRegistry.Claim.NEW, "removed after 90 s: a new player")
	assert_eq(registry.peer_for(papo.id), 9)


func test_the_registry_never_hands_out_secrets() -> void:
	registry.claim(papo.id, papo.secret, 5, _is_dropped)
	for property: Dictionary in registry.get_property_list():
		var value: Variant = registry.get(property["name"])
		assert_false(str(value).contains(papo.secret), "only a hash of the secret is kept")
