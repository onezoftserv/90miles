class_name RateLimiter
extends RefCounted
## A token bucket (coop-networking "Per-peer rate limits"): holds up to `capacity` tokens,
## starts full and refills at `refill_per_s`. The caller passes the time, so tests and the
## host's clock drive it the same way.

## Tolerance for float crumbs when a request equals what is left (0.1 + 0.1 + 0.05...).
const EPSILON: float = 0.000000001

var capacity: float
var refill_per_s: float
var _tokens: float
var _last_s: float = -INF


func _init(bucket_capacity: float, refill_rate_per_s: float) -> void:
	capacity = maxf(bucket_capacity, 0.0)
	refill_per_s = maxf(refill_rate_per_s, 0.0)
	_tokens = capacity


## Takes `amount` tokens at time `now_s` if that many are available. Refuses (and takes
## nothing) for amounts that are not finite and positive.
func try_take(amount: float, now_s: float) -> bool:
	if not is_finite(amount) or amount <= 0.0:
		return false
	_refill(now_s)
	if amount > _tokens + EPSILON:
		return false
	_tokens = maxf(_tokens - amount, 0.0)
	return true


## Tokens available at `now_s`.
func available(now_s: float) -> float:
	_refill(now_s)
	return _tokens


# A clock that goes backwards adds nothing and does not move the reference time back.
func _refill(now_s: float) -> void:
	if not is_finite(now_s):
		return
	if _last_s == -INF:
		_last_s = now_s
		return
	if now_s > _last_s:
		_tokens = minf(capacity, _tokens + (now_s - _last_s) * refill_per_s)
		_last_s = now_s
