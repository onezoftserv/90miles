# Design

## Shape

A route is data (`RouteData`): starter, requirements, rider requirements, capacity, discovery conditions. Code only interprets it.

- `RouteLauncher` (pure, static): `can_start(route, starter)` and `riders(route, sender, candidates, anchor)`. Candidates must be alive, standing and within `board_radius_tiles` of the anchor. `ALL` takes them, `PER_SWIMMER` filters by `rider_requirements`, `FIXED` takes the sender and the nearest. The sender always comes first; a sender who cannot ride gives `[]`.
- `IslandRoutes` (a node named `Routes` in the session on every peer, group `island_routes`): `offered`, `discovered`, `departed`. `start_for(peer, route_id)` runs on the host only: discovery check, route offered and discovered, sender on the island, anchor found (for a build-site route the built structure within reach of the sender; for an item route the sender), requirements, riders. It then marks the riders departed, emits `route_started` and sends `receive_departure` (authority, reliable, sender must be 1) to the clients, which do the same locally.
- `CrossingStub.depart(body)` is the hand-off seam: `left_island = true`, hidden, collision off. The crossing change replaces this file and `GameShell._on_route_started`.
- `CoopSession.start_route(route_id)` sends `request_start_route` to the host (`any_peer`, `call_local`, reliable); the handler runs on the server for `_sender()` and calls `start_route_for`, which needs `_acting_body` (alive, standing, rate-limited, not departed). The request names only the route.
- The raft site is a `BuildSite` named `RaftSite` at the layout's `B` cell, created by `SandbarIsland.furnish` on every peer. Level-placed sites set `synced`; the host then pushes `receive_state(deposits, progress, built)` to the clients after each deposit, every 1/120 of progress and on completion. The client clamps what it receives to the recipe's inputs and, when told it is built, completes locally, so the `Raft` structure (name `Raft`, set by `structure_name`) exists on every peer at the same path. A launched raft is freed and a fresh `RaftSite` replaces it on every peer from the same `route_started` signal.
- `Raft` (structure) holds `recipe_id`, joins the `built_structures` group with a `recipe_id` meta, and on `interacted` asks the routes to start the route named by its recipe id (host only).
- Conditions: `METER_AT_LEAST` reads `meters.value`, `STATUS_ACTIVE` reads `meters.has_status`, `WEATHER_IS_CLEAR` reads `WeatherData.is_clear` of the actor's climate, `STRUCTURE_BUILT` looks for a structure with that `recipe_id`. Party-scoped conditions read the starter, as `ConditionCheck` already does.
- Binoculars: an `ItemUseData` ACTIVATE (`spends_use = false`) with a `START_ROUTE` effect; `EffectApplier` finds the routes node and calls `start_for` for the user's peer. The use goes through the host's `use_for`, so it is host-authoritative already.
- The shell ends the run when every player is dead or has left, at least one having left or all dead; entries carry the route's Spanish name and the summary prints "(se fue en: Balsa)".

## Solo

One player is the host and the sender, the only rider and the only swimmer. The raft needs one player to deposit, work and launch; the run then ends. Nothing needs a second peer.

## Reference games (ideas only; nothing copied or translated)

- **Brogue CE, `Architect.c` `buildAMachine` with `BP_ADOPT_ITEM` / `BP_REWARD`:** borrowed the idea that a machine is a placed feature whose payoff opens when a condition holds, and its key can be an item adopted from elsewhere. Our route is a starter (raft site or binoculars) plus a requirement list checked at use. Rejected: generation-time machine placement and item adoption; the sandbar is handmade, and procedural placement belongs to `island-generation`.
- **DCSS, `branch.h` `struct Branch` and `dat/des/portals/bailey.des` (`timed_marker`, `timed_msg`):** borrowed that exits are data rows with their own entry feature and destination profile (our `RouteData` crossing fields) and that handmade portal vaults are data. Rejected for now: timed portals (the signal boat's one-hour window is a later route).
- **Shattered Pixel Dungeon, `LevelTransition`, `Level.activateTransition` (returns false to veto) and `Hero.actTransition`:** borrowed that the exit is a cell-bound object and that using it goes through one gate that can refuse, with nothing changed on refusal (`IslandRoutes.start_for` returns false). The "keep acting while adjacent" shape matches `Crafter._advance_site`. Rejected: its single-hero transition; we pick a rider set by capacity and leave the others on the island.

## Decisions and risks

See `proposal.md` for the owner's two decisions, the provisional numbers and what was adapted from the plan.

- **Rope.** With the hut's 2 extra rope a solo player can gather 6 driftwood, 2 tubes and 3 rope on day 1 (the sandbar holds 8 driftwood and 2 tubes). Spending 6 driftwood on the raft leaves 2 for fires until a squall refreshes the beach driftwood.
- **Risk: departed bodies.** They stay in the tree, hidden, so teammates' lists and the camera keep working; they no longer move, tick meters or act. A departed player is not counted as "on the island" for riders, discovery or `_acting_body`.
- **Risk: sync of site state.** Deposits are clamped to the recipe on the client; a forged `receive_state` from a client is dropped by the sender check.
