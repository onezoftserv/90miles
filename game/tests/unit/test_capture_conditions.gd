extends GutTest
## guardacostas-capture, group 3 (design.md §9 "Code this needs"): the condition and effect kinds the
## capture scene's data uses. ANY_PLAYER over an ALL_OF across a party, BACKGROUND_PRESENT read from
## PlayerBody.background_id, FLAG_SET from the run's flags and PLAYERS_AT_LEAST over the scene's party,
## TAKE_ITEMS_WITH_CAPABILITY removing every fire source but a keepsake, and the two travels, which only
## the host carries out.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const FOTO: ItemData = preload("res://tests/fixtures/content/items/foto_test.tres")
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"

var net: NetHarness = null


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null


func _body(background: StringName = &"", morale: float = 100.0) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	body.auto_advance = false
	body.background_id = background
	body.meters.morale = morale
	return body


func _cond(kind: ConditionData.Kind, ref: StringName = &"", scope: ConditionData.Scope = ConditionData.Scope.ACTOR) -> ConditionData:
	var condition := ConditionData.new()
	condition.kind = kind
	condition.ref_id = ref
	condition.scope = scope
	return condition


# The persuasion condition of design.md §9: some player is a Maestro or a Médico with morale 60.
func _persuasion() -> ConditionData:
	var either := _cond(ConditionData.Kind.ANY_OF)
	either.children.append(_cond(ConditionData.Kind.BACKGROUND_PRESENT, &"maestro"))
	either.children.append(_cond(ConditionData.Kind.BACKGROUND_PRESENT, &"medico"))
	var morale := _cond(ConditionData.Kind.METER_AT_LEAST)
	morale.meter = DataEnums.Meter.MORALE
	morale.amount = 60.0
	var root := _cond(ConditionData.Kind.ALL_OF, &"", ConditionData.Scope.ANY_PLAYER)
	root.children.append(either)
	root.children.append(morale)
	return root


# --- conditions -----------------------------------------------------------------------------------

func test_any_player_passes_when_one_player_passes_every_child() -> void:
	var maestro := _body(&"maestro", 50.0)
	var medico := _body(&"medico", 70.0)
	var party: Array[PlayerBody] = [maestro, medico]
	assert_true(ConditionCheck.holds(_persuasion(), maestro, party), "the Médico at 70 passes for the party")
	assert_eq(ConditionCheck.passing_players(_persuasion(), party), [medico] as Array[PlayerBody], "only the Médico passes")
	# The Maestro's background and the Médico's morale do not add up to one passing player.
	var low_medico := _body(&"medico", 50.0)
	var high_nobody := _body(&"", 90.0)
	assert_false(ConditionCheck.holds(_persuasion(), low_medico, [low_medico, high_nobody] as Array[PlayerBody]))


func test_a_player_with_no_background_never_passes() -> void:
	var nobody := _body(&"", 100.0)
	assert_false(ConditionCheck.holds(_persuasion(), nobody, [nobody] as Array[PlayerBody]))


func test_a_downed_player_cannot_plead_for_the_party() -> void:
	var medico := _body(&"medico", 90.0)
	medico.meters.downed = true
	assert_false(ConditionCheck.holds(_persuasion(), medico, [medico] as Array[PlayerBody]), "only a standing player speaks")


func test_background_present_reads_the_players_background_id() -> void:
	var body := _body()
	var medico := _cond(ConditionData.Kind.BACKGROUND_PRESENT, &"medico")
	assert_false(ConditionCheck.holds(medico, body), "no background until the backgrounds change")
	FixtureBackgrounds.give(body, &"medico")
	assert_true(ConditionCheck.holds(medico, body))
	assert_false(ConditionCheck.holds(_cond(ConditionData.Kind.BACKGROUND_PRESENT, &"maestro"), body))


func test_players_at_least_counts_the_party_given() -> void:
	var a := _body()
	var b := _body()
	var two := _cond(ConditionData.Kind.PLAYERS_AT_LEAST, &"", ConditionData.Scope.PARTY)
	two.amount = 2.0
	assert_false(ConditionCheck.holds(two, a, [a] as Array[PlayerBody]), "one captured player: the singular")
	assert_true(ConditionCheck.holds(two, a, [a, b] as Array[PlayerBody]), "two: the plural")


func test_flag_set_reads_the_runs_flags() -> void:
	var host := await _host_alone()
	var body := host.body(1)
	var again := _cond(ConditionData.Kind.FLAG_SET, &"captura_previa", ConditionData.Scope.PARTY)
	assert_false(ConditionCheck.holds(again, body))
	host.run_record.set_flag(&"captura_previa")
	assert_true(ConditionCheck.holds(again, body))
	var loose := _body()
	assert_false(ConditionCheck.holds(again, loose), "a body in no session has no run")


# --- effects --------------------------------------------------------------------------------------

func test_taking_fire_sources_removes_the_lighter_and_keeps_keepsakes() -> void:
	var body := _body()
	var keepsake_lighter := ItemData.new()
	keepsake_lighter.id = &"zippo_test"
	keepsake_lighter.tags = [DataEnums.ItemTag.KEEPSAKE] as Array[DataEnums.ItemTag]
	keepsake_lighter.capabilities = [DataEnums.Capability.LIGHT_FIRE] as Array[DataEnums.Capability]
	keepsake_lighter.stack_size = 1
	body.inventory.register(keepsake_lighter)
	body.inventory.register(FOTO)
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"knife", 1)
	body.inventory.add(&"rope", 3)
	body.inventory.add(&"foto_test", 1)
	body.inventory.add(&"zippo_test", 1)
	var take := EffectData.new()
	take.kind = EffectData.Kind.TAKE_ITEMS_WITH_CAPABILITY
	take.capability = DataEnums.Capability.LIGHT_FIRE
	EffectApplier.apply(take, body, body)
	assert_eq(body.inventory.count_id(&"lighter"), 0, "the lighter is a fire source")
	assert_eq(body.inventory.count_id(&"knife"), 1)
	assert_eq(body.inventory.count_id(&"rope"), 3)
	assert_eq(body.inventory.count_id(&"foto_test"), 1, "keepsakes are always kept")
	assert_eq(body.inventory.count_id(&"zippo_test"), 1, "a keepsake that lights fire is kept too")


func test_inventory_removes_every_item_with_a_capability_except_a_tag() -> void:
	var body := _body()
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"knife", 1)
	var taken := body.inventory.take_capability(DataEnums.Capability.LIGHT_FIRE, DataEnums.ItemTag.KEEPSAKE)
	assert_eq(taken, [&"lighter"] as Array[StringName])
	assert_eq(body.inventory.capability_slot(DataEnums.Capability.LIGHT_FIRE), -1)


func test_taking_fire_sources_from_the_party_takes_them_from_every_player() -> void:
	var host := await _host_alone()
	var body := host.body(1)
	body.inventory.add(&"lighter", 1)
	var take := EffectData.new()
	take.kind = EffectData.Kind.TAKE_ITEMS_WITH_CAPABILITY
	take.capability = DataEnums.Capability.LIGHT_FIRE
	take.target = EffectData.Target.PARTY
	EffectApplier.apply(take, body, body)
	assert_eq(body.inventory.count_id(&"lighter"), 0)


func test_the_travel_effects_move_the_party_on_the_host_only() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var next := EffectData.new()
	next.kind = EffectData.Kind.TRAVEL_NEXT_ISLAND
	var back := EffectData.new()
	back.kind = EffectData.Kind.TRAVEL_PREVIOUS_ISLAND
	# A client applying them (it never should) moves nobody.
	EffectApplier.apply(next, client.body(net.peer_id(client)), client.body(net.peer_id(client)))
	await wait_process_frames(3)
	assert_eq(_travel(host).island.layout.id, SANDBAR, "the host stays")
	assert_eq(_travel(client).island.layout.id, SANDBAR, "the client never loads on its own")
	# The host's next island: the coast cay, for both.
	EffectApplier.apply(next, host.body(1), host.body(1))
	assert_true(await wait_until(func() -> bool: return _travel(client).island.layout.id == COAST, 6.0))
	assert_eq(_travel(host).island.layout.id, COAST)
	assert_eq(_travel(host).islands_reached, 2)
	assert_eq(_travel(client).islands_reached, 2, "the index rides in the travel message")
	# The host's previous island: the sandbar again, still 2 reached on both.
	EffectApplier.apply(back, host.body(1), host.body(1))
	assert_true(await wait_until(func() -> bool: return _travel(client).island.layout.id == SANDBAR, 6.0))
	assert_eq(_travel(host).island.layout.id, SANDBAR)
	assert_eq(_travel(host).islands_reached, 2)
	assert_eq(_travel(client).islands_reached, 2)


# --- helpers --------------------------------------------------------------------------------------

func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _host_alone() -> CoopSession:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	await wait_process_frames(2)
	net.silence_input()
	return host


func _pair() -> Array[CoopSession]:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


