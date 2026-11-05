# 90 Millas — Bestiary

Every threat, with lore, behavior spec, numbers for the first balance pass, and the reference-game behavior it adapts. Creatures are `.tres` resources; behaviors are state machines in `game/scripts/ai/`.

Difficulty scales by **distance** (islands 1–2: coast, 3–5: mid, 6–8: far) and by **party size** (patrols +1 per 2 players, spawn rates ×1.2 per extra player).

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

**Behavior.** `submerged → lunge → death roll`. Invisible in still brackish water (no ripples). Lunges at anything within 2 tiles of the water edge at night or in fog: 40 damage and **grab**: the player is dragged one tile per second toward deep water; teammates must hit it (any weapon) three times in 5 s to make it release. Solo: mash to escape, 50% chance per second, each second costs 10 health.

**Old crocodile (mangrove boss).** Same but 80 damage, needs 6 hits, and it guards the boat. Trick: it leaves the nest at dusk to hunt. Players have 90 s to clear the nest, which makes it return early; or feed it a whole cooked crab pile (5) and it sleeps for a full night.

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

**Behavior.** Circle rocky keys and any beach where food lies uncovered. Swoop: steal one food item from the ground or from a player's hands (not inventory) and fly off. They defend egg nests: 3 damage per peck, swarm of 4.

**Counters.** Cover food. Chase them with a stick (they flee 30 s). Egg raids are worth it: 10 eggs per nest.

**Reference.** Brogue monkeys (steal and flee).

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

**On capture.** If everyone is caught: *La captura* scene with Rodríguez (see `CHARACTERS.md`). Otherwise the captured player is held on the boat at the dock until freed or until the boat leaves (3 min), after which that player respawns on the previous island with no items.

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
