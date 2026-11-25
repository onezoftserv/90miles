# Design

## Context

See proposal.md "Why" for the review findings. As built on main 446f22b:

- **The patrol boat** is a `Creature` with no `sprite_frames`.
  - `PatrolLook` (`scenes/creatures/patrol_look.gd`) draws a 17×8 grey polygon, rotated to any heading, while the boat is in sight.
  - The searchlight is a `PointLight2D` whose texture is `PatrolCone`'s wedge. The wedge is generated so it lights exactly the cells `Searchlight` lights, with a 2.5° / 4 px rim inside the edge.
  - The loudhailer line goes through `CoopSession.show_bubble`, a world-space `SpeechBubble` label.
- **The squad.** `SquadLook` draws:
  - each soldier as a 9×15 box;
  - the dinghy as a 9×5 polygon inside the boat's canvas item, so it y-sorts at the boat's position out at sea;
  - the squad's calls, through `show_bubble`.
- **Art data exemptions.** `CreatureArt.frames_problems` exempts both creatures "until their art exists".
- **The HUD marks.**
  - `BodyMarks` (`scripts/ui/body_marks.gd`) draws the 7×5 closed eye, open eye and rope pixel by pixel in code. The open eye's 3×3 iris fills with `spot_shown`.
  - `PatrolHorizon` draws a 5×2 grey hull or a 3×2 light on the 6 px horizon band, placed by the bearing of the lap start.
- **The scene panel.** `ScenePanel` (`scenes/ui/scene_panel.gd`) is a 400 px paper card at (120, 262): name, then text revealed at 40 chars/s. It has no portrait. Only the host's interact skips a line.
- **The capture scene.** `CaptureScene.hold_s` holds a line for `length / 40 + 2` s, measured on the Spanish text the host resolved.
  - `begin_scene` hides every body (`IslandArrival.hold`).
  - `_finish` runs the outcome's effects, including `TAKE_ITEMS_WITH_CAPABILITY` (fire sources) and the travel. `EffectApplier` throws away the ids that `Inventory.take_capability` returns.
- **Where the boat is at capture.** A squad's boat docks where it spotted. `SquadPlan.landing_cell` is the nearest land, and the dinghy rows there. In a haul at sea, the boat is alongside the swimmer. On a non-final crossing, the crossing's own view is shown.
- **The art pipeline** (`docs/ASSETS.md`).
  - Player looks are composed at load time from parts (`LookComposer`): a body, an outfit drawn in the clothing key ramp, a hair layer and an item, each built by `tools/art/compose.py` from MetroCity bands, pose rules and a hand-fix overlay. A character animation may have 6 frames.
  - Creature sheets are built by `tools/art/creatures.py` from hand sources. A creature animation may have 4 frames.
  - The HUD kit's pieces are built by `tools/art/ui.py` from `ui_kit.json`, which includes `icon` pieces drawn row by row.
- **The outline family check** (actors black, structures in dark tones) is art-prop-polish D1, open as PR #105 (`claude/art-prop-outline`). It is **not on main**. This change rims every new actor sheet in #000000, so it passes that check either way.
- **Tests that pin today's look.** Tasks rewrite them first:
  - `test_patrol_cues.gd`: 5×2 hull, 3×2 light, the polygon hull, and the cone as a 60° wedge with its rim inside;
  - `test_capture_cues.gd`: `test_the_soldier_and_the_dinghy_are_drawn_from_the_synced_state`, and calls in bubbles;
  - `test_body_look.gd`: `MARK_SIZE`, the open-eye placement;
  - `test_capture_scene.gd`: `hold_s` as length/40 + 2, and the panel's 40 chars/s and fit;
  - `test_look_parts.gd`: the shipped part list;
  - `test_capture_cues.gd:88`: the rope's 7×5, which stays and is only re-read.

## Goals / Non-Goals

**Goals:**
- Every new picture is built by a tracked recipe from tracked hand sources or packs, and is reproducible byte for byte.
- Every new node only reads synced state. Each one joins `test_art_sim_invariance`.
- The two behaviour changes (pacing and the confiscation report) stay host-decided and small.
- New files and nodes added from `bind()` are preferred over edits to scenes that other sessions touch.

**Non-Goals:**
- The closed eye and the rope mark (still 7×5).
- H6's outline of a body hidden under a roof (SP12).
- H5's notice line and the motor sound (the sound pass).
- Taken captives' losses at the time they are taken. The notice covers only the scene's outcome.
- Emotion-specific portraits.
- Showing the held party inside the staged scene.
- The final crossing's `devuelto`.

## Decisions

### D1. Reference games (ideas only, nothing copied)

**Shattered Pixel Dungeon** (`core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`):
- **Borrowed for D2:** `sprites/GuardSprite.java` and its kin. A mob variant is a frame list over a shared sheet, not new drawing code. Our soldier looks are data (`PlayerLookData`) over the shared people parts.
- **Borrowed for D7:** `effects/EmoIcon.java` (`Alert`, `Lost`, driven by `CharSprite.showAlert`/`showLost`). A small icon owned by the sprite follows it and hides with it, which is our eye mark following its body.
- **Rejected:** SPD's icons are binary. Ours carries a 0–1 meter (D7).
- **Borrowed for D11:** `windows/WndTitledMessage.java` and `WndQuest.java`, an `IconTitle` (portrait plus name) over a text block in a bordered chrome. That is the panel's portrait column.
- **Rejected:** `windows/WndStory.java`'s full-screen tap-to-dismiss blocker. Co-op cannot block every peer on one press.
- **Borrowed for D9's warning:** `ui/DangerIndicator.java` stays hidden until there is a threat, then shows one small chip.
- **Rejected:** click-to-cycle the camera to the threat. It is real time, and there is no pause in co-op.

**DCSS** (`crawl-ref/source/`):
- **Borrowed for D6:** `mon-speak.cc` `mons_speaks_msg`, with `MSGCH_TALK` against `MSGCH_TALK_VISUAL`. Speech is a channel apart from other messages, and visual chatter is shown only when the speaker is seen. Our calls are a kind of window of their own, and an off-screen speaker points from the edge.
- **Borrowed for D7:** `output.cc` `stealth_pips`/`_stealth_bar` shows stealth as a graded bar, and `tile-flags.h` `TILE_FLAG_*` (`TILEI_UNAWARE`, drawn in `tiledgnbuf.cc`) as a per-monster overlay. The bar under the eye is the graded part.
- **Borrowed for D11:** `message.cc`'s `--more--` prompt is a visible cue that the text waits for a key.
- **Rejected:** blocking every peer until a key.

**Brogue CE** (`src/brogue/`):
- **Borrowed for D4:** `lightCatalog` (`Globals.c`) with `radialFadeToPercent` (`Rogue.h`), painted by `paintLight` (`Light.c`). A light's falloff is data, and its edge is soft by construction. Our cone keeps its near and far falloff and gains a rim centred on the true edge.
- **Borrowed for D6:** `IO.c` `flashMessage`, a short coloured string with a backing colour at a map cell, that fades. That is our window over the speaker.
- **Rejected:** writing straight on the map with no backing.
- **Borrowed for D11:** `IO.c` `message`, which draws `--MORE--` in inverse colours at the line's end. That is our arrow placed after the text, in the HUD's alert colours.
- **Borrowed for D7:** the sidebar's "Stealth range" (`IO.c`), whose colour runs from shadow to light with the value. That gives our bar's warm colour near 1.

**Don't Starve Together** (dontstarve.wiki.gg, ideas only):
- **Borrowed for D6:** the Pig King and character pages ("Quotes" sections). Speech floats over the speaker's head and lasts by its length.
- **Rejected:** unbacked floating text. That is today's problem, H4.
- **Borrowed for D9:** the Hound page. A coming attack is warned with a sound that grows, plus a short character line, before the hounds show. Our chip blinks faster in the last 5 s; the sound pass owns the sound.
- **Borrowed for D3:** the Boat page. Boats are bigger than a player and hold several, which is the scale rule for our launch.

**GBA dialogue boxes** (Pokémon Ruby, Sapphire and FireRed; Zelda: The Minish Cap; A Link to the Past), from general knowledge:
- **Borrowed for D10 and D11:**
  - A box across the bottom, 2–3 lines of text.
  - A small arrow that bobs or blinks at the bottom-right once the text has typed out.
  - A portrait or name tab at the box's left in story scenes.
  - Black bars in cutscenes while the HUD steps away.
- **Rejected:** a full-width box. The 640×360 view keeps the 400–440 px card the sign note set.

### D2. Soldiers are composed people (character path, not creature frames)

- **The look.** A soldier's look is a `PlayerLookData` composed by `LookComposer`, as a player's is: MetroCity's body, `outfit_uniform` and `hair_cap`.
  - **`outfit_uniform`:** a `look_parts.json` entry over MetroCity `Outfit5` (shirt, long trousers, shoes). Its colour map sends the shirt and trousers to the olive ramp #8f974a, #4b692f, #524b24 and #323c39, and the shoes to #222034 boots. It is drawn directly in palette olives, not the key ramp, so no slot swap touches it. A soldier needs no shader.
  - **`hair_cap`:** a hair-layer part whose hand-fix overlay `tools/art/fixes/hair_cap.png` draws a patrol cap (a crown in #4b692f and #8f974a, a visor in #323c39) on every cell, made by a one-off scratch script, as earlier hand sources were.
  - The rim is #000000, like every part.
- **Three looks** in `game/assets/art/characters/looks/`: `soldado_1` (body_man, skin row 0), `soldado_2` (body_man, skin row 2) and `soldada` (body_woman, skin row 1). `skin_ramps.png` has three rows.
  - A soldier takes look `n mod 3`, where `n` is the number in its node name (`Creature<n>`, the same on every peer).
  - The squad's three are spawned one after another, so no two share a look.
- **Drawing.** `SquadLook` gives each soldier an `AnimatedSprite2D` with the composite's frames.
  - The pose comes from `PlayerPose.pick` (standing or walking only), and facing comes from a `Facing` observing the drawn position, as `PlayerLook` does.
  - The feet are on the creature's position, with a `DropShadow`.
  - The flashlight glint stays, as one pixel at night on the facing side.
- **Rejected:** soldier frames as a creature sheet. The creature cap is 4 frames, against MetroCity's 6-frame walk, and `CreatureLook` would also draw any creature that has `sprite_frames`, so it would draw twice. The soldier keeps `sprite_frames = null`, and its exemption in `CreatureArt.frames_problems` is reworded to "drawn by the squad look", not removed.
- **Data.** The look list lives in `GuardacostasArt` (D5), so adding a fourth look edits no script.

### D3. The launch and the dinghy are creature sheets drawn by the coast guard looks

**The launch.**
- `creature_sheets.json` gains `patrol_boat`: a 384×48 sheet, four 96×48 cells in one row. Two frames of `move` with alternating bow foam, two of `idle` with a 1 px bob.
- It is drawn from `tools/art/fixes/creatures/patrol_boat.png`:
  - a grey hull (#9badb7, #847e87, #595652);
  - a white cabin (#ffffff, #cbdbfc) with dark windows;
  - one plain #306082 stripe, with no agency mark or flag;
  - a lamp (#fbf236 on #595652) on the cabin roof.
- The opaque bounds are about 88×36, against the raft's 64×32 frame.
- The sheet is rimmed #000000.

**The dinghy.**
- `dinghy` is a 96×16 sheet in 32×16 cells, three frames: `row` ×2 (oars forward and back) and `beached` ×1 (oars in, a wet-sand fringe).
- It is a brown wooden hull (#8f563b, #663931) with grey oars, rimmed #000000.

**Drawing.**
- `PatrolLook` replaces the polygon with an `AnimatedSprite2D`:
  - shown only in sight states;
  - `flip_h` when the heading's x is below 0;
  - `move` while the drawn position moves, `idle` otherwise.
- The sprite is offset so the lamp pixel sits on the creature's position. The light's apex is the same point, so the drawn lamp and `Searchlight`'s apex agree. The hull itself shows about 14 px south of the boat's position, within one tile.
- **Rejected:** rotating the sprite to any heading. With nearest filtering it shears, and the raft and the car already establish side-on, mirrored vessels.
- The dinghy moves out of the boat's canvas item into a new `DinghyLook` child of the creature, created by `SquadLook`.
  - The creature node has `y_sort_enabled`, so the child sorts by its own position, `dinghy_px`.
  - Its frame is `row` while `0 < dinghy_t < 1`, and `beached` when `dinghy_t >= 1` with a squad ashore.
  - It is mirrored by the direction it rows.

### D4. The cone's rim is centred on the true edge

- `PatrolCone._build` keeps the near and far falloff (0.9 to 0.6) and changes only the edges.
  - **The angular edge:** `smoothstep(-RIM_DEG/2, RIM_DEG/2, half_cone - off)`.
  - **The range edge:** `smoothstep(-RIM_PX/2, RIM_PX/2, radius - distance)`.
  - The rim is 8° and 12 px.
- At the true edge a cell is lit at half strength. Inside the rim's inner half it is at full strength, and beyond the outer half it is dark.
- The texture grows by the rim's outer half, so `length_px` and `height_px` add it, and the light's offset still puts the apex on the boat.
- A test reads the texture back through `Searchlight`'s cell rule (the spec's "Lit cells look lit").
- **Rejected:** a wider rim inside the edge only. Then a lit cell near the edge could show almost no light, which is a lie in the dangerous direction.

### D5. One art resource for the coast guard

- `GuardacostasArt` (`scripts/art/guardacostas_art.gd`, `res://assets/art/creatures/guardacostas_art.tres`) is art data, like `CreatureArt`. It holds:
  - `hull_frames`, `hull_lamp_px` and `hull_foot_px`;
  - `dinghy_frames`;
  - `soldier_looks: Array[PlayerLookData]`;
  - `soldier_foot_px`.
- `PatrolLook` and `SquadLook` read `GuardacostasArt.standard()`.
- `patrol_boat.tres` and `shore_soldier.tres` keep `sprite_frames = null`, so `CreatureLook` stays out.
- **Rejected:** frames on the creature data. `CreatureLook` would draw them in every state, including AWAY.

### D6. Call windows in the HUD

- **The node.** `CallWindows` (`scenes/ui/call_windows.gd`) is a `Control` that `RunHud.bind` adds. It listens to a new `CoopSession.call_shown(speaker: Node2D, text: String)` signal.
  - `PatrolLook._speak` and `SquadLook._speak` emit it instead of calling `show_bubble`.
  - Quick chat and signs keep `SpeechBubble`.
- **The window.**
  - It uses its own variation `HudCall`, the `window_thin` stylebox with content margins 4/1/4/1, so it is not one of `RunHud.HUD_PANELS`. The prompt does not dodge calls.
  - Cream 8 px text in 10 px rows, at most 30 glyphs (240 px) per row and 3 rows.
  - A 3 px tail toward the speaker.
- **Placement.**
  - The window's bottom sits 3 px above the speaker's top: the hull's top row, or the soldier's head anchor. The point is mapped with `world_to_hud` at whole pixels.
  - It is clamped 2 px inside the view and above the bottom band (y ≤ 326). It is moved down, under a top HUD window, or up, over the prompt, when it overlaps them.
  - An off-screen speaker puts the window at the nearest edge, and its tail points along that edge toward the speaker.
- **Time.** A call shows for `max(3, 1 + length / 15)` s. It is view timing only.
  - A new call from the same speaker replaces the old one.
  - Two speakers' windows that overlap stack: the later one moves above.
- **The budget test** lays every alert, give-up and squad line of every patrol, in both languages, into a window: none takes more than 3 rows. The longest today is 71 characters ("The inspection of the cay is under way. Cooperate with the authorities."), which is 3 rows.
- **Rejected:**
  - a backed `SpeechBubble` in the world, which the night tint and the Suave filter would recolour, and which scales with the world view;
  - `HudPanelThin`, which would make every call an avoid rect, so the interact prompt would jump.

### D7. The plated eye and its bar

- **New `ui_kit.json` icon piece `eye_open_plate`** (11×7, built by `ui.py` into `game/assets/art/ui/`):
  - a #222034 plate with a 1 px #222034 frame;
  - an almond eye in #ffedde across the inner 9×5;
  - a 3×3 #222034 iris in the middle.
- **The bar** is drawn in code under it: 11×3, sharing the plate's bottom row, so the mark is 11×9.
  - The frame is #222034 and the inner row is 9 px.
  - The fill is `round(9 × fraction)` px from the left: #ffedde below 0.5, #df7126 from 0.5, and `HudStyle.ALERT` from 0.75.
- **Placement.** It is placed like today's mark: centred over the head at whole pixels, its bottom 3 px above the head or the tag.
  - `BodyMarks.marker_rect` returns the 11×9 rect for an open eye, so the bubble and prompt stacking still hold.
  - The closed eye still wins over the open one.
  - The rope still wins over both.
- **Rejected:** keeping the iris fill. At 1x a 3×3 fill does not read as a meter (H6).

### D8. The warning chip

- **Two `ui_kit.json` icon pieces**, 9×7 with the outline:
  - `boat_chip_day`: a #000000 outline round a #9badb7 hull with a #ffffff cabin;
  - `boat_chip_night`: a #000000 outline round a #3f3f74 hull with a #fbf236 lamp.
- **`PatrolHorizon` draws the texture.**
  - The texture replaces the 5×2 and 3×2 rects, with the band's dark as a 1 px underlay.
  - The chip's top is at y 1. It is placed by the same bearing and then slid along the band to the nearer side clear of any top HUD window (the meters, phase, weather and teammates panels on show).
- **The blink.**
  - The chip shows its colours for 0.3 s and its outline only for 0.2 s, at 2 Hz.
  - In the last 5 s it blinks at 4 Hz (0.15 s and 0.1 s).
  - The time left is `horizon_warning_s` minus the boat's time in HORIZON from its synced `route_t` (`PatrolLoop.lap_time`), so peers agree to the frame they hold.
- **Rejected:** hiding the whole chip on the off beat. An empty band half the time reads worse than an outline.

### D9. Staging La captura

- **The node.** `CaptureStage` (`scenes/ui/capture_stage.gd`) is a HUD `Control` that `RunHud.bind` adds after the scene panel. It listens to `CaptureScene.scene_started` and `scene_ended`, which fire on every peer.
- **The letterbox.** Two #000000 bars, 28 px each, top and bottom. They slide in over 0.5 s at the start and out over 0.5 s at the end.
- **Hiding the HUD.** It calls a new `RunHud.set_staged(value)`, which hides, without closing input:
  - the meters, phase, weather, teammates, needle, note, watching panel and strip;
  - the prompt (its drawing only);
  - the marks, floats and patrol chips.

  The scene panel, the pause or run menu and the stage stay.
  - `set_screen_shown` is not reused. It also hides the scene panel and closes the HUD's input.
- **The framing (QG1 a).** The stage eases the local `Camera2D.offset` over 0.6 s.
  - The target is the patrol boat in a sight state nearest the local held body. While that boat's squad is out with a valid landing, the target is the midpoint of the boat and its landing cell.
  - The offset is clamped so the target stays inside the view.
  - It eases back to zero at the end. The travel then moves the body.
  - With no boat in sight (a crossing, or a boat gone), nothing moves.
  - The camera offset is client view state and is never synced.
- **Rejected:**
  - a stand-in boat (QG1 b), a prop that can contradict the real boat on screen;
  - a separate cutscene camera node. The player's own camera already follows the held body.

### D10. Portraits

- **Rodríguez.** His portrait is `NpcData.portrait`: `res://assets/art/portraits/rodriguez.png`, 32×32.
  - It is built by a new `tools/art/portraits.py` (reusing `creatures.py`'s sheet functions, so no shared tool changes) from `portraits.json` and the hand source `tools/art/fixes/portraits/rodriguez.png`.
  - It shows a tired man in his forties:
    - an olive cap with a visor;
    - a greying moustache, with bags under the eyes;
    - an olive collar with plain shoulder boards, no real insignia.
  - Palette colours only, rimmed #000000.
  - The new `portraits/` folder gets a `License.txt` own-work block.
  - Satire is the character's; he is fictional and resembles nobody.
- **A player's line.** The plea shows the speaker's composed look, frame 0 of `idle_down` (32×32). Its clothing is swapped to the speaker's slot row (`PaletteSwap.swap_rows`), and it is cached per look and slot.
- **The panel.** It becomes 440 px wide at x 100.
  - The portrait sits in a 36×36 `window_dark` frame at its left. The name and text are to its right, 392 px or 49 glyphs.
  - The card's bottom is at y 330, above the bottom bar.
  - `MAX_LINES` stays 7, and the fit test is re-run at the new width.

### D11. The advance cue

- **The arrow.**
  - When `revealed_chars()` reaches the text length, the panel shows the kit's `arrow_down` (7×4) and the interact label in `[%s]` from `InputLabels.label_for(&"interact", device, ...)`, at its bottom-right.
  - It blinks 0.3 s on and 0.2 s off.
  - It shows only where a press skips (`multiplayer.is_server()`: solo and the host).
- **On a client (QG3 a)** a 1 px #222034 bar under the text drains over the line's hold.
  - The hold is computed as the host does: `CaptureScene.hold_s` of the line's Spanish text, found by its id. It is right even when the client reads English.
- **The device** comes from `RunHud.device`, passed to the panel when it changes.

### D12. Line pacing (QG2 a)

- `CaptureScene.hold_s(text) = max(length / 40 + 2, 1 + length / 15)`, on the Spanish text, on the host.
- The act line (135 characters) goes from 5.4 s to 10 s. A 20-character line keeps 2.5 s.
- Skipping is unchanged.
- This is a rule change: `test_capture_scene.gd`'s `hold_s` test is rewritten first.

### D13. The confiscation report (QG4 a)

- **Host, in `CaptureScene._finish`.**
  - Before the outcome's effects, it records each party body's item counts by id. After them, it takes the difference.
  - For each peer whose player lost items, it calls `show_confiscated.rpc_id(peer, ids)`: a reliable call from the host, with ids in slot order and one entry per item kind. The host calls it locally for its own player.
  - The record is whatever the effects removed. So a data change to the outcome (another capability, or `TAKE_ITEM`) is reported without code, and a release reports nothing.
- **Every peer.**
  - It accepts the call only from the host, keeps at most 16 ids, and drops ids that are not items.
  - It stores the list and emits `confiscation_shown`.
  - `CaptureStage` writes "Te quitaron: " plus the item names in this peer's language, joined with ", ", into the HUD notice row for 5 s. It is cut with "…" at the row's width.
- **Order.** The call is sent after the travel's own message on the same reliable channel, so a client has landed when it shows the notice. The host shows it after its own relocation.
- **Rejected:**
  - a client diffing its own inventory, which would race the restart;
  - hard-wiring "fire sources", which would break on any future outcome.

### D14. Build order and PRs

1. **Docs** (this change), after the owner's answers.
2. **HUD:** D6, D7, D8.
3. **Sprites:** D2, D3, D4, D5, with the host-plus-client check on UDP 7803 that the squad and the dinghy draw on a client.
4. **La captura:** D9, D10, D11, D12, D13, with a host-plus-client run for the confiscation message.

Every PR carries before and after captures taken through the capture tools (`scenes/dev/capture_patrol.tscn`, `capture_la_captura.tscn`, `tests/manual/capture_squad.gd`), written under `UserTmp`, never to the user's settings.

## Risks / Trade-offs

- [Other sessions edit `run_hud.gd`/`.tscn`, `patrol_look.gd` (the sound pass's loudhailer), `patrol_horizon.gd` (the motor) and `tools/art` JSON] → Add nodes from `bind()` and keep the scene file untouched. Change `_speak` only where it emits. Append JSON entries at the end. Rebase on main before each PR.
- [`hair_cap`'s overlay must follow the head through every cell, including pose cells a soldier never uses] → Generate it from each cell's topmost opaque row by facing. Hold `test_every_shipped_body_outfit_and_hair_composes_with_closed_outlines` over the new parts.
- [A sprite hull 14 px off its sim position] → Within a tile. The light and the lamp agree. The collision and the chase are unaffected because they are sim.
- [The camera offset fights the shell's own camera fitting on travel] → Ease the offset back to zero on `scene_ended`, before the relocation lands. A test holds the offset at zero after the scene.
- [The notice arrives before the client's island is built] → Reliable messages keep their order on one channel, and a test on two processes checks the notice after landing. If the order ever breaks, the notice waits until the local body is back in play (`left_island` false).
- [Longer holds make co-op clients wait] → QG2 sets the pace. The host can still skip, and the drain bar tells a client how long is left.
- [The family check lands with different folders] → New actor sheets are black-rimmed. `portraits/` has no family, and it is rimmed black anyway.

## Migration Plan

- Art and art data are rebuilt with `python -I tools/art/compose.py outfit_uniform hair_cap`, `creatures.py`, `portraits.py` and `ui.py`, each with `--packs C:/Users/liann/src/90miles/game/assets`. Then `check.py`, and the import twice.
- There is no save format, and the confiscation message is new. An older client would ignore it, but host and client always run the same build.
- To roll back, revert the PR. The sim is untouched apart from `hold_s` and the report.
- Archive after `guardacostas-stealth` and `guardacostas-capture`. The two MODIFIED requirements need theirs in `openspec/specs/` first.

## Open Questions

None. The owner chose (a) for QG1–QG4 on 2026-11-23 (proposal.md).

## Build Notes

- **2026-11-23, gate.** The owner chose (a) for QG1–QG4. PR #105 (the outline family check) is merged; main is at 041e711. Each build PR branches from the main of its day, and the shared files are re-read there.
- **2026-11-23, HUD PR (groups 1–3), from main 041e711.** Re-read `run_hud.gd`/`.tscn`, `patrol_look.gd`, `patrol_horizon.gd` and the art JSON there; no other session had changed them. Before captures: `capture_patrol.tscn`, `capture_squad.gd` and `capture_la_captura.tscn` at 1x from main, plus the review's own captures (halved to 1x).
  - **Departures.**
    - The chip's off beat needs a hollow outline, so the kit has a third piece, `boat_chip_outline` (D8 named two).
    - The kit pieces are referred to by the theme as icons (`HudMarks/icons/eye_open_plate`, `HudHorizon/icons/boat_chip_*`), as `HudDigits/icons/atlas` is, so `check.py` finds them in use. The call window's `HudCall` variation shares the `hud_panel_thin` stylebox.
    - The bar's empty cells are the HUD track blue (#3f3f74), so a low meter still reads as a bar.
    - The chip's blink adds 0.1 ms to the clock before the beat test: a clock summed from 0.1 s ticks drifts just below a beat's edge.
    - Until the sprites PR, the call window points at the polygon hull's top (`PatrolLook.TOP_Y` = −9) and the placeholder soldier's cap (`SquadLook.SOLDIER_TOP_Y` = −13).
    - `RunHud.top_window_rects()` (panels whose top is above y 20) feeds the chip; `RunHud.call_avoid_rects()` (every panel plus the prompt) feeds the call windows.
  - **Measured.** The longest shipped call, 71 characters, wraps to 3 rows; every call of `patrol_boat.tres` (14 lines in two languages) fits. The plated eye is 11×9 and the chips 9×7.
- **2026-11-23, sprites PR (groups 4–6), stacked on the HUD PR.**
  - **Departures.**
    - The launch's sheet is 384×48 (four 96×48 cells in one row); D3 said 192×48, which holds only two. The lamp is at (49, 9) in every cell, and the hull bobs under it in `idle`.
    - The dinghy's keel middle is (14, 11) in its 32×16 cell.
    - `GuardacostasArt` keeps `hull_cell`, `dinghy_cell` and `dinghy_foot_px` instead of `hull_foot_px` and `soldier_foot_px`: a soldier's feet use the player's own `PlayerPose.OFFSET`, and the hull is anchored on its lamp.
    - The cone's two rims take the lower of the two smoothsteps, not their product, so the wedge's far corners are drawn at half strength too (D4's "every lit cell at half or more").
    - Call windows also keep clear of the local player's figure and its mark (`RunHud.local_figure_rect`): a squad landing beside the player covered their head in the first capture. A rect whose middle is above y 120 pushes a window down, any other pushes it up.
    - `outfit_uniform` keeps Outfit5's shoes, recoloured to #222034 boots; `hair_cap` is band 7 with a generated overlay (crown, a 2-row visor to the front and side, crown only from behind). The cap reads tall: rough first, to be refined in a later pass.
  - **Measured.** Hull frames 86–94 × 36–37 opaque against the raft's 64×32 frame; dinghy 24×13 rowing, 28×14 beached.
  - **Two-process run on UDP 7803** (`tests/manual/guardacostas_art_run.gd`, headless): host and client both draw the launch at the docked boat, the dinghy beached on the landing cell, three soldiers in `soldada`, `soldado_1` and `soldado_2`, and the landing call in a call window; 0 engine errors on either peer.
- **2026-11-24, La captura PR (groups 7–9), stacked on the sprites PR, branch `claude/art-guardacostas-la-captura`.**
  - **Departures.**
    - The card has a cue row under the text: the arrow and "[E]" at its right, the client's drain bar along it. In the first capture the key sat on the act's last line. The card is one row taller (the act's card is 58 px).
    - The kit's arrow is cream; on the light note card it is tinted the card text's dark (#222034).
    - The stage puts the framed point 30 px above the view's centre (`CaptureStage.FRAME_LIFT_PX`), in the open space between the top bar and the panel; centred, the boat sat behind the panel.
    - `RunHud.set_staged` hides by transparency (`modulate.a`), so the panels' own per-frame refreshes and their input stay as they are.
    - After main brought hud-clarity (#120: the objective row, the clock, the Calor and Sangrando rows, the site arrow), the staging hides every piece of the HUD but a keep-list (the scene panel, the stage, the run menu and the quick-chat wheel) instead of a list of names, and gives each piece back the alpha it had; a piece a later change adds hides too. Tested solo, host plus client, and in the two-process run (host and client 13 of 13).
    - A plea's portrait is the whole 32×32 `idle_down` frame (the figure, head to feet), its key ramp swapped to the slot's row.
    - The host keeps `CaptureScene.last_report` (peer → ids) for the record; the notice text is `hud_text.tres`'s `confiscated` line ("Te quitaron: %s" / "They took: %s").
    - `tools/art/portraits.py` imports `creatures.py`'s and `rim.py`'s helpers and changes no shared tool.
  - **Measured.** The act (`captura_act_singular_acta`) holds 10 s instead of 5.4 s; the longest scene line, a Médico plea, holds 11.5 s. Every la_captura line fits 7 rows at 49 glyphs in both languages.
  - **Two-process run on UDP 7803, extended:** the host (a fosforera, 40 morale) and the client (a coconut) are caught together; both stage the scene, the client sees the drain bar over the Spanish hold and no arrow, and after landing only the host's notice reads "Te quitaron: Fosforera". Host 11 of 11, client 11 of 11, 0 engine errors.
