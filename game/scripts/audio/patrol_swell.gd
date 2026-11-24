class_name PatrolSwell
extends RefCounted
## sound-pass audio "The patrol motor swells over the horizon warning" and "…follows the boat in
## sight" (design D5; Fable review H5; DST's hound growls that grow before a wave): the level (0 to 1,
## on top of the motor's bank level) one patrol boat asks of the patrol_motor loop.
## - HORIZON: from motor_low_db at the warning's start to motor_high_db at its end, steady in dB.
##   The warning's length is the boat's own data, never a literal.
## - In sight (LAP, ALERT_LOCK, ALERT_SEARCH, CHASE): motor_high_db within motor_near_tiles of the
##   view, falling steadily in dB to motor_far_db at motor_far_tiles, then fading to silence at
##   twice that.
## - AWAY and DOCKED: silent.


static func level(state: int, clock_s: float, warning_s: float, distance_tiles: float, bank: SoundBank) -> float:
	match state:
		PatrolRoute.State.HORIZON:
			if warning_s <= 0.0:
				return 0.0
			var progress: float = clampf(clock_s / warning_s, 0.0, 1.0)
			return db_to_linear(lerpf(bank.motor_low_db, bank.motor_high_db, progress))
		PatrolRoute.State.LAP, PatrolRoute.State.ALERT_LOCK, PatrolRoute.State.ALERT_SEARCH, PatrolRoute.State.CHASE:
			return in_sight(distance_tiles, bank)
	return 0.0


## The level of a boat in sight `distance_tiles` from the view.
static func in_sight(distance_tiles: float, bank: SoundBank) -> float:
	var near: float = bank.motor_near_tiles
	var far: float = maxf(bank.motor_far_tiles, near + 0.001)
	if distance_tiles <= near:
		return db_to_linear(bank.motor_high_db)
	if distance_tiles <= far:
		return db_to_linear(lerpf(bank.motor_high_db, bank.motor_far_db, (distance_tiles - near) / (far - near)))
	if distance_tiles <= far * 2.0:
		return db_to_linear(bank.motor_far_db) * (1.0 - (distance_tiles - far) / far)
	return 0.0
