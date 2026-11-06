# Tasks

## 1. Tests first

- [x] 1.1 Add GUT tests for the clock, weather cycle, content files, sky, manager (including the solo pause), tint, horizon line, playground, host sync and a 1-player offline day; verify they fail (RED)

## 2. Data

- [x] 2.1 Add `DayCycleTuning` with `resources/day_cycle.tres`, and `weather/calm.tres` and `weather/squall.tres` that pass the content check

## 3. Clock, weather and sky

- [x] 3.1 Add `DayClock`, `WeatherCycle` and `WorldSky` (writes `ClimateState`) and the thin `WeatherManager` (`start`, `stop`, readers, forwarded signals)
- [x] 3.2 Movement and co-op playgrounds take their climate from `WeatherManager.sky` and start at 10:00; the meter tests stay green

## 4. Presentation

- [x] 4.1 Add `DayNightTint` (`CanvasModulate`) and `HorizonLine`, and put both in the playgrounds

## 5. Co-op sync

- [x] 5.1 `CoopSession.sky`, the sky keys in the world state, `send_sky` and `receive_sky`, the periodic resync, clients never roll

## 5b. Shell run

- [x] 5b.1 `GameShell` runs on `WeatherManager.sky` (solo and host start it at dawn, a client follows the host, `_end_run` and the summary stop it), with `DayNightTint` in the world view and `HorizonLine` in the run HUD; `test_shell_sky.gd`

## 6. Checks

- [x] 6.1 Import, smoke run, GUT and the 300-frame run are clean (GREEN); `openspec validate --all` and `validate weather-daynight --type change --strict` pass
- [x] 6.2 Tick `weather-daynight` in `TASKS.md`
