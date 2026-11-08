# 90 Millas — Bestiary

Every threat, with lore, behavior spec, numbers for the first balance pass, and the reference-game behavior it adapts. Creatures are `.tres` resources; behaviors are state machines in `game/scripts/ai/`.

Difficulty scales by **distance** (islands 1–2: coast, 3–5: mid, 6–8: far) and by **party size**, the living, connected players when the island is set up (patrols +1 per 2 players, spawn rates ×1.2 per extra player).

---

## Sea

### Reef shark (*tiburón de arrecife*)

**Lore.** The reef sharks of the cays have learned that rafts mean food: not people, but the fish guts and bait that fall off them. They are curious, not evil. Blood changes that.

**Behavior.** `patrol → investigate → circle → strike → retreat`
- Patrols deep water (≥2 tiles from shore). Investigates splashes within 8 tiles.
- Circles a swimmer for 6–10 s. Strikes only if the target is **bleeding** (coral cut, crab wound, raw fish on them) or if energy < 20 (slow swimmer). Otherwise loses interest.
- After a strike (25 damage + bleeding) it retreats 4 s, then circles again.
- Groups of 2–3 on reef chains; the tiger shark boss replaces them once per run.

**Counters.** Bandage cuts before swimming. Stay in shallows (≤1 tile). Throw raw fish away from you (decoy, 10 s). Spear hits in the nose cause a 15 s retreat.

**Reference.** DCSS sharks frenzy when their target is wounded; Brogue's eels only attack from water.

---

### Moray eel (*morena*)

**Lore.** Lives in reef holes and lobster traps. Ramón has lost two fingers' worth of patience to them.

**Behavior.** `hidden → strike → retreat`. Invisible until a player steps on an adjacent reef tile at low tide or pulls a trap. Bites once (15 damage + bleeding), then hides for 20 s. Bubbles on the tile are the tell (visible with Navigation ≥1).

**Counters.** Walk the long way at low tide; poke holes with the spear first; have a *Pescador* pull traps (they read the bubbles).

**Reference.** Brogue's submerged eels.

---

### Barracuda school (*picúas*)

**Lore.** Fast silver knives. They hit anything that flashes.

**Behavior.** Pack of 5–8 in shallows and channels. Targets any player carrying a **shiny item** (mirror, knife out, watch, foil) in the water. Swarm: each hit 5 damage, three hits a second if surrounded. Flees when 3 of the school die or the shiny item is dropped.

**Counters.** Sheathe shiny items before swimming. Fight in a narrow channel so only two can reach you. Drop the item as a decoy.

**Reference.** Brogue jackal packs (fast, weak, swarm).

---

### Portuguese man o' war (*agua mala*)

**Lore.** The blue balloon that every Cuban kid has been warned about. It is not a jellyfish; it is a colony. That does not help when it stings.

**Behavior.** Drifts with the wind; beaches at high tide; lies in shallows at low tide. Touching it: 10 damage and **paralysis** 4 s (you float, can't swim, sharks notice). Sting lasts 30 s as a thirst ×1.5 debuff.

**Counters.** Look before stepping in shallows (visible as a blue dot). Push it away with a stick. Aloe reduces the debuff to 10 s.

**Reference.** Floor traps in SPD and Brogue; here they drift.

---

### Tiger shark — reef chain boss (*el tigre*)

**Lore.** Four meters, one eye, a lobster-trap float tangled in its tail from 2009. Ramón calls it *la jefa*. It has sunk two rafts this season.

**Behavior.** Hunts the reef around the shipwreck island while you salvage the wreck. Unlike reef sharks, it does not need blood: it strikes anyone in deep water every 20 s. 60 damage. It breaks a raft in two hits. Can be driven off for 2 minutes by: a spear hit to the gills (needs Combat ≥2), a signal fire on the water (burning tarp), or the dolphin pod arriving at dawn.

**Win condition.** You do not kill it. You get the boat's engine or oars out of the wreck in three dives while it circles, and leave.

**Reference.** SPD's boss floors are set pieces with a trick; Brogue's "machines".

---

### Sea crocodile (*cocodrilo americano*)

**Lore.** The American crocodile lives in the brackish mangroves and does not care about borders. The old one in the mangrove chain is five meters and has a nest on the repairable boat.

**Behavior.** `submerged → lunge → death roll`. Invisible in still brackish water (no ripples). Lunges at anything within 2 tiles of the water edge at night or in fog: 40 damage and **grab**: the player is dragged one tile per second toward deep water; teammates must hit it (any weapon) three times in 5 s to make it release. The grabbed player can always mash to escape, solo or not: 50% chance per second, rolled first, and only a failed second costs 10 health. If the drag reaches deep water it death-rolls: 20 damage and bleeding, then it lets go.

**Old crocodile (mangrove boss).** Same but 80 damage, needs 6 hits, and it guards the boat. One tuning for every party size: a solo player takes the same 80 and mashes the same way. Trick: it leaves the nest at dusk to hunt. Players have 90 s to clear the nest, which makes it return early; or feed it a whole cooked crab pile (5) and it sleeps for a full night.

**Counters.** Avoid still water at night. Throw a crab to see if it lunges. Travel in pairs in the mangroves.

**Reference.** Brogue bog monsters (submerged grab).

---

## Land

### Land crabs (*cangrejos*)

**Lore.** The beaches crawl at night. In Cuba the blue crabs cross the roads in March and the cars crush thousands; here they get even.

**Behavior.** Spawn at night on any beach, 4–8. Fast, 3 health, 5 damage pinch (bleeding 10%). Their real job is **theft**: any stash not in a sealed container loses 1 food item per crab per minute. They flee from fire light.

**Counters.** Seal caches (jug with lid, buried). Keep a fire. Hunt them: they are food (cook them, raw crab is 30% poison).

**Reference.** SPD sewer crabs; the theft is from Brogue monkeys.

---

### Seagulls (*gaviotas*)

**Lore.** They were here first and they know it.

**Behavior.** Circle rocky keys and any beach where food lies uncovered. Swoop: steal one food item from the ground or from a player's hands (not the rest of the inventory) and fly off for 30 s, then come back to the nest. "Hands" is the first food slot of the inventory while the player is on land, not swimming (`creatures-ai`, owner-confirmed 2026-11-08). They defend egg nests: 3 damage per peck, swarm of 4.

**Counters.** Cover food. Chase them with a stick (they flee 30 s). Egg raids are worth it: 10 eggs per nest. Carrying the *Pluma de galleguito* keepsake makes every gull ignore you.

**Codex line.** "El mismo que te robó el cangrejo en el primer cayo. Ahora quiere que lo lleves." / "The same one that stole your crab on the first cay. Now it wants a ride."

**Reference.** Brogue monkeys (steal and flee).

#### The final passenger (*el galleguito*)

The same species, the laughing gull Cubans call *galleguito*, and the same attitude: on the islands it steals your lunch, and at the end it steals a ride. It is a separate creature (`galleguito`) so the island gull's spawn rules stay untouched. Its story is invention, inspired by one unverified anecdote and the gull's real habits (`docs/LORE.md` §8).

- **Spawn.** A crossing rule on the final chain family at chance 1.0, once per run: it appears on the crossing out of the final island, every run. It is a creature, not a set piece.
- **Behavior.** `perch_ride`. As the party pushes off, it circles twice and lands on one player's head and stays for the whole crossing, turning when the player turns. Shooed (interact), it hops to another head, or in solo circles and lands again. If its player falls in, it lifts off and waits overhead. It ignores sharks, searchlights and squalls. At the beach it hops off first and walks up the sand ahead of everyone.
- **Small effect, never a survival lever.** Each player who sees it land gets +10 morale, once per run; solo and co-op get the same per-player bonus (shore birds mean shore). Once every 60 s it has a 50% chance to take one *held* food item from the player it rides (never from inventory), and it does not fly away after; on a 60–120 s crossing that is at most two snacks. It never changes speed, drift, threats or the outcome.
- **The pick.** In co-op the host picks the player holding the most food items, ties broken by the run seed, and rolls the theft; clients only send the shoo. In solo it picks the solo player. A *Pluma de galleguito* holder is never robbed.
- **Lines.** "No lo espantes. Si un pájaro de costa se monta aquí, es que la costa está cerca." · "Se me sentó en la cabeza como si tuviera visa." · the theft: "¡Oye, esa galleta era mía! ...Bueno. Peaje es peaje." · "¡Me cagó el galleguito! ...Bueno, dicen que es buena suerte." (soft: "¡Me ensució el galleguito!..."). The endings carry its line (`GAME_DESIGN.md` §13).

---

### Mosquito cloud (*los mosquitos*)

**Lore.** The mangroves at dusk. There are no words.

**Behavior.** A gas-cloud area that spawns at dusk on mangrove and sandbar tiles. Inside: energy −2/s, morale −1/s, no damage. Drifts with wind. Dispersed by smoke (fire with green leaves) for 3 minutes.

**Counters.** Sleep upwind or on a raft offshore; smoke fire (which patrols see).

**Reference.** Brogue and DCSS gas clouds.

---

### Fire ants (*hormigas bravas*)

**Lore.** The mound you stepped on while looking at the horizon.

**Behavior.** Static mounds on dunes; stepping on one gives **burning** 10 s (3 damage/s, speed −30%). Aloe cures.

**Reference.** Floor traps.

---

### Manchineel (*manzanillo*)

**Lore.** The most dangerous tree in the Caribbean. The Spaniards called it the "little apple of death". It looks like a nice spot for shade.

**Behavior.** A tree. Standing under it in rain: burning 10 s. Eating its fruit (unidentified "fruta verde"): 50 damage over 60 s and thirst ×2. A *Médico* identifies it on sight; anyone else learns the hard way, once per run.

**Reference.** Unidentified potions in SPD/Brogue.

---

## Human

### Guardacostas patrol boat (*la lancha*)

**Lore.** Twelve-meter patrol boats out of Mariel and Matanzas. The crews are kids doing service and one sergeant who has done this for years.

**Behavior.** `route → spotlight → chase → board`
- Runs a fixed loop around coast-chain islands, 3-minute period, visible on the horizon 20 s before it passes.
- Night: searchlight cone (60°, 10 tiles) sweeps the beach and water. Any player in the cone for 2 s is **spotted**.
- Spotted → the boat chases anything in the water (speed 2× swimmer) and launches a **shore squad** if the party is on land.
- Also triggered by **smoke** (any fire 2 tiles from cover) and **noise** (gunshots, breaking wood near the shore).

**Counters.** Learn the loop; cross right after it passes. At night: crouch in brush (hidden), dive under water (hidden 5 s), stand in mangroves (hidden). Put fires out when the horizon shows a light. Stealth skill lengthens all hidden timers.

**Reference.** Brogue stealth range and noise system.

---

### Shore squad (*los guardias*)

**Behavior.** Three soldiers land from the patrol boat and search for 3 minutes: they walk to the fire, then toward last known positions, then random. They do not fight; they **capture** (touch for 2 s). Captured players are walked to the boat; a teammate who touches the captive while no soldier is within 3 tiles frees them. The squad leaves when the timer ends or all players are caught.

**On capture.** If everyone is caught (a solo player always is): *La captura* scene with Rodríguez (see `CHARACTERS.md` and `GAME_DESIGN.md` §9). Otherwise the captured player is held on the boat at the dock until freed or until the boat leaves (3 min), after which that player respawns on the previous island with no items.

---

### Guardacostas cutter *Tiburón 3* — coast chain boss

**Lore.** The big one. Rodríguez's ship.

**Behavior.** The first crossing is a chase: the cutter spots the raft at 30 s and follows at 1.5× raft speed with a searchlight. Escape by: entering fog, reaching the reef line (it cannot follow), or cutting the sail to drift dark while the light passes. Caught = *La captura*.

---

## Weather as a threat

| Event | Effect | Counter |
| --- | --- | --- |
| Squall | Raft −30% integrity, fire out, visibility 3 tiles, 2 minutes | Tie down (rope), beach the raft |
| Scorching noon | Heat ×2 for 2 hours in-game | Shade, swim in shallows |
| Fog | Islands and binoculars useless; sharks hunt by blood only | Wait; or use the compass and charts |
| Rip current (reef shallows) | Pulls swimmers out 1 tile/s | Swim parallel to shore |
| Hurricane — storm-key boss | A full night: wind pushes everything, water rises 3 tiles, structures break | Dig in behind the dune, tie everything down, keep the kid inside |
| The Florida Straits — final boss | Night, Gulf Stream, a squall, a patrol, sharks. Every system at once | Everything you learned; the lighthouse beam if Caridad lit it |

---

# Expansion — creatures 16–35

Added to reach reference-game density (~35 creature types). Each follows the same resource + behavior-id pattern; most reuse an existing state machine with different numbers.

## Sea (added)

| # | Creature | Chain | Behavior | Numbers | Counter | Lore line |
| --- | --- | --- | --- | --- | --- | --- |
| 16 | **Bull shark** (*tiburón toro*) | Mangrove, lagoon | `patrol_circle_strike` but in brackish and shallow water, strikes without blood if you are alone (no other player or living companion within 5 tiles) | 30 dmg, speed 4 | Swim with someone (a companion counts); any noise that reaches it scares it off for 20 s, solo too | The only shark that comes up the rivers in Cuba. It does not care that the water is brown. |
| 17 | **Stingray** (*raya*) | Sandbar, reef flats | `static_hazard` buried in sand; stepping on it = tail strike | 20 dmg + bleeding + speed −30% for 30 s | Shuffle (crouch-walk) in shallows; a Pescador sees the outline | Every Cuban kid knows the shuffle. Every tourist learns it. |
| 18 | **Sea urchin field** (*erizos*) | Reef flats | `static_hazard`, cluster of 6–10 | 5 dmg + bleeding per step | Sandals (craft: tire + rope) or the long way | Black pincushions. The spines break off inside. |
| 19 | **Lionfish** (*pez león*) | Reef, wreck holds | `hidden_ambush`, stationary; venomous when touched or speared badly | 15 dmg + heat ×1.5 for 60 s | Spear from 2 tiles; it is good eating (food 25) | Invasive, beautiful, and the reef's fault is nobody's. |
| 20 | **Remora** (*rémora*) | Any crossing | Attaches to the raft; `night_thief` variant that eats bait and fish on lines | Steals 1 fish per 2 min | Knock it off (interact) | It thinks the raft is a whale. It is not wrong about the smell. |
| 21 | **Jellyfish bloom** (*medusas*) | Mid/far crossings, calm weather | `gas_cloud` on water: a drifting field | 3 dmg/s + paralysis 1 s on entry | Steer around; Navigation sees it 10 tiles out | The sea turns pink and you stop rowing. |
| 22 | **Needlefish** (*agujón*) | Night, near lights | `swoop_steal` variant: leaps at light sources on the water | 10 dmg, 20% chance per minute a fire is lit on the raft | No fire on the raft at night; or a torch held away as a decoy | They jump at the lantern and sometimes at the face holding it. |
| 23 | **Sea snake** (*serpiente de mar*) | Far reefs | `hidden_ambush` in coral | 25 dmg poison over 60 s | Médico identifies; antidote = aloe + noni | Striped like a warning. It is a warning. |
| 24 | **Hammerhead** (*cornuda*) | Far crossings | `patrol_circle_strike`, follows the raft for a full crossing, strikes only if someone falls in | 40 dmg | Nobody falls in | It escorts you. Politely. For ninety minutes. |
| 25 | **Sperm whale** (*cachalote*) | Far crossings, rare (5%) | Non-hostile set piece; surfaces, breathes, dives; wake rocks the raft | Raft −10 integrity from the wake | None; +20 morale to everyone who sees it | The first thing in days that was not trying to kill you. |

## Land (added)

| # | Creature | Chain | Behavior | Numbers | Counter | Lore line |
| --- | --- | --- | --- | --- | --- | --- |
| 26 | **Hutía** (*jutía*) | Far cays, mangroves | Passive; flees; food 25 if caught (trap or thrown rock) | 4 health, speed 5 | Snare (rope + stick); a Pescador's trap works too | The Cuban tree rat. Grandparents ate it in the 90s and will tell you how. |
| 27 | **Iguana** (*iguana*) | Rock, storm key | Passive by day; bites if cornered; food 30 | 10 health, 8 dmg | Approach from behind at noon when it is sluggish | The Bahamas kind. It has seen more rafts than you have. |
| 28 | **Feral dogs** (*perros jíbaros*) | Storm key | `pack_swarm` on land, 3–5; hunt at night; steal meat | 6 dmg each | Fire scares them; a Músico calms them (song); the family on the key feeds them | Somebody's dogs from a boat that never came back. |
| 29 | **Sand fleas** (*pulgas de arena*) | Any beach, dusk | `gas_cloud` on sand, low | Morale −0.5/s inside; no damage | Sleep on the raft or on rock | They are not fleas. They itch like fleas. |
| 30 | **Boa** (*majá de Santa María*) | Lighthouse garden, hardwood hammock | `hidden_ambush` in trees; constrict | 10 dmg/s grab for 5 s; teammates hit twice to free; the grabbed player mashes to escape, 50% per second rolled before the damage, solo too | Caridad warns you; walk the path | Cuba's only big snake. Harmless, she says. It does not feel harmless. |
| 31 | **Rats** (*ratones del barco*) | Shipwreck holds | `night_thief` indoors, day and night | Steal food; 3 health | Seal food; the galley pot is a rat trap | Three generations born in the hull. They own it. |
| 32 | **Pelican** (*pelícano*) | Any cove | Passive; dives on fish you are reeling in | Steals the catch 30% | Reel fast; it is a tell that fish are there | He fishes better than you. Nobody argues. |
| 33 | **Scorpion** (*alacrán*) | Rock cave, bunker | `static_hazard` under rocks and in boots left out | 15 dmg + energy −30 | Shake out boots; a stick under rocks | Check your shoes. Check them again. |

## Human (added)

| # | Threat | Chain | Behavior | Counter | Lore line |
| --- | --- | --- | --- | --- | --- |
| 34 | **Jet-ski patrol** (*la moto*) | Coast, day | Fast (speed 8), loud (heard 20 tiles), short loop (90 s), no searchlight; spots swimmers in open water by day | Stay out of open water at midday; the noise is the warning | Two kids with sunglasses and a radio. They are bored. That makes them look harder. |
| 35 | **Smugglers** (*los lancheros*) | Far chains, night, rare | A go-fast boat; will carry you for everything you own, or rob you; 50/50 | Negotiate with a Músico or El Chino present; or hide | Nine thousand dollars a head in Havana. Here the price is whatever you are holding. |

## Birds (added)

Four birds, one for each place a Cuban sees them from a boat. The first three are ambient: they follow the vessel for a morale bump and never threaten anyone. Nobody jokes about them at the expense of a person.

| # | Creature | Chain | Behavior | Numbers | Counter | Lore line |
| --- | --- | --- | --- | --- | --- | --- |
| 36 | **Galleguito** (*galleguito*, laughing gull) | The final crossing, every run | `perch_ride`, see "The final passenger" | No health; +10 morale once per player; steals one held food item, 50% per 60 s | Shoo it (hops away); the *Pluma de galleguito* | He sat on my head like he had a visa. |
| 37 | **Pajarito** (*pajarito*, small songbird) | Mid and far crossings, dawn, 10% | `ambient`, follows the vessel; flies off at any noise | +5 morale to each player who sees it, once a day | Keep quiet | A little yellow bird fell asleep on the oar. Nobody talked for an hour so as not to wake him. |
| 38 | **Pájaro bobo** (*pájaro bobo*, booby) | Crossings, 15% | `ambient`, follows the vessel; flees once the weather is a squall | +5 morale to each player who sees it, once a day | None needed; it leaves on its own with the dark-line tell | A pájaro bobo climbed aboard. Doesn't pay, doesn't row, but at least he doesn't complain. |
| 39 | **Rabihorcado** (*rabihorcado*, frigatebird) | Reef and rock cays, 40% | `swoop_steal` from the fishing catch, airborne only, never catchable; replaces the pelican where it spawns, so two catch thieves never stack | Steals the catch 20%, then flees | Reel fast | Doesn't swim, doesn't fish. Lives off taking from whoever works. That bird's a dirigente. |

The `ambient` machine is shared with the sperm whale and the pelican. A forecast condition for the booby's early squall tell would need new code and is not proposed.

## Weather and environment (added)

| Event | Where | Effect | Counter |
| --- | --- | --- | --- |
| **Waterspout** (*tromba*) | Mid crossings, squalls | A moving column; raft −60 if touched; 20 s warning | Steer perpendicular |
| **Red tide** (*marea roja*) | Reef, 1 in 5 runs | Fish and oysters are 60% poison for two days; the water smells | Eat coconuts, crabs, eggs; wait |
| **King tide** (*marea viva*) | Sandbar, full moon | The whole cay floods for a half day; stashes wash away | Hang everything in the palms; climb |
| **Heat dome** (*el calorón*) | Any, far chains | Three days of scorching calm; thirst ×2.5 | Still + rain catcher; dig a shade pit |
| **Sargassum raft** (*sargazo*) | Crossings | A floating mat; slows the raft to half; hides remoras and a small fish bounty | Pole through; fish it |
| **Lightning** (*rayos*) | Squalls | Strikes the tallest point (mast, palm, you) | Lower the mast; stay low |

## Density check

With these additions: 39 creature types, 5 bosses, 11 weather events. Per island the generator picks 3–5 creature types from the chain's list, so a 7-island run shows ~20 and two runs rarely repeat the same mix.
