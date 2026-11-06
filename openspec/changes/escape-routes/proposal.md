# Proposal

## Why

Milestone B "Leave the island" needs a way off the sandbar. `RouteData` exists as a data class and the catalog already has a `routes` folder, but no route, no raft and no binoculars exist, and nothing can start one.

## What Changes

- Two routes as data: `game/resources/routes/raft.tres` and `binoculars_swim.tres`; the raft recipe (`recipes/raft.tres`) and the binoculars item (`items/binoculars.tres`). A new route is a new `.tres`.
- `RouteData` gains `board_radius_tiles` and `discover_conditions` (data, so later routes need no script).
- `ConditionCheck` interprets `METER_AT_LEAST`, `STATUS_ACTIVE`, `WEATHER_IS_CLEAR` and `STRUCTURE_BUILT`; `EffectApplier` interprets `START_ROUTE`; `SurvivalMeters` holds statuses (host-only; nothing causes bleeding yet).
- `RouteLauncher` (pure rules: requirements, riders by capacity) and `IslandRoutes` (the routes an island offers, discovery, who left, the host-authoritative start and its RPC to clients).
- A raft build site on the sandbar at a marked beach cell (`B` in `sandbar.tres`), at the same path on every peer, with its state pushed from the host to clients; the finished `Raft` structure starts the route; a launched raft is replaced by a fresh site.
- `CoopSession.start_route(route_id)` and its host handler; a player who left no longer acts.
- `CrossingStub` is the hand-off seam: riders leave the island and the run ends with the summary ("se fue en: Balsa") once everyone has left or died.
- **Owner's decision, sandbar rope:** the hut gets 2 more rope (never refreshed) next to the flotsam line's 1, so a player can build the raft on day 1. Data only (`sandbar.tres`), `docs/ISLANDS.md` §1, and a MODIFIED "Sandbar contents" block.

Out of scope: the crossing scene, arrival and the next island, the other routes (repair-wreck, turtle, tarp-sail, dolphins, signal-boat, gulf-stream, almendrón, board), NPCs, patrols, a map UI, bleeding causes and bandages, the Mecánico's 2x build speed (no backgrounds exist; the recipe carries `skill` and `skill_speed_multiplier` as data only).

## Solo

One offline player builds the raft alone (they deposit everything, work it 60 s and launch it) or swims alone; the run then ends with the summary. `test_escape_routes_solo.gd` covers the raft, the swim and each refusal with exactly 1 player, discovery in a squall start, and the shell's summary; `test_route_launcher.gd` covers the 1-player rider list.

## Decided by the owner (2026-11-06)

1. **Rope on the sandbar: 3** (flotsam line keeps 1, refreshed; the hut holds 2 more, never refreshed).
2. **Binoculars: the swim route is built and tested with binoculars given in the test; none are placed on the sandbar.** The route can be discovered there but not taken yet. Follow-up: binoculars appear on islands that have them (rock cairn, captain's chest).

## Provisional decisions

Taken from the plan's recommended options; the owner has not confirmed them.

1. **Raft work 60 s** (no doc gives one; at 1 energy/s a solo builder ends at 40).
2. **Boarding radius 5 tiles** (`RouteData.board_radius_tiles`), matching the crossing's 5-tile arrival scatter.
3. **Raft launch hold 1.0 s.**
4. **Site state push** on each deposit, on completion and every 1/120 of progress (0.5 s of work).
5. **Swim crossing fields** (`shark_multiplier` 1.0, duration 60-120 s) are placeholders until the crossing change tunes them.
6. **Riders board automatically**: every eligible player within the radius goes; no opt-out prompt ("me quedo" is a follow-up).
7. **Party requirements read the starter's own inventory** (no pooled party inventory yet), as `ConditionCheck` already documents.
8. **Bleeding is a host-only status** that nothing causes or clears yet; not synced to clients.
9. **Discovery is host-only state**, no map UI. The swim is discovered the first time the weather is clear while any player is on the island.
10. **After a raft launch** a fresh empty raft site returns, so players who stay keep the raft route.
11. **`ItemUser.use` returns true even when the route refuses**; harmless because binoculars are not spent.
12. **No MODIFIED block for Routes or Weather gating**: `balsero-lore` modifies them and is not archived. This change ADDs `escape-routes` and MODIFIES only "Sandbar contents" (the owner's rope decision).

## Adapted from the plan

- The plan said the sandbar had 1 rope; the owner's decision (above) makes it 3, so the plan's "do not change sandbar counts" no longer holds.
- A departed player is marked `PlayerBody.left_island` (hidden, no collision, not simulated, meters stopped) instead of `process_mode = DISABLED`: a disabled body has no physics space and the clients' reconciliation of the host's state then logged engine errors.
- `IslandRoutes` hides the riders itself through `CrossingStub` on every peer (host and clients, from `receive_departure`), and the shell only checks whether the run is over, so a client's bodies hide without the shell.
- A finished `BuildSite` leaves the tree at once (not at the end of the frame) so the structure and a fresh site can reuse its name.
- The weather condition reads `WeatherData.is_clear` through the content catalog; the structure condition reads the `built_structures` group and a `recipe_id` meta set by the structure.
- `docs/ISLANDS.md` §1 sandbar text was edited for the rope; the sandbar's description line was invalid UTF-8 (a stray byte) and is now valid.

## Follow-ups

Crossing scene replaces `CrossingStub` and the shell's handling of `route_started`; arrival and the "next island waits" half of split parties; Mecánico and pliers build speed; bleeding causes, bandages and status sync; discovery sync and a map UI; a "me quedo" choice; binoculars on islands that have them (cairn, captain's chest); the raft's 6 driftwood and the nightly fires compete for the sandbar's 8 driftwood (sandbar-island decision 1).
