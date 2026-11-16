# Proposal

## Why

The 2026-11-14 art and HUD review (`docs/art-pass/review-2026-11-14/DESIGN_PASS.md`, section 2.6, findings ST1 to ST3; section 3, wave 5, changes C33 to C35) found three places where the world's mood is flat:

- **Night (ST1).** Night is one flat multiply. The lit fire turns olive and casts no light: its white core is the same value as the night foam. The value steps of the sand and the sea flatten, and dusk turns the water a muddy teal. No `Light2D` lights the island; the only one in `game/` is the patrol's searchlight (`PatrolLook`).
- **Squalls (ST2).** A squall is only a 30% darker tint. No rain falls, the sea and the foam move as in calm, and the HUD does not say a squall is running. At night it reads as a darker night. `squall.tres` already has `rain = true` and an unused `vfx_scene` slot.
- **The open sea (ST3).** The crossing is about 95% one moving water texture, with no crests and no wake. The crossing-gameplay change adds grabbable flotsam, rocks, debris and leaks, drawn as kitbashed placeholders in `CrossingHazards`. Its design says their real art belongs with the art review.

The owner accepted every recommendation of the review on 2026-11-14 and approved queuing this wave on 2026-11-15:
- **Q13 (a):** the fire casts a warm light pool exactly as far as its company bonus reaches, and night gets slightly brighter.
- **Q14 (a):** rain, a faster sea and foam, and a weather label. Lightning is not part of it.

## What Changes

The changes go in this order, smallest first. They are art only: no simulation value, synced property, walkable cell or crossing rule changes.

- **C33a, a readable night and dusk (ST1, data).**
  - `day_cycle.tres`'s night tint is lifted from (0.35, 0.40, 0.65) to about (0.42, 0.47, 0.72).
  - Its dusk tint is softened from (0.90, 0.70, 0.60) to about (0.95, 0.78, 0.74), so tinted water stays blue instead of teal.
  - Both are provisional tint data (weather-daynight "Calm and squall data", `docs/GAME_DESIGN.md` §5), and no number in a design doc changes.
- **C33b, firelight (ST1).**
  - A lit fire's `Look` gains a `PointLight2D` in additive mode.
  - Its texture is made at run time, 1:1 with the screen. It has four hard rings whose outer edge is the company radius: `company_radius_tiles` × 16 = 80 px today, read from `survival_tuning.tres`.
  - Its energy, below 1, follows the darkness of the sky's tint: 0 by day, full at night.
  - It flickers with the flame's frame from a data table, never from a random roll. Under "Reducir destellos" it holds steady.
  - It is off once the fire is out.
- **C34, a squall you can see (ST2).**
  - **Rain.** A rain layer, the squall's `vfx_scene`, sits in the tinted world under the name tags. It shows 1 px diagonal streaks in #cbdbfc and #9badb7 covering at most 25% of the view, so the sky tint and the fire's light fall on it. It builds in two stages, light then heavy. A few 3-frame splash ticks show where drops land.
  - **A faster sea and foam.** The sea's drift and the foam's frame rate run on clocks accumulated on the CPU, so a weather's pace (new `WeatherData` fields `sea_pace` and `foam_pace`) speeds them up with no jump. They keep moving under solo pause, as today.
  - **A weather label.** While the weather is not clear, the HUD shows its name in the session's language ("Turbonada") in its own small `HudPanel` window, right of the day phase.
- **C35, life on the open sea (ST3).** Built after crossing-gameplay merges.
  - **Crests.** `CrossingCrests` at z −38 shows small dashes that come and go on the scrolling sea. They use only the deep ramp and #4a85a8, never white, so nothing reads as a fin.
  - **Wake.** `CrossingWake` at z −35 shows a bow ripple and a stern wake for the raft and the car, and a small one per intact board.
  - **Flotsam.** Crossing-gameplay's flotsam pieces get their real look: the item's own icon riding a waterline with a 1 px bob and a dashed ring, and a hand-drawn plank. Each piece stays readable as loot.
- **New art** (rain, splash, crests, wake and the plank) is hand-drawn own work in `tools/art/fixes/mood/`. A new recipe, `tools/art/mood.py`, built on `png.py` with no Pillow, checks it and writes it to `game/assets/art/fx/` and `game/assets/art/sea/`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`:
  - **New:** "Firelight at night", "Squall on screen" and "Life on the open sea".
  - **Changed:** "Scrolling sea" lets a weather's data raise the drift, easing in. This change archives after art-coast-pass, whose text it carries.
- `weather-daynight`: new "Weather label" and "A readable night and dusk".

## Impact

- **Art tools (`tools/art/`):** the new `mood.py`, `mood_fx.json`, `test_mood.py` and `fixes/mood/` hand sources.
- **New tracked art:**
  - `game/assets/art/fx/rain.png` and `splash.png`;
  - `game/assets/art/sea/crests.png`, `wake.png` and `plank.png`;
  - their `License.txt` own-work blocks.
- **Data:**
  - `game/resources/day_cycle.tres`: the night and dusk tints;
  - `game/resources/weather/squall.tres`: `vfx_scene`, `sea_pace`, `foam_pace`;
  - `game/scripts/data/weather_data.gd`: two fields;
  - `game/scripts/art/art_tuning.gd` and `art_tuning.tres`: the fire light and pace-ease fields.
- **Game scripts and scenes:**
  - `scenes/art/structure_look.gd` and a new `scripts/art/fire_glow.gd`, which makes the ring texture the way `PatrolCone` makes the searchlight's;
  - new `scripts/art/sea_pace.gd` and `scenes/art/sea_pace_driver.gd`;
  - `world_sea.gdshader`, `shore.gdshader`, `terrain_view.gd` and `crossing_sea.gd`;
  - new `scenes/world/weather_vfx.gd` (a child of `day_night_tint.tscn`) and `scenes/art/weather/rain_overlay.tscn`;
  - `scenes/ui/run_hud.tscn` and `run_hud.gd` (the `WeatherPanel`);
  - new `scenes/crossing/crossing_crests.gd` and `crossing_wake.gd` in `crossing.tscn`;
  - `crossing_hazards.gd`'s piece drawing.
- **Tests:**
  - new cases in `test_structure_looks.gd`, `test_day_night_tint.gd`, `test_weather_content.gd`, `test_run_hud.gd`, `test_crossing_art.gd` and `test_terrain_view.gd`, and a new `test_mood_fx.gd`;
  - `test_art_sim_invariance`, `test_art_palette`, `test_palette_swap`, `test_searchlight` and `test_patrol_cues` stay green.
- **Not touched:**
  - any synced property, `Fire`'s simulation, the company radius, the weather roll, the crossing plan and its HUD;
  - crossing-gameplay's rock, debris and leak placeholders (a follow-up);
  - lightning, birds at sea and decorative flotsam (non-goals).
