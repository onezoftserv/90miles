extends GutTest
## net-platform "Backend choice" and "Failure reasons": game/resources/net_backends.tres holds
## every backend's profile and the failure lines, Spanish first with English beside. The
## backend is picked by build feature tag, ENet by default, and anything unreadable gives ENet.

const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")
const ENET_SCRIPT: String = "res://scripts/net/enet_backend.gd"


func _profile(profile_id: StringName, tag: String, script_path: String = ENET_SCRIPT) -> NetBackendProfile:
	var profile := NetBackendProfile.new()
	profile.id = profile_id
	profile.feature_tag = tag
	profile.backend_script = script_path
	return profile


func _table(rows: Array[NetBackendProfile], default_id: StringName = &"enet") -> NetBackendTable:
	var table := NetBackendTable.new()
	table.default_id = default_id
	table.profiles = rows
	return table


func test_the_shipped_table_loads_and_defaults_to_enet() -> void:
	assert_true(ResourceLoader.exists(NetBackendTable.PATH), "net_backends.tres is shipped")
	var table := NetBackendTable.load_shipped()
	assert_not_null(table)
	assert_eq(table.default_id, &"enet")
	var none := func(_tag: String) -> bool: return false
	var chosen := table.pick(none)
	assert_not_null(chosen)
	assert_eq(chosen.id, &"enet")
	assert_eq(chosen.feature_tag, "", "ENet is never picked by a tag, only as the default")
	assert_true(table.create(chosen) is EnetBackend)


func test_profile_ids_are_unique_and_every_script_is_a_backend() -> void:
	var table := NetBackendTable.load_shipped()
	assert_gt(table.profiles.size(), 0)
	var seen: Array[StringName] = []
	for profile: NetBackendProfile in table.profiles:
		assert_not_null(profile)
		assert_false(seen.has(profile.id), "id %s is unique" % profile.id)
		seen.append(profile.id)
		assert_true(ResourceLoader.exists(profile.backend_script), "%s exists" % profile.backend_script)
		var script := load(profile.backend_script) as Script
		assert_not_null(script, "%s loads by path" % profile.backend_script)
		if script != null:
			assert_true(script.new() is NetBackend, "%s is a NetBackend" % profile.backend_script)


func test_enet_profile_keeps_the_transport_timeout() -> void:
	var table := NetBackendTable.load_shipped()
	var enet := table.profile(&"enet")
	assert_not_null(enet)
	assert_eq(enet.join_timeout_s, 0.0, "ENet keeps its own timeout")
	assert_eq(enet.backend_script, ENET_SCRIPT)
	assert_eq(enet.lobby_note.size(), 2, "[es, en]")
	assert_string_contains(enet.lobby_note[0], "%d")
	assert_string_contains(enet.lobby_note[1], "%d")
	assert_eq(table.lobby_note(enet, 7780),
			"Los demás se unen por IP en el puerto UDP 7780. Por internet, abre ese puerto en tu router.")
	assert_eq(table.lobby_note(enet, 7777),
			"Los demás se unen por IP en el puerto UDP 7777. Por internet, abre ese puerto en tu router.",
			"port 7777 reads as the lobby scene's own note")
	assert_eq(table.lobby_note(_profile(&"bare", ""), 7777), "", "no note keeps the scene's own")


func test_every_reason_but_none_and_cancelled_has_a_spanish_line() -> void:
	var table := NetBackendTable.load_shipped()
	for value: int in NetFailure.Reason.values():
		var reason := value as NetFailure.Reason
		var pair: PackedStringArray = table.failure_texts.get(reason, PackedStringArray())
		var reason_name: String = NetFailure.Reason.keys()[value]
		if reason == NetFailure.Reason.NONE or reason == NetFailure.Reason.CANCELLED:
			assert_eq(pair.size(), 0, "%s has no line" % reason_name)
			assert_eq(table.failure_text(reason), "", "%s shows nothing" % reason_name)
			continue
		assert_eq(pair.size(), 2, "%s is an [es, en] pair" % reason_name)
		if pair.size() == 2:
			assert_false(pair[0].strip_edges().is_empty(), "%s has a Spanish line" % reason_name)
			assert_false(pair[1].strip_edges().is_empty(), "%s has an English line" % reason_name)


func test_each_line_sits_on_its_reason() -> void:
	var table := NetBackendTable.load_shipped()
	assert_eq(table.failure_text(NetFailure.Reason.TIMED_OUT), "El anfitrión no respondió.")
	assert_eq(table.failure_text(NetFailure.Reason.FULL), "La partida está llena.")
	assert_eq(table.failure_text(NetFailure.Reason.NOT_FOUND), "Esa partida ya no existe.")
	assert_eq(table.failure_text(NetFailure.Reason.UNSUPPORTED), "Esta versión del juego no puede hacer eso.")
	assert_eq(table.failure_text(NetFailure.Reason.PLATFORM_UNAVAILABLE), "La plataforma en línea no está disponible.")
	assert_eq(table.failure_text(NetFailure.Reason.NOT_SIGNED_IN), "Inicia sesión en la plataforma para jugar en línea.")
	assert_eq(table.failure_text(NetFailure.Reason.NO_PRIVILEGE), "Tu cuenta no puede jugar en línea.")
	assert_eq(table.failure_text(NetFailure.Reason.INVALID_TARGET), "Esa dirección no sirve.")


func test_enet_lines_match_the_screens() -> void:
	var table := NetBackendTable.load_shipped()
	assert_eq(table.failure_text(NetFailure.Reason.UNREACHABLE), JoinScreen.FAILED)
	assert_eq(table.failure_text(NetFailure.Reason.PORT_UNAVAILABLE, [7777]), "No se pudo abrir el puerto 7777.")
	var host_lost := HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child_autofree(host_lost)
	assert_eq(table.failure_text(NetFailure.Reason.HOST_LEFT), host_lost.message.text)


func test_english_is_picked_when_asked() -> void:
	var table := NetBackendTable.load_shipped()
	assert_eq(table.failure_text(NetFailure.Reason.UNREACHABLE, [], "en"), "Could not connect.")
	assert_eq(table.failure_text(NetFailure.Reason.PORT_UNAVAILABLE, [7780], "en"), "Could not open port 7780.")
	assert_eq(table.failure_text(NetFailure.Reason.FULL, [], "en_US"), "The game is full.")
	assert_eq(table.lobby_note(table.profile(&"enet"), 7780, "en"),
			"Others join by IP on UDP port 7780. Over the internet, forward that port on your router.")


func test_a_line_without_its_arguments_is_left_as_written() -> void:
	var table := NetBackendTable.load_shipped()
	assert_eq(table.failure_text(NetFailure.Reason.PORT_UNAVAILABLE), "No se pudo abrir el puerto %d.",
			"no arguments: no format error")
	assert_eq(table.failure_text(NetFailure.Reason.FULL, [3]), "La partida está llena.",
			"a line with no placeholder ignores extra arguments")


func test_pick_prefers_a_present_feature_tag_then_the_default() -> void:
	var enet := _profile(&"enet", "")
	var steam := _profile(&"steam", "steam")
	var eos := _profile(&"eos", "eos")
	var table := _table([enet, steam, eos] as Array[NetBackendProfile])
	var with_steam := func(tag: String) -> bool: return tag == "steam"
	var with_eos := func(tag: String) -> bool: return tag == "eos"
	var with_none := func(_tag: String) -> bool: return false
	var with_all := func(_tag: String) -> bool: return true
	assert_eq(table.pick(with_steam), steam)
	assert_eq(table.pick(with_eos), eos)
	assert_eq(table.pick(with_none), enet, "no tag present: the default")
	assert_eq(table.pick(with_all), steam, "the first listed tag wins; an empty tag never auto-picks")


func test_a_missing_default_or_bad_script_still_gives_enet() -> void:
	var steam := _profile(&"steam", "steam")
	var no_default := _table([steam] as Array[NetBackendProfile], &"missing")
	var with_none := func(_tag: String) -> bool: return false
	var fallback := no_default.pick(with_none)
	assert_not_null(fallback, "a missing default still gives a profile")
	assert_eq(fallback.id, &"enet")
	assert_eq(fallback.backend_script, ENET_SCRIPT)
	assert_true(no_default.create(fallback) is EnetBackend)
	var table := _table([_profile(&"enet", "")] as Array[NetBackendProfile])
	for bad_path: String in ["", "res://scripts/net/no_such_backend.gd", "res://scripts/net/net_peers.gd"]:
		var made := table.create(_profile(&"broken", "broken", bad_path))
		assert_true(made is EnetBackend, "%s gives ENet" % bad_path)
		assert_not_null(made.profile, "the fallback carries a profile")
		assert_eq(made.profile.id, &"enet", "the fallback carries ENet's profile")
	var nothing := table.create(null)
	assert_true(nothing is EnetBackend)
	assert_not_null(nothing.profile)


func test_create_hands_the_backend_its_profile() -> void:
	var table := NetBackendTable.load_shipped()
	var enet := table.profile(&"enet")
	var made := table.create(enet)
	assert_true(made is EnetBackend)
	assert_eq(made.profile, enet)


func test_an_unreadable_table_gives_enet() -> void:
	for path: String in ["res://resources/no_such_table.tres", "res://resources/hud_text.tres"]:
		var table := NetBackendTable.load_shipped(path)
		assert_not_null(table, "%s still gives a table" % path)
		var with_none := func(_tag: String) -> bool: return false
		var chosen := table.pick(with_none)
		assert_eq(chosen.id, &"enet")
		assert_true(table.create(chosen) is EnetBackend)
	var fallback := NetBackendTable.enet_only()
	assert_eq(fallback.profiles.size(), 1)
	assert_eq(fallback.profiles[0].join_timeout_s, 0.0)
	assert_eq(fallback.failure_text(NetFailure.Reason.UNREACHABLE), "", "the in-code fallback has no texts")


func test_each_load_is_a_copy_of_the_shipped_table() -> void:
	var first := NetBackendTable.load_shipped()
	first.profiles.clear()
	first.failure_texts.clear()
	first.default_id = &"changed"
	var second := NetBackendTable.load_shipped()
	assert_ne(second, first)
	assert_eq(second.default_id, &"enet", "the shipped table is not changed through a copy")
	assert_eq(second.profiles.size(), 1)
	assert_eq(second.failure_text(NetFailure.Reason.FULL), "La partida está llena.")
