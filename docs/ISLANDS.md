# 90 Millas — Islands and Resource Places

Islands are generated from **chain templates**. A run is 6–8 islands: island 1 is always the sandbar; island 2 is always a coast-chain island; from island 3 the route branches between chains; the last island is always the final approach. Each island rolls 2–3 escape routes and 3–6 points of interest (POIs) from its chain's table. The one exception is the secret cay, an off-graph detour that never counts as one of the 6–8 islands and has only the routes its layout lists (see "Secret: El cayo sin norte").

Generation: `IslandGenerator` builds a landmass from seeded integer steps (height bumps along a spine, integer smoothing, a sea level picked by rank; no floating-point noise, so every peer builds the same island from the run seed) on a 96×64 tile grid, places biome bands (deep water → shallows → beach → dunes/mangrove/rock → interior), then places POIs with a rule set (min distance, shoreline access, no two of the same kind). Escape routes are POIs with a flag. See `openspec/specs/island-generation/spec.md`.

---

## Chains and distance

| Distance | Chains available | Threat level |
| --- | --- | --- |
| Islands 1–2 (coast) | Sandbar, Coast cay | Guardacostas at full strength, reef sharks |
| Islands 3–5 (mid) | Mangrove, Reef, Rocky key, Lighthouse | Crocodiles, barracuda, tiger shark, fewer patrols |
| Islands 6–7 (far) | Storm key, Shipwreck reef, Bahamas family | Hurricane, open water, no patrols |
| Island 8 (final) | Final approach | The Florida Straits |

---

## Chain templates

### 1. Sandbar cay (*el banco de arena*)

**Lore.** The first cay out of Cuba is barely an island: a crescent of sand with a dozen palms and a single ruined fisherman's hut. Every balsero who ever left washed up here or on one like it. The sand is full of flip-flops.

**Biome.** 70% beach, 20% dune with sea grapes, a few palms. No shade at noon except the hut. No fresh water except rain and coconuts.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Ruined hut | Tarp, 2 driftwood planks, a rusted knife, 2 rope, the first bottle note | Only shade; a workbench. The 2 rope are never refreshed |
| Palm grove (6 palms) | Coconuts, 8–12; climbing costs energy, throwing costs a coconut | Gulls nest in two of them |
| Flotsam line | Inner tubes ×2, plastic jugs ×3, rope ×1, random shiny item | Refreshes after a squall. With the hut the island holds 3 rope, the raft's 3 |
| Tide pools | Crabs at night, one man o' war, sea urchins (bleeding if stepped on) | Low tide only |
| La señora's camp | The woman who never left; water for stories | 50% chance |
| Raft for sale (*se vende balsa*) | A half-finished inner-tube raft with a hand-painted SE VENDE sign: 2 inner tubes, 3 driftwood, rope (50%), a note | 20% on either variant; the builder changed his mind. Salvage that speeds up the raft without replacing it |
| Scattered landing | Each player starts 20–30 tiles from the next in join order, spread along the arc | Co-op: find each other first |

**Escape routes.** Raft (always), binoculars-and-swim (the next island is visible on clear days), signal the fishing boat (Ramón, 30%).

**Threats.** Patrol every 3 minutes, gulls, crabs, the sun, and one reef shark offshore (deep and shallow water at least 2 tiles from shore; it circles swimmers and strikes only a bleeding swimmer or one below 20 energy; `creatures-ai`, owner-confirmed 2026-11-08; a spawn chance of 0 in `reef_shark.tres` turns it off).

---

### 2. Coast cay (*el cayo de la costa*)

**Lore.** Close enough to Cuba that on clear nights you see the glow of Havana. Close enough that the patrol passes twice an hour. A concrete observation post from the 1980s rots on the point, slogans still painted on it.

**Biome.** Beach, dunes, a rocky point, a small lagoon.

**Size.** Base variant, handmade (`coast_cay.tres`, owner-confirmed 2026-11-08): 88×64 cells, 1,021 land cells (18.1%) in a C of two 12-wide strips and a rocky spur round shallow flats, a long axis of 60 tiles (about 15 s) and a 42-cell brackish lagoon in the north-west corner. Four landing cells within 3 tiles of each other on the south-west beach. Walks from the first landing cell: raft site 3 s, flotsam 3–4 s, lagoon 7 s, aloe 8–9 s, rope cache 12 s, observation post 14 s. The lagoon never runs dry (thirst +10, then −5 after 30 s). Counts are fixed: nails ×4, mirror ×1, aloe ×4, rope ×4, lighter ×1, tubes ×2, jugs ×2, driftwood 8, 5 palms with 10 coconuts; no workbench, no noni yet.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Observation post | Nails, a mirror (signal), a dead radio, wall slogans | Best hiding spot from searchlights |
| The lagoon | Fresh-ish water (brackish: thirst +10, then −5), fish | Crocodile 20% on mid chains only |
| Dune with aloe | Aloe ×4, noni tree | |
| Rope cache | A buried bag: rope ×4, a lighter | Marked by a crossed-stick sign, Navigation ≥1 to notice |
| Ramón's cove | Ramón and *La Esperanza II* | 40% |
| Other balseros' camp | 2–3 NPCs competing for the palms | 50% |
| Raft for sale | As on the sandbar: 2 tubes, 3 driftwood, rope (50%), a note | Bunker 25%, village 30% |
| Fishermen's houses (village variant) | Grapefruit ×1–3 (respawns daily), bicycle tubes ×1–2, 2 drums (guaranteed), a botija (30%); in one house, a finished raft that does not fit the door (set piece) | Wall slogans on the walls, each with a reply written below |
| Village dock (village variant) | A fuel jug (guaranteed) | |
| The almendrón (village variant) | A rusted 1950s car behind the houses, drive shaft in place: pliers, a propeller, 6 nails, 2 drums, 2 rope, shade under the chassis | Rolled route, weight 0.6; "Detrás de las casas hay un almendrón. Flotar, no flota... todavía." |

**Escape routes.** Raft, Ramón's boat (quest), tarp sail (trade wind days), Gulf Stream (needs charts, rare this early). On the village variant, also the almendrón (rolled, never guaranteed; the raft stays guaranteed).

**Threats.** Patrols at full strength (searchlight every night), reef sharks, the cutter on the crossing out.

---

### 3. Mangrove cay (*el cayo de mangle*)

**Lore.** A maze of red mangrove roots and black water. Tourist excursions from Varadero used to come here for "eco" tours until one boat sank. Its wreck is still here, with its menu board.

**Biome.** 60% mangrove (slow movement, hidden from searchlights, no sun), channels (swim or wade), a sand spit, one dry hammock with hardwood.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Tourist boat wreck | Tarp ×2, life vests ×2, a cooler (sealed storage), rum | Las jineteras and El turista are here |
| The repairable boat | A fishing skiff on its side in a channel; needs nails ×6, resin ×2, oars or fuel | Guarded by the old crocodile's nest |
| Mangrove oysters | Food, 10 per cluster, no cooking needed | Cuts hands (bleeding) without gloves/cloth |
| Hardwood hammock | Mast-quality wood ×2, dry grass | Only dry campsite; mosquitoes at dusk |
| Crab mounds | Land crabs by the hundred at night | Food farm if you have fire |
| El Chino's hideout | El Chino, hiding from a patrol | 60% |
| Camp ruin | *El diario del Período Especial*; 40% *El sobre de tres generaciones* (the envelope) | |
| Rental shack (maze variant) | A wrecked excursion hut by the tourist wreck: 1–2 surfboards, a tarp, hardwood and 2 rope, all guaranteed; shade and a workbench | Rolled board route, weight 0.4; the tourist wreck can also hold a board (30%) |

**Escape routes.** Repair the boat (boss), raft (hardwood makes it stronger), follow the dolphins (dawn, from the sand spit). On the maze variant, also the board (trade wind; rolled, never guaranteed).

**Threats.** Crocodiles, mosquito clouds, the old crocodile (boss), patrols only at the spit.

---

### 4. Reef cay (*el cayo del arrecife*)

**Lore.** A limestone island ringed by a reef that drops to deep blue. Lobster traps everywhere, half of them Ramón's. The reef is beautiful and will cut you to pieces.

**Biome.** Rocky shore, a beach on the lee side, reef flats at low tide, deep water 3 tiles out.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Lobster traps (6) | Lobster (food 35), rope ×1 each, a moray in two of them | Ramón's quest |
| Reef flats | Fish (spear), sea urchins, man o' war, conch (food + shell horn) | Low tide only; rip current on the north side |
| The ghost net | Vieja the turtle, tangled | 70% |
| Limestone cave | Shade, fresh water seep (2 rain cups, refilled each dawn), bats | Only shade; echoes carry (noise ×2) |
| Palm grove (about half the reefs) | 3 palms, 5 coconuts | The reef's only coconuts; the other reefs have none |
| Blue hole | Deep, cold, a sunk outboard motor at the bottom | Diving quest: 3 dives, sharks |
| Dayana's camp | Dayana with the broken ankle | 60% |
| Empty raft (*balsa vacía*, *balsa marcada*) | One washed-up raft: a tube (70%), rope, a plastic jug (50%). Marked: a spray-painted tube, no morale change. Unmarked: morale −5 to players nearby, once per run | 20% each on every reef, rock, lighthouse, storm and yacht variant; never on the freighter (its raft is Ramón's son's). No jokes |

**Escape routes.** Turtle (quest), binoculars-and-swim (the next island is always visible from the cave roof), raft.

**Threats.** Reef sharks ×3, barracuda, morays, the tiger shark on the shipwreck variant.

---

### 5. Rocky key (*el cayo de piedra*)

**Lore.** A black volcanic-looking rock (it is really ironshore limestone) with ten thousand birds and one hermit with a radio. The guano is ankle-deep. Nothing grows.

**Biome.** Rock, cliffs, a shingle beach, nests everywhere.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Bird colony | Eggs ×40, feathers, gull swarms | Loudest place in the game |
| The radio cave | El loco de la radio; radio fragments; a car battery | Sells "news"; charger for Yunior's phone (50%) |
| Cliff top | Binoculars (always, hidden in a cairn) | Only place binoculars are guaranteed |
| Rain cisterns | Three natural rock bowls; full after rain (10 cups) | The only water |
| Shingle beach | Driftwood ×10 (storms pile it here) | Best raft-building site |

**Escape routes.** Binoculars-and-swim (always), raft, signal boat (the cliff fire is visible for miles; also to patrols).

**Threats.** Gulls, fire ants, falling (cliff edges), no shade.

---

### 6. Lighthouse key (*el cayo del faro*)

**Lore.** A Spanish-era lighthouse, 1859, dark since 1991. La Vieja Caridad lives in the keeper's house with her charts, her kerosene lamp and her list. Everyone who passes scratches a name on the wall. Some names are crossed out in a different hand.

**Biome.** A proper small island: beach, scrub, a well, the lighthouse and house, a dock.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Keeper's house | Caridad, charts (quest), compass, *La lista*; 40% *El sobre de tres generaciones* | Safe at night: patrols leave her alone |
| The well | Fresh water, unlimited, slow (1 cup / 20 s) | The only unlimited water in the game |
| Lighthouse top | Spot every island in the chain; lamp (needs kerosene) | Navigation lesson here |
| The dock | A rowboat with no oars | Papo can make oars from hardwood |
| Old garden | Noni, aloe, a mango tree (food 20, thirst 10), grapefruit | Gulls |

**Escape routes.** Rowboat (needs oars), Gulf Stream (charts + compass from Caridad), raft.

**Threats.** Few. This is the breath before the far chains. One patrol passes at dawn and does not stop.

---

### 7. Storm key (*el cayo de la tormenta*)

**Lore.** The last Bahamian cay before open water. A Cuban family who gave up settled here in 2015 and built a house from wreck wood. They know when the hurricane comes.

**Biome.** Low, long, dune-backed beach, casuarina trees that scream in wind.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| The family house | Los cubanos de Bahamas; a bed (costs a day, restores everything); hurricane warning | They offer you to stay. Forever. |
| Casuarina grove | Mast wood, needles for fire | |
| Wreck field | After the hurricane: everything respawns ×3 | |
| The dune | The only shelter from the hurricane | Dig in with hands or oars |
| Papo's wreck | Papo repairing a boat | 50% |

**Escape routes.** Raft (rebuilt after the storm), tarp sail (the post-hurricane wind is perfect), the family's boat if you helped them tie it down. On the resort variant, also the almendrón (weight 0.8) and the board (weight 1.0), both rolled; the raft stays guaranteed. The resort's generator ("fuel!") holds 2–4 drums, 1–2 fuel jugs and a botija (50%); a rental shack by the pool holds the boards.

**Threats.** The hurricane (boss), then nothing: everything is gone.

---

### 8. Shipwreck reef (*el arrecife del naufragio*)

**Lore.** A 1960s freighter broken on the reef, half above water. Three decades of balseros have camped in its hull. Someone painted *¡Patria y Vida!* on the side; someone else painted over it; someone painted it again.

**Biome.** The wreck (a dungeon: decks, holds, ladders), reef flats, a tiny beach.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Captain's cabin | A sealed chest: pick one of three (binoculars, fishing net, solar charger); the others lock | Brogue vault rule |
| Engine room (flooded) | The outboard / oars for the boat (3 dives) | Tiger shark hunts here |
| Galley | Nails ×8, a pot (cooking, water boiling), canned food ×3 (1990s, 20% poison) | |
| The hull camp | Beds, graffiti, *Las cartas de la Yuma*, El ahogado on the beach below | Yunior's uncle's watch |
| Ramón's son's raft | A raft frame with a photo nailed inside | Ramón's quest |

**Escape routes.** Repair the boat with the engine (boss), raft, signal boat (El pescador de Miami, far chains only). On the yacht-graveyard variant, also the board (weight 0.5): one yacht vault is a surfboard and a forced shack holds the tarp, hardwood and rope for the sail. The galley also holds sugar ×1–2.

**Threats.** The tiger shark (boss), morays, the structure itself (falling through rotten decks).

---

### 9. Final approach (*las noventa millas*)

**Lore.** No island. A sandbar at low tide that is gone at high tide, 20 miles from Key West. You can see the glow. You have one tide to build what you need and one night to cross.

**POIs.** The sandbar (driftwood ×6, that's it), whatever you brought.

**Escape route.** Cross. That is the only route.

**The piling (sandbar variant).** Six tiles off the sandbar stands a concrete piling from an old bridge, with a faded official board bolted to it (set piece *El pilote*, 50%). Reading the board gives a bureaucratic ruling on whether a piling counts as land. It is a landmark, not a refuge: the tide still forces departure at 360 s. Tomás or Ramón in the party plays a short exchange about the old dry-feet rule, which ended in 2017.

**The final passenger.** As the party pushes off the final island, a laughing gull (*galleguito*) lands on one player's head and rides the whole crossing out. It is a creature, not a set piece, so it never competes with the piling for the island's set-piece roll. See `BESTIARY.md`.

**Threats.** The Florida Straits (boss): night, the Gulf Stream pushing east, a squall at the halfway mark, one last patrol (or the Miami fisherman, if you met him), sharks following any blood. The lighthouse beam if Caridad lit it.

---

## Secret: El cayo sin norte (off-graph)

**Secret and off-graph** (change `secret-cay`). Not a chain and not one of the run's 6–8 islands. No chart, binoculars, lighthouse, keepsake, NPC, route discovery, carried map knowledge, HUD marker or AI ever shows or mentions it. The generator never builds, lists or numbers it. Layout: `game/resources/islands/cayo_sin_norte.tres` (`off_graph`, `secret`).

**How you get there.** In 1 run in 3, a *Brújula rota* and a *Mapa sin norte* hide on two different islands from 2 to 5 (never the sandbar or the final approach), one per island, concealed until a player is within 3 tiles, with a short shimmer every 6 s. A piece hides on a land cell (beach, dune or scrub, never shallows), measured from the landing (the layout's solo spawn): between the 50th and 85th percentile of walking distance over the reachable land cells, and 4–10 tiles in a straight line from the nearest feature the tuning lists (a palm, a non-secret pick-up, a tide pool, the workbench or the raft site). On an island too crowded for that, the rule relaxes in a fixed order (a wider band, then no feature limit, then any reachable land cell off the features and spawns), so the piece is always placed. The map's text names the kind of spot where the compass hides. Holding both, the party can choose *Seguir la aguja* on leaving an island from index 3 on (later work: crossing, arrival and the departure choice). Everything in `ITEMS.md` "Secret items".

**Lore.** A sand teardrop no fisherman talks about. Someone got here first and left minutes ago: the embers are still warm, a cigar stub is still smoking, a fresh raft-drag mark runs from the camp to the water, and a cut mooring line hangs from a post. He is coming back on Thursday. Nobody died here and nothing here is a memorial.

**Layout.** 48×27 tiles: about 200 cells of sand and scrub, a ring of reef shallows, deep water around.

| Place | What is there |
| --- | --- |
| South beach | The landing: everyone arrives within 5 tiles of each other |
| Waist | A palm-frond lean-to (the only shade) with the *sombrero de yarey con cinta roja* hanging on it, the warm embers, the smoking cigar stub, a knife, 2 rain cups, 3 palms with 7 coconuts |
| East cove | A raft build site with at least the raft recipe's inputs on the sand (today 6 driftwood, 2 inner tubes, 3 rope) |
| Waterline | The drag mark and the post with the cut mooring line |
| North tip | The chest, on the land (non-shallows) cell farthest by walking from the landing (any one of them on a tie): open it (hold 1 s) and it holds only the note *Llegaste tarde* |

**Escape route.** Only the raft (the cay lists one route instead of rolling 2–3), which one player with an empty inventory can gather, build and launch alone. After the cay the party goes on to the island it was heading for.

**Rules.** No Experiencia point, no Experiencia-level driftwood or coconut, no party-size scaling: the contents are the same for 1–4 players, and no pick-up respawns after a squall or a night. No creatures, patrols or set pieces, even with the patrols-everywhere challenge; the sun, thirst and hunger still work. A captured party never restarts here.

**Threats.** The sun, thirst, and the extra crossing.

---

## Resource rules (for the generator and balance)

| Resource | Base per island | Scales with |
| --- | --- | --- |
| Driftwood | 8 | +4 after squall, ×0.8 per extra player |
| Coconuts | 10 (sandbar/coast), 0 (rock, storm) | |
| Fresh water | 0 except lighthouse well, rock cisterns, cave seep | Rain gives 2 cups per catcher per squall |
| Crabs | 6 per night per beach | Fire halves them (they flee light) |
| Fish | Infinite with skill; 1 per 30 s base, 1 per 10 s for a Pescador | |
| Rope | 2–4 | Lobster traps +1 each |
| Tubes/jugs | 2–3 on flotsam | Respawn after squall |
| Unknown fruit | 3–5, one is manchineel on 50% of islands | |
| Keepsake/text | 1 important text + 1–3 bottle notes | |

Off-graph handmade layouts (today only the secret cay) skip this table: they place exactly the pick-ups their layout lists, never scaled by party size or Experiencia, and none respawns after a squall or a night.

## Set pieces (Brogue "machines")

Scripted mini-situations the generator can drop onto any island, max one per island:

- **The floating cooler:** a sealed cooler drifting 6 tiles out, full of food and one beer. Sharks are circling it.
- **The other raft:** a raft of 3 NPC balseros beached and arguing. They need a mechanic; you need their tubes.
- **The patrol dinghy:** a guardacostas dinghy left unattended on the beach while the squad searches. Steal it (escape route, but Rodríguez remembers).
- **The signal fire someone else lit:** a fire on the far point is already drawing a patrol. Put it out or use the distraction.
- **The turtle nest:** eggs in the sand; taking them gives food but Vieja will never follow you.
- **The message in the bottle, returned:** a bottle note that is a reply to one you wrote on an earlier island (AI).

---

# Expansion — chain variants and more set pieces

## Chain variants (9 chains → 18 playable layouts)

Each chain has two variants. The generator picks one per visit; a run rarely sees both. Variants share the chain's POI table and swap the layout rule, the signature POI and the threat mix.

| Chain | Variant A | Variant B |
| --- | --- | --- |
| Sandbar | **Crescent**: one beach, hut on the point, flotsam on the inside curve | **Twin bars**: two bars with a channel between; stingrays in the channel; players may start on different bars |
| Coast cay | **The bunker**: observation post on a point, lagoon behind | **The village**: three abandoned fishermen's houses, a rusted well (brackish), a dock, other balseros always present |
| Mangrove | **The maze**: channels, the tourist wreck, the repairable skiff | **The river mouth**: brackish river with bull sharks, the hardwood hammock upstream, a half-sunk ferry |
| Reef | **The traps**: lobster traps, ghost net, cave | **The blue hole**: a deep hole with the outboard, a lionfish ring, no cave (shade is the problem) |
| Rocky key | **The colony**: birds and cliffs | **The quarry**: an abandoned stone quarry with a flooded pit (fresh water, 20 cups) and scorpions |
| Lighthouse | **Caridad's**: the standard | **The dark lighthouse**: Caridad has died this run; her list, her lamp and a letter remain; Alfredo may be there instead; no well water (pump broken; Papo fixes it) |
| Storm key | **The family**: the Bahamian Cubans | **The abandoned resort**: a half-built hotel from 2008 with a pool (green water, boil it), feral dogs, a generator (fuel!) |
| Shipwreck reef | **The freighter**: the standard dungeon | **The yacht graveyard**: six small wrecks on a flat, each a one-room vault; pick three to dive, the tiger shark circles all |
| Final approach | **The sandbar**: the standard | **The buoy**: no land at all; a weather buoy to cling to for one tide; the Miami fisherman's VHF channel is painted on it |

## Set pieces (6 → 17)

| # | Set piece | Where | What happens |
| --- | --- | --- | --- |
| 1 | The floating cooler | Any | A sealed cooler 6 tiles out, sharks circling |
| 2 | The other raft | Any beach | 3 NPC balseros need a mechanic; you need their tubes |
| 3 | The patrol dinghy | Coast | Unattended during a squad search; steal it, Rodríguez remembers |
| 4 | Someone else's signal fire | Any | A fire on the far point already drawing a patrol |
| 5 | The turtle nest | Sandbar, reef | Eggs = food, but Vieja never follows you |
| 6 | The reply bottle | Later island | A reply to a note you wrote (AI) |
| 7 | **La cola** | Village cay | Other balseros queuing at the well for a "turn"; cut the line (fight), wait (a phase), or organize it (Maestro: morale +10 all) |
| 8 | **El apagón** | Lighthouse, resort | The generator/lamp dies at the worst moment; fix it in the dark with the crocodile or dogs around |
| 9 | **The drone** | Far chains, 10% | A US Coast Guard drone passes; wave (Miami fisherman odds ×2) or hide (nothing) |
| 10 | **The bale** | Any crossing, 5% | A floating bale of something wrapped in plastic. Take it: smugglers come looking (rob or trade). Leave it: nothing |
| 11 | **The radio contest** | Rock cave | El loco's radio picks up a Miami station giving away a prize to "the first balsero who calls"; the VHF is the only way |
| 12 | **The dominoes night** | Any camp, 2+ players | Dominoes found; a full night of play restores morale to 100 for all, costs the night, crabs eat everything unsealed |
| 13 | **The funeral** | Any island after a companion dies | Their body washes up; bury it (shovel, a phase, morale +15) or leave it (morale −15, gulls) |
| 14 | **The patrol that stops** | Coast | Rodríguez's boat anchors offshore for a full day phase: his crew is swimming. Steal from the boat, or be seen |
| 15 | **The wedding** | Village cay, rare | Two NPC balseros marry on the beach before leaving; attend (morale +30, a day) and they join the ending credits |
| 16 | **La balsa en la sala** | Village cay, 60%, once per run, island 2+ | A finished raft fills a fishermen's house and will not fit the door. Take it apart (3 tubes, 2 rope, 2 driftwood), knock the wall down (everything, but noise 20 tiles and a 40% patrol alert: somebody reports you even on an empty cay) or take it out the window on its edge (everything, quiet, morale +5 to the party; needs a Mecánico or 2 players within 5 tiles) |
| 17 | **El pilote** | Final sandbar, 50% | A piling six tiles offshore with an official board; read it (morale +5 on first read) for a ruling on whether a piling is land. Tomás or Ramón in the party adds an exchange |

## Density after expansion

18 layouts, 17 set pieces, ~50 POI types, 39 creatures, 113 items, 8 companions. A 7-island run uses roughly a third of the pool.
