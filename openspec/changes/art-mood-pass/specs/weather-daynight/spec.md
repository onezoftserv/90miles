## ADDED Requirements

### Requirement: Weather label
While the weather is not a clear one, each peer's HUD SHALL show that weather's name from its data, in the session's language, in a small window of its own inside the day phase's band, overlapping no other HUD element: meters, day phase, teammates, compass needle, sign note, note label or crossing HUD. Clear weather shows none, and a new weather needs no script. The label only reads the sky. A solo player sees the same label.

#### Scenario: A solo player sees the squall named
- **GIVEN** one offline player on the sandbar, language Spanish, in calm weather
- **WHEN** a squall starts, and later ends
- **THEN** while it runs the HUD's weather window shows "Turbonada", and once calm returns the window is hidden

#### Scenario: English names it too
- **GIVEN** a session whose language is English, during a squall
- **WHEN** the HUD is drawn
- **THEN** the weather window shows "Squall"

#### Scenario: The label overlaps nothing
- **GIVEN** the run HUD of a co-op session with teammates, the compass needle and a sign note open, during a squall
- **WHEN** the weather window's rect is compared with every other top-band HUD element's rect, the teammate list's restyled place and the crossing HUD's band included
- **THEN** it intersects none of them and lies inside the day phase's band

#### Scenario: Every weather name fits
- **GIVEN** every weather in the content catalog that is not clear
- **WHEN** its Spanish and English names are measured in the HUD's glyphs
- **THEN** each fits inside the weather window

### Requirement: A readable night and dusk
The day-cycle tints SHALL keep the world readable: at night the scene is dark, under half the day's brightness, but bright enough that the sand and the sea keep their value steps under the fire's pool; at dusk the tinted deep and shallow water stay blue, with blue their strongest channel, rather than teal. The tints stay provisional data (`docs/GAME_DESIGN.md` §5), and no rule reads them but the drawing. With exactly 1 player, offline, the night and dusk look the same.

#### Scenario: Dusk water stays blue
- **GIVEN** the day-cycle data and the sea's ramps
- **WHEN** the dusk tint is multiplied into the deep and the shallows ramps' base colours
- **THEN** each result's blue channel is greater than its green one

#### Scenario: Night is dark but readable
- **GIVEN** the day-cycle data in calm weather
- **WHEN** the night tint's luminance is computed (0.2126 r + 0.7152 g + 0.0722 b, as `Color.get_luminance` does)
- **THEN** it lies between 0.44 and 0.52, where the day tint's is 1

#### Scenario: A solo night on the sandbar
- **GIVEN** one offline player on the sandbar in calm weather, at night past the blend time
- **WHEN** the scene's tint is read
- **THEN** it is the night colour from the day-cycle data times calm's tint
