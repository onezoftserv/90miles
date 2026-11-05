# 90 Millas — Tasks

Ordered. Tick as you go; Claude Code keeps this file current. Each coding task maps to an OpenSpec change (`/openspec:proposal <name>`).

## 0. Tooling (one-time, ~1 hour)

- [ ] Install Godot 4.4+ and open it once
- [ ] Install Claude Code: `npm install -g @anthropic-ai/claude-code`
- [ ] Install ECC: `/plugin marketplace add https://github.com/affaan-m/ECC` then `/plugin install ecc@ecc`
- [ ] Copy ECC common rules to `~/.claude/rules/ecc/` (see README §2)
- [ ] Install OpenSpec: `npm install -g @fission-ai/openspec`, then `openspec init` in the repo (pick Claude Code)
- [ ] Build and register the Godot MCP (`Coding-Solo/godot-mcp`), confirm `claude mcp list` shows it
- [ ] Register the AWS and GitHub MCP servers; export `AWS_PROFILE` and `GITHUB_PERSONAL_ACCESS_TOKEN`
- [ ] `git init`, first commit, create the GitHub repo, push
- [ ] `./tools/clone_references.sh` (reference games into git-ignored `reference/`)

## 1. Assets (~2 hours)

- [ ] `python -I tools/fetch_assets.py` for the Kenney packs
- [ ] Manually download the OpenGameArt sea creatures, beach/boat tiles and freesound ambience listed in `docs/ASSETS.md`
- [ ] Download "Press Start 2P" or "Pixelify Sans" (check ñ and accents render)
- [ ] Create `game/assets/CREDITS.md` with every pack, author, license, URL
- [ ] Import everything in Godot; set `texture_filter = nearest` project-wide

## 2. Project skeleton (change: `project-skeleton`)

- [ ] Create `game/project.godot` (640×360, integer scale, GDScript, GUT addon)
- [ ] Autoloads: `GameState`, `NetManager`, `WeatherManager`, `DialogueService`, `AudioManager` (stubs)
- [ ] Folder layout from README; `tests/smoke.gd` that boots and quits
- [ ] CI: GitHub Action running the headless smoke test and GUT

## 3. Milestone A — Two players on a handmade island

- [ ] `player-movement`: walk, run, crouch, swim, dive, interact
- [ ] `coop-networking`: host/join, spawner, synchronizer, quick chat
- [ ] `survival-meters`: all six meters with the §4 numbers, HUD bars
- [ ] Handmade sandbar scene: hut, 6 palms, flotsam line, tide pools
- [ ] `crafting-inventory`: inventory, pick-up, coconut, rain cup, workbench, fire
- [ ] `weather-daynight`: 12-minute day, CanvasModulate, calm/squall only
- [ ] Playtest: can 2 players survive 3 days? Tune drains.

## 4. Milestone B — Leave the island

- [ ] `escape-routes`: raft build site (shared), binoculars-swim
- [ ] `crossing`: scrolling sea, raft integrity, squall event, fall-in and rescue
- [ ] Arrival on a second handmade island (coast cay)
- [ ] `creatures-ai`: reef shark (patrol/circle/strike), crabs, gulls
- [ ] Death, run summary with the Cuban one-liner, restart

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

## Done

(move finished items here with the date)
