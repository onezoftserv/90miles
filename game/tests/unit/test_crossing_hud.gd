extends GutTest
## crossing "Crossing HUD and telegraphs" with exactly 1 player, offline: the strip shows the vessel
## at the elapsed share and its integrity out of the route's, the squall's two lines come 30 s and
## 10 s before its hit, a fin's line names its side, a leak's line shows as it opens, the HUD sits
## clear of the sign note's place, and only the crossing's riders see it.

const K := CrossingBeat.Kind


func _hud(crossing: Crossing) -> CrossingHud:
	return crossing.get_node_or_null("Hud") as CrossingHud


func test_solo_reads_the_strip() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, [CrossingRig.beat(5.0, K.SQUALL)])
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 30.0 - crossing.elapsed_s)
	var hud := _hud(crossing)
	assert_not_null(hud, "the crossing has its HUD")
	hud.local_peer = 1
	assert_almost_eq(hud.progress(), 0.5, 0.01, "the raft halfway")
	assert_eq(hud.integrity_text("es"), "Balsa 70/100")
	assert_eq(hud.integrity_text("en"), "Raft 70/100")


func test_the_squall_counts_down() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(70.0, K.SQUALL)])
	var hud := _hud(crossing)
	hud.local_peer = 1
	CrossingRig.run(crossing, 39.9)
	assert_eq(hud.current_line(), "")
	CrossingRig.run(crossing, 0.2)
	assert_eq(hud.current_line(), "La raya negra viene pa'cá.")
	CrossingRig.run(crossing, 20.0)
	assert_eq(hud.current_line(), "¡Amárrate, que ahí viene!")
	CrossingRig.run(crossing, 4.0)
	assert_eq(hud.current_line(), "", "each line stays up 3 s")


func test_a_fin_and_a_leak_are_called_out() -> void:
	var beats: Array[RefCounted] = [CrossingBeat.create(30.0, K.SHARK_PASS, 0, CrossingBeat.Side.WEST), CrossingBeat.create(40.0, K.DEBRIS, 0)]
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0, beats)
	var hud := _hud(crossing)
	hud.local_peer = 1
	CrossingRig.run(crossing, 25.1)
	await wait_process_frames(2)
	assert_eq(hud.current_line(), "¡Aleta! Por la izquierda.")
	CrossingRig.run(crossing, 40.1 - crossing.elapsed_s)
	await wait_process_frames(2)
	assert_eq(hud.current_line(), "¡Un hueco! Tápalo.")


func test_the_hud_sits_clear_of_the_sign_note() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var hud := _hud(crossing)
	var sign_note := Rect2(200.0, 22.0, 240.0, 38.0)
	assert_false(CrossingHud.STRIP_RECT.intersects(sign_note), "the strip")
	assert_false(CrossingHud.LINE_RECT.intersects(sign_note), "the line")
	assert_false(CrossingHud.STRIP_RECT.intersects(Rect2(140.0, 46.0, 360.0, 20.0)), "and the cay note label")
	assert_eq(hud.layer, CrossingHud.LAYER)


func test_only_the_crossings_riders_see_it() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 60.0)
	var hud := _hud(crossing)
	hud.local_peer = 1
	await wait_process_frames(2)
	assert_true((hud.get_node("Strip") as Control).visible, "the rider sees it")
	hud.local_peer = 7
	await wait_process_frames(2)
	assert_false((hud.get_node("Strip") as Control).visible, "someone still on the island does not")


func test_a_swimmer_reads_a_nado() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0)
	var hud := _hud(crossing)
	hud.local_peer = 1
	assert_eq(hud.integrity_text("es"), "A nado")
