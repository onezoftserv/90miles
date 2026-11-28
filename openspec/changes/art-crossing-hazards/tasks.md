# Tasks

## 0. Gate

- [ ] 0.1 Wait until art-mood-pass group 5 (#129) has merged into `main`, and branch from it. Re-read its `CrossingHazards` (`piece_look`, `shown_beats`, `shown_leaks`) and `CrossingArt`.
- [ ] 0.2 Wait for the owner's answer to QH1 (design.md "Owner decisions"). The tasks below are written for (a). If the answer is (b) or (c), update the spec's width rule and D1 first.

## 1. Tests first

- [ ] 1.1 In `test_crossing_art.gd`, write these and see them fail:
  - **The 1-player test:** a solo raft crossing whose plan brings a rock in lane 2 and debris in lane −1.
    - Once both are on the sea, `CrossingArt.hazard_look` gives each its own texture (`sea/rock.png`, `sea/debris.png`, neither the flotsam plank), centred on `beat_center`.
    - Each outlined body is exactly `rock_width_tiles` × 16 and `debris_width_tiles` × 16 px wide.
    - Its collar sits at its waterline, reaches at most `hazard_collar_px` past the body, and uses no #ffffff.
  - **The leak, 1 player:** a solo raft crossing with an open leak draws its jet from `fx/leak_spurt.png` bottom-centre on `leak_position`, over the deck and under the rider (`DrawOrder`).
  - **Frames:** the collar's and the jet's frames step with `elapsed_s` at `hazard_fps`, and two leaks at one time differ by their index offset.
  - **Contrast:** the rock's and the debris's outline rings and each surf frame reach 3:1 on the deep and on the shallows (`ArtChecks.check_water_contrast`).
  - **Host and client:** in the existing two-peer raft test, with a rock on the sea and an open leak, the client's hazard and spurt looks equal the host's at the client's plan time.
- [ ] 1.2 In `test_mood.py`, grow the tracked list by the five pieces. Add a recipe test: a surf or jet source holding #ffffff is refused.
- [ ] 1.3 `test_art_sim_invariance.gd` and `test_draw_order.gd` keep passing. Add the hazards' z −30 and the spurts' z −19 to the crossing's order test if they are not there yet.

## 2. The art

- [ ] 2.1 Draw the hand sources in `tools/art/fixes/mood/`: `rock.png` (32×16), `rock_surf.png` (3 frames of 36×6), `debris.png` (16×10), `debris_surf.png` (2 frames of 18×4) and `leak_spurt.png` (3 frames of 9×12), as design D2–D4 describe.
- [ ] 2.2 Add them to `mood_fx.json`: the bodies with `"outline": "#000000"`, the surfs and the jet with their colour sets. Build with `python -I tools/art/mood.py`. Add the own-work blocks to `sea/License.txt`, `fx/License.txt` and the fixes' licence. Run `check.py` on the art and the fixes.

## 3. The drawing

- [ ] 3.1 Add `hazard_fps` and `hazard_collar_px` to `ArtTuning` and `art_tuning.tres`. Add `hazard_frame`, `hazard_look` and `spurt_look` to `CrossingArt`.
- [ ] 3.2 Replace `CrossingHazards._draw_rock`, `_draw_debris` and `_draw_spurts` with texture draws that consume those looks. Name the five textures on `Hazards` in `crossing.tscn`. Keep `shown_beats`, `shown_leaks`, the z values and the flotsam drawing as they are.
- [ ] 3.3 Verify 1.1–1.3, `test_crossing_hazards.gd`, `test_crossing_leaks.gd`, `test_crossing_leaks_net.gd`, `test_crossing_flotsam.gd` and the Python art tests. Run the import twice, smoke and GUT.

## 4. Captures

- [ ] 4.1 Extend `tests/manual/capture_crossing.tscn` with a rock, debris and an open leak. Shoot them in one off-screen launch (`--position -32000,-32000 --resolution 640x360`), per the owner's 2026-11-23 rule. Compare with the placeholders shot from main before the build, and read the run log.

## 5. Integration

- [ ] 5.1 Rebuild with `mood.py` to scratch and `cmp` each sheet against the tracked file. Run `check.py`, the Python art tests, the import twice, smoke and GUT. All must be clean.
- [ ] 5.2 Co-op check, since the look reads synced state: run host and client locally, headless, through a raft crossing with a rock, debris and a leak, and read both logs for `ERROR:` lines.
- [ ] 5.3 Update `TASKS.md` and this design's build notes, and run `openspec validate art-crossing-hazards --strict`.

## Workflow follow-up

- Open one PR for the build into `main`, and send the coordinating session its link with the before and after captures.
- Archive the change after the owner has seen the captures (not in that PR).
