# Proposal

## Why

Nothing under `game/` exists yet, and every Milestone A change (`player-movement` first) needs a project that opens, a place for content data, a test harness and a CI gate. Building those once, before any gameplay, keeps the first feature changes small and lets every later change prove itself with `godot --headless` instead of manual checks.

## What Changes

- New Godot 4.7 project at `game/project.godot`: 640×360 base viewport, integer scaling, nearest texture filtering project-wide, GL Compatibility renderer, a minimal main scene that boots and idles.
- Typed `Resource` classes for every content folder in `docs/CONTENT_MANIFEST.md`, including the folders the manifest lists without naming a class (`pois/`, `weather/`, `dialogue/`), plus a content catalog that discovers `.tres` files by folder so adding content never needs a script edit.
- The five global services from `CLAUDE.md` (`GameState`, `NetManager`, `WeatherManager`, `DialogueService`, `AudioManager`) as thin, typed autoload stubs with no gameplay logic.
- GUT 9.7.1 (the release for Godot 4.7) vendored under `game/addons/gut/`, with unit tests for the data classes, the catalog and content validation.
- A headless smoke test (`game/tests/smoke.gd`) that boots the project, checks the services and content, and exits non-zero on any failure.
- A GitHub Actions workflow that imports the project and runs the smoke test and GUT on Linux against the same pinned engine version.
- Corrects the smoke-test command in `CLAUDE.md` and the autoload names in `README.md`'s layout to match what is built, and adds `.gitattributes` so scripts keep LF endings on Windows.

## Capabilities

### New Capabilities

- `content-data`: game content (creatures, items, recipes, NPCs, dialogue, chains, POIs, set pieces, routes, backgrounds, weather, texts, keepsakes) is stored as typed data files that are discovered by folder, identified by id, bilingual, and validated, so adding content never requires code.
- `core-services`: the fixed set of always-available global services every scene and headless script can rely on, and the rule that changing that set requires a spec change.
- `build-verification`: the project opens and quits clean headless, unit tests run headless with a failing exit code on failure, and CI gates every push and pull request on a pinned engine version.

### Modified Capabilities

None. The skeleton also applies the display settings from `player-movement`'s "Camera and viewport" requirement (640×360, integer scaling, nearest filtering) without changing that requirement.

## Impact

- New: `game/` (project, scenes, scripts, resources folders, tests), `game/addons/gut/` (third-party, MIT), `.github/workflows/ci.yml`, `.gitattributes`.
- Docs: `CLAUDE.md` Testing section, `README.md` repo layout, `TASKS.md` §2 ticks.
- Tooling: CI downloads the official Godot 4.7.2 Linux build; local runs use the installed 4.7.2 editor. Kenney assets stay git-ignored and nothing in the skeleton references them, so CI needs no assets.
- No gameplay behavior yet; later changes build on these types and services.
