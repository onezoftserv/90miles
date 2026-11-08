# Proposal

## Why

A crossing ends nowhere: riders vanish through `ArrivalStub` and a solo run ends in the summary the moment the raft lands. Milestone B needs the second island: `docs/ISLANDS.md` says island 2 is always a coast-chain island. This change builds *el cayo de la costa* as handmade data, replaces the stub with real arrival, and settles what happens to a party that splits across a crossing.

## What Changes

- A second handmade island, *El cayo de la costa* (`game/resources/islands/coast_cay.tres`, base variant): 88×64 cells, 1,021 land cells (18.1%), a long axis of 60 tiles; beach and dunes with sea grapes, a rocky point with the observation post, a 42-cell brackish lagoon, a dune with aloe, a buried rope cache, a flotsam line, 8 driftwood, 5 palms with 10 coconuts, the raft build site and a landing of 4 beach cells.
- Four new items as data: *Clavos* (`nails`), *Espejo* (`mirror`), *Sábila* (`aloe`), *Fosforera* (`lighter`).
- Arrival replaces `ArrivalStub`: `IslandArrival` (hold and land a body) and `IslandTravel` (a session child that keeps the live island). Riders of an ended crossing wait on the shore out of play; when no living player is left on the sandbar and no crossing is running, the host loads the coast cay for every peer (one live level). Riders land within 5 tiles of each other with the health and energy they had; an intact raft is beached at the raft build site with its crossing integrity and can be launched again; a broken raft is lost.
- The island scene builds any handmade layout it is given before it enters the tree; the layout names its chain family (creature rules read it) and its next island (`sandbar` names `coast_cay`; the coast cay names none, so leaving it ends the run with today's summary until the next island exists).
- Layout data for a drinking spot (the lagoon: thirst +10 now, −5 after 30 s) and for flavour signs (dead radio, two wall slogans, the crossed sticks), shown as speech bubbles on every peer.
- Delayed effects: `EffectData.delay_s` is honoured, in the player's own meter ticks. `EffectApplier` also interprets `CURE_STATUS` (aloe needs it).
- Reef sharks and land crabs also spawn on the coast chain; gulls stay sandbar-only (the coast cay has no nest palms).
- Joiners and rejoined players hear the host's island, who waits and the raft lying there in the world state.
- A waiting rider no longer counts as company or as a teammate who could revive (`PlayerBody._has_living_teammate`), so the last player on the island falls into a solo last stand, not a wait for a revive nobody can give.

Capabilities: no new one (the island lives in `island-generation`). Modified: `crossing` (Arrival), `escape-routes` (Split parties). Added requirements: `island-generation`, `crafting-inventory`, `creatures-ai`.

Not in this change: the village variant, Ramón and *La Esperanza II*, the other balseros' camp, NPCs, patrols, searchlight and the "best hiding spot", stealth, tarp sail, Gulf Stream, noni (no item data), "Navigation ≥1 to notice" (no skills yet), mirror signalling, nails reinforcing a raft, raft repair, the run summary and death rework, island generation, spectating a teammate while waiting.

## Solo

Solo is first class. A solo player never waits: their crossing ending loads the coast cay at once. Tested with exactly 1 player, offline: a solo crossing lands alone on the first landing cell with the health and energy the crossing left and a raft beached at its integrity; a broken raft is lost; the beached raft launches again and the run then ends in the summary; a death in the crossing ends the run as a death; one player drinks from the lagoon, reads the wall, takes the post's nails and builds a raft there alone, and lights a fire with the lighter in 1 s.

## Confirmed by the owner (2026-11-08)

1. **Split parties.** Riders whose crossing ends wait out of play with their meters frozen (they may watch). When no living player is left on the sandbar and no crossing is running, the host loads the coast cay for every peer. Riders land within 5 tiles of each other with the health and energy from their crossing result; an intact raft is beached at the raft site and can be launched again. A solo player never waits. This modifies `escape-routes` "Split parties", whose scenario is kept and reworded and to which five scenarios are added.
2. **Requirement name.** This change adds the island-generation requirement `Any handmade layout builds the island` exactly; the `secret-cay` change drops its own copy and relies on this one.
3. **The lagoon.** Brackish water is unlimited, as `docs/ISLANDS.md` §2 says (thirst +10, then −5 after 30 s).

## Provisional decisions

The owner confirmed these as they stand on 2026-11-08, and kept the rule that a rider waiting on the next island is no living teammate (the last player on the sandbar gets the solo last stand). The sign lines stay draft Spanish for the owner's voice pass.

Not yet confirmed by the owner. Each is data or a named constant.

- **Q3 What a waiting rider sees.** A centred label "En la orilla. Esperando a: <names>" from the shell, over the sea their crossing left them in. No spectate camera yet (a follow-up).
- **Q5 The rope cache is visible to everyone** until skills exist ("Navigation ≥1 to notice" waits for them); the crossed-stick sign is flavour for now.
- **Q6 No noni tree**: noni has no item data. A follow-up with the food items.
- **Q7 No workbench on the coast cay**: the doc lists none; raft and fire are build sites, so nothing is blocked.
- **Q8 Two rafts arriving**: the sturdiest intact one is beached, the others are lost. Only possible if a second raft was built on the sandbar.
- **Numbers.** Grid 88×64, land 1,021, lagoon 42 cells, long axis 60 tiles; landing: 4 cells in a 2-tile-spaced square (pairwise ≤ 2.9 tiles); walks from the first landing cell: raft site 2.6 s, flotsam 3.1–4.3, lagoon 6.5, aloe 8.1–8.7, cache 11.6–11.9, post 13.8–14.3. Nails ×4 (the doc gives no count; the almendrón's 6 belong to the village), mirror ×1, aloe ×4, rope ×4 and lighter ×1 (doc), tubes ×2, jugs ×2, driftwood 8, coconuts 10 over 5 palms; counts fixed, not scaled by party size. Items: nails stack 12 weight 0.1; mirror weight 0.3; aloe stack 4 weight 0.2 with a 1 s use; lighter 20 uses, fire in 1 s, weight 0.1.
- **Drink hold 2 s** (the timed-interaction default) and the −5 after 30 s (the doc says "then").
- **Sign lines** are draft Spanish and English, for the owner's voice pass; generic slogans, no named person, no real quote.
