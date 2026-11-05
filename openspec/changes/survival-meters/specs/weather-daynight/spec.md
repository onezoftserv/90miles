# Spec Delta

## MODIFIED Requirements

### Requirement: Day cycle
A day SHALL last 12 real minutes: dawn 1, day 5, dusk 1, night 5. One in-game hour is 30 real seconds and the clock reads 06:00 when dawn starts, so the day phase runs 08:00–18:00, dusk 18:00–20:00 and night 20:00–06:00. `WeatherManager` drives a `CanvasModulate` color curve and emits `phase_changed`. (Clock added by survival-meters; `docs/GAME_DESIGN.md` §5.)

#### Scenario: Dusk arrives
- GIVEN a new day starting at dawn
- WHEN 6 real minutes pass
- THEN the phase is dusk and `phase_changed` was emitted

#### Scenario: Clock time
- **GIVEN** a new day starting at dawn
- **WHEN** 2.5 real minutes pass
- **THEN** the clock reads 11:00 and the phase is day
