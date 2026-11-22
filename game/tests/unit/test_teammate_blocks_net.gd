extends GutTest
## ui-shell "HUD layout" (hud-window-kit design D7, owner answer B1) over ENet on localhost
## (NetHarness): a host and a client each list the other as a teammate block, with the right name,
## clothing chip, health bar and state word, read from what the host replicates; a dropped client
## reads "Desconectado" in grey on the host; and a client that joins later sees the same blocks.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0

var net: NetHarness
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _named(player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		_island(session)
		session.local_identity = PlayerIdentity.create()
		session.local_name = player_name


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


# The block of the teammate named `player_name` on `hud`, refreshed now, or null.
func _block(hud: RunHud, player_name: String) -> TeammateBlock:
	hud.refresh()
	for block: TeammateBlock in hud.teammate_blocks():
		if block.teammate_name == player_name:
			return block
	return null


func test_host_and_client_each_show_the_other_as_a_block() -> void:
	var host := net.add_host(_named("Yuni"))
	var client := await net.join(_named("Papo"))
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var papo_id: int = net.peer_id(client)
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	host.body(papo_id).meters.health = 40.0
	var replicated := func() -> bool: return is_equal_approx(client.body(papo_id).meters.health, 40.0)
	assert_true(await wait_until(replicated, TIMEOUT_S), "the client has its own health from the host")
	var papo_on_host := _block(host_hud, "Papo")
	var yuni_on_client := _block(client_hud, "Yuni")
	assert_not_null(papo_on_host, "the host lists Papo")
	assert_not_null(yuni_on_client, "the client lists Yuni")
	if papo_on_host == null or yuni_on_client == null:
		return
	assert_eq(papo_on_host.bar.value, 40.0, "Papo's bar on the host")
	assert_eq(yuni_on_client.bar.value, 100.0, "Yuni's bar on the client")
	assert_true(papo_on_host.chip.color.is_equal_approx(TeammateBlock.chip_color(host.body(papo_id).look_slot)), "Papo's chip is his look slot's colour")
	assert_true(yuni_on_client.chip.color.is_equal_approx(TeammateBlock.chip_color(client.body(CoopSession.HOST_ID).look_slot)), "Yuni's chip, as the host replicates her look slot")
	assert_ne(papo_on_host.chip.color, yuni_on_client.chip.color, "two players, two clothing colours")
	assert_eq(_block(client_hud, "Papo"), null, "no block for the local player")
	await wait_process_frames(2)
	var list := client_hud.teammates_panel.get_global_rect()
	assert_eq(list.end.x, 636.0, "right-anchored on the client")


func test_a_dropped_client_reads_desconectado_in_grey_and_a_joiner_sees_the_blocks() -> void:
	var host := net.add_host(_named("Yuni"))
	var dayana := await net.join(_named("Dayana"))
	var papo := await net.join(_named("Papo"))
	assert_not_null(dayana)
	assert_not_null(papo)
	if dayana == null or papo == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var host_hud := _hud(host)
	net.drop(papo)
	var dropped := func() -> bool:
		var block := _block(host_hud, "Papo")
		return block != null and block.state == "Desconectado"
	assert_true(await wait_until(dropped, TIMEOUT_S), "the host holds Papo as dropped")
	var block := _block(host_hud, "Papo")
	assert_true(block.state_label.get_theme_color(&"font_color").is_equal_approx(TeammateBlock.DROPPED_COLOR), "in grey")
	var late := await net.join(_named("Lola"))
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	var late_hud := _hud(late)
	var seen := func() -> bool:
		var yuni := _block(late_hud, "Yuni")
		var day := _block(late_hud, "Dayana")
		return yuni != null and day != null
	assert_true(await wait_until(seen, TIMEOUT_S), "the joiner lists the others as blocks")
