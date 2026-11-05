# Adversarial repo review, 2026-11-05

Six reviewers (cross-doc consistency, specs vs design, setup and tooling, architecture, balance math, legal and content) read the whole repo; every finding was then attacked by independent refuters (three for high-severity claims), a completeness critic added four gap areas (project-skeleton-code-tests-ci, content-data-schema, creature-behavior-coverage, export-platform-input-ui-shell), and a final pass merged duplicates. 142 findings, 124 survived verification and 18 were refuted; after merging, 60 remain. None is critical or high.

Status is as of commit 481c7c2. "Open" items are design or architecture choices for the owner of the docs; most of them should be settled in the spec of the capability they touch before that capability is built (for example items 15, 17, 19, 20 and 22 before `player-movement` and `coop-networking`).

| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | medium | project-skeleton is labelled GREEN, but its content types are missing and the content check passes on an empty catalog | In progress |
| 2 | medium | The smoke/CI gate misses import errors, every scene except main.tscn, and errors raised while autoloads are constructed | Fixed in d9e8231 |
| 3 | medium | No typed effect or status model: item, plant, wearable, keepsake and companion effects are free text, and bleeding, poison and burning have no numbers | Addressed by the data model |
| 4 | medium | CreatureData has a single behavior id and no behavior parameters, but most bestiary entries are tuned variants with their own rules | Addressed by the data model |
| 5 | medium | Spawn rules have no shared shape or closed vocabulary, and no spec places creatures on generated islands | Addressed by the data model |
| 6 | medium | The manifest stores chains as 18 flat variant files, but every system keys on a chain id that does not exist | Open |
| 7 | medium | Recipes have no source table, most outputs are structures with no content type, and several inputs are not items | Open |
| 8 | medium | Items used by starting kits, quests, recipes and creature loot are missing from the 97-item list, and one fruit has two ids | Open |
| 9 | medium | Loot and resource quantities have two competing sources and no data type | Addressed by the data model |
| 10 | medium | Dialogue, offline fallback lines and handwritten found-text bodies have no schema | Addressed by the data model |
| 11 | medium | Quests are required to be data but have no content type | Addressed by the data model |
| 12 | medium | creatures/ holds entries that no behavior covers or that are not creatures (passive prey, whale, patrols, jet-ski, smugglers, hurricane, Straits) | Open |
| 13 | medium | Weather resources mix the five exclusive states with multi-day and overlapping events that weather-daynight cannot run | Addressed by the data model |
| 14 | medium | Escape routes: ISLANDS uses routes outside the 8 route resources, repair-wreck is defined two ways, and RouteData fields are undefined | Addressed by the data model |
| 15 | medium | Host-authoritative movement with 20 Hz sync and no prediction or interpolation, decided before player-movement is built | Decided 2026-11-05 |
| 16 | medium | Split parties require the host to run several islands and a crossing at once, but networking, weather and scene specs assume one live island | Open |
| 17 | medium | The RPC convention @rpc("any_peer", "call_local") leaves out the rules that make host authority hold | Open |
| 18 | medium | Survival meters: the in-game clock is undefined, drain rates are about 5–10× too slow for the run length, sunstroke can never trigger, and heat runs in opposite directions | Decided 2026-11-05 |
| 19 | medium | Swimming drains 100 energy in 33 s against a 60–120 s crossing, and two specs disagree on what happens at 0 energy in water | Open |
| 20 | medium | Input is only 'WASD/left stick' plus one overloaded interact button; most player verbs have no action, and hold durations contradict | Open |
| 21 | medium | Kenney art is git-ignored and fetched by an unpinned scraper, so CI and release builds have no art and the first sprite breaks build-verification | Open |
| 22 | medium | Asset docs do not match the packs: characters are 16×16 single frames, not 32×32 walk cycles, two listed packs return 404, and destinations differ | Decided 2026-11-05 |
| 23 | medium | No spec or task owns the player-facing shell: title, host/join lobby, run setup, HUD layout, inventory and map screens | Open |
| 24 | medium | Session lifecycle is undefined: no pause rule, no rule for panels open during real-time co-op, no decision on saving a 60–90 minute run | Open |
| 25 | medium | Setup docs are stale: Godot 4.4+ vs the 4.7 the skeleton needs, wrong autoload names and layout, wrong Node/Python floors, wrong repo URL, 'empty repo' state | Fixed in 481c7c2 |
| 26 | medium | MCP setup installs an archived GitHub server and a superseded AWS server, omits uv, and gives the agent write access with the developer's credentials | Fixed in 481c7c2 (setup docs) |
| 27 | medium | Co-op resource scaling shrinks total supply as the party grows, and the 'always buildable' raft cannot be built from the sandbar's listed materials | Open |
| 28 | medium | Specs depend on backgrounds and skill levels nobody defines (no XP curve, a 'Combat' skill that doesn't exist), and profile.cfg has no schema or co-op trust model | Open |
| 29 | medium | The crossing model doesn't close: unsteered drift always overshoots, vessel speed and base duration are undefined, and raft integrity mixes percent and points with no repair cost | Open |
| 30 | medium | Capture rules contradict each other and leave cases unhandled; getting caught on purpose skips crossings and the coast boss | Decided 2026-11-05: one outcome for every party size (solo-play change) |
| 31 | medium | The searchlight's 2 s dwell equals the spot timer, so any stealth level makes a player standing still in the open unspottable | Open |
| 32 | medium | The final crossing (the Straits boss) has no owning requirement, and its patrol is excluded by the crossing event list | Open |
| 33 | medium | Ending selection cannot be computed from the flags the specs emit: common co-op outcomes match no ending, Solo never plays solo, and Devuelto is unreachable | Decided 2026-11-05: survivor-based ending order, Devuelto is a loss (solo-play change) |
| 34 | medium | Experiencia carry-over contradicts other specs: plant-ID scope, easing formula and totals, co-op death, and uncapped permanent boosts | Open |
| 35 | medium | Keepsake effects and unlocks contradict each other across GAME_DESIGN §14, ITEMS and CHARACTERS, and the spec points at the incomplete §14 table | Open |
| 36 | medium | 'Found every run' texts and 'any island' NPCs are tied to chains a run can skip, and 5 of 8 companions have no spawn POI | Open |
| 37 | medium | Per-install API keys issued at first launch make 'per-player' rate limits bypassable, and there is no global cap on Bedrock spend | Open |
| 38 | medium | Client-supplied context goes into the system prompt and the shared 30-day cache key drops most prompt inputs, so one client can poison lines for everyone; which co-op peer calls the backend is unspecified | Open |
| 39 | medium | The 3 s client timeout cannot fit the backend design (6 s Lambda, in-Lambda retry, fetch when the player starts talking), and 100 ms offline needs a health state | Open |
| 40 | low | Join-by-IP over ENet is hard-wired: no peer abstraction, no stable identity for reconnects, and no target-platform list (web rationale conflicts with ENet) | Open |
| 41 | low | .gitignore misses root .env and local junk, and there is no .gitattributes for Godot text resources | Fixed |
| 42 | low | No export preset or filters: the 'Exported build' scenario cannot be verified, test classes and GUT would ship, and backend.cfg would be left out | Open |
| 43 | low | The CI gate has never run and does not bind: commits are unpushed and main is unprotected | Fixed 2026-11-05 |
| 44 | low | The documented smoke-test command fails as written: no --path game and no import step | Fixed in 77cacd3 |
| 45 | low | Spanish-first localization has no path beyond names, and 'English keeps the slang' cannot be told apart from 'not translated yet' | Open |
| 46 | low | Run structure and boss placement contradict across docs: branch point, distance bands, 'one boss per chain', tiger shark's chain, the cutter's crossing | Open |
| 47 | low | Manifest, HANDOFF and TASKS counts don't match the listed content (37 creatures not 40, 22 NPCs not 24), and batches break the 30-file cap | Open |
| 48 | low | The set of AI-voiced NPCs and texts is 7 and 4 in some docs and 12 and 6 in others | Open |
| 49 | low | Smaller number and lore contradictions: dominoes, expired medicine odds, manchineel identification, and the Rodríguez–Caridad timeline | Open |
| 50 | low | Seeded generation inputs are incomplete, so the hash check scope and shared/daily seed rules are undefined | Open |
| 51 | low | Revive works with any cup, including seawater, and the downed-timer boosts do nothing in solo | Decided 2026-11-05: solo last-stand window (solo-play and survival-meters changes) |
| 52 | low | OpenSpec 1.x ignores openspec/project.md and config.yaml has no context, so /opsx planning never sees the glossary | Fixed in 481c7c2 (openspec/config |
| 53 | low | The Bedrock model ID in CLAUDE.md and the spec cannot be invoked on bedrock-runtime | Open |
| 54 | low | No release plan for live AI text: no output moderation, report trail, AI disclosure or privacy and retention policy | Open |
| 55 | low | Runtime Kokoro TTS has no agreed home and its Spanish path pulls in GPL-3.0 espeak-ng, which ASSETS.md doesn't list | Open |
| 56 | low | Content names real people, a band and a brand despite CLAUDE.md's 'no real people' rule; Caridad's AI profile will invent Martí quotes | Open |
| 57 | low | Brogue CE is AGPL-3.0, not GPL, and 'read there, write here' gives an agent no separation between studying and writing code | License wording fixed in 481c7c2 |
| 58 | low | No LICENSE file in the public repo, and shipped builds would lack the required engine and font notices and the credits screen the docs promise | Open |
| 59 | low | Voice-cloning consent is a one-line 'written permission' that does not cover synthetic lines, profanity, satire, commercial use or revocation | Open |
| 60 | low | Mature content has no rating plan or design rule for illicit-drug items | Open |

## Findings

### 1. project-skeleton is labelled GREEN, but its content types are missing and the content check passes on an empty catalog

**Severity:** medium · **Dimensions:** project-skeleton-code-tests-ci · **Status:** In progress: the data classes for every manifest folder are being integrated in project-skeleton.

**Files:** `game/scripts/content/content_catalog.gd`, `game/scripts/content/content_validator.gd`, `game/tests/unit/test_content_catalog.gd`, `game/tests/unit/test_content_validator.gd`, `openspec/changes/project-skeleton/proposal.md`, `openspec/changes/project-skeleton/design.md`, `openspec/changes/project-skeleton/specs/content-data/spec.md`, `docs/CONTENT_MANIFEST.md`, `START.md`, `TASKS.md`

**Evidence.** content_catalog.gd:9 `DEFAULT_TYPES = {}`, so ContentValidator walks no types. The reviewer added a garbage .tres and an untyped .tres to resources/items/ and still got smoke exit 0 and GUT 30/30. scripts/data/ holds only content_data.gd and game/resources/ does not exist, yet proposal.md:10 promises a typed class for every manifest folder and CONTENT_MANIFEST.md:3 says the classes are defined in this change. design.md:66-68 'Data classes: To be filled'. `openspec status` reports 3/4 artifacts and apply is blocked (no tasks.md), but 61a4fdd '(GREEN)' is on main and TASKS.md:27-30 are unticked. Tests pass only because they inject fixture types (test_content_catalog.gd:16). Partial fix: ContentCatalog.unregistered_folders() exists in the working tree, uncommitted. Still open: content_catalog.gd:50 skips subfolders (test_content_catalog.gd:73-79 asserts this), and loose .tres files at the content root are never reported.

**Why it matters.** Every content batch and Milestone A change builds on these types. CI reports green while the change's main deliverable is missing, so broken content will pass as soon as it is written. The first batch to hit the missing classes would force a redesign mid-stream.

**Suggested fix.** Reopen the change. Finish design 'Data classes' and write tasks.md. Add one ContentData subclass per manifest folder and register each in DEFAULT_TYPES. Add tests asserting DEFAULT_TYPES keys equal the manifest folders and that a broken file in a real folder fails the run. Commit unregistered_folders() and also report nested directories and loose root files. Tick TASKS §2 and archive only after that.

### 2. The smoke/CI gate misses import errors, every scene except main.tscn, and errors raised while autoloads are constructed

**Severity:** medium · **Dimensions:** project-skeleton-code-tests-ci · **Status:** Fixed in d9e8231: CI fails on import and run error lines, the smoke run loads every scene and resource and rejects git-ignored asset dependencies. Remaining: register the smoke logger in _init and run the checks on the first frame.

**Files:** `.github/workflows/ci.yml`, `game/tests/smoke.gd`, `openspec/changes/project-skeleton/specs/build-verification/spec.md`, `openspec/changes/project-skeleton/design.md`, `game/scripts/autoload/game_state.gd`

**Evidence.** In HEAD, the ci.yml `--import` step relies only on the exit code, and Godot 4.7.2 exits 0 while logging parse and import errors. HEAD smoke.gd loads only .gd files under scripts/ and scenes/ and instantiates only main.tscn, so a scenes/islands/isle.tscn pointing at res://assets/kenney/missing.png passed both import and smoke. build-verification spec.md:57-63 therefore holds only for main.tscn. Errors from autoload member initializers or _init run before smoke.gd registers OS.add_logger in _initialize, so they print but are not counted. game_state.gd:6 builds the catalog in exactly that window. design.md:9 claims autoloads are in the tree and have run _ready under -s; a probe showed is_inside_tree=false during _initialize. The working tree has a fix that is uncommitted and not CI-proven: ci.yml tees import/run output and greps `^(ERROR|SCRIPT ERROR):`, and smoke.gd loads every .tscn/.tres under scenes/ and resources/ and rejects dependencies in kenney/oga/itch/ambience.

**Why it matters.** Milestone A scenes will reference art and resources, and Linux CI is case-sensitive. Without these checks, broken scenes and a Kenney dependency reach clean checkouts while CI stays green.

**Suggested fix.** Commit the working-tree ci.yml and smoke.gd changes and prove them in CI. Move OS.add_logger into smoke.gd's _init(), which was verified to catch construction errors. Run the service and content checks on the first _process frame. Correct design.md:9 and the ci.yml comment that blames autoload _ready.

### 3. No typed effect or status model: item, plant, wearable, keepsake and companion effects are free text, and bleeding, poison and burning have no numbers

**Severity:** medium · **Dimensions:** content-data-schema, creature-behavior-coverage · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/crafting-inventory/spec.md`, `openspec/specs/creatures-ai/spec.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/crossing/spec.md`, `docs/ITEMS.md`, `docs/BESTIARY.md`, `docs/CHARACTERS.md`, `docs/CONTENT_MANIFEST.md`, `openspec/changes/project-skeleton/design.md`

**Evidence.** crafting-inventory:9 gives items one 'use effect' field, but the data needs more: ITEMS.md:15 seawater '+10, then −30 over 120 s'; :16 rum changes four meters and adds a delayed effect; :51 mushroom has weighted outcomes; :115 '50% heals 30, 50% nothing, 10% poison' (110%, or an undefined separate roll); :44 effect triggered by touch. Bleeding is cited about 15 times (BESTIARY.md:17-18, :31, :95, :203; crossing:41) with no rate, duration or expiry, yet creatures-ai:25 bases shark targeting on it. creatures-ai:9 gives creatures only a scalar 'damage'. Burning is '3 dmg/s, speed −30%' in BESTIARY.md:131 but 'no food' in ITEMS.md:44. Companion and background modifiers are also prose (CHARACTERS.md:104, :108, :112). CONTENT_MANIFEST.md has no statuses folder, and design.md:66-68 has not written the data classes yet.

**Why it matters.** SurvivalMeters timed effects (seawater, raw-food poison, sunstroke), crafting use effects, and content batches 1–9 all need one shape. Without it, each author invents a dictionary or effects get hard-coded, and every item and creature file is redone once the model lands. The shark rule has no defined input.

**Suggested fix.** While deriving the data classes, define shared typed sub-resources: Effect (meter, delta, duration_s, delay_s, status_id), Outcome (weight plus effects; the validator checks weights), Modifier, Trigger (on_use, on_touch, on_equip, passive) and Requirement. Add StatusData (tick effect, default duration, stacking, cured_by tags, AI-readable flags such as bleeding), host-authoritative and synced. Give CreatureData on_hit_effects and contact_effects. Settle the bleeding numbers and the medicine odds.

### 4. CreatureData has a single behavior id and no behavior parameters, but most bestiary entries are tuned variants with their own rules

**Severity:** medium · **Dimensions:** content-data-schema, creature-behavior-coverage · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/creatures-ai/spec.md`, `openspec/specs/crossing/spec.md`, `docs/BESTIARY.md`

**Evidence.** creatures-ai:9 lists id, sprite, health, speed, damage, domain, spawn rules, one behavior id and loot. BESTIARY.md:196 says variants reuse a machine 'with different numbers', but no fields hold those numbers. creatures-ai:25 says all sharks strike only when the target bleeds or has energy below 20, which the bull shark contradicts ('strikes without blood if you are alone', BESTIARY.md:202). creatures-ai:17 gives the crocodile both hidden_ambush and grab_drag, with one slot to hold them. :33 fixes the grab numbers to the crocodile, yet the old crocodile needs 6 hits (BESTIARY.md:81) and the boa has a 2-hit grab with no drag (:221). Most original entries have no health or speed (:16-18, :43, :79). crossing:17 hard-codes 'shark hit −20' while the tiger shark 'breaks a raft in two hits' (:67). Skill-gated reveals (:31, :203, :207) have no field. creatures-ai:49 'Fire emits light' is a sentence, not an event, though crabs flee light (:95) and needlefish are drawn to it (:208), and noise always triggers investigation even though it scares the bull shark.

**Why it matters.** The CreatureData schema is being set now. Without parameter fields, content-batch-1 will either hard-code `if id == &"bull_shark"` branches, breaking 'adding a crab needs no script', or drop the variant rules. Teammate rescue from a grab would end up implemented three different ways.

**Suggested fix.** Give CreatureData a typed per-behavior params resource (SharkParams.strike_condition, ThiefParams, HazardParams, GrabParams with drag speed, release hits and duration). Allow behavior composition, such as ambush handing off to grab. Add a per-event reaction {investigate, flee, attract, ignore} plus duration, a light(pos, radius) event, vessel_damage, and reveal {skill, level} or background. Fill in health and speed for the original creatures. Reword creatures-ai:25 as the reef-shark default and add a scenario for each variant.

### 5. Spawn rules have no shared shape or closed vocabulary, and no spec places creatures on generated islands

**Severity:** medium · **Dimensions:** content-data-schema, creature-behavior-coverage · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/creatures-ai/spec.md`, `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/island-generation/spec.md`, `openspec/specs/weather-daynight/spec.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/crafting-inventory/spec.md`, `docs/BESTIARY.md`, `docs/ITEMS.md`, `docs/ISLANDS.md`, `openspec/changes/project-skeleton/design.md`

**Evidence.** Spawn rules have two shapes: creatures-ai:9 '(chain, time of day, weather, tide)' and npcs-dialogue:9 '(chains, chance, min island)'. The bestiary needs fields neither has: group size (BESTIARY.md:19, :43), odds (:211 'rare (5%)'), once per run (:19), party scaling ×1.2 (:5, missing from coop-networking:41) and POI placement (ISLANDS.md:98). The BESTIARY 'Chain' column mixes biomes, POIs and phases ('Mangrove, lagoon' :202). 'Clear weather' (escape-routes:33) is not one of the states in weather-daynight:17. Item tags differ: 13 in ITEMS.md:5, 7 in crafting-inventory:9. island-generation has no creature requirement, though BESTIARY.md:246 says the generator picks 3–5 types from the chain's list, so references run both ways. ISLANDS.md:54 'Crocodile 20% on mid chains only' sits on the coast cay and can never fire. design.md:40 promises a DataEnums script that does not exist yet.

**Why it matters.** Every content batch writes these values. As free strings they fail the reference check or slip past it, the spawner ends up string-matching, and creature placement gets bolted onto the generator in Milestone C/D.

**Suggested fix.** Create DataEnums for DayPhase, Tide, Skill, ItemTag (one list), Station, DistanceBand and Biome. Reference chains, weather and POIs by validated id. Add one SpawnRule sub-resource (chains or bands, phases, weather, tide, chance, group min/max, max_per_run, poi tags) shared by creatures, NPCs, set pieces and weather events. Add an island-generation 'Creature placement' requirement with one-way references. Define 'clear' and add the ×1.2 rule to coop-networking.

### 6. The manifest stores chains as 18 flat variant files, but every system keys on a chain id that does not exist

**Severity:** medium · **Dimensions:** content-data-schema · **Status:** Open: needs a design decision.

**Files:** `docs/CONTENT_MANIFEST.md`, `docs/ISLANDS.md`, `openspec/specs/island-generation/spec.md`, `openspec/specs/weather-daynight/spec.md`, `openspec/specs/endings-progression/spec.md`, `openspec/changes/project-skeleton/specs/content-data/spec.md`, `TASKS.md`

**Evidence.** CONTENT_MANIFEST.md:43-45 lists 18 files (reef_traps, reef_bluehole …). In the content-data spec an id equals its file name and references must resolve, so a spawn rule naming 'reef' fails validation. The chain id is used by island-generation:9 '(run seed, island index, chain id)', weather-daynight:17 'chain-based weights', creatures-ai:9, npcs-dialogue:9, endings-progression:49 'per chain', and TASKS.md:53 'sandbar, coast, mangrove, reef, rock'. ISLANDS.md:238 says variants 'share the chain's POI table', yet :245 says 'no cave'. ISLANDS.md:15 lists 'Bahamas family' as a far chain, but it is storm-key variant A (:248).

**Why it matters.** Content-batch-7 would copy shared POI tables, weather weights and route lists into two files per chain, which then drift apart, and every 'reef' reference has no id to resolve to. The ChainData schema is being derived now.

**Suggested fix.** Use ChainData (9 files: distance band, POI table, route list, weather weights, creature pool, resource budget) plus variants, either as a sub-resource array or a VariantData type that references its chain. A variant holds layout rule, signature POI, POI add/remove lists and threat overrides. Fix ISLANDS.md:15.

### 7. Recipes have no source table, most outputs are structures with no content type, and several inputs are not items

**Severity:** medium · **Dimensions:** consistency, content-data-schema · **Status:** Open: needs a design decision.

**Files:** `docs/CONTENT_MANIFEST.md`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `openspec/specs/crafting-inventory/spec.md`, `openspec/changes/project-skeleton/specs/content-data/spec.md`

**Evidence.** CONTENT_MANIFEST.md:29 lists 18 recipe ids and no doc gives a table for them. Twelve outputs are not items: raft, raft_hardwood, raft_repair, solar_still, rain_catcher, sail, mast, oars, fire, signal_fire, bandage, shade_pit. Inputs that are not items: 'rocks', '4 sticks', 'friction' (GAME_DESIGN.md:95), 'rope + stick' (ITEMS.md:65), 'rock + knife' (:72), 'Casuarina sap' (:87). crafting-inventory:25 defines a recipe as inputs, one output and a station (none/workbench/fire), and :30 says inputs are consumed, which would destroy the knife in 'driftwood + knife'. 'fire' is both a station and a recipe output. Cooked foods (ITEMS.md:23, :25) have no cooking recipe and no raw hutía or iguana. Shared build sites take deposits (:57). The validator rejects unresolved references (content-data spec:46-57). The Papo-only shovel/oar rule has no field (oars exist as shovel_oar).

**Why it matters.** Raft integrity, still yield and fire light/smoke have no data home, so they get hard-coded. Batch-5 either fails validation or invents ids. Milestone A crafting-inventory already needs fire and the rain catcher.

**Suggested fix.** Add a recipe table (docs/RECIPES.md or ITEMS.md) with ingredients, quantities, consumed vs tool, station, time, skill multiplier, required companion and output kind. Add StructureData for raft, still, catcher, fire, signal fire, shade pit and workbench (integrity, yield, light/smoke radius). Give RecipeData an output kind of item, structure or repair. Add rock, stick, bandage, mast and sail. Decide whether cooking is recipes at station fire or an ItemData cooks_into field. Drop or define 'mirror signal'.

### 8. Items used by starting kits, quests, recipes and creature loot are missing from the 97-item list, and one fruit has two ids

**Severity:** medium · **Dimensions:** consistency, content-data-schema, creature-behavior-coverage · **Status:** Open: needs a design decision.

**Files:** `docs/ITEMS.md`, `docs/GAME_DESIGN.md`, `docs/CHARACTERS.md`, `docs/ISLANDS.md`, `docs/BESTIARY.md`, `docs/CONTENT_MANIFEST.md`

**Evidence.** The Médico starts with 'Bandages' (GAME_DESIGN.md:155) and there is a 'bandage' recipe (CONTENT_MANIFEST.md:29), but no bandage item. CHARACTERS.md:40 asks for '2 fuel jugs' and ITEMS.md:5 has a 'fuel' tag, but there is no fuel item. Fuel only appears on far chains (ISLANDS.md:187, :248), while El queroseno is at the mid-chain lighthouse (ISLANDS.md:14), so it cannot be finished in chain order. These have no ids: Maestro 'Notebook, pencil', Músico guitar (GAME_DESIGN.md:156-157), Caridad's letter that Rodríguez checks for in inventory (CHARACTERS.md:80), the son's photo (:21), the uncle's watch (:134), raw hutía and iguana, lionfish (BESTIARY.md:205, :217-218), and the stick and torch that counters need (:57, :109, :208). coco_plum (ITEMS.md:31) and hicaco (:47) are the same fruit with the same stats, one known and one unknown. Sea grapes ripe/unripe is not a duplicate, and oars exist as shovel_oar.

**Why it matters.** BackgroundData, RecipeData, CreatureData.loot and quest conditions will reference ids that do not exist, so data entry either fails the validator or invents ids. The identify game cannot tell whether coco_plum is the identified hicaco.

**Suggested fix.** Add the items with manifest ids (bandage, fuel_jug, notebook/guitar or one kit item, caridad_letter, son_photo, uncle_watch, raw hutía and iguana, lionfish, stick, rock, torch), or rewrite the references. Fold coco_plum into hicaco through an identify group. Put a fuel source before the lighthouse. Update the counts.

### 9. Loot and resource quantities have two competing sources and no data type

**Severity:** medium · **Dimensions:** content-data-schema, balance-math · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `docs/ISLANDS.md`, `docs/CONTENT_MANIFEST.md`, `openspec/specs/island-generation/spec.md`, `openspec/specs/endings-progression/spec.md`

**Evidence.** POI rows and the resource-rules table give different numbers. ISLANDS.md:32 palm grove 'Coconuts, 8–12' (random) vs :212 'Coconuts | 10'. endings-progression:46 expects exactly 13 coconuts at level 3, which needs a fixed base. Driftwood is 8 per island (:211) but 6 on the final approach (:199) and ×10 on the shingle beach (:124). Rope is 'Rope 2–4 | Lobster traps +1 each' (:216), mixing POI loot into the budget. Nothing says whether POI loot counts against the budget or adds to it. There is no folder or class for the rules (CONTENT_MANIFEST.md:47-49 covers POIs only). Special mechanics: pick one of three (:183), well 1 cup per 20 s unlimited (:142), 'full after rain' (:123). The Experiencia +1 coconut has nowhere to go on rock/storm islands, where the base is 0.

**Why it matters.** POI data shape is being decided now, and island-generation:49 resource spawning needs one source of truth. Otherwise the generator double-spawns or ignores half the data, and the POI files are redone when a loot type exists.

**Suggested fix.** Define LootEntry (item id or tag, count min/max, chance, condition, refresh trigger) and ResourceNode (capacity, refill rate or trigger, pick-one group). Pick one precedence rule: either the budget is authoritative and POIs draw from it, or POI loot is authoritative and the table is derived. Store the budget in ChainData.

### 10. Dialogue, offline fallback lines and handwritten found-text bodies have no schema

**Severity:** medium · **Dimensions:** content-data-schema, specs-vs-design · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `docs/CONTENT_MANIFEST.md`, `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/endings-progression/spec.md`, `openspec/specs/ai-dialogue-backend/spec.md`, `openspec/changes/project-skeleton/specs/content-data/spec.md`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `CLAUDE.md`

**Evidence.** CONTENT_MANIFEST.md:41 puts minor NPC lines, story beats, 5 endings, 8 quick-chat phrases and 20 death one-liners in one folder, but content-data spec:9-10 requires one type per folder, and manifest :3 names no dialogue class. These are undefined: the 'state' key (npcs-dialogue:25), branching for '1–3 choices' (:17), ending slots (endings-progression:17), the list of causes of death (:89), and the emotion 'fixed set' (ai-dialogue-backend:25) that grunt clips depend on (:49). `profanity: soft|full` exists only for AI lines (ai-dialogue-backend:25), while the toggle in GAME_DESIGN.md:243 covers all lines. No handwritten fallbacks are planned for the 12 AI profiles (CONTENT_MANIFEST.md:37), despite CLAUDE.md:33 and the 100 ms offline scenario (npcs-dialogue:35-38). Handwritten found texts (ITEMS.md:148-153) have no home for their bodies.

**Why it matters.** Content-batch-10 cannot start without a DialogueData shape. The emotion set is a shared client/backend contract. Adding soft variants or emotions after lines are written means touching every line and every pre-generated Chatterbox clip again.

**Suggested fix.** Define DialogueData with a Line sub-resource: speaker, state enum, conditions, emotion enum in DataEnums shared with the backend schema, text per language with an optional soft variant, voice clip ref, choices pointing to next ids, and slot tokens. Give ending scenes, quick-chat UI strings and death lines keyed by a CauseOfDeath enum their own types. Add fallback pools per AI NPC and AI text, and a body pool for handwritten found texts and loading tips.

### 11. Quests are required to be data but have no content type

**Severity:** medium · **Dimensions:** content-data-schema · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/npcs-dialogue/spec.md`, `docs/CONTENT_MANIFEST.md`, `docs/CHARACTERS.md`, `openspec/changes/project-skeleton/design.md`, `TASKS.md`

**Evidence.** npcs-dialogue:41 says 'Quests SHALL be data: steps with conditions (item in inventory, flag set, location reached) and rewards', and :9 gives NpcData a 'quests' field. CONTENT_MANIFEST.md:3-65 has no QuestData and no quests folder, and the content-data spec purpose leaves quests out. CHARACTERS.md defines about a dozen quests whose rewards are item counts, rides, keepsake unlocks, 'Navigation skill +2' and flags (:20-22, :39-41). design.md:39 already expects 'NPC ↔ quest item' references. TASKS.md:96 runs content batches alongside milestones C–E, so batch-6 NPCs could come before the quest schema.

**Why it matters.** Batch-6 would either inline untyped quest dictionaries or leave quests out, and both mean redoing the NPC files. Quest conditions that reference items cannot be validated.

**Suggested fix.** Add QuestData (its own folder or embedded typed sub-resources) with Condition sub-resources (has_item, flag, at_poi, skill_check) and Reward sub-resources (items, flag, keepsake unlock, skill delta, route), and reuse them for route requirements. NpcData references quests by id. Quest items are covered by the missing-items fix.

### 12. creatures/ holds entries that no behavior covers or that are not creatures (passive prey, whale, patrols, jet-ski, smugglers, hurricane, Straits)

**Severity:** medium · **Dimensions:** creature-behavior-coverage, content-data-schema · **Status:** Open: needs a design decision.

**Files:** `docs/CONTENT_MANIFEST.md`, `openspec/specs/creatures-ai/spec.md`, `openspec/specs/guardacostas-stealth/spec.md`, `openspec/specs/weather-daynight/spec.md`, `docs/BESTIARY.md`, `docs/ITEMS.md`, `openspec/changes/project-skeleton/specs/content-data/spec.md`

**Evidence.** CONTENT_MANIFEST.md:10-13 puts sperm_whale, hutia, iguana, pelican, patrol_boat, shore_soldier, jet_ski, smugglers, boss_hurricane and boss_straits in creatures/, and content-data:10 allows one type per folder. These fit none of the 9 behaviors (creatures-ai:17): hutía and iguana are passive and flee (BESTIARY.md:217-218), and the whale is a non-hostile set piece (:211). No spec defines fishing or reeling (pelican :223) or how a snare catches a creature (ITEMS.md:65). Patrol and squad numbers are constants in guardacostas-stealth (:9, :17, :41), with no behavior id or data fields. The jet-ski (BESTIARY.md:230, spots swimmers by day) and smugglers (:231, carry or rob 50/50) appear in no spec. creatures-ai:41 hands the hurricane and the Straits to weather-daynight and crossing, yet both count toward '40 creatures' (:7, :69), and weather/ also has 'hurricane' (:65).

**Why it matters.** Content-batch-2 cannot give these files a valid behavior id: the validator must accept empty ids or someone invents machines outside any spec. Two CreatureData files would carry meaningless health, speed and domain values.

**Suggested fix.** Remove boss_hurricane and boss_straits from creatures/. Add passive_flee (with a cornered bite) and ambient behaviors. Specify fishing/reeling and snare capture. Decide patrol ownership: a PatrolData type owned by guardacostas-stealth, or patrol_route and squad_search behaviors with params. Add a jet-ski requirement covering daytime spotting. Model smugglers as an encounter or route. Have the validator reject unknown behavior ids.

### 13. Weather resources mix the five exclusive states with multi-day and overlapping events that weather-daynight cannot run

**Severity:** medium · **Dimensions:** specs-vs-design, content-data-schema · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/weather-daynight/spec.md`, `docs/CONTENT_MANIFEST.md`, `docs/BESTIARY.md`, `docs/GAME_DESIGN.md`

**Evidence.** weather-daynight:17 says the manager 'SHALL hold one of' five states, rolled per phase. CONTENT_MANIFEST.md:65 has 11 weather files that also include events: red tide 'for two days' (BESTIARY.md:238), king tide on a 'full moon' (:239, and no moon cycle exists), heat dome 'Three days' (:240), and lightning and waterspout during squalls. None of the six added events appears in any spec. GAME_DESIGN.md:69 makes a squall a '2-minute storm', but weather rolls per phase and phases last up to 5 minutes. The manifest list also drops rip current and scorching noon.

**Why it matters.** weather-daynight is a Milestone A change. A WeatherData built only for states forces rework when the event files arrive in batch-7.

**Suggested fix.** Give WeatherData a kind (state or event) with duration, trigger and the states it can occur during. Drop 'full moon' or add a moon cycle. Define what holds after a squall ends inside a phase. Reconcile the 11-entry list with BESTIARY.

### 14. Escape routes: ISLANDS uses routes outside the 8 route resources, repair-wreck is defined two ways, and RouteData fields are undefined

**Severity:** medium · **Dimensions:** consistency, specs-vs-design, content-data-schema · **Status:** Addressed by the project-skeleton data model (typed effects, conditions, spawn rules, quests, dialogue, weather and route parts). Check the choices it made in openspec/changes/project-skeleton/data-model-questions.md.

**Files:** `openspec/specs/escape-routes/spec.md`, `openspec/specs/crossing/spec.md`, `openspec/specs/island-generation/spec.md`, `docs/ISLANDS.md`, `docs/GAME_DESIGN.md`, `docs/CHARACTERS.md`, `docs/BESTIARY.md`, `docs/CONTENT_MANIFEST.md`

**Evidence.** escape-routes:17 fixes 8 routes. ISLANDS.md adds Ramón's boat (:60; 3 seats per CHARACTERS.md:22, unlike signal-boat's 'Everyone'), the family's boat (:168), the patrol dinghy 'Steal it (escape route...)' (:227), and smugglers who 'will carry you' (BESTIARY.md:231). Repair-wreck is 'Boat in mangroves + nails, resin, oars or fuel' (GAME_DESIGN.md:108) but 'Repair the boat with the engine (boss)' on the shipwreck reef (ISLANDS.md:189). The final approach says 'Cross. That is the only route' (:201), against island-generation:41's 2–3 routes. escape-routes:9 gives capacity as 'int or "all"' (a Variant, against static typing). 'Risk profile' is never defined, though crossing:9 rolls threats from it. The requirement kinds listed at :9 omit the energy ≥ 100 and time-window requirements used at :33. 'Routes are POIs with a flag' (ISLANDS.md:5) sits beside a separate RouteData type.

**Why it matters.** RouteData is defined in the current skeleton change. The extra routes either get hard-coded or disappear, and the crossing has nothing defined to read for risk.

**Suggested fix.** Make capacity a mode enum (fixed, all, per_swimmer, vessel) plus an int. Add a RiskProfile sub-resource and shared Condition requirements (meter, status, weather set, phase window, item, flag, skill). Model a generic boat route with per-POI requirements and capacity, and define repair-wreck the same way. Link POIs to routes with a POI.route_id pointing at RouteData. Exempt the final approach from the 2–3 rule. Add the new ids to the manifest and the spec.

### 15. Host-authoritative movement with 20 Hz sync and no prediction or interpolation, decided before player-movement is built

**Severity:** medium · **Dimensions:** architecture, export-platform-input-ui-shell · **Status:** Decided 2026-11-05: host authority with client prediction and reconciliation, driven by MoveIntent (CLAUDE.md). Implemented in coop-networking.

**Files:** `CLAUDE.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/player-movement/spec.md`, `TASKS.md`

**Evidence.** CLAUDE.md:24 says 'Never trust client-reported positions'. coop-networking:17 has clients send intents by RPC while MultiplayerSynchronizer replicates positions at 20 Hz. No spec mentions prediction, reconciliation or interpolation, and MultiplayerSynchronizer provides none. Players join by IP over the internet (coop-networking:9; Steam/relay is post-v1, TASKS.md:94). At 6 tiles/s × 16 px / 20 Hz, a sprite jumps 4.8 px per update, about 14 screen px at 3× scale. The local-only co-op test rule (CLAUDE.md:45) hides latency. TASKS.md:34-35 builds player-movement before coop-networking.

**Why it matters.** Each client's own character would move a full round trip late, in a game about dodging sharks and 2 s searchlight timers. The authority model shapes the player scene, the synchronizer and the RPCs in the first Milestone A changes.

**Suggested fix.** Decide in coop-networking before player-movement. One option is client-owned avatar position with host plausibility checks (speed cap, terrain, teleport rejection). The other is host authority with client prediction and reconciliation. Either way, interpolate remote entities, add an RTT-budget scenario (for example, playable at 150 ms), amend CLAUDE.md:24, and drive movement from an input object rather than polling Input in _physics_process.

### 16. Split parties require the host to run several islands and a crossing at once, but networking, weather and scene specs assume one live island

**Severity:** medium · **Dimensions:** specs-vs-design, architecture · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/escape-routes/spec.md`, `openspec/specs/crossing/spec.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/weather-daynight/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/GAME_DESIGN.md`, `TASKS.md`

**Evidence.** escape-routes:41 and :46 keep the old island active while players who already crossed 'can survive' on the next island. crossing:9 makes the crossing its own scene, so up to three spaces are live on the host. GAME_DESIGN.md:116 says 4-player parties 'often' split. coop-networking:14 sends a joiner 'the island seed' (singular) and nothing scopes state per island. weather-daynight:17 holds one state with chain-based weights. endings-progression:9 lets routes lead to different chains, and crossing:25 overshoot 'skips to a harder chain', so the halves can diverge with no reunion rule. coop-networking is built in Milestone A; binoculars-swim (one route per swimmer) arrives in Milestone B.

**Why it matters.** Supporting more than one live level shapes the scene tree, the spawners, synchronizer visibility and WeatherManager. Retrofitting it after Milestone A means reworking all of those.

**Suggested fix.** Decide in coop-networking: either one active level with a waiting state for arrivals, or several Level containers (offset in one World2D, or SubViewports) with per-peer visibility via set_visibility_for. WeatherManager would route to per-level state. Forbid split groups from taking different branches, or define how they reunite. Alternatively, cut simultaneous split play from v1 and say so.

### 17. The RPC convention @rpc("any_peer", "call_local") leaves out the rules that make host authority hold

**Severity:** medium · **Dimensions:** architecture · **Status:** Open: needs a design decision.

**Files:** `CLAUDE.md`, `openspec/specs/coop-networking/spec.md`

**Evidence.** CLAUDE.md:24 gives only the annotation. coop-networking:17-22 has one validation scenario, which checks distance. Calling .rpc() on such a method runs it locally and broadcasts it to every peer (SceneMultiplayer.server_relay defaults to true). Nothing requires an is_server() guard or a check that get_remote_sender_id() owns the node the intent targets, so peer 3 can act as peer 2 near an item and pass the distance check. When the host calls locally, the sender id is 1 (scene_rpc_interface.cpp set_remote_sender_override). The annotation itself is the one Godot recommends for a listen server; the gap is the missing rules around it.

**Why it matters.** Coding agents follow CLAUDE.md literally. Desync and impersonation bugs would be built into every intent handler from the first networking change.

**Suggested fix.** Rewrite the convention: send intents with rpc_id(1, ...); start every intent handler with `if not multiplayer.is_server(): return`; resolve the acting player from get_remote_sender_id() mapped to that peer's node, never from an argument; use authority mode for host-to-client RPCs; add per-peer rate limits. Add a coop-networking scenario in which the host rejects an intent naming another player's node.

### 18. Survival meters: the in-game clock is undefined, drain rates are about 5–10× too slow for the run length, sunstroke can never trigger, and heat runs in opposite directions

**Severity:** medium · **Dimensions:** consistency, specs-vs-design, balance-math, content-data-schema · **Status:** Decided 2026-11-05: heat rises 0 to 100 with sunstroke at 100 (GAME_DESIGN §4 updated); drains are retuned in survival-meters so thirst empties in about 1-1.5 in-game days.

**Files:** `docs/GAME_DESIGN.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/weather-daynight/spec.md`, `openspec/specs/escape-routes/spec.md`, `docs/ITEMS.md`, `docs/BESTIARY.md`, `docs/CHARACTERS.md`, `HANDOFF.md`, `TASKS.md`

**Evidence.** weather-daynight:9 defines a day as 12 real minutes (1/5/1/5) but never maps that to clock time. Other specs still use clock hours: heat between 'in-game 10:00 and 16:00' (survival-meters:33), still '1 per 2 in-game hours' (ITEMS.md:13), 'Heat ×2 for 2 hours in-game' (BESTIARY.md:186), 'first hour after dusk' (escape-routes:33). Thirst at 1/min (GAME_DESIGN.md:50, survival-meters:17) with night ×0.5 drains about 14.5 per day, so 100 thirst lasts about 83–126 min, longer than a 60–90 min run (GAME_DESIGN.md:20). That contradicts 'Thirst is the main pressure' (:46), and the 3-day sandbar target (HANDOFF.md:65) needs no water. The heat window is about 3 real minutes, giving roughly +6 per day (+12 in scorching calm) with a nightly reset, so sunstroke at 100 is unreachable. At 24 h per 12 min, a still gives +40 thirst per real minute. GAME_DESIGN.md:52 runs heat 100 (cool) → 0 with sunstroke at 0, while survival-meters:33 has heat rising to sunstroke at 100, and :9 defers to §4. Morale differs only in threshold: 0 vs <20 (:49). Multi-day quests (CHARACTERS.md:39, :144) do not fit about 8–15 min per island. HANDOFF.md:65 calls the drain numbers first guesses, but the units, clock and direction are not tuning questions.

**Why it matters.** SurvivalMeters, the HUD and weather-daynight are Milestone A. GUT tests and the playtest would be built on contradictory units and directions, and that playtest would tell you nothing about the core pressure loop.

**Suggested fix.** Define the clock in weather-daynight: ratio, the clock time at dawn, and phase boundaries. Require one duration unit in data (an _s or _gmin suffix). Size drains so thirst empties in about 1–1.5 days. Rescale the still, well and heat to real time. Adopt heat rising 0→100 and update §4 and the morale threshold. Express wearables as gain multipliers. Fit quests to about one day per island, and restate the playtest target.

### 19. Swimming drains 100 energy in 33 s against a 60–120 s crossing, and two specs disagree on what happens at 0 energy in water

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/player-movement/spec.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/crossing/spec.md`, `openspec/specs/escape-routes/spec.md`, `openspec/specs/crafting-inventory/spec.md`, `docs/ITEMS.md`, `docs/GAME_DESIGN.md`, `TASKS.md`

**Evidence.** Swimming drains 3 energy/s (player-movement:17, survival-meters:41), so 100 energy lasts 33 s, or 16.7 s when carrying over 15 weight (crafting-inventory:17). Crossings last 60–120 s (crossing:4) and list swimmers as a vessel (:9). Below 20 energy sharks strike (crossing:41), which happens after about 27 s. binoculars-swim requires energy ≥ 100 (escape-routes:33) and is in Milestone B (TASKS.md:44). At 0 energy, player-movement:17 says the player floats and drifts, crossing:17 says 'swim the remainder ... or drown', and ITEMS.md:97's life vest 'Float at 0 energy' implies floating is not the default. A teammate can still pull a fallen player aboard (crossing:41), and dolphins keep sharks away (CHARACTERS.md:148).

**Why it matters.** The Swimmer component in Milestone A must choose float or drown, and the binoculars-swim route in Milestone B cannot be completed as written.

**Suggested fix.** Give crossing its own swim drain (about 0.6/s), a shorter swim crossing, or a dolphin tow. Let player-movement alone own the 0-energy-in-water rule (float, or drown after N s) with the life vest as the exception. Add a scenario: binoculars-swim at 100 energy completes a 60 s crossing.

### 20. Input is only 'WASD/left stick' plus one overloaded interact button; most player verbs have no action, and hold durations contradict

**Severity:** medium · **Dimensions:** export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/player-movement/spec.md`, `game/project.godot`, `openspec/specs/creatures-ai/spec.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/coop-networking/spec.md`, `docs/CHARACTERS.md`, `docs/GAME_DESIGN.md`, `docs/BESTIARY.md`

**Evidence.** player-movement:9 'WASD/left stick'. :25 uses one interact for pick up, talk, use and climb, with a 2 s hold for timed actions, while its own drag scenario (:27-30) is a hold that lasts until release. project.godot defines no gameplay InputMap actions. These verbs have no action or aim model: throw (creatures-ai:25 thrown fish decoy), weapon hits (:33), giving a cup to a downed teammate (survival-meters:57), inventory, map and crafting, radial quick chat (coop-networking:49), and 'mash to escape' (BESTIARY.md:79). Tap versus hold on a downed teammate is ambiguous. Cutting a net takes 2 s (player-movement:25) but 30 s with sharks arriving at 20 s (CHARACTERS.md:144). The shipwreck intro is the only tutorial (GAME_DESIGN.md:208) and has no spec.

**Why it matters.** player-movement is the next change. Action names, tap/hold rules and the held-item model decide the shape of the client intent RPCs, and getting them wrong reworks both input and networking code.

**Suggested fix.** In player-movement, list named InputMap actions with keyboard/mouse and gamepad defaults, an aim model, and a held or selected item (hotbar). Make hold duration a per-interactable field (default 2 s, net 30 s, interruptible) and separate channel actions from sustain actions. Commit the actions to project.godot. Spec the shipwreck intro and the controls it teaches.

### 21. Kenney art is git-ignored and fetched by an unpinned scraper, so CI and release builds have no art and the first sprite breaks build-verification

**Severity:** medium · **Dimensions:** setup-tooling, export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `.gitignore`, `tools/fetch_assets.py`, `docs/ASSETS.md`, `game/assets/CREDITS.md`, `openspec/changes/project-skeleton/specs/build-verification/spec.md`, `openspec/changes/project-skeleton/design.md`, `game/tests/smoke.gd`

**Evidence.** .gitignore:9-13 ignores game/assets/kenney/, oga/, itch/ and audio/ambience/. The last three are manual downloads (ASSETS.md:13, :17; freesound needs a login), so the 're-fetchable' comment is wrong and those packs exist on one machine only. build-verification:57-63 requires smoke and tests to pass with no packs present. design.md:60 mitigates this only for the skeleton, while ASSETS.md:11-15 make Kenney the Priority 1 source for the first playable. fetch_assets.py:56-63 scrapes data-download-id with no version or hash, and :86-88 skips folders that already exist. Kenney has remade packs under the same slug (UI Pack 2.0). The .import sidecars, which hold UIDs, are ignored too. Fonts are already committed with their .import files, which sets a precedent. A missing ext_resource fails to load and the smoke run exits 1.

**Why it matters.** The first Milestone A scene with a sprite will either break the CI smoke run or break the spec. No release can be reproduced from the repo, and UIDs drift between machines.

**Suggested fix.** Before player-movement, commit the CC0 subset you actually use, with its .import files, in a tracked folder (as with the fonts). Alternatively, pin each pack with a SHA-256 and a mirror URL and fetch it in CI. Never ignore manually downloaded packs. Reword the build-verification requirement to match. Check itch and OpenGameArt licenses before committing them, since the repo is public.

### 22. Asset docs do not match the packs: characters are 16×16 single frames, not 32×32 walk cycles, two listed packs return 404, and destinations differ

**Severity:** medium · **Dimensions:** setup-tooling, legal-content · **Status:** Decided 2026-11-05: characters are 16×16 (Kenney CC0 bases) for now; CLAUDE.md and ASSETS.md updated.

**Files:** `docs/ASSETS.md`, `CLAUDE.md`, `README.md`, `tools/fetch_assets.py`

**Evidence.** CLAUDE.md:26 and ASSETS.md:3, :11 call for '32×32 characters, 4-direction walk' from Kenney Roguelike Characters / Tiny Dungeon. The fetched sheets say 'TILE SIZE: 16 x 16' (spritesheetInfo.txt) and Tiny Dungeon has 132 single 16×16 frames; Roguelike Characters is a paper-doll kit with no walk frames. ASSETS.md:12 'Pixel Platformer Industrial' and :14 'Roguelike Items' return 404 on kenney.nl and are not in fetch_assets.py PACKS. Generic Items is not pixel art. ASSETS.md:18 sends SFX to assets/audio/sfx/, but the script writes kenney/audio_sfx/. README.md:118 promises Quaternius and Mixamo downloads, while ASSETS.md:35 says to skip them. The legal-content claims about a `roguelike-items` slug and a .zip regex are stale against HEAD.

**Why it matters.** Character size drives collision shapes, sprite offsets, animation frames and camera scale in player-movement. Building to the wrong size means rework, and no task covers making or commissioning a walking player.

**Suggested fix.** Decide character size before player-movement: scale the 16×16 bases, change the convention, or schedule custom 32×32 walk art. Update CLAUDE.md:26 and ASSETS.md:11. Remove the 404 packs, align destinations with the script, and rewrite README §7.

### 23. No spec or task owns the player-facing shell: title, host/join lobby, run setup, HUD layout, inventory and map screens

**Severity:** medium · **Dimensions:** export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `game/scenes/main/main.gd`, `openspec/project.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/endings-progression/spec.md`, `openspec/specs/escape-routes/spec.md`, `openspec/specs/survival-meters/spec.md`, `openspec/changes/project-skeleton/design.md`, `docs/GAME_DESIGN.md`, `README.md`, `TASKS.md`

**Evidence.** main.gd:2 says 'Menus and the run start arrive with later changes', and no such change exists. project.md:50 lists 13 capabilities and none is UI; skeleton design.md:24 excludes UI. Each capability names its own screen: host/join (coop-networking:9), host lost (:33), background pick (GAME_DESIGN.md:149), keepsake choice (endings-progression:25), Experiencia spend (:57), seed and daily runs (:73), challenges (:81), branch choice (:9), island map (escape-routes:49). Nothing owns the flow between them or a HUD budget for 6 meters, 12 slots, teammate status and phase/weather at 640×360; survival-meters:13 only says the client 'draws its meters'. README.md:160 documents `--host` / `--join 127.0.0.1` flags that no spec defines.

**Why it matters.** coop-networking, the second Milestone A change, needs a host/join entry. Per-player run setup has to happen before the host generates the island, which shapes the handshake. HUD space is tight enough that per-feature widgets will collide.

**Suggested fix.** Add a ui-shell capability before coop-networking covering: screen flow (title, host/join, run-setup lobby, intro, run, summary), per-player choices versus host settings, a 640×360 HUD budget, inventory, crafting and map screens, the host-lost screen and loading screens. Define the CLI flags as a dev-only path or remove them from the README.

### 24. Session lifecycle is undefined: no pause rule, no rule for panels open during real-time co-op, no decision on saving a 60–90 minute run

**Severity:** medium · **Dimensions:** export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/weather-daynight/spec.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/endings-progression/spec.md`

**Evidence.** Play is real-time with 60–90 min runs (GAME_DESIGN.md:19-20). Solo runs the same code path as co-op (coop-networking:9). In dialogue 'the player who talks drives; others see the text' (npcs-dialogue:17), and found texts open a reading panel (:57). Timers run in real time: 12-minute day (weather-daynight:9), 90 s downed (survival-meters:57), 3-minute patrols (guardacostas-stealth:9). A search finds no pause, save, resume or quit rule anywhere. The profile is written only on death or win (endings-progression:41, :49), so quitting mid-run to dodge a death is undefined. Late joining already requires full entity state (coop-networking:12-15).

**Why it matters.** Whether runs can be saved decides whether every component must be serializable from the first gameplay change. Whether the player is vulnerable while a panel is open affects every system's timers.

**Suggested fix.** Add one session requirement: solo pause freezes the simulation; co-op has no pause or the host pauses everyone; which panels are modal and whether the player is vulnerable while one is open; save-and-quit at island arrival, or an explicit 'no mid-run saves in v1'; what quitting does to Experiencia. If saves are in scope, require serialize/deserialize on each component from the first gameplay change.

### 25. Setup docs are stale: Godot 4.4+ vs the 4.7 the skeleton needs, wrong autoload names and layout, wrong Node/Python floors, wrong repo URL, 'empty repo' state

**Severity:** medium · **Dimensions:** project-skeleton-code-tests-ci, consistency, setup-tooling · **Status:** Fixed in 481c7c2.

**Files:** `CLAUDE.md`, `README.md`, `HANDOFF.md`, `START.md`, `TASKS.md`, `openspec/project.md`, `docs/GAME_DESIGN.md`, `game/project.godot`, `.github/workflows/ci.yml`

**Evidence.** 'Godot 4.4+' appears at CLAUDE.md:18, README.md:27, HANDOFF.md:30, START.md:19, TASKS.md:7, project.md:9 and GAME_DESIGN.md:17. But project.godot:11 declares 4.7, ci.yml pins 4.7.2, GUT versions.json sets godot_min 4.7, and smoke.gd uses Logger/ScriptBacktrace (4.5+). HANDOFF.md:23 and START.md:17 still say nothing is coded. README.md:137 lists autoloads 'TurnlessGameState, WeatherManager, NetManager' against the five in CLAUDE.md:22, and TASKS.md:29 says 'Folder layout from README' (skeleton proposal.md:15 plans the fix); the README layout also omits scripts/core/. README.md:29 Node 20.19+ vs OpenSpec 1.16 engines >=22.12. README.md:30 Python 3.11+ vs Lambda 3.12 (CLAUDE.md:38). SAM CLI is not listed. README.md:39-40 clones '<you>/90-millas.git'. HANDOFF.md:35 and TASKS.md:14 say to git init and create the repo, which already exists as onezoftserv/90miles. README.md:43 opens game/project.godot at step 1. README §8 references deploy.sh and .env.example, which are Milestone F.

**Why it matters.** A developer or agent following these docs installs a Godot version that cannot run the gate, fails OpenSpec setup, or tries to recreate the repo. Later sessions are told the repo is empty.

**Suggested fix.** Do one doc pass: 'Godot 4.7.2 exact' everywhere, updating ci.yml GODOT_VERSION and SHA together; update the state lines; build the README layout from CLAUDE.md, including scripts/core/ and tests/; Node 22.12+, Python 3.12 and SAM CLI in prerequisites; the real clone URL; replace the git init steps with clone/verify; mark README §8 as Milestone F.

### 26. MCP setup installs an archived GitHub server and a superseded AWS server, omits uv, and gives the agent write access with the developer's credentials

**Severity:** medium · **Dimensions:** setup-tooling · **Status:** Fixed in 481c7c2 (setup docs).

**Files:** `README.md`, `TASKS.md`, `HANDOFF.md`

**Evidence.** README.md:101 runs `uvx awslabs.aws-api-mcp-server@latest`. That server's README says it is superseded by the official AWS MCP server, documents a different Windows form (`uvx --from ... awslabs.aws-api-mcp-server.exe`), and defaults READ_OPERATIONS_ONLY to false. README.md:103 uses @modelcontextprotocol/server-github, archived 2025-05-29 and deprecated on npm. README.md:106 and TASKS.md:13 export GITHUB_PERSONAL_ACCESS_TOKEN and AWS_PROFILE in the shell. uv is missing from the prerequisites (README.md:23-32).

**Why it matters.** New setups get unmaintained servers, and an agent running with the developer's default profile can make mutating AWS calls such as IAM changes or delete-stack.

**Suggested fix.** Use gh or the official remote GitHub MCP with a fine-grained PAT scoped to the repo. Use the official AWS MCP Server, or at least READ_OPERATIONS_ONLY=true with a least-privilege project profile. Add uv to the prerequisites and keep tokens out of shell profiles.

### 27. Co-op resource scaling shrinks total supply as the party grows, and the 'always buildable' raft cannot be built from the sandbar's listed materials

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/coop-networking/spec.md`, `openspec/specs/island-generation/spec.md`, `docs/ISLANDS.md`, `docs/GAME_DESIGN.md`, `openspec/specs/crossing/spec.md`

**Evidence.** coop-networking:41 multiplies resource spawns by 0.8 per extra player, and its scenario at :46 fixes ×0.64 for 3 players, so per-head supply is 40%, 21% and 12.8% of solo for 2–4 players. island-generation:41 promises an 'always-buildable route (raft)' of 6 driftwood, 2 tubes and 3 rope (GAME_DESIGN.md:95, :107). Driftwood falls from 8 to 5.1 (3 players) and 4.1 (4 players). The sandbar's only rope is the flotsam line's ×1 (ISLANDS.md:33), while the rules say 'Rope 2–4' (:216), so even solo can fall short. ISLANDS.md:211 scales only driftwood, against the spec's blanket rule. Validation checks reachability, not buildability (island-generation:65). Mitigations exist: squalls add 4 driftwood and refresh flotsam, the hut has 2 planks, the raft carries over (crossing:49), and the swim route needs no binoculars. So island 1 is slow, not unwinnable.

**Why it matters.** Co-op gets harder than solo instead of the reverse, and the ×0.64 scenario would be locked into a GUT test.

**Suggested fix.** Scale per-head consumables up sublinearly (for example ×(1 + 0.6(n−1))). Never scale route-critical inputs below one full recipe. Guarantee raft inputs on the sandbar. State which resources scale and whether POI loot does. Add a buildability check to generator validation. Rewrite the ×0.64 scenario.

### 28. Specs depend on backgrounds and skill levels nobody defines (no XP curve, a 'Combat' skill that doesn't exist), and profile.cfg has no schema or co-op trust model

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math, consistency, creature-behavior-coverage, export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `openspec/project.md`, `openspec/specs/survival-meters/spec.md`, `openspec/specs/crossing/spec.md`, `openspec/specs/escape-routes/spec.md`, `openspec/specs/guardacostas-stealth/spec.md`, `openspec/specs/crafting-inventory/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/GAME_DESIGN.md`, `docs/BESTIARY.md`, `CLAUDE.md`, `TASKS.md`

**Evidence.** Specs branch on background or skill: Pescador (survival-meters:25), Músico (:49), Maestro (crossing:25), 'A Mecánico builds at 2×' (escape-routes:25), '+1 s per level (max +3)' (guardacostas-stealth:25), skill multiplier (crafting-inventory:25). No capability defines XP sources, level thresholds or per-level effects (project.md:50). endings-progression:49 persists 'skill XP' capped at level 3, and GAME_DESIGN.md:224 caps skills at 5 and 3. BESTIARY.md:67 gates on 'Combat ≥2', but the skill list (GAME_DESIGN.md:214) has no combat; Ex-militar has 'Stealth and combat' (:158). Backgrounds arrive in Milestone E (TASKS.md:75), after the A/B/D specs that use them. user://profile.cfg has no schema or version, and the co-op owner of carried XP and trust is undefined (keepsakes, levels and points are per-player at :25, :41, :57). Run-start perks come from each client's local profile, so the host must accept a client-reported loadout, against CLAUDE.md:24.

**Why it matters.** Meters, routes and stealth would hard-code skill numbers with no owner. Experiencia carry-over cannot be implemented without an XP model, and saves break on the first schema change.

**Suggested fix.** Add a backgrounds-skills capability (starting items, XP sources, thresholds, caps, per-level effects). Resolve Combat, either as a skill or mapped to Ex-militar stealth. Define profile.cfg schema and version and per-player vs host ownership. Have the host validate a run-start loadout against the catalog and caps, and accept local-profile edits as a friends-only cheat.

### 29. The crossing model doesn't close: unsteered drift always overshoots, vessel speed and base duration are undefined, and raft integrity mixes percent and points with no repair cost

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/crossing/spec.md`, `openspec/specs/crafting-inventory/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/BESTIARY.md`, `docs/ITEMS.md`, `docs/GAME_DESIGN.md`, `docs/ISLANDS.md`

**Evidence.** crossing:25 sets drift at 1 tile/s, adds 30 s per 10 tiles, and overshoots at 40 tiles. Every unsteered mid or far crossing therefore overshoots at t=40 s, before the 60 s minimum (crossing:4), and at 3 s per tile an unsteered crossing never finishes on its own. Only a Maestro or compass+charts can steer, and the charts come from the mid-chain lighthouse (ISLANDS.md:141, :147). 'Skips to a harder chain' is not an edge in the branch graph (endings-progression:9). Vessel speed is undefined although the cutter follows at '1.5× raft speed' (BESTIARY.md:177), and there is no base duration per band. Integrity is a percent in crafting-inventory:41 and :46 ('25% per crossing') but points in crossing:17 (raft 100, boat 200, squall −30, no wear). BESTIARY mixes both ('−30%' :185, '−10' :211). Hardwood is +50 (ITEMS.md:80) and Nudo +25% (:131), so units diverge for boats and upgraded rafts. Repair has no cost (GAME_DESIGN.md:99), and a raft is reusable on arrival (crossing:49).

**Why it matters.** The crossing (Milestone B) and the Gulf Stream route (Milestone C) would ship with guaranteed chain skips that break the 6–8 island structure. The integrity unit spreads into many .tres files.

**Suggested fix.** In crossing, define a base duration per band and a vessel speed. Model drift as a capped lateral offset that does not feed duration. Make overshoot a defined branch transition. Make crossing the single owner of integrity in points, with flat wear applied on arrival. Price raft_repair, and decide whether rafts carry over.

### 30. Capture rules contradict each other and leave cases unhandled; getting caught on purpose skips crossings and the coast boss

**Severity:** medium · **Dimensions:** consistency, specs-vs-design, balance-math · **Status:** Decided 2026-11-05: in the solo-play change, one capture outcome for every party size, and a solo player is a party of one: `la_captura`, then the persuasion check; on failure the party restarts the previous island, regenerated from the run seed, with its inventory minus fire sources and keepsakes always kept. On island 1 the party restarts island 1 the same way. A whole-party capture on the final crossing ends the run with Devuelto (no check). Still to settle in the guardacostas-stealth build: a per-run release limit, capture at sea, a partial captive rejoining the party, Marisol and the letter, companions during capture.

**Files:** `openspec/specs/guardacostas-stealth/spec.md`, `openspec/specs/crossing/spec.md`, `docs/GAME_DESIGN.md`, `docs/BESTIARY.md`, `docs/CHARACTERS.md`, `docs/ISLANDS.md`

**Evidence.** guardacostas-stealth:57: when everyone is captured, la_captura plays; persuasion (morale ≥ 60 and a Maestro or Médico) releases the party at the next cay; otherwise the party restarts the previous island 'inventory intact minus fire sources'. GAME_DESIGN.md:143 says 'a solo player loses their items'. The sandbar has a patrol every 3 minutes (ISLANDS.md:40) but no previous island. The check is fixed, has no per-run limit and no cost. A daytime fire within 6 tiles of the shore triggers spotting (:33) and the squad goes to the fire first (:41), so capture on purpose is easy; and with BESTIARY.md:177 'Caught = La captura', the coast boss has no fail state. The crossing spec gives no outcome for capture at sea (crossing:37-38). A lone co-op captive respawns on the previous island apart from the party, with no rejoin rule. Marisol's release (CHARACTERS.md:104) and the letter pass (:80) are in no spec. Whether 'previous island' is regenerated from the seed or restored with entity state is undefined.

**Why it matters.** The guardacostas-stealth change (Milestone D) needs one capture state machine. Without it, the solo outcome is ambiguous, island 1 has no target, and capture becomes a free escape route.

**Suggested fix.** Write one capture-outcome table covering solo, party, partial, at sea and island 1. Make release once per run and probabilistic, with a real cost, on the same island. Define the island-1 fallback. Return a partial captive on the party's next island. Add the Marisol and letter rules. Define how entity state is restored.

### 31. The searchlight's 2 s dwell equals the spot timer, so any stealth level makes a player standing still in the open unspottable

**Severity:** medium · **Dimensions:** architecture, specs-vs-design · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/guardacostas-stealth/spec.md`, `openspec/specs/crossing/spec.md`, `docs/GAME_DESIGN.md`

**Evidence.** guardacostas-stealth:17: a 60° cone sweeping 30°/s spots a player after 2 s, and one uniform pass lights a stationary point for exactly 60/30 = 2.0 s, so the :21 scenario sits on the boundary. :25 adds +1 s per stealth level, so stealth ≥1 is never spotted on a single pass. Oscillating sweeps near turnarounds and the boat's movement change this, but the sweep pattern and whether the timer resets or accumulates are unspecified. Area2D cones (GAME_DESIGN.md:271) ignore walls and no line-of-sight check is specified. crossing:37 reuses the 2 s rule.

**Why it matters.** Stealth XP carries over between runs, so progression quietly removes the searchlight, the main threat on the first islands, and detection depends on floating-point edge behavior.

**Suggested fix.** Use an accumulating spot meter that decays slowly between passes, or slow the sweep (about 15°/s), or let the beam pause on a suspicious target. Specify the sweep pattern, check line of sight with a raycast or scripts/fov.gd, and scale stealth as a percentage of the timer. Add a scenario for a stealth-1 player standing still.

### 32. The final crossing (the Straits boss) has no owning requirement, and its patrol is excluded by the crossing event list

**Severity:** medium · **Dimensions:** specs-vs-design, creature-behavior-coverage, consistency · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/crossing/spec.md`, `openspec/specs/creatures-ai/spec.md`, `openspec/specs/guardacostas-stealth/spec.md`, `docs/ISLANDS.md`, `docs/BESTIARY.md`

**Evidence.** creatures-ai:41 says the Straits is a weather boss owned by crossing, but crossing has no Straits requirement. ISLANDS.md:203 describes the sequence: a squall at the halfway mark, one last patrol or the Miami fisherman, sharks following blood. guardacostas-stealth:65 requires 'the final crossing exactly one' patrol, but crossing:33 allows only 'searchlight (coast only)' and lists no patrol event. crossing:33 does already list the final-only lighthouse beam and fisherman.

**Why it matters.** The run's final boss has no spec, and the Devuelto ending depends on a capture during this crossing that cannot happen.

**Suggested fix.** Add a 'Final crossing' requirement to crossing that lists its scripted events in order. Allow the final-crossing patrol, model the Straits as crossing or route profile data, and define capture there so it sets a captured_final flag.

### 33. Ending selection cannot be computed from the flags the specs emit: common co-op outcomes match no ending, Solo never plays solo, and Devuelto is unreachable

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math · **Status:** Decided 2026-11-05: in the solo-play change, survivors are the players and companions who reach land; order `devuelto` → `el_nino` → `solo` (exactly one survivor, any party size) → `todos` (at least one companion met, every met companion and NPC ally alive) → `los_que_llegamos` (any other outcome), so every cell has one ending. Yunior's death no longer selects Solo. Devuelto ends the run as a loss: it counts as a death (+1 Experiencia level, 50% carry-over) and unlocks its keepsake. Still needed: the final-crossing patrol (item 32), the met and left-behind flags in npcs-dialogue, and the Devuelto keepsake's name.

**Files:** `openspec/specs/endings-progression/spec.md`, `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/guardacostas-stealth/spec.md`, `openspec/specs/crossing/spec.md`, `docs/CHARACTERS.md`, `docs/GAME_DESIGN.md`

**Evidence.** endings-progression:17 checks, 'On reaching land', in order: devuelto → el_nino → todos (all met companions and NPC allies alive) → los_que_llegamos (party alive, some companions lost) → solo (one survivor). Devuelto (captured on the final crossing) cannot occur: capture never ends a run (guardacostas-stealth:57) and the final crossing has no capture path (crossing:33). todos ignores dead players. With 2 of 4 survivors and a companion lost, no ending matches. In single-player los_que_llegamos outranks solo. npcs-dialogue:65 has no met, left-behind or captured flags, though :54 sets a left-behind flag. 'NPC allies' is undefined. CHARACTERS.md:63 says Yunior's death unlocks Solo 'even if others survived', which contradicts 'one survivor'.

**Why it matters.** The flag producers (NPC/companion code) and the five ending scenes in Milestone E cannot be written or tested against this, and a keepsake is gated on the unreachable ending.

**Suggested fix.** Write a decision table over explicit flags (companion_<id>_met/_alive/_left_behind, captured_final, yunior_dead, living and total players) with exactly one ending per cell. Trigger Devuelto from the final-crossing capture. Add every flag to npcs-dialogue:65. Define Solo by human-player count, and settle the Yunior rule.

### 34. Experiencia carry-over contradicts other specs: plant-ID scope, easing formula and totals, co-op death, and uncapped permanent boosts

**Severity:** medium · **Dimensions:** specs-vs-design, balance-math, legal-content, consistency · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/endings-progression/spec.md`, `openspec/specs/crafting-inventory/spec.md`, `openspec/specs/survival-meters/spec.md`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `docs/BESTIARY.md`

**Evidence.** crafting-inventory:33 says identification is 'party-wide and run-scoped', but endings-progression:49 and :54 persist every plant identification, GAME_DESIGN.md:215 says 'forever' and ITEMS.md:39 agrees, while BESTIARY.md:141 says 'once per run'. Easing: spec :41 '×0.97 (compounding, min ×0.76)', but 0.97^8 = 0.784 so the floor is unreachable; GAME_DESIGN.md:226's '−24%' is linear, and its '8 extra materials' is actually 16 items. Point boosts are 'permanent' (GAME_DESIGN.md:225, spec:57) with only a 12-point bank cap and no per-boost rank, so slots and max thirst stack without limit. '+10 max thirst' conflicts with meters fixed at 0–100 (survival-meters:9). Downed-timer boosts do nothing in solo (survival-meters:57). It is undefined whether one co-op player's permadeath adds a level. The seeded/daily rule (GAME_DESIGN.md:228) is missing from spec:73.

**Why it matters.** An implementer of crafting-inventory would drop identifications at run end. GUT tests written from the spec would contradict the design doc, and uncapped boosts break 'it never becomes easy' (GAME_DESIGN.md:210).

**Suggested fix.** Keep a per-profile known-plant set unioned into the party at run start, rewrite crafting-inventory:33, and add more look-randomized plants. Pick linear or compounding easing and state the cap. Give each boost a max rank, or make boosts last one run. Make meter max a per-player stat. Define death per participating profile, give solo players something useful instead of downed boosts, add the seeded/daily rule, and fix the 16.

### 35. Keepsake effects and unlocks contradict each other across GAME_DESIGN §14, ITEMS and CHARACTERS, and the spec points at the incomplete §14 table

**Severity:** medium · **Dimensions:** consistency, specs-vs-design, balance-math, legal-content · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `docs/CHARACTERS.md`, `docs/CONTENT_MANIFEST.md`, `openspec/project.md`, `openspec/specs/endings-progression/spec.md`

**Evidence.** GAME_DESIGN.md:197-204 (§14) lists 6 keepsakes, while ITEMS.md:122 'Keepsakes (7)' and CONTENT_MANIFEST.md:24 list 7. ITEMS.md:124 defers unlocks to §14, and endings-progression:25 says keepsakes 'SHALL unlock per docs/GAME_DESIGN.md §14'. Pelota firmada is missing from §14 and unlocks when Yunior reaches land (ITEMS.md:134) or when Yusnavy does (CHARACTERS.md:112). Nudo: 'Cross 3 times by raft' (GAME_DESIGN.md:202) vs the reward for La foto (CHARACTERS.md:21). Medalla: 'Save La Vieja's quest' (GAME_DESIGN.md:201), but no quest has that name and Vieja is also the turtle; CHARACTERS.md:43 has Caridad give it when a Maestro is present. Devuelto (:190) and a win (:227) unlock unnamed keepsakes. Keepsakes are a meta unlock in project.md:44 but found or gifted in-run in GAME_DESIGN.md:93 and an inventory item in ITEMS.md:124. TextData and KeepsakeData are named (CONTENT_MANIFEST.md:3) but stored in items/.

**Why it matters.** KeepsakeData, the profile unlock flags and NPC quest rewards in content-batch-5 and Milestone E would each follow a different source.

**Suggested fix.** Make §14 the single table with all 7: one effect, one unlock (or an explicit OR), persistent vs in-run, slot cost. Name the keepsakes for Devuelto and a win. Have ITEMS and CHARACTERS reference §14. Make KeepsakeData and TextData ItemData subclasses (the validator's is_instance_of accepts subclasses) or give them their own folders.

### 36. 'Found every run' texts and 'any island' NPCs are tied to chains a run can skip, and 5 of 8 companions have no spawn POI

**Severity:** medium · **Dimensions:** consistency · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `docs/CHARACTERS.md`, `docs/ISLANDS.md`, `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md`, `CLAUDE.md`, `openspec/specs/npcs-dialogue/spec.md`

**Evidence.** Important texts are 'found every run' (GAME_DESIGN.md:179, :247; CLAUDE.md:33), yet each has one home: La lista at the lighthouse (ISLANDS.md:141), Las cartas in the shipwreck hull (:186), La libreta in Ramón's boat, the diario at the mangrove camp ruin (:81). 'You cannot see every chain in one run' (GAME_DESIGN.md:40). ISLANDS.md:219 asks for '1 important text' per island, but only 4 exist. Ramón can appear on 'any island' (CHARACTERS.md:13) but is placed only at the sandbar 30% and coast 40% (ISLANDS.md:38, :57), while his photo quest needs an item from the far shipwreck reef brought back (:187; it sets the ramon_photo flag). Only El Chino (:80), Dayana (:103) and Papo (:166) have POI rows; Marisol, Alfredo, Yusnavy, Tania and Tomás have none, though npcs-dialogue:9 provides spawn-rule fields. Variant signature POIs have no rows, yet CONTENT_MANIFEST.md:49 includes the_buoy.

**Why it matters.** The generator and NpcData/TextData spawn rules either break the 'every run' promise, which the AI backend's purpose relies on, or have to invent placements, and Ramón's quest has no valid order.

**Suggested fix.** Choose floating placements injected on whatever chain the run visits, or chain-locked placements with the 'every run' claim dropped. Give every companion spawn chances. Add a late-run spawn for Ramón. Add rows for the signature POIs and list the POI ids.

### 37. Per-install API keys issued at first launch make 'per-player' rate limits bypassable, and there is no global cap on Bedrock spend

**Severity:** medium · **Dimensions:** setup-tooling, architecture, specs-vs-design, legal-content · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/ai-dialogue-backend/spec.md`, `CLAUDE.md`, `docs/GAME_DESIGN.md`, `TASKS.md`

**Evidence.** ai-dialogue-backend:9 says 'Auth via a per-install API key issued at first launch', so the issuing endpoint must accept anonymous callers. :41 limits only per key (60/min, 2,000/day), and 'Target cost ≤ $0.05 per run' is a target, not a cap. CLAUDE.md:39 and GAME_DESIGN.md:257 call these per-player limits. No global throttle, budget alarm, reserved concurrency or kill switch is specified. AWS usage-plan docs say throttles and quotas are 'not hard limits' and should not be relied on to control costs, and that API keys are not for authentication; native keys are capped at 10,000 per region. At the repo's ~$0.0015 per line (GAME_DESIGN.md:252), each minted key can cost about $3/day in cache misses. The coarse cache (spec:33) bounds spend only if its key fields are validated, and widening the cache key (next item) removes that bound.

**Why it matters.** Once deployed, the developer's AWS bill sits behind an endpoint that hands out keys to anyone. The issuance design shapes the API, so it is cheaper to settle before backend code exists.

**Suggested fix.** Use a server-verifiable identity (a platform ticket later) or signed tokens checked by a Lambda authorizer, with per-IP issuance limits. Keep per-identity limits in DynamoDB plus a WAF rate rule. Add a global daily spend breaker (Budgets action → SSM flag → fallback-only mode) and reserved concurrency. Enum-validate the cache-key fields. Design this together with the context and cache item.

### 38. Client-supplied context goes into the system prompt and the shared 30-day cache key drops most prompt inputs, so one client can poison lines for everyone; which co-op peer calls the backend is unspecified

**Severity:** medium · **Dimensions:** architecture, legal-content, specs-vs-design · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/ai-dialogue-backend/spec.md`, `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/CHARACTERS.md`, `CLAUDE.md`

**Evidence.** spec:9 has the client send `{npc_id|text_id, lang, context}`, and :17 puts 'the context' into the system prompt. npcs-dialogue:33 includes 'run history, recent events', with no schema or validation. The cache is keyed by hash(npc_id, lang, profanity, context_bucket), shared by all players for 30 days (:33). The key has no text_id, no `returning` flag (endings-progression:65-70) and no run-reactive fields. A crafted context therefore poisons a bucket for everyone, and honest lines that reference one player's run (CHARACTERS.md:158-159) are served to others. Content rules are prompt instructions only (:25), and nothing checks output before caching. npcs-dialogue:17 'the player who talks drives' leaves open which peer calls; if the client fetches and relays text, host authority breaks, and whose trust sets `returning` is undefined.

**Why it matters.** Slurs or invented quotes from real politicians could be shown to every player for a month, breaking the project's own content rules. The context contract is fixed in Milestone E npcs-dialogue, before the backend is built.

**Suggested fix.** Have only the host's DialogueService call the backend, building context from host state. The server builds the prompt from enumerated, validated fields (ids, ints, enums), puts the context in the user turn and accepts no free text. Make the cache key the hash of exactly those inputs, including text_id, returning and trust tier, and store N variants per key. Validate output (length, emotion enum, real-name deny-list, profanity level) before caching. Align CLAUDE.md:39.

### 39. The 3 s client timeout cannot fit the backend design (6 s Lambda, in-Lambda retry, fetch when the player starts talking), and 100 ms offline needs a health state

**Severity:** medium · **Dimensions:** architecture, specs-vs-design · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/npcs-dialogue/spec.md`, `openspec/specs/ai-dialogue-backend/spec.md`, `TASKS.md`

**Evidence.** npcs-dialogue:33 promises a line or fallback within 3 s (TASKS.md:82), and :38 an offline fallback within 100 ms. ai-dialogue-backend:41 sets the Lambda timeout at 6 s and :17 retries once on non-JSON. Haiku 4.5 on Bedrock has a time to first token of about 1.1 s plus about 100 output tokens, so one call takes about 1.5–2 s, and a retry plus a cold start cannot return inside 3 s. A blackholed connection does not fail in 100 ms unless the client already knows it is offline. When the fetch happens is unspecified. A late result still fills the cache, and output is already schema-constrained, so this is about UX and budget, not wasted lines.

**Why it matters.** Without a prefetch policy every important conversation can stall up to 3 s, and the offline scenario cannot be met as written.

**Suggested fix.** Prefetch on spawn or approach, show a handwritten line immediately and swap in the AI line if it arrives in time. Drop the retry (use structured outputs) or give it its own budget. Add a DialogueService health state (startup ping plus a circuit breaker) that defines 'offline'.

### 40. Join-by-IP over ENet is hard-wired: no peer abstraction, no stable identity for reconnects, and no target-platform list (web rationale conflicts with ENet)

**Severity:** low · **Dimensions:** architecture, export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/coop-networking/spec.md`, `openspec/changes/project-skeleton/design.md`, `openspec/specs/endings-progression/spec.md`, `docs/GAME_DESIGN.md`, `TASKS.md`

**Evidence.** coop-networking:9 hosts on port 7777 with join by IP over ENet (:4), and Steam/relay is post-v1 (TASKS.md:94), so v1 hosts must forward UDP and CGNAT blocks it. Peer IDs change on every connection, so a client reconnecting within the 90 s downed window (:33) cannot reclaim its body or inventory, and whether a removed player counts as dead for endings or Experiencia is undefined. No doc lists target platforms. skeleton design.md:34 says the renderer 'keeps a web export open', but ENetMultiplayerPeer does not exist on Web and browser HTTPRequest needs CORS, which ai-dialogue-backend:9 does not mention.

**Why it matters.** Hard-coding ENetMultiplayerPeer in the Milestone A coop-networking change makes Steam relay or web a rewrite, and a co-op disconnect silently splits the party.

**Suggested fix.** Have NetManager create its peer behind one factory method (ENet now; Steam or WebRTC later) and try UPNP. Document the port-forwarding limitation. Add a join handshake with a stable player UUID so reconnects restore state, and define how a removed player counts. State the v1 platforms (for example Windows and Linux desktop) and drop the web rationale.

### 41. .gitignore misses root .env and local junk, and there is no .gitattributes for Godot text resources

**Severity:** low · **Dimensions:** setup-tooling · **Status:** Fixed: .gitattributes in b373675, .gitignore in 481c7c2.

**Files:** `.gitignore`, `CLAUDE.md`

**Evidence.** CLAUDE.md:50 forbids committing .env files, but .gitignore:16 ignores only backend/.env, so root, tools/ or game/ .env and any .env.* are not ignored. bash.exe.stackdump is untracked and not ignored. .claude/worktrees/ is excluded only in the local .git/info/exclude. There is no .gitattributes while core.autocrlf=true; the skeleton proposal plans one. backend.cfg is ignored and no example file exists.

**Why it matters.** A stray secret file or crash dump gets swept into a commit. Without eol rules, .sh scripts and .tscn/.tres files check out as CRLF on Windows.

**Suggested fix.** Ignore .env, .env.*, !.env.example, *.stackdump and .claude/worktrees/. Land .gitattributes (`* text=auto eol=lf`, `*.sh text eol=lf`, binary rules for art and audio) before the first .tscn/.tres is committed. Commit backend.cfg.example.

### 42. No export preset or filters: the 'Exported build' scenario cannot be verified, test classes and GUT would ship, and backend.cfg would be left out

**Severity:** low · **Dimensions:** export-platform-input-ui-shell, project-skeleton-code-tests-ci, architecture · **Status:** Open: needs a design decision.

**Files:** `openspec/changes/project-skeleton/specs/content-data/spec.md`, `openspec/changes/project-skeleton/design.md`, `game/tests/fixtures/fixture_item_data.gd`, `game/tests/fixtures/fixture_recipe_data.gd`, `game/addons/gut`, `README.md`, `.github/workflows/ci.yml`

**Evidence.** No export_presets.cfg exists. content-data spec:67-69 'Exported build' cannot be verified (design.md:62 defers it), and ci.yml never exports. Godot's default 'export all resources' preset would pack addons/gut (3 MB, 12 fonts) and tests/. FixtureItemData, FixtureRecipeData and TestFs declare class_name, so they show in the New Resource dialog (the validator would reject a fixture placed in a real folder). game/config/backend.cfg is not a resource and needs a non-resource filter to export (README.md:128 says the game reads its API URL from there), so a shipped build would silently run without AI.

**Why it matters.** A spec scenario would be archived as done without ever running. Player builds would ship test code and quietly lose the backend URL.

**Suggested fix.** Commit desktop presets that exclude `addons/gut/*` and `tests/*` and include *.cfg and license .txt files. Add a CI export plus a headless catalog-listing comparison, or track the first export test as a task. If class_name is removed from the fixtures, update the tests that assert on those names.

### 43. The CI gate has never run and does not bind: commits are unpushed and main is unprotected

**Severity:** low · **Dimensions:** project-skeleton-code-tests-ci · **Status:** Fixed 2026-11-05: main pushed and the first CI run passed (run 42053690396).

**Files:** `.github/workflows/ci.yml`, `openspec/changes/project-skeleton/specs/build-verification/spec.md`, `CLAUDE.md`

**Evidence.** main is 7 commits ahead of origin (64a7bd5) and GitHub has zero workflow runs. main is not protected and has no rulesets. Every commit went straight to main, against CLAUDE.md:14 'Small PRs'. The uncommitted working tree already changes cancel-in-progress to PR-only and sets the smoke timeout to 60 (spec.md:15). Linux, which is case-sensitive, has never built the code. The pinned engine SHA-512 and action SHAs check out.

**Why it matters.** The 'GREEN' claim rests only on local Windows runs, and nothing stops a red main.

**Suggested fix.** Push the skeleton on a branch and open a PR so CI runs once. Add a ruleset requiring 'Godot headless checks' on main, and commit the ci.yml fixes.

### 44. The documented smoke-test command fails as written: no --path game and no import step

**Severity:** low · **Dimensions:** setup-tooling, architecture · **Status:** Fixed in 77cacd3.

**Files:** `CLAUDE.md`, `HANDOFF.md`, `game/tests/smoke.gd`, `openspec/changes/project-skeleton/proposal.md`

**Evidence.** CLAUDE.md:44 and HANDOFF.md:72 give `godot --headless -s tests/smoke.gd` with no --path, while project.godot is in game/. From the repo root this fails with 'File not found'. On a fresh checkout without .godot/, class_name types fail to parse. `godot` is not on PATH on this Windows machine. smoke.gd:6-7 already shows `--path game --import` followed by `--path game -s res://tests/smoke.gd`, and proposal.md:15 plans to fix CLAUDE.md, but HANDOFF.md:72 is not on its list.

**Why it matters.** The one CI gate CLAUDE.md makes mandatory, and the 'run after every change' habit, copy this command.

**Suggested fix.** Update CLAUDE.md:44 and HANDOFF.md:72 to the two-step command, state that tests live in game/tests/, and define GODOT once (the *_console.exe on Windows, a pinned download in CI).

### 45. Spanish-first localization has no path beyond names, and 'English keeps the slang' cannot be told apart from 'not translated yet'

**Severity:** low · **Dimensions:** content-data-schema · **Status:** Open: needs a design decision.

**Files:** `game/scripts/data/content_data.gd`, `game/scripts/content/content_validator.gd`, `game/project.godot`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `CLAUDE.md`, `TASKS.md`

**Evidence.** content_data.gd:6-15 has only name_es and name_en, with English falling back to Spanish, so an empty name_en means both 'keep the Spanish' (CLAUDE.md:30) and 'untranslated'. There is no description or lore field, yet GAME_DESIGN.md:239 puts satire in item descriptions, and loading tips (:240) have no folder. The validator requires only name_es (content_validator.gd:36), while the source tables give English names (ITEMS.md:12-14, 22-35). project.godot has no translation setup. The data classes are not written yet, so this is cheap to settle now.

**Why it matters.** Every batch writes player-visible text. The 'English localization pass' (TASKS.md:91) cannot measure coverage, and batch authors invent Spanish names with no review.

**Suggested fix.** In the data-class derivation, add description/lore fields or a LocalizedText {es, en, keep_es}, or use tr() keyed on Spanish msgids with an en.po. Make 'keep Spanish' explicit, have the validator warn on missing English, and add Spanish names to the doc tables.

### 46. Run structure and boss placement contradict across docs: branch point, distance bands, 'one boss per chain', tiger shark's chain, the cutter's crossing

**Severity:** low · **Dimensions:** consistency, creature-behavior-coverage · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `docs/ISLANDS.md`, `docs/BESTIARY.md`, `openspec/specs/crossing/spec.md`, `openspec/specs/endings-progression/spec.md`

**Evidence.** The route branches 'After island 1' in GAME_DESIGN.md:40 but 'from island 3' in ISLANDS.md:3 and endings-progression:9. Distance bands use fixed island numbers (ISLANDS.md:13-16 'Islands 6–7 (far)') although runs are 6–8 islands, so a 6-island run may get no far island. GAME_DESIGN.md:139 'one per chain' names 5 bosses for 9 chains. The tiger shark is the reef boss in BESTIARY.md:63, GAME_DESIGN.md:139, ISLANDS.md:14 and crossing:33 'reef only', but is fought on the far shipwreck reef (BESTIARY.md:67; ISLANDS.md:184, :191, :249); ISLANDS.md:107's 'shipwreck variant' of the reef does not exist (:245). The cutter chases on the 'first crossing' (BESTIARY.md:177; crossing:35) but on the coast cay's 'crossing out' (ISLANDS.md:62); BESTIARY scripts a spot at 30 s at 1.5× speed, while crossing:37 uses detection.

**Why it matters.** ChainData, the boss resources and endings-progression part 1 need one rule for which chain sits at which index and which chain owns which boss, before Milestones C and D.

**Suggested fix.** Write a slot table per run length and decide whether a far island is guaranteed. Replace 'one per chain' with the actual chain→boss map. Pick the tiger shark's chain, and pick the cutter's crossing(s) and trigger model, with the numbers in data. Fix GAME_DESIGN.md:40.

### 47. Manifest, HANDOFF and TASKS counts don't match the listed content (37 creatures not 40, 22 NPCs not 24), and batches break the 30-file cap

**Severity:** low · **Dimensions:** consistency, creature-behavior-coverage · **Status:** Open: needs a design decision.

**Files:** `docs/CONTENT_MANIFEST.md`, `docs/BESTIARY.md`, `docs/ITEMS.md`, `HANDOFF.md`, `TASKS.md`

**Evidence.** CONTENT_MANIFEST.md:7 says '35 + 5 bosses' and :69 '40 creatures', and HANDOFF.md:17 says '(40)', but lines 9-13 list 32 + 5 = 37; BESTIARY.md:246 counts three bosses twice, and ISLANDS.md:274 says '35'. NPCs are '24' (:31, :69) against 22 listed. ITEMS.md:54 'Tools (14)' has 16 rows. TASKS.md:100-101 'creatures 1–20 / 21–40' matches no numbering. The TASKS.md:98 30-file cap is broken by batch 4 (36), batch 5 (49), batch 6 (34) and batch 8 (~45).

**Why it matters.** The manifest is the checklist for data-entry batches, and the batch split as written cannot be carried out.

**Suggested fix.** Correct the totals, number the entries, and define each batch by a list of ids that stays within the cap.

### 48. The set of AI-voiced NPCs and texts is 7 and 4 in some docs and 12 and 6 in others

**Severity:** low · **Dimensions:** consistency · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `docs/CHARACTERS.md`, `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md`, `TASKS.md`, `openspec/project.md`, `openspec/specs/npcs-dialogue/spec.md`

**Evidence.** GAME_DESIGN.md:173 names 7 AI NPCs, and TASKS.md:80 budgets 7 NPC profiles and 4 text profiles. CHARACTERS.md:90-118 marks all 8 companions as AI, CONTENT_MANIFEST.md:37 asks for 12 profiles, and project.md:42 defines 'important' as AI-generated. ITEMS.md:146-147 and CHARACTERS.md:160 mark bottle notes and the reply bottle as AI, while ISLANDS.md:219 treats bottle notes separately. TextData has no AI flag (npcs-dialogue:9 has a dialogue mode for NPCs only).

**Why it matters.** The backend's scope, its profile files, the number of fallback lines and the ≤$0.05/run cost check all depend on this list.

**Suggested fix.** Write the canonical lists once in GAME_DESIGN §11 and §12. Add an ai flag to TextData. Update TASKS §8 and the manifest, and re-run the cost estimate including bottle notes.

### 49. Smaller number and lore contradictions: dominoes, expired medicine odds, manchineel identification, and the Rodríguez–Caridad timeline

**Severity:** low · **Dimensions:** consistency, legal-content · **Status:** Open: needs a design decision.

**Files:** `docs/ITEMS.md`, `docs/ISLANDS.md`, `docs/BESTIARY.md`, `docs/GAME_DESIGN.md`, `docs/CHARACTERS.md`

**Evidence.** Dominoes give '+20 morale' (ITEMS.md:119) but 'restore morale to 100' in a set piece (ISLANDS.md:267). Expired medicine reads '50% heals, 50% nothing, 10% poison' (ITEMS.md:115). Manchineel has a fixed look and is learned 'once per run' (BESTIARY.md:141), while plants get a random look each run and identifications carry over (ITEMS.md:39, GAME_DESIGN.md:215). Rodríguez is 44 (CHARACTERS.md:71) with a present of 2022 or later (:73), so he was at most about 13 in 1991, when Caridad had already left the academy (:34); yet 'he was her student', which El trato del capitán depends on (:80). The hutía and iguana food values read as raw vs cooked; the missing raw items are covered by the missing-items fix.

**Why it matters.** Batch data entry would have two valid values to choose from, and both AI profiles would repeat the impossible student link.

**Suggested fix.** Pick one dominoes value and fix the medicine odds. Make manchineel follow the random-look and carry-over rule. Make Rodríguez about 60, or move Caridad's dates. Add a canonical present year to CHARACTERS.md.

### 50. Seeded generation inputs are incomplete, so the hash check scope and shared/daily seed rules are undefined

**Severity:** low · **Dimensions:** specs-vs-design · **Status:** Open: needs a design decision.

**Files:** `openspec/specs/island-generation/spec.md`, `openspec/specs/coop-networking/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/GAME_DESIGN.md`, `docs/ISLANDS.md`

**Evidence.** island-generation:9 generates deterministically from (seed, index, chain id) and has clients verify a hash. But challenges 'SHALL modify generation' (endings-progression:81), and the Experiencia bonus (:41) and party scaling (coop-networking:41) change quantities. What the hash covers is undefined, given that resources are host-spawned (coop-networking:14-25). spec:73 omits GAME_DESIGN.md:228 'seeded/daily earn Experiencia but do not spend it' and adds 'Seeded runs do not unlock keepsakes', which is not in the design. endings:54 shows the turtle route as discovered although it may not roll (island-generation:41; ghost net 70%, ISLANDS.md:100).

**Why it matters.** The hash check can fail spuriously, and daily runs stop being comparable.

**Suggested fix.** Define a generation-input record (seed, index, chain, variant, party size, easing level, challenge flags) and a hash scope covering terrain and POIs. Keep layout RNG separate from quantity RNG. Align the seeded/daily rules with the design, and say whether a discovered route is forced or shown only if present.

### 51. Revive works with any cup, including seawater, and the downed-timer boosts do nothing in solo

**Severity:** low · **Dimensions:** balance-math · **Status:** Decided 2026-11-05: for a player with no other living player the downed-timer rewards lengthen a solo last-stand window: 0 s base on run 1, +5 s per Experiencia level and +10 s from the point boost, shared with the Medalla revive. The survival-meters change implements the window (and which cups revive); endings-progression states the Experiencia side (solo-play change).

**Files:** `openspec/specs/survival-meters/spec.md`, `openspec/specs/endings-progression/spec.md`, `docs/ITEMS.md`, `docs/GAME_DESIGN.md`

**Evidence.** survival-meters:57 revives at 30 health with 'any cup', and seawater is available 'Anywhere' (ITEMS.md:15); GAME_DESIGN.md:57's shade is optional. Solo players die immediately at 0 (:57), so +5 s per level (endings:41) and the +10 s boost (:57) are dead picks in solo. A seawater revive does cost a net −20 thirst.

**Why it matters.** Two Experiencia rewards are worthless for solo players, and the rules for the main co-op safety net are loose.

**Suggested fix.** Say which cups revive (fresh water, or a bandage) and require a timed interact. Replace the downed-timer boosts with something solo players can use.

### 52. OpenSpec 1.x ignores openspec/project.md and config.yaml has no context, so /opsx planning never sees the glossary

**Severity:** low · **Dimensions:** specs-vs-design, setup-tooling · **Status:** Fixed in 481c7c2 (openspec/config.yaml context and rules).

**Files:** `openspec/config.yaml`, `openspec/project.md`, `README.md`, `HANDOFF.md`, `START.md`

**Evidence.** config.yaml:1 contains only `schema: spec-driven` and commented examples; there is no context: or rules:. OpenSpec 1.16 treats project.md as legacy (legacy-cleanup.js tells you to migrate it to config.yaml), and the propose skill reads only config.yaml context. README.md:71, HANDOFF.md:11 and START.md:15 still point to project.md. CLAUDE.md is auto-loaded and carries the conventions, so what is actually lost is mainly the domain glossary (project.md:31-44).

**Why it matters.** Proposals and content batches run without the domain terms (chain, route, keepsake), and the CLI flags project.md as a leftover.

**Suggested fix.** Move the glossary, reference paths and a Windows/Git Bash note into the config.yaml `context:`. Add rules such as: tasks end with a Godot MCP run plus the smoke test, and spec deltas cite the GAME_DESIGN number they change. Point the docs at config.yaml.

### 53. The Bedrock model ID in CLAUDE.md and the spec cannot be invoked on bedrock-runtime

**Severity:** low · **Dimensions:** setup-tooling · **Status:** Open: needs a design decision.

**Files:** `CLAUDE.md`, `openspec/specs/ai-dialogue-backend/spec.md`

**Evidence.** CLAUDE.md:38 and ai-dialogue-backend:17 use `anthropic.claude-haiku-4-5`. The AWS model card says bedrock-runtime needs a geo or global inference profile (us. or global.anthropic.claude-haiku-4-5-20251001-v1:0); the bare id works only on bedrock-mantle. IAM must grant the profile ARN plus the foundation-model ARNs in every destination region. The model is Active, and its 'EOL no sooner than Oct 16, 2026' date has passed with no Legacy notice.

**Why it matters.** A boto3 Lambda written to these docs fails its first call with a ValidationException, and a policy scoped to one model ARN gets AccessDenied.

**Suggested fix.** Make the model id a SAM parameter set to the profile id, name the endpoint, document the IAM resources, and re-check the model lifecycle before Milestone F.

### 54. No release plan for live AI text: no output moderation, report trail, AI disclosure or privacy and retention policy

**Severity:** low · **Dimensions:** legal-content · **Status:** Open: needs a design decision.

**Files:** `docs/GAME_DESIGN.md`, `openspec/specs/ai-dialogue-backend/spec.md`, `openspec/specs/npcs-dialogue/spec.md`, `docs/CHARACTERS.md`, `TASKS.md`

**Evidence.** The safeguards at GAME_DESIGN.md:257 list no content filter, and content rules are prompt instructions only (ai-dialogue-backend:25). Steam requires disclosing live-generated AI and describing guardrails, and players can report output through the overlay (Steam is only implied, TASKS.md:94). There is no line id or log to trace and purge a reported cached line. Yunior is 12 (CHARACTERS.md:51). A per-install key plus IP in logs is personal data under GDPR, CloudWatch logs never expire by default, and there is no privacy notice, opt-out or deletion path.

**Why it matters.** These are store and legal requirements at release. They are cheap to put in the spec before the backend is built.

**Suggested fix.** Add Bedrock Guardrails or other output moderation before caching. Store line id, cache key and timestamp so a report can purge an entry. Add an in-game AI disclosure and an 'online dialogue off' toggle. Keep names and free text out of the context schema. Set log retention to 30 days or less, document the inference region, and publish a privacy notice.

### 55. Runtime Kokoro TTS has no agreed home and its Spanish path pulls in GPL-3.0 espeak-ng, which ASSETS.md doesn't list

**Severity:** low · **Dimensions:** legal-content, export-platform-input-ui-shell, consistency, specs-vs-design · **Status:** Open: needs a design decision.

**Files:** `docs/ASSETS.md`, `docs/GAME_DESIGN.md`, `openspec/specs/ai-dialogue-backend/spec.md`, `openspec/project.md`, `HANDOFF.md`, `TASKS.md`

**Evidence.** ASSETS.md:31 lists Kokoro only as Apache 2.0. Kokoro's pipeline sends Spanish ('e') through EspeakG2P, and espeak-ng and phonemizer are GPL-3.0. Where Kokoro runs is described three ways: 'Kokoro at runtime' as a decision (GAME_DESIGN.md:256), a stretch goal behind a flag (HANDOFF.md:58, ai-dialogue-backend:49), and 'offline tooling in tools/' (project.md:13). The fallback model is 'Nova Micro/Lite' in GAME_DESIGN.md:258 but 'Nova Micro' in HANDOFF.md:57.

**Why it matters.** Bundling espeak-ng in the client brings GPL-3.0 obligations into a game whose code is meant to be MIT. Running it server-side changes Lambda cost and caching.

**Suggested fix.** Record espeak-ng and phonemizer (GPL-3.0) in ASSETS.md. Decide that runtime TTS runs server-side or is out of v1 (v1 already ships grunt clips). Align GAME_DESIGN, HANDOFF and project.md, and get a license review before any client-side use.

### 56. Content names real people, a band and a brand despite CLAUDE.md's 'no real people' rule; Caridad's AI profile will invent Martí quotes

**Severity:** low · **Dimensions:** consistency, legal-content · **Status:** Open: needs a design decision.

**Files:** `CLAUDE.md`, `docs/CHARACTERS.md`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `openspec/specs/ai-dialogue-backend/spec.md`

**Evidence.** CLAUDE.md:52 says 'No ... real people in assets or dialogue'. Yet Yunior (AI) 'talks constantly, mostly about Messi' (CHARACTERS.md:53), Caridad (AI) 'Quotes Martí' (:45), there is a 'Cassette de Los Van Van' (GAME_DESIGN.md:204), and 'Cohibas' (ITEMS.md:116). The spec only bans invented quotes from 'real named politicians' (ai-dialogue-backend:25; CLAUDE.md:31). Disclosed fiction is allowed under the AUP, Martí's writings are public domain, and ASSETS.md:28 and :36 already rule out real recordings and likenesses.

**Why it matters.** The style guide and profiles will be written to the narrower spec rule, and Haiku may invent Martí quotes that end up in the shared cache.

**Suggested fix.** Narrow CLAUDE.md:52 to likeness, brand art and invented quotes, or rename the references. Give caridad.md a vetted list of real Martí quotes to use verbatim.

### 57. Brogue CE is AGPL-3.0, not GPL, and 'read there, write here' gives an agent no separation between studying and writing code

**Severity:** low · **Dimensions:** legal-content · **Status:** License wording fixed in 481c7c2. Keeping study and implementation in separate sessions is a process decision.

**Files:** `CLAUDE.md`, `README.md`, `docs/GAME_DESIGN.md`, `HANDOFF.md`, `tools/clone_references.sh`, `openspec/specs/creatures-ai/spec.md`, `openspec/specs/island-generation/spec.md`

**Evidence.** BrogueCE is AGPL-3.0 (LICENSE.txt and the Monsters.c header), while README.md:114, GAME_DESIGN.md:297, CLAUDE.md:49, HANDOFF.md:61 and clone_references.sh:3 and :21 call it GPL. The specs point agents at exact files (creatures-ai:4 'Brogue Monsters.c'; island-generation:4 SPD builders/painters), and the same session that reads them then writes the GDScript.

**Why it matters.** Close structural ports are likely, nothing checks for them, and the license names are simply wrong.

**Suggested fix.** Say 'GPL/AGPL'. Have a research step write a prose-only mechanism note into design.md, with the implementing session not opening reference/. Add a PR checklist item.

### 58. No LICENSE file in the public repo, and shipped builds would lack the required engine and font notices and the credits screen the docs promise

**Severity:** low · **Dimensions:** legal-content, export-platform-input-ui-shell · **Status:** Open: needs a design decision.

**Files:** `README.md`, `game/assets/CREDITS.md`, `docs/ASSETS.md`, `game/addons/gut/LICENSE.md`, `game/addons/gut/fonts/OFL.txt`, `openspec/specs/endings-progression/spec.md`

**Evidence.** The repo is public with licenseInfo null and no LICENSE or NOTICE, while README.md:164 says 'Code: MIT; design docs and writing: all rights reserved', names no holder, and leaves the boundary for backend/prompts and game/resources/dialogue undefined. Godot's 'Complying with licenses' requires the MIT text and third-party notices (FreeType, ENet, mbedTLS). CREDITS.md omits Godot, GUT (MIT) and GUT's 12 OFL fonts, and that OFL.txt carries only Anonymous Pro's copyright. CREDITS.md:3 and ASSETS.md:50 require an in-game credits screen that no spec creates; the ending credits slots do exist (endings-progression:17).

**Why it matters.** The MIT grant is ambiguous, and a distributed build would not meet the MIT, OFL and FreeType terms.

**Suggested fix.** Add LICENSE (MIT with holder and year) and a NOTICE mapping paths to licenses. Add a Credits/Licenses screen reachable from the menu, using Engine.get_license_text() and get_copyright_info(). Add Godot and GUT to CREDITS.md or exclude GUT from exports.

### 59. Voice-cloning consent is a one-line 'written permission' that does not cover synthetic lines, profanity, satire, commercial use or revocation

**Severity:** low · **Dimensions:** legal-content · **Status:** Open: needs a design decision.

**Files:** `docs/ASSETS.md`, `TASKS.md`, `docs/GAME_DESIGN.md`, `openspec/specs/ai-dialogue-backend/spec.md`

**Evidence.** ASSETS.md:30 'Record friends/family with written permission' and TASKS.md:88 are the only consent rules. Cloned voices will speak lines the donors never recorded, including strong profanity (GAME_DESIGN.md:241) and political satire (:239), in a commercial product. Nothing covers retention, deletion or revocation. California Labor Code §927 voids digital-replica clauses that lack a reasonably specific description of uses, where California law governs.

**Why it matters.** Donors with family in Cuba could be identified, and one withdrawal late in development forces re-voicing that donor's characters.

**Suggested fix.** Before recording (Milestone G), write a release that names the synthetic model, new lines (attach a sample script), worldwide commercial use, compensation, credit or anonymity, storage and deletion, and what revocation does. Keep signed copies outside the repo.

### 60. Mature content has no rating plan or design rule for illicit-drug items

**Severity:** low · **Dimensions:** legal-content · **Status:** Open: needs a design decision.

**Files:** `README.md`, `docs/GAME_DESIGN.md`, `docs/ITEMS.md`, `docs/ISLANDS.md`, `docs/CHARACTERS.md`

**Evidence.** README.md:5 says the game 'is rated for mature audiences' and GAME_DESIGN.md:22 lists swearing, satire and danger, with no descriptor list. Content includes rewarded alcohol and tobacco (ITEMS.md:16, :52, :116), a hallucinogenic mushroom (:51), a drug bale (ISLANDS.md:265), a sex-work reference (CHARACTERS.md:135) and a 12-year-old who can die. Australia's 2023 guidelines refuse classification for illicit drug use tied to rewards (Halloween: The Game was refused). The current design stays inside R18+/M.

**Why it matters.** One tuning change, such as the mushroom or bale giving a buff, would make the game unsellable in Australia, and store and IARC surveys need the descriptors.

**Suggested fix.** Add a content-rating section: target rating per region, a descriptor matrix, and a rule that illicit-drug items never give a net benefit. Change README to 'target rating'.

## Refuted

These claims did not survive verification (the refuters could not confirm them from the files or an external source), or were already fixed when checked:

- [consistency] Ending conditions are ambiguous and conflict with character-specific ending rules
- [specs-vs-design] Morale is 'shared' in the design but per-player in the spec; hallucination threshold and persuasion check depend on which
- [setup-tooling] Godot version is an open '4.4+' floor while 4.7.2 is installed; GODOT_PATH example is macOS-only
- [setup-tooling] Remaining script robustness issues: fetch_assets.py path depends on the working directory and is unpinned; clone_references.sh updates shallow clones with a plain pull
- [setup-tooling] Conflicting rules for TASKS.md (tick in place vs move to Done) will cause merge conflicts between parallel sessions
- [architecture] Wrong Bedrock model ID and missing inference-profile requirement: `anthropic.claude-haiku-4-5` cannot be invoked
- [architecture] How the island reaches clients is contradictory: clients regenerate it from the seed, entities arrive through MultiplayerSpawner, and runtime terrain changes have no sync path
- [architecture] The cost estimate is too low and leans on caching that Haiku 4.5 cannot do for prompts this size
- [architecture] The skeleton's resource classes and autoload list don't match the content manifest or README, and weather is hardcoded where everything else is data
- [balance-math] Run length (60-90 min) cannot fit the multi-day content and 5-minute sleeps the 12-minute day implies
- [legal-content] The 'LPC Animals' license claim is wrong: LPC animal art is CC-BY-SA 3.0/GPL 3.0 or CC-BY/GPL 2.0, not CC0, and its style does not fit 16×16
- [legal-content] Handwritten content names a real band, real brands and real broadcasters, against the repo's own rules; the Los Van Van keepsake implies licensed recordings
- [project-skeleton-code-tests-ci] Manifest folders and named data classes do not map one-to-one, so 'one content type per folder' cannot be met as written
- [project-skeleton-code-tests-ci] GUT exits 0 when it finds no tests, so a config or folder mistake makes CI permanently green
- [project-skeleton-code-tests-ci] The CLAUDE.md static-typing rule is not enforced; a one-line project setting would make the gate fail on untyped code
- [project-skeleton-code-tests-ci] ContentCatalog.get_entry accepts path-like ids and returns content of the wrong type
- [content-data-schema] The skeleton shipped without its data classes and the content validator checks nothing, yet ~280 content files are queued against it
- [creature-behavior-coverage] Crossing-only creatures have no support in the crossing spec: the event list is closed, there is no water grid, and the scene is shorter than their timers
