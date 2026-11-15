extends GutTest
## coop-networking "Host authority": the client's buffer of intents the host has not processed.

const DT: float = 1.0 / 60.0

var buffer: PredictionBuffer


func before_each() -> void:
	buffer = PredictionBuffer.new()


func test_intents_are_numbered_from_1() -> void:
	assert_eq(buffer.push(MoveIntent.create(Vector2.RIGHT), DT), 1)
	assert_eq(buffer.push(MoveIntent.create(Vector2.LEFT), DT), 2)
	assert_eq(buffer.size(), 2)
	assert_eq(buffer.last_seq, 2)


func test_pending_keeps_order_seq_and_delta() -> void:
	buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	buffer.push(MoveIntent.create(Vector2.UP, true), 0.02)
	var pending := buffer.pending()
	assert_eq(pending.size(), 2)
	assert_eq(pending[0].seq, 1)
	assert_eq(pending[0].intent.direction, Vector2.RIGHT)
	assert_eq(pending[1].seq, 2)
	assert_eq(pending[1].intent.direction, Vector2.UP)
	assert_true(pending[1].intent.run)
	assert_eq(pending[1].delta, 0.02)


func test_acknowledge_drops_everything_up_to_the_seq() -> void:
	for i: int in 5:
		buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	buffer.acknowledge(3)
	var seqs: Array[int] = []
	for entry: PendingIntent in buffer.pending():
		seqs.append(entry.seq)
	assert_eq(seqs, [4, 5] as Array[int])
	assert_eq(buffer.acked_seq, 3)


# intent-delivery "Intent delivery": each message carries the newest unacknowledged intents.
func test_newest_returns_the_newest_unacknowledged_intents_oldest_first() -> void:
	for i: int in 10:
		buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	assert_eq(_seqs(buffer.newest(4)), [7, 8, 9, 10] as Array[int])
	assert_eq(_seqs(buffer.newest(20)), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as Array[int], "never more than are pending")
	buffer.acknowledge(9)
	assert_eq(_seqs(buffer.newest(8)), [10] as Array[int])
	buffer.acknowledge(10)
	assert_eq(buffer.newest(8).size(), 0, "none once all are acknowledged")


func test_newest_hands_out_the_stored_copies() -> void:
	var intent := MoveIntent.create(Vector2.RIGHT, true)
	buffer.push(intent, 0.02)
	intent.direction = Vector2.LEFT
	var newest := buffer.newest(1)
	assert_eq(newest[0].intent.direction, Vector2.RIGHT)
	assert_true(newest[0].intent.run)
	assert_eq(newest[0].delta, 0.02)


func test_an_older_acknowledgement_changes_nothing() -> void:
	for i: int in 5:
		buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	buffer.acknowledge(4)
	buffer.acknowledge(2)
	assert_eq(buffer.size(), 1)
	assert_eq(buffer.acked_seq, 4)


func test_acknowledging_past_the_last_seq_empties_the_buffer() -> void:
	buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	buffer.acknowledge(99)
	assert_eq(buffer.size(), 0)
	assert_eq(buffer.push(MoveIntent.create(Vector2.RIGHT), DT), 2, "numbering continues")


func test_stored_intents_are_copies() -> void:
	var intent := MoveIntent.create(Vector2.RIGHT, true, false, true)
	buffer.push(intent, DT)
	intent.direction = Vector2.LEFT
	intent.run = false
	var stored: MoveIntent = buffer.pending()[0].intent
	assert_eq(stored.direction, Vector2.RIGHT)
	assert_true(stored.run)
	assert_true(stored.interact_held)


func test_move_intent_copy_is_equal_and_independent() -> void:
	var intent := MoveIntent.create(Vector2(0.6, 0.8), true, true, true)
	var copy := intent.copy()
	assert_eq(copy.direction, intent.direction)
	assert_eq([copy.run, copy.crouch, copy.interact_held], [true, true, true])
	copy.crouch = false
	assert_true(intent.crouch)


func test_the_buffer_keeps_at_most_max_pending_intents() -> void:
	for i: int in PredictionBuffer.MAX_PENDING + 10:
		buffer.push(MoveIntent.create(Vector2.RIGHT), DT)
	assert_eq(buffer.size(), PredictionBuffer.MAX_PENDING)
	assert_eq(buffer.pending()[0].seq, 11, "the oldest are dropped")


func _seqs(intents: Array[PendingIntent]) -> Array[int]:
	var seqs: Array[int] = []
	for entry: PendingIntent in intents:
		seqs.append(entry.seq)
	return seqs
