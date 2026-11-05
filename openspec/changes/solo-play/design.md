# Design

## Context

See proposal.md for why. The 16 audit findings touch eight capabilities; this change owns six of them. `survival-meters` (Medalla revive, solo last stand, §4 solo death) and `coop-networking` (solo pause, scaling count) are being changed in other sessions, so this change does not edit their specs and only states the Experiencia side of the last stand. Nothing is built here: each requirement is implemented and tested in its capability's build change.

## Goals / Non-Goals

**Goals:** every rule that needed a teammate states its solo alternative; every changed or added requirement has a scenario with exactly 1 player and real numbers; the design docs say the same thing as the specs.

**Non-Goals:** code, `.tres` content, the final-crossing patrol event (review item 32), the rest of review item 29 (vessel speed, base duration, integrity units), companions during capture, the Devuelto keepsake's name and effect.

## Decisions

Each decision below is the user's (approved 2026-11-05) unless marked **provisional**, meaning this change picked the detail and it is easy to change.

1. **Solo tuning (island-generation "Escape routes"):** solo uses the same base numbers as co-op. Every island set up for one living, connected player exposes at least one reachable route that needs no background skill and no background starting item. **Provisional:** "starting item" means an item from a background's starting kit (GAME_DESIGN §10); keepsakes are not counted. Rejected: hidden solo-only numbers or a generalist skill bonus (no XP model exists yet, review item 28).
2. **Pause:** a solo pause freezes the whole simulation, co-op has none. Owned by the `coop-networking` change; listed in proposal Impact only.
3. **Steering (crossing "Steering and current"):** anyone aboard steers with no held station (drift 0.25 tile/s), so a solo player can tie down in a squall and still steer; a Maestro, Navigation ≥ 2 or compass + charts cancel drift. Drift is a lateral offset capped at 40 tiles that never lengthens the crossing, which closes the loop in review item 29. **Provisional:** with nobody aboard (everyone in the water) drift stays 1 tile/s, and a crossing whose offset reached the cap keeps the existing "skips to a harder chain" outcome; where that skip lands in the branch graph is still review item 29.
4. **Capture (guardacostas-stealth):** a solo player is a party of one: `la_captura`, the persuasion check, and on failure the previous island regenerated from the seed with the inventory minus fire sources, keepsakes always kept. Regenerating (rather than restoring saved state) means the raft materials already spent are back, so a capture can never soft-lock a run. **Provisional:** on island 1 the party restarts island 1 regenerated the same way; a whole-party capture on the final crossing rolls no persuasion check and goes straight to `devuelto` (decision 9), because there is no next cay to release the party at.
5. **Bull shark (creatures-ai "Shark targeting"):** another player or a living companion within 5 tiles breaks ALONE (the radius the data model already has); any noise event that reaches a bull shark makes it leave for 20 s instead of investigating. Trade-off: near a patrolled shore that noise (radius ≥ 8) can also spot the party (guardacostas-stealth "Triggers").
6. **Boa (creatures-ai "Boa grab"):** mash interact, 50% per second, rolled before that second's 10 damage, in any party size; no extra mash cost because the constriction is the cost.
7. **Crocodile (creatures-ai "Grab and rescue", "Crocodile death roll"):** one tuning for every party size (the old crocodile still lunges for 80 solo); anyone grabbed may mash; the roll comes before the 10-health cost. **Provisional:** when the drag reaches deep water the crocodile death-rolls for 20 damage plus bleeding and lets go. Alternatives were holding the player until freed (a guaranteed solo death) or releasing for free (makes the drag meaningless).
8. **Endings (endings-progression "Ending selection"):** survivors are the players and companions who reach land; order `devuelto` → `el_nino` → `solo` → `todos` → `los_que_llegamos`. `solo` sits right after `el_nino` so it plays whenever exactly one survives. `todos` needs at least one companion met, so a lone balsero who met nobody gets `solo`, not "the whole group". `los_que_llegamos` takes every other outcome, so every cell has exactly one ending. Yunior's death no longer selects `solo` (`docs/CHARACTERS.md` updated).
9. **Devuelto (endings-progression "Devuelto"):** ends the run as a loss: counts as a death (+1 Experiencia level, 50% carry-over), not a win (no −2), and unlocks its keepsake except in a seeded run. The keepsake's name and effect stay open (data-model question 9) rather than being invented here.
10. **Downed-timer rewards (endings-progression "Solo last stand from Experiencia"):** for a player with no other living player the existing +5 s per level and +10 s boost lengthen a last-stand window whose base is 0 s, so run 1 stays brutal and both rewards matter solo. `survival-meters` defines what the window does and the Medalla revive that shares it.

Clear fixes:

- **Self-climb (crossing "Fall in and rescue"):** hold interact for 3 s within 1 tile of an intact vessel's edge. **Provisional:** 3 s, not 2 s, because the teammate's pull is 2 s and must stay faster.
- **Party size (island-generation "Resource spawns"):** living, connected players counted when the island is set up; respawns on that island reuse the count. `coop-networking` holds the same rule for its scaling factors.
- **Second person (ai-dialogue-backend "Endpoint", "Caching", "Second person matches the players addressed"):** an explicit `addressed: one|several` field in the request and the cache key, instead of deriving it from the context bucket, so a cached `ustedes` line can never reach a solo player; handwritten fallbacks that address the player(s) ship in both forms. Cost: those fallbacks double, which is limited to lines that actually address the player(s).

## Risks / Trade-offs

- [Requirements here depend on two changes in flight (`survival-meters` for the last-stand window, `coop-networking` for the scaling count)] → this change states only its own side and names the owner; archive it after or alongside them and re-run `openspec validate --all`.
- [`devuelto` is still unreachable until the final crossing has a patrol event (review item 32)] → named in proposal Impact; the crossing build change must add it.
- [Regenerating the previous island refills resources, so a capture could be used as a refill] → the persuasion check still costs fire sources and time; a per-run release limit stays open in review item 30.
- [Untested numbers (the provisional 3 s climb and 20-damage death roll, the user's 0.25 tile/s weak steering, the existing 40-tile cap) need playtests] → each is one constant with a named scenario.
- [Weak steering for everyone makes a Maestro less special] → a Maestro still cancels drift outright and keeps every other Navigation perk.
