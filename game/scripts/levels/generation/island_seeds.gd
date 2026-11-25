class_name IslandSeeds
extends RefCounted
## island-generator design §4 step 1: one seed per (run seed, island index, chain, attempt, stage),
## taken from SHA-256 so it is the same on every platform and engine version (never the engine's own hashing).
## Each stage draws from its own generator, so a POI roll never moves the land.

## The integer of the first 15 hex digits of the SHA-256 of "run|index|chain|attempt|stage":
## at least 0 and below 2^60.
static func seed_for(run_seed: int, index: int, chain_id: StringName, attempt: int, stage: StringName) -> int:
	var text: String = "%d|%d|%s|%d|%s" % [run_seed, index, chain_id, attempt, stage]
	return text.sha256_text().substr(0, 15).hex_to_int()


## A generator seeded for that stage.
static func rng_for(run_seed: int, index: int, chain_id: StringName, attempt: int, stage: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(run_seed, index, chain_id, attempt, stage)
	return rng


## An integer chance test: true with probability `chance` (0..1), one draw.
static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randi_range(0, 9999) < roundi(chance * 10000.0)
