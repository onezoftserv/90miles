## ADDED Requirements

### Requirement: Firelight at night
A lit fire SHALL cast a warm pool of hard concentric rings, drawn 1:1 with the screen, whose outer edge lies exactly at the fire's company radius from the survival tuning. Its strength follows the sky's darkness: none by day, full at night. It flickers with the flame's frames, never by chance, and holds steady while "Reducir destellos" is on. A fire that is out, and every other structure, casts none. The light only draws. A solo player by their fire sees the same pool.

#### Scenario: A solo player by the fire at night
- **GIVEN** one offline player on the sandbar beside a lit fire, at night in calm weather
- **WHEN** the fire is drawn
- **THEN** its look has a light that is on, whose texture is drawn 1:1, whose outer ring's radius is the company radius in pixels (80 px with today's tuning) and whose energy is above 0 and below 1

#### Scenario: No light by day, none once out
- **GIVEN** one offline player beside a lit fire
- **WHEN** it is day, and later the fire has burnt out at night
- **THEN** by day its light is off, and once it is out its light is off, while a lit rain catcher or workbench never has one

#### Scenario: The light follows the company radius
- **GIVEN** a survival tuning whose company radius is 6 tiles
- **WHEN** a lit fire is drawn at night
- **THEN** its light's outer ring is 96 px from its centre

#### Scenario: Steady with reduced flashes
- **GIVEN** a lit fire at night and "Reducir destellos" on
- **WHEN** its flame plays every frame of its animation
- **THEN** its light's energy is the same on every frame, while with the setting off it follows the flame's frame

### Requirement: Squall on screen
While a weather whose data names an overlay runs, every peer SHALL draw it over the world view, under the name tags and inside the sky's tint. The squall's overlay is rain: thin diagonal streaks in light palette colours covering at most a quarter of the view, light then heavy, with splash ticks placed by a hash, never by chance. A weather's pace data speeds the foam, easing in and out so it never jumps. All of it only draws. A solo player sees the same squall.

#### Scenario: A solo squall
- **GIVEN** one offline player on the sandbar in calm weather
- **WHEN** a squall starts, and 120 s later ends
- **THEN** while it runs a rain overlay is shown inside the tinted world, and the sea's and the foam's pace rise to the squall's; once it ends the overlay is gone and both paces ease back to calm's

#### Scenario: Rain stays thin
- **GIVEN** the rain overlay's frames
- **WHEN** their opaque pixels are counted
- **THEN** the light frame covers at most 12% of its pixels and the heavy one at most 25%, every pixel a master palette colour, fully opaque or fully transparent

#### Scenario: The foam speeds up without a jump
- **GIVEN** the island's foam clock in calm weather
- **WHEN** a squall starts and every frame is stepped at 60 frames per second
- **THEN** the foam's clock never advances more than the squall's pace times the frame time in one step, and at the end of the ease it advances at the squall's pace

#### Scenario: Rain on the crossing
- **GIVEN** one offline player on a raft crossing when a squall starts
- **WHEN** the crossing is drawn
- **THEN** the rain overlay covers the crossing's view inside the tint, and the crossing's sea runs at the squall's pace

### Requirement: Life on the open sea
The crossing SHALL draw crests on its sea in the deep water's own colours, never white, so none reads as a fin; a wake at the bow and stern of the shared vessel and of each intact board, none for a sunk deck or a swimmers' route; and each flotsam piece as its item riding a waterline, or as a plank, readable as loot. All of it follows the scroll and lateral position every peer receives, and nothing is synced. A solo crossing looks the same.

#### Scenario: A solo raft crossing has crests and a wake
- **GIVEN** one offline player on a raft crossing at integrity 100
- **WHEN** the crossing is drawn
- **THEN** crests are shown on the sea under the wake, every crest pixel a deep-ramp colour or the deep glint, none white, and a wake is shown at the raft's north and south edges under the deck

#### Scenario: No wake when there is no vessel
- **GIVEN** one offline player on a swimmers' route, and later a raft crossing whose deck has sunk
- **WHEN** each crossing is drawn
- **THEN** no wake is shown in either

#### Scenario: A solo player sees a coconut to grab
- **GIVEN** one offline player on a raft crossing whose plan carries a coconut down lane 3
- **WHEN** the coconut is in view
- **THEN** it is drawn from the coconut's own icon with at least 9 of its rows above its waterline and a ring at the line, and its grab point is where the piece is

#### Scenario: Same sea on every peer
- **GIVEN** a host and a client in a raft crossing
- **WHEN** both draw it at the same plan time, scroll and lateral position
- **THEN** both show the same crests and the same wake

## MODIFIED Requirements

### Requirement: Scrolling sea
Water cells SHALL show one moving sea under the land layers: a seamless water texture drifting at a steady speed, with shallows drawn a palette step lighter than deep water and brackish water in a step of its own, every colour on the master palette. A weather's presentation data may raise that speed; the change eases in and out, so the water never jumps. The steps SHALL meet in a curved line that does not follow the cell squares, and each water cell's centre is drawn in its own step while the line is at rest. The sea's motion comes from its own clock, which keeps running under a solo pause, and never from simulation state; only the current weather's pace sets how fast that clock runs.

#### Scenario: Shallows read lighter than deep water
- **GIVEN** a shallows cell beside a deep cell
- **WHEN** the sea is drawn
- **THEN** the shallows cell's colours are the lighter step and the deep cell's the darker one, both from the master palette

#### Scenario: The sea moves on its own
- **GIVEN** a solo game on the sandbar with the player standing still
- **WHEN** two frames are drawn a second apart
- **THEN** the water texture has moved and no cell has changed its terrain

#### Scenario: The deep edge is soft and every cell keeps its step
- **GIVEN** the sandbar and the coast cay built for one offline player
- **WHEN** the sea's depth mask is read at each water cell's centre, with the line at rest
- **THEN** every deep, shallows and brackish cell's centre shows its own step
- **AND** between a deep cell and a shallows cell beside it the mask is graded, not a step at the cell border, so the line rounds the corners of the coast instead of copying them

#### Scenario: A squall speeds the sea without a jump
- **GIVEN** a solo game on the sandbar in calm weather, its sea clock running at pace 1
- **WHEN** a squall starts and the sea is stepped every frame
- **THEN** the sea clock's pace rises to the squall's sea pace over the ease time, and in no frame does the clock advance more than that pace times the frame time

#### Scenario: The sea keeps moving under a solo pause
- **GIVEN** one offline player on the sandbar who pauses the game
- **WHEN** a second passes while paused
- **THEN** the sea's and the foam's clocks have advanced, and the day clock has not
