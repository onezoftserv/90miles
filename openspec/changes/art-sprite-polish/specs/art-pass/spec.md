## MODIFIED Requirements

### Requirement: Swimmers at the water line
A swimming or floating player SHALL be drawn sunk so the water line lies on the feet line, with the rows above it at full opacity and the rows below it not drawn, an animated ripple ring (a dashed light oval wider than the shoulders) round the body at the line, and no drop shadow; the two swim frames differ above the line by a small bob; a diving player SHALL show only a small ripple ring where they are. A solo swimmer looks the same, and teammates see the same ring.

#### Scenario: Swim and dive
- **GIVEN** a solo player swimming in deep water
- **WHEN** they swim, then dive
- **THEN** while swimming only their upper body is drawn, the ripple ring marks the line and no shadow is drawn; while diving only the dive ripple ring is drawn

#### Scenario: The line is a cut, not a painted row
- **GIVEN** a solo player built for one offline player, swimming
- **WHEN** their frame is drawn through the player material
- **THEN** no texel on the water line is turned to the foam colour, every row below the line is clear, and the ring is its own sprite drawn under the body sprite

#### Scenario: A swimmer bobs
- **GIVEN** the composed look of slot 0
- **WHEN** its two swim frames of a facing are compared above the water line
- **THEN** they differ, and the swim head anchor is the same as before

### Requirement: Crossing look
The crossing SHALL draw the same sea in its deep-water step, scrolling with the crossing's own scroll, under everything in the crossing; the raft deck by its integrity, above the sea and under every rider; and riders in the water cut at the water line. A swimmer north of a drawn deck's or board's top edge, within its span, SHALL be drawn under that deck, so only their head shows above the planks; a swimmer beside it or south of it is drawn over it. A client and a late joiner draw it from the crossing state they already receive. A solo crossing looks the same.

#### Scenario: A solo raft crossing
- **GIVEN** a solo player who launched the raft
- **WHEN** the crossing runs and a squall throws them in
- **THEN** the open sea scrolls with the crossing, the deck shows the raft at its integrity, and the player is drawn over the sea, cut at the water line beside it

#### Scenario: Riders and the shark over the sea and the deck
- **GIVEN** a host and a client in a raft crossing with one rider aboard, one thrown in and the shark passing that swimmer
- **WHEN** both draw the crossing
- **THEN** on both peers the rider aboard is drawn over the deck, and the swimmer and the shark over the sea

#### Scenario: A solo swimmer north of the deck
- **GIVEN** a 1-player raft crossing, offline, whose player swims 1 px north of the deck's top edge, within its span
- **WHEN** the crossing is drawn
- **THEN** the player is drawn after the sea and before the deck, and once they swim to 1 px east of the deck, or climb aboard, they are drawn after it again

### Requirement: Facing variants for creatures
When a creature's frames have facing variants of an animation (`<name>_down`, `<name>_up`, `<name>_side`), the variant for its synced facing SHALL play, the larger of the horizontal and vertical facing winning; side variants are mirrored while it faces left. Frames without variants play as they are.

#### Scenario: A gull flying north
- **GIVEN** a test creature with the seagull's behaviour whose frames have `swoop_down`, `swoop_up` and `swoop_side`
- **WHEN** it swoops facing mostly up
- **THEN** it plays `swoop_up`, and so does the shipped seagull, whose flight frames have `swoop_*`, `flee_*` and `return_*` facings, while frames with only `idle_*` and `move_*` play `move_up`

## ADDED Requirements

### Requirement: Cover over a crouched body
A player on a scrub cell SHALL be drawn with that cell's bush in front of their body: the brush layer's exact tile at their cell, variant included, drawn over the body sprite at the cell's place and showing only the bush's front rows. Anything sorted in front of the player still draws over it; off scrub nothing is drawn. Every peer draws it, and the hidden state and its mark are unchanged. A solo player sees it on themself.

#### Scenario: A solo player crouches in scrub
- **GIVEN** a sandbar built for one offline player, the player crouched on a scrub cell
- **WHEN** they are drawn
- **THEN** the bush front is shown with the same tile, atlas coordinates and alternative as the brush layer at that cell, it is drawn after the body sprite, and a palm one cell south is drawn after both

#### Scenario: Off scrub
- **GIVEN** the same solo player
- **WHEN** they walk onto sand and then swim
- **THEN** no bush front is drawn

#### Scenario: A teammate in scrub
- **GIVEN** a host and a client, the client's player standing on a scrub cell
- **WHEN** both peers draw it
- **THEN** both show the bush front with the same tile at the same place

### Requirement: The fin stays off the deck
While a crossing shark is warned beside a vessel, circles it, strikes it or leaves, every drawn pixel of its frames SHALL lie outside each intact deck's and board's rect and inside the crossing's sea. Art never moves the shark: it is drawn at its synced position, bobbing at most 1 px in place, so the shoo point stays on the fin. A solo crossing looks the same.

#### Scenario: A solo raft crossing's shark pass
- **GIVEN** a 1-player raft crossing, offline, whose shark pass names the east side
- **WHEN** the fin is drawn on every frame from its warning to its retreat
- **THEN** the box of its frame's drawn pixels, at its drawn position, never overlaps the deck's rect and stays inside the sea's rect

#### Scenario: A solo board crossing's shark pass
- **GIVEN** a 1-player board crossing, offline, whose shark pass comes
- **WHEN** the fin is drawn from its warning to its retreat
- **THEN** its drawn box never overlaps any intact board's rect

### Requirement: The shark reads from every side
The reef shark SHALL be drawn as a fin over a tapered body under the water line, with the line marked by the fin's base and a broken foam dash rather than a solid bar, and SHALL have facing variants of its patrol, circle and move animations: side frames, and an edge-on fin for up and down. No frame's drawn pixels reach more than 15 px from its centre on either side, and the fin keeps its contrast on shallows and deep water. A solo player sees the same shark.

#### Scenario: A solo player sees a shark head north
- **GIVEN** a sandbar built for one offline player, its reef shark patrolling and heading mostly north
- **WHEN** it is drawn
- **THEN** it plays `patrol_up`, an edge-on fin, and when it turns east it plays `patrol_side` unmirrored

#### Scenario: No solid foam bar
- **GIVEN** every side frame of the shark sheet
- **WHEN** the water-line row is read
- **THEN** no run of opaque pixels on it is longer than the fin's base plus a short dash

### Requirement: Crab frames
The land crab SHALL be drawn narrower than its cell (about 12–13 px of its 16), asymmetric with one big claw, its feet on the cell's bottom row and its shell dark red; it idles on frames 0, 1, 0, 2 at 4–5 fps and scuttles on 4 frames at no more than 12 fps, within the creature frame budget. A solo player sees it.

#### Scenario: A solo player watches a crab
- **GIVEN** a sandbar built for one offline player, with a crab standing still and then walking
- **WHEN** it is drawn
- **THEN** it plays `idle` on 3 unique frames in the order 0, 1, 0, 2 at 4–5 fps and then `move` on 4 frames at no more than 12 fps, and no frame has an opaque pixel in its outer columns

### Requirement: Gull flight frames
A flying gull SHALL be drawn from flight frames wider than its 16 px standing cell, with bent wings whose tips never touch the frame's edge, lifted 14–16 px above its shadow, which stays on the ground. Standing and perched frames keep their cells. A solo player sees the same flight.

#### Scenario: A solo player is swooped
- **GIVEN** a sandbar built for one offline player and a gull that swoops
- **WHEN** it is drawn while swooping
- **THEN** it plays a flight animation for its facing, its frame has no opaque pixel in its outer columns, and its feet are 14–16 px above its shadow on the ground

### Requirement: Lying pose
A downed, dragged or dead player SHALL be drawn lying along the ground with the face upright, the eyes side by side, made by a pose rule from the walk frame so every look part follows with no hand pixels, and with a lying shadow about 22–24×5 px in place of the standing one. The downed pose keeps its breath frame and dead keeps none. A solo player sees their own lying pose.

#### Scenario: A solo player is downed
- **GIVEN** a sandbar built for one offline player
- **WHEN** the player is downed
- **THEN** their body plays the lying downed frames, wider than tall, and the shadow under it is the lying size, not the 12×7 standing size

#### Scenario: Every look part lies the same way
- **GIVEN** every look part sheet
- **WHEN** the lying rule is applied per layer and the layers are composited
- **THEN** the result equals the rule applied to the composite
