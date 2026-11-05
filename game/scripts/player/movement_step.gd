class_name MovementStep
extends RefCounted
## The result of one MovementModel step.

enum Move { WALK, RUN, CROUCH, CRAWL, SWIM, FLOAT, DIVE, DRAGGED }
enum Stealth { VISIBLE, HIDDEN, SUBMERGED }

## Velocity in tiles/s.
var velocity: Vector2 = Vector2.ZERO
var energy_spent: float = 0.0
var movement: Move = Move.WALK
var stealth: Stealth = Stealth.VISIBLE
