extends GutTest
## coop-networking "Quick chat" and its rate limit, in a solo session (the host's own player
## goes through the same request path as a client's), with a test clock.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const SHARK: int = 3

var now_s: float = 0.0


func before_each() -> void:
	now_s = 0.0


func _solo() -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.clock = func() -> float: return now_s
	session.start()
	session.body(1).player_input.enabled = false
	return session


func _bubble(session: CoopSession, peer_id: int) -> SpeechBubble:
	return session.body(peer_id).get_node_or_null(^"SpeechBubble") as SpeechBubble


func test_picking_a_phrase_shows_a_bubble_over_the_speaker() -> void:
	var session := _solo()
	watch_signals(session)
	session.say(SHARK)
	var bubble := _bubble(session, 1)
	assert_not_null(bubble)
	if bubble == null:
		return
	assert_eq(bubble.label.text, "¡Tiburón!")
	assert_signal_emitted_with_parameters(session, "quick_chat_shown", [1, SHARK])


func test_the_voice_clip_is_looked_up_by_line_id_and_none_exists_yet() -> void:
	var session := _solo()
	session.say(SHARK)
	var bubble := _bubble(session, 1)
	assert_not_null(bubble)
	if bubble == null:
		return
	assert_eq(session.phrases.voice_path(SHARK), "res://assets/audio/voice/quick_chat_tiburon.ogg")
	assert_null(bubble.voice, "no clip until Milestone G")


func test_a_bubble_with_a_clip_plays_it() -> void:
	var session := _solo()
	var clip := AudioStreamWAV.new()
	var bubble := session.show_bubble(session.body(1), "¡Tiburón!", clip)
	assert_eq(bubble.voice_player.stream, clip)


func test_a_bubble_lasts_2_5_s() -> void:
	var session := _solo()
	session.say(SHARK)
	var bubble := _bubble(session, 1)
	assert_eq(SpeechBubble.SHOW_S, 2.5)
	bubble._process(2.4)
	assert_false(bubble.is_queued_for_deletion())
	bubble._process(0.2)
	assert_true(bubble.is_queued_for_deletion())


func test_a_new_phrase_replaces_the_old_bubble() -> void:
	var session := _solo()
	session.say(0)
	now_s = 0.1
	session.say(SHARK)
	var bubbles: int = 0
	for child: Node in session.body(1).get_children():
		if child is SpeechBubble and not child.is_queued_for_deletion():
			bubbles += 1
	assert_eq(bubbles, 1)
	assert_eq(_bubble(session, 1).label.text, "¡Tiburón!")


func test_quick_chat_spam() -> void:
	var session := _solo()
	watch_signals(session)
	for i: int in 5:
		session.say(i)
	assert_signal_emit_count(session, "quick_chat_shown", 3, "a burst of 3")
	now_s = 1.9
	session.say(5)
	assert_signal_emit_count(session, "quick_chat_shown", 3, "nothing back before 2 s")
	now_s = 2.0
	session.say(5)
	assert_signal_emit_count(session, "quick_chat_shown", 4, "the next phrase 2 s later")


func test_slots_outside_the_wheel_are_ignored() -> void:
	var session := _solo()
	watch_signals(session)
	session.say(-1)
	session.say(QuickChatPhrases.SLOTS)
	assert_signal_not_emitted(session, "quick_chat_shown")
	assert_null(_bubble(session, 1))


func test_rewording_a_phrase() -> void:
	var line := DialogueLineData.new()
	line.id = &"quick_chat_dale"
	line.text_es = "¡Dale, asere!"
	var state := DialogueStateData.new()
	state.state = QuickChatPhrases.STATE
	state.lines = [line] as Array[DialogueLineData]
	var data := DialogueData.new()
	data.kind = DialogueData.Kind.QUICK_CHAT
	data.states = [state] as Array[DialogueStateData]
	var session := _solo()
	session.phrases = QuickChatPhrases.from_dialogue(data)
	session.say(0)
	assert_eq(_bubble(session, 1).label.text, "¡Dale, asere!")
	var wheel := (load("res://scenes/ui/quick_chat_wheel.tscn") as PackedScene).instantiate() as QuickChatWheel
	wheel.phrases = session.phrases
	add_child_autofree(wheel)
	assert_eq(wheel.slot_label(0).text, "¡Dale, asere!")


func test_the_session_reads_the_phrase_file_by_default() -> void:
	var session := _solo()
	assert_eq(session.phrases.size(), QuickChatPhrases.SLOTS)
	assert_eq(session.phrases.text(SHARK), "¡Tiburón!")
