# Proposal

## Why

On 2026-11-05 the user required that the game be fully playable and winnable by 1 player ("make sure the game can be played by 1 player also"), and `CLAUDE.md` now makes solo a first-class mode. A solo-play audit of the specs and design docs found 16 verified gaps where a lone player has no way out (no way back aboard, no steering, no grab escape), gets a contradictory outcome (capture, endings), or receives rewards that do nothing. The user approved a fix or a decision for each one; this change writes them into the specs and the docs.

## What Changes

- **crossing:** a player in the water can climb back aboard an intact vessel alone by holding interact for 3 s at its edge (a teammate's 2 s pull stays faster). Steering against the Gulf Stream no longer needs a Maestro: anyone aboard steers weakly (drift 0.25 tile/s), and a Maestro, Navigation ≥ 2 or compass + charts cancel drift. Drift becomes a lateral offset capped at 40 tiles that never lengthens the crossing, which closes the endless-overshoot loop.
- **guardacostas-stealth:** a 1-player capture is a whole-party capture (a party of one): `la_captura` plays, then the persuasion check; on failure the party restarts the previous island, regenerated from the run seed, keeping its inventory minus fire sources and always keeping keepsakes. On island 1 the party restarts island 1 the same way. A whole-party capture on the final crossing ends the run with `devuelto`. Free a captive states its solo case.
- **creatures-ai:** ALONE (the bull shark's no-blood strike) is broken by any other player or living companion within 5 tiles, and a noise event that reaches a bull shark scares it off for 20 s, solo too. The grabbed player may mash in any party size; the 50% escape roll comes before the second's damage. The crocodile death-rolls when the drag reaches deep water. The boa grab gets the same mash escape.
- **endings-progression:** survivors are the players and companions who reach land; `solo` plays when exactly one survives (any party size), checked right after `el_nino`; `todos` needs at least one companion met. `devuelto` ends the run as a loss: it counts as a death (+1 Experiencia level, 50% carry-over) and unlocks its keepsake. In solo the downed-timer rewards (+5 s per Experiencia level, +10 s boost) lengthen a last-stand window that starts at 0 s.
- **island-generation:** "party size" means the living, connected players when the island is set up. Every island set up for one living player has at least one escape route that needs no background skill and no starting item; solo otherwise uses the same base numbers.
- **ai-dialogue-backend:** the request says how many players the line addresses (`one` or `several`), that value is part of the cache key, and Spanish second person (tú / ustedes) must match it, in generated lines and in the singular and plural forms of every handwritten fallback that addresses the player(s).
- **Docs:** `docs/GAME_DESIGN.md` §8, §9, §10, §13 and §14, `docs/BESTIARY.md` (crocodile, old crocodile, shore squad, bull shark, boa, party size) and `docs/CHARACTERS.md` (Yunior) are brought in line; review items 30, 33 and 51 and the Medalla data-model question are marked decided.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `crossing`: "Steering and current" (weak steering for anyone aboard, capped drift offset) and "Fall in and rescue" (self-climb in 3 s).
- `guardacostas-stealth`: "Capture outcome" and "Free a captive" (a solo capture is a whole-party capture); added "Previous island after capture" (regenerated from the seed, island-1 fallback) and "Capture on the final crossing".
- `creatures-ai`: "Shark targeting" (ALONE and the noise scare) and "Grab and rescue" (mash in any party size, roll first, one tuning); added "Crocodile death roll" and "Boa grab".
- `endings-progression`: "Ending selection" (survivors, solo, todos); added "Devuelto" and "Solo last stand from Experiencia".
- `island-generation`: "Resource spawns" (party size = living, connected players at set-up) and "Escape routes" (solo route guarantee).
- `ai-dialogue-backend`: "Endpoint" and "Caching" (the `addressed` field and cache key); added "Second person matches the players addressed".

## Impact

- Specs only: six delta specs, no code under `game/` or `backend/`. Each capability's build change implements and tests these requirements, including a 1-player test per scenario.
- Docs: `docs/GAME_DESIGN.md`, `docs/BESTIARY.md`, `docs/CHARACTERS.md`, `docs/reviews/2026-11-05-repo-review.md` (items 30, 33, 51), `openspec/changes/archive/2026-11-05-project-skeleton/data-model-questions.md` (Medalla question).
- The rest of the solo picture is owned by two other changes in flight, listed here so the whole solo design is in one place:
  - `coop-networking` change: a solo pause freezes the whole simulation (clock, meters, creatures, patrols, weather) and co-op has no pause; difficulty scaling counts living, connected players, so one player gets resources ×1 and patrols +0 (island-generation uses the same count).
  - `survival-meters` change: the Medalla de la Caridad's free revive works for a solo holder; the solo last-stand window (0 s base on run 1, plus the Experiencia easing and boost stated here) and the solo-death line in `docs/GAME_DESIGN.md` §4.
- Still open after this change: the final-crossing patrol event that makes `devuelto` reachable (review item 32), the Devuelto keepsake's name and effect (data-model question 9), what companions do during a capture, and the rest of review item 29 (vessel speed, base duration per band, integrity units).
