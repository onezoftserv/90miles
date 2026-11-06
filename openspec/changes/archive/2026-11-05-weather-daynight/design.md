# Design

## Context

`ClimateState` (phase, midday, heat factor) is what the meters read; a level hands one shared object to the session and bodies. `WeatherData` already has every field calm and squall need. Co-op sends `world_state` once per joiner and has authority-only reliable RPCs for host events. Autoloads inherit the pausable process mode, so the solo pause stops them with the tree.

## Decisions

- **Pure classes, thin autoload.** `DayClock` (time), `WeatherCycle` (calm and squall), `WorldSky` (both, the `ClimateState`, the tint, sync state). `WeatherManager` holds one `WorldSky`, advances it from `_process` and re-emits its signals.
- **One clock, written into `ClimateState`.** The sky writes the climate after every change; survival-meters stays untouched.
- **`WeatherManager` is idle until `start()`.** A global clock ticking under the whole GUT suite would flip phases mid-test; levels start it and stop it on exit.
- **Phase lengths and the 30 s hour are constants in `DayClock`.** The spec fixes them. Tints, blend, resync and roll weights are data.
- **Roll by `PHASE_ROLL` and `roll_weight`.** The field a later chain-weighted roll will use, so calm and squall files do not change then.
- **Squall warned at the roll.** The phase start rolls and warns, the squall starts 60 s later. A dawn or dusk squall therefore begins as the next phase starts.
- **Sync by reliable authority RPC.** State changes a few times a day: `receive_world_state` on join (the sky state merged in), `receive_sky` on change and every `resync_s`. The sky keys are `weather`, `time_of_day_s`, `day`, `weather_left_s`, `pending`, `pending_in_s`. Clients check the sender is the host and the values are in range (`WorldSky.apply_state`).
- **`CoopSession.sky` is injected, null by default.** One process runs several peers in tests, so each branch gets its own `WorldSky`; with no sky the world state is sent as it was.
- **Clients advance between messages but never roll** (`rolls_enabled = false`), which gives a smooth tint without trusting a client with weather.
- **Squall effects are signals and data only.** `fire_extinguish_s`, `patrols_in_port`, `morale_on_start` and the rest are filled in `squall.tres` and read by nobody yet.
- **The horizon line is a HUD band**, outside the tinted canvas.

## Risks

- A test that starts the manager must stop it (`after_each`); the playgrounds stop it in `_exit_tree`.
- World-sky tests turn rolls off so a random 25 % squall cannot break them.
