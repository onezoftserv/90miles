# 90 Millas — Content Manifest

Every data resource to create, by folder. Each line is one `.tres` file. The resource scripts (`CreatureData`, `ItemData`, `NpcData`, `RecipeData`, `ChainData`, `SetPieceData`, `RouteData`, `TextData`, `KeepsakeData`, `BackgroundData`) are defined in the `project-skeleton` change. Creating content is data entry against the docs, so it can be done in batches by Claude Code with `/opsx:apply content-batch-<n>`.

Tick when the file exists and loads in Godot.

## game/resources/creatures/ (35 + 5 bosses) — `docs/BESTIARY.md`

- [ ] reef_shark · moray_eel · barracuda_school · man_o_war · land_crab · seagull · mosquito_cloud · crocodile · fire_ants · manchineel_tree
- [ ] bull_shark · stingray · urchin_field · lionfish · remora · jellyfish_bloom · needlefish · sea_snake · hammerhead · sperm_whale
- [ ] hutia · iguana · feral_dogs · sand_fleas · boa · rats · pelican · scorpion
- [ ] patrol_boat · shore_soldier · jet_ski · smugglers
- [ ] boss_cutter · boss_old_crocodile · boss_tiger_shark · boss_hurricane (weather) · boss_straits (crossing script)

## game/resources/items/ (97) — `docs/ITEMS.md`

- [ ] water (6): coco · rain_cup · still_cup · well_cup · seawater_cup · rum
- [ ] food (14): crab_raw · crab_cooked · fish_raw · fish_cooked · lobster · oysters · conch · bird_eggs · sea_grapes · coco_plum · mango · hutia_cooked · iguana_cooked · canned_food
- [ ] plants (10): manzanillo · guao · jaguey · uva_caleta_unripe · hicaco · guanabana · noni · sabila · hongo_playa · tabaco_silvestre
- [ ] tools (16): knife · machete · broken_bottle · spear · fishing_line · lure · net · snare · pliers · binoculars · compass · charts · mirror · lighter · flint_steel · shovel_oar
- [ ] materials (12): driftwood · hardwood · inner_tube · plastic_jug · rope · line_spool · tarp · nails · resin · dry_grass · cloth · tire
- [ ] wearables (8): straw_hat · life_vest · wetsuit_top · fins · sandals · gloves · sunglasses · military_belt
- [ ] oddities (12): flare · radio · car_battery · solar_charger · vhf · gps · expired_medicine · cigars · fire_pages · baseball · dominoes · bilge_pump
- [ ] keepsakes (7): foto_familia · cuchillo_abuelo · medalla_caridad · nudo_pescador · pedazo_mapa · cassette_van_van · pelota_firmada
- [ ] texts (12): libreta_ramon · diario_periodo_especial · cartas_yuma · la_lista · bottle_note · reply_bottle · wall_slogan · radio_fragment · menu_board · patrol_logbook · yunior_notebook · captain_log

## game/resources/recipes/ (18)

- [ ] raft · raft_hardwood · raft_repair · solar_still · rain_catcher · spear · sail · mast · oars · snare · sandals · gloves · fire · flint_steel · signal_fire · resin · bandage · shade_pit

## game/resources/npcs/ (24) — `docs/CHARACTERS.md`

- [ ] important (4): ramon · caridad · yunior · rodriguez
- [ ] companions (8): dayana · papo · el_chino · marisol · alfredo · yusnavy · tania · tomas
- [ ] minor (8): otros_balseros · senora_del_cayo · pescador_miami · loco_radio · cubanos_bahamas · ahogado · jineteras · turista
- [ ] animals (2): vieja_turtle · dolphin_pod
- [ ] profiles for AI NPCs → `backend/prompts/npcs/<id>.md` (12)

## game/resources/dialogue/ (handwritten, es + en)

- [ ] minor NPC lines (8 files) · story beats (intro, la_captura, each boss) · endings (5) · quick-chat (8 phrases) · death one-liners (20)

## game/resources/chains/ (9 chains × 2 variants = 18) — `docs/ISLANDS.md`

- [ ] sandbar_crescent · sandbar_twin · coast_bunker · coast_village · mangrove_maze · mangrove_river · reef_traps · reef_bluehole · rock_colony · rock_quarry · lighthouse_caridad · lighthouse_dark · storm_family · storm_resort · wreck_freighter · wreck_yachts · final_sandbar · final_buoy

## game/resources/pois/ (~45)

- [ ] one per POI row in `docs/ISLANDS.md` chain tables (ruined_hut, palm_grove, flotsam_line, tide_pools, … , captains_cabin, engine_room, galley, hull_camp, sons_raft, the_buoy)

## game/resources/set_pieces/ (15)

- [ ] floating_cooler · other_raft · patrol_dinghy · others_fire · turtle_nest · reply_bottle · la_cola · el_apagon · the_drone · the_bale · radio_contest · dominoes_night · the_funeral · patrol_stops · the_wedding

## game/resources/routes/ (8)

- [ ] raft · repair_wreck · turtle · binoculars_swim · tarp_sail · dolphins · signal_boat · gulf_stream

## game/resources/backgrounds/ (6)

- [ ] pescador · mecanico · medico · maestro · musico · ex_militar

## game/resources/weather/ (11)

- [ ] calm · trade_wind · squall · fog · hurricane · waterspout · red_tide · king_tide · heat_dome · sargassum · lightning

## Totals

40 creatures, 97 items, 18 recipes, 24 NPCs, 18 chains, ~45 POIs, 15 set pieces, 8 routes, 6 backgrounds, 11 weather = **~280 resource files**. At the reference games' scale for a 7-island run.
