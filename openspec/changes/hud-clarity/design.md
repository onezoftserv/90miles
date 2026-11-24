# Design

## Context

### What the review found
From the Fable review of 2026-11-22 (main 8c58c16), copied here because the review sits in another session's temp folder. The captures are in `docs/ui-shell/hud-clarity/before/`.

| ID | Sev | Finding | Review's fix | Evidence |
|---|---|---|---|---|
| H1 | high | Time is one word; no time to dark, no day count | Clock strip with marker and "Día 2" | `sandbar_day_spawn_hud_x3.png` |
| H2 (+G4) | high | No goal, direction or run progress on screen | Objective row, raft-site arrow, "Cayo 1/3" | `play_01_spawn.png` |
| H13 (+G9, G13) | med | Calor reads like an emptied meter; the blur has no word; two meters never move | Its own Calor row, an "Insolación" tag, threshold notches; hide or wire Energía and Ánimo | `hud_meters_phase_top_x3.png`, `play_04_crossing_hazard.png` |
| H14 | med | "Sangrando" is a bare word: no icon, timer or cure hint | Status row with icon and time bar; pulse the sábila slot | `hud_bleeding_tag_x3.png` |
| G4 | high | No opening, no goal, no tutorial | Shipwreck intro; hut note; start thirst at 70 | `play_01_spawn.png` |
| G9 | med | Calor 100 for 46 s at sea with no counter; the blur hides hazards | Tarp as shade, or cap heat at sea | `play_04_crossing_hazard.png` |

The owner chose these options on 2026-11-23:
- **5 (a):** objective row, hut note and controls card now; the shipwreck intro is its own change.
- **7 (a):** Calor gets its own thermometer row with an "Insolación" tag, and heat at sea is capped until the toldo ships.

This change does not cover:
- **The controls card:** it belongs to run-menu.
- **The heat cap:** it belongs to island-pressure.
- **"Cayo 1/3", Energía and Ánimo, and the sábila pulse:** they are listed as follow-ups.

### The 640×360 top band today
| Piece | Rect | Shows |
|---|---|---|
| Patrol horizon band | (0,0)–(640,6) | while a patrol is on the horizon |
| Meters window | inside (4,4)–(136,90) | always; "Sangrando" adds a row |
| PhasePanel (`HudPanel`) | (260,4)–(380,18) | always; 112 px inner, 14 glyphs |
| WeatherPanel (`HudPanelThin`) | (384,6)–(464,16) | squall only. Pinned by art-mood-pass D5 and four tests in `test_run_hud.gd` |
| Needle (secret-cay) | (308,20)–(332,44) | while carrying the broken compass |
| Sign note | (200,22)–(440,22+h) | while open; the longest coast cay line reaches y 60 |
| Note label | (140,46)–(500,66) | 6 s + 50 ms per character after the chest or the map |
| Crossing strip (#75, not merged) | (220,68)–(420,80), line (160,81)–(480,91) | riders on a crossing; pinned by `test_crossing_hud.gd` |
| Teammates | x 502–636, y 4–90 | co-op |

The empty space is x 140–256 at y 4–18, left of the phase tag. The sign note and note label already overlap on paper (y 46–60). They are both transient reading texts, and the kit accepts this.

### State the HUD can read on every peer
- **Clock:** `session.sky` (a `WorldSky`) holds `clock.time_of_day_s` and `clock.day`. The host runs it. Each client runs `WeatherManager.follow()` between `receive_sky` resyncs (every 10 s, `day_cycle.tres`). The day starts at 1 in `GameShell` (`sky.start_at`) and is never reset by `IslandTravel`; the run summary's "Días" reads the same clock. Tests that build a session by hand have no sky, so they fall back to `WeatherManager.sky`.
- **Raft site:** each island level places a synced `BuildSite` named `RaftSite` under the session (`SandbarIsland._place_raft_site`). The host pushes its deposits and progress to clients. When built it becomes `Raft`. A launched raft is replaced by a fresh site, and an intact raft that arrives is beached as `Raft`. Bench-placed sites also join the `build_sites` group, so we read by name and never by group.
- **At sea:** `session.has_left(peer)`, as `InventoryStrip.at_sea()` does.
- **Meters:** `heat`, `sunstroke` and `status_flags` are synced (`player.tscn` replication, ALWAYS). The bleeding time left is host-only (`_status_left_s`, bleeding-and-sabila D1). A client cannot work it out, because a new wound restarts it without changing the bit.

### Other sessions at work
| Session | Touches | Our stance |
|---|---|---|
| run-menu | pause menu, controls card, fonts | No pause-menu edits. If Q16's font switch lands first, glyph widths are re-checked by the budget tests. |
| island-pressure | raft build staging, heat at sea, thirst start | The objective reads `BuildSite` generically (`missing_items()`, deposits, progress), so staged holds still show progress. No tuning edits. |
| crossing-gameplay #70/#75 | `crossing_hud.gd`, `run_hud.gd` (`OUTSIDE_PANEL_GROUP`), `hud_text.tres`, `ci.yml` | No rect of theirs moves. Our overlap test copies their rects as constants. `run_hud.gd` changes stay a few lines in new places, and `hud_text.tres` gets new export blocks, not `lines` entries. |
| sound, guard-art, art waves | audio; coast guard and prop art | No shared files. |

## Goals / Non-Goals

**Goals**
- A first-time solo player knows the goal from the first frame, follows the row to a win, and always knows the day and how long until dark.
- Every new piece reads synced state only, so a client's view matches the host's. The only new network data is the bleeding time left.
- No HUD rect moves except the phase window (which grows left) and the needle.

**Non-Goals**
- No new simulation rule. Heat, bleeding, building and travel numbers are unchanged.
- No minimap and no general waypoint system. The arrow points at the raft only.
- No objective for anything secret (secret-cay "Secrecy").

## Decisions

### D1. Reference games (ideas only, nothing copied)
A background study read the three roguelikes in `reference/` and the DST wiki (Clock, Day-Night Cycle, Overheating, Thermal Measurer, Map, Health, Compass/DST, Sign/DST, Wetness/DST) plus `docs/REFERENCE_DST.md`. Names below were spot-checked in the sources.

**Objective row**
- **SPD** has none. It teaches the goal through guide pages dropped early (`EntranceRoom.placeEarlyGuidePages`, `Document.ADVENTURERS_GUIDE`), and the journal button flashes (`MenuPane.flashForPage`). **Rejected** as the main channel: a goal you must open a window to read fails in real time.
- **Brogue** states the run goal once in the log at start (`RogueMain.c` `welcome()`), with the item name coloured.
- **DCSS** announces a goal change once (`orb.cc` `start_orb_run`). It then keeps a permanent status light while the orb is carried (`status.cc` `STATUS_ORB`).
- **Borrowed:** DCSS's shape, one short persistent line that changes only when the state changes, and Brogue's coloured key noun. Our row colours the count.

**Clock strip**
- **SPD** has no clock. Depth sits in `MenuPane` (`depthText`).
- **Brogue** keeps the depth footer on a row its bars never draw over (`IO.c` `printProgressBar`, `refreshSideBar`).
- **DCSS** labels time in `output.cc` (`update_turn_count`). Its deadline light `status.cc` `_describe_zot` appears only near the deadline (`Options.always_show_zot` aside) and steps colour.
- **DST (Clock, Day-Night Cycle)** uses a dial of phase-coloured segments with a day counter.
- **Borrowed:** DST's phase-coloured day with a marker and a day count, drawn as a thin horizontal strip. A round dial needs about 24×24 px to read, and we have 14 px of height. From DCSS, the countdown changes colour near the deadline (orange from dusk).
- **Rejected:** DCSS's show-only-near-the-deadline rule, which needs owner question Q2. The review asks for time to dark at a glance, and a column that comes and goes would shift the row.

**Edge arrow**
- **SPD** `ui/Compass.java` is a needle in the status pane. It points at the exit, is shown only once that cell is `visited` or `mapped`, and is retargeted to the entrance after the amulet (`StatusPane` constructor, `Statistics.amuletObtained`).
- **Brogue** auto-travels to known stairs instead (`Movement.c` `proposeOrConfirmLocation`).
- **DST** shows signs and other carriers on its map (Compass/DST, Sign/DST).
- **Borrowed:** SPD's retargeting. The arrow follows `RaftSite` or `Raft`, whichever exists.
- **Rejected:** the fixed corner needle, because eyes stay on your own body in co-op, so an arrow on the view's edge reads faster. Also rejected is SPD's seen-first gating (owner question Q3): the raft site is the run's one goal, and the hut note and the row already name it.

**Hut note**
- **SPD** has a modal `WndStory` for documents. **Rejected:** nothing pauses here.
- **DCSS** has tutorial markers (`dat/dlua/tutorial.lua`).
- **DST (Sign/DST)**: examining a sign has the character say its text.
- **Borrowed:** a place-bound text read on demand, reusing our non-blocking sign note (inventory-hud "Sign note").

**Calor row**
- **Brogue** puts a stage name in the nutrition label (`IO.c` `printMonsterInfo`).
- **DCSS** colours by band and hides at zero (`output.cc` `_print_stats_contam`).
- **DST** warns of overheating at the screen edge only (Overheating), and shows the Wetness gauge only while wet (Wetness/DST).
- **Borrowed:**
  - DCSS's bands, as the tinted zones of the thermometer track;
  - Brogue's named stage, as the "Insolación" row;
  - DST's conditional row: the Insolación and Sangrando rows show only while they apply.
- **Rejected:** DST's edge-only cue. The screen already blurs, and the missing word is the bug. Also rejected is hiding Calor below a notch (review decision 7 (b), not chosen).

**Sangrando row**
- **Brogue** draws each timed status as a labelled bar that drains from its starting value (`printMonsterInfo`).
- **SPD** fades a grey overlay over the buff icon (`BuffIndicator.iconFadePercent`, `Buff.iconFadePercent`) or shows turns left (`iconTextDisplay`).
- **DCSS** dims an expiring light (`status.cc` `_dur_colour`, `_mark_expiring`) and fuzzes the time.
- **Borrowed:** Brogue's icon-plus-draining-bar. **Rejected:** DCSS's fuzzed time: in real time the bar must be honest, so the host's time is synced (D7).

**Anti-clutter, from all four:** rows exist only while they apply (`Hunger.icon()`, Brogue status bars, DCSS contamination, DST Wetness); warnings go on existing pieces; the key line is protected (Brogue's depth row).

### D2. The top band: rects and what can show together
| Piece | Rect | Notes |
|---|---|---|
| Clock row (`PhasePanel`, `HudPanel`) | (152,4)–(380,18) | grows left into the empty x 140–256; keeps the node names `PhasePanel` and `%Phase` |
| Objective row (`HudPanelThin`) | (152,20)–(380,30) at most | sized to its text and centred under the clock |
| Weather | (384,6)–(464,16) | unchanged |
| Needle | (384,20)–(408,44) | moved from (308,20); under the weather's place |
| Sign note | (200,22)–… | unchanged; the objective row hides while it is open |
| Note label | (140,46)–(500,66) | unchanged; the needle still ends above it (44 < 46) |
| Crossing strip and line | #75's rects | unchanged; the objective row (y ≤ 30) is clear |

Which pieces can show at once:

| | Clock | Objective | Weather | Needle | Sign note | Note label | Crossing |
|---|---|---|---|---|---|---|---|
| Objective | yes | – | yes | yes | **never** (hides) | yes | yes |
| Needle | yes | yes | yes | – | yes (paper overlap today, unchanged) | yes | yes |
| Sign note | yes | never | yes | yes | – | yes (paper overlap today) | never (no signs at sea) |

One test forces every piece that can co-exist visible: a squall, the compass, the longest objective line in both languages, the note label, and the crossing rects as constants. It then asserts no pairwise overlap (ui-shell "The top band holds together").

**Alternatives rejected**
- **A two-row clock (y 4–28):** it pushes the sign note, needle, note label and crossing strip down a cascade.
- **Moving the weather window:** art-mood-pass pins it.
- **Hiding the objective row while the needle shows:** the needle can be carried for the rest of a run.

### D3. The clock row's columns (inner 220 px, 8 px glyphs)
| Column | Width | Contents |
|---|---|---|
| Day | 48 | "Día 2", left-aligned; fits up to "Día 99" |
| Strip | 56 | a 56×7 bar box: 1 px outline round 54×5 |
| Time | 32 | a 5×5 moon or sun mark, 2 px gap, then up to 3 glyphs ("14h", "40m") |
| Phase | 72 | right-aligned; "Atardecer" is the longest at 9 glyphs |

Gaps of 4 px separate the columns: 48+4+56+4+32+4+72 = 220.

**The strip (`DayStrip`, pure)**
- The span of time `[0, 720)` maps onto 54 px.
- The parts are dawn 0–60, day 60–360, dusk 360–420 and night 420–720. The midday stretch, 120–300, sits inside the day part.
- The colours come from `HudStyle` and the master palette:
  - dawn: rose;
  - day: sand;
  - midday: sun-orange;
  - dusk: orange-red;
  - night: deep sea dark.
- The marker is a 2×7 sun-yellow column, standing 1 px past the bar at top and bottom, at `floor(t/720 × 54)`.

**Time left**
- **Day:** `left = 420 − t` before night.
- **Night:** `left = 720 − t` until dawn.
- **Format:** hours = `ceil(left/30)` while `left ≥ 30`, else minutes = `ceil(left × 2)`. For example, 18:30 is `t = 375` → 45 s → 2h; 05:40 is `t = 710` → 10 s → 20m.
- **Colour:** cream, or orange while `360 ≤ t < 420`.

**Phase words** come from `clock_words` in `hud_text.tres`, keyed `dawn`, `morning`, `midday`, `afternoon`, `dusk` and `night`. `RunHud.phase_name()` keeps its signature and returns these. Its tests in six files are updated for "Mañana" and "Tarde".

### D4. The objective (`Objective`, pure; `ObjectiveRow`, drawing)
`Objective.from(session, local_peer, island_layout, text, locale) -> Goal` returns a step and a line. The steps are `AT_SEA`, `WAIT_DARK`, `LAUNCH`, `GATHER(item, have, need)`, `DELIVER`, `WORK(percent)` and `NONE`, decided in the order the spec lists them.

- **Inputs:**
  - `session.get_node_or_null("RaftSite") as BuildSite`;
  - `session.get_node_or_null("Raft") as Raft`;
  - `session.has_left(peer)`;
  - the local body's `inventory.count_id(id)`;
  - the island layout, from `session.get_node_or_null("Travel")`, `island.layout`, or set by tests.
- **Gather:**
  - `have = mini(site.deposited.get(id,0) + inv.count_id(id), need)`, over `recipe.inputs` in its declared order;
  - `recipe.input_tags` follow, with `HudText.tag_names` as the noun;
  - the noun is `ItemData.count_name(locale)`, the short name or else the name.
- **Wait for the dark:** with the raft built, `Objective.launch_waits(session, climate)` is true while a patrol `Creature` (`is_patrol()`, not queued for deletion) is among `session.entities`, the phase is not in its `data.patrol.searchlight_phases`, and the current `WeatherData` (`session.sky.weather.current`, which clients follow) neither keeps patrols in port (`patrols_in_port`, a squall) nor disables `SIGHT`. That mirrors island-pressure's `LaunchSight.seen_by` day rule (a boat with its light off sees the whole sea; a squall keeps patrols in port) without depending on it. Once island-pressure lands, whichever change merges second makes `launch_waits` call `LaunchSight` so the two can never disagree. At night the objective says go; the launch prompt's own warning covers a searchlight on the player.
- **Work:** percent = the site's progress × 100, floored. Today that is `BuildSite`'s work over `recipe.time_s`, read through a new `progress_ratio()` accessor if none exists.
- **Lines** live in a new `objective_lines: Dictionary[StringName, PackedStringArray]` export on `HudText`, with `gather`, `deliver`, `work`, `wait_dark`, `launch_default` and `at_sea`. A test checks that every line, filled with its longest content (each vessel build-site recipe's inputs at their real need, 100%), fits in 27 glyphs in both languages. Two-digit counts would not fit with an 8-letter noun; no raft input needs ten.
- **Updates:** `RunHud._process` already calls `refresh()` every frame. The row recomputes and redraws only when its line changes.

### D5. The raft-site arrow (`SiteArrow`)
- **Target:** `RaftSite` or `Raft` under the session, mapped through `RunHud.world_to_hud`.
- **When it draws:** only when the target's HUD point lies outside the view rect (0,0)–(640,360) less a 4 px margin.
- **Placement:** the arrow sits where the ray from the view centre (320,180) to the target crosses the frame (8,96)–(632,300). It is clamped into the frame, so its 9×9 rect stays inside.
- **Art:** eight directions from two kit icons, `arrow_straight` and `arrow_diagonal` (9×9, sun yellow with a 1 px dark outline), each turned by quarter turns. Pixel art is never rotated to an arbitrary angle.
- **Hiding:** follows "When the raft-site arrow hides". It is not a panel, so it is not in `panel_rects()`.

### D6. Meters window: Calor last, two status rows
- **Rows:** Salud, Sed, Hambre, Energía, Ánimo, Calor, then the status rows. Calor's `MeterBar` instance moves last in `meters_hud.tscn`. `bars()` order tests are updated.
- **Thermometer:** `MeterBar` gains an export, `zones: PackedColorArray`, empty by default. When it is set (Calor), the empty track is drawn in three dark zone tints (below 50, 50–75, 75 and up) instead of `empty_color`. The 1 px notches at 50 and 75 (`WARN_HEAT`, `CRITICAL_HEAT`) stand 1 px above and below the box, in orange and alert red. The old 1 px tick at 75 inside the bar is replaced by these notches.
- **Status rows:** `StatusRow` (`HBoxContainer`) holds a 7×7 icon (kit pieces `status_sunstroke` and `status_bleeding`), a 2 px gap, the word in the alert red (`AlertLabel`), and a 32×7 time bar box right-aligned to the meters' value column. The rows are `Insolación` and `Sangrando`. Each shows only while it applies; Insolación sits first.
- **Bars:**
  - Insolación: `(heat − ends_below) / (sunstroke_at − ends_below)`, from `survival_tuning.tres`.
  - Sangrando: `bleeding_left_s / bleeding_s`.
- **Height:** the window must stay inside y 90 with both status rows. If the 10 px rows overflow, the status rows drop to 9 px, which is still an 8 px glyph plus 1. A test with both on checks the rect.
- **Compatibility:** `MetersHud.bleeding_tag()` keeps its name and returns the row's word label, so the bleeding tests keep working.

### D7. The bleeding time, synced
- `SurvivalMeters` gains `var bleeding_left_s: float = 0.0`, a plain property. The host writes it in `tick()` from `_status_left_s` and zeroes it when the status ends.
- `player.tscn` gets one more replication entry, `SurvivalMeters:bleeding_left_s`, spawn on, mode ALWAYS, like the rest.
- `test_player_state_sync`'s list gains the path.
- Solo: the same property, nothing sent.
- Alternative rejected: a local client timer started on the bit. It is wrong after a re-wound, and for a spectator who started watching mid-bleed.

### D8. Content fields
- `ItemData` gains `short_name_es` and `short_name_en` and a `count_name(locale)` helper. They are filled for driftwood, the inner tube and rope.
- `IslandLayoutData` gains `launch_line_es` and `launch_line_en`, in the "Drinking and signs" group's neighbour group "HUD". They are filled for the sandbar.
- `ContentValidator` checks the lengths (8 and 27) and that a short name is lower case. The short-name limit is what keeps "Arma la balsa: 9/9 " plus the noun inside 27 glyphs.

### D9. The hut note
- Glyph `n`, terrain sand (`terrain_glyphs["n"] = 3`), one cell on the sand row just south of the hut's `HHHq` row, facing the spawn. It is a one-character edit in `rows`, plus a new `IslandSignData` in `signs`.
- **Draft text,** for the owner's voice pass (Q4):
  - ES: "Pa'l que venga detrás: la Florida 'tá a noventa millas, pa'l norte. Arma una balsa con palos, cámaras y soga, y zarpa de noche o con la turbonada: de día la lancha te ve."
  - EN: "For whoever comes next: Florida's ninety miles north. Build a raft from wood, tubes and rope, and set off at night or in a squall: by day the patrol boat sees you."
  - The first draft said "zarpa con luz" (leave by daylight). The owner's island-pressure Q1 (a), 2026-11-23, makes every daytime launch seen by the patrol, so the clause now gives the same advice as island-pressure's launch warning ("De día te ve la lancha. Espera la noche o la turbonada."). It stays flagged for the voice pass.
- It names no count, so island-pressure's recipe changes can't make it wrong.
- It is a sign, not the "first bottle note" found text that `docs/ISLANDS.md` puts in the hut. That stays balsero-lore's, for when found texts exist.

### D10. Art
New kit icons go through `tools/art/ui.py` and `ui_kit.json` as `icon` pieces (ASCII layers in palette colours):
- `status_bleeding`, `status_sunstroke` (7×7);
- `clock_moon`, `clock_sun` (5×5);
- `arrow_straight`, `arrow_diagonal` (9×9).

The palette test already covers `assets/art/ui/`. The strip and the bars are drawn in code with `HudStyle` colours. There are no new fonts.

### D11. Files
| Kind | Files |
|---|---|
| New | `scripts/ui/objective.gd`, `scripts/ui/day_strip.gd`; `scenes/ui/clock_strip.gd`, `objective_row.gd`, `site_arrow.gd`, `status_row.gd` (each with a `.tscn` where it has nodes) |
| Edited | `run_hud.gd` and `.tscn`, `meters_hud.gd` and `.tscn`, `meter_bar.gd`, `compass_needle.tscn`, `survival_meters.gd`, `player.tscn`, `hud_text.gd` and `.tres`, `item_data.gd`, three item `.tres`, `island_layout_data.gd`, `sandbar.tres`, `content_validator.gd`, `tools/art/ui_kit.json` |

## Risks / Trade-offs
- **[Phase window grows left (152 to 260):** the clock is no longer centred on x 320.] → The top band reads left to right, meters then clock, and the objective row centres under the clock. Captures show it. The owner can reject this at review.
- **[Glyph budget, 27 per objective line]** → Every line is tested filled to its maximum in both languages. If Q16's font switch changes glyph widths, the test catches it.
- **[Raft site changes in island-pressure (staged holds)]** → The objective reads deposits, `missing_items()` and a progress accessor only. Any new stage still shows "Dale a la balsa: P%".
- **[Synchronizer change]** → One property, mode ALWAYS like its siblings. The UDP 7800 run checks a client's bleeding bar.
- **[Clock drift on clients between resyncs]** → It is bounded by the 10 s resync, and the spec says "to within one resync".
- **[Merge friction in `run_hud.gd` and `hud_text.tres` with #75]** → Few lines, new export blocks, and no edits to `panel_rects()`.

## Migration Plan
- No saved data changes.
- **Archive order:** hud-window-kit, damage-feedback, bleeding-and-sabila, art-mood-pass, then this change. Its MODIFIED blocks are written on hud-window-kit's "HUD layout" and "HUD bars" and on the main specs' "Inventory band and world marks", "Bleeding tag on the HUD" and "Needle on the carrier's HUD".
- **Rollback:** revert the PR. Nothing persists.

## Owner decisions (answered 2026-11-23: all four (a))
- **Q1 (a).** DAY reads "Mañana", "Mediodía" or "Tarde", so the row never reads "Día 2 … Día".
- **Q2 (a).** Time to dark is always shown, in in-game hours beside a moon mark, orange from dusk, counting to dawn at night.
- **Q3 (a).** The raft-site arrow shows whenever the site is off screen.
- **Q4 (a).** The hut note ships as D9's draft, flagged for the later voice pass.
- **Consistency with island-pressure Q1 (a).** Every daytime launch from a patrolled island is seen, so players leave at night or in a squall. The hut note's "zarpa con luz" became "zarpa de noche o con la turbonada: de día la lancha te ve", and the objective gained the wait step "Espera la noche pa' zarpar" ("Objective waits for the dark").

## Open Questions
- Whether a 9 px status row reads as well as a 10 px one at 1×. This is settled by the capture in task 6. It does not change the specs (the rect rule holds either way).
