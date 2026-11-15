# 90 Millas — Content Manifest

Every data resource to create, by folder. Each line is one `.tres` file. The resource scripts (`CreatureData`, `ItemData`, `NpcData`, `RecipeData`, `ChainData`, `SetPieceData`, `RouteData`, `TextData`, `KeepsakeData`, `BackgroundData`) are defined in the `project-skeleton` change. Creating content is data entry against the docs, so it can be done in batches by Claude Code with `/opsx:apply content-batch-<n>`.

Tick when the file exists and loads in Godot.

## game/resources/creatures/ (39 + 5 bosses) — `docs/BESTIARY.md`

- [ ] reef_shark · moray_eel · barracuda_school · man_o_war · land_crab · seagull · mosquito_cloud · crocodile · fire_ants · manchineel_tree
- [ ] bull_shark · stingray · urchin_field · lionfish · remora · jellyfish_bloom · needlefish · sea_snake · hammerhead · sperm_whale
- [ ] hutia · iguana · feral_dogs · sand_fleas · boa · rats · pelican · scorpion
- [ ] patrol_boat · shore_soldier · jet_ski · smugglers
- [ ] birds (4, content-batch-12): galleguito · pajarito · pajaro_bobo · rabihorcado
- [ ] boss_cutter · boss_old_crocodile · boss_tiger_shark · boss_hurricane (weather) · boss_straits (crossing script)

## game/resources/items/ (117) — `docs/ITEMS.md`

- [ ] water (7): coco · rain_cup · still_cup · well_cup · seawater_cup · rum · milordo
- [ ] food (16): crab_raw · crab_cooked · fish_raw · fish_cooked · lobster · oysters · conch · bird_eggs · sea_grapes · coco_plum · mango · hutia_cooked · iguana_cooked · canned_food · toronja · bistec_toronja
- [ ] plants (10): manzanillo · guao · jaguey · uva_caleta_unripe · hicaco · guanabana · noni · sabila · hongo_playa · tabaco_silvestre
- [ ] tools (18): knife · machete · broken_bottle · spear · fishing_line · lure · net · snare · pliers · binoculars · compass · charts · mirror · lighter · flint_steel · shovel_oar · tabla_surf · tabla_vela
- [ ] materials (17; `inner_tube`, `plastic_jug`, `rope` exist): driftwood · hardwood · inner_tube · plastic_jug · rope · line_spool · tarp · nails · resin · dry_grass · cloth · tire · tanque_55 · propela · bidon_combustible · azucar · camara_bici
- [ ] wearables (9; `sombrero_cinta_roja` exists): straw_hat · life_vest · wetsuit_top · fins · sandals · gloves · sunglasses · military_belt · sombrero_cinta_roja (secret)
- [ ] oddities (15; `brujula_rota`, `mapa_sin_norte` exist): flare · radio · car_battery · solar_charger · vhf · gps · expired_medicine · cigars · fire_pages · baseball · dominoes · bilge_pump · botija · brujula_rota (secret) · mapa_sin_norte (secret)
- [ ] keepsakes (9): foto_familia · cuchillo_abuelo · medalla_caridad · nudo_pescador · pedazo_mapa · cassette_van_van · pelota_firmada · llave_almendron · pluma_galleguito
- [ ] texts (16; `nota_llegaste_tarde` exists): libreta_ramon · diario_periodo_especial · cartas_yuma · la_lista · bottle_note · reply_bottle · wall_slogan · radio_fragment · menu_board · patrol_logbook · yunior_notebook · captain_log · nota_se_vende · fallo_del_pilote · sobre_tres_generaciones · nota_llegaste_tarde (secret)

## game/resources/recipes/ (22)

- [ ] raft · raft_hardwood · raft_repair · solar_still · rain_catcher · spear · sail · mast · oars · snare · sandals · gloves · fire · flint_steel · signal_fire · resin · bandage · shade_pit · almendron_flotante · vela_tabla · milordo · parche_bici

The grapefruit steak is `toronja.cooks_into`, not a recipe.

## game/resources/npcs/ (24) — `docs/CHARACTERS.md`

- [ ] important (4): ramon · caridad · yunior · rodriguez
- [ ] companions (8): dayana · papo · el_chino · marisol · alfredo · yusnavy · tania · tomas
- [ ] minor (8): otros_balseros · senora_del_cayo · pescador_miami · loco_radio · cubanos_bahamas · ahogado · jineteras · turista
- [ ] animals (2): vieja_turtle · dolphin_pod
- [ ] profiles for AI NPCs → `backend/prompts/npcs/<id>.md` (12)

## game/resources/dialogue/ (handwritten, es + en)

- [ ] minor NPC lines (8 files) · story beats (intro, la_captura, each boss) · endings (5) · quick-chat (8 phrases) · death one-liners (20; `death_one_liners.tres`, draft, `run-end`)
- [ ] balsero lore beats (2, content-batch-12): beat_galleguito · beat_pies_secos

## game/resources/chains/ (9 chains × 2 variants = 18) — `docs/ISLANDS.md`

- [ ] sandbar_crescent · sandbar_twin · coast_bunker · coast_village · mangrove_maze · mangrove_river · reef_traps · reef_bluehole · rock_colony · rock_quarry · lighthouse_caridad · lighthouse_dark · storm_family · storm_resort · wreck_freighter · wreck_yachts · final_sandbar · final_buoy

## game/resources/pois/ (~50)

- [ ] one per POI row in `docs/ISLANDS.md` chain tables (ruined_hut, palm_grove, flotsam_line, tide_pools, … , captains_cabin, engine_room, galley, hull_camp, sons_raft, the_buoy)
- [ ] balsero lore (5, content-batch-12): almendron_varado · caseta_alquiler · balsa_se_vende · balsa_marcada · balsa_vacia (the piling is a landmark inside its set piece, not a POI)

## game/resources/set_pieces/ (17)

- [ ] floating_cooler · other_raft · patrol_dinghy · others_fire · turtle_nest · reply_bottle · la_cola · el_apagon · the_drone · the_bale · radio_contest · dominoes_night · the_funeral · patrol_stops · the_wedding · balsa_en_la_sala · el_pilote

## game/resources/routes/ (10)

- [ ] raft · repair_wreck · turtle · binoculars_swim · tarp_sail · dolphins · signal_boat · gulf_stream · almendron · tabla

## game/resources/backgrounds/ (6)

- [ ] pescador · mecanico · medico · maestro · musico · ex_militar

## game/resources/weather/ (11)

- [ ] calm · trade_wind · squall · fog · hurricane · waterspout · red_tide · king_tide · heat_dome · sargassum · lightning

## game/resources/islands/ (3)

- [x] sandbar (handmade first island, change `sandbar-island`; `IslandLayoutData`: text rows plus glyph legend)
- [x] coast_cay (handmade second island, change `coast-cay`)
- [x] cayo_sin_norte (handmade secret cay, change `secret-cay`; marked `secret` and `off_graph`, so island generation never lists or numbers it; `docs/ISLANDS.md` "El cayo sin norte")

## Secret cay (change `secret-cay`)

5 new content files, built by the change itself rather than a content batch, because they need its new fields and enum values: items `brujula_rota`, `mapa_sin_norte`, `sombrero_cinta_roja`, `nota_llegaste_tarde` and island `cayo_sin_norte`. Its tuning file `game/resources/secret_tuning.tres` sits beside the other tuning files and is not content. Its dev hunt layout lives in `game/scenes/dev/`, outside the content folders, so no run or catalog offers it.

## Balsero lore batches (change `balsero-lore`)

The 35 new files of the lore research, in two batches under `TASKS.md` §10, each within the 30-file cap and each required to load in Godot.

- **content-batch-11 (balsero gear), 19 files:** routes 2 (`almendron`, `tabla`), recipes 4, items 11 (`tanque_55`, `propela`, `bidon_combustible`, `tabla_surf`, `tabla_vela`, `toronja`, `bistec_toronja`, `azucar`, `milordo`, `camara_bici`, `botija`), keepsakes 2. The routes and `llave_almendron` need `Vessel.CAR` and `Vessel.BOARD` from the later code change; the other 16 do not.
- **content-batch-12 (balsero world), 16 new files:** creatures 4, POIs 5, set pieces 2, texts 3 (`nota_se_vende`, `fallo_del_pilote`, `sobre_tres_generaciones`), dialogue 2. `galleguito` and `beat_galleguito` need `Behavior.PERCH_RIDE`; `pajarito` and `pajaro_bobo` need `ambient.gd`.

Batch 12 also edits existing entries (no new files; do these in the batch that creates each target, or in batch 12 if the target exists):

- `bottle_note` (+4 entries), `wall_slogan` (+4), `radio_fragment` (+3), `diario_periodo_especial` (+4 pages).
- `seagull`: codex line and the `pluma_galleguito` counter.
- `la_captura`: the `almendron_a_bordo` variant state that sets `almendron_hundido`.
- Ending dialogue (`ending_todos`, `ending_los_que_llegamos`, `ending_solo`, `ending_el_nino`, `ending_devuelto`): the galleguito, piling and almendrón lines, gated by flags.
- Chains: the `almendron` and `tabla` route rows on `coast_village`, `storm_resort`, `mangrove_maze` and `wreck_yachts`, the empty-raft and raft-for-sale `poi_chances`.
- POI loot: `fishermen_houses` (toronja, camara_bici, tanque_55, botija), `village_dock` (bidon_combustible), `resort_generator` (tanque_55, bidon_combustible, botija), the galley (azucar).

Not built: the patrol plane (`cutter_us`, `beat_captura_us`, the reworked `the_drone`) waits for the guardacostas-stealth work.

Ids are proposals. POI ids such as `fishermen_houses`, `village_dock`, `resort_generator`, `hull_camp`, `camp_ruin` and `keepers_house` follow the chain tables; confirm them in content-batch-8.

## Totals

44 creatures, 117 items, 22 recipes, 24 NPCs, 18 chains, ~50 POIs, 17 set pieces, 10 routes, 6 backgrounds, 11 weather, 2 handmade islands = **~321 resource files** (the handwritten dialogue files are listed separately). At the reference games' scale for a 7-island run. The creature and NPC counts still carry the mismatches in review item 47.
