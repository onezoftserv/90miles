# Design

## Context

See proposal.md for why. The review behind this change is `docs/art-pass/review-2026-11-14/DESIGN_PASS.md` (it lands with art-coast-pass): section 2.6 (ST1 to ST3), section 3 wave 5 (C33 to C35), artboards A11 and A12, and section 6 Q13 and Q14.

How it works today:
- **Tint.** `DayNightTint` (`scenes/world/day_night_tint.gd`) is the world's `CanvasModulate`. Each frame it takes `WorldSky.tint()`: the phase colour from `day_cycle.tres`, blended over `blend_s`, times the weather's `canvas_tint`. HUD CanvasLayers are not tinted. The shell adds the tint to `$WorldView/Viewport/World`, where the island and the session (and so the crossing) live.
- **Searchlight.** The only light in `game/` is the patrol's searchlight: `PatrolLook._make_light` builds a `PointLight2D` whose cone texture is made at run time by `PatrolCone.texture`. Under the night tint it brightens the sand it covers.
- **Fire look.** The fire's `Look` is a `StructureLook`. It plays `StructureArt.fire_frame(lit)` from `structure_art.tres`.
- **Sea and foam.** The sea (`world_sea.gdshader`, as rebuilt by art-coast-pass on `claude/art-wave-1-d6d1b2`) drifts by `drift * TIME` and `second_drift * TIME`, with a static warp and a 0.05 sway. The foam (`shore.gdshader`) steps frames by `floor(TIME * frames_per_second)` at 6 fps. Both run on the shader clock, which a paused tree does not stop, so the sea moves under solo pause (archived art-pass D12, K47).
- **Squall data.** `squall.tres` has `canvas_tint = (0.7, 0.72, 0.8)`, `rain = true`, `name_es = "Turbonada"` and an empty `vfx_scene` ("Rain or fog overlay (asset)").
- **Crossing.** The sea is at z −40 and the deck and boards at −20 (`crossing.tscn`). Crossing-gameplay (branch `claude/crossing-gameplay-53b440`, not yet merged) adds `CrossingHazards` at z −30. It draws rocks, debris, leak spurts and flotsam pieces as placeholders; a piece is today the item's whole icon on a half-white circle.

Constraints:
- **Art never changes the simulation.** No node here writes a synced or simulated value, and `test_art_sim_invariance` stays green.
- **Palette and outlines.** Tracked images use the master palette with whole alpha, and actor and item outlines stay 1 px. Light textures are made at run time and are not tracked images.
- **Renderer.** Godot 4.7.2's Compatibility renderer. Only a light texture drawn 1:1 with the screen (`texture_scale` 1) keeps hard steps; at any other scale the steps blur. The review measured this for ST1.
- **Settings.** "Reducir destellos" (`HurtCues.reduce_flashes`) turns every blink and flash into a steady tint or nothing (`docs/GAME_DESIGN.md` §4).
- **Solo.** Every part works the same with exactly one offline player.

## Goals / Non-Goals

**Goals:**
- A fire reads as the place to be at night: a warm pool of hard rings exactly as far as its company bonus, with a night bright enough that the sand and the sea still read.
- A squall is visible on the island and at sea: rain, a quicker sea and foam, and its name on the HUD.
- The crossing's sea has crests and a wake, and its flotsam looks like loot you can grab.

**Non-Goals:**
- **Lightning.** Q14 (a) leaves it out. DST's version is noted under References for a later storm change.
- **Birds at sea.** They would come through the ambient crossing creature data, and nothing in the task asks for them.
- **Decorative flotsam.** Crossing-gameplay's flotsam is grabbable loot, so drawn drift bits would read as loot that cannot be taken.
- **Art for crossing-gameplay's rocks, debris and leak spurts.** It is a follow-up; only flotsam is in this change.
- **Fuel-driven light.** The light's radius stays the company radius; there is no fuel system.
- **A per-cell light map.**
- **The rain filling catchers.** That already happens in the simulation (`rain = true`), and the drawing only shows it.
- **Changing the horizon line, the phase tag or the crossing HUD.**

## Decisions

### D1. A readable night and dusk, as data (C33a)
- **Night.** `day_cycle.tres` phase 3 goes from (0.35, 0.40, 0.65) to about (0.42, 0.47, 0.72). The fire's pool then reads against the night, and the sand and the shallows keep separate values.
- **Dusk.** Phase 2 goes from (0.90, 0.70, 0.60) to about (0.95, 0.78, 0.74). Multiplied into the shallows base, `#5fcde4` today and art-terrain-polish's darker base, blue stays the largest channel instead of green.
- **The pins** are properties, not numbers, because the tints are provisional (weather-daynight "Calm and squall data"):
  - at dusk, both the deep and the shallows ramp bases have blue greater than green;
  - the night tint's luminance (`Color.get_luminance`) is between 0.44 and 0.52. Today's is 0.41 and the target's 0.48;
  - the existing tint tests, which read the data, pass unchanged.
- **Builder's choice.** The exact values are tuned from the windowed captures and recorded in Build notes.
- **Seam with guardacostas-stealth.** A brighter night lowers the searchlight's relative contrast. The capture task re-shoots `docs/guardacostas-stealth/sandbar_night_beam.png` and checks that the beam still reads.

### D2. Firelight: one PointLight2D under the fire's Look (C33b)
- **The light.** `StructureLook`, for `KIND_FIRE` only, makes a `FireLight` `PointLight2D` child on its first step, the way `PatrolLook._make_light` does:
  - blend mode ADD, no shadows;
  - its `texture` is made by `FireGlow.texture(radius_px, steps)`;
  - `texture_scale` 1, and the node's `texture_filter` is nearest.
- **The radius** is `SurvivalTuning.company_radius_tiles × PlayerBody.TILE_SIZE`, read from `survival_tuning.tres`, so the pool is exactly the reach of the fire's company (Q13 (a)): 80 px today. A change to the tuning moves both together, and a test pins that.
- **The rings.** `FireGlow` (`scripts/art/fire_glow.gd`, pure static, like `PatrolCone`) makes a (2r + 1)² image of `steps` concentric bands of equal width:
  - each band has one value, from data;
  - 4 steps, after DST's four light steps;
  - nothing outside r.
  - It is made once per radius and cached.
- **Energy** is `ArtTuning.fire_light_energy` (below 1, for example 0.6), times the darkness, times the flicker:
  - **Darkness** is `clamp((1 − luma(tint)) / (1 − luma(night tint × calm tint)), 0, 1)`, read from `WeatherManager.sky.tint()`. It is 0 by day and full at night. At dusk it is partial.
  - At darkness 0 the light is hidden.
- **The colour** is `ArtTuning.fire_light_color`, a palette warm tone (#df7126 to start), tuned from the capture.
- **Flicker.** `ArtTuning.fire_flicker` holds one factor per frame of the lit flame animation. The light takes the factor of the flame sprite's current frame, so light and flame move together and nothing is random.
  - Under "Reducir destellos" the factor is the table's mean, held steady.
  - A test checks that the table's length equals the lit animation's frame count.
- **Off.**
  - When `lit` is false (embers), the light is hidden on that peer. A client follows the synced `lit`, as the flame already does.
  - Other structure kinds never make a light.
- **The flame at full colour** (artboard A11). It is optional and comes last: an unshaded flame overlay is kept only if a 4.7.2 Compatibility check shows it escapes the `CanvasModulate`. Otherwise the additive light over the flame is enough. The result goes in Build notes.
- **Rejected:**
  - **A tracked ring PNG through a recipe.** Its size must follow the company radius in data at exactly 1:1, and a texture rebuilt by hand for every tuning change drifts. `PatrolCone` already makes the searchlight's texture the same way, from data.
  - **A soft radial gradient.** It is not a GBA look, and its steps blur.
  - **A per-cell light map** (Brogue, DCSS), which is more than one fire needs.
  - **A random flicker** (Brogue's `randClump` on the radius). It is not the same on every peer, and it fights the reduce-flashes setting.

### D3. Rain as the squall's vfx scene, inside the tinted world (C34)
- **Where it lives.** `WeatherVfx` (`scenes/world/weather_vfx.gd`) is a Node2D child of `day_night_tint.tscn`, so every scene that tints its world (the shell's world view and the movement playground) also shows its weather.
  - On `WorldSky.changed` it instances the current weather's `vfx_scene` (`squall.tres` → `scenes/art/weather/rain_overlay.tscn`) and frees it when the weather changes away.
  - A new weather overlay, such as fog, is then data only.
- **Drawing.** Because it is a child under the `CanvasModulate`, the rain is multiplied by the sky's tint and lit by the fire's light, with no code of its own (artboard A12).
  - It draws at z 10: over actors (0) and under the name tags and speech bubbles (20).
  - Each frame it covers the camera's visible rect (`get_viewport().get_canvas_transform()`), so it rains over the island and over the crossing alike.
- **Streaks.**
  - `fx/rain.png` is a 64 × 64 seamless tile of 1 px diagonal streaks in #cbdbfc and #9badb7, whole alpha, in two frames: light (at most 12% of its pixels opaque) and heavy (at most 25%).
  - It scrolls down and to the left on the overlay's own clock.
  - The light frame shows for `ArtTuning.rain_light_s` after the squall starts, then the heavy one. This is Shipwrecked's staged storm as two stages.
- **Splashes.**
  - `fx/splash.png` holds 3 frames of a 5 × 3 tick in #cbdbfc.
  - At most `ArtTuning.rain_splashes` are shown at once, at screen cells and time slots picked by `TerrainArt.mix32` of (slot, cell). There is no random roll.
  - They play at 12 fps or less.
- **Process mode.** The overlay keeps moving under solo pause, like the sea.
- **Rejected:**
  - **A CanvasLayer.** It would escape the tint, which is exactly what made the review's mock read wrong.
  - **GPUParticles2D.** Its particles are not palette-whole and are hard to pin in a headless test.
  - **Fading the rain in by alpha.** It would show half-transparent off-palette streaks.
  - **Per-cell rain clouds** (DCSS `CLOUD_RAIN`). A squall covers the whole sky.

### D4. Faster sea and foam through CPU-accumulated clocks (C34)
- **The clocks.** A pure `SeaPace` (`scripts/art/sea_pace.gd`) keeps two clocks:
  - `sea_time += delta × sea_pace`;
  - `foam_time += delta × foam_pace`.
  Each pace eases toward the current weather's `WeatherData.sea_pace` and `foam_pace` (new, default 1.0; squall 1.8 and 1.6 to start) over `ArtTuning.pace_ease_s` (4 s to start).
- **No pop.** The rate changes but the clock never jumps, so neither the water texture nor the foam frame skips. A test checks that over a calm → squall change, `foam_time` never moves more than `foam_pace_max × delta` in a step.
- **Drivers.** A small `SeaPaceDriver` child (`scenes/art/sea_pace_driver.gd`, `process_mode` ALWAYS) under `TerrainView` and under `CrossingSea` owns one `SeaPace`. Each frame it writes:
  - `sea_time` to that view's sea material;
  - `foam_time` to the Shore layer's material on the island.
  Under solo pause the sea and the foam keep moving, as D12 and K47 require today.
- **Shaders.**
  - `world_sea.gdshader` replaces `TIME` with `sea_time` in its two drift terms only. The sway keeps `TIME`, so art-coast-pass's measured line excursion is unchanged.
  - `shore.gdshader` replaces `TIME * frames_per_second` with `foam_time * frames_per_second`.
  - At pace 1 both draw exactly as today.
  - The foam's peak, 6 × 1.6 ≈ 10 fps, stays under 12 fps (the foam is exempt from the frame budget, but it keeps under it anyway).
- **`SeaShaderChecks`** gains a reader for the new uniforms, and the K47 drift test reads `drift × pace`.
- **Rejected:**
  - **A larger `drift` uniform set on the weather change.** `drift × TIME` jumps by the change times the whole elapsed time, which is the pop the review warned of.
  - **Global shader uniforms.** They need project-wide `shader_globals` and a single writer, and per-material uniforms are simpler and testable headless.
  - **A clock inside `WorldSky`.** The sky pauses with the tree and resyncs from the host, but a cosmetic clock must do neither.

### D5. The weather label: its own window right of the day phase (C34)
- **The rect.** `WeatherPanel` (PanelContainer, theme variation `HudPanel`, `mouse_filter` ignore) is at (384, 4)–(464, 18), inside the phase tag's 14 px band:
  - 4 px right of the phase tag (260–380);
  - left of the teammate blocks: today's (520, 4)–(636, 18), and hud-window-kit's x 502–636;
  - above the compass needle (308, 20)–(332, 44), the sign note (200, 22)–(440, …) and the note label (140, 46)–(500, 66);
  - far above the crossing HUD's y 68–90;
  - over the patrol horizon band (0–640, y 0–6) only on rows 4–5, where the phase tag already sits; the patrol marks are on rows 2–3.
  - The day horizon line hides once a squall runs (weather-daynight "Squall runs its course"), and the label shows only then.
- **Text.** The label shows the current weather's own name, `name_es` or `name_en` by `CoopSession.locale_of(session)`, while that weather is not `is_clear`. The squall shows "Turbonada" (9 glyphs, 72 px, exactly the window's inner width at the HUD's 8 px glyphs) or "Squall".
  - A content test keeps every non-clear weather's names at 9 glyphs or fewer.
  - Calm is clear, so it shows nothing.
  - A new weather needs no script.
- **The no-overlap test** reads the real nodes' rects in `run_hud.tscn` (PhasePanel, TeammatesPanel, Needle, NoteLabel, Meters) and `SignNote.card_rect()`. It also checks hud-window-kit's teammate x 502 and the crossing HUD's band y 68–90 as constants until those land. It fails on any intersection.
- **Restyle.** hud-window-kit later restyles `HudPanel` into its dark window, so this needs nothing of its own. If the kit has landed first, the label takes `HudPanelThin` if its 10 px row fits the 14 px band. The builder records which in Build notes.
- **Rejected:**
  - **Appending the weather to the phase text** ("Atardecer · Turbonada" is 21 glyphs, 168 px, wider than the 120 px phase tag).
  - **A second line under the phase,** where the needle and the sign note sit.

### D6. Crests on the open sea (C35)
- **The node.** `CrossingCrests` (Node2D in `crossing.tscn`, z −38, in `art_view`) draws crest dashes from `sea/crests.png`: 3 frames, rising, peak and falling, of an 8 × 3 dash.
  - The colours are only the deep ramp (`#2a5578 #306082 #35678a #3a6f92`) and #4a85a8. They are never #ffffff or #cbdbfc, which the fin's foam, the swimmer's ring and the wake use, so no crest reads as a fin.
- **Where they show.** On a lattice of 3 × 3-tile cells over `sea_rect()`, each lattice cell shows at most one crest, in the time slots where `TerrainArt.mix32(cell, slot)` passes a density from data. Its position:
  - moves with `scroll_px()` like the water under it;
  - slides by the vessel's lateral position, as crossing-gameplay draws its hazards at `lane − position`.
- **Clients and joiners** draw the same crests from the plan clock, the scroll and the position they already receive.
- **Rejected:** a white crest layer (the review's "never white"), and animated noise in the sea shader. The latter would change the sea's every-pixel-a-ramp-colour rule and art-coast-pass's measured edge.

### D7. A wake at the bow and the stern (C35)
- **The node.** `CrossingWake` (Node2D, z −35, in `art_view`) reads `deck_rect()`, the boards' rects, the scroll and the integrity, and draws from `sea/wake.png`:
  - a 2-frame bow ripple along the north edge;
  - a 3-frame V of dashes trailing about 2 tiles south from the stern.
  The colours are #cbdbfc and #9badb7. The crossing scrolls north, so the bow is the north edge.
- **Which vessels.**
  - The raft and the car get one wake.
  - Each intact board gets a small one.
  - A sunk deck (integrity 0) and the swimmers' route get none.
  - Frames step with `scroll_px()`, so a faster route's wake runs faster.
- **The fin.** The wake stays inside the deck's x span. The fin circles 1 tile off the east or west edge (crossing-gameplay "Shooing the shark"), so the two never meet.
- **Rejected:** z −21, which the review suggested but art-sprite-polish's wet swimmer north of the deck uses. The wake belongs under the hazards anyway.

### D8. Flotsam that looks like loot (C35)
- **The node.** Crossing-gameplay's `CrossingHazards._draw_piece` (z −30) is replaced. A piece is now drawn as:
  - the item's own 16 × 16 icon (`ItemData.sprite`), cut at a waterline 3 rows above its lowest opaque row (the rows below are not drawn);
  - a 1 px bob from `TerrainArt.mix32(beat index)` and the plan clock;
  - a 2-frame dashed ring (#cbdbfc and #9badb7) at the line.
  - The plank is `sea/plank.png`, a hand-drawn 16 × 5 board with two nails, outlined in #222034.
- **Loot reads as loot.**
  - At least 9 rows of the icon stay above the line, so its silhouette and its #222034 outline show.
  - Black is the one outline colour that reaches 3:1 on deep water (art-pass "Actors stand out from the ground").
- **The grab point is not moved.** The bob is drawing only and at most 1 px, so the GRAB point, which follows the piece's position, stays on the drawn piece.
- **Out of this change.** Rocks, debris and leaks keep crossing-gameplay's placeholders.
- **Rejected:** decorative drifting bits (non-goal), and a white ring, so white stays the fin's.

### The crossing's z order
Shared with art-sprite-polish:

| z | What | Owner |
|---|---|---|
| −40 | sea | crossing (today) |
| −38 | crests | this change, D6 |
| −35 | wake | this change, D7 |
| −30 | `CrossingHazards`: rocks, debris, flotsam, leaks | crossing-gameplay, flotsam look D8 |
| −21 | a wet swimmer north of the deck | art-sprite-polish (C22) |
| −20 | deck and boards | crossing (today) |
| 0 | riders, the fin and creatures, y-sorted | crossing (today) |
| 10 | rain | this change, D3 |
| 20 | name tags and speech bubbles | today |

### D9. New art through one recipe
- **The recipe.** `tools/art/mood.py`, with `mood_fx.json`, reads the hand sources in `tools/art/fixes/mood/`: `rain.png`, `splash.png`, `crests.png`, `wake.png` and `plank.png`. For each one it checks:
  - the master palette (`palette.py`) and whole alpha;
  - the frame sizes, and the 64 × 64 rain tile being seamless;
  - the coverage limits: rain light ≤ 12% and heavy ≤ 25%;
  - the colour sets: crests only deep ramp plus #4a85a8, and wake and rain only #cbdbfc and #9badb7;
  - the plank's closed 1 px outline.
- **The output** goes to `game/assets/art/fx/` and `game/assets/art/sea/`, byte for byte on a re-run. Each file gets an own-work block in that folder's `License.txt`.
- **Tools.** It uses `png.py` only, never Pillow. No pack is read; the packs stay read-only.
- **Tests:** `tools/art/test_mood.py`.

## Reference games

Ideas and structure only, never code, data or text.

**Shattered Pixel Dungeon**
- *Borrowed for C33b:* `effects/TorchHalo.java` (`update`, `putOut`). A light-blended halo sits over its sprite and eases in when lit and out when put out. Our light shows and hides with `lit`; its energy eases with the darkness, not per lighting.
- *Rejected:* `com.watabou.noosa.Halo`'s smooth radial gradient. Hard steps fit the GBA look and the 1:1 rule.
- *Borrowed for C34:* `effects/Splash.java` (`at`), a short burst drawn where something lands, as the splash ticks. Ours come from a hash, not a random burst.

**Brogue CE**
- *Borrowed for C33b:* `Light.c` `updateLighting`, which paints every light source (`paintLight`) over the dark each turn. A fire is a light source.
- *Rejected:* the per-cell light map that `paintLight` accumulates into `tmap`, and `randClump` on the radius, which flickers by chance.

**DCSS**
- *Rejected for C33b:* `tileview.cc` `tile_apply_properties`, which marks cells inside a halo with a per-cell overlay, for the same reason as Brogue's light map.
- *Rejected for C34:* `cloud.cc`'s `CLOUD_RAIN`, a rain cloud tile per cell. A squall covers the whole sky.
- No DCSS weather fits C35.

**Pokémon Ruby/Sapphire/Emerald** (general knowledge of how it looks; nothing copied)
- *Borrowed:* rain as a full-screen overlay of short diagonal streaks over the world, with the world still readable through it. The streak count is kept low.

**Don't Starve Together** (`docs/REFERENCE_DST.md`; dontstarve.wiki.gg)
- *"Darkness and the night attacker"* (Charlie/Darkness, Night). *Borrowed:* light as the safe pool at night, so a fire is where the party gathers. Our pool is exactly the company radius that stops the lonely-night morale drain. *Rejected:* the unseen attacker. Night penalties are the simulation's business, not this change's.
- *"Campfire and fire pit fuel"* (Campfire/DST, Fire Pit). *Borrowed:* light and heat grow in four steps, as the pool's four hard rings. *Rejected:* a radius that follows the fuel level, because the burn time is fixed and the radius is the company bonus.
- *"Rain as a moisture accumulator"* (Rain/DST). *Borrowed:* rain shown with its intensity, as our light and heavy stages. *Rejected:* the hidden moisture value, which is weather simulation, not drawing.
- *"Storms at sea (from Shipwrecked)"* (Waves, Hurricane Season). *Borrowed:* the staged storm, as the rain's light-then-heavy build-up. *Rejected for now:* waves with a heading. That is crossing gameplay.
- *"Lightning"* (Rain/DST, Lightning). *Rejected now* (Q14 (a)). It is noted for a later storm change, telegraphed by a flash and behind "Reducir destellos".
- *"The sea graded by distance from land"* (Ocean/DST). *Borrowed:* "darker means deeper". The crests keep to the deep ramp so the open sea stays dark and readable.

## Owner decisions

- **Q13 (a), accepted 2026-11-14:** a warm light pool as far as the company bonus, and a slightly brighter night.
- **Q14 (a), accepted 2026-11-14:** rain, a faster sea and foam, and a weather label. No lightning.
- **No new question.** The label's rect (D5) is clear of every HUD node and of the planned kit and crossing HUD.

## Seams with other changes

- **art-coast-pass (wave 1).**
  - This change MODIFIES art-pass "Scrolling sea" with art-coast-pass's text, so it archives after art-coast-pass. Before archiving it re-syncs that block with the archived spec.
  - Its shader edit (D4) sits on art-coast-pass's warp and sway.
- **art-terrain-polish.**
  - Its darker shallows (C7) change the ramp D1's dusk test reads. The test reads the ramps from `ArtTuning`, not constants.
  - It MODIFIES "Shoreline overlay". This change does not, because the foam's speed is not in that requirement.
- **art-sprite-polish.**
  - The z table is shared.
  - The swim ring's #ffffff and #cbdbfc are kept off the crests.
- **crossing-gameplay.**
  - D6 to D8 read its lateral position, `CrossingHazards` and the flotsam table, so C35 builds after it merges.
  - `crossing.tscn` gains two nodes, and `crossing_hazards.gd`'s `_draw_piece` is replaced.
- **hud-window-kit.**
  - The label uses `HudPanel`, which the kit restyles. D5's rect is clear of the kit's teammate blocks.
  - If the kit lands first, the builder re-reads its `run_hud.tscn` rects before placing the label.
- **guardacostas-stealth.** A brighter night lowers the searchlight's relative contrast (D1). The capture checks it.

## Risks / Trade-offs

- **[A brighter night weakens the dark]** The night is still under half the day's luminance, and §5's "night is dark" holds. The fire's pool now carries the contrast.
- **[Light2D cost in Compatibility]** One light per lit fire, on a few fires, with no shadows. The searchlight already runs the same way, and the capture run reads the frame time.
- **[A ring texture of (2r + 1)²]** That is 161² px at r = 80, made once and cached.
- **[Clocks drift apart from the shader's `TIME`]** Only the drift and the foam frames move to `sea_time` and `foam_time`. The sway stays on `TIME`, which changes nothing visible.
- **[Rain hides the ground]** The coverage is capped at 25% and drawn in light, tinted colours, and the capture checks that a crouched player and pick-ups still read.
- **[Flotsam bob against the grab point]** The bob is 1 px, drawing only, and the GRAB point follows the synced piece.

## Migration Plan

Art and presentation data only. Rebuild the new sheets with `python -I tools/art/mood.py` and re-import. To roll back, revert the commits and restore the two tints in `day_cycle.tres`. No save, network message or layout depends on any of it.

## Build notes

Measured values (the final tints, light energy and flicker table, paces, the rain coverage, whether the unshaded flame overlay works in 4.7.2 Compatibility, the label's panel variation) are recorded here as the tasks ship.

**Gate (0.1).** art-coast-pass merged into main (c0a1915, 2026-11-15); the coordinating session said go. It is not archived yet, and this change's MODIFIED "Scrolling sea" block was copied from its delta, which has not changed since; the block is re-synced when it archives.

**C33a, a readable night and dusk (group 1, D1).**
- `day_cycle.tres`: dusk (phase 2) (0.90, 0.70, 0.60) → (0.95, 0.78, 0.74); night (phase 3) (0.35, 0.40, 0.65) → (0.42, 0.47, 0.72). The design's values held on the captures, so no tuning was needed.
- Tests (written first, failing on today's tints): `test_at_dusk_the_tinted_sea_stays_blue` (the deep and shallows ramp bases times dusk keep blue above green; today's shallows went teal, green 0.563 over blue 0.537) and `test_night_is_dark_but_readable` (the night tint's luminance 0.44–0.52; today 0.407, now 0.477). `test_the_tint_node_takes_night_times_calm` (1 player) and `test_world_sky`, `test_weather_content`, `test_searchlight` pass unchanged.
- Captures: `docs/art-pass/mood/dusk_night_before_after_x2.png` (the sandbar's west shore from a windowed day capture times the dusk tint, top, and the night tint, bottom; before left, after right; the CanvasModulate is a plain multiply, so this is exact), and `docs/guardacostas-stealth/sandbar_night_beam.png` re-shot with `capture_patrol.tscn`: the searchlight still reads clearly against the brighter night. The day capture predates art-terrain-polish C7's darker shallows; with them, dusk stays blue too (the test reads whatever ramp is on main).

**C33b, firelight (group 2, D2).**
- `FireGlow` (`scripts/art/fire_glow.gd`, pure static, cached by radius and values): a (2r + 1)² image of equal-width bands from the centre out, one value each, nothing beyond r. `FireGlow.radius_px(company_radius_tiles)` is the tiles × 16, so the sandbar's 5 tiles give 80 px and a tuning of 6 gives 96 (a 193 px texture).
- `ArtTuning`: `fire_light_energy` 0.6, `fire_light_color` #df7126, `fire_light_steps` 4, `fire_ring_values` (1, 0.7, 0.45, 0.22) and `fire_flicker` (1, 0.88, 0.95, 0.82), one factor per frame of the 4-frame lit flame.
- `StructureLook`, for a fire only, makes `FireLight` (PointLight2D, ADD, no shadows, texture_scale 1, nearest) on its first step. Its energy is the tuning's energy × `StructureLook.darkness(sky)` × the flame frame's flicker factor; `darkness` is (1 − luminance of the sky's tint) over (1 − luminance of the night tint), clamped, so 0 by day, partial at dusk and 1 at a calm night. It is hidden at darkness 0 and when the fire is out (embers). Under "Reducir destellos" it holds the table's mean.
- **2.4, the unshaded flame: not kept.** On the capture the additive pool already keeps the flame at full warm colour, not olive, so no overlay sprite was added.
- Tests (written first; they failed to parse before `FireGlow` existed): a solo lit fire at night has the light visible, ADD, 1:1, 161 px wide, energy in (0, 1), no shadows; off by day and once out; no light on a palm, a rain catcher or a workbench; the radius follows the company tuning (6 → 193 px); exactly 4 hard steps and nothing beyond r; the flicker follows the flame's frame through the table and holds steady under "Reducir destellos"; the table's length is the lit animation's frame count. `test_art_sim_invariance` and `test_patrol_cues` stay green.
- Capture: `docs/art-pass/mood/firelight_night_after_x3.png`, from a new manual tool `tests/manual/capture_firelight.tscn` (the real sandbar under the night tint in a viewport, a lit fire on the beach nearest the solo spawn, a player two cells east). Four hard warm rings reach 80 px; the flame stays bright; sand and player are lit inside the pool. Process frame time 8.6 ms. Before: `docs/art-pass/review-2026-11-14/before/sandbar_night_fire_x3.png`.


**Art for the squall (group 3, D9).**
- `tools/art/mood.py` and `mood_fx.json` build `fx/rain.png` and `fx/splash.png` from hand sources in `tools/art/fixes/mood/`. It checks the master palette, whole alpha, the frame grid, a piece's own colours, the rain's cover per stage, seamless streaks (a streak leaving an edge goes on at the opposite one) and closed 1 px outlines; it reads no pack, writes nothing when any source is refused, and a re-run gives the same bytes.
- The rain's measured cover: light 6.7%, heavy 14.5% (limits 12% and 25%). The first heavy drafts covered 19.7% (too dense on the capture) and then 10.6–11% (too thin to tell from the light one); a 1 px gap between heavy streaks, 85 streaks of 7 px, settled it.
- **Departure:** `crests.png`, `wake.png` and `plank.png` were drawn but are not tracked yet. `check.py` refuses tracked art that no scene or resource names, and only group 5's crossing nodes name them; they join the recipe there. Their drawing helper is kept outside the repo until then.
- **Order, honestly:** `mood.py` was written before `test_mood.py` was run, so the recipe tests never had a red run against a missing builder; each rule was then checked against a failing fixture.

**C34, a squall you can see (group 4, D3–D5).**
- **Data.** `WeatherData.sea_pace` and `foam_pace` (Presentation, default 1). Squall 1.8 and 1.6, kept from the design after the capture: the foam peaks at 6 × 1.6 = 9.6 fps. `ArtTuning.pace_ease_s` 4, `rain_light_s` 20, `rain_splashes` 6 (3 in the light stage). The overlay's own `fall_px_s` 96 and `splash_fps` 10 are properties of `rain_overlay.tscn`.
- **SeaPace** moves each pace at a steady rate set when its target changes (the gap over `pace_ease_s`), so a whole change takes exactly the ease and the clocks only ever change rate. `world_sea.gdshader`'s two drift terms read `sea_time`; the sway keeps `TIME`, so art-coast-pass's measured line excursion is unchanged. `shore.gdshader` steps on `foam_time`. `SeaPaceDriver` (process mode ALWAYS) is a node in `terrain_view.tscn` and is added in code by `CrossingSea._init` (so crossing.tscn, which crossing-gameplay owns, is untouched). `SeaShaderChecks` gains `clock_of` and `drift_per_s(material, pace)`.
- **The rain.** `WeatherVfx` under `day_night_tint.tscn` shows the current weather's `vfx_scene`; `RainOverlay` draws the 64 px tile over the camera's rect, anchored to the screen and scrolled down and to the left, at z 10, process mode ALWAYS.
  - **Departure:** `WeatherVfx` follows the sky every frame, as `DayNightTint` itself does, instead of connecting `WorldSky.changed`: the tint sets its sky in its own `_ready`, after its child's, and a frame's check is cheap. It makes a new instance only when the scene changes.
  - **Departure:** the stage reads the synced weather's own time (its duration less what is left) when it has a duration, so a peer that joins mid-squall sees the same stage; the overlay's own clock is the fallback.
  - **Departure:** splashes land on world cells inside the view (not screen cells) and each keeps its cell for its whole slot, so a splash stays on the ground while the camera moves. `RainOverlay.splash_cell(slot, index, view)` mixes them by `TerrainArt.mix32`; a slot is 3 frames and 2 empty ones at 10 fps.
  - The tile and the tick are exported properties set in `rain_overlay.tscn`, because the art checks want a scene or resource to name every tracked PNG.
- **The label (D5).** hud-window-kit had landed (0.3): the teammate column is at x 502–636 in `run_hud.tscn` and the theme has `HudPanelThin`, whose 10 px row fits the 14 px band, so `WeatherPanel` takes it, at (384, 6)–(464, 16). Its text row (y 7–15, 72 px wide, "Turbonada" exactly) lines up with the phase tag's. `RunHud.weather_name(weather_id, locale)` reads the weather's own name from the session's climate; clear weather shows nothing.
- **Tests.** `test_mood_fx.gd` (8, one player offline): the ease and the no-jump bound, back to calm, the shaders' clocks, the solo sandbar's driver writing both materials, a paused tree moving the sea and the foam but not the day, the crossing sea's own driver, the solo squall's rain under the tint at z 10 and gone with calm, the light then heavy stage by the squall's time, and hashed splashes with no random generator. `test_weather_content.gd`: calm at pace 1 and every non-clear weather's names in 9 glyphs. `test_run_hud.gd` (4, solo): "Turbonada", "Squall" in English, hidden in calm, and the rect inside y 4–18 clear of PhasePanel, TeammatesPanel, Needle, NoteLabel, the meters' window, the sign note, x 502 and the crossing band. **Order, honestly:** the 4.1 tests were written before the code but first run after it; the 4.5 tests were run first and failed on the missing panel.
- **Capture (4.6).** `art_pass_run.gd --mode=solo --only=squall` (new step, windowed, 20 checks pass, no engine error): by day the paces reach 1.80 and 1.60 in 4 s and no clock moved faster than 1.80× a frame's time; the crouched player and the pick-ups read through both stages; the label sits beside the phase. At night a lit fire's pool lights the rain. Image: `docs/art-pass/mood/squall_before_light_heavy_night.png` (calm by day, the light stage, the heavy stage, night by a fire; half size). Compare `docs/art-pass/review-2026-11-14/before/sandbar_squall_day.png` and `before/sandbar_night_squall_fire.png`.
  - A squall puts out an unsheltered fire in 5 s (`fire_extinguish_s`), so the night shot is 1 s into it, in the light stage; at night the light streaks are dim except inside the fire's pool, which is the intended read.
  - The whole windowed solo run (`--mode=solo`) passed every step after the squall starts. Its two night checks had read the tint 1 s into the night, which with C33a's brighter dusk is still mostly dusk: the night darkening read ×0.84 (limit 0.8), and a later shore view lost its foam under the patrol's beam. The run now waits out `blend_s` before its night views; `--only=foam` then passed 40 of 40, all four night views included.

**C35, life on the open sea (group 5, D6–D8).** Stacked on art-sprite-polish group 7 (#127), which is stacked on group 6 (#123), from main f8a6c75, after crossing-gameplay (#70, #75).
- **Gate (0.2).** crossing-gameplay's merged code was re-read:
  - `CrossingHazards` draws the lane beats from `shown_beats()` at z −30;
  - a lane beat sits at `lane − steer.position` across and its time to come up the sea (`Crossing.beat_center`);
  - flotsam pieces come from the tuning's `flotsam_items`, `coco` and `PLANK_ID` among them, with a GRAB point half a tile toward the deck from the piece (`_refresh_play_points`).
- **Tests first.** In `test_crossing_art.gd`; they failed for the right reasons against a compile-only skeleton:
  - **crests:** the solo raft crossing's `Crests` is at z −38, in `art_view`, its texture only the deep ramp and #4a85a8, and it shows several crests inside the sea that move as the water does;
  - **the wake:** `Wake` is at z −35, its textures only #cbdbfc and #9badb7. The raft gets one full wake, with the bow on the deck's north edge and the stern trailing at least a tile south, both inside the deck's x span. Its steps per wrap divide by 2 and 3;
  - **no wake** on the binoculars swim or once the deck has sunk;
  - **boards:** a 2-board `test_board` route shows two small wakes, each inside its board's span, and one once a board breaks;
  - **host and client:** in the two-peer test, the client's crests equal the host's computed at the client's plan time and position;
  - **the coconut:** a coconut in lane 3 is drawn from its own icon, with at least 9 rows above its waterline, the rows under it cut, and a ring. It sits within 0.5 px across and 1.5 px down of its beat over 12 steps, its bob 0 or 1. Every flotsam item keeps 9 rows;
  - **the plank** piece is `sea/plank.png`.
  - `test_draw_order.gd`: the crests and the wake lie over the sea and under the hazards.
  - `test_mood.py`: the tracked list gains the five sea pieces.
- **Crests (D6).** `CrossingCrests` draws what `CrossingArt.crests` gives. A lattice of 3×3-tile cells lies on the water. Each cell shows at most one crest, in the 1.6 s slots its hash passes a density of 0.3 (`ArtTuning.crest_*`). Where in the cell and when in the slot come from the same hash.
  - **Departure:** the water's drift is the route's scroll speed times the plan clock, unwrapped, plus `steer.position` sideways, not `scroll_px()`. That scroll is accumulated on each peer and wraps at 64 px, which is no multiple of the 48 px lattice, so crests keyed to it would differ between peers and jump at each wrap. Both move at the same speed.
  - `sea/crests.png`: 3 frames of 8×3, a light #4a85a8 top over a #2a5578 trough. The first draft used mid-ramp blues and barely showed against the water.
- **The wake (D7).** `CrossingWake` draws what `CrossingArt.wakes` gives for each deck `CrossingArt.drawn_decks` names (group 7's rule):
  - the bow ripple, 2 frames of 16×3, laid across the deck's width just north of its edge;
  - the stern V, 3 frames of 32×24, from 2 px under the stern;
  - a board's small V is the full V's top middle 16×12;
  - the frames step 12 times per scroll wrap (`ArtTuning.wake_steps`), so the wrap never shows and a faster route's wake runs faster.
  - **Departure:** two files, `sea/wake_bow.png` and `sea/wake_stern.png`, not one `wake.png`, because `mood.py` takes one frame size per piece.
- **Flotsam (D8).** `CrossingHazards._draw_piece` now draws what `piece_look(beat)` gives:
  - the item's icon, cut 3 rows above its lowest opaque row but keeping at least 9 rows (`ArtTuning.flotsam_cut_rows`, `flotsam_min_rows`);
  - a 0 or 1 px bob from the beat's index and the plan clock, every 0.5 s;
  - a 2-frame dashed ring at the line.
  - The plank is `sea/plank.png`, 16×5 with two nails. The piece stays centred on its beat, so the GRAB point stays where crossing-gameplay put it. Rocks, debris and leaks keep crossing-gameplay's placeholders.
  - **The clamp, measured:** cut 3 rows above its bottom, the cloth would keep 8 rows, so the cut stops at 9. The coconut keeps 9, the inner tube 10, the driftwood, rope and jug 11.
  - **Departure:** the plank's outline is black, not #222034. Black is the outline the item icons beside it carry (art-prop-polish D1's actor family), and its ring reaches 3.34:1 on the deep where #222034 reaches 2.52:1.
  - **Departure:** the ring is a recipe piece, `sea/flotsam_ring.png` (2 frames of 18×5), so its colours are checked, though D9 did not list it.
- **The recipe.** `mood_fx.json` adds the five pieces with their colour sets and the plank's closed outline; `mood.py` builds 7 files. The own-work blocks are in `sea/License.txt` and the fixes' licence. The new textures are named by `crossing.tscn` (`Crests`, `Wake` and the hazards' `plank_texture` and `ring_texture`), as `check.py` asks.
- **A shared helper.** `CrossingArt` (`scripts/art/crossing_art.gd`, from art-sprite-polish group 7) holds the crests, the wakes, the waterline cut and the bob as pure reads, so the tests read what is drawn rather than pixels.
- **Capture (5.3),** off-screen per the owner's 2026-11-23 rule: `capture_crossing.tscn` adds `crossing_flotsam.png`, with a coconut and a plank drifting past. The board route ran in GUT only, headless: `test_a_board_route_shows_one_small_wake_per_intact_board`. The capture scene runs the real shell, which has no board route outside the test fixture.
- **Image:** `docs/art-pass/mood/crossing_sea_before_after_x3.png`. Above, `before/crossing_raft_aboard_x3.png`. Below, the same view now: the stern wake trailing the raft, faint crests on the open water, and the plank and the coconut on their rings.
