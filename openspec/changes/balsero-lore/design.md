# Design

## Decisions (the user, 2026-11-05)

| Question | Decision |
| --- | --- |
| Era of the run | The present day. 1994 only in found texts, wrecks and older characters' stories. |
| The almendrón | Rare (two chains, weight 0.6 and 0.8: about 1 run in 4 sees it) and drawn as a car (`Vessel.CAR`). |
| Drums | Floats only (`MATERIAL`); fuel is the separate jug (`FUEL`). Float-or-fuel drums stay a later upgrade. |
| The galleguito | Small effect (+10 morale once per player; may steal one held snack; never a survival lever), on every final crossing (chance 1.0), perched on a head (`Behavior.PERCH_RIDE`). |
| The board | Its own vessel type (`Vessel.BOARD`, integrity 60, riders dumped and self-climbing), lost on arrival, riders scattered 10–20 tiles. |
| Letter entry 2 | Keep the victim's own joke (eggs at the door); the 1994 tugboat sinking stays out of the game. |
| The Devuelto keepsake | *Pluma de galleguito*. |
| How specific the history is | Real places and years, never real people. |
| Existing doc problems | Left unchanged; recorded in the repo review. |
| The patrol plane (addition 9) | Not in this change; waits for the guardacostas-stealth work. |

## Where the repo differs from the proposal, and what was done

- **Capture at sea is settled.** The proposal deferred the car's capture rule because capture at sea was open (review 30). The archived `solo-play` change settled it (the previous island regenerates from the run seed), so the rule is written here as the escape-routes requirement "Almendrón capture" (a flag gate on chain rows and one `la_captura` variant) and guardacostas-stealth **Capture outcome** stays unmodified. A final-crossing capture is `devuelto` with no `la_captura`, so `almendron_hundido` is only ever set by an earlier capture; the sunk-car ending line reads it from there.
- **`AMBIENT` already exists** in `CreatureData.Behavior`, so only `PERCH_RIDE` is appended. `ambient.gd` is still missing, and the creatures-ai behavior list did not name `ambient`; the modified requirement now does.
- **No arrival effects field.** The proposal offered an optional `RouteData.on_arrival_effects` to make `almendron_a_bordo` mean "at sea in the car now". It is not adopted: the flag means "the car was used this run", which is what the ending lines and the capture gate need. The line "El almendrón subió la arena tosiendo..." (it depended on that field) is not written.
- **Real station names.** The proposal renamed Radio Martí and Radio Reloj in `docs/CHARACTERS.md`. The user chose to leave existing real names unchanged, so that row keeps its text and the new onda corta entries (generic stations only) sit beside it.
- **The drone.** `the_drone` is untouched (10%, far chains, Miami fisherman odds ×2): addition 9 is out of scope. The proposal's numbers for it (15%, island 5+) are not used.
- **Counts.** Without `cutter_us` and `beat_captura_us`: creatures +4, dialogue +2, files 35 (19 + 16), ≈ 315 in total. Items 97 → 113, recipes 18 → 22, POIs ≈ 45 → ≈ 50, set pieces 15 → 17, routes 8 → 10. Bestiary density 35 → 39.
- **Docs fixed in passing.** `docs/ITEMS.md` headed Tools as 14 while listing 16; it now says 18 with the two boards.

## New data-model values (documented only; `game/` is not edited here)

| Where | Value | Why |
| --- | --- | --- |
| `DataEnums.Vessel` (`game/scripts/data/data_enums.gd`) | Append `CAR` | The almendrón is a vessel with its own sprite, integrity 160 and squall damage ×1.5. Today: RAFT, BOAT, TURTLE, SWIMMERS, DOLPHIN_POD. |
| `DataEnums.Vessel` | Append `BOARD` | One small vessel per rider, integrity 60, dumps and self-climb, lost on arrival. Appended after `CAR`, so existing `.tres` enum integers do not shift. |
| `RouteData` (`route_data.gd`) | New `@export var arrival_scatter_tiles: Vector2i = Vector2i(0, 5)` | `ChainData.spawn_scatter_tiles` scatters a whole destination chain; a board route needs its own (10, 20). |
| `CreatureData.Behavior` (`creature_data.gd`) | Append `PERCH_RIDE`, script `game/scripts/ai/perch_ride.gd` | Head perch, theft pick (most food, run-seed tie-break), shoo and re-land. Appended after `TRADE_OR_ROB`. |

Fallbacks if the code lands late (not shipped, kept for reference): the car as `Vessel.BOAT`, the board as `Vessel.SWIMMERS` with `swim_drain_multiplier` 0.27 and a rider requirement of energy ≥ 80 (a 70 s crossing costs about 57 energy, so the rider lands near 23, above the 20 at which sharks target swimmers), and the galleguito as `AMBIENT` with no theft. The user chose Tier B, so none of these is the plan.

## Data sketches

```
routes/almendron.tres   starter BUILD_SITE almendron_flotante · capacity ALL · vessel CAR (kept on arrival)
  integrity 160 · duration (60, 90) · speed 1.4 · drift 0.5 · sharks 0.6 · threats 1.2 · squall damage ×1.5
  requirements: HAS_ITEM bidon_combustible 1 consume; WEATHER_IS squall negate
  on_start_effects: NOISE 25 tiles; SET_FLAG almendron_a_bordo; GIVE_ITEM botija 1 ACTOR · patrol_alert_chance 0.5
recipes/almendron_flotante.tres  VESSEL, build site, integrity 160 · {tanque_55 4, rope 4, nails 6, driftwood 4, propela 1}
  tool REPAIR · skill BUILDING ×2 · 90 s · terrain BEACH
routes/tabla.tres       starter ITEM_USE tabla_vela · capacity PER_SWIMMER · vessel BOARD, integrity 60, lost on arrival
  requirements: WEATHER_IS trade_wind · rider: HAS_ITEM tabla_vela consume; STATUS_ACTIVE BLEEDING negate
  duration (60, 70) · speed 1.8 · drift 1.5 · sharks 1.3 · threats 0.7 · dump_triggers [SQUALL, SHARK_ATTACK]
  riders_swim false · arrival_scatter_tiles (10, 20)
chains: coast_village almendron 0.6 · storm_resort almendron 0.8, tabla 1.0 · mangrove_maze tabla 0.4 · wreck_yachts tabla 0.5
  almendron rows: extra_requirements FLAG_SET almendron_hundido negate · starter POIs almendron_varado / caseta_alquiler
creatures/galleguito.tres  PERCH_RIDE · domains [AIR, VESSEL] · follows_vessel · max_per_run 1
  spawn: CROSSING, chain_families [FINAL], chance 1.0 · sighting: PLAY_DIALOGUE beat_galleguito ONCE_PER_RUN (flag-gated),
  SET_FLAG galleguito_a_bordo, METER_ADD MORALE +10 ACTOR ONCE_PER_RUN · steal HELD FOOD ×1, 0.5 per 60 s, stays
  counters: INTERACT → FLEE 5 s; ITEM_CARRIED pluma_galleguito → NEGATE (also on seagull)
items/pluma_galleguito.tres  KeepsakeData · unlock FINISH_RUN, endings [DEVUELTO], count 1 · LIFETIME
items/llave_almendron.tres   KeepsakeData · BUILD_SPEED ×1.2 HOLDER · unlock CROSSINGS_BY_ROUTE [almendron] count 1
set_pieces/balsa_en_la_sala  ISLAND, coast_village, requires fishermen_houses, island 2+, chance 0.6, once per run
  desarmar: 3 tubes, 2 rope, 2 driftwood · tumbar: 3 tubes, 2 rope, 4 driftwood, NOISE 20, ALERT_PATROL 0.4
  ventana: ANY_OF [Mecánico present, 2 players within 5 tiles]; same loot; MORALE +5 PARTY
set_pieces/el_pilote         ISLAND, final_sandbar, OFFSHORE 6 tiles, chance 0.5 · leer: OPEN_TEXT fallo_del_pilote;
  PLAY_DIALOGUE beat_pies_secos if Tomás or Ramón in party · not a refuge: the 360 s tide limit stands
foods: toronja (+5, thirst −2, cooks_into bistec_toronja 20 s) · bistec_toronja (+8, MORALE +5 ONCE_PER_DAY)
  milordo (WATER item with no WATER tag, thirst +20, MORALE +3 ONCE_PER_DAY, no REVIVE; recipe azucar + rain_cup, 5 s)
botija (ODDITY): PLAY 20 s at a lit fire within 5 tiles: +5 to players within 5 tiles ONCE_PER_DAY, +5 more with PLAYS_SONGS
camara_bici: parche_bici = 2 camara_bici + 1 resin → 1 inner_tube at a workbench, 30 s
```

Morale from a creature or a text is per player (the sighting effect targets the actor), so solo and a 4-player party get the same per-player base numbers.

## Sources by addition

The claims and their URLs live in `docs/LORE.md`; this table points to the section. A summary is never a quote, and no real person is named.

| Addition | Claim it rests on | Source |
| --- | --- | --- |
| Almendrón, drums, propeller, car | 2003 pickup and 2004 sedan (inspiration only, nothing retold) | LORE §5 |
| Board | 2014 and 2022 windsurfers (inspiration only) | LORE §5 |
| Galleguito | Cuban name, Florida breeding, handouts; one unverified 2024 anecdote | LORE §8 |
| Pluma | Being sent back after interception at sea | LORE §6 |
| Raft in the living room | Secondhand 1994 account (inspiration only) | LORE §5 |
| Se vende balsa | Cojímar, rafts sold in public | LORE §4 |
| Empty rafts, marked and unmarked | Coast Guard sinking or spray-painting rafts; 1994 beach wreckage | LORE §5 |
| El pilote | 2006 piling, 2016 lighthouse (inspiration only); the end of wet foot, dry foot in 2017 | LORE §6 |
| Bottle notes | The current, the 1994 and 2004 drifters, "90 miles", what rafters carried | LORE §1, §5 |
| El sobre, entry 1 (1965) | Camarioca and the Varadero flights | LORE §2 |
| El sobre, entry 2 (1980) | Mariel shrimp boats, actos de repudio, the scarcity of the era | LORE §2, §3 |
| El sobre, entry 3 (1994) | The base's tent camps; melted ration packets | LORE §4 |
| El sobre, entries 4–5 (2017) | The end of wet foot, dry foot; the visa lottery (el bombo) | LORE §6 |
| Wall slogans | Gusano, mariposa, the egg-throwing crowds | LORE §2 |
| Onda corta: official announcer | "Abandono" of a delegation by athletes (translation site; a direct *Trabajadores* or *Granma* link is still wanted) https://translatingcuba.com/1053-athletes-have-fled-cuba-in-a-decade-82-of-them-so-far-this-year | LORE §2 |
| Onda corta: the 1994 rumor | The August 1994 decision to stop preventing departures | LORE §4 |
| Onda corta: the fishing report | Gulf Stream speed | LORE §1 |
| Special Period kitchen, diary pages | Blackouts, bistec de toronja, milordo, the Chinese bicycle | LORE §3 |
| Bicycle tube | More than a million Chinese bicycles, no spare parts | LORE §3 |
| Botija | The earthenware jar of early son groups | LORE §8 |
| Songbird, booby, frigatebird | Songbirds landing on boats, boobies on buoys, frigatebird piracy | LORE §8 |

Entry 2 of the envelope is the most sensitive line: the joke belongs to the victim and aims at the scarcity behind the system that organized the act. The user decided to keep it, and the History and lore review (`TASKS.md` §11) has the final say. Death and the missing are never a joke: the empty rafts are plain, the board-rider line appears only if a rider died on that crossing, and the AI prompt bans the 1994 tugboat.

## Risks

- The galleguito's theft makes it a minor survival lever if it takes the last snack. It takes one held item at most twice per crossing, never from inventory, and a *Pluma* holder is immune; the +10 morale is per player.
- Provisional numbers: crossing durations and speeds wait for review item 29.
- Boards scatter riders 10–20 tiles, which the arrival code must keep inside the beach. A solo rider has nobody to find.
