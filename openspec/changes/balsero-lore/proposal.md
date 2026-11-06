# Proposal

## Why

The user asked for lore drawn from real balsero history and new content built on it: a car that floats on fuel drums, a surfboard crossing and a seagull that sits on a player's head as the party leaves the final island. A research pass (sources in `docs/LORE.md`) and a design pass produced 16 additions. On 2026-11-05 the user decided every open option and asked for the docs, specs and content manifest to be written, with no game code. The patrol plane (addition 9) is not part of this change: it waits for the guardacostas-stealth work.

## What Changes

- **Era.** The run is the present day. 1994 and the older waves (Camarioca 1965, Mariel 1980) appear only in found texts, wrecks and older characters' stories. Landing is the win, not a legal guarantee.
- **escape-routes:** two rolled routes join the eight. The *almendrón flotante* (a rare 1950s car on four drums, drawn as a car; drums are floats only, fuel is a separate jug per crossing) and *la tabla* (a rigged surfboard, one per rider, needs trade wind). Neither is ever an island's guarantee; a car used this run cannot be rebuilt after a capture. Weather gating gains the board.
- **crossing:** the car is a vessel (integrity 160, squall −45) and the board is its own vessel type (integrity 60 per rider, lost on arrival, riders land 10–20 tiles apart). Both profiles stay inside 60–120 s.
- **creatures-ai:** the *galleguito* perches on a player's head on every final crossing (`perch_ride`: +10 morale once per player, may steal one held snack, never a survival lever); `ambient` joins the behavior list (songbird, booby); the rabihorcado is a catch thief; a check that chance-1.0 crossing rules are always placed.
- **endings-progression:** *Devuelto* unlocks the *Pluma de galleguito* (gulls never steal from the holder); endings carry flag-gated epilogue lines.
- **npcs-dialogue:** three new ending flags.
- **Data (no spec change):** 16 new items (grapefruit steak, milordo, sugar, bicycle tube, botija, drums, propeller, fuel jug, board, sailed board, three found texts), 4 recipes, 2 keepsakes, 5 POIs, 2 set pieces (the raft in the living room, the piling), 4 creatures, 2 dialogue beats and about 15 new entries in existing texts. Two content batches (11 and 12) cover them.
- **Docs:** new `docs/LORE.md`; `GAME_DESIGN`, `ITEMS`, `ISLANDS`, `BESTIARY`, `CHARACTERS`, `ASSETS` and `CONTENT_MANIFEST` describe the additions; `TASKS.md` §10 gets the two batches; the repo review records four open lore problems the user chose to leave.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `escape-routes`: "Routes" and "Weather gating" modified; added "Almendrón route", "Almendrón capture", "Board route", "Rolled routes are never the guarantee".
- `crossing`: "Crossing scene", "Vessel integrity" and "Arrival" modified; added "Car and board profiles".
- `creatures-ai`: "Behavior state machines" modified; added "Perch ride", "Final gull", "Crossing spawn rules", "Frigatebird".
- `endings-progression`: "Devuelto" modified; added "Epilogue lines".
- `npcs-dialogue`: "Ending flags" modified.

## Impact

- **No code under `game/`.** The Tier B pieces (car and board vessels, the board's arrival scatter, the head-perch behavior, the ambient script) are specified here and listed as unticked implementation tasks for a later code change, with 1-player GUT tests named in `tasks.md`.
- **Solo stays first-class.** Every requirement states its 1-player case. No addition needs a teammate, none is an island's skill-free guarantee, and morale from seeing a bird or reading a text is per player, never a bonus that grows with party size.
- **Left unchanged on purpose** (the user's decision; recorded in `docs/reviews/2026-11-05-repo-review.md`): the Medalla de la Caridad revive against the no-faith rule, the real names in existing docs (Radio Martí, Radio Reloj, the Los Van Van cassette, Cohibas, Messi), and the freighter's *¡Patria y Vida!* slogan.
- **Not in this change:** the patrol plane and `cutter_us`; the guardacostas-stealth capture deltas; `RouteData.on_arrival_effects` (see `design.md`).
- Not archived: the code and content tasks are open.
