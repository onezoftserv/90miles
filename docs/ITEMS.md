# 90 Millas — Items

Every item, with tags, effect and where it comes from. Items are `.tres` resources (`game/resources/items/<id>.tres`). Numbers are first-pass; tune in playtests. Study: Shattered Pixel Dungeon `items/` for the identify/upgrade pattern, DCSS item data for data-driven definitions.

Tags: `food`, `water`, `tool`, `weapon`, `material`, `wearable`, `shiny` (attracts barracuda), `keepsake`, `text`, `container`, `fuel`, `medicine`, `unknown` (needs identification).

## Water (6)

| Item | Thirst | Source | Notes |
| --- | --- | --- | --- |
| Coco (green coconut) | +15, hunger +5 | Palms | Needs a knife or a rock; 2 uses |
| Rain cup | +25 | Rain catcher | 1 use; jug stores 4 |
| Still cup | +40 | Solar still, 1 per 12 in-game hours | |
| Well cup | +30 | Lighthouse well only | |
| Seawater cup | +10, then −30 over 120 s | Anywhere | The desperate option |
| Rum (bottle) | +5, morale +15, energy −10, thirst −10 after | Tourist wreck, Papo | 3 uses; Papo's need |

## Food (14)

| Item | Hunger | Source | Risk |
| --- | --- | --- | --- |
| Crab (raw) | +20 | Beaches at night, tide pools | 30% poison |
| Crab (cooked) | +25 | Fire + raw crab | — |
| Fish (raw) | +30 | Spear, line | 30% poison; bait for turtle |
| Fish (cooked) | +35 | Fire | — |
| Lobster | +35 | Traps | Moray in some traps |
| Oysters (6) | +12, thirst +2 | Mangrove roots | Cuts hands without cloth; red tide 60% poison |
| Conch | +25 | Reef flats | Shell becomes a horn (noise radius 15) |
| Bird eggs (5) | +10 | Nests | Gulls |
| Sea grapes | +5 | Dunes | — |
| Coco plum | +8, thirst +3 | Dunes | — |
| Mango | +20, thirst +10 | Lighthouse garden only | — |
| Hutía (cooked) | +40 | Snare, far cays | — |
| Iguana (cooked) | +35 | Rock, storm key | — |
| Canned food (1990s) | +30 | Wreck galley | 20% poison; needs a knife to open |

## Unknown plants and fruit (10) — the identify game

Each run assigns a random look ("fruta roja", "fruta verde", "baya morada", "hongo blanco"…) to each plant below. One player eating it, a Médico seeing it, or an NPC naming it identifies it for the party. Identifications carry over between runs (Experiencia).

| Plant | True effect | Lore |
| --- | --- | --- |
| Manzanillo (manchineel) | −50 health over 60 s, thirst ×2 | The little apple of death |
| Guao | Touch: burning 20 s, no food | Cuba's poison ivy, worse |
| Jagüey fig | +15 hunger | Safe, sticky |
| Uva caleta (sea grape, unripe) | +3 hunger, thirst −5 | Sour and useless |
| Hicaco (coco plum) | +8, thirst +3 | Safe |
| Guanábana (rare) | +25, thirst +15, morale +10 | Grandmother's fruit |
| Noni | +5 hunger, heals 10, cures poison | Smells like vomit, works |
| Sábila (aloe) | Heals sunburn and bleeding | Known to any Cuban over 40 |
| Hongo de playa | 40% hallucinations for 2 min, 60% +10 hunger | A coin flip |
| Hierba de tabaco silvestre | Morale +10 when smoked (needs fire) | Ex-militar identifies on sight |

## Tools (14)

| Item | Use | Durability | Source |
| --- | --- | --- | --- |
| Cuchillo (knife) | Open coconuts, cut nets, craft; weapon 10 dmg | 40 uses | Hut, grandfather keepsake |
| Machete | Weapon 20 dmg, cut mangrove paths, open coconuts | 60 | Ex-militar start, wreck |
| Botella rota (broken bottle) | Weapon 8 dmg, bleeding; shiny | 5 | Any wreck; the desperate weapon |
| Spear | Fish in shallows; weapon 12 dmg; shark nose hit | 30 | Craft: driftwood + knife |
| Fishing line + hook | Fish from shore or raft | 25 | Pescador start, Ramón, traps |
| Lure (shiny) | Fish ×2 rate; attracts barracuda when swimming | — | Wrecks |
| Net | Catch 3 fish per cast in shallows; also traps crabs | 15 | Captain's chest, Ramón |
| Snare | Catches hutía, crabs overnight | 10 | Craft: rope + stick |
| Pliers | Pull nails, open cans, repair; building ×1.5 | 50 | Mecánico start |
| Binoculars | Spot islands at any time of day; reveals routes | — | Rock cairn, captain's chest |
| Compass | Steer on crossings | — | Lighthouse, Caridad |
| Charts | Gulf Stream route; island layouts for the chain | — | Caridad (quest) |
| Mirror | Signal boats by day; shiny | — | Observation post |
| Lighter | Instant fire; 20 uses | 20 | Rope cache |
| Flint + steel | Fire in 10 s | — | Craft: rock + knife |
| Shovel (oar) | Dig shade pits, bury stashes, dig in for the hurricane | 30 | Papo makes from hardwood |

## Materials (12)

| Item | Used in | Source |
| --- | --- | --- |
| Driftwood | Raft, fire, spear, shelter | Beaches; storms pile it on shingle |
| Hardwood | Mast, oars, stronger raft (+50 integrity) | Mangrove hammock, casuarinas |
| Inner tube | Raft flotation (2 per raft) | Flotsam, other balseros |
| Plastic jug | Water storage (4 cups), still, sealed stash | Flotsam |
| Rope | Raft, snare, turtle harness, tie-down | Wrecks, traps, cache, Ramón |
| Fishing line (spool) | Lines, snares, stitching | Traps, wrecks |
| Tarp | Sail, shade, rain catcher, still | Hut, tourist wreck |
| Nails | Repair the wreck (6), reinforce raft | Observation post, galley |
| Resin | Seal the wreck (2), waterproof | Casuarina sap + fire |
| Dry grass / needles | Fire starting | Dunes, casuarinas |
| Cloth (shirt, towel) | Gloves for oysters, bandages, sail patch | Wrecks, your own shirt (heat +) |
| Tire | Sandals (craft), raft fender | Flotsam |

## Wearables (8)

| Item | Effect | Trade-off |
| --- | --- | --- |
| Sombrero de yarey (straw hat) | Heat −30% | Blows off in squalls |
| Life vest | Float at 0 energy; +buoyancy | Swim speed −20% |
| Wetsuit scrap (top) | Swim thirst ×2 instead of ×3; coral cuts −50% | Heat +20% on land |
| Fins | Swim speed +30% | Walk speed −30%; must remove |
| Sandals (tire + rope) | Immune to urchins, stingray, ants | — |
| Gloves (cloth) | Oysters and traps without bleeding | — |
| Sunglasses (shiny) | Binoculars work in scorching calm glare | Barracuda |
| Military belt | +2 inventory slots | Ex-militar start |

## Wreck loot and oddities (12)

| Item | Effect | Lore |
| --- | --- | --- |
| Flare (×2) | Signal-boat route at night, 100% boats notice, 100% patrols notice | Pick who sees it |
| Radio (dead) | Nothing until a battery; then the radio fragments | |
| Car battery | Powers the radio or charges Yunior's phone | Heavy (10) |
| Solar charger | Charges the phone over a full day | Captain's chest |
| VHF handset | Call the Miami fisherman once, far chains only | |
| GPS (dead battery) | With the car battery: shows your real position once | Overshoot insurance |
| Expired medicine | 50% heals 30, 50% nothing, 10% poison | A Médico reads the label |
| Cigars (box) | Morale +15 per cigar, 5; needs fire; smoke draws patrols | Cohibas, obviously fake |
| A Bible / a Granma newspaper | Pages are fire starter (10 fires); reading = morale +5 | Players choose which they burn first |
| Baseball | Thrown weapon 8 dmg, returns if you fetch it; morale +5 to play catch | Every raft had one |
| Dominoes (set) | At a fire with 2+ players: morale +20 for all, costs 1 night phase | Nobody leaves mid-game |
| Hand pump + bilge bucket | Repaired boat sinks 50% slower; raft sheds squall water | |

## Keepsakes (7)

See `GAME_DESIGN.md` §14 for unlocks. Each is one inventory slot and cannot be lost unless the player dies.

| Keepsake | Effect |
| --- | --- |
| Foto de la familia | Morale drain −30% |
| Cuchillo del abuelo | Start with a knife (unbreakable) |
| Medalla de la Caridad | One free revive per run |
| Nudo del pescador | Rafts +25% integrity |
| Pedazo de mapa | Reveals one route on island 1 |
| Cassette de Los Van Van | Músico songs without a Músico (radio + battery needed) |
| Pelota firmada | Morale +10 to everyone when thrown; unlocks if Yunior reaches land |

## Found texts (12 types)

Readable items. Important ones (marked AI) are generated per run.

| Text | Where | AI |
| --- | --- | --- |
| La libreta de Ramón | Ramón's boat | AI |
| El diario del Período Especial | Camp ruins | AI |
| Las cartas de la Yuma | El ahogado, wreck hull | AI |
| La lista | Lighthouse wall | AI |
| Bottle note | Any beach | AI |
| Reply bottle (to your own note) | Later island | AI |
| Wall slogan | Bunkers, wrecks | HW |
| Radio fragment | Radio + battery | HW |
| Tourist menu board | Tourist wreck | HW |
| Patrol logbook page | Patrol dinghy | HW |
| Yunior's school notebook | Yunior | HW |
| Captain's log (the freighter) | Captain's cabin | HW |

## Counts

6 water, 14 food, 10 plants, 16 tools, 12 materials, 8 wearables, 12 oddities, 7 keepsakes, 12 texts = **97 item definitions**.
