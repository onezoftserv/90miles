# 90 Millas — Items

Every item, with tags, effect and where it comes from. Items are `.tres` resources (`game/resources/items/<id>.tres`). Numbers are first-pass; tune in playtests. Study: Shattered Pixel Dungeon `items/` for the identify/upgrade pattern, DCSS item data for data-driven definitions.

Tags: `food`, `water`, `tool`, `weapon`, `material`, `wearable`, `shiny` (attracts barracuda), `keepsake`, `text`, `container`, `fuel`, `medicine`, `unknown` (needs identification), `secret` (never shown by charts, binoculars, map knowledge, route discovery, HUD markers or AI context, and never picked by item-tag spawns or found-text placement, so its spawn weight is 0; see "Secret items" below).

## Water (7)

| Item | Thirst | Source | Notes |
| --- | --- | --- | --- |
| Coco (green coconut) | +15, hunger +5 | Palms | Needs a knife or a rock; 2 uses |
| Rain cup | +25 | Rain catcher | 1 use; jug stores 4 |
| Still cup | +40 | Solar still, 1 per 12 in-game hours | |
| Well cup | +30 | Lighthouse well only | |
| Seawater cup | +10, then −30 over 120 s | Anywhere | The desperate option |
| Rum (bottle) | +5, morale +15, energy −10, thirst −10 after | Tourist wreck, Papo | 3 uses; Papo's need |
| Milordo | +20, hunger 0, morale +3 once a day | Craft: 1 sugar + 1 rain cup, 5 s, no station | *Milordo*: sugar water served as "coffee". Not a meal (no energy), no `water` tag, never revives; seawater cups cannot make it |

## Food (16)

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
| Toronja (grapefruit) | +5, thirst −2 | Fishermen's houses (1–3, respawns daily), lighthouse old garden | "Amarga." Cooks into the steak at a fire in 20 s (`cooks_into`, no recipe) |
| Bistec de toronja | +8, morale +5 to the eater once a day | Fire + toronja | A joke dish, not a food source (cooked fish is +35). Grapefruit pith, breaded and fried (`docs/LORE.md` §3) |

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

## Tools (18)

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
| Tabla (surfboard) | Base for the sail; no use alone | — | The rental shack (1–2), tourist wreck (30%), a yacht vault. "Era de alquiler. El recibo dice 'devolver antes de las 5'. No dice de qué día." |
| Tabla con vela | Activate with trade wind to cross on the board route; one per rider; used up | — | Craft at a workbench: board + tarp + hardwood + 2 rope, 60 s (Mecánico ×2) |

## Materials (17)

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
| Tanque de 55 (drum) | Float for the almendrón (4); weight 6; floats only, never fuel | Fishermen's houses (2), resort generator (2–4), the car (2) |
| Propela | Welded to the car's drive shaft (1); shiny | The car |
| Bidón de combustible (fuel jug) | Tags `fuel`, `container`; spent by each almendrón crossing, Caridad's lamp (2) and wreck repair; weight 4 | Village dock (1), resort generator (1–2) |
| Azúcar (sugar) | Milordo; ingredient only, no use, stacks to 5 | Freighter galley (1–2), balseros' camps (trade) |
| Cámara de bicicleta (Chinese-bicycle tube) | 2 + 1 resin → 1 inner tube at a workbench, 30 s; weight 1, stacks to 4 | Flotsam line (30%, 1–2, respawns after a squall), fishermen's houses (1–2). "Esta cámara cruzó La Habana mil veces. Ahora le toca cruzar el mar." |

## Wearables (9)

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
| Sombrero de yarey con cinta roja (`sombrero_cinta_roja`, secret) | Heat −30%, like the yarey hat | Never blows off (it has a chin cord). Only one, hanging on the lean-to of the secret cay. Wearing it waits for the equipment change |

## Wreck loot and oddities (15)

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
| Botija | Blow into the emptied fuel jug at a lit fire (20 s): a bass note, morale +5 to players within 5 tiles once a day, +5 more with a Músico or the cassette present; plays no real song | Given to whoever starts the almendrón; also loot in the fishermen's houses (30%) and resort generator (50%). "En Cuba nada se bota: se reasigna." |
| Brújula rota (`brujula_rota`, secret) | Points to secrets: a HUD needle, shown only to its carrier, aims at the nearest concealed item on the island or at the secret cay's unopened chest and steadies as you close in. Never steers and never cancels drift | Concealed (reveal radius 3 tiles, 1.5 s hold to dig it out) on a mid-run island in 1 run in 3. "La única brújula que nunca te manda pa'l Norte." |
| Mapa sin norte (`mapa_sin_norte`, secret) | Does nothing alone; its text names the kind of spot where this run's compass hides. Never counts as charts | Concealed like the compass, on a different mid-run island. "Una X, {pista} y una rosa de los vientos torcida. Se nota que lo dibujaron con una brújula que no sirve." (`{pista}` is the hint phrase, see "Secret items") |

## Keepsakes (9)

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
| Llave del almendrón | Building ×1.2 for the holder; unlocks by crossing once by the almendrón. "La llave de un carro que está en el fondo del mar. O en Hialeah. Depende de cómo te fue." |
| Pluma de galleguito | Island gulls and the final galleguito never steal from the holder; unlocks on *Devuelto*. "Una pluma gris. Él llegó; tú no. Por lo menos los galleguitos ya te conocen." |

## Found texts (16 types)

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
| Se vende (note) | The raft-for-sale POI on sandbar and coast cays | HW |
| El fallo del pilote (the board) | The piling off the final sandbar | HW |
| El sobre de tres generaciones | Keeper's house, camp ruin (40% each) | HW |
| Llegaste tarde (`nota_llegaste_tarde`, secret) | The chest on the secret cay | HW |

The lore additions also give four existing texts new handwritten entries, no new files: bottle note (four entries that become its offline fallbacks), wall slogan (four slogans, each with a reply written under it), radio fragment (three broadcasts from generic stations) and the Special Period diary (four fallback pages). Every text is original, uses real places and years but only invented people with first names, and keeps its sources in `docs/LORE.md`. Each gives +10 morale on first read, as every found text does.

## Secret items (change `secret-cay`)

Four items tagged `secret`, for the hidden cay (`ISLANDS.md`, "El cayo sin norte"). In 1 run in 3 the compass and the map hide on two different islands from 2 to 5; with both, the party can detour to the cay. Every number lives in `game/resources/secret_tuning.tres`; the reveal radius is the items' own `conceal_radius_tiles`, and the tuning names which two items are the pieces (`map_item_id`, `compass_item_id`). Nothing secret is ever shown by charts, binoculars, the lighthouse, keepsakes, NPC reveals, route discovery, carried map knowledge, HUD markers or the AI. All four have `spawn_weight` 0, so no item-tag spawn or found-text placement ever picks them; the content validator rejects a `secret` item with a spawn weight above 0.

- **Brújula rota** / *Broken compass* (`brujula_rota`, oddity, weight 0.3, capability `POINT_TO_SECRET`, never `STEER` or `NAVIGATE_STREAM`). "La única brújula que nunca te manda pa'l Norte." / "The only compass that never sends you to el Norte."
- **Mapa sin norte** / *Map without north* (`mapa_sin_norte`, oddity, weight 0.1, never `REVEAL_LAYOUT` or `REVEAL_ROUTES`). "Una X, {pista} y una rosa de los vientos torcida. Se nota que lo dibujaron con una brújula que no sirve." / "An X, {pista} and a crooked compass rose. You can tell it was drawn with a compass that doesn't work." Each peer fills the `{pista}` slot with the hint phrase for the kind of spot where this run's compass hides (the kind of the spot's nearest feature; table below), never the island or the cell.
- **Sombrero de yarey con cinta roja** / *Yarey hat with a red band* (`sombrero_cinta_roja`, wearable, head, weight 0.3, heat gain ×0.7, no weather knocks it off). "Yarey de verdad, cinta roja sencilla y barbiquejo: a este no se lo lleva el viento." / "Real yarey, a plain red band and a chin cord: the wind won't take this one." One per cay, whoever takes it first. Later, everyone present unlocks it as a cosmetic for future runs (no stats from run start).
- **Llegaste tarde** / *Too slow* (`nota_llegaste_tarde`, text, handwritten, one entry picked at random when the chest opens). Every entry is written by someone alive who left minutes ago and is coming back on Thursday; the hat's owner appears only in the last one. No entry has a swear, so the soft bodies stay empty (already clean). Each entry gives its heading, then its body:
  1. `llegaste_tarde` (*Llegaste tarde* / *Too slow*): "Llegaste tarde, mi hermano. Aquí el que no madruga no coge ni la nota, y esta te la dejé por lástima. Vuelvo el jueves." / "Too slow, mi hermano. Around here, whoever doesn't get up early doesn't even get the note, and I left you this one out of pity. Back on Thursday."
  2. `decomisado` (*Acta de decomiso* / *Seizure notice*): "Contenido: DECOMISADO. Motivo: tesoro sin factura. Para reclamar, traiga el carné, tres fotos y el tesoro. Oficina cerrada; vuelvo el jueves." / "Contents: DECOMISADO. Reason: treasure without a receipt. To file a claim, bring your carné, three photos and the treasure. Office closed; back on Thursday."
  3. `la_cola` (*¿Quién es el último?* / *Who's last in the cola?*): "Para el tesoro hubo cola. Yo marqué, me fui a resolver una cosa y cuando volví ya no había ni cola. Ahora voy a marcar en otra. Vuelvo el jueves." / "There was a cola for the treasure. I marked my place, went off to resolver something, and when I got back there wasn't even a cola. Now I'm off to mark my place in another one. Back on Thursday."
  4. `ni_el_norte` (*Sobre la brújula* / *About the compass*): "Si llegaste con esa brújula, felicidades: te perdiste igualito que yo. Con ella dibujé el mapa. Por eso aquí no hay nada. Ni el Norte. Vuelvo el jueves, si la brújula me deja." / "If you got here with that compass, congratulations: you got lost just like I did. I drew the map with it. That's why there's nothing here. Not even el Norte. Back on Thursday, if the compass lets me."
  5. `el_sombrero` (*Sobre el sombrero* / *About the hat*): "Ese sombrero tiene dueño, y no eres tú. Dijo que volvía por él. Yo vuelvo el jueves, a ver quién llega primero. Mientras, póntelo, que este sol no perdona. Pero no le cojas cariño." / "That hat has an owner, and it isn't you. He said he's coming back for it. I'm back on Thursday; we'll see who gets here first. Meanwhile, put it on, this sun doesn't forgive. But don't get attached."

The map's hint phrases (`spot_hints_es` / `spot_hints_en` in `secret_tuning.tres`), by spot kind. A pick-up's kind is its glyph's `group`; any kind not listed takes `default`:

| Spot kind | `{pista}` (es) | `{pista}` (en) |
| --- | --- | --- |
| `palm` | una palma | a palm |
| `flotsam` | un reguero de cosas que trajo el mar | a reguero of junk the sea brought in |
| `hut` | un bohío sin techo | a bohío with no roof |
| `beach` | un pedazo de playa | a stretch of beach |
| `dune` | una loma de arena | a hill of sand |
| `tide_pool` | un charco entre las piedras | a pool among the rocks |
| `workbench` | un banco de trabajo | a workbench |
| `raft_site` | un buen sitio pa' armar una balsa | a good spot to put a raft together |
| `default` | algo que no se entiende | something nobody can make out |

The hat is a plain Cuban yarey hat with a red band. No name, emblem or line from any franchise appears with it, in any file, text, art or prompt.

## Counts

7 water, 16 food, 10 plants, 18 tools, 17 materials, 9 wearables, 15 oddities, 9 keepsakes, 16 texts = **117 item definitions** (the 16 added by `balsero-lore`: 11 items, 2 keepsakes, 3 texts; the 4 added by `secret-cay`: 1 wearable, 2 oddities, 1 text).
