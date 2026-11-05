# 90 Millas — Game Design

Version 1.0 · November 2026 · Reviewed and consolidated from the original design doc.

## 1. Pitch

You are Cuban balseros. Your raft breaks apart off the coast at night, and you wash up on a sandbar with whatever you could hold. Ninety miles of open water, sharks, storms and the *guardacostas* stand between you and land. Every island is a problem: survive it, then find a way off it. Reach the other side, and the ending depends on who you brought with you.

A 1–4 player co-op survival roguelite. Real-time, 2D top-down pixel art, built in Godot 4.

## 2. Decisions

| Item | Decision |
| --- | --- |
| Genre | Survival roguelite, island-hopping crawler |
| Players | 1–4 online co-op (host and join); solo is the same game |
| Engine | Godot 4.7, GDScript |
| View | 2D top-down pixel art, 16×16 tiles |
| Time model | Real-time, Don't Starve Together pace; a full day is 12 real minutes |
| Run length | 6–8 islands, 60–90 minutes |
| Language | Spanish original; English keeps key slang |
| Rating | Mature: swearing, political satire, danger |
| Tone | Dark comedy with real stakes; Cubans laughing at the worst day of their lives |
| Backend | AWS Bedrock (Claude Haiku 4.5) for key dialogue; Lambda + API Gateway |

## 3. Core loop

1. **Shipwreck intro.** The raft sinks at night; each player chooses what to grab (one of three items floating by).
2. **Wash up.** Players land on the first cay, scattered along the shore, and must find each other.
3. **Survive.** Manage thirst, hunger, heat, energy and morale through a day-night cycle.
4. **Explore.** Scavenge, meet NPCs, find texts, discover the island's two or three escape routes.
5. **Prepare.** Gather materials, finish quests, wait for the right weather or patrol gap.
6. **Cross.** A short open-water sequence: sharks, currents, storms, searchlights.
7. **Arrive.** The next island, farther out and harsher. Repeat.
8. **Finish.** Reach land. The ending plays based on who made it.

### Every run is different

- Islands are generated fresh each run from chain templates (see `ISLANDS.md`).
- After island 1 the route branches (mangroves, reefs, storm keys). You cannot see every chain in one run.
- The order of NPCs, found texts and events is shuffled. Important NPCs can appear on any island and their AI-generated lines react to what has happened so far.
- Seeded runs let friends share a seed. Daily runs use the date.

## 4. Survival meters

Thirst is the main pressure; everything else makes it harder to manage.

| Meter | Max | Drains from | Restored by | At zero |
| --- | --- | --- | --- | --- |
| Thirst | 100 | 1/min base, ×2 in sun, ×3 swimming | Coconut 15, rain cup 25, still 40 | Health drains 2/s |
| Hunger | 100 | 0.5/min, ×2 while working | Crab 20, fish 30, eggs 10, sea grapes 5 | Energy cap halves |
| Heat | 100 (cool) → 0 | Midday sun 2/min, no shade | Shade, night, water | Sunstroke: blurred screen, speed −40% |
| Energy | 100 | Swimming 3/s, building 1/s, running 0.5/s | Sleep (+50 per night), food | Collapse: can only crawl |
| Morale | 100 | Loss of ally −30, storm −10, alone at night −5/min | Teammate nearby +2/min, fire +5, keepsake, music | Hallucinations: fake islands, fake voices |
| Health | 100 | Attacks, thirst, heat | Aloe, rest, noni | Downed |

**Downed, not dead.** A player at 0 health is downed for 90 s. Teammates can drag them to shade and give water to revive. Solo players, or an unrevived player, die: permadeath for the run.

**Drinking seawater** restores 10 thirst, then drains 30 over the next two minutes. Desperate players will do it anyway. That is the point.

## 5. Weather and time

A day is 12 real minutes: dawn (1), day (5), dusk (1), night (5).

| Weather | Effect | Tell |
| --- | --- | --- |
| Scorching calm | Heat ×2, no wind for sails, clear horizon (binoculars work) | White sky |
| Trade wind | Sails work, raft drifts east if unsteered | Palms lean |
| Squall | 2-minute storm: raft damage, fire goes out, patrols stay in port | Dark line on horizon 1 min before |
| Fog | Islands hidden, searchlights useless, sharks hunt by smell (blood matters more) | Gray screen edges |
| Hurricane (storm key only) | Environmental boss: survive the night, rebuild | NPC warns a day ahead |

Tides flip every half day. Low tide exposes reef paths, tide pools and the man o' war; high tide floods mangrove paths and lets the repairable boat float.

Night is cooler (thirst ×0.5) but dark. Searchlights, crocodiles and crabs come out. Players need a fire, which the patrols can see.

## 6. Resources and crafting

| Resource | Where | Used for |
| --- | --- | --- |
| Driftwood | Any beach, more after storms | Raft, fire, spear shaft |
| Inner tubes, plastic jugs | Wreck lines, flotsam | Raft flotation, still, water storage |
| Rope, fishing line | Wrecks, lobster traps, fisherman | Raft lashing, fishing, turtle harness |
| Tarp | Wrecks, camp ruins | Sail, shade, rain catcher |
| Coconuts | Palms (climb or throw) | Water + food |
| Crabs | Beaches at night, tide pools | Food (cook or raw with risk) |
| Fish | Shallows (spear), deep (line) | Food, bait for turtle |
| Bird eggs | Rocky keys, nests | Food; gulls defend them |
| Sea grapes, coco plum | Dunes | Light food, no thirst |
| Aloe, noni | Dunes, mangrove edge | Heal sunburn and cuts |
| Unknown fruit | Everywhere | Food or poison until identified |
| Nails, resin, cloth | Wrecks, camps | Upgrades |
| Keepsakes | Found texts, NPC gifts | Morale, run modifiers |

**Crafting** happens at a workbench (any flat rock or wreck table). Recipes are data (`.tres`). Core recipes: raft (6 driftwood + 2 tubes + 3 rope), solar still (jug + tarp + rocks), spear (driftwood + knife), rain catcher (tarp + 4 sticks), sail (tarp + mast + rope), mirror signal (any mirror), fire (3 driftwood + dry grass + friction or lighter).

**Identification.** Unknown fruit shows as "fruta roja" until someone eats it or an NPC names it. Manchineel looks like a small green apple and burns you from the inside. Once one player learns a plant, the party knows it.

**Durability.** Tools wear out. The raft loses 25% integrity per crossing and more in squalls; repair with driftwood and rope.

## 7. Escape routes

Each island rolls two or three. Routes are the "stairs".

| Route | Needs | Risk | Capacity |
| --- | --- | --- | --- |
| Build a raft | 6 driftwood, 2 tubes, 3 rope | Slow; breaks in squalls | Everyone |
| Repair the wreck | Boat in mangroves + nails, resin, oars or fuel | Quest-heavy; safest crossing | Everyone |
| Ride the turtle | Free Vieja from a net, feed her 3 fish | She dives if frightened | 2 |
| Binoculars and swim | Clear weather, 100 energy, bandaged cuts | Sharks, exhaustion | Each swimmer |
| Tarp sail | Raft + sail + trade wind | Wrong wind drifts you east | Raft-sized |
| Follow the dolphins | Find the pod at dawn, swim with them | Low; timing only | Everyone, swimming |
| Signal a fishing boat | Fire or mirror at the right hour | Boat may not stop; patrol may see fire | Everyone |
| Ride the Gulf Stream | Compass + charts + navigator skill | Fast; easy to overshoot | Raft-sized |

The turtle's two-seat limit and the swimmer's energy cost are intentional: a 4-player party often has to split routes and meet on the next island.

## 8. The crossing

A 60–120 second sequence on a scrolling sea. Threats roll by distance from Cuba and weather: reef sharks follow blood; a squall line forces you to tie down; searchlights sweep from a cutter on the early chains; the Gulf Stream pushes east and the navigator must correct. Falling in the water costs energy and attracts sharks. The raft takes damage; at 0 it breaks and everyone swims the rest or drowns.

## 9. Threats

Full lore and behavior specs in `BESTIARY.md`. Summary:

| Threat | Behavior | Reference archetype |
| --- | --- | --- |
| Reef shark | Circles; strikes when you bleed | DCSS shark frenzy |
| Moray eel | Hidden in reef holes; ambush | Brogue eel |
| Barracuda school | Swarm shiny objects | Brogue jackal pack |
| Portuguese man o' war | Passive drifting trap; paralysis sting | SPD / Brogue traps |
| Land crabs | Night thieves; steal from stashes | SPD sewer crab |
| Seagulls | Steal food and flee | Brogue monkey |
| Mosquito cloud | Energy drain at dusk | Brogue / DCSS gas |
| American crocodile | Drags you under in still water | Brogue bog monster |
| Guardacostas | Patrol routes, searchlights, shore squads, capture | Brogue stealth/noise |
| Weather | Environmental pressure | Brogue terrain effects |

**Bosses**, one per chain: the guardacostas cutter (coast), the old crocodile (mangroves), the tiger shark (reef), the hurricane (storm key), the Florida Straits (final crossing).

### Guardacostas and stealth

The human threat on the first two or three islands, fading as you head north. Patrol boats run fixed routes; at night a searchlight cone sweeps beach and water. Smoke or fire draws a shore squad that searches the island for three minutes. A caught player is taken aboard: teammates can free them by sneaking onto the boat at the dock; a solo player loses their items and restarts the previous island. Stealth is a skill: crouching in brush, diving, hiding in mangroves and putting out fires all count.

## 10. Characters and co-op

### Backgrounds

Each player picks a background at the start; it sets starting items and a skill that grows with use.

| Background | Starts with | Skill |
| --- | --- | --- |
| Pescador | Fishing line, knife | Fishing: faster catches, reads the tide |
| Mecánico | Pliers, nails | Building: faster rafts, repairs wrecks |
| Médico | Bandages, aloe | Medicine: better healing, identifies plants |
| Maestro | Notebook, pencil | Navigation: reads stars, spots islands, finds texts |
| Músico | A guitar with two strings | Morale: songs restore the party, dolphins come closer |
| Ex-militar | Machete | Stealth and combat: quieter, hits harder |

Any player can do anything; backgrounds do it better. In solo, the player picks one and the game is tuned for it.

### Co-op rules

- Host-and-join, up to 4. Host is authoritative.
- A raft needs everyone's materials; crafting a shared project pools inventories.
- Downed players can be dragged, revived with water, and fed.
- Morale is shared: losing a player hits everyone.
- Difficulty scales: resources ×0.8 per extra player, patrols +1 per 2 players.
- Voice chat is not built in; players use their own. Quick-chat wheel with Cuban phrases (*¡Dale!*, *¡Agua!*, *¡Pa'llá no!*, *¡Tiburón!*).

## 11. NPCs

Full backstories in `CHARACTERS.md`. Important NPCs (AI dialogue) are **Ramón** the fisherman, **La Vieja Caridad** the lighthouse hermit, **Yunior** the kid, **El Capitán Rodríguez** (guardacostas), and the rescued balseros **Dayana**, **Papo** and **El Chino**. Minor NPCs use handwritten lines.

Rescued balseros join your party as AI companions (like Brogue's freed captives). Each needs something to survive the trip and each changes the ending.

## 12. Found texts

Bottle notes, journals, wet letters, radio fragments and wall graffiti. They carry lore, hints and the political voice of the game. Important texts (found every run, AI-generated and reacting to your run) include **La libreta de Ramón**, **El diario del Período Especial**, **Las cartas de la Yuma** and **La lista**.

## 13. Endings

Decided: multiple endings, based on who you saved and how.

| Outcome | Ending |
| --- | --- |
| Everyone you met made it | *Todos.* The whole group walks up the beach together. |
| Your party made it, NPCs lost | *Los que llegamos.* Reunion on the pier; a chair stays empty. |
| Only one survivor | *Solo.* A long silent walk. A phone call home. |
| Captured on the final crossing | *Devuelto.* Fade on the deck of the cutter. Unlocks a keepsake. |
| Secret: Yunior reaches land | *El Niño.* A different voice reads the credits. |

## 14. Roguelite progression

Permadeath per run. Between runs you unlock **memories**: keepsakes you can start with.

| Keepsake | Effect | Unlock |
| --- | --- | --- |
| Foto de la familia | Morale drains 30% slower | Finish any run |
| Cuchillo del abuelo | Start with a knife | Kill a shark |
| Medalla de la Caridad | One free revive | Save La Vieja's quest |
| Nudo del pescador | Rafts 25% stronger | Cross 3 times by raft |
| Pedazo de mapa | Reveals one route on island 1 | Reach the storm key |
| Cassette de Los Van Van | Music works without a Músico | Finish with a Músico |

### Difficulty and carry-over ("Experiencia")

The game is hard from the first run: island 1 at full thirst drain, a patrol every 3 minutes, no tutorial beyond the shipwreck intro. Most first runs end on island 2 or 3. That is intended.

What makes the next run a bit easier is **Experiencia**: when you die, you keep a percentage of what you built up, and the world itself eases slightly. The first run is brutal; by run five it is hard; it never becomes easy.

| What you built | Kept on death | Kept on a win |
| --- | --- | --- |
| Skill levels (fishing, building, medicine, navigation, morale, stealth) | 50% of the XP earned that run, rounded down | 100% |
| Identified plants and fruit | All of them, forever | All |
| Discovered escape routes | Routes you used stay discovered on their chain for next run | All |
| NPC trust (Ramón, Caridad, Rodríguez) | 50% of trust earned; they remember you ("¿Tú otra vez?") | 100% |
| Recipes learned from NPCs | All | All |
| Map knowledge | Chain layouts you reached show POI icons on arrival next run | All |
| Keepsakes | Unlocked ones stay | Unlocked ones stay |
| Items | None | None |

Rules:
- Skills cap at level 5 per background skill and level 3 for the others; carry-over never pushes a skill above level 3 without a run that earned it.
- Each run also grants **1 Experiencia point** per island reached, spent at the start of the next run on small permanent boosts: +10 max thirst, +1 inventory slot, +10 s downed timer, start with a known plant, start with 1 rope. Max 12 points banked; spending is the only way to use them.
- **The world eases a little per death, capped.** Each death adds one "Experiencia level" (max 8). Per level: thirst and hunger drain −3%, patrol period +10 s, one extra driftwood and one extra coconut per island, downed timer +5 s. At the cap that is drains −24%, patrols at 4:20 instead of 3:00, and 8 extra materials per island: enough to feel the game meet you halfway, not enough to remove the pressure.
- Winning a run removes 2 Experiencia levels (the game gets harder again for a champion) and unlocks a keepsake.
- Seeded and daily runs earn Experiencia but do not spend it.

Challenges (optional hard modes): no fire, permanent storm season, sinking raft from the start, patrols on every island.

## 15. Cuban voice and humor

The game speaks like Cubans talk.

| Layer | Examples | Where |
| --- | --- | --- |
| Slang | asere, ¿qué bolá?, tremendo, la yuma, resolver, la lucha, no es fácil, pincha, jeva, fula | All dialogue |
| Political references | la libreta, la cola, los apagones, el Período Especial, slogans on walls, 1994 | Found texts, NPC stories, item descriptions |
| Ironic slogans | Revolutionary slogans repurposed as item names and loading tips | UI, loading screens |
| Profanity | coño, cojones, pinga, and stronger, in the right places | Reactions, shark attacks, storms |

Rules: satire targets the system, slogans and daily life, not invented quotes from real politicians. A settings toggle softens profanity. Haiku receives a style guide and slang glossary. Spanish first.

## 16. AI dialogue and voice

Claude Haiku 4.5 on Amazon Bedrock generates dialogue for **important NPCs and the texts found every run**, so the content players see most stays fresh. Minor NPCs, story beats, bosses and endings are handwritten.

| Item | Decision |
| --- | --- |
| Model | Claude Haiku 4.5 on Bedrock (~$1 in / $5 out per 1M tokens) |
| Cost | ~$0.0015 per line; a few cents per run |
| Pipeline | Godot `HTTPRequest` → API Gateway → Lambda → Bedrock |
| Input | Game-state JSON: island, weather, party, who was saved, items, NPC profile, run history |
| Output | `{speaker, text, emotion}` |
| Voice | Pre-generated Chatterbox (cloned Cuban voices) for handwritten lines; Kokoro at runtime for generated ones |
| Safeguards | Keys only in Lambda; per-player rate limits; cache by state hash; handwritten fallbacks offline |
| Fallback model | Amazon Nova Micro/Lite for low-stakes flavor if costs grow |

## 17. Technical plan

| System | Godot approach | Reference |
| --- | --- | --- |
| Island generation | TileMapLayer, noise island shape, rule-placed POIs | SPD room builders |
| Natural features | Mangroves, reefs, tide pools by placement rules | Brogue lakes and machines |
| Pathfinding and AI | AStarGrid2D; state machines per creature | Brogue Dijkstra maps |
| Data | Custom Resources (.tres) for items, creatures, NPCs, recipes | DCSS data files |
| Survival meters | `SurvivalMeters` component, host-synced | Original |
| Multiplayer | ENet, MultiplayerSpawner, MultiplayerSynchronizer | Godot docs |
| Weather and day-night | `WeatherManager` autoload driving CanvasModulate and spawns | Original |
| Stealth | Light cones with Area2D, noise events on a bus | Brogue stealth |
| Dialogue | `DialogueService` autoload with cache + fallback | Original |

### Tooling

| Tool | Purpose |
| --- | --- |
| Claude Code + ECC (`ecc@ecc`) | Agents, skills, hooks and rule packs for the daily workflow |
| OpenSpec | Spec-driven changes: proposal → apply → archive |
| Godot MCP (Coding-Solo/godot-mcp) | Run the project, read errors, create scenes from Claude Code |
| AWS MCP | Deploy and debug the Lambda and Bedrock calls |
| GitHub MCP | Issues and PRs |
| GUT | Unit tests for generation, meters, recipes |

### Build order

1. Player movement and co-op connection (2 players)
2. One handmade island with thirst, hunger and heat
3. Raft escape route and the crossing scene
4. Procedural islands and more escape routes
5. NPCs, weather, sharks, guardacostas
6. AI dialogue backend
7. Roguelite memories, endings, polish

### Reference use

All three references are copyleft (Shattered Pixel Dungeon and DCSS GPL, Brogue CE AGPL-3.0), so they are used for ideas and structure, never copied code.

## 18. Review notes

What changed from the first design doc, and why:

- **Meters now have numbers.** A design without numbers cannot be built or balanced; the values here are starting points for playtests.
- **Day length, run length and difficulty scaling are fixed** so co-op tuning has a target.
- **Backgrounds replace "roles".** Backgrounds carry starting items and a skill, which gives solo play a build choice too.
- **The crossing is its own scene.** It was implied before; it is where the game's tension peaks and deserves its own spec.
- **Endings are explicit**, including a secret one, so the "who you saved" rule has concrete outcomes to track.
- **Found texts are a system**, not a line in a table; they carry most of the political writing.
- **The faith mechanic was cut** at your request.
- **Reference material is mapped per system** so the OpenSpec specs can cite what to study.
