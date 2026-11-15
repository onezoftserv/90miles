class_name PeerLimits
extends RefCounted
## One peer's rate limits on the host (coop-networking "Per-peer rate limits"). The numbers are
## the coop-networking proposal's decision 6, with headroom for host hitches from intent-delivery
## (owner decision Q3, 2026-11-14).

## Intents per second, with a burst for frames that arrive together: a second and a half of
## frames, so the count never refuses a backlog the simulated-time slack allows.
const INTENT_BURST: float = 90.0
const INTENTS_PER_S: float = 90.0
## Simulated movement time per second of real time, with slack for jitter and for a host
## hitch. The host's clock runs through a hitch, so the bucket is back at its slack when the
## client's backlog arrives: a 1 s host frame fits and leaves 0.25 s for jitter. The refill is
## the honest rate, so a cheat gains one 1.25 s burst at most, never lasting speed.
const SIM_TIME_SLACK_S: float = 1.25
const SIM_TIME_PER_S: float = 1.0
## Every intent costs at least one physics frame, so tiny claimed steps cannot buy extra
## interaction presses (an honest client's step is exactly one frame).
const MIN_INTENT_COST_S: float = 1.0 / 60.0
## Quick-chat phrases: a burst of 3, then one every 2 s.
const QUICK_CHAT_BURST: float = 3.0
const QUICK_CHAT_PER_S: float = 0.5

## Item uses, crafts and deposits (CraftingTuning, crafting-inventory).
var actions: RateLimiter = RateLimiter.new(
	preload("res://resources/crafting_tuning.tres").action_burst,
	preload("res://resources/crafting_tuning.tres").actions_per_s)
var intents: RateLimiter = RateLimiter.new(INTENT_BURST, INTENTS_PER_S)
var sim_time: RateLimiter = RateLimiter.new(SIM_TIME_SLACK_S, SIM_TIME_PER_S)
var quick_chat: RateLimiter = RateLimiter.new(QUICK_CHAT_BURST, QUICK_CHAT_PER_S)


## Whether an intent claiming `delta` seconds may be applied at `now_s`.
func allow_intent(delta: float, now_s: float) -> bool:
	return intents.try_take(1.0, now_s) and sim_time.try_take(maxf(delta, MIN_INTENT_COST_S), now_s)


func allow_quick_chat(now_s: float) -> bool:
	return quick_chat.try_take(1.0, now_s)


func allow_action(now_s: float) -> bool:
	return actions.try_take(1.0, now_s)
