# Design

## Context

The repo held design docs and specs only; `game/` and `backend/` were empty (see proposal.md - Why). The project must live in `game/` (README layout), run on Windows for development and Linux in CI, and follow `CLAUDE.md`: static typing, data in `.tres`, thin autoloads, host authority, no new autoloads without a spec change. Godot 4.7.2 is the installed and current stable engine.

Facts checked against the real 4.7.2 binary before deciding (throwaway projects in the session scratchpad):

- Autoloads are in the tree and have run `_ready` when a `SceneTree` script runs with `-s`.
- `class_name` types are not registered on a fresh checkout (no `.godot/`) until `godot --import` has run once.
- `ResourceLoader.list_directory()` exists and lists resource files; it is the export-safe way to enumerate `res://` folders.
- `OS.add_logger()` with a `Logger` subclass receives engine and script errors, so a headless run can count them.
- Both pixel fonts contain ñ, Ñ, accented vowels, ü, ¿ and ¡.
- GUT 9.7.1 is the release for Godot 4.7; GUT skips test scripts that fail to parse and still exits 0.

## Goals / Non-Goals

**Goals:**
- A project that opens and quits clean headless, with every later change able to prove itself with the same three commands.
- One content type per manifest folder, discovered by folder, validated mechanically.
- A CI gate that cannot pass with broken scripts, broken test files or invalid content.

**Non-Goals:**
- Any gameplay, UI beyond a title label, networking, weather or dialogue logic.
- Creating content `.tres` files (the content batches in `TASKS.md` §10 do that).
- Godot MCP setup (tooling outside the repo).

## Decisions

### Project layout and commands
The project root is `game/`; tests are inside it (`res://tests/`) so they can use `res://` paths. Every command passes `--path game`, and CI runs `--import` first because of the `class_name` fact above. `CLAUDE.md`'s old `godot --headless -s tests/smoke.gd` could not work from the repo root and is corrected.

### Renderer and display
GL Compatibility renderer: 2D only, widest hardware support, and it keeps a web export open. Forward+ adds nothing for 16×16 pixel art. Display follows `player-movement`'s "Camera and viewport": 640×360 base, `stretch/mode = viewport` with `scale_mode = integer` (pixel-perfect; `canvas_items` would allow sub-pixel motion), nearest texture filter project-wide, 2D transforms snapped to pixels, and a 1280×720 window by default.

### Content model
- `ContentData` (`scripts/data/content_data.gd`) is the base of every content type: `id` (equals the file name), `name_es`, `name_en` with English falling back to Spanish, `get_reference_fields()` declaring which fields hold ids of which content type, and `requires_name()`.
- One `Resource` subclass per manifest folder in `scripts/data/`, registered in `ContentCatalog.DEFAULT_TYPES` (folder name → script). The class list and fields come from a read of every source doc and spec; see "Data classes" below.
- References between content are `StringName` ids (single id, array of ids, or dictionary keyed by id), not direct `Resource` references: files stay independent, load order does not matter, and the validator can check every reference by id. Alternative considered: `ExtResource` links in `.tres`. Rejected because a broken link fails at load time with an engine error instead of a named content error, and circular references (NPC ↔ quest item) become awkward.
- Shared enums live in one `DataEnums` script when more than one class needs them.

### Discovery and validation
- `ContentCatalog` lists `<root>/<type>/` with `ResourceLoader.list_directory()` (export-safe: exported builds list remapped resources) and keys entries by file name. It takes a root and a type map so tests point it at throwaway folders under `user://`. It is a plain `RefCounted` owned by `GameState`, not an autoload, because `core-services` fixes the autoload set at five.
- `ContentValidator.validate(catalog)` returns one message per problem (`<type>/<id>: ...`) for wrong folder type, id/file-name mismatch, duplicate ids, empty `name_es`, unknown reference fields or types, and dangling references. The smoke run fails on any message.

### Core services
Five autoload stubs in `scripts/autoload/` with no `class_name` (an autoload name is already global). `CoreServices.NAMES` holds the list; `CoreServices.check()` compares it with the project's `autoload/*` settings and the scene tree. `test_core_services.gd` keeps its own copy of the spec's list so the service set changes only when spec, code and test change together.

### Tests and smoke run
- GUT 9.7.1 vendored in `addons/gut/` (MIT) rather than fetched in CI: reproducible, works offline, and the version matches Godot 4.7's stricter return typing.
- `test_suite_integrity.gd` loads every script under `res://tests` and fails if one does not compile, because GUT otherwise skips broken test files and exits 0.
- `tests/smoke.gd` is a `SceneTree` script: it registers a `Logger` that collects errors (not warnings), loads every script under `res://scripts` and `res://scenes` (catches parse errors anywhere, not just in the main scene), instantiates the main scene, runs 10 frames, checks the core services and validates all content, then exits 1 if anything was reported.
- Tests build their fixtures at runtime under `user://` with `ResourceSaver`, so no fixture `.tres` files are committed and each test starts clean.

### CI
One job on `ubuntu-24.04`: download the official Godot 4.7.2 Linux build, verify it against a SHA-512 pinned in the workflow, check that `--version` matches and that `project.godot` declares 4.7, then import, smoke and GUT, each with a timeout. Actions are pinned by commit SHA and the token is read-only. The Godot download is cached per version and hash.

## Risks / Trade-offs

- [Kenney assets are git-ignored, so CI has none] → nothing in the skeleton references them; the build-verification spec makes this a requirement and the smoke run would fail if a scene did.
- [GUT vendored: updates are manual] → pinned on purpose; update GUT together with the engine version.
- [`ResourceLoader.list_directory()` behavior in exported builds is not exercised by CI] → it is the API Godot provides for that case; the first export test should confirm the catalog lists the same ids.
- [The SHA-512 pin must change with every engine update] → the workflow comment says so, and the version check fails loudly if only one of the two is changed.
- [Line endings on Windows] → `.gitattributes` forces LF for Godot files and scripts.

## Data classes

Derived by a workflow: one reader per content group read every source doc and spec entry by entry, a reconciler unified conventions and spot-checked entries, then parallel writers produced the classes and an integrator compiled, registered and tested them on 4.7.2.

| Manifest folder | Class | Notes |
| --- | --- | --- |
| `creatures/` | `CreatureData` | Bosses included; `boss_hurricane` and `boss_straits` are proxy entries (`boss_kind` WEATHER / CROSSING) |
| `items/` | `ItemData` | `KeepsakeData` and `TextData` extend `ItemData`, so the folder still has one content type |
| `recipes/` | `RecipeData` | Non-item outputs (structures, vessels, upgrades) are named by the recipe id |
| `npcs/` | `NpcData` | Companion, quest, hook and ending-role values are embedded parts |
| `dialogue/` | `DialogueData` | Handwritten lines (es + en); the manifest lists the folder without naming a class |
| `chains/` | `ChainData` | |
| `pois/` | `PoiData` | Listed in the manifest without a class |
| `set_pieces/` | `SetPieceData` | |
| `routes/` | `RouteData` | |
| `backgrounds/` | `BackgroundData` | |
| `weather/` | `WeatherData` | Listed in the manifest without a class |

Embedded values extend `DataPart`: `EffectData`, `ConditionData` (recursive `ALL_OF`/`ANY_OF` via `children`), `ModifierData`, `SpawnEntryData`, `ChoiceData`, the creature parts (`CreatureSpawnRuleData`, `CreatureCounterData`, `GrabData`, `PatrolData`), `ItemUseData`, `TextEntryData`, the NPC parts (`NpcSpawnRuleData`, `CompanionData`, `CompanionStatusData`, `QuestData`, `QuestStepData`, `NpcHookData`, `EndingRoleData`), the dialogue parts (`DialogueStateData`, `DialogueLineData`) and `ChainRouteEntryData`. Enums used by more than one class live in `DataEnums` and are append-only because `.tres` files store them as integers.

The derivation found 37 contradictions or gaps in the docs and 16 behaviours data cannot express. Each class takes the choice named in [data-model-questions.md](data-model-questions.md); those are design decisions for the docs' owner, to settle before the matching content batch, and none of them changes this skeleton.
