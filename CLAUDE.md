# CLAUDE.md — 90 Millas

Read this before touching the repo. The design docs in `docs/` are the source of truth for gameplay; `openspec/` is the source of truth for what is being built right now.

## What this is

Godot 4 (GDScript) co-op survival roguelite, 1–4 players, real-time, 2D top-down pixel art. Cuban balseros island-hop across the Florida Straits. See `docs/GAME_DESIGN.md`.

## Workflow

- Every feature starts as an OpenSpec change: `/opsx:propose`, review, `/opsx:apply`, `/opsx:archive`. Do not write gameplay code without a change in `openspec/changes/`.
- Use the Godot MCP to run the project and read errors after every change. A feature is not done until the project runs clean.
- Keep `TASKS.md` current: tick tasks as they ship, add new ones below the current milestone.
- Small PRs, one capability each. Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`).
- Solo is a first-class mode: every feature must work, be winnable and be tested with exactly 1 player, offline (no hosting, no port, no second peer). A rule that needs a teammate (revive, drag, pooled materials, shared seats) must state its solo alternative in the spec, and each change adds at least one 1-player test.
- Reference games first: before designing any mechanic (for example how fast time passes, hunger and thirst rates, stealth, level generation, AI, items), check how Shattered Pixel Dungeon, Brogue CE and DCSS handle it in `reference/`, and how Don't Starve Together does (owner, 2026-11-14). Record in the change's `design.md` which ideas are borrowed or rejected and why: file and function names for the three roguelikes, and wiki page names for DST. Ideas and structure only; never copy code, data tables or text.
  - DST is the closest match: co-op survival with meters, seasons, boats, ghosts and revival, creatures, crafting, and servers you join. It is closed source (Klei), so read it through the community wiki (dontstarve.wiki.gg) and our own notes in `docs/REFERENCE_DST.md`. Never use its code, data, numbers tables, text or art.

## Godot conventions

- Godot 4.7 (CI pins 4.7.2), GDScript with static typing on every variable, parameter and return (`var hp: int = 10`, `func take(amount: float) -> void`).
- Scenes: one scene per entity in `game/scenes/<area>/<name>.tscn`, script beside it with the same name.
- Node names in PascalCase, files in snake_case, signals in past tense (`died`, `item_picked_up`).
- Data, not code: items, creatures, NPCs, recipes and islands are `Resource` subclasses saved as `.tres` in `game/resources/`. Adding a crab must never require editing a script.
- Autoloads (singletons) live in `game/scripts/autoload/`: `GameState`, `NetManager`, `WeatherManager`, `DialogueService`, `AudioManager`. Keep them thin; logic belongs in components.
- Components over inheritance: `SurvivalMeters`, `Swimmer`, `Inventory`, `Stealth` are child nodes, not base classes.
- Multiplayer: the host is authoritative. State lives on the host and syncs through `MultiplayerSynchronizer`; clients send intents through RPCs marked `@rpc("any_peer", "call_local")`. Never trust client-reported positions or inventory.
- Pathfinding: `AStarGrid2D` on the island grid. Field of view: shadowcasting in `scripts/fov.gd`.
- Pixel art (decided 2026-11-08, art direction C "GBA tropic"; replaces the 2026-11-05 16×16 characters): a bright *A Link to the Past* / Pokémon look with 1 px dark outlines in 3/4 view, 16×16 tiles, players drawn as about 16×28 figures in 32×32 frames anchored bottom-centre on a one-tile (16 px) footprint, viewport 640×360 scaled, `texture_filter = nearest`. Sources: MetroCity (people), the ArMM1998 Zelda-like set (land), Scallywag and Eldiran (sea and foam), DawnLike and Tiny, Tiny Heroes (creatures), Kyrise and DawnLike (items); pieces no pack has are kitbashed from them by hand to one master palette, rough first. Only the files used are copied into tracked `game/assets/art/<area>/` folders with their `License.txt`; CC-BY credits go in `game/assets/CREDITS.md` and the in-game credits screen. Art is client-side drawing and never changes the simulation. See `docs/ASSETS.md`.
- Movement sync (decided 2026-11-05): the host simulates every player from `MoveIntent`s; each client predicts its own player locally and reconciles to the host's state. Remote players are interpolated.

## Writing and dialogue

- Spanish first. English is a translation that keeps key slang untranslated.
- Cuban voice: slang, political satire and swearing are intended. Satire targets the system and daily life, never invented quotes from real politicians.
- Cuban speech, not textbook Spanish (owner, 2026-11-08): in dialogue, narration, notes, signs, one-liners, hints and item descriptions use the spoken contractions: pa' (para), pa'l (para el), pa'llá, pa'cá, pa'lante, na' (nada), to' (todo or todos), 'tá and 'toy (está and estoy), and the like. Keep it readable: characters lean on it more than the narrator. Official notices, slogans and bureaucrats keep formal Spanish, because that is the joke. Menus, buttons and settings stay standard. Never contract a homograph: "nada" meaning swims and "para" meaning stops stay whole.
- Handwritten: main story beats, boss scenes, endings, minor NPC lines (`game/resources/dialogue/*.tres`).
- v1 is handwritten only: the important NPCs and the texts found every run included (owner decision, 2026-11-08). AI-generated lines are v2.
- AI-generated, in v2 (Claude Haiku 4.5 on Bedrock, via `backend/`): important NPCs and texts found every run. The prompt and slang glossary live in `backend/prompts/`. Always ship handwritten fallback lines for offline play.
- Every generated line returns JSON `{speaker, text, emotion}`; the game never renders raw model output.

## Backend (v2)

- Not part of v1 (owner decision, 2026-11-08); nothing in `game/` may depend on it in v1.
- `backend/` is an AWS SAM app: API Gateway → Lambda (Python 3.12) → Bedrock `anthropic.claude-haiku-4-5`.
- AWS credentials never enter `game/`. Per-player rate limiting and response caching (keyed by game-state hash) are mandatory.

## Testing

- GUT (Godot Unit Test) for pure logic: generation, meters, recipes, pathfinding. Tests live in `game/tests/unit/test_*.gd`.
- The project lives in `game/`, so every command passes `--path game`. On a fresh checkout run the import twice so `class_name` types resolve (the first pass prints load errors for the project theme, which loads before its fonts and textures are imported; the second must be clean):
  - `godot --headless --path game --import`
  - `godot --headless --path game -s res://tests/smoke.gd` (smoke run; must pass in CI)
  - `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit` (GUT)
- GUT skips test scripts that fail to parse and still exits 0; `test_suite_integrity.gd` fails the run instead, so keep it.
- `Array[StringName].sort()` does not sort by text; sort with a `String` comparator or compare as `PackedStringArray`.
- Co-op: run host + client locally before merging any networking change.

## Don'ts

- No copied code from Shattered Pixel Dungeon or DCSS (GPL) or Brogue CE (AGPL-3.0). Ideas and structure only. They live in `reference/` (git-ignored, `./tools/clone_references.sh`); read there, write here.
- Nothing taken from Don't Starve Together (proprietary, Klei): no code, data, numbers tables, text, names of its characters or art. Ideas only, described in our own words.
- No AWS keys, tokens or `.env` files committed.
- No new autoloads without a spec change.
- No copyrighted characters, logos or real people in assets or dialogue.
