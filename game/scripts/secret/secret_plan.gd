class_name SecretPlan
extends RefCounted
## secret-cay "Existence roll": the host's one roll per run, from the run seed, of whether the run
## holds the secret, and on which two run indices the map and the compass lie. Its own generator,
## seeded from the run seed and the tuning's salt, so shipping it never shifts any other roll made
## from the same seed (SPD's pushed generator, DCSS's subgenerator). Pure: a 1-player run rolls the
## same way. Nothing in a real run calls it until island-generation owns the run seed.


## {held: bool, pieces: {map_item_id: index, compass_item_id: index}} for `run_seed`; `pieces` is
## empty when the run holds no secret. The map's index is drawn first, then the compass's from the
## indices left.
static func roll(run_seed: int, tuning: SecretTuning) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, tuning.roll_salt])
	var plan: Dictionary = {"held": false, "pieces": {}}
	if rng.randf() >= tuning.run_chance:
		return plan
	var indices: Array[int] = []
	for index: int in range(tuning.index_min, tuning.index_max + 1):
		indices.append(index)
	if indices.size() < 2:
		return plan
	var map_index: int = indices.pop_at(rng.randi_range(0, indices.size() - 1))
	var compass_index: int = indices[rng.randi_range(0, indices.size() - 1)]
	plan["held"] = true
	plan["pieces"] = {tuning.map_item_id: map_index, tuning.compass_item_id: compass_index}
	return plan
