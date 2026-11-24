## MODIFIED Requirements

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit in one window inside (4,4) to (136,90), Salud first, each row a label, a thin bar at a fixed x and the value; Calor is the last meter row, drawn as a thermometer (survival-meters "HUD bars"), and status rows follow it only while they apply. A label turns a steady orange at the warning step (50 or less, heat 50 or more) and a steady alert red at the critical one (25 or less, heat 75 or more), where the bar's outline and value also pulse; the label never pulses. The clock row (the day phase window) sits top-centre at (152,4) to (380,18), the objective row under it at (152,20) to (380,30), and the weather window keeps (384,6) to (464,16). In co-op, teammates are listed top-right inside x 502 to 636, each with their name, a health bar and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel. An open sign note sits top-centre under the clock row, clear of the meters, the teammate list and the centre; the objective row yields to it. The secret cay's needle sits at (384,20) to (408,44), and the note label at (140,46) to (500,66).

#### Scenario: Solo HUD
- **GIVEN** a solo run
- **WHEN** the HUD is shown
- **THEN** it shows the meters, the clock row, the objective row and the inventory strip, and no teammate list or quick-chat wheel

#### Scenario: Critical thirst
- **GIVEN** a player whose thirst is 20
- **WHEN** the HUD draws the thirst row
- **THEN** the Sed bar's outline and its value pulse while the label "Sed" is a steady alert red, and the pulse stops once thirst is above 25

#### Scenario: Warning step
- **GIVEN** a solo player, offline, with exactly 1 player, whose thirst is 40 and heat 60
- **WHEN** the HUD draws the meters
- **THEN** the labels "Sed" and "Calor" are a steady orange, nothing pulses, and every other label is cream

#### Scenario: Teammate down
- **GIVEN** a co-op run with Papo downed
- **WHEN** a teammate looks at the HUD
- **THEN** Papo's block reads "Caído" beside his health bar, and his name and health strip show over his head

#### Scenario: The sign note keeps clear
- **GIVEN** a co-op run with three teammates listed and a sign note open showing the longest coast cay line
- **WHEN** the HUD is drawn
- **THEN** the note's rectangle overlaps none of the meters, the clock row, the teammate list, the inventory band or the centre, and the objective row is hidden while the note is open

#### Scenario: The meters stay in their corner
- **GIVEN** a solo run, offline, with exactly 1 player who bleeds and has sunstroke
- **WHEN** the HUD is drawn
- **THEN** the meters window with its "Insolación" and "Sangrando" rows lies inside (4,4) to (136,90), with Salud as its first row, and left of x 140, where the secret cay's note label starts

#### Scenario: The longest teammate block
- **GIVEN** a host with three clients, one named with 16 characters whose client is disconnected
- **WHEN** the host's HUD is drawn
- **THEN** the teammate list lies inside x 502 to 636 and y 4 to 90, shows that whole name and "Desconectado", and overlaps neither the clock row, the objective row, the needle's place nor the sign note's place

#### Scenario: The top band holds together
- **GIVEN** a solo run, offline, with exactly 1 player in a squall carrying the broken compass, with the objective row showing its longest line in Spanish and in English
- **WHEN** the HUD is drawn
- **THEN** the meters window, the clock row, the objective row, the weather window, the needle and the note label's place overlap none of each other, nor the teammate list's place (x 502 to 636), nor the crossing strip's places ((220,68) to (420,80) and (160,81) to (480,91))

### Requirement: Inventory band and world marks
During a run the HUD's bottom band (y 306 to 360) SHALL hold the local player's inventory strip, its selected item's line and refusal line, and the crafting list opens above it at the left edge (4,162 to 244,302) while the player is at a workbench (inventory-hud). In the centre the HUD draws only marks anchored to something in the world: a teammate's name tag, the interact prompt, the hidden mark and, on the frame of the view, the raft-site arrow ("Raft-site arrow"). Solo the same.

#### Scenario: Marks in the centre
- **GIVEN** a solo player standing within 1 tile of a coconut, crouched in brush
- **WHEN** the HUD is drawn
- **THEN** the interact prompt shows over the coconut and the hidden mark over the player, both anchored to their world positions, and no panel covers the centre

#### Scenario: The band in co-op
- **GIVEN** a host with one client
- **WHEN** each peer draws its HUD
- **THEN** the strip and its lines lie inside y 306 to 360 and overlap neither the meters, the clock row nor the teammate list

## ADDED Requirements

### Requirement: Clock strip
The clock row SHALL show, left to right: the day count ("Día 2"; "Day 2"), from 1 at the run's start and never reset by travel; a strip of one day from dawn to dawn, coloured by phase (dawn, day with its midday stretch marked, dusk, night), with a sun-yellow marker at the time of day; the time left ("Time left before dark"); and the phase word ("Phase words"). Drawing only. With exactly 1 player, offline, it reads the local sky and freezes with the solo pause.

#### Scenario: A solo morning
- **GIVEN** a solo run, offline, with exactly 1 player, on day 1 at 09:00
- **WHEN** the clock row is drawn
- **THEN** it reads "Día 1", the moon mark with "11h" and "Mañana", and the marker stands an eighth of the way along the strip

#### Scenario: Travel keeps the day
- **GIVEN** a solo run, offline, with exactly 1 player, that reached the coast cay on day 2
- **WHEN** the clock row is drawn
- **THEN** it reads "Día 2"

### Requirement: The clock follows the host
The clock row SHALL read the session's sky: the host's clock, which every client follows between the host's resyncs, so the row is the same on every peer to within one resync. A client never runs a day count or a time of its own beyond the host's. With exactly 1 player, offline, the player's own game is the host.

#### Scenario: A client's clock matches the host's
- **GIVEN** a host and a client in a run on day 2 at 14:00
- **WHEN** each peer draws its clock row after a resync
- **THEN** both read "Día 2", "6h" and "Mediodía", with the marker at the same place

### Requirement: Time left before dark
The clock row SHALL show the time left before night begins (20:00) beside a moon mark, or at night the time left before dawn (06:00) beside a sun mark: in in-game hours rounded up ("3h"), or in in-game minutes rounded up under one hour ("40m"). It is cream, and orange from dusk (18:00) until night. With exactly 1 player, offline, it reads the same.

#### Scenario: Late afternoon turns orange
- **GIVEN** a solo run, offline, with exactly 1 player, on day 2 at 18:30
- **WHEN** the clock row is drawn
- **THEN** it reads "Día 2", the moon mark with "2h" in orange and "Atardecer"

#### Scenario: Night counts to dawn
- **GIVEN** a solo run, offline, with exactly 1 player, at 05:40 on day 1
- **WHEN** the clock row is drawn
- **THEN** it reads the sun mark with "20m" in cream and "Noche"

### Requirement: Phase words
The clock row's phase word SHALL be "Amanecer" at dawn, "Mañana" from 08:00 to 10:00, "Mediodía" from 10:00 to 16:00, "Tarde" from 16:00 to 18:00, "Atardecer" at dusk and "Noche" at night ("Dawn", "Morning", "Midday", "Afternoon", "Dusk", "Night" in English), so the day phase is never read as the day count's "Día". With exactly 1 player, offline, the words are the same.

#### Scenario: The afternoon word
- **GIVEN** a solo run, offline, with exactly 1 player, at 17:00
- **WHEN** the clock row is drawn
- **THEN** its phase word is "Tarde"

### Requirement: Objective row
The objective row SHALL name the local player's current goal in the session's language ("Objective while building the raft", "Objective at launch and at sea"), in at most 27 glyphs, and be hidden when no goal applies, while a sign note is open, while a screen is over the run and while the run summary shows. It reads only synced state, so a client's row follows the host's. Drawing only. With exactly 1 player, offline, the run can be won by following the row alone.

#### Scenario: A solo player's first frame
- **GIVEN** a solo run, offline, with exactly 1 player, on the sandbar with an empty inventory and an empty raft site
- **WHEN** the HUD is first drawn
- **THEN** the objective row reads "Arma la balsa: 0/6 madera"

#### Scenario: The sign note covers the row
- **GIVEN** a solo player, offline, with the objective row shown
- **WHEN** they open the hut note, and then close it
- **THEN** the objective row is hidden while the note is open and shows again after

#### Scenario: English
- **GIVEN** a solo player, offline, in English, with an empty inventory on the sandbar
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Build the raft: 0/6 wood"

### Requirement: Objective while building the raft
While the raft is not built, the objective row SHALL read the level's raft site and the local player's synced inventory. For the first input, in recipe order, whose count in the site plus the inventory is below the need: "Arma la balsa: N/M <noun>" (N that sum, M the need, the noun the item's short name). Once all are covered: "Lleva to' pa' la balsa" until the site holds them all, then "Dale a la balsa: P%", the build's progress. Solo, the counts are the player's own.

#### Scenario: Counting what is carried and what is in
- **GIVEN** a solo player, offline, carrying 4 driftwood, with 2 driftwood, 0 inner tubes and 0 rope in the raft site
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Arma la balsa: 0/2 cámaras"

#### Scenario: Everything in hand
- **GIVEN** a solo player, offline, carrying 6 driftwood, 2 inner tubes and 3 rope, with an empty raft site
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Lleva to' pa' la balsa"

#### Scenario: Building
- **GIVEN** a solo player, offline, whose raft site holds every input and is 40% built
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Dale a la balsa: 40%"

#### Scenario: A client's row follows the host's site
- **GIVEN** a host and a client on the sandbar, the client carrying nothing
- **WHEN** the host deposits 6 driftwood in the raft site
- **THEN** the client's objective row reads "Arma la balsa: 0/2 cámaras"

### Requirement: Objective at launch and at sea
While the local player has left the island on a crossing, the objective row SHALL read "Aguanta hasta tierra" ("Hold on till land"). Otherwise, while the island's raft is built and the launch would not wait for the dark ("Objective waits for the dark"), it reads the island's launch line (content-data "Launch lines"), or the default "Zarpa pa'l norte" ("Set off north"). With exactly 1 player, offline, the lines are the same.

#### Scenario: Built, then at sea
- **GIVEN** a solo player, offline, on the sandbar at night with the raft built
- **WHEN** the HUD is drawn, and again after they launch
- **THEN** the row reads "Zarpa pa'l cayo", then "Aguanta hasta tierra" for the whole crossing

#### Scenario: The coast cay uses the default line
- **GIVEN** a solo player, offline, who reached the coast cay with an intact raft, at night
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Zarpa pa'l norte"

### Requirement: Objective waits for the dark
While the island's raft is built, a patrol boat is out on the island and the day phase is one in which that boat's searchlight is off (dawn, day, dusk), the objective row SHALL read "Espera la noche pa' zarpar" ("Wait for dark to set off"), unless a squall or a weather that blinds sight is falling. It matches island-pressure's launch rule (owner, 2026-11-23): by day the patrol sees every launch; a squall keeps it in port. Solo, offline, the same.

#### Scenario: A solo player builds by day
- **GIVEN** a solo player, offline, on the sandbar at 09:00 with the raft built and a patrol boat out
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Espera la noche pa' zarpar"

#### Scenario: Night or a squall opens the window
- **GIVEN** the same player and boat
- **WHEN** the phase turns to night, or a squall starts falling by day
- **THEN** the objective row reads "Zarpa pa'l cayo"

#### Scenario: No boat, no wait
- **GIVEN** a solo player, offline, on an island with the raft built and no patrol boat out, at 09:00
- **WHEN** the HUD is drawn
- **THEN** the objective row reads the island's launch line

### Requirement: The objective keeps secrets
The objective row SHALL never name the island the party stands on, and never name, count or point at a secret item, the chest or the hidden cay (secret-cay "Secrecy"); it reads only the level's raft site and raft, never another build site. With exactly 1 player, offline, the same holds.

#### Scenario: Nothing secret
- **GIVEN** a solo player, offline, on the hidden cay carrying the map and the broken compass, with its raft site empty
- **WHEN** the HUD is drawn
- **THEN** the objective row reads "Arma la balsa: 0/6 madera" and names neither the cay, the chest, the map nor the compass

### Requirement: Raft-site arrow
While the current island's raft site or built raft has its centre outside the view, the local player's HUD SHALL draw one small arrow pointing at it, where the line from the view's centre to the site crosses the frame (8,96) to (632,300), which keeps it off the HUD's windows, the horizon band and the bottom band. It points at the level's site by its name, never at another build site or anything secret. Solo, it points from the player's own view.

#### Scenario: A solo player walks off
- **GIVEN** a solo run, offline, with exactly 1 player on the sandbar
- **WHEN** the player walks until the raft site is out of view to the west
- **THEN** an arrow on the frame's left edge points west at the site, and it goes away when the site comes back into view

#### Scenario: The arrow keeps off the windows
- **GIVEN** a solo player, offline, whose raft site lies far to the north-west, out of view
- **WHEN** the arrow is drawn
- **THEN** its rectangle lies inside (8,96) to (632,300) and overlaps none of the HUD's windows

#### Scenario: A client's arrow
- **GIVEN** a host and a client on the sandbar, the client's player standing where the raft site is out of view
- **WHEN** the client's HUD is drawn
- **THEN** the client's arrow points at the site from the client's own view, and the host's HUD shows no arrow while the site is in the host's view

### Requirement: When the raft-site arrow hides
The raft-site arrow SHALL be hidden while the site is on screen, while the local player has left the island on a crossing, while the crafting list or a sign note is open and while a screen is over the run. With exactly 1 player, offline, the same holds.

#### Scenario: No arrow at sea
- **GIVEN** a solo player, offline, on a crossing
- **WHEN** the HUD is drawn
- **THEN** no raft-site arrow shows
