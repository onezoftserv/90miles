# Proposal

## Why

The game is silent: there is no audio file in `game/`, and `AudioManager.play_sfx` is a no-op stub (Fable review 2026-11-22, finding G5, priority 5). The patrol's only warning is a 5×2 px mark on the horizon band, which nobody notices (H5). On 2026-11-23 the owner chose a small pass before the first playtest: about 15 effects and loops, and no music.

## What Changes

**Sounds we make ourselves (no downloads).**
- A small generator in `tools/audio/` synthesizes every sound in a retro GBA style (square, triangle, noise and sine voices with envelopes, sweeps, filters and tremolo). It writes 16-bit mono WAV files with the Python standard library only.
- Each sound's parameters are data (`tools/audio/sounds.json`), so any sound can be regenerated and tuned.
- The WAVs are tracked in `game/assets/audio/sfx/` and `game/assets/audio/loops/` with a `License.txt` (own work). Their origin is recorded in `game/assets/CREDITS.md` and `docs/ASSETS.md`.
- Any sound can later be swapped for a CC0 recording as a data-only change (a bank entry and a credits line).

**Fifteen sounds:**
- 4 loops: `sea`, `wind`, `night` and `patrol_motor`;
- 11 one-shots: `pickup`, `hurt_hit`, `hurt_big`, `hurt_drain`, `use_done`, `thirst_low`, `raft_hit`, `loudhailer`, `thunder`, `arrival` and `compass_rattle`.

**Sounds are data.** A `SoundBank` resource (`game/resources/sound_bank.tres`) maps each id to its file, bus, level, loop flag, pitch jitter and repeat guard. The cue thresholds (the motor swell, the low-thirst step, the thunder interval) live in the same bank. Adding or replacing a sound edits only data.

**AudioManager becomes real but stays thin.**
- It plays a one-shot by id, sets a loop's level by id and stops all loops.
- It holds the two buses (Efectos and Ambiente) and a master volume.
- An unknown or empty id stays a silent no-op.
- It reports every request on a signal, so tests check what was asked for, never what an audio device did.

**Cues from state every peer already has (`RunSounds`, one per peer, client-side only).**
- **Own events** (only the peer whose player it is hears them):
  - pick-up: something added to your bag;
  - the four existing hurt and use hooks: hurt_hit, hurt_big, hurt_drain, use_done;
  - low thirst: your thirst falls to the step where the Sed bar starts to pulse;
  - the compass rattle.
- **World events** (every peer hears them, read from the host's synced state):
  - the sea, the wind and the night;
  - thunder: when a squall is warned (far), when it breaks, and now and then while it lasts;
  - the patrol motor, which swells over the boat's horizon warning (20 s by data) and then follows the boat's distance while it is in sight;
  - the loudhailer on each patrol alert;
  - a hit on your vessel in a crossing (rock, debris, shark or squall);
  - arrival on the next island.
- Nothing new is synced and no RPC is added. Audio never changes the simulation, and a test proves it.

**A volume setting.** AudioManager gets a volume API and a default level, and `GameSettings` keeps the level. The Ajustes row's shape is an owner decision (design "Owner decisions"); the run-menu session owns the Ajustes screen.

## Capabilities

### New Capabilities
- `audio`: what the game plays and when. It covers:
  - the sound bank as data;
  - AudioManager's playback contract;
  - own-event and world-event cues on each peer;
  - the patrol warning's motor swell;
  - loops ending with the run;
  - the volume level;
  - audio never changing the simulation;
  - reproducible generated sounds with recorded origin.

### Modified Capabilities
None. The patrol cue on the HUD (guardacostas-stealth "Patrol cues") and the Ajustes screen (ui-shell "Settings") are left as they are. Both are being changed by other sessions right now (coast guard art, HUD clarity, run menu). The audio requirements only add to them, so the deltas cannot clash when archived.

## Impact

**New code:**
- `tools/audio/` (`sfx.py`, `sounds.json`, `test_sfx.py`);
- `game/assets/audio/sfx/` and `game/assets/audio/loops/` (WAVs, `.import` files and `License.txt`);
- `game/scripts/audio/` (`sound_data.gd`, `sound_bank.gd`, `run_sounds.gd` and small pure cue helpers);
- `game/resources/sound_bank.tres`;
- the tests.

**Edited:**
- `audio_manager.gd`, from a stub to the playback contract;
- `game_shell.gd`: about three lines that attach `RunSounds` beside the HUD when a run starts (it is freed with the HUD);
- `game_settings.gd`: one volume key;
- `test_core_services.gd`: the "plays nothing yet" assertion becomes "plays through the bank";
- `.github/workflows/ci.yml`: one line running `tools/audio` tests;
- `docs/ASSETS.md`, `game/assets/CREDITS.md` and `TASKS.md`.

**Not touched:**
- `player.tscn`'s synchronizer, every creature, crossing and meter script, and every item `.tres`;
- `run_hud.gd`, `patrol_horizon.gd`, `patrol_look.gd`, `meters_hud.gd` and `settings_screen.gd`. They are other sessions' files; the existing `MetersHud._cue` hook already calls AudioManager.

**Downloads:** none. The git-ignored `game/assets/audio/ambience/` folder stays unused, as `test_downloaded_asset_refs.gd` requires.
