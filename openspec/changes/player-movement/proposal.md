# Proposal

## Why

Milestone A starts with a player who can walk, run, crouch, swim, dive and interact on a handmade island (`TASKS.md` §3). Every later capability (meters, crafting, stealth, crossings, co-op) acts through this body, so its rules and numbers need to be code and tests before anything builds on them.

## What Changes

- A player character for 1–4 players: walk 4, run 6, crouch 2 tiles/s on land; swim 3 tiles/s in shallow and deep water; float and drift with the current at 0 energy; dive (hold crouch in water) to be hidden from searchlights for 5 s at a cost of 10 energy; crawl on land at 0 energy.
- Energy costs from `player-movement` and `survival-meters`: running 0.5/s, swimming 3/s. A minimal per-player energy meter is added now inside `SurvivalMeters`; the other five meters arrive with `survival-meters`.
- Stealth states the guardacostas will read later: hidden while crouching on brush or mangrove, submerged while diving.
- Interaction with the nearest interactable within 1 tile, instant or held (default 2 s, per interactable), and dragging a downed teammate at 2 tiles/s.
- Each client's camera follows its own player at 640×360 (integer scaling and nearest filtering are already set by `project-skeleton`).
- Movement is driven by an input intent (direction, run, crouch, interact) rather than by reading the keyboard in the body, so `coop-networking` can carry intents from clients to the host.
- Named input actions with keyboard and gamepad defaults.
- A movement playground scene with land, brush, shallow and deep water for manual runs, built without downloaded art.

**Provisional decisions to confirm** (they come from open items in `docs/reviews/2026-11-05-repo-review.md`; each is easy to change later):
1. Crawl speed at 0 energy on land is 1 tile/s. No doc gives a number (survival-meters only says "can only crawl").
2. Hold time is a property of each interactable, default 2 s, rather than one global 2 s (review item 20).
3. The co-op sync model stays open (review item 15). Intents make both options possible: host authority with client prediction, or client-owned movement with host checks. `coop-networking` decides.
4. Characters use a 16×16 CC0 Kenney sprite as a placeholder, committed to the repo so CI has it (review items 21 and 22); the final character size is still open.
5. Drift: the water current comes from the island's terrain source and defaults to 1 tile/s east (trade wind), matching the spec scenario's "1 tile/s in the current direction".
6. Treading water (swim state, no direction) costs no energy and ignores the current; only moving drains 3/s.
7. Dragging a downed teammate is instant on press and lasts while interact is held, not a 2 s hold. A dive needs more than 10 energy so it never ends the frame after it is paid for.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `player-movement`: "Walk, run, crouch" gains the crawl rule at 0 energy; "Interaction" makes hold time per interactable with a 2 s default; two requirements are added: movement is driven by intents, and named input actions with keyboard and gamepad defaults.

## Impact

- New: `game/scripts/player/` (movement model, player body, input, interaction), `game/scenes/player/player.tscn`, `game/scenes/dev/movement_playground.tscn`, a terrain query interface, `SurvivalMeters` with energy only, one committed placeholder sprite with its license.
- `game/project.godot`: input actions.
- Tests: GUT for every spec scenario, run headless.
- No change to the five core services.
