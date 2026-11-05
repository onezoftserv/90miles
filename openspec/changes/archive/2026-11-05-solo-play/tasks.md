# Tasks

This change edits specs and docs only. No file under `game/` or `backend/` changes, so the import, smoke run and GUT gate is unaffected; each group checks that instead of running Godot.

## 1. Delta specs

- [x] 1.1 Write the six delta specs (crossing, guardacostas-stealth, creatures-ai, endings-progression, island-generation, ai-dialogue-backend), copying every MODIFIED block whole from `openspec/specs/`, and verify every changed or added requirement has a scenario with exactly 1 player and numbers
- [x] 1.2 Verify `openspec validate solo-play --type change --strict` passes and every requirement description is 500 characters or fewer
- [x] 1.3 Verify `git status` shows no change under `game/` or `backend/`

## 2. Design docs

- [x] 2.1 Update `docs/GAME_DESIGN.md`: §8 (steering, climbing back aboard), §9 (capture), §10 (solo tuning), §13 (ending order and survivors), §14 (Medalla, solo downed-timer rewards, Devuelto), and verify each section matches its delta spec
- [x] 2.2 Update `docs/BESTIARY.md` (party size, crocodile and old crocodile, shore squad on capture, bull shark, boa) and `docs/CHARACTERS.md` (Yunior's death no longer selects Solo), and verify a search for "Solo: mash", "a solo player loses their items" and "Solo is unlocked even if others survived" finds nothing in `docs/` outside `docs/reviews/` (which quotes them as evidence)
- [x] 2.3 Verify `git status` shows no change under `game/` or `backend/`

## 3. Decision records

- [x] 3.1 Mark review items 30, 33 and 51 in `docs/reviews/2026-11-05-repo-review.md` as "Decided 2026-11-05: ..." in the table and in each section's Status line, and verify the table and the sections agree
- [x] 3.2 Mark the Medalla question (item 10) in the archived project-skeleton `data-model-questions.md` as decided, and verify the line names the `survival-meters` change as its owner
- [x] 3.3 Verify `openspec validate --all` passes and `git status` shows no change under `game/` or `backend/`

## Workflow follow-up

- Each capability's build change implements these requirements and adds a 1-player, offline GUT test for every solo scenario here (crossing, guardacostas-stealth, creatures-ai, endings-progression, island-generation, ai-dialogue-backend).
- Archive this change after the `survival-meters` and `coop-networking` changes it depends on, then re-run `openspec validate --all`.
- Still open elsewhere: the final-crossing patrol event (review item 32), the Devuelto keepsake's name and effect, companions during capture, the rest of review item 29.
