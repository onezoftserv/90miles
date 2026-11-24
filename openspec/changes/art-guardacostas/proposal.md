# Proposal

## Why

The coast guard is the game's signature scene, and it is still programmer art. The Fable review of 2026-11-22 (main 8c58c16) made it priority 7 ("make the coast guard readable") and priority 8 ("stage La captura"):

- **A4 (+A14):** the soldiers are three olive boxes, the patrol boat is smaller than the player, the dinghy is a brown rectangle, and the searchlight is a hard wedge (`squad_ashore_x3.png`, `patrol_boat_day.png`).
- **H4:** the loudhailer and the squad's calls are unbacked world text, unreadable at 1x (`patrol_alert_night.png`).
- **H5 (visual part):** the only warning of a patrol is a 5×2 px grey mark (`patrol_horizon_hull_day_top_x4.png`).
- **H6:** the open eye is 7×5 px, and its fill does not read as a meter (`patrol_searchlight_night.png`).
- **MN-02 (+MN-11):** La captura is a text card over an empty beach. It has no speaker, no advance cue, and a long line stays too briefly (`la_captura_line1.png`, `la_captura_line3.png`).
- **H17 (capture part):** nothing says what was confiscated (`la_captura_after.png`).

The owner chose "Yes, now" for an `art-guardacostas` change on 2026-11-23.

## What Changes

**Sprites (art only).** These are built through the `tools/art/` recipes and hand sources with `png.py`. They use the master palette and are outlined in black (art-prop-polish D1).
- **Soldiers.** Each soldier is a MetroCity person recoloured into an olive uniform with boots and a patrol cap. There are three looks, told apart by skin and build, and each soldier keeps one look. Soldiers walk with the player's walk frames and face the way they move.
- **The patrol boat.** The hull is wider and longer than the raft's 64×32 frame. It is a grey launch with a cabin, a plain stripe and a lamp on the roof. It is seen side-on and mirrored by heading, as the raft and the car are. The searchlight starts at the lamp.
- **The dinghy.** It is a small boat with oars: it rows in and out, and it lies on the landing beach while the squad is ashore. It sorts by its own position on the beach.
- **The searchlight cone.** It is softened, and still truthful: its feathered rim is half bright on the true edge of the lit cells, so every lit cell shows the light and no unlit cell shows more than a faint fringe.

**HUD.**
- **Calls in a window.** Loudhailer lines and squad calls show in a small thin window (the HUD kit's `window_thin`), in the HUD's 8 px font, over the speaker. Each window is at most 30 glyphs wide and 3 lines tall, and stays inside the view. It shows long enough to read. Quick chat and signs keep their speech bubble.
- **The spot eye.** The open eye becomes an 11×7 mark on a dark plate. Under it, a fill bar shows the spot meter, and it warms in colour as the meter nears 1. The closed eye and the rope mark do not change.
- **The patrol warning chip.** During each boat's 20 s horizon warning, a 9×7 outlined boat chip blinks on the horizon band. It is a lit hull at night and a grey hull by day, and it blinks faster in the last 5 s. The sound-pass change adds the motor.

**La captura staging.**
- **Letterbox and HUD.** Black bars slide in when the scene starts, and the run HUD hides everything but the scene. That means the meters, phase, strip, marks and chips.
- **The speaker.** The panel shows the speaker's 32×32 portrait. Rodríguez's comes from his NPC data. A player's plea shows that player's own figure.
- **The boat.** Each peer's view frames the boat that made the capture, with its beached dinghy and squad when they are ashore (QG1).
- **The advance arrow.** A blinking arrow with the interact glyph shows once the line is fully revealed, on every peer whose press can skip the line (QG3).
- **Closing notice.** After the scene, each peer names what its own player lost, for example "Te quitaron: Fosforera". It shows nothing when nothing was taken (QG4).

**Behaviour, declared as such.** Two items change rules and are not art:
- **Line pacing.** A line now stays at least 1 s plus 1 s per 15 characters, and never less than its reveal plus 2 s (QG2). The host still paces every line, and solo and the host can still skip.
- **The confiscation report.** The host records what the outcome's effects actually removed from each player and sends each peer its own list as item ids. This is a new reliable host message, so it gets the host-and-client run.

**Unchanged.** Detection, the spot meter, chase, squad, capture rules, outcomes and every synced field stay as they are. The cue nodes only read state.

## Owner decisions (answered 2026-11-23)

The owner chose option (a) for all four on 2026-11-23, and the artifacts follow it. The other options are kept for the record.

- **QG1:** (a), frame the real boat, and its dinghy and squad when they are ashore.
- **QG2:** (a), 1 s plus 1 s per 15 characters, never less than today's hold.
- **QG3:** (a), the arrow with the interact glyph on the host and in solo; a client sees a 1 px bar that drains.
- **QG4:** (a), "Te quitaron: …" on the HUD notice row for 5 s after landing, and nothing on a release.

The options as they were asked:

- **QG1. The boat at the shore.**
  - (a) Frame the real boat: each peer's view eases to the boat that made the capture, and to its landing when its squad is ashore. A capture with no boat in sight keeps the view.
  - (b) A stand-in boat moored at the shore nearest the party, drawn only for the scene.
  - (c) No world staging: only the letterbox, the portrait and the panel.
- **QG2. Line pacing.**
  - (a) 1 s plus 15 characters a second, at least reveal plus 2 s. The 135-character act holds 10 s instead of 5.4 s.
  - (b) 12 characters a second (12.3 s).
  - (c) Keep today's 40 characters a second plus 2 s.
- **QG3. A client's cue.** Only the host can skip a line.
  - (a) The arrow shows on the host and in solo. A client sees a 1 px bar that drains over the line's hold.
  - (b) The arrow shows on every peer, and a client's press asks the host to advance (a new intent).
  - (c) The arrow shows on the host and in solo, and a client sees nothing.
- **QG4. Where the notice shows.**
  - (a) After landing, on the HUD's notice row for 5 s.
  - (b) As a last card in the scene panel before the travel.
  - (c) Both.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `guardacostas-stealth`:
  - **Modified: Patrol cues.** The warning chip, the plated eye with its bar, and the loudhailer in a call window.
  - **Modified: Capture cues.** Squad calls in call windows.
  - **Added:** Call windows, Capture staging, Capture advance cue, Capture line pacing and Confiscation notice. "The capture scene" itself is unchanged.

  Neither modified requirement is in `openspec/specs/` yet. They arrive when `guardacostas-stealth` and then `guardacostas-capture` are archived, so this change archives after both.
- `art-pass`: three requirements are added: Shore soldier look, Patrol boat and dinghy look, and Searchlight edge.

## Impact

- **Art.**
  - New hand sources: `tools/art/fixes/` (the cap overlay), `tools/art/fixes/creatures/` (the hull and the dinghy) and `tools/art/fixes/portraits/` (Rodríguez).
  - Recipe entries: `look_parts.json` (`outfit_uniform`, `hair_cap`) and `creature_sheets.json` (`patrol_boat`, `dinghy`).
  - A small new `tools/art/portraits.py` writes `game/assets/art/portraits/`.
  - New tracked art: `characters/parts/outfit_uniform.*` and `hair_cap.*`, `creatures/patrol_boat.*` and `dinghy.*`, `portraits/rodriguez.*`, `characters/looks/soldado_*.tres`, and `creatures/guardacostas_art.tres` (a new `GuardacostasArt` resource).
- **Code.**
  - Drawing: `patrol_look.gd`, `squad_look.gd`, a new `dinghy_look.gd`, `patrol_cone.gd` and `creature_art.gd` (the "until their art exists" exemptions go).
  - The HUD: `body_marks.gd`, `patrol_horizon.gd`, a new `call_windows.gd`, `scene_panel.gd`, a new `capture_stage.gd`, and `run_hud.gd` (nodes added from `bind()`).
  - Rules: `coop_session.gd` (a `call_shown` signal beside `show_bubble`), and `capture_scene.gd` (`hold_s`, the confiscation record and its RPC).
  - Data: `rodriguez.tres` (portrait) and `hud_text.tres`.
- **Docs.** `docs/GAME_DESIGN.md` §9 "Guardacostas and stealth" ("a minimal scene panel" becomes a staged scene), and `docs/ASSETS.md` (portraits folder, coast guard rows).
- **Tests.** Rewrite first the tests that pin today's look:
  - `test_patrol_cues.gd`: the 5×2 hull and 3×2 light, the polygon hull, and the cone's wedge;
  - `test_capture_cues.gd`: the soldier and dinghy placeholders, and calls as bubbles;
  - `test_body_look.gd`'s open-eye size;
  - `test_capture_scene.gd`'s `hold_s`;
  - `test_look_parts.gd`'s shipped-part list.
- **Networking.** One new reliable host-to-peer message, the confiscation list. The host-plus-client run uses UDP 7803.
- **Other sessions.**
  - Hud-clarity and run-menu also touch `run_hud.gd`/`.tscn`.
  - Sound-pass touches `patrol_look.gd`'s `_speak` and the horizon warning.
  - Art-waves edits `tools/art/` JSON.
  - New nodes are added from `bind()` and new files are preferred, to keep merges small.
