# Design

## Decisions

1. **Cause recorded on the meters.** `SurvivalMeters.death_cause: StringName`, a plain replicated property like `dead`. `harm(amount, cause)` remembers the last loss's cause. `_on_health_empty()` copies it into a private "down cause". The host sets `death_cause` just before `dead = true`. A free revive returns before the copy. `revive()` clears both. `add()` and timed changes that lower health count as `other`. This follows DCSS: every damage call carries its kill method.
2. **Cause ids.** Fixed ids `thirst`, `drowning`, `removed` and `other` (constants in `DeathCause`), plus a creature's own `CreatureData.id`, so a new creature needs no script edit (CLAUDE.md "Adding a crab must never require editing a script"). Labels: Spanish UI strings in code for the fixed ids, `CreatureData.name_es` for creatures. No status has a cause: none takes health (see the proposal).
3. **Sync order.** `SurvivalMeters:death_cause` sits before `SurvivalMeters:dead` in the `StateSync` config, both ALWAYS and spawn. The synchronizer applies properties in config order, so a client's `died` already sees the cause. A test pins the order (by relative index, so later fields do not break it).
4. **Removed cause.** The session keeps `_removed_causes` beside `_removed`. `record_removed` and `receive_lobby` carry them, and a client cleans a received cause with `DeathCause.checked()`. A player whose meters died while they were away keeps that cause (D6).
5. **One-liners as content.** One DEATH_LINES `DialogueData`, one `DialogueStateData` per cause, `DialogueLineData` with es/en/soft variants. Line ids are `death_<cause>_<n>` (they will name the voice clips, as quick-chat lines do). The file's `name_es` reads "Frases de muerte (borrador)" until the owner's voice pass.
6. **The pick.** `(run_seed + n) mod count`, where n counts earlier summary rows with the same cause. No `hash()` (unstable across engine versions), no RNG state. It is deterministic on every peer and pinnable in tests.
7. **Run seed.** The host or solo rolls `randi()` in `GameShell._build_run` (through a replaceable `seed_source`) into `session.world_state["run_seed"]`. Joiners receive it through the existing `join_state()`. It is the seed island-generation will later reuse. This change only adds it.
8. **Totals.** `IslandTravel.islands_reached` starts at 1, rises in `_load` and goes to joiners through `_join_extras` (`"islands"`). Days = `WeatherManager.sky.clock.day` when the run ended.
9. **Layout.** The panel grows to 576x328 at (32, 16). Totals go in two lines, then the rows sit in a `ScrollContainer` (at least 200 px tall), then the buttons. Each row is a `SummaryRow` with three labels: `Fate`, `Line` (wraps at about 68 glyphs of Press Start 2P 8 px) and `Tip`. With four players and four tips, the rows scroll and never leave the 640x360 view.
10. **Restart.** Solo: `start_solo()` (it already tears down through `_end_run()` and rebuilds). Co-op: "Volver al inicio" only. Bringing the same peers back to a lobby needs a new host-to-client RPC, every client rebuilding its session and re-sending its join request, and node paths reused under live spawners. That is its own change (D3). The HUD is queue-freed when the summary shows, and `_end_run()` clears `get_tree().paused`. On a client, `_on_host_lost()` during the summary keeps the summary, shows a note and frees the run deferred.
11. **ui-shell.** Not modified (no main spec yet). Its "Screen flow" sentence "When every player still in the run is dead the run summary shows, then the title" is refined by "Restart from the summary". It should be reworded when ui-shell is archived (D7).

## Reference games

Ideas only; nothing copied.

| Game | Where | Borrowed | Rejected |
| --- | --- | --- | --- |
| DCSS | `crawl-ref/source/ouch.cc` `ouch(dam, death_type, source, aux, death_source_name)`; `kill-method-type.h` `kill_method_type` | Every damage call names its kill method and source, and the record is taken from the final blow: `SurvivalMeters.harm(amount, cause)`. A closed set of non-monster methods plus "killed by a monster" with its source: our fixed ids plus a creature's id. `KILLED_BY_QUITTING` and `KILLED_BY_LEAVING` are endings recorded as methods: our `removed` and the survivor's route. | The 40+ method enum (we have six causes). |
| DCSS | `crawl-ref/source/hiscores.cc` `scorefile_entry::death_description(death_desc_verbosity)` | Store the id, render the text at display time: `DeathCause.label` and `DeathLines`. | Verbosity levels (`DDV_TERSE` to `DDV_LOGVERBOSE`): one card, one level. The `switch` of hard-coded strings: our text is data. The morgue file and the scores file: no persistence (Experiencia is out). |
| Brogue CE | `src/brogue/RogueMain.c` `gameOver(killedBy, useCustomPhrasing)`; callers in `Combat.c` (`monsterName`) and `Time.c` ("Starved to death", "Killed by a fall", "Died from poison") | The killer passes the cause in. Non-monster deaths use their own phrasing, monsters use "killed by a <name>": our fixed labels and the creature's `name_es`. One guarded end-of-run entry (`MB_IS_DYING`, `rogue.highScoreSaved`): `_check_run_over` returns unless `flow == RUN`. The card shows depth: islands reached and days. | High scores (`saveHighScore`), run history (`saveRunHistory`), recordings, the feats list, "press i to view inventory". |
| Brogue CE | `src/brogue/MainMenu.c` (`NG_NEW_GAME`: `initializeRogue(seed)` with seed 0 from the clock, then `freeEverything()` in `RogueMain.c`) | Restart is one full teardown plus one full build with a fresh seed: `_end_run()` + `_build_run()` with a new `run_seed`. | Brogue's return to the title after every death: we offer "Otra vez" directly. |
| SPD | `actors/hero/Hero.java` `die(Object cause)`, `Hero.Doom.onDeath()`; `Dungeon.fail(cause)`; `Rankings.submit(win, cause)` | The cause is an object the killer supplies, with its own death text: lines keyed by cause. The Ankh check runs before death: the Medalla's free revive runs before any cause is recorded. | Deleting the save on death (`Dungeon.deleteGame`): no saves exist. |
| SPD | `Rankings.Record.desc()` (`Messages.get(cause, "rankings_desc")`, falling back to "something") | Fallback text when a cause has none: `other` lines and the "causa desconocida" label. | The rankings list (`scenes/RankingsScene.java`) and its stored records. |
| SPD | `windows/WndGame.java` (when the hero is dead: "start" a new game pre-selecting the same class, "rankings", "menu"); `windows/WndRanking.java` (stats, items and badges tabs) | Restart offered only after death and keeping the same mode: solo "Otra vez" restarts solo; "Volver al inicio" is always there. | Tabs: one card fits 640x360. |

## Solo

Every cause is reachable alone. The summary has one row. "Otra vez" exists only in solo. Tests use exactly 1 player for causes, summary and restart.

## Departures from the build plan

Filled in when the change is built (see the end of this file).
