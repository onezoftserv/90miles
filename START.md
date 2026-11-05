# Start a coding session

Open a terminal on the coding laptop, then:

```bash
git clone git@github.com:onezoftserv/90miles.git
cd 90miles
claude
```

Paste this as the first message:

---

Read `HANDOFF.md`, then `CLAUDE.md`, then `docs/GAME_DESIGN.md`, then `openspec/project.md` and `TASKS.md`. Do not read the other docs until a task needs them.

This is the first coding session of 90 Millas. Nothing under `game/` or `backend/` exists yet. Work through `HANDOFF.md` section 3 in order and stop at the end of each numbered step to report before continuing:

1. Tooling (TASKS §0). Check what is already installed before installing: Godot 4.4+, Claude Code, ECC plugin (`ecc@ecc`) and its rules, OpenSpec (`openspec init`, choose Claude Code, keep the existing `openspec/` files), the Godot MCP (Coding-Solo/godot-mcp), AWS and GitHub MCPs. Then `./tools/clone_references.sh`. Tell me anything that needs my input (paths, credentials, a restart of Claude Code) instead of guessing.
2. Assets (TASKS §1). Run `python -I tools/fetch_assets.py`, list the manual downloads from `docs/ASSETS.md` for me to do, and create `game/assets/CREDITS.md`.
3. Project skeleton (TASKS §2) as an OpenSpec change: `/openspec:proposal project-skeleton`. Include the resource scripts from `docs/CONTENT_MANIFEST.md` (CreatureData, ItemData, NpcData, RecipeData, ChainData, SetPieceData, RouteData, TextData, KeepsakeData, BackgroundData), the five autoload stubs, GUT, a smoke test and the CI workflow. Show me the proposal before applying. Run the project through the Godot MCP after applying; it must open and quit clean.
4. Then start Milestone A (TASKS §3) with `player-movement` as its own change.

Rules: follow `CLAUDE.md`. One OpenSpec change per capability. Run the project after every change and read the errors. Data goes in `.tres` resources, never in scripts. Never copy code from `reference/`. Keep `TASKS.md` ticked as you go. At the end of the session, complete the checklist in `HANDOFF.md` section 7 and commit.

---

## Later sessions

Paste this instead:

---

Read `HANDOFF.md`, `CLAUDE.md` and `TASKS.md`. Check `openspec/changes/` for any change left in progress and `git log -5`. Tell me where we are in one paragraph, then continue with the next unticked task in `TASKS.md` as an OpenSpec change. Same rules as always: run after every change, data in `.tres`, nothing copied from `reference/`, tick `TASKS.md`, finish with the section 7 checklist.

---

## Content batches

When the skeleton exists, data entry can run as its own sessions:

---

Read `CLAUDE.md` and `docs/CONTENT_MANIFEST.md`. Create the next unticked batch of resources (at most 30 files) as `/openspec:proposal content-batch-<n>`, using `docs/BESTIARY.md`, `docs/ITEMS.md`, `docs/CHARACTERS.md` and `docs/ISLANDS.md` as the source. Every file must load in Godot (run the project). Tick the manifest, commit.

---
