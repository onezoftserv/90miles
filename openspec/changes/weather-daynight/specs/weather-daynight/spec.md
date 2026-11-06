## MODIFIED Requirements

### Requirement: Day cycle
A day SHALL last 12 real minutes: dawn 1, day 5, dusk 1, night 5. One in-game hour is 30 real seconds and the clock reads 06:00 when dawn starts, so the day phase runs 08:00–18:00, dusk 18:00–20:00 and night 20:00–06:00. `WeatherManager` drives a `CanvasModulate` color curve and emits `phase_changed`. (Clock added by survival-meters; `docs/GAME_DESIGN.md` §5.)

`WeatherManager` owns the only clock: it emits `phase_changed` when a phase begins and `day_started` when dawn begins, and every other system (survival-meters' day phase and 10:00–16:00 midday window included) reads the time of day, the in-game hour and minute, the phase and midday from it. The clock runs on the host and pauses with the tree. A `CanvasModulate` in each playable scene takes a colour per phase from data (`game/resources/day_cycle.tres`), blends from the previous phase's colour over the first seconds of each phase, and multiplies the current weather's tint; HUD layers are not tinted. With exactly 1 player (solo, offline) the clock runs the same way with no second peer, and the solo pause freezes it.

#### Scenario: Dusk arrives
- GIVEN a new day starting at dawn
- WHEN 6 real minutes pass
- THEN the phase is dusk and `phase_changed` was emitted

#### Scenario: Clock time
- **GIVEN** a new day starting at dawn
- **WHEN** 2.5 real minutes pass
- **THEN** the clock reads 11:00 and the phase is day

#### Scenario: Midday window
- **GIVEN** a new day starting at dawn
- **WHEN** 2 real minutes pass
- **THEN** the clock reads 10:00 and it is midday, and 3 real minutes later it reads 16:00 and it is no longer midday

#### Scenario: A full day
- **GIVEN** a new day starting at dawn
- **WHEN** 12 real minutes pass
- **THEN** `phase_changed` was emitted for day, dusk, night and dawn in that order, `day_started` was emitted once and the clock reads 06:00 of the next day

#### Scenario: Night tint
- **GIVEN** calm weather and the night colour from the day-cycle data
- **WHEN** the phase has been night for longer than the blend time
- **THEN** the scene's `CanvasModulate` colour is the night colour times calm's tint

#### Scenario: Solo pause freezes the clock
- **GIVEN** one player, offline, with the clock running
- **WHEN** they pause
- **THEN** the time of day does not change until they resume, and then it runs again from where it stopped

### Requirement: Weather states
The manager SHALL hold one of: calm (scorching), trade-wind, squall, fog, hurricane. Transitions are rolled per phase with chain-based weights; a squall is announced 60 s early by a dark horizon line; a hurricane is announced one day early by an NPC.

Until chains exist only calm and squall are rolled. When a phase begins and the weather is calm with no squall warned, the host picks the next weather among the `WeatherData` states allowed in that phase, by their roll weight. A squall picked this way is warned at once (`weather_warned`, the horizon line shows), starts 60 s later, lasts 2 real minutes and is followed by calm; no roll happens while a squall is warned or running. `weather_changed` is emitted on every change; what a squall does to fires, rafts, patrols and morale belongs to the capabilities that listen for it. Weather works the same with exactly 1 player.

#### Scenario: Squall warning
- GIVEN the next weather roll is a squall
- WHEN it is 60 s before the squall starts
- THEN a dark horizon line appears

#### Scenario: Squall runs its course
- **GIVEN** a squall rolled at the start of a phase
- **WHEN** 60 s pass, and then 120 s more
- **THEN** the weather turns to squall after the 60 s and back to calm after the 120 s, `weather_changed` firing each time, and the horizon line is gone once the squall starts

#### Scenario: No roll during a squall
- **GIVEN** a squall that is warned or running
- **WHEN** a new phase begins
- **THEN** no weather is rolled and no second squall is warned

### Requirement: Weather sync
Weather state and phase SHALL be host-authoritative and synced to clients on change and on join.

The host sends the time of day, day, weather, the squall warning and the time left on the current weather to every client when it joins, whenever the phase or weather changes or a squall is warned, and every 10 s in between. A client's clock runs between messages but never rolls weather; it takes the host's values when they arrive, and ignores clock messages not sent by the host and values out of range. With exactly 1 player (solo, offline) nothing is sent and the host's clock is the only one.

#### Scenario: Join during fog
- GIVEN the host's weather is fog and the phase is night
- WHEN a client joins
- THEN the client receives fog and night from the host

#### Scenario: Client follows a squall
- **GIVEN** a client connected to a host in calm weather
- **WHEN** the host rolls a squall
- **THEN** the client's horizon line shows, and when the squall starts the client's weather is squall

#### Scenario: Forged clock ignored
- **GIVEN** two clients connected to a host
- **WHEN** one client sends the other a clock message
- **THEN** the other client's time and weather do not change

## ADDED Requirements

### Requirement: Calm and squall data
Calm and squall SHALL be `WeatherData` files in `game/resources/weather/` that pass the content validator. Every number of the clock's presentation and roll SHALL be read from data, so retuning never needs a script edit. Calm is scorching (heat ×2, clear sky); squall is a storm warned 60 s early by the horizon line, lasting 120 s, followed by calm. Roll weights and tint colours are provisional until the Milestone A playtest (`docs/GAME_DESIGN.md` §5). The same data applies with exactly 1 player.

#### Scenario: Weather files validate
- **GIVEN** the content catalog
- **WHEN** the content validator runs
- **THEN** calm and squall load as `WeatherData` with no errors, squall lasting 120 s with a 60 s horizon-line warning followed by calm, and calm with a heat factor of 2

### Requirement: The shell's run uses the sky
A run started from the game shell (solo, host or joined client) SHALL run on the game's one sky: the same clock, climate, tint and horizon line as the playgrounds. Solo and the host start the clock at 06:00 (`docs/GAME_DESIGN.md` §5) when the run begins; a joined client runs it between the host's resyncs without restarting the day or rolling weather. Leaving or ending the run stops it. The tint SHALL cover the world view only. With exactly 1 player, offline, all of this holds.

#### Scenario: Solo run from the title
- **GIVEN** the title screen and no teammate
- **WHEN** the one player starts a solo run
- **THEN** the clock starts at 06:00 and advances, the player's body reads the sky's climate, the tint covers the world view and the horizon line is in the HUD, and returning to the title stops the clock

#### Scenario: Hosted and joined runs
- **GIVEN** a host in the lobby and a client that joined
- **WHEN** the host begins the run
- **THEN** the host's clock starts, and the client's session holds the same sky with weather rolls off, its clock runs between the host's resyncs (which only correct drift) and a client joining mid-run keeps the host's time of day
