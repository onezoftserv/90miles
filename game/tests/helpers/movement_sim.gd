class_name MovementSim
extends RefCounted
## Test helper: runs a MovementModel for some seconds and reports the totals.

const DT: float = 1.0 / 60.0


## Steps `model` for `seconds` at a fixed time step. Returns {"tiles": Vector2 moved,
## "energy": float left, "last": MovementStep of the final step}.
static func run(model: MovementModel, terrain: DataEnums.Terrain, energy: float, intent: MoveIntent, seconds: float, current: Vector2 = TerrainQuery.DEFAULT_CURRENT) -> Dictionary:
	var tiles := Vector2.ZERO
	var left: float = energy
	var last: MovementStep = null
	var steps: int = roundi(seconds / DT)
	for i: int in steps:
		last = model.step(terrain, current, left, intent, DT)
		tiles += last.velocity * DT
		left -= last.energy_spent
	return {"tiles": tiles, "energy": left, "last": last}
