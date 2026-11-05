# CLAUDE.md — 90 Millas

Read this before touching the repo. The design docs in `docs/` are the source of truth for gameplay; `openspec/` is the source of truth for what is being built right now.

## What this is

Godot 4 (GDScript) co-op survival roguelite, 1–4 players, real-time, 2D top-down pixel art. Cuban balseros island-hop across the Florida Straits. See `docs/GAME_DESIGN.md`.

## Workflow

- Every feature starts as an OpenSpec change: `/openspec:proposal`, review, `/openspec:apply`, `/openspec:archive`. Do not write gameplay code without a change in `openspec/changes/`.
- Use the Godot MCP to run the project and read errors after every change. A feature is not done until the project runs clean.
- Keep `TASKS.md` current: tick tasks as they ship, add new ones below the current milestone.
- Small PRs, one capability each. Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`).

## Godot conventions

- Godot 4.4+, GDScript with static typing on every variable, parameter and return (`var hp: int = 10`, `func take(amount: float) -> void`).
- Scenes: one scene per entity in `game/scenes/<area>/<name>.tscn`, script beside it with the same name.
- Node names in PascalCase, files in snake_case, signals in past tense (`died`, `item_picked_up`).
- Data, not code: items, creatures, NPCs, recipes and islands are `Resource` subclasses saved as `.tres` in `game/resources/`. Adding a crab must never require editing a script.
- Autoloads (singletons) live in `game/scripts/autoload/`: `GameState`, `NetManager`, `WeatherManager`, `DialogueService`, `AudioManager`. Keep them thin; logic belongs in components.
- Components over inheritance: `SurvivalMeters`, `Swimmer`, `Inventory`, `Stealth` are child nodes, not base classes.
- Multiplayer: the host is authoritative. State lives on the host and syncs through `MultiplayerSynchronizer`; clients send intents through RPCs marked `@rpc("any_peer", "call_local")`. Never trust client-reported positions or inventory.
- Pathfinding: `AStarGrid2D` on the island grid. Field of view: shadowcasting in `scripts/fov.gd`.
- Pixel art: 16×16 tiles, 32×32 characters, viewport 640×360 scaled, `texture_filter = nearest`.

## Writing and dialogue

- Spanish first. English is a translation that keeps key slang untranslated.
- Cuban voice: slang, political satire and swearing are intended. Satire targets the system and daily life, never invented quotes from real politicians.
- Handwritten: main story beats, boss scenes, endings, minor NPC lines (`game/resources/dialogue/*.tres`).
- AI-generated (Claude Haiku 4.5 on Bedrock, via `backend/`): important NPCs and texts found every run. The prompt and slang glossary live in `backend/prompts/`. Always ship handwritten fallback lines for offline play.
- Every generated line returns JSON `{speaker, text, emotion}`; the game never renders raw model output.

## Backend

- `backend/` is an AWS SAM app: API Gateway → Lambda (Python 3.12) → Bedrock `anthropic.claude-haiku-4-5`.
- AWS credentials never enter `game/`. Per-player rate limiting and response caching (keyed by game-state hash) are mandatory.

## Testing

- GUT (Godot Unit Test) for pure logic: generation, meters, recipes, pathfinding.
- A headless smoke test (`godot --headless -s tests/smoke.gd`) must pass in CI.
- Co-op: run host + client locally before merging any networking change.

## Don'ts

- No copied code from Shattered Pixel Dungeon, Brogue or DCSS (GPL). Ideas and structure only. They live in `reference/` (git-ignored, `./tools/clone_references.sh`); read there, write here.
- No AWS keys, tokens or `.env` files committed.
- No new autoloads without a spec change.
- No copyrighted characters, logos or real people in assets or dialogue.
