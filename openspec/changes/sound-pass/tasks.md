# Tasks

The owner chose Q1 A and Q2 B on 2026-11-23 (design "Owner decisions"):
- Q1 A: one "Volumen" row, 0 to 100 %, default 80 %. This change ships the key and the API; run-menu adds the row.
- Q2 B: CC0 recordings for the sea, wind and thunder, after the owner approves each file. Until then the generated three are placeholders (group 9).

The commands below run from the repo root, using the Godot 4.7.2 console binary:
- "Import" is `godot --headless --path game --import`, run twice on a fresh checkout.
- "Smoke" is `godot --headless --path game -s res://tests/smoke.gd`.
- "GUT" is `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.
- "Audio tools" is `python -I -m unittest discover -s tools/audio -p 'test_*.py'`.

## 1. The generator and the fifteen files (audio "Generated sounds are reproducible and credited")

- [x] 1.1 Tests first: write `tools/audio/test_sfx.py`. It covers:
  - each voice (square with duty, triangle, sine, noise and brown noise) has the expected period or spectrum shape;
  - the envelope's stages;
  - a sweep moves the pitch the right way;
  - the low-pass lowers high-frequency energy;
  - a seeded part renders byte-identically twice;
  - a WAV round trip (22 050 Hz, 16-bit, mono) through the standard `wave` module;
  - for every sound in `sounds.json`: it is not silent (RMS over a floor), never clips (peak under 0.99), has its length, one-shots end in silence, and, for loops, the seam holds: the step from the last sample to the first is no bigger than the loop's own 99.9th-percentile step. The tracked WAVs match a fresh render, byte for byte on the machine that wrote them and within one step of the last bit elsewhere (another maths library).

  Verify: Audio tools fails first.
- [x] 1.2 Write `tools/audio/sfx.py` (standard library only) and `tools/audio/sounds.json` with the 15 sounds (design D1). Running `python -I tools/audio/sfx.py` writes `game/assets/audio/sfx/*.wav` and `game/assets/audio/loops/*.wav`. Verify: Audio tools passes, and a second run leaves `git status` clean.
- [x] 1.3 Add `License.txt` to both folders in the "Work:" block format (design D2). Add a `CREDITS.md` row and an `ASSETS.md` row naming the folders and the generator. Add the Audio tools line to `.github/workflows/ci.yml` beside `tools/art`.
- [x] 1.4 Import twice. Commit the `.import` files with `edit/loop_mode=2` for the four loops. Verify: Import, Smoke and GUT pass.

## 2. The bank (audio "Sounds are data")

- [x] 2.1 Tests first: write `game/tests/unit/test_sound_bank.gd` (pure). It covers:
  - the 15 ids, unique;
  - every stream loads from `res://assets/audio/`;
  - the loops have `loop_mode` other than disabled, and the one-shots disabled;
  - `thirst_low_at` equals `MeterBar.CRITICAL_LOW`;
  - no tracked path names `audio/ambience/`;
  - an entry without a stream is reported by id (a fixture bank).

  Also write `test_sound_credits.gd`: every WAV under both folders is named in its `License.txt` and in `CREDITS.md`, with a fixture folder that fails.
- [x] 2.2 Write `game/scripts/audio/sound_data.gd` (`SoundData`) and `sound_bank.gd` (`SoundBank`, with `entry(id)` and `problems()`), and `game/resources/sound_bank.tres` with every number in design D3. Verify: Import, Smoke and GUT pass.

## 3. AudioManager (audio "Playing a one-shot by id", "Loops are set by level")

- [x] 3.1 Tests first: write `game/tests/unit/test_audio_manager.gd` against a fresh AudioManager instance with a fixture bank and a fake clock. It covers:
  - `&""` and an unknown id are silent and do not fail, and the unknown id warns once;
  - three requests inside the repeat interval emit `sfx_played` once;
  - pitch stays within the spread over 200 plays;
  - `db_offset` lowers the voice;
  - a loop set to 1 fades up over `fade_s`, holds, and stops at 0;
  - `stop_loops()` empties the loops;
  - `set_volume(0.3)` sets the Master bus volume to `linear_to_db(0.3)`;
  - the two buses exist once, after `_ready` runs twice.

  Change `test_core_services.gd:97` from "plays nothing yet" to "plays through the bank": `play_sfx(&"hurt_hit")` emits `sfx_played`, and `play_sfx(&"")` does not.
- [x] 3.2 Rewrite `audio_manager.gd` to design D4. Verify: Import, Smoke and GUT pass, and the smoke run's exit leak count is no higher than on main.

## 4. Cue logic, pure (audio "Pick-up cue", "Low-thirst cue", "Ambience follows place, time and weather", "Raft hit and arrival", "The patrol motor swells over the horizon warning", "The patrol motor follows the boat in sight", "Loudhailer")

- [x] 4.1 Tests first: write `game/tests/unit/test_audio_cues.gd` (pure; 1 player, offline). It covers:
  - `ThresholdCue`: it fires on the fall to 25, not again at 10, re-arms above 30, does not fire when seeded at 20, and arms after a rise;
  - `InventoryGain`: a rise fires; a fall, a use spent, an equal state and the first seed do not;
  - `ChangeWatch` (one class for vessel integrity and alert serials, keyed by instance id): a fall reads negative and a rise positive; an equal resync, a new vessel or boat, and the first seed read 0; forgotten keys seed again;
  - `PatrolSwell`:
    - HORIZON at 5 s is quieter than at 15 s, and at the warning's end equals `motor_high_db`;
    - in sight it is loudest within the near distance and at `motor_far_db` at the far distance;
    - it is 0 beyond twice the far distance, and AWAY and DOCKED are 0;
    - the warning is read from the boat's data;
  - `RunAmbience`: island day, island night, a crossing, and a squall on an island and at sea.
- [x] 4.2 Write `game/scripts/audio/threshold_cue.gd`, `inventory_gain.gd`, `change_watch.gd`, `patrol_swell.gd` and `run_ambience.gd`. Verify: Import, Smoke and GUT pass.

## 5. RunSounds in a solo run (audio, all cue requirements, "Audio never changes the simulation", "Loops end with the run")

- [ ] 5.1 Tests first: write `game/tests/unit/test_sound_pass_solo.gd` (exactly 1 player, offline, `UserTmp.path()` for any settings file). It records `sfx_played` and `loop_level_set` and covers every case in design D8 "Solo". Write `test_sound_sim_invariance.gd`: the same 600 frames with and without `RunSounds`, through a pick-up, a crab pinch and a patrol warning, end in the same state hash.
- [ ] 5.2 Write `game/scripts/audio/run_sounds.gd` (design D5). In `game_shell._enter_run`, attach it to the HUD with the needle. Verify: the shell's existing run tests still pass. Import, Smoke and GUT pass.
- [ ] 5.3 Run the game windowed through the Godot MCP and listen to a solo run: the sea at start, a pick-up, a crab, a patrol warning, a squall and a crossing to arrival. Read the errors: none new. Note any level to retune in `sound_bank.tres` or `sounds.json`.

## 6. Volume (audio "Volume level"; owner Q1)

- [ ] 6.1 Tests first: extend the settings tests with the volume default (8), a round trip through a `UserTmp.path()` file, and malformed values (a string, -1, 11) falling back to 8. Write a shell test that the stored level reaches `AudioManager.volume()` at start.
- [ ] 6.2 Add `GameSettings.volume` and apply it in `GameShell`. The Ajustes row is run-menu's (Q1 A): the coordinator passes it the key, the steps (0 to 10, shown as 0 to 100 %) and `AudioManager.set_volume(volume / 10.0)`. Verify: Import, Smoke and GUT pass.

## 7. Co-op (audio "Own events are heard only by their player", "World events are heard by every peer")

- [ ] 7.1 Tests first: write `game/tests/unit/test_sound_pass_net.gd` (in-process host and client, the `test_damage_feedback_net` pattern). It covers:
  - the host's pick-up plays on the host only, and the client's on the client only;
  - a patrol HORIZON raises `patrol_motor` on both;
  - an alert plays `loudhailer` on both;
  - a squall plays `thunder` on both;
  - a rejoining client with a full bag hears no `pickup`.
- [ ] 7.2 Write `game/tests/manual/sound_pass_run.gd`: two processes on UDP 7802, each logging the ids it played. It asserts:
  - each peer's own events;
  - the shared world events;
  - that the client never logs the host's `pickup` or `hurt_hit`.

  Run it 3 times. Verify: Import, Smoke and GUT pass.

## 8. Docs

- [ ] 8.1 Add a short "Sound" section to `docs/GAME_DESIGN.md`: the cue list, own against world events, and "sound never carries information alone". Tick the `sound-pass` line in `TASKS.md`. Record the owner's answers in design "Owner decisions". Verify: `openspec validate sound-pass --strict`, and Import, Smoke and GUT pass.

## 9. CC0 recordings for the sea, wind and thunder (owner Q2 B)

- [ ] 9.1 Send the coordinator exact CC0 candidates for `sea`, `wind` and `thunder`: file name, source page, author, licence (CC0 only), size and format, two per sound where possible. Download nothing until the owner approves a file.
- [ ] 9.2 Give `SoundData` a `generated: bool` field (default true). The bank and credits tests skip the rebuild check for a recording and ask its `License.txt` block for author, licence and source instead. Keep the three generated placeholders until approved files arrive.
- [ ] 9.3 After approval, per file: copy it into the right folder, trim and loop it (seam crossfade, mono, 22 050 Hz), add its `.import` and its `License.txt` block, set its bank entry, and add its `CREDITS.md` row. Verify: Import, Smoke and GUT pass. This may land as its own small PR after the main one.
