# 90 Millas — Islands and Resource Places

Islands are generated from **chain templates**. A run is 6–8 islands: island 1 is always the sandbar; island 2 is always a coast-chain island; from island 3 the route branches between chains; the last island is always the final approach. Each island rolls 2–3 escape routes and 3–6 points of interest (POIs) from its chain's table.

Generation: `IslandGenerator` builds a noise-shaped landmass on a 96×64 tile grid, places biome bands (deep water → shallows → beach → dunes/mangrove/rock → interior), then places POIs with a rule set (min distance, shoreline access, no two of the same kind). Escape routes are POIs with a flag. See `openspec/specs/island-generation/spec.md`.

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
| Ruined hut | Tarp, 2 driftwood planks, a rusted knife, the first bottle note | Only shade; a workbench |
| Palm grove (6 palms) | Coconuts, 8–12; climbing costs energy, throwing costs a coconut | Gulls nest in two of them |
| Flotsam line | Inner tubes ×2, plastic jugs ×3, rope ×1, random shiny item | Refreshes after a squall |
| Tide pools | Crabs at night, one man o' war, sea urchins (bleeding if stepped on) | Low tide only |
| La señora's camp | The woman who never left; water for stories | 50% chance |
| Scattered landing | Players start 10–20 tiles apart | Co-op: find each other first |

**Escape routes.** Raft (always), binoculars-and-swim (the next island is visible on clear days), signal the fishing boat (Ramón, 30%).

**Threats.** Patrol every 3 minutes, gulls, crabs, the sun.

---

### 2. Coast cay (*el cayo de la costa*)

**Lore.** Close enough to Cuba that on clear nights you see the glow of Havana. Close enough that the patrol passes twice an hour. A concrete observation post from the 1980s rots on the point, slogans still painted on it.

**Biome.** Beach, dunes, a rocky point, a small lagoon.

**POIs.**
| POI | Resources | Notes |
| --- | --- | --- |
| Observation post | Nails, a mirror (signal), a dead radio, wall slogans | Best hiding spot from searchlights |
| The lagoon | Fresh-ish water (brackish: thirst +10, then −5), fish | Crocodile 20% on mid chains only |
| Dune with aloe | Aloe ×4, noni tree | |
| Rope cache | A buried bag: rope ×4, a lighter | Marked by a crossed-stick sign, Navigation ≥1 to notice |
| Ramón's cove | Ramón and *La Esperanza II* | 40% |
| Other balseros' camp | 2–3 NPCs competing for the palms | 50% |

**Escape routes.** Raft, Ramón's boat (quest), tarp sail (trade wind days), Gulf Stream (needs charts, rare this early).

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
| Camp ruin | *El diario del Período Especial* | |

**Escape routes.** Repair the boat (boss), raft (hardwood makes it stronger), follow the dolphins (dawn, from the sand spit).

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
| Limestone cave | Shade, fresh water seep (2 cups/day), bats | Only shade; echoes carry (noise ×2) |
| Blue hole | Deep, cold, a sunk outboard motor at the bottom | Diving quest: 3 dives, sharks |
| Dayana's camp | Dayana with the broken ankle | 60% |

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
| Keeper's house | Caridad, charts (quest), compass, *La lista* | Safe at night: patrols leave her alone |
| The well | Fresh water, unlimited, slow (1 cup / 20 s) | The only unlimited water in the game |
| Lighthouse top | Spot every island in the chain; lamp (needs kerosene) | Navigation lesson here |
| The dock | A rowboat with no oars | Papo can make oars from hardwood |
| Old garden | Noni, aloe, a mango tree (food 20, thirst 10) | Gulls |

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

**Escape routes.** Raft (rebuilt after the storm), tarp sail (the post-hurricane wind is perfect), the family's boat if you helped them tie it down.

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

**Escape routes.** Repair the boat with the engine (boss), raft, signal boat (El pescador de Miami, far chains only).

**Threats.** The tiger shark (boss), morays, the structure itself (falling through rotten decks).

---

### 9. Final approach (*las noventa millas*)

**Lore.** No island. A sandbar at low tide that is gone at high tide, 20 miles from Key West. You can see the glow. You have one tide to build what you need and one night to cross.

**POIs.** The sandbar (driftwood ×6, that's it), whatever you brought.

**Escape route.** Cross. That is the only route.

**Threats.** The Florida Straits (boss): night, the Gulf Stream pushing east, a squall at the halfway mark, one last patrol (or the Miami fisherman, if you met him), sharks following any blood. The lighthouse beam if Caridad lit it.

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

## Set pieces (Brogue "machines")

Scripted mini-situations the generator can drop onto any island, max one per island:

- **The floating cooler:** a sealed cooler drifting 6 tiles out, full of food and one beer. Sharks are circling it.
- **The other raft:** a raft of 3 NPC balseros beached and arguing. They need a mechanic; you need their tubes.
- **The patrol dinghy:** a guardacostas dinghy left unattended on the beach while the squad searches. Steal it (escape route, but Rodríguez remembers).
- **The signal fire someone else lit:** a fire on the far point is already drawing a patrol. Put it out or use the distraction.
- **The turtle nest:** eggs in the sand; taking them gives food but Vieja will never follow you.
- **The message in the bottle, returned:** a bottle note that is a reply to one you wrote on an earlier island (AI).
