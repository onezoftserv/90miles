# Design

## Context

`project-skeleton` gives a 640×360 Godot 4.7 project with static typing enforced, five autoload stubs, typed content data (`DataEnums.Terrain` already names DEEP, SHALLOWS, BRACKISH, BEACH, DUNE, MANGROVE, ROCK, SCRUB...) and a headless test gate. No island, meters or networking exist yet; this change must not wait for them. See proposal.md for the provisional decisions.

## Goals / Non-Goals

**Goals:** every number in the player-movement spec is enforced by a GUT test; the player body is driven by intents; the rules are testable without a running scene tree.

**Non-Goals:** networking (intents only), the other five meters, real island art or generation, guardacostas detection (only the stealth state it will read), item pick-up effects (interactables only report that they were used).

## Decisions

### Rules live in a pure model, the body only applies them
`MovementModel` (`RefCounted`, `scripts/player/movement_model.gd`) takes the current terrain, energy, an intent and a time step and returns the velocity in tiles/s, the energy spent and the resulting movement and stealth states. `PlayerBody` (`CharacterBody2D`, `scenes/player/player.gd`) converts tiles to pixels (16 px per tile), calls `move_and_slide()` and spends energy. All spec scenarios are tested against the model with exact numbers, and the body gets a few integration tests stepping `_physics_process` by hand. Alternative: rules inside the body's `_physics_process`; rejected because physics stepping makes exact-number tests fragile.

### Intents, not input polling
`MoveIntent` (`RefCounted`: `direction: Vector2` with length ≤ 1, `run`, `crouch`, `interact_held` booleans) is built by `PlayerInput` from the named input actions for the local player, or set directly by tests and, later, by `coop-networking`. The body never reads `Input`. This keeps both co-op sync models open (review item 15).

### Terrain behind one small interface
`TerrainQuery` (`RefCounted` base: `terrain_at(cell: Vector2i) -> DataEnums.Terrain`, `current_at(cell: Vector2i) -> Vector2` in tiles/s) is what the body asks. `GridTerrain` implements it from a `Dictionary[Vector2i, DataEnums.Terrain]` for tests and the playground; `island-generation` will add a `TileMapLayer`-backed implementation. Water is DEEP, SHALLOWS or BRACKISH; brush is SCRUB or MANGROVE; everything else is land. Default current: 1 tile/s east.

### Energy now, the rest of the meters later
`SurvivalMeters` (`Node`, `scripts/components/survival_meters.gd`) is created with only `energy` (0–100, `spend_energy`, `energy_changed` signal) so `survival-meters` extends the same component instead of replacing a stand-in.

### States
Movement: WALK, RUN, CROUCH, CRAWL, SWIM, FLOAT, DIVE, DRAGGED. Stealth: VISIBLE, HIDDEN (crouching on brush or mangrove), SUBMERGED (diving, up to 5 s, costs 10 energy once per dive). Swimming at 0 energy is FLOAT: speed 0 plus the current. Crawling is 1 tile/s on land at 0 energy, with run ignored. Being dragged moves a downed player toward the dragger at 2 tiles/s.

### Interaction
`Interactable` (`Node2D` component, `scripts/interaction/interactable.gd`): `hold_time_s` (default 2.0; 0 means instant), an `interacted(by: Node)` signal and an `enabled` flag. `InteractionPicker` (pure) picks the nearest enabled interactable within 1 tile (16 px). `InteractionHold` tracks hold progress per player and resets on release. Dragging a downed teammate is a `DragHandle` interactable on each player, enabled only while that player is downed (the downed flag is a plain property until `survival-meters` owns it).

### Camera and art
Each `PlayerBody` has a `Camera2D` that is enabled only when the body belongs to the local peer (`is_multiplayer_authority()`; always true offline). The placeholder sprite is one 16×16 character frame from Kenney "Tiny Dungeon" (CC0), copied into a tracked folder with its license, because `game/assets/kenney/` is git-ignored and the smoke run rejects scenes that depend on it.

## Risks / Trade-offs

- [Provisional numbers (crawl 1 tile/s, default current 1 tile/s east) may change] → both are single constants, and each has a test naming it.
- [The energy-only `SurvivalMeters` may not fit `survival-meters`' design] → it only adds `energy`; the spec for that change can reshape it.
- [Physics collisions with island walls are not specified yet] → the body uses `move_and_slide()`; collision layers arrive with the island.
- [Gamepad defaults are guesses] → they are input-map entries, editable without code.

## Open Questions

None that change this design; the provisional decisions are listed in proposal.md for the user to confirm.
