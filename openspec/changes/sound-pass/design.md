# Design

## Context

**Audio today (surveyed 2026-11-23 on main 122e9bf)**
- `AudioManager` is one function, `play_sfx(_id)`, that does nothing.
- `MetersHud._cue(id)` already calls it for `hurt_hit`, `hurt_big`, `hurt_drain` and `use_done` (damage-feedback D7), then emits `hurt_cued`.
  - `hurt_drain` fires once when a drain starts, not every frame.
  - The cue follows the body the meters panel shows: the player's own body, or the teammate watched while dead.
- `CompassNeedle.rattled` exists with nothing connected. Its comment says it is "a cue for AudioManager when its sound exists".
- `test_core_services.gd:94-97` asserts `play_sfx` exists, accepts `&""`, and that AudioManager has no children ("plays nothing yet").
- There is no audio file under `game/`.
- `docs/ASSETS.md` plans downloaded ambience in `game/assets/audio/ambience/`. That folder is git-ignored, and `test_downloaded_asset_refs.gd` fails if any tracked file names it.

**How each cue's state reaches each peer.** The host is authoritative, so most gameplay signals fire only on the host. Every cue here comes from state the listening peer already holds.

| Cue | Host | What a client already has | Read from |
|---|---|---|---|
| hurt_hit, hurt_big, hurt_drain, use_done | MetersHud watches its body's meters | the same watch, on replicated meters | existing `MetersHud._cue` |
| pickup | `WorldItem._on_interacted` → `Inventory.add` (`taken` fires only when the stack empties, host only) | `Inventory.from_net` → `changed` | local body's `Inventory.changed`, counts compared |
| thirst_low | `SurvivalMeters.thirst` | replicated `thirst` | local body's meters |
| compass_rattle | `CompassNeedle.rattled` (HUD, per peer) | the same | `RunHud.needle.rattled` |
| sea, wind, night | `WeatherManager` sky | `WeatherManager.follow()` plus `CoopSession.receive_sky` | `WeatherManager.phase()` and `weather_id()`, polled |
| thunder | `WeatherCycle.weather_warned` / `weather_changed` | the same signals re-emitted from the received sky (`weather_cycle.gd:131`) | polled `weather_id()`; the warning from the `weather_warned` signal |
| patrol_motor | `PatrolRoute._publish` writes `route_t`, `state_id` | synced `route_t`, `state_id`, `position`; `PatrolView.step_client` runs `route_t` on between syncs | each patrol `Creature` under `session.entities` |
| loudhailer | `alert_serial += 1` (`patrol_route.gd:181, 293, 327`) | synced `alert_serial` (what `patrol_look.gd` shows its speech bubble from) | per-boat serial watch |
| raft_hit | `Crossing.hit_vessel` / `hit_every_vessel` | `integrity.value` via `receive_state` (on change and every second), boards per rider | `crossing.vessel_of(local_peer).value`, drops |
| arrival | `Crossing.ended` | `receive_result` → `ended` | the crossing's `ended`, local rider alive |

**Other sessions' files, avoided.**
- HUD clarity: `run_hud.gd`, `patrol_horizon.gd`, `meters_hud.gd`.
- Coast guard art: `patrol_look.gd`.
- Run menu: `settings_screen.gd` and the Ajustes screen.
- Island pressure: the meters and their tuning.
- The crossing session: `crossing.gd`.

This change reads those classes' public state and edits none of them.

## Goals / Non-Goals

**Goals**
- Fifteen sounds that fit the GBA tropic look: small, chirpy, a little crunchy.
- Every sound rebuilt from data in the repository.
- The patrol warning heard before it is seen, on every peer.
- A sound layer that cannot touch the simulation and is easy to swap.

**Non-Goals**
- Music (owner, 2026-11-23).
- Menu and button sounds.
- Voices and speech: the loudhailer is a megaphone squawk, never words.
- Stereo panning by bearing, positional 2D audio, reverb and ducking.
- New HUD art for the warning: HUD clarity owns the boat chip.

## Decisions

### D1. Sounds are generated, not downloaded
`tools/audio/sfx.py` is a small sfxr-style synthesizer using the standard library only. Its parts:
- Voices: square with duty, triangle, sine, and seeded white or brown noise.
- An attack, decay, sustain and release envelope.
- Frequency sweeps and slides, arpeggio steps, vibrato and tremolo.
- A one-pole low-pass and high-pass filter, a bit-crush, and layered parts with offsets.
- Output: 22 050 Hz 16-bit mono WAV.

`tools/audio/sounds.json` holds each sound's parameters. The generator is deterministic: noise comes from a `random.Random(seed)` per part, so a rebuild is byte-identical.

A loop is made seamless by rendering it longer than its length and crossfading the tail into the head. A test checks the seam: the last and first samples, and the RMS of a window either side.

`tools/audio/test_sfx.py` stands in for ears. It checks that each sound is not silent, does not clip, has its expected length, and that each loop's seam holds. CI runs it beside `tools/art`.

Alternatives:
- **Kenney "Impact Sounds" and "Interface Sounds".** They are CC0 and already fetched, git-ignored. They are clean modern samples rather than retro, they are OGG, and copying them in needs the owner's yes. Kept as owner option Q2 C.
- **freesound.org CC0 recordings** for the sea, wind and thunder. Each needs a download approval and a credits row. Kept as owner option Q2 B, with exact candidates listed before any download.
- **jsfxr or bfxr.** An external tool whose output nobody can rebuild in CI. Rejected.

### D2. Tracked folders
- One-shots go in `game/assets/audio/sfx/`, loops in `game/assets/audio/loops/`.
- Each folder has a `License.txt` in the art folders' "Work:" block format: Author 90 Millas, Licence "All rights reserved (see LICENSE)", Source "90 Millas (own work, tools/audio/sfx.py)", and the files listed.
- `CREDITS.md` gets one row.
- The git-ignored `audio/ambience/` stays for any future downloaded recordings and is never named.

### D3. The bank: `SoundData` and `SoundBank` resources
`SoundData` (`game/scripts/audio/sound_data.gd`) has these fields:
- `id`;
- `stream: AudioStream`;
- `bus` (`SFX` or `AMBIENCE`);
- `volume_db`;
- `loop: bool`;
- `pitch_spread` (± fraction, SPD-style);
- `min_interval_s` (the repeat guard);
- `fade_s` (loops: seconds to move between levels);
- `generated: bool`. It is true for files from `tools/audio`, and false for an approved recording (owner Q2 B), whose origin its `License.txt` block carries.

`SoundBank` (`sound_bank.gd`) holds `entries: Array[SoundData]` and the cue numbers:
- `motor_low_db` and `motor_high_db`;
- `motor_near_tiles`, `motor_far_tiles` and `motor_far_db`;
- `thirst_low_at` and `thirst_rearm_above`;
- `thunder_gap_min_s` and `thunder_gap_max_s`;
- `thunder_far_db`;
- the ambience levels: `sea_island_db`, `sea_crossing_db`, `wind_crossing_db`, `wind_squall_db` and `night_db`;
- `squall_weathers`.

The file is `res://resources/sound_bank.tres`. A content check fails if any entry has no stream or an id appears twice. A test also checks that the 15 spec ids are all there.

Loops loop through their `.import` (`edit/loop_mode=2`, `loop_begin=0`, `loop_end=-1`), which is committed. A test loads each loop and asserts `loop_mode != LOOP_DISABLED`, so a re-import that dropped it fails.

`thirst_low_at` is 25, the Sed bar's `MeterBar.CRITICAL_LOW`. A test pins them together, so the warning and the pulse cannot drift apart.

### D4. AudioManager: the playback contract, nothing else
- `_ready` adds two buses under Master, Efectos (`SFX`) and Ambiente (`AMBIENCE`), unless they exist (`AudioBuses.ensure`). The bus names, the voice count and the silence floor are constants of `AudioBuses`, because core-services forbids a service from declaring constants. The patrol motor plays on Efectos: it is a warning, not a bed.
- It loads the bank from its standard path. Callers do not load it, which avoids the static-typed loader leak, art-pass K26.
- `play_sfx(id, db_offset = 0.0)` (the existing one-argument calls keep working):
  - Empty or unknown ids return at once; an unknown id warns once.
  - The repeat guard reads a clock (`Time.get_ticks_msec` by default; tests replace it).
  - Pitch is `1 ± pitch_spread` from AudioManager's own `RandomNumberGenerator`.
  - It plays on the next voice of a pool of 8 `AudioStreamPlayer`s; the oldest is stolen when all are busy.
  - It emits `sfx_played(id)`.
- `set_loop_level(id, level)`, with level from 0 to 1 on top of the entry's `volume_db`:
  - It creates the loop's player on first use and starts it above 0.
  - `_process` moves the player toward the target at `1 / fade_s` per second and stops it at 0.
  - It emits `loop_level_set(id, level)` when the target changes.
  - `loop_level(id)` and `loop_target(id)` are there for tests.
- `stop_loops()` stops and forgets every loop at once, with no fade.
- `set_volume(level)` sets the Master bus volume, and `volume()` reads it.
- Its players keep the default pausable mode, so the solo pause freezes the sea with the world, as `WeatherManager` does. Nothing in it reads or writes game state.

This keeps the service thin. The bank is content, and every rule about when to play is in `RunSounds`. "Services hold no content data" holds: no id table, level or threshold is in the autoload.

### D5. `RunSounds`: one per peer, client-side only
`game/scripts/audio/run_sounds.gd` (`class_name RunSounds`, a `Node`).

**Binding.**
- `game_shell._enter_run` makes it after the HUD and adds it to the HUD with `bind(session, local_peer, hud.needle)`, so it is freed with the HUD at `_end_run`.
- `_exit_tree` calls `AudioManager.stop_loops()`. Every way a run ends (death, summary, abandon, host lost, rematch) frees the HUD, so the sea never plays over the summary.

**Each frame, it reads and writes only to AudioManager.**
- **The local body.** It is `session.body(local_peer)`, re-found each frame. A new body (rebind, rejoin, island travel) re-seeds the watches silently.
- **Pick-up.** It connects `Inventory.changed` on the local body. `InventoryGain.gained(before, after)` compares per-id counts and is true when any id's count rose. The first observation of a bag only seeds.
  - Crafted output counts, as the spec says. Spending a use, removing an item and transferring an item out never do.
- **Low thirst.** `ThresholdCue` fires when the value is at or below `at` while armed, and re-arms above `rearm_above`. A seed at or below `at` (joining, already thirsty) does not fire, and the cue arms only once the value is seen above `rearm_above`.
- **The compass.** `needle.rattled` plays `compass_rattle`.
- **Ambience.** `RunAmbience.levels(riding, phase, squall, bank)` is pure and returns `{sea, wind, night}` levels in 0..1. "Riding" means the local peer is a rider of a live crossing (`Crossing.peers()`), and "on island" is the opposite.
  - Sea: the island level, or the crossing level.
  - Wind: the crossing level, or the squall level in a squall, whichever is higher; 0 otherwise.
  - Night: on an island at NIGHT only.
- **Thunder.**
  - On `WeatherManager.weather_warned` for a squall weather: `thunder`, far.
  - When the polled weather changes into a squall: `thunder`.
  - While a squall lasts: again after `rng.randf_range(gap_min, gap_max)`, from RunSounds' own `RandomNumberGenerator`, which no simulation code sees.
  - The far thunder is the same `thunder` entry played `thunder_far_db` quieter, through `play_sfx(id, db_offset)`, so one file serves both.
- **Patrol.** For every patrol `Creature` in `session.entities`, `PatrolSwell.level(state, clock_s, warning_s, distance_tiles, bank)` gives a linear level, and the loudest boat sets `patrol_motor`:
  - HORIZON: `clock_s / warning_s` maps from `motor_low_db` to `motor_high_db`, linear in dB, so the swell sounds steady.
  - LAP, ALERT_LOCK, ALERT_SEARCH and CHASE: `motor_high_db` within `motor_near_tiles`, falling linearly in dB to `motor_far_db` at `motor_far_tiles`, and silent beyond twice that.
  - AWAY and DOCKED: silent.
  - The clock is `fposmod(route_t, PatrolView.period_s)`. The warning is `data.patrol.horizon_warning_s`, never a literal 20.
  - A `ChangeWatch` keeps each boat's last `alert_serial` by instance id. A rise plays `loudhailer`, and a boat seen for the first time only seeds.
- **Raft hit.** For the crossing the local peer rides, a second `ChangeWatch` follows `vessel_of(local_peer).value` by vessel identity. A fall of more than 0.01 plays `raft_hit`. A new vessel (a new crossing, or a board after a break) only seeds, and so does the first `receive_plan` or snapshot value.
- **Arrival.** It connects `Crossing.ended` for each crossing it sees. When the local peer is in `result.riders` and not `dead`, it plays `arrival`.

`RunSounds` writes nothing to the session, bodies, creatures, crossings, the weather or any random generator the game uses. It adds no synchronizer, property or RPC.

### D6. Own and world events
- **Own events** (pick-up, thirst, compass, plus the existing MetersHud hooks) are read from the local body or the local HUD. A teammate's events are never heard.
- **World events** are read from state every peer shares, so the host and every client hear the same thing at about the same time.
- **Solo** is the same code with one body. Nothing needs a teammate.

### D7. Volume
- `GameSettings` gets `volume: int` (0 to 10, default 8, so 80 %) saved under `[audio] volume`. A malformed value falls back to 8.
- `GameShell` applies it at start with `AudioManager.set_volume(volume / 10.0)`, beside the display settings it applies already.
- The Ajustes row follows owner decision Q1. The run-menu session owns `settings_screen.gd`; this change only provides the key and the API.
- The 0 to 10 steps borrow SPD's `SPDSettings.SFXVol()`.

### D8. Tests
**Pure:**
- `test_sound_bank.gd`:
  - the 15 ids, unique;
  - every stream loads from a tracked path under `res://assets/audio/`;
  - loops loop and one-shots do not;
  - `thirst_low_at == MeterBar.CRITICAL_LOW`;
  - no path names `audio/ambience/`.
- `test_sound_credits.gd`: every WAV under the two folders is listed in its `License.txt` and in `CREDITS.md`.
- `test_audio_manager.gd`:
  - empty and unknown ids are silent;
  - the repeat guard, with a fake clock;
  - pitch stays within the spread;
  - a loop fades up, holds and stops;
  - `stop_loops` empties the loops;
  - volume.
- `test_audio_cues.gd`:
  - `ThresholdCue`, including the seed and the re-arm;
  - `InventoryGain`;
  - `ChangeWatch`, including the first sight;
  - `PatrolSwell`: it rises through HORIZON, reaches its high level at the warning's end, follows distance in sight, and is silent AWAY and DOCKED;
  - `RunAmbience`.
- `test_game_settings` additions: the volume default, its round trip, and a malformed value.

**Solo (1 player, offline):**
- `test_sound_pass_solo.gd` runs a solo session with `RunSounds` and records `sfx_played` and `loop_level_set`:
  - a driftwood pick-up plays `pickup`;
  - a crab pinch plays `hurt_hit`;
  - thirst set to 25 plays `thirst_low` once;
  - night raises `night`;
  - a forced squall plays `thunder` and raises `wind`;
  - a patrol boat's HORIZON raises `patrol_motor` over time;
  - an alert plays `loudhailer`;
  - a crossing hit plays `raft_hit`;
  - an alive end plays `arrival`;
  - freeing the HUD stops every loop.
- `test_sound_sim_invariance.gd` runs the same solo run of 600 frames twice, with and without `RunSounds`, and compares the state hash, in the manner of `test_art_sim_invariance`.

**Net (in-process host and client, the `test_damage_feedback_net` pattern):**
- `test_sound_pass_net.gd`:
  - the host's pick-up plays on the host only;
  - the client's pick-up plays on the client only;
  - a patrol's HORIZON raises the motor on both;
  - an alert plays `loudhailer` on both;
  - a joiner with a full bag hears no pick-up.

**Manual:**
- `tests/manual/sound_pass_run.gd`: two processes on UDP 7802. Each process logs the ids it played; the run asserts each peer's own and world lists, and the negative: the client never logs the host's pick-up or hurt.

### D9. Reference games

**Shattered Pixel Dungeon**
- `com.watabou.noosa.audio.Sample.play(id, leftVolume, rightVolume, pitch)` plays a loaded sample by id, scaled by one `globalVolume`. Ids are the `Assets.Sounds` constants.
- **Borrowed:**
  - play by id through one thin service with one global volume;
  - `Char.hitSound(pitch)`, called with `Random.Float(0.87f, 1.15f)`, so repeated hits don't sound mechanical: our `pitch_spread`;
  - 0 to 10 volume steps (`SPDSettings.SFXVol`, `WndSettings.AudioTab`).
- **Rejected:**
  - `Sample.playDelayed`: no cue here needs a delay;
  - separate music and SFX volumes: there is no music.

**DCSS**
- `sound.cc`: `parse_sound(message)` → `check_sound_patterns(message)` matches each message against `Options.sound_mappings` (regex to file), then `play_sound(file)`.
- **Borrowed:** the mapping from cue to file lives outside the code, in data the player or designer edits.
- **Rejected:**
  - keying sounds on message text: our cues are typed ids, and our messages are Spanish and change;
  - sound being off by default and absent from most builds.

**Brogue CE**
- It has no audio. `Globals.c` describes sounds only as message text on dungeon features, for example a feature that "retracts into the ground with a grinding sound".
- **Borrowed:** the principle that sound never carries information alone. Every cue here has a visual twin:
  - the motor has the horizon mark;
  - the loudhailer has the speech bubble;
  - low thirst has the pulsing Sed bar;
  - a raft hit has the integrity bar;
  - hurt has the flash.
  A muted or deaf player loses nothing.

**Don't Starve Together** (wiki, and `docs/REFERENCE_DST.md`)
- **Borrowed:**
  - [Hound/DST](https://dontstarve.wiki.gg/wiki/Hound/DST): growls that grow louder before a wave arrives. This is the patrol motor's swell over the horizon warning, which `REFERENCE_DST.md` already flagged for `guardacostas-stealth`.
  - The temperature warning (Overheating, noted in `REFERENCE_DST.md`): one sound as a meter nears its danger step. This is `thirst_low` at the Sed bar's critical step.
  - [Darkness](https://dontstarve.wiki.gg/wiki/Darkness): a sound before the dark strikes. Here the loudhailer and the motor give the patrol its spoken-warning beat.
- **Rejected:**
  - Sanity's tiered whisper ambience: no sanity meter fits a loop yet;
  - per-season ambience beds: one tropic season, so sea, wind and night cover it.

No code, data, numbers or audio from any of the four is used.

## Risks / Trade-offs

- **[A synthesized sea can sound like radio static.]**
  - It is shaped brown noise with slow swells and a lighter wash on top, the way GBA games used their noise channel.
  - The owner listens to the files in the PR, and any id can become a CC0 recording as a data-only change (Q2 B).
- **[Headless runs use the dummy audio driver.]** No test reads `playing` or a playback position. They read the `sfx_played` and `loop_level_set` signals and the manager's own loop levels.
- **[A re-import drops the loop flag.]** The `.import` files are committed, and `test_sound_bank` asserts the loop mode on the loaded stream.
- **[A client's `integrity.value` arrives once a second as well as on change.]** A resync that equals the current value plays nothing, and a rise (a mend) plays nothing.
- **[A boat's `route_t` on a client runs locally between syncs.]** It can snap back on a sync. The swell reads the level fresh each frame and AudioManager smooths it over `fade_s`, so a snap never clicks.
- **[Merges with other sessions.]**
  - `game_shell.gd` (attach `RunSounds` and apply the volume: about 6 lines);
  - `game_settings.gd` (one key);
  - `test_core_services.gd` (one assertion);
  - `TASKS.md`, `CREDITS.md`, `ASSETS.md` and `ci.yml` (append-only lines).
  These are named to the coordinator so the run-menu session expects them.
- **[Process-exit leak reports, Fable G17.]** AudioManager frees its players in `_exit_tree`. The smoke run's leak count is compared before and after.

## Owner decisions

Asked through the coordinating session on 2026-11-23, recommended first. The owner answered the same day in option dialogs.

- **Q1. Volume control: A.**
  - One "Volumen" row in Ajustes, 0 to 100 % in 10 % steps, default 80 %.
  - This change ships `GameSettings.volume` and `AudioManager.set_volume` (D7).
  - The run-menu session adds the row; the coordinator tells it.
  - Not chosen: B, two rows "Efectos" and "Ambiente"; C, no control in this pass.
- **Q2. Where the sounds come from: B.**
  - Generated effects, but CC0 recordings for the sea, wind and thunder.
  - Before any download, the coordinator gets the exact candidates for those three: file name, source page, licence (CC0 only) and size, two per sound where possible. The owner approves each file.
  - Meanwhile everything is built with the generated sounds. The three stay as generated placeholders, so dropping the recordings in later is a data-only swap:
    - the file;
    - its `sound_bank.tres` entry;
    - a `License.txt` block and a `CREDITS.md` row with author, licence and source;
    - the `tools/audio` provenance list.
  - Spec "Generated sounds are reproducible and credited" already covers this: an outside sound comes in only with the owner's approval and a recorded origin. A recording's bank entry is marked `generated = false`. The rebuild check then skips it, and the credits check asks for its author and source instead.
  - Not chosen: A, all generated; C, Kenney's Impact and Interface Sounds for hits and the pick-up.
