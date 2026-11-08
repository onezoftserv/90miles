# 90 Millas — Tasks

Ordered. Tick as you go; Claude Code keeps this file current. Each coding task maps to an OpenSpec change (`/opsx:propose <name>`).

## 0. Tooling (one-time, ~1 hour)

- [x] Install Godot 4.7.2 and open it once
- [x] Install Claude Code: `npm install -g @anthropic-ai/claude-code`
- [x] Install ECC: `/plugin marketplace add https://github.com/affaan-m/ECC` then `/plugin install ecc@ecc`
- [x] Copy ECC common rules to `~/.claude/rules/ecc/` (see README §2)
- [x] Install OpenSpec: `npm install -g @fission-ai/openspec`, then `openspec init` in the repo (pick Claude Code)
- [x] Build and register the Godot MCP (`Coding-Solo/godot-mcp`), confirm `claude mcp list` shows it
- [ ] Register the AWS and GitHub MCP servers; export `AWS_PROFILE` and `GITHUB_PERSONAL_ACCESS_TOKEN`
- [x] Clone the GitHub repo (`onezoftserv/90miles`); it already exists, so no `git init`
- [x] `./tools/clone_references.sh` (reference games into git-ignored `reference/`)

## 1. Assets (~2 hours)

- [x] `python -I tools/fetch_assets.py` for the Kenney packs
- [ ] Manually download the OpenGameArt sea creatures, beach/boat tiles and freesound ambience listed in `docs/ASSETS.md`
- [x] Download "Press Start 2P" or "Pixelify Sans" (check ñ and accents render)
- [x] Create `game/assets/CREDITS.md` with every pack, author, license, URL
- [x] Import everything in Godot; set `texture_filter = nearest` project-wide

## 2. Project skeleton (change: `project-skeleton`)

- [x] Create `game/project.godot` (640×360, integer scale, GDScript, GUT addon)
- [x] Autoloads: `GameState`, `NetManager`, `WeatherManager`, `DialogueService`, `AudioManager` (stubs)
- [x] Folder layout from README; `tests/smoke.gd` that boots and quits
- [x] CI: GitHub Action running the headless smoke test and GUT

## 3. Milestone A — Two players on a handmade island

- [x] `player-movement`: walk, run, crouch, swim, dive, interact
- [x] `coop-networking`: host/join, spawner, synchronizer, quick chat
- [x] `survival-meters`: all six meters with the §4 numbers, HUD bars
- [x] `ui-shell`: title, host/join lobby, HUD layout, game theme, display scaling, pixel filter
- [x] `coop-reconnect`: stable player id, rejoin within 90 s reclaims the body, removed players count as dead
- [x] Handmade sandbar scene: hut, 6 palms, flotsam line, tide pools (`sandbar-island` change, archived 2026-11-06)
- [x] `crafting-inventory`: inventory, pick-up, coconut, rain cup, workbench, fire
- [x] `weather-daynight`: 12-minute day, CanvasModulate, calm/squall only
- [ ] Playtest: can 2 players survive 3 days? Tune drains.

## 4. Milestone B — Leave the island

- [x] `escape-routes`: raft build site (shared), binoculars-swim
- [x] `crossing`: scrolling sea, raft integrity, squall event, fall-in and rescue
- [x] `crossing-late-join`: a client that joins or rejoins mid-crossing sees the crossing and the route departures
- [ ] Arrival on a second handmade island (coast cay)
- [ ] `creatures-ai`: reef shark (patrol/circle/strike), crabs, gulls
- [ ] Death, run summary with the Cuban one-liner, restart
- [ ] `secret-cay` (OpenSpec change written 2026-11-06; `escape-routes` is merged and archived, so it is ready to build): the four secret items (`brujula_rota`, `mapa_sin_norte`, `sombrero_cinta_roja`, `nota_llegaste_tarde`), `secret_tuning.tres`, concealment with a shimmer and a dig hold, hiding spots, the broken-compass needle on the HUD, the hidden cay `cayo_sin_norte` (off-graph) with its empty chest, note and hat, the note on a HUD label, the hunt and cay dev scenes, 1-player and host-plus-client tests. Nothing reaches a real run yet. Later, each when its capability exists:
  - [ ] Place the pieces in real runs (1 run in 3, two islands from 2 to 5): island-generation, the run seed and run state
  - [ ] The crossing to the cay and back, and the needle holding the cay's bearing: crossing and arrival
  - [ ] The *Seguir la aguja* departure choice: the run graph, the branch-choice UI, party-scoped conditions (and the open questions in the change's design.md)
  - [ ] Wearing the red-band hat (heat −30%, never blown off): the first equipment change
  - [ ] The hat as a cross-run cosmetic for everyone present: keepsakes or a profile cosmetic shelf
  - [ ] Reading panels for the note and the map: npcs-dialogue found texts
  - [ ] Secrecy checks in charts, binoculars, the lighthouse, *Pedazo de mapa*, Tomás, Experiencia map knowledge, HUD markers and the AI prompts, as each is built

## 5. Milestone C — Procedural islands

- [ ] `island-generation`: seeded landmass, bands, POI placement, validation
- [ ] Chain templates: sandbar, coast, mangrove, reef, rock (data in `.tres`)
- [ ] Resource rules and respawn hooks (squall, night)
- [ ] Run structure: 6–8 islands with branching (`endings-progression` part 1)
- [ ] Remaining routes: turtle, tarp sail, dolphins, signal boat, repair wreck, Gulf Stream

## 6. Milestone D — Threats and stealth

- [ ] `guardacostas-stealth`: patrol loop, searchlight cone, hidden states, smoke/noise bus
- [ ] Shore squad, capture, free-a-captive, `la_captura` scene
- [ ] Eels, barracuda, man o' war, mosquitoes, crocodile grab, fire ants, manchineel
- [ ] Bosses: cutter chase, old crocodile nest, tiger shark dives
- [ ] Lighthouse, storm key, shipwreck reef and final approach chains
- [ ] Hurricane night and the Florida Straits crossing

## 7. Milestone E — People

- [ ] `npcs-dialogue`: NPC resource, dialogue UI, quests, companions, found texts
- [ ] Handwritten lines for all minor NPCs, story beats, endings (Spanish, then English)
- [ ] Companions: Dayana, Papo, El Chino with needs and skills; Yunior
- [ ] Ramón, Caridad, Rodríguez quests and ending flags
- [ ] Endings: five scenes with slots; `endings-progression` part 2
- [ ] Keepsakes, Experiencia carry-over and levels, Experiencia point shop
- [ ] Backgrounds: six, with starting items and skill growth

## 8. Milestone F — AI dialogue

- [ ] `backend/`: SAM template, Lambda, Bedrock Haiku 4.5 call with JSON schema, DynamoDB cache, API key issuance, rate limits
- [ ] `backend/prompts/style.md` and `slang.md`; NPC profiles for the 7 important NPCs; text profiles for the 4 important texts
- [ ] `backend/mock_server.py` for offline dev
- [ ] `DialogueService` client with 3 s timeout and fallback
- [ ] Test Haiku's Cuban Spanish on 50 sample contexts; iterate the style guide
- [ ] Cost check: ≤ $0.05 per run

## 9. Milestone G — Voice and polish

- [ ] Record 6–8 Cuban voices (written permission); clone with Chatterbox; generate all handwritten lines (`tools/gen_voice.py`)
- [ ] Emotion grunt clips for AI lines; Kokoro runtime TTS behind a flag
- [ ] Music: Músico songs, ending themes (CC-BY or commissioned)
- [ ] Profanity toggle, English localization pass
- [ ] Set pieces (Brogue machines): six from `docs/ISLANDS.md`
- [ ] Challenges, seeds, daily run
- [ ] Steam/relay joining (post-v1)

## 10. Content batches (data entry, parallel to milestones C–E)

Source: `docs/CONTENT_MANIFEST.md` (~315 `.tres` files). Each batch is one OpenSpec change, max 30 files, must load in Godot.

- [ ] content-batch-1: creatures 1–20
- [ ] content-batch-2: creatures 21–40
- [ ] content-batch-3: items water, food, plants
- [ ] content-batch-4: items tools, materials, wearables
- [ ] content-batch-5: items oddities, keepsakes, texts; recipes
- [ ] content-batch-6: NPCs, companions, animals; AI profiles in `backend/prompts/npcs/`
- [ ] content-batch-7: chains (18), weather (11)
- [ ] content-batch-8: POIs (~45)
- [ ] content-batch-9: set pieces (15), routes (8), backgrounds (6)
- [ ] content-batch-10: handwritten dialogue (minor NPCs, beats, endings, quick-chat, death lines)
- [ ] content-batch-11 (balsero gear, 19 files): routes `almendron` and `tabla`, recipes 4, items 11, keepsakes `llave_almendron` and `pluma_galleguito`. Routes and the key need `Vessel.CAR` and `Vessel.BOARD` (`balsero-lore` task group 6)
- [ ] content-batch-12 (balsero world, 16 files plus entry edits): creatures `galleguito`, `pajarito`, `pajaro_bobo`, `rabihorcado`, POIs 5, set pieces `balsa_en_la_sala` and `el_pilote`, texts 3, dialogue `beat_galleguito` and `beat_pies_secos`. The gull needs `Behavior.PERCH_RIDE`, the two ambient birds `ambient.gd`

## 11. Lore, stories and asset review (start alongside the content batches; finish before Milestone G)

Each review is its own OpenSpec change; findings go back into the docs and the affected `.tres` files.

- [ ] History and lore review: every historical claim in `docs/LORE.md` and the balsero found texts (entry 2 of *El sobre de tres generaciones* gets the final say), plus the lore, found texts, item descriptions and loading tips is checked against its sources; nothing names real people or puts invented words in real politicians' mouths; deaths are treated with respect while the satire stays aimed at the system
- [ ] Background stories review: every NPC backstory in `docs/CHARACTERS.md`, the six backgrounds and the companions are checked for consistency with the history, the timeline (the canonical present year) and each other, and for the Cuban voice
- [ ] Asset audit, one row per content entry (creatures, items, NPCs, companions, POIs, vessels such as the car-boat and surfboard, set pieces, UI, ambient birds like the head-sitting seagull): the asset found or missing, its source, license, resolution (16×16 tiles and characters) and fit; packs with the wrong size or style are flagged
- [ ] Decide character height: 16×16 (today's Kenney bases) or 16×24 (same 16×16 tiles, taller characters with room for faces and expressions). Compare side-by-side mockups at 1920×1080 (3×) and 1366×768 (2×), as in the 2026-11-05 fullscreen previews, then update `CLAUDE.md`, `docs/ASSETS.md` and the placeholder sprite to the choice
- [ ] Decide per missing or poor-fit asset: a better free asset (CC0 preferred, CC-BY credited) or our own pixel art, with a shared palette and an animation list (walk cycles at the chosen character height)
- [ ] Create or commission the "make it ourselves" art, commit it to tracked folders with its license, and update `game/assets/CREDITS.md` and `docs/ASSETS.md`

## Done

- 2026-11-05: Tooling: Godot 4.7.2 (winget), ECC plugin, OpenSpec 1.16 (`openspec init`, Claude Code), reference games cloned. Still open: ECC rules copy, Godot MCP build and registration, AWS and GitHub MCPs (each needs the user).
- 2026-11-05: Assets: 9 Kenney packs (CC0) and both OFL pixel fonts via the fixed `tools/fetch_assets.py`; `game/assets/CREDITS.md`; Spanish glyph coverage tested. Manual downloads still open.
- 2026-11-05: `project-skeleton` change: project, 5 autoload stubs, content catalog and validator, 34 data classes for the 11 content folders, GUT 9.7.1, smoke run, CI workflow (not yet run on GitHub). Open design questions: `data-model-questions.md` in the project-skeleton change; repo review: `docs/reviews/2026-11-05-repo-review.md`.
- 2026-11-05: `player-movement` change implemented test-first (GUT 178/178, smoke and a 300-frame run clean); provisional choices confirmed; archived with `project-skeleton` after the first CI run passed. Decided: host authority with prediction, heat rises with retuned drains, 16×16 characters.
- 2026-11-05: ECC common rules copied to `~/.claude/rules/ecc/`; Godot MCP built and registered (user scope, Godot 4.7.2 console binary); AWS MCP connected after `aws login --profile control-plane-test` (that profile is a full-access role). GitHub MCP still open: it needs the user's fine-grained token (README §5).
- 2026-11-05: `survival-meters` change implemented test-first (GUT 302/302, smoke and a 300-frame run clean): six meters in `SurvivalMeters` with the numbers in `game/resources/survival_tuning.tres`, meters-owned downed state (90 s plus downed-timer bonuses, revive at 30), sunstroke slowing movement, HUD bars with the sunstroke blur in the movement playground, and the clock (30 s per in-game hour, dawn 06:00). Solo play (user-approved): a player with no other living player gets a last stand of 0 s plus their downed-timer bonuses instead of being downed (death at once on run 1), the Medalla's free revive stands its holder at 30 once per run, a lit fire keeps a lone player company at night, and one player gets through 3 sandbar days on 9 coconuts. Provisional until the playtest and the user's confirmation: thirst 6/min (×2 sun, ×3 swim, ×0.5 night), hunger 3/min, heat ±45/min with sunstroke 100→60, and the ten rules in the change's proposal.md. Not archived yet. The 3-day sandbar check assumes crafting-inventory rescales the still to 1 cup per 6 real minutes.
- 2026-11-05: `coop-networking` change implemented test-first (GUT 478/478 after merging survival-meters, import, smoke and a 300-frame run clean; a host and a client run as two local processes): ENet behind `NetPeers`, `NetManager` host/join/solo, `CoopSession` (spawners, world state on join, 4-player cap, intent RPC rules, per-client rate limits, 90 s downed on disconnect, host-lost screen), host authority with client prediction, reconciliation and interpolation, quick chat as content, co-op dev playground. Solo is offline and first-class; approved: difficulty counts living, connected players (one player gets the base numbers) and solo pause freezes the simulation (co-op has no pause). Not archived: proposal.md lists the remaining provisional decisions and questions (split parties, reconnect identity, platforms, opening a solo run to joiners, quick chat in solo).
- 2026-11-05: `ui-shell` change implemented test-first (GUT 553/553, import, smoke and a 300-frame run clean; a host and a client went title → lobby → run through the shell as two processes): whole-number window fit and F11/Alt+Enter fullscreen, crisp Pixelify Sans 16/32 and Press Start 2P 8, one project theme with tracked CC0 Kenney 9-slices, a title over a sunset sea, settings, join, lobby (names once per peer, players spawn when the host starts), run HUD (labels inside the meter bars with a critical pulse, day phase, teammates and name tags in co-op only, no quick chat in solo), a run summary and a "Filtro de píxeles" setting (Nítido, pixel-identical to before; Suave, a Scale2x shader on the world only, written from the published rules; captures in `docs/ui-shell/`). Ideas from Shattered Pixel Dungeon, Brogue CE and DCSS (no code). Not archived: proposal.md lists provisional decisions (fullscreen by default?, fonts, palette, default name, spectating when dead).
- 2026-11-05: `coop-reconnect` change implemented test-first (GUT 703/703, import and smoke clean; a host, a client that quit, and a second client process from the same settings file rejoined through the shell as three processes): a random player id and secret per install (`[player]` in `user://settings.cfg`), carried by the join request and kept by the host as id → peer and a SHA-256 of the secret, never sent to other clients; a rejoin within the 90 s downed window, or while the host still holds a crashed client's dead connection, takes back the same body node (re-bound to the new peer: meters, inventory, position), and the body stands unless its meters downed it; a wrong secret, no id or the host's own id joins as a new player; players spawn on the join request, and a peer silent for 10 s is disconnected; removed players count as dead (`removed_names()`, listed as "Murió" in the run summary, and read by endings and Experiencia once they exist). Not archived: proposal.md lists four decisions to confirm (a failed claim joins as new, plain-text secret over ENet, the node keeps its first name, the 10 s timeout).
- 2026-11-05: `sandbar-island` change implemented test-first (GUT 695 tests, import, smoke and a 300-frame run clean): the sandbar is `game/resources/islands/sandbar.tres` (text rows + glyph legend, 64×40), read by `IslandLayout` into `SandbarIsland` (hut with workbench and 4 pick-ups, 6 palms with 10 coconuts climbed by a 2 s hold costing 5 energy, the flotsam line, 6 beach driftwood and 3 dry grass, 3 tide pools); the host places pick-ups through a new `PickupSpawner` and puts flotsam and beach driftwood back when a squall ends; solo spawns 3 tiles from the hut, co-op spawns are 10-20 tiles apart. Provisional: driftwood 8 (3 solo days need 9 or one squall), climb 5 energy, 64×40 map. Not archived; archive after ui-shell, weather-daynight and crafting-inventory. Follow-ups: tide, shiny item, bottle note, Experiencia bonuses, party scaling, palm counts synced to clients, removing `DevIsland`.
- 2026-11-06: `escape-routes` change implemented test-first (GUT 732 tests, import, smoke and a 300-frame run clean): routes are data (`routes/raft.tres`, `routes/binoculars_swim.tres`), `IslandRoutes` + `RouteLauncher` start a route on the host from a client request naming only the route and pick the riders by capacity, the sandbar has a shared raft build site (6 driftwood, 2 tubes, 3 rope, 60 s) whose state reaches every peer, binoculars-and-swim needs calm, energy 100 and no bleeding, and `CrossingStub` takes riders off the island and ends the run when everyone has left or died. Owner: 3 rope on the sandbar (hut +2), no binoculars placed yet. Confirmed by the owner (2026-11-06): 60 s raft work for any party, 5-tile automatic boarding, one pair of binoculars for the group, a fresh site after launch, 1 s launch hold. Archived 2026-11-06. Follow-ups: crossing replaces `CrossingStub`; binoculars in the rock cairn and captain's chest; Mecánico/pliers build speed; bleeding causes, bandages and status sync; discovery sync and map UI; a "me quedo" choice.
- 2026-11-08: `sandbar-size` change implemented test-first (GUT 735 tests, import, smoke and a 300-frame run clean): the sandbar is now 80×72 with 991 land cells in an open crescent opening east, an arc of about 90 tiles, POIs spread along it, and co-op spawns 20–30 tiles from the next in join order (owner's decision, 2026-11-06; the plan's C-shaped lagoon was rejected). Only the rows of `sandbar.tres` changed. Provisional: the 940–1,100 land band, the 1-player walk bands (palms 6–11 s, raft site 4.5–8 s, pools 13–17.5 s) and all cell positions. Not archived.
- 2026-11-08: `crossing` change implemented test-first (GUT 771 tests, import, smoke and a 300-frame run clean): `Crossing` replaces `CrossingStub` with a scrolling sea, the raft at its launched integrity (squall -30, shark -20, rock -40), a plan rolled on the host, the squall warned 60 s ahead through the existing weather warning and `HorizonLine`, tie-down (1 s), fall-in (-10 energy, 3 energy/s in the water times the route factor, drowning at 0), pull (2 s) and solo climb (3 s), `CrossingThreats` as the hook for the reef shark, and `ArrivalStub` plus `CrossingResult` at the end. Confirmed by the owner (2026-11-06): every untied rider is thrown by a squall, swimmers drain and drown, swim drain 0.4, fall-in 10, raft 60-90 s and swim 60 s, shark pass 0.5 and rock 0.25 on the coast, no steering and drift 0. Follow-ups: arrival on the next island replaces `ArrivalStub`; the reef shark behind `CrossingThreats`; steering and the Gulf Stream on mid and far crossings; searchlights and the cutter; item loss in water; a life vest; host-and-client hand test; crossing art and the sea shader; bleeding status sync to clients.
- 2026-11-08: `coop-reconnect` after merging `crossing` (GUT 816/816, import and smoke clean): the crossing takes a rider's peer from `CoopSession.peer_of` (lashing and rescue points), and the crossing's riders (slot, state, climb and pull points) and the route departures move to the new peer on `player_rebound`, on every peer; `test_reconnect_crossing.gd` and a route test. Known gap, left out: a client that joins or rejoins during a crossing has no crossing on its screen (the host keeps the rider).
- 2026-11-08: `creatures-ai` change implemented test-first (GUT 812+ tests, import, smoke and a 300-frame run clean; not archived): reef shark, land crab and seagull are `.tres` files read by one generic host-run `Creature` with three state machines (`patrol_circle_strike`, `night_thief`, `swoop_steal`), land and water `AStarGrid2D`s with the shark's 2-tile shore margin, a `CreatureSpawner` on the sandbar (crabs at night with the fire halving and party scaling, gulls at two nest palms, one offshore shark) and `CreatureThreats` behind the crossing's shark pass. Owner-confirmed: held food is the first food slot on land (D3), one offshore sandbar shark (D6).
- 2026-11-08: `crossing-late-join` change implemented test-first on top of `coop-reconnect` (GUT 887/887 after merging `main` with `creatures-ai`, import, smoke and a 300-frame run clean; a host and a client process through the shell, the client joining 5 s into the host's raft crossing, both with zero error lines): after the join reply the host sends `IslandRoutes.receive_progress` with the route departures (applied without starting anything), the crossing counter and a checked `CrossingSnapshot` of each crossing under way (serial, route, riders in slot order, plan, clock, states, positions, vessel maximum, value and break); the joiner builds or refreshes each with `Crossing.restore`, its riders on sea ground with the camera kept to the sea and nothing replayed; a crossing sends its plan, states and result only to peers that have it, so no peer gets a message for a node it lacks; the joiner's shell follows restored crossings and hides riders whose crossing already ended; a break now sinks the deck on clients too. Confirmed by the owner (2026-11-08): riders of an ended crossing are hidden on a joiner as on the host, riders appear where the host has them, and the joiner's clock starts at the host's time with nothing replayed. Archived 2026-11-08. Follow-ups queued: the reef shark seen by clients during a crossing, and bleeding status reaching clients.
