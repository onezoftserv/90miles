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
| Run length | 6–8 islands, 60–90 minutes. The secret cay is an optional detour that never counts as one of them (`ISLANDS.md` "Secret: El cayo sin norte") |
| Language | Spanish original; English keeps key slang |
| Rating | Mature: swearing, political satire, danger |
| Tone | Dark comedy with real stakes; Cubans laughing at the worst day of their lives |
| Era | The present day. 1994 and the earlier waves (1965, 1980) live in found texts, wrecks and older characters' stories, never in the run's date; see `docs/LORE.md` |
| Backend | v2: AWS Bedrock (Claude Haiku 4.5) for key dialogue; Lambda + API Gateway |

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
- The order of NPCs, found texts and events is shuffled. Important NPCs can appear on any island; their lines react to what has happened so far (handwritten in v1; AI-generated in v2, §16).
- Seeded runs let friends share a seed. Daily runs use the date. (v2: seeds, dailies and challenges are not in v1.)

## 4. Survival meters

Thirst is the main pressure; everything else makes it harder to manage.

Rates are per real minute (one in-game hour is 30 real seconds, see §5). The numbers were retuned in the `survival-meters` change and are provisional until the Milestone A playtest; `game/resources/survival_tuning.tres` holds them, per real second.

| Meter | Max | Drains from | Restored by | At zero |
| --- | --- | --- | --- | --- |
| Thirst | 100 | 6/min at rest; ×2 in direct sun (day phase, on land, no shade), ×3 swimming instead of the sun, ×0.5 at night | Coconut 15, rain cup 25, still 40, well 30 | Health drains 2/s |
| Hunger | 100 | 3/min, ×2 while crafting or swimming | Crab 20, fish 30, eggs 10, sea grapes 5 | Energy capped at 50 |
| Heat | 0 (cool) → 100 (rises; decided 2026-11-05) | Rises 45/min in direct sun between 10:00 and 16:00, ×2 in scorching calm | Falls 45/min in shade, in water or outside 10:00–16:00; 0 at night | At 100, sunstroke until heat drops below 60: blurred screen, speed −40% |
| Energy | 100 | Swimming 3/s, building 1/s, running 0.5/s | Sleep (+50 per night in shelter), meals (+10); nothing else | Collapse: can only crawl |
| Morale | 100 | Loss of ally −30, squall −10 (both hit every player), −5/min at night with no teammate and no lit fire within 5 tiles | Teammate within 5 tiles +2/min, fire +5, song +15, found text +10, keepsake | Below 20: hallucinations: fake islands, fake voices |
| Health | 100 | Attacks, thirst, poison (−20 over 30 s), bleeding (6/min until 120 s after the latest wound; never the last point, so it never downs or kills) | Sábila (+5, stops bleeding), rest, noni | Downed (solo: last stand) |

What that means for one player starting full at dawn: thirst lasts 1.15 days (≈ 14 min) working in the sun all day, 1.4 days half in the shade, 1.75 days resting in the shade. Hunger lasts 2–2.8 days. Standing in the midday sun brings sunstroke after 133 s (67 s in scorching calm); half sun, half shade never does on a normal day. Heat never costs health (provisional).

**Downed, not dead.** A player at 0 health is downed for 90 s plus their downed-timer bonuses (Experiencia +5 s per level, the +10 s point boost), still losing thirst and hunger. Teammates can drag them to shade and give water to revive them at 30 health. An unrevived player dies: permadeath for the run. A dead co-op player watches a living teammate instead of their own body, switching between them with A/D, ←/→, the D-pad or the mouse wheel, until the last of them dies and the run summary shows; a rider waiting on the next island's shore watches the same way. A solo death goes straight to the summary (`ui-shell` "Spectating a teammate").

**Last stand (solo).** A player with no other living player in the run (solo, or the last one alive) is not downed at 0 health: they get a last stand of 0 s plus the same bonuses, lying where they fell, and can drink a reviving cup they carry to stand at 30 health. On run 1, with no bonus, that is death at once. The Medalla de la Caridad's one free revive per run stands its holder at 30 health instead of going down, a last stand or death, solo or not.

**Alone.** Every meter works for one player (provisional numbers). A lit fire within 5 tiles keeps a lone player company at night, so the night drain stops; a fire also shows to patrols. One player playing half in the sun gets through 3 days on the sandbar on 9 of its 10 coconuts, and a week with a fire every night and a squall every day still ends at morale 65.

**Drinking seawater** restores 10 thirst, then drains 30 over the next two minutes. Desperate players will do it anyway. That is the point.

**Feeling a hit** (`damage-feedback`, owner 2026-11-14). Each player's game works out hits and drains from the health it already receives, so nothing new is sent.
- **A hit** is health lost at once: a shark's 25, a crab's 5.
  - The hurt body is drawn white for one frame, then blinks for 0.6 s, on every screen.
  - On the screen showing that body's meters (your own, or the teammate you watch while dead):
    - the screen edges flash red, stronger for a bigger hit, with a floor so a crab's 5 still shows, at most three times a second;
    - the Salud bar shows the lost part in pale red, holds it 0.4 s, drains it over 0.5 s, and shakes by 1 px.
  - No number floats for a hit.
- **A drain** is health lost over time: thirst at 0, drowning, manzanillo. It only ticks the lost part down and glows the Salud frame dim red until 1 s after the last loss.
- **A meter that jumps at once** floats its change over that body on every screen ("+15 Sed", in the meter's colour, or "+6 Sed" when only 6 fit), and its bar lights the gained part and flashes once.
- **A status that clears** floats "Sin sangrado".
- **"Reducir destellos"** in Ajustes turns every blink, flash and shake into a steady tint or nothing.

**Reading the HUD** (`hud-window-kit`, owner 2026-11-14 and 2026-11-15). The HUD sits on dark rounded windows, cream paper for notes, all in the game palette (`ui-shell` "Shared theme").
- **The meters** read Salud, Sed, Hambre, Calor, Energía, Ánimo from the top: a label, a thin bar in the meter's colour and the value. A label turns orange at 50 (heat at 50) and red at 25 (heat at 75), where the bar's frame and the value pulse.
- **Teammates** sit top right, one block each: the name, a chip in their clothing colour, a small health bar and their state ("Caído", "Muerto", "Desconectado").
- **The strip** keeps its slots. Small digits give a stack's count or a tool's uses (orange on the last use), the number key shows only on the selected slot, a slot whose use would be refused now is dimmed, and the mouse gets a tooltip with the item and its verb.

## 5. Weather and time

A day is 12 real minutes: dawn (1), day (5), dusk (1), night (5). One in-game hour is 30 real seconds and the clock reads 06:00 when dawn starts, so the day phase runs 08:00–18:00, dusk 18:00–20:00 and night 20:00–06:00 (provisional, `survival-meters`). Midday, 10:00–16:00, is the middle 3 real minutes of the day phase.

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

**Using an item** (`damage-feedback`). The row above the selected item says what its use does, built from the item's own data:
- "Sed +15 · Hambre +5 · Energía +10" for a coconut, which counts as a meal;
- "Sed +15 (+6 útil)" when only part fits;
- "Cura quemadura y sangrado · Salud +5" for sábila.

A use that would change nothing is refused with a reason and spends nothing:
- "No tienes sed.";
- "'Tás entero." (sábila at full health);
- "No hay na' que curar.";
- "A Papo no le hace falta.".

It counts as changing nothing only when every meter it raises is within 1 point of full, every status it cures is absent, and it has no other effect. A coconut is still drunk when you are hungry, and a conch still leaves its horn.

**Durability.** Tools wear out. The raft loses integrity on each crossing to what its riders do not dodge, plug or shoo (§8 "Playing the crossing"; measured on a 75 s coast crossing: about 70 for a rider who does nothing, under 10 for an attentive one, a squall's 30 aside) and more in squalls; a plank caught at sea mends 10, and on land it is repaired with driftwood and rope.

**Mending the raft** (`island-stop`). Any built raft still on the island can be mended at its work point, on its land side. A mend costs 1 driftwood and 1 rope and 10 s of work (5 s for a Mecánico), gives +20 integrity, never goes above the raft's maximum, and can be repeated.
- There is one job on a raft at a time. Anyone deposits into it and anyone works it.
- A launch ends an unfinished job and gives the deposits back.
- An intact raft can always sail on at once: there is no gate. Its prompt shows its integrity and warns below half.
- Stopping pays in mends now. The fittings (clavazón, defensas, toldo) follow in the change's second PR.

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
| The floating almendrón | A rusted 1950s car with its drive shaft: 4 drums, 4 rope, 6 nails, 4 driftwood, a propeller, and a fuel jug per crossing | Fastest and loudest: starting it is heard 25 tiles away (50% chance to alert the patrol); a squall swamps it (×1.5 damage); the fuel jug is contested | Everyone |
| The board | A rental surfboard rigged with a sail (board, tarp, hardwood, 2 rope), trade wind, no bleeding; one board per rider | Fastest and loneliest: sharks ×1.3, drift ×1.5; a squall or shark dumps the rider; the board is lost on arrival | One rider per board |

The turtle's two-seat limit and the swimmer's energy cost are intentional: a 4-player party often has to split routes and meet on the next island.

The almendrón and the board are rolled extras on a few chains (`ISLANDS.md`), never an island's guaranteed route: the raft stays guaranteed wherever they appear. One player can finish either one alone: the car's pliers, propeller, nails, drums and fuel are all on its island, and the board's shack always holds a board plus the tarp, hardwood and rope for one sail. Tomás refuses the board as he refuses rafts; Marisol and Alfredo cannot swim, so only the car takes them.

## 8. The crossing

A 60–120 second sequence on a scrolling sea. Threats roll by distance from Cuba and weather: reef sharks follow blood; a squall line forces you to tie down; searchlights sweep from a cutter on the early chains; the Gulf Stream pushes east: anyone aboard slows the drift to 0.25 tile/s, and a *Maestro*, Navigation 2 or a compass with charts cancels it (the secret *Brújula rota* and *Mapa sin norte* never count as either, `ITEMS.md` "Secret items"). Drift pushes you sideways (up to 40 tiles, then you overshoot to a harder chain) but never makes the crossing longer. A car rides high and is hard to fall off (sharks ×0.6) but is loud under a searchlight (threats ×1.2). A board is its own small vessel: each rider has one (integrity 60) and it has no lashing, so nobody ties down on a board. A squall hits every board and dumps every board rider; a rock or a shark hits one board at a time, in turn through the riders, and a shark dumps that board's rider. A rider climbs back onto their own board as below, or a teammate on their own board pulls them onto it, and at 0 the board breaks and its rider swims the rest. Only a raft is ever beached on the next island: the board is lost on arrival, and the car is not beached yet. Board riders land 10–20 tiles apart instead of within 5, so a party finds each other on the next beach; a solo rider has nobody to look for. Falling in the water costs energy and attracts sharks; a swimmer climbs back aboard alone by holding interact for 3 s at the edge, or a teammate pulls them in 2 s. The raft takes damage; at 0 it breaks and everyone swims the rest or drowns.

Swimmers in the water lose energy every second, moving or not (3 a second, times the route's drain factor: 0.4 for binoculars-and-swim, so a solo swimmer at 100 ends a 60 s crossing with 28); at 0 energy they drown at 10 health a second. Falling in costs 10 energy.

**Playing the crossing** (`crossing-gameplay`, decided 2026-11-15). Every beat is warned before it lands and can be answered by one rider, so a solo crossing is played, not watched:

- **Paddling.** A rider aboard holds interact at the paddle on the deck's west or east edge (on a board, beside it) to slide the vessel that way: 1.5 tiles/s, 2.25 with two or more on one side, the two sides subtracting, never more than 6 tiles from the line. When nobody paddles, the current pulls it back to the line at 0.5 tiles/s, so a rider who does nothing sits on the line and meets every beat in it. Paddling is not drift: coast drift stays 0 and the Gulf Stream rule above is untouched.
- **Rocks and debris** come down a lane from the sea's north edge, 5 s before they reach the deck, and hit only where their lane overlaps the vessel (a rock is 2 tiles wide, debris 1, the raft and the car 4, boards the whole row): a rock −40, debris −5. A row of boards takes each hit on the next board in turn, as above. A swimmer a rock passes over is cut (−15 health and bleeding, so the shark's first choice); debris takes 5.
- **Leaks.** Debris that hits a vessel also opens a leak on the half of its deck nearer the debris (on a board, on that board): it drains 0.5 integrity a second until a rider aboard that vessel, untied, holds interact on it for 2 s. At most 3 are open on one vessel.
- **Flotsam.** Coconuts, driftwood, rope, plastic jugs, cloth, the odd inner tube and planks drift down lanes 2 to 5 tiles off the line. A rider aboard holds interact for 0.3 s as a piece passes within 1 tile of them, or a swimmer touches it: an item goes into their inventory (a full one leaves it in the sea), a plank is lashed on at once for +10, up to the route's full integrity (a raft launched at 70 can be mended to 100). Items still cannot be used at sea.
- **The shark** is told 5 s ahead by its fin circling 1 tile off one side; a rider aboard who holds interact on it for 1 s before the strike shoos it off. When a press reaches several jobs, it goes to the fin, then a swimmer to pull, then flotsam, then a leak, then a paddle or the lashing.
- **The crossing HUD** sits top-centre under the day phase: a strip from island to island with the vessel at the share of the crossing gone, the vessel's integrity ("Balsa 70/100", "A nado" for swimmers), and short shouted lines for the squall (30 s and 10 s before its hit), a fin and a leak.
- **Pacing.** The host rolls no beat in the first 6 s, puts the first between 6 and 9 s and then one every 3 to 9 s (the 9 s ×0.9 for each rider past the first), with rocks, debris and flotsam weighted 0.12, 0.20 and 0.68 on the coast. The squall's blow (the 15 s after its hit, when paddling runs at half speed) holds no rolled beat, and a rock or debris falls in the 10 s before a hit, so tying down early costs a dodge. Every crossing ends with the reef line: two rocks 10 tiles apart, 4 s before the end, with the gap within 3 tiles of the line.

## 9. Threats

Full lore and behavior specs in `BESTIARY.md`. Summary:

| Threat | Behavior | Reference archetype |
| --- | --- | --- |
| Reef shark | Circles; strikes when you bleed | DCSS shark frenzy |
| Moray eel | Hidden in reef holes; ambush | Brogue eel |
| Barracuda school | Swarm shiny objects | Brogue jackal pack |
| Portuguese man o' war | Passive drifting trap; paralysis sting | SPD / Brogue traps |
| Land crabs | Night thieves; steal from stashes | SPD sewer crab |
| Seagulls | Steal food and flee; the same species rides the final crossing as the *galleguito* | Brogue monkey |
| Mosquito cloud | Energy drain at dusk | Brogue / DCSS gas |
| American crocodile | Drags you under in still water | Brogue bog monster |
| Guardacostas | Patrol routes, searchlights, shore squads, capture | Brogue stealth/noise |
| Weather | Environmental pressure | Brogue terrain effects |

**Bosses**, one per chain: the guardacostas cutter (coast), the old crocodile (mangroves), the tiger shark (reef), the hurricane (storm key), the Florida Straits (final crossing).

### Guardacostas and stealth

The human threat on the first two or three islands, fading as you head north. Patrol boats run fixed routes; at night a searchlight cone sweeps beach and water. A spotted swimmer is chased (2× swim speed, deep water only) and hauled aboard after 2 s alongside; the shallows, land, a dive or a 10-tile gap break the chase. An alert on land (a player spotted ashore, smoke or noise) lands a shore squad of three by dinghy, which searches the island for three minutes: every lit fire first, then the last known position, then a random walk. A caught player is walked to the dinghy on the landing beach; a teammate frees them with a 1 s hold while no soldier is within 3 tiles. When the squad leaves while someone is still free, it takes its captives along: they wait out of play with only their keepsakes (their secret items stay on the beach) and land with the party on the next island. When the last free player is caught (a solo player always is; downed and dropped teammates go along), *La captura* plays with Rodríguez on every peer, in a minimal scene panel: a party with a standing Maestro or Médico at morale 60 or more is released at the next cay, keeping everything (released from the last island, the run ends); otherwise it restarts the previous island, regenerated from the run seed, keeping its items except fire sources (keepsakes always stay). Meters and the clock carry on, and the islands reached never count an island twice. On island 1 the party restarts island 1 the same way. The secret cay is never the previous island (a party caught after the detour restarts the island it left for the cay), and a regenerated island never places a secret piece the run has already spawned (`ISLANDS.md` "Secret: El cayo sin norte"). Caught on the final crossing, the run ends: *Devuelto*. Stealth is a skill: crouching in brush, diving, hiding in mangroves and putting out fires all count.

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

Any player can do anything; backgrounds do it better. Solo uses the same base numbers as co-op, and any background can finish a run: every island set up for one living player has at least one escape route that needs no background skill and no starting item.

### Co-op rules

- Host-and-join, up to 4. Host is authoritative.
- A raft needs everyone's materials; crafting a shared project pools inventories.
- Downed players can be dragged, revived with water, and fed.
- Morale is shared: losing a player hits everyone.
- Difficulty scales: resources ×0.8 per extra player, patrols +1 per 2 players. The secret cay is never scaled: its handmade contents are the same for 1–4 players and it has no patrols (`ISLANDS.md` "Secret: El cayo sin norte").
- Voice chat is not built in; players use their own. Quick-chat wheel with Cuban phrases (*¡Dale!*, *¡Agua!*, *¡Pa'llá no!*, *¡Tiburón!*).

## 11. NPCs

Full backstories in `CHARACTERS.md`. Important NPCs (handwritten in v1, AI dialogue in v2) are **Ramón** the fisherman, **La Vieja Caridad** the lighthouse hermit, **Yunior** the kid, **El Capitán Rodríguez** (guardacostas), and the rescued balseros **Dayana**, **Papo** and **El Chino**. Minor NPCs use handwritten lines.

Rescued balseros join your party as AI companions (like Brogue's freed captives). Each needs something to survive the trip and each changes the ending.

## 12. Found texts

Bottle notes, journals, wet letters, radio fragments and wall graffiti. They carry lore, hints and the political voice of the game. Important texts (found every run, AI-generated and reacting to your run) include **La libreta de Ramón**, **El diario del Período Especial**, **Las cartas de la Yuma** and **La lista**.

## 13. Endings

Decided: multiple endings, based on who you saved and how.

| Outcome | Ending |
| --- | --- |
| Everyone you met made it (at least one companion met) | *Todos.* The whole group walks up the beach together. |
| Two or more survivors, but not *Todos* (someone you met was lost, or nobody was met) | *Los que llegamos.* Reunion on the pier; a chair stays empty. |
| Only one survivor (any party size, solo included) | *Solo.* A long silent walk. A phone call home. |
| Whole party captured on the final crossing | *Devuelto.* Fade on the deck of the cutter. Ends the run as a loss (counts as a death) and unlocks a keepsake. |
| Secret: Yunior reaches land | *El Niño.* A different voice reads the credits. |

Survivors are the players and companions who reach land. The first match wins, in this order: *Devuelto*, *El Niño*, *Solo*, *Todos*, *Los que llegamos*. A solo player who met nobody gets *Solo*; one who brings a companion to land can get *Todos*.

**Epilogue lines.** Each ending card can carry flag-gated one-liners (data, not new endings; the selection order above is unchanged):

- *El galleguito* (flag `galleguito_a_bordo`, set when the gull perched on someone during the final crossing; all five endings): the gull gets off first and walks up the beach, or in *Devuelto* is never sent back. It rides every final crossing out, solo included.
- *El pilote* (every landing ending, no condition): "Pisamos arena. Ahora empieza la otra cola: la de los papeles." The era makes it true: landing is the win, not a legal guarantee.
- *El almendrón* (flag `almendron_a_bordo`, the car was used this run): the key and the gas smell are all that is left. In *Devuelto*, if the car was sunk at sea (`almendron_hundido`), the car stays on the bottom.

## 14. Roguelite progression

Permadeath per run. Between runs you unlock **memories**: keepsakes you can start with.

| Keepsake | Effect | Unlock |
| --- | --- | --- |
| Foto de la familia | Morale drains 30% slower | Finish any run |
| Cuchillo del abuelo | Start with a knife | Kill a shark |
| Medalla de la Caridad | One free revive per run, solo included (`survival-meters` defines how) | Save La Vieja's quest |
| Nudo del pescador | Rafts 25% stronger | Cross 3 times by raft |
| Pedazo de mapa | Reveals one route on island 1 | Reach the storm key |
| Cassette de Los Van Van | Music works without a Músico | Finish with a Músico |
| Llave del almendrón | Building ×1.2 for the holder | Cross once by the almendrón |
| Pluma de galleguito | Gulls never steal from the holder (island gulls and the final galleguito) | Be returned (*Devuelto*) once |

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
| Map knowledge | Chain layouts you reached show POI icons on arrival next run; nothing from the secret cay or its pieces (no map knowledge, route or hiding spot) is ever kept | All, with the same exception |
| Keepsakes | Unlocked ones stay | Unlocked ones stay |
| Items | None | None |

Rules:
- Skills cap at level 5 per background skill and level 3 for the others; carry-over never pushes a skill above level 3 without a run that earned it.
- Each run also grants **1 Experiencia point** per island reached, spent at the start of the next run on small permanent boosts: +10 max thirst, +1 inventory slot, +10 s downed timer, start with a known plant, start with 1 rope. Max 12 points banked; spending is the only way to use them. The secret cay is not an island reached and grants no point.
- **The world eases a little per death, capped.** Each death adds one "Experiencia level" (max 8). Per level: thirst and hunger drain −3%, patrol period +10 s, one extra driftwood and one extra coconut per island (never on the secret cay, whose contents are fixed), downed timer +5 s. At the cap that is drains −24%, patrols at 4:20 instead of 3:00, and 8 extra materials per island: enough to feel the game meet you halfway, not enough to remove the pressure.
- **Downed-timer rewards in solo.** For a player with no other living player (solo, or the last one alive), the downed timer is a last-stand window with a 0 s base, so a first solo run stays brutal. The +5 s per Experiencia level and the +10 s boost lengthen that window (for example 30 s at level 4 with the boost); `survival-meters` defines what the player can do in it, and the Medalla revive, which fires at 0 health before the window starts, so it saves a solo player even on run 1.
- Winning a run removes 2 Experiencia levels (the game gets harder again for a champion) and unlocks a keepsake.
- *Devuelto* is a loss: it counts as a death (one Experiencia level added, the death carry-over above) and removes no levels. It unlocks the *Pluma de galleguito*, a small consolation and a joke, not a power spike.
- Seeded and daily runs earn Experiencia but do not spend it.

Challenges (optional hard modes): no fire, permanent storm season, sinking raft from the start, patrols on every island (except the secret cay, which never has patrols; the other challenges apply there as anywhere).

## 15. Cuban voice and humor

The game speaks like Cubans talk.

| Layer | Examples | Where |
| --- | --- | --- |
| Slang | asere, ¿qué bolá?, tremendo, la yuma, resolver, la lucha, no es fácil, pincha, jeva, fula | All dialogue |
| Political references | la libreta, la cola, los apagones, el Período Especial, slogans on walls, 1994 | Found texts, NPC stories, item descriptions |
| Ironic slogans | Revolutionary slogans repurposed as item names and loading tips | UI, loading screens |
| Profanity | coño, cojones, pinga, and stronger, in the right places | Reactions, shark attacks, storms |

Rules: satire targets the system, slogans and daily life, not invented quotes from real politicians. A settings toggle softens profanity. Haiku receives a style guide and slang glossary. Spanish first.

## 16. AI dialogue and voice (v2)

This whole section is v2 (owner decision, 2026-11-08). In v1 every line is handwritten, the important NPCs and the texts found every run included, and there is no voice acting; music stays in v1.

Claude Haiku 4.5 on Amazon Bedrock generates dialogue for **important NPCs and the texts found every run**, so the content players see most stays fresh. Minor NPCs, story beats, bosses and endings are handwritten.

| Item | Decision |
| --- | --- |
| Model | Claude Haiku 4.5 on Bedrock (~$1 in / $5 out per 1M tokens) |
| Cost | ~$0.0015 per line; a few cents per run |
| Pipeline | Godot `HTTPRequest` → API Gateway → Lambda → Bedrock |
| Input | Game-state JSON: island, weather, party, who was saved, items, NPC profile, run history; never a secret item or the secret cay (`ITEMS.md` "Secret items") |
| Output | `{speaker, text, emotion}` |
| Voice | Pre-generated Chatterbox (cloned Cuban voices) for handwritten lines; Kokoro at runtime for generated ones |
| Safeguards | Keys only in Lambda; per-player rate limits; cache by state hash; handwritten fallbacks offline |
| Fallback model | Amazon Nova Micro/Lite for low-stakes flavor if costs grow |

## 17. Technical plan

| System | Godot approach | Reference |
| --- | --- | --- |
| Island generation | TileMapLayer, seeded integer island shape (no floating-point noise), rule-placed POIs | SPD room builders, Brogue blobs, DCSS Shoals |
| Natural features | Mangroves, reefs, tide pools by placement rules | Brogue lakes and machines |
| Pathfinding and AI | AStarGrid2D; state machines per creature | Brogue Dijkstra maps |
| Data | Custom Resources (.tres) for items, creatures, NPCs, recipes | DCSS data files |
| Survival meters | `SurvivalMeters` component, host-synced | Original |
| Multiplayer | ENet by default behind a platform backend (net-platform); MultiplayerSpawner, MultiplayerSynchronizer | Godot docs |
| Weather and day-night | `WeatherManager` autoload driving CanvasModulate and spawns | Original |
| Stealth | Searchlight cones tested by the host as plain geometry (angle and distance; no Area2D, no occlusion), a spot meter per player, noise and smoke events on a bus owned by the session (not an autoload) | Brogue stealth, SPD guard cones, DCSS noise |
| Dialogue | `DialogueService` autoload with cache + fallback | Original |
| Sound | `AudioManager` autoload plays ids from `sound_bank.tres`; `RunSounds`, one per peer, reads state the peer already holds | SPD `Sample`, DCSS `sound.cc`, DST hound warning |

### Sound (`sound-pass`, 2026-11-23)

The first pass is about 15 retro effects and loops, and no music, which is still a Milestone G task.
- **Where the sounds come from.** Twelve are generated by `tools/audio/sfx.py` from `tools/audio/sounds.json`, so any of them can be rebuilt and tuned. The sea, wind and thunder are CC0 recordings from Freesound, each file approved by the owner. `tools/audio/recordings.py` trims them using `tools/audio/recordings.json`.
- **Own events are heard only by their player.** These are the pick-up, the hurt and use cues, low thirst (Sed at 25, where the bar pulses) and the compass rattle.
- **World events are heard by everyone.** These are the sea (louder at sea), the wind (crossings and squalls), insects at night on an island, thunder (quiet at a squall's warning, loud when it breaks), the patrol motor, the loudhailer, a hit on your raft, and arrival.
- **The patrol motor.** It swells over the boat's 20 s horizon warning and then follows the boat's distance, so the patrol is heard before it is seen. This is DST's growing hound warning.
- **Sound never carries information alone.** Every cue has something you can see, so a muted player loses nothing. This follows Brogue, which has no audio at all.
- **Sound never changes the simulation.** A test runs the same run with and without it.
- **Volume.** The volume setting (Ajustes "Volumen", 0 to 100 %, default 80 %) scales everything.

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
