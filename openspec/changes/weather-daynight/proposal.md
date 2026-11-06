# Proposal

## Why

Milestone A needs a real day. survival-meters already rules by phase and by the 10:00–16:00 window, but it reads a hand-set `ClimateState`; `WeatherManager` is a three-line stub; and co-op sends a fixed `time_of_day_s` and `weather` once on join. Nothing runs the 12-minute day, tints the screen, announces a squall or keeps clients in step with the host.

## What Changes

- **Clock.** `WeatherManager` owns the only clock: a 720 s day (dawn 60, day 300, dusk 60, night 300), one in-game hour = 30 s, dawn at 06:00. It emits `phase_changed` on each transition and `day_started` at dawn, and answers hour, minute, phase and midday. It writes the `ClimateState` the meters already read, so survival-meters code and tests do not change.
- **Weather.** Calm or squall. When a phase begins and nothing is warned or running, the host rolls the next weather by roll weight from data. A squall is warned 60 s early (`weather_warned`, a dark horizon line in the HUD), starts, lasts 120 s and is followed by calm (`weather_changed`).
- **Tint.** A `CanvasModulate` (`DayNightTint`) in each playable scene takes a colour per phase from `resources/day_cycle.tres`, blends from the previous phase's colour, and multiplies the weather's `canvas_tint`.
- **Sync.** The host sends clock and weather to a joiner, on every phase or weather change or warning, and every 10 s. Clients run their copy between messages, never roll, and ignore anything not from the host. Solo sends nothing, and the solo pause freezes the clock.
- **Data.** New `resources/weather/calm.tres`, `resources/weather/squall.tres` and `resources/day_cycle.tres` (`DayCycleTuning`).

Out of scope: trade wind, fog, hurricane, tides, chain-based weights, and every squall effect (fires out, raft damage, patrols in port, morale −10, rain). Those capabilities subscribe to `weather_changed` later; their fields are filled in `squall.tres` but nothing reads them here.

## Solo

Everything runs on the offline peer with no second peer. The clock and weather run on the host, which is the solo player; `send_sky` returns at once when there are no remote peers; the solo pause freezes the clock and weather. `test_weather_solo.gd` and `test_weather_manager.gd` cover exactly 1 player.

## Provisional numbers

All until the Milestone A playtest. Fixed by `GAME_DESIGN` §5 and so not provisional: phase lengths, the 30 s hour, 60 s warning, 120 s squall, calm heat ×2.

| Number | Value | Where |
| --- | --- | --- |
| Calm roll weight | 3.0 | `weather/calm.tres` |
| Squall roll weight | 1.0 (25 % per phase roll, about one squall a day) | `weather/squall.tres` |
| Squall allowed phases | any | `weather/squall.tres` |
| Squall heat factor | 1.0 (§5 gives none) | `weather/squall.tres` |
| Squall tint | (0.70, 0.72, 0.80) | `weather/squall.tres` |
| Phase tints | dawn (0.95, 0.80, 0.75), day (1, 1, 1), dusk (0.90, 0.70, 0.60), night (0.35, 0.40, 0.65) | `day_cycle.tres` |
| Blend time | 20 s | `day_cycle.tres` |
| Resync interval | 10 s | `day_cycle.tres` |
| Horizon line | 6 px band, (0.10, 0.12, 0.18, 0.85) | `horizon_line.gd` |
| Squall warned at the roll, so a squall rolled at a phase start begins 60 s into the phase | — | design.md |

## Impact

`game/scripts/autoload/weather_manager.gd`, new `game/scripts/world/*` and `game/scenes/world/*`, `HorizonLine`, `CoopSession` (`sky`, `send_sky`, `receive_sky`, four world-state keys), both dev playgrounds, new data files and tests. No new autoload, no new `WeatherData` fields.
