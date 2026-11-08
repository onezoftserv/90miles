# Spec Delta

## Purpose

A rare, optional secret: a map and a broken compass hidden on two mid-run islands lead the party to a tiny hidden cay whose chest holds only a joke note, next to a yarey hat with a red band. It costs a detour and gives laughs, never power, and works for one player offline.

## ADDED Requirements

### Requirement: Secret tuning data
Every number of the secret, which items are its two pieces, the feature kinds hiding spots are measured from and the map's hint phrases SHALL live in one tuning data file, so tuning never needs a script edit. The reveal radius is each item's own concealment radius, not a tuning value. The same values apply with 1 player and with 4.

#### Scenario: The shipped values
- **WHEN** the secret tuning file is read
- **THEN** it names `mapa_sin_norte` as the map and `brujula_rota` as the compass, and holds run chance 0.33, run indices 2 to 5, a shimmer of 0.75 s every 6 s, a concealed pick-up hold of 1.5 s, needle band edges at 40, 20, 11 and 6 tiles with wobbles of ±90°, ±45° and ±20°, a spin of 0.5 turn/s, a chest hold of 1 s, a note time of 6 s plus 50 ms per character, hiding spots between the 50th and 85th percentile of land walking distance and 4 to 10 tiles from a feature, a fallback band from the 25th to the 100th percentile, the feature kinds palm, pick-up, tide pool, workbench and raft site, and a Spanish and an English hint phrase for every spot kind plus a default

#### Scenario: Retuning is a data edit
- **GIVEN** the tuning file with the shimmer period changed from 6 s to 4 s and no script edited
- **WHEN** a concealed item lies on an island in a solo offline game
- **THEN** it shimmers every 4 s

### Requirement: Secret items
The broken compass, the map without north, the red-band yarey hat and the late note SHALL be marked secret, and so SHALL the hidden cay. Secret means only "never shown by any discovery, map, marker or AI system, and never picked by an item-tag spawn or by found-text placement"; each of the four items has a spawn weight of 0. The compass and the map are also concealed, each with a reveal radius of 3 tiles; the hat and the note are not concealed. Only the compass points to secrets.

#### Scenario: The four items from data
- **WHEN** the four item files are loaded
- **THEN** all four carry the secret tag and a spawn weight of 0, the compass and the map have a reveal radius of 3 tiles, the hat and the note have none, and only the compass has the point-to-secret capability

#### Scenario: The compass line
- **WHEN** the broken compass's Spanish description is read
- **THEN** it is "La única brújula que nunca te manda pa'l Norte."

### Requirement: Existence roll
Once per run the host SHALL roll from the run seed whether the run holds the secret, once for the pair. On success both pieces are always placed, one per island, on two different run indices inside the tuning window (2 to 5), so never on the sandbar or the final approach. The same seed always gives the same answer. A 1-player run rolls the same way. Whether seeded and daily runs roll at all is open (design.md open question 3); the roll itself is defined for any seed.

#### Scenario: One run in three
- **GIVEN** the shipped tuning (run chance 0.33)
- **WHEN** the roll is made for 3,000 different seeds
- **THEN** between 30% and 36% of them hold the secret, and every one that does places the map and the compass on two different indices from 2 to 5

#### Scenario: Same seed, same plan
- **GIVEN** a seed whose roll succeeded with the map on index 3 and the compass on index 5
- **WHEN** the roll is made again from that seed in a solo offline game
- **THEN** it succeeds again with the map on index 3 and the compass on index 5

#### Scenario: Never and always
- **GIVEN** a tuning file with run chance 0, then one with run chance 1
- **WHEN** the roll is made for 100 seeds with each
- **THEN** no run holds the secret with chance 0, and every run holds both pieces with chance 1

### Requirement: Hiding spots
A piece SHALL hide on a land cell (beach, dune or scrub) reachable on foot or wading from the landing, the layout's solo spawn. Walking distance wades through shallows; its percentiles count reachable land cells only. A spot lies between the 50th and 85th percentile of that distance, 4 to 10 tiles in a straight line from the nearest feature of a kind the tuning lists (palm, non-secret pick-up, tide pool, workbench, raft site), on no feature or spawn cell. One player can reach every spot.

#### Scenario: The dev hunt island's spots
- **GIVEN** the dev hunt layout and its solo spawn
- **WHEN** its hiding spots are listed by the strict rule
- **THEN** there are at least two, and each is a land cell reachable on foot or wading from the solo spawn, lies between the 50th and 85th percentile of land walking distance from it, is 4 to 10 tiles from the nearest feature of a listed kind, and is on no feature or spawn cell

### Requirement: Hiding-spot fallback
When no cell meets the hiding-spot rule, the rule SHALL relax in order until one does: first the walking band widens to the tuning's fallback band (25th to 100th percentile), then the feature-distance limit is dropped, then any reachable land cell that is not a feature or spawn cell is accepted, so an island with such a cell always receives its piece. The same holds with 1 player.

#### Scenario: A small, crowded island still gets its piece
- **GIVEN** a small inline layout on which every land cell is within 3 tiles of a palm or a pick-up
- **WHEN** its hiding spots are listed in a solo offline game
- **THEN** the list is not empty, and every cell in it is reachable land on no feature or spawn cell

### Requirement: Spot pick
The host SHALL pick each piece's spot uniformly from the hiding-spot list with the seed, and every peer shows the piece on that cell. In real runs each island holds a single piece; only the dev hunt layout holds both, on different cells. A solo player is their own host.

#### Scenario: A solo hunt from a fixed seed
- **GIVEN** one offline player in the dev hunt scene with a fixed seed
- **WHEN** the pieces are placed twice from that seed
- **THEN** the map and the compass lie on two different hiding spots, the same two cells both times

#### Scenario: Host and client agree on the spot
- **GIVEN** a host and a client in the dev hunt scene with a fixed seed
- **WHEN** the host places the map and the compass
- **THEN** both lie on different hiding spots, and the client sees each at the same cell as the host

### Requirement: Map hint
The map's text SHALL fill its landmark slot with the tuning's hint phrase for the kind of spot where this run's compass hides (the kind of the spot's nearest listed feature, such as a palm, the flotsam or the hut; a kind with no phrase takes the default phrase), and never name the island or the cell. Until an inventory panel exists, when any player picks up the map every peer shows the filled text on the note label, in that peer's language. A solo player sees it on their own screen.

#### Scenario: A solo player reads where the compass hides
- **GIVEN** one offline player in Spanish in the dev hunt scene, whose compass lies on a hiding spot whose nearest feature is a palm
- **WHEN** they pick up the map
- **THEN** the note label shows the map's text with the palm phrase in its landmark slot, and no cell or island

#### Scenario: A hint that is not a palm
- **GIVEN** one offline player in Spanish whose compass lies on a hiding spot whose nearest feature is flotsam
- **WHEN** they pick up the map
- **THEN** the note label shows the map's text with the flotsam phrase in its landmark slot, and the text contains no "palma"

### Requirement: Concealment
A concealed item lying on the ground SHALL draw nothing distinct, apart from its shimmer, while every player is farther than its reveal radius (straight-line distance in tiles), and draw normally once any player is within it. Each peer decides this alone from the positions it already receives, so a modified client can learn where the pieces lie; that is accepted. Concealment never hides an item from the host's pick-up rules. Solo, the one player's position decides.

#### Scenario: Revealed by walking close
- **GIVEN** one offline player 5 tiles from the concealed map, with a tuning copy whose shimmer length is 0
- **WHEN** they walk until they are 3 tiles from it
- **THEN** the map was drawn as nothing distinct at 5 tiles and is drawn normally at 3 tiles

#### Scenario: A teammate's approach reveals it for everyone
- **GIVEN** a host and a client, the host's player 20 tiles from the concealed compass
- **WHEN** the client's player comes within 3 tiles of it
- **THEN** both peers draw the compass normally

### Requirement: Shimmer
A concealed item SHALL shimmer for the tuning's shimmer length every shimmer period (0.75 s every 6 s), from its own phase, drawn wherever it is on screen at any distance from the players. Nothing else marks it: no decal, no outline, no sound. With 1 player the shimmer is the same.

#### Scenario: A solo player spots the glint from afar
- **GIVEN** one offline player 15 tiles from the concealed map, both on screen, and the map's phase set so that a shimmer starts at 0 s
- **WHEN** 12 s pass with the player standing still
- **THEN** the map started a shimmer exactly twice, at 0 s and at 6 s, each lasting 0.75 s, and drew nothing distinct the rest of the time

### Requirement: Concealed pick-up hold
Picking up an item whose reveal radius is above 0 SHALL take holding interact for the tuning's hold (1.5 s) instead of an instant press; releasing early takes nothing and the next hold starts from 0. The host applies the pick-up as for any item. One player needs no help.

#### Scenario: A solo player digs out the compass
- **GIVEN** one offline player within 1 tile of the compass, with room in their inventory
- **WHEN** they hold interact for 1 s and release, then hold it for 1.5 s
- **THEN** the compass is still on the ground after the first hold and in their inventory after the second

#### Scenario: A client digs it out
- **GIVEN** a host and a client whose player stands within 1 tile of the map
- **WHEN** the client holds interact for 1.5 s
- **THEN** the host puts the map in the client's inventory and it is gone on both peers

### Requirement: The broken compass is never a compass
The broken compass SHALL never steer a vessel, cancel or cut drift, or count as the compass in compass plus charts; the map SHALL never count as charts and never reveal a layout, a route or a point of interest. Both work the same for 1 player as for 4.

#### Scenario: A solo crossing with both pieces
- **GIVEN** a 1-player run whose Pescador carries the broken compass and the map, with no compass or charts
- **WHEN** the crossing's drift is worked out
- **THEN** it is the same as for a player carrying neither

### Requirement: Needle on the carrier's HUD
While the local player carries an item with the point-to-secret capability, their HUD SHALL show a 24×24 px needle at the top centre, under the day phase, inside the 640×360 HUD budget and clear of the meters, the teammate list, the centre and the bottom band. Other players' screens do not show it. A solo player sees it on their own HUD.

#### Scenario: A solo player picks up the compass
- **GIVEN** one offline player with no compass and no needle on screen
- **WHEN** they pick up the broken compass
- **THEN** a 24×24 px needle shows top-centre under the day phase

#### Scenario: Only the carrier sees it
- **GIVEN** a host and a client, the client's player carrying the compass
- **WHEN** both HUDs are drawn
- **THEN** the client's HUD shows the needle and the host's does not

### Requirement: Needle target
The needle SHALL point from its carrier to the nearest concealed item lying on the island; with none, to the island's unopened chest; with neither, it spins at the tuning's spin (0.5 turn/s). It ignores north (it is never a compass) and never points at an item someone carries. With 1 player the target is the same.

#### Scenario: Pointing at the map, then spinning
- **GIVEN** one offline player holding the compass in the dev hunt scene, the map lying 5 tiles due east
- **WHEN** the needle is drawn, and again after the player picks up the map
- **THEN** it first points due east and holds still, then spins at 0.5 turn/s

#### Scenario: Pointing at the chest
- **GIVEN** one offline player holding the compass on the cay with the chest unopened
- **WHEN** the needle is drawn, and again after the chest opens
- **THEN** it first points at the chest, then spins

### Requirement: Needle bands
The needle SHALL steady with the straight-line distance in tiles from its carrier to its target: beyond 40 tiles it spins; within 40 it wobbles ±90° around the bearing, within 20 ±45°, within 11 ±20°, and within 6 it holds still. It rattles once on entering 40 tiles and can rattle again only after going back beyond 40. With 1 player the bands are the same.

#### Scenario: A solo player walks in
- **GIVEN** one offline player holding the compass 44 tiles from the concealed map
- **WHEN** they walk straight to it
- **THEN** the needle spins at 44 tiles, wobbles ±90° at 30, ±45° at 15, ±20° at 8 and holds still at 4, and it rattled exactly once

#### Scenario: Leaving re-arms the rattle
- **GIVEN** a player holding the compass who entered 40 tiles of the map and heard the rattle
- **WHEN** they walk out to 44 tiles and back to 38
- **THEN** the needle rattles a second time

### Requirement: Secrecy
Secret things SHALL never be shown, listed or hinted by charts, binoculars, the lighthouse top, keepsakes, NPC reveals, route discovery, map knowledge carried between runs, HUD markers, item-tag spawns, found-text placement or any AI context. Only the needle and the map's hint lead to them. This holds with 1 player.

#### Scenario: No weighted pick can draw a secret item
- **WHEN** the four secret items' spawn weights are read in a solo offline game
- **THEN** each is 0, so an item-tag spawn picking by spawn weight can never choose one

### Requirement: One shared secret check
Every system that shows something or draws from a list of items or layouts SHALL ask one shared check whether an entry is secret, and pass its list through one shared filter that drops secret entries. Each such system adds its own test when it is built (design.md "Later"). The check and the filter work the same with 1 player.

#### Scenario: The shared check and filter
- **GIVEN** the four secret items, the cay layout, driftwood and the sandbar layout, in a solo offline game
- **WHEN** the shared secret check and the shared filter run on them
- **THEN** the check is true for the four items and the cay and false for driftwood and the sandbar, and filtering a list of all six leaves only driftwood and the sandbar

### Requirement: The hidden cay
The hidden cay SHALL be a handmade layout of at least 40×23 tiles, marked secret and off-graph: a sand teardrop ringed by reef shallows and deep water, landing at the south end, the chest on the land (non-shallows) cell farthest by walking from the solo spawn (any one of them on a tie), a palm-frond lean-to as the only shade. No creature, patrol or set piece ever appears on it, but the meters keep draining. Solo lands alone at its solo spawn.

#### Scenario: The cay loads
- **WHEN** the cay layout is built
- **THEN** it is 48×27 tiles with no problems, is marked secret and off-graph, has 3 palms holding 7 coconuts, its shade cells are the lean-to's, its chest is on a land cell whose walking distance from the solo spawn is the greatest of any land cell, and it places no creature or patrol

#### Scenario: Arriving together
- **WHEN** the cay's solo and co-op spawn points are read
- **THEN** each is on sand at the south end and every pair of co-op spawns is within 5 tiles

### Requirement: He left minutes ago
The cay SHALL show that its last visitor left minutes ago and is coming back: warm embers by the lean-to, a cigar stub still smoking, a fresh raft-drag mark from the camp to the waterline, a cut mooring line on a post, and the hat hanging on the lean-to. Nothing on it is a grave, a marker, a stake, an empty raft or a memorial. One player sees the same scene.

#### Scenario: The scenery from data
- **WHEN** the cay layout is built
- **THEN** it holds the embers, the smoking stub, the drag mark reaching a shallows cell and the cut line, and the hat's cell is a lean-to cell

### Requirement: A lone player can live and leave
The cay SHALL let exactly 1 offline player who arrives with an empty inventory drink, eat and leave alone: its pick-ups hold at least the raft recipe's inputs, read from the recipe file, plus a knife and 1 or 2 rain cups, beside 3 palms with 7 coconuts and the lean-to's shade; a raft build site and the raft route, its only route, stand on its beach.

#### Scenario: Empty-handed and alone
- **GIVEN** one offline player with an empty inventory and thirst and hunger at 50 on the cay
- **WHEN** they pick up the knife and a rain cup, climb a palm, drink the rain cup and drink the coconut
- **THEN** thirst is above 50 and hunger is above 50

#### Scenario: Enough for the raft
- **GIVEN** the raft recipe's inputs read from its file (today 6 driftwood, 2 inner tubes and 3 rope)
- **WHEN** the cay's pick-ups are counted
- **THEN** each input is covered at least once, and one offline player who takes them all can deposit them in the raft site, build the raft alone and launch it

### Requirement: Fixed cay contents
The cay's palms, coconuts and pick-ups SHALL be the same for 1, 2, 3 and 4 players and at every Experiencia level: no party-size scaling and no per-island bonus changes them, and no pick-up respawns after a squall or a night.

#### Scenario: Four players, Experiencia level 5
- **GIVEN** a 4-player run at Experiencia level 5
- **WHEN** the cay is set up
- **THEN** it holds the same 7 coconuts and the same pick-ups as for one player at level 0

### Requirement: Empty chest
The chest SHALL stand on the chest cell on every peer. Holding interact on it for the tuning's chest hold (1 s) opens it, once in the run: the note appears as a pick-up beside it and nothing else. It is never opened again, broken, moved, burned or looted, and the hat is never inside it. One player opens it alone.

#### Scenario: A solo player opens it
- **GIVEN** one offline player within 1 tile of the closed chest
- **WHEN** they hold interact for 1 s, then hold it again
- **THEN** the chest is open with exactly one note lying beside it, and the second hold changes nothing

### Requirement: Same chest for everyone
The host SHALL decide the opening and pick the note's entry once, and every peer SHALL show the chest open with that entry, including a peer whose player joins after it opened. A client never opens it itself. A solo player is their own host.

#### Scenario: Host and client see one opening
- **GIVEN** a host and a client next to the closed chest
- **WHEN** the client holds interact on it for 1 s
- **THEN** the chest is open on both peers with the same entry, and one note lies beside it

#### Scenario: A late joiner sees it open
- **GIVEN** a hosted cay run whose chest the host opened with entry `ni_el_norte`
- **WHEN** a client joins afterwards
- **THEN** the client's chest is open with entry `ni_el_norte`, and no second note appears

### Requirement: Note on the HUD until the reading panel
When the chest opens, each peer whose player is in the run SHALL show the chosen entry's body in that peer's language (Spanish unless English is set; its soft variant once a profanity setting exists) on a HUD label below the needle's place at the top centre, for 6 s plus 50 ms per character. The reading panel replaces this later. A solo player sees it on their own HUD.

#### Scenario: A solo player reads the note
- **GIVEN** one offline player in Spanish who opens the chest, and the chosen entry's Spanish body is 120 characters long
- **WHEN** the chest opens
- **THEN** the label shows that body for 12 s and then hides

### Requirement: The late note
The note SHALL hold 5 handwritten entries, Spanish first with English, each with a heading and a body, picked one at random per opening; none is ever AI-generated. An entry has soft variants only where its body has profanity (none today, so the soft bodies stay empty, which means already clean). The same note serves 1 player and 4.

#### Scenario: The entries from data
- **WHEN** the note's file is loaded
- **THEN** it is handwritten, has 5 entries with Spanish and English headings and bodies, and every soft body is empty

### Requirement: The note's voice
Each entry SHALL read as written by someone alive who left minutes ago and names a return on Thursday; exactly one says the hat has an owner who said he is coming back for it. No entry names a franchise, a character or a real person. One player reads the same entries.

#### Scenario: Alive and coming back
- **WHEN** the note's entries are read
- **THEN** every Spanish body mentions "jueves", and exactly one, `el_sombrero`, mentions that the hat has an owner

### Requirement: The red-band yarey hat
The cay SHALL hold one yarey hat with a plain red band, for any party size, taken by whoever picks it up first. Its data gives the yarey hat's heat −30% in the sun (heat gain ×0.7) and lists no weather that knocks it off (a chin cord). Its text names no owner; that wink lives only in the note. One player can take it alone.

#### Scenario: The hat from data
- **WHEN** the hat's file is loaded
- **THEN** it is a head-slot wearable with heat gain ×0.7, no weather that knocks it off, and a description that names no owner

#### Scenario: One hat for four players
- **GIVEN** a 4-player hosted cay run
- **WHEN** two players try to pick up the hat at once
- **THEN** exactly one of them holds it and no second hat exists

### Requirement: A leaver's secret items
When a co-op player is removed from the run (a client that stayed disconnected), the host SHALL lay every secret item that player carried on the ground at the player's last position, so the secret never leaves the run with them. A player who had already left the island by a route is skipped: their items left with them, and what a disconnect at sea does belongs to the crossing work. With 1 player there is no client to remove, and death ends the run.

#### Scenario: A client leaves holding the compass
- **GIVEN** a host and a client whose player carries the broken compass at a known position
- **WHEN** the client disconnects and its player is removed after the downed time
- **THEN** the compass lies on the ground at that last position on the host, and any peer still in the run sees it there

#### Scenario: A rider who already left the island
- **GIVEN** a host and a client whose player carries the broken compass and has left the island by a route
- **WHEN** the client disconnects and its player is removed
- **THEN** no compass is laid on the island

### Requirement: Dev scenes for the hunt and the cay
Two dev scenes SHALL be playable solo offline and as host plus client, each with the run HUD bound to its local player: the hunt, which places both pieces on the dev hunt layout by the hiding-spot rule from a fixed seed, and the cay, which builds the cay layout. Neither layout is offered by any run, and nothing in a real run changes.

#### Scenario: Both scenes start solo
- **WHEN** each dev scene starts in solo mode offline
- **THEN** it builds its own layout with the player at its solo spawn, no network port opens, its run HUD holds the needle and the note label, and the hunt holds the concealed map and compass

#### Scenario: Real runs are unchanged
- **WHEN** a solo run starts from the title screen
- **THEN** it starts on the sandbar with no secret item placed
