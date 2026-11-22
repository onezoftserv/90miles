# Tasks

**Every group ends** with:
- the import run twice (`godot --headless --path game --import`);
- the smoke run (`godot --headless --path game -s res://tests/smoke.gd`);
- GUT (`godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`).

A path written `before/<name>` is in `docs/art-pass/review-2026-11-14/before/`, the review's before captures tracked with the proposal.

A group that touches `tools/art/` also runs `python -m unittest` in `tools/art` and `python -I tools/art/check.py game/assets/art`.

**Art rules:**
- art goes only through `tools/art/mood.py` with `png.py`, never Pillow;
- the packs stay read-only;
- master palette, whole alpha, and 1 px outlines on the plank;
- art never changes the simulation.

**Tests.** GUT tests run headless and assert node state, uniforms, rects and bytes, never rendered pixels. The windowed 1-player captures are separate tasks.

**Test paths** are as on main. If the test-folders change has moved `game/tests/unit/`, follow its layout.

## 0. Gate

- [x] 0.1 Wait until art-coast-pass (art wave 1) has merged into `main` and the coordinating session says go. Branch from `main`.
  - Re-read the merged `world_sea.gdshader`, `shore.gdshader`, `sea_mask.gd` and `SeaShaderChecks`.
  - Re-sync this change's MODIFIED "Scrolling sea" block with the archived art-pass spec. If art-coast-pass is not archived yet, sync with its delta.
- [ ] 0.2 Groups 1 to 4 need only art-coast-pass. Group 5 waits until crossing-gameplay has merged. Before group 5, re-read its `crossing_hazards.gd`, `crossing.tscn` and how it exposes the vessel's lateral position.
- [ ] 0.3 Before group 4, check whether hud-window-kit has landed.
  - If it has, re-read its `run_hud.tscn` rects and its `HudPanel` and `HudPanelThin` sizes.
  - If not, build on today's.
  - Then confirm D5's rect against the real nodes.

## 1. C33a: a readable night and dusk (data)

- [x] 1.1 In `test_day_night_tint.gd`, write the property tests and see them fail on today's `day_cycle.tres`:
  - the dusk tint times the deep and the shallows ramp bases, read from `ArtTuning.sea_ramps`, gives blue above green;
  - the night tint's `get_luminance()` is between 0.44 and 0.52.
  The existing `test_the_tint_node_takes_night_times_calm` is the 1-player case and must stay green.
- [x] 1.2 Set `day_cycle.tres` phase 2 to about (0.95, 0.78, 0.74) and phase 3 to about (0.42, 0.47, 0.72). Verify that the new tests, `test_world_sky.gd`, `test_weather_content.gd` and `test_searchlight.gd` pass.
- [x] 1.3 Windowed 1-player capture: the solo sandbar at dusk and at night with the patrol beam. Compare with the review's `before/sandbar_dusk_west_shore.png` and `docs/guardacostas-stealth/sandbar_night_beam.png`. Tune the two tints if needed and record the values in design.md Build notes.

## 2. C33b: firelight

- [ ] 2.1 In `test_structure_looks.gd`, write these first and see them fail:
  - a solo lit fire at night has a `FireLight` `PointLight2D` under its `Look` that is visible, in ADD mode, with `texture_scale` 1, its texture `2r + 1` px wide for r = company radius × 16 (80), and energy in (0, 1);
  - by day the light is hidden; when the fire is out it is hidden;
  - a palm, a workbench and a rain catcher have no light;
  - with a tuning whose company radius is 6, the texture is 193 px wide;
  - "Reducir destellos" on: the energy is equal on every flame frame; off: it follows `ArtTuning.fire_flicker`;
  - the flicker table's length equals the lit flame animation's frame count.
  Also, `FireGlow.texture` has exactly `steps` distinct non-zero values, and nothing beyond r.
- [ ] 2.2 Add `scripts/art/fire_glow.gd` (pure static, cached by radius), modelled on `PatrolCone`. Add the `ArtTuning` fields and their data in `art_tuning.tres`:
  - `fire_light_energy`, `fire_light_color` and `fire_light_steps`;
  - `fire_ring_values` and `fire_flicker`.
- [ ] 2.3 Make the light in `StructureLook` for `KIND_FIRE` only, as design D2. Verify the 2.1 tests, `test_art_sim_invariance.gd`, `test_patrol_cues.gd` and the fire's existing look test.
- [ ] 2.4 Optional: the unshaded flame overlay. First check in a 4.7.2 Compatibility windowed run that it escapes the `CanvasModulate`. Keep it only if it does, and record the finding in Build notes.
- [ ] 2.5 Windowed 1-player capture: the solo sandbar at night by a lit fire, at x3. Compare with the review's `before/sandbar_night_fire_x3.png` and artboard A11:
  - four hard rings out to 80 px;
  - the flame not olive;
  - sand and player lit inside the pool.
  Read the run log for shader and light errors and the frame time.

## 3. Art for the squall and the sea (recipe)

- [ ] 3.1 In `tools/art/test_mood.py`, write the recipe tests on fixtures and see them fail:
  - a source with an off-palette pixel or a partial alpha is refused;
  - a rain tile that is not seamless, or that covers more than 12% (light) or 25% (heavy), is refused;
  - a crest with #ffffff or #cbdbfc is refused;
  - a plank without a closed 1 px outline is refused;
  - a re-run gives the same bytes;
  - nothing is written when a source is refused;
  - no pack folder is read.
- [ ] 3.2 Write `tools/art/mood.py` and `mood_fx.json` (design D9). Draw the hand sources in `tools/art/fixes/mood/`:
  - `rain.png` (64 × 64, 2 frames);
  - `splash.png` (3 frames of 5 × 3);
  - `crests.png` (3 frames of 8 × 3);
  - `wake.png` (bow 2 frames, stern 3 frames);
  - `plank.png` (16 × 5).
  Build into `game/assets/art/fx/` and `game/assets/art/sea/`. Add the own-work blocks to both `License.txt` files. Verify `check.py`, `test_art_palette.gd`, `test_art_tracked` and a byte-for-byte re-run.

## 4. C34: a squall you can see

- [ ] 4.1 In a new `game/tests/unit/test_mood_fx.gd` and in `test_weather_content.gd`, write these first and see them fail:
  - `SeaPace` eases from pace 1 to the squall's `sea_pace` and `foam_pace` over `pace_ease_s`, and in no 1/60 s step does a clock advance more than the larger pace times the step;
  - back in calm it eases to 1;
  - the `SeaPaceDriver` writes `sea_time` to the sea material and `foam_time` to the Shore layer's material on a solo sandbar run;
  - its `process_mode` is ALWAYS, so with the tree paused a step still advances both clocks while the day clock does not;
  - `WeatherVfx` under the tint instances `squall.tres`'s `vfx_scene` on a solo squall start, at z 10 inside the tinted world, and frees it when calm returns;
  - splash placements for two equal (slot, view) inputs are equal, and use no random generator;
  - every weather that is not `is_clear` has `name_es` and `name_en` of 9 glyphs or fewer;
  - calm has `sea_pace` and `foam_pace` 1.
- [ ] 4.2 Add `sea_pace` and `foam_pace` (Presentation group, default 1.0) to `WeatherData`. Add `pace_ease_s`, `rain_light_s` and `rain_splashes` to `ArtTuning` and its data. Set the squall's paces (1.8 and 1.6 to start) and its `vfx_scene`.
- [ ] 4.3 Add `scripts/art/sea_pace.gd` and `scenes/art/sea_pace_driver.gd`. In `world_sea.gdshader`, replace `TIME` with `sea_time` in the two drift terms only; in `shore.gdshader`, use `foam_time` in place of `TIME`.
  - Add a driver under `TerrainView` and under `CrossingSea`.
  - Extend `SeaShaderChecks` to read the new uniforms.
  - Verify that at pace 1 the art-coast-pass sea tests, `test_shoreline.gd`, `test_terrain_view.gd`, `test_crossing_art.gd` and the 1500 ms build bound pass.
- [ ] 4.4 Add `scenes/world/weather_vfx.gd` as a child of `day_night_tint.tscn`, and `scenes/art/weather/rain_overlay.tscn`: the tile scrolled over the camera's rect, the two stages and the hashed splashes. Verify the 4.1 tests, `test_day_night_tint.gd` and `test_art_sim_invariance.gd`.
- [ ] 4.5 In `test_run_hud.gd`, write these first and see them fail:
  - on a solo run in a squall, `WeatherPanel` is visible and reads "Turbonada", or "Squall" with an English session;
  - in calm it is hidden;
  - its rect is inside y 4–18 and intersects none of PhasePanel, TeammatesPanel, Needle, NoteLabel, Meters, `SignNote.card_rect()`, the kit's teammate column (x ≥ 502) or the crossing HUD's band (y 68–90).
  Then add `WeatherPanel` to `run_hud.tscn` (design D5) and fill it in `run_hud.gd` from the session's climate and the weather data. Verify every `test_run_hud.gd` case.
- [ ] 4.6 Windowed 1-player capture: a solo sandbar squall by day and at night beside a fire. Compare with the review's `before/sandbar_squall_day.png` (against `before/sandbar_day_structures.png`), `before/sandbar_night_squall_fire.png` and artboard A12:
  - streaks at most 25%;
  - the foam visibly faster with no jump at the start;
  - the label beside the phase;
  - a crouched player and pick-ups still readable.
  Record the paces and the stage time in Build notes.

## 5. C35: life on the open sea (after crossing-gameplay)

- [ ] 5.1 In `test_crossing_art.gd`, write these first and see them fail:
  - on a solo raft crossing at integrity 100, `CrossingCrests` (z −38) shows crests whose texture pixels are only deep-ramp colours and #4a85a8, and `CrossingWake` (z −35) shows a bow and a stern wake inside the deck's x span;
  - a swimmers' route and a sunk deck show no wake;
  - a board route shows one small wake per intact board;
  - host and client draw the same crest list at the same plan time, scroll and position;
  - a coconut piece in lane 3 is drawn from the coconut's icon with at least 9 rows above its waterline and a ring, its bob at most 1 px, and the GRAB point at the piece's position;
  - the plank piece uses `sea/plank.png`.
- [ ] 5.2 Add `scenes/crossing/crossing_crests.gd` and `crossing_wake.gd` to `crossing.tscn` (design D6 and D7, the z table). Replace `CrossingHazards._draw_piece` (design D8), leaving rocks, debris and leaks as crossing-gameplay drew them.
  - Verify 5.1, `test_palette_swap.gd`, `test_art_palette.gd` (water.png keeps the deep ramp) and crossing-gameplay's flotsam and art tests.
- [ ] 5.3 Windowed 1-player capture: a solo raft crossing with flotsam passing. Compare with the review's `before/crossing_raft_aboard_x3.png`:
  - crests that never read as a fin;
  - the wake under the deck;
  - the coconut readable as loot.
  Also run a board fixture route once. Read the log.

## 6. Integration

- [ ] 6.1 Run everything:
  - rebuild with `mood.py` to scratch and `cmp` it against the tracked sheets;
  - `check.py` and `python -m unittest` in `tools/art`;
  - the import twice, smoke and GUT. All must be clean.
- [ ] 6.2 Co-op check, since the look reads synced state: run host and client locally through a night by the fire, a squall and a raft crossing. Confirm that both peers show the light, the rain, the label, the crests and the wake, with no `ERROR:` line.
- [ ] 6.3 Update `TASKS.md` and design.md Build notes, and run `openspec validate art-mood-pass --strict`.

## Workflow follow-up

- Open one PR per shipped group into `main`: groups 1 and 2; 3 and 4; then 5. Send the coordinating session each link with the before and after captures.
- Archive the change after art-coast-pass is archived and the owner has seen the captures (not in these PRs).
- Follow-ups, outside this change: art for crossing-gameplay's rocks, debris and leaks; lightning behind "Reducir destellos"; birds at sea.
