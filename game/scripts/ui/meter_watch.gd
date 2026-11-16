class_name MeterWatch
extends RefCounted
## Sorts one meter's changes on one body (survival-meters "Hits and drains are told apart", "Jumps
## and cures are told apart"; damage-feedback design D3). A cue feeds it the value it already holds
## once per drawn frame: the host its own simulation, a client what StateSync last set. Nothing is
## sent for it. A loss at least `margin` more than the body's recent steady loss would give in the
## same time is a HIT; any other loss is a DRAIN. A rise at least `margin` above the recent steady
## rise is a JUMP; a slower one is nothing. The first value, a value after `reset()` and every value
## while dead only set where it starts.
## Feedback only: it reads, never writes, and draws no random numbers.

enum Change { NONE, HIT, DRAIN, JUMP }

## How far past the steady change a change at once must go.
var margin: float = 3.0
## Seconds without a change in one direction before its steady rate is forgotten.
var forget_s: float = 1.0
## The signed size of the latest HIT (negative) or JUMP (positive), past the steady change.
var last_change: float = 0.0

var _has_base: bool = false
var _last: float = 0.0
var _losses: _Trend = _Trend.new()
var _gains: _Trend = _Trend.new()


func _init(change_margin: float = 3.0, steady_forget_s: float = 1.0) -> void:
	margin = change_margin
	forget_s = steady_forget_s


## Forgets the body: the next value only sets where it starts (a rebind, a spectate switch).
func reset() -> void:
	_has_base = false
	_losses = _Trend.new()
	_gains = _Trend.new()


## One drawn frame: `value` now, whether the body is dead, and the frame's seconds.
func observe(value: float, dead: bool, delta: float) -> Change:
	var step: float = maxf(delta, 0.0)
	_losses.since_s += step
	_gains.since_s += step
	if dead or not _has_base:
		_has_base = true
		_last = value
		return Change.NONE
	var moved: float = value - _last
	_last = value
	if is_zero_approx(moved):
		return Change.NONE
	if moved < 0.0:
		var hit: float = _losses.sudden(-moved, margin, forget_s)
		if hit > 0.0:
			last_change = -hit
			return Change.HIT
		return Change.DRAIN
	var jump: float = _gains.sudden(moved, margin, forget_s)
	if jump > 0.0:
		last_change = jump
		return Change.JUMP
	return Change.NONE


# The steady change in one direction: its rate per second and the time since its last step.
class _Trend:
	extends RefCounted

	const MIN_STEP_S: float = 0.001

	var rate: float = 0.0
	var since_s: float = 0.0

	# How far `amount` (positive) goes past what the steady rate gives since the last step, when that
	# is at least `margin`; otherwise 0, and `amount` becomes the steady rate. Either way it is a step.
	func sudden(amount: float, margin: float, forget_s: float) -> float:
		var steady: float = rate if since_s <= forget_s else 0.0
		var excess: float = amount - steady * since_s
		var interval: float = since_s
		since_s = 0.0
		if excess >= margin:
			return excess
		rate = amount / maxf(interval, MIN_STEP_S)
		return 0.0
