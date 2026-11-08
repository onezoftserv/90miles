extends GutTest
## crossing "Vessel integrity", as pure logic.

var broke_count: int = 0


func before_each() -> void:
	broke_count = 0


func test_raft_starts_at_100_and_takes_squall_and_shark() -> void:
	var integrity := VesselIntegrity.create(100.0)
	assert_eq(integrity.value, 100.0)
	integrity.hit(30.0)
	assert_eq(integrity.value, 70.0)
	integrity.hit(20.0)
	assert_eq(integrity.value, 50.0)
	assert_false(integrity.broken)


func test_squall_rock_squall_breaks_raft() -> void:
	var integrity := VesselIntegrity.create(100.0)
	integrity.broke.connect(func() -> void: broke_count += 1)
	integrity.hit(30.0)
	integrity.hit(40.0)
	assert_true(integrity.hit(30.0), "the third hit breaks it")
	assert_eq(integrity.value, 0.0)
	assert_true(integrity.broken)
	integrity.hit(20.0)
	assert_eq(integrity.value, 0.0)
	assert_eq(broke_count, 1)


func test_swimmers_have_no_integrity() -> void:
	var integrity := VesselIntegrity.create(0.0)
	assert_false(integrity.has_integrity())
	assert_false(integrity.hit(20.0))
	assert_eq(integrity.value, 0.0)
	assert_false(integrity.broken)
