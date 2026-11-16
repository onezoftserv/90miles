## MODIFIED Requirements

### Requirement: Lean-to over the hut
The sandbar's hut SHALL be drawn as a palm-frond lean-to standing on the hut's back edge, its posts and roof rising over the row north of it, so everything on the hut's cells, its pick-ups and whoever stands there, draws in front of it and only what is north of the hut goes behind the roof. The lean-to reads as a frond shelter: a ragged eave whose frond tips hang below it, closed top corners with nothing showing through, and a contact shadow at each post's foot. The hut's shade is darkest at its north edge, under the roof, and fades south, and every shaded cell keeps its shade. Which layouts get a shelter, and which shelter, is art data: the sandbar and the hidden cay get the lean-to, and the coast cay's watch post gets a ruined garita ("A garita over the watch post"). A solo player in the hut stays visible.

#### Scenario: Standing in the hut
- **GIVEN** a solo player standing on the hut's back row beside its tarp and driftwood
- **WHEN** the hut is drawn
- **THEN** the player, the tarp and both driftwood are drawn in front of the lean-to, on the shade decal

#### Scenario: Behind the roof
- **GIVEN** a solo player one tile north of the hut
- **WHEN** the hut is drawn
- **THEN** the lean-to's roof is drawn over them

#### Scenario: The shade is darkest under the roof
- **GIVEN** the sandbar built for one offline player
- **WHEN** the shade decals of the hut's shaded cells are read
- **THEN** all 12 shaded cells have a shade decal, and on each the shade's alpha is highest on its north rows and falls toward the south

#### Scenario: A closed roof
- **GIVEN** the lean-to's frame
- **WHEN** its pixels are read
- **THEN** the frame keeps its 64×48 size and its anchor, no transparent pixel lies inside the roof's outline, and the eave's lowest row is not one straight run across the frame

## ADDED Requirements

### Requirement: A garita over the watch post
The coast cay's watch post SHALL be drawn as an open-front, ruined concrete garita standing on the post's back edge over its shaded cells, with a faded slogan band and no legible letters. Everything on the post's cells draws in front of it, and only what is north of the post goes behind its roof. It is drawing only: no cell becomes solid. A solo player at the post stays visible.

#### Scenario: A solo player inside the garita
- **GIVEN** the coast cay built for one offline player, standing on the post's back row beside its nails, its mirror and the radio
- **WHEN** the post is drawn
- **THEN** the garita is drawn behind the player, the pick-ups and the signs, and every post cell is as walkable as with no art

#### Scenario: The garita's look
- **GIVEN** the garita's frame
- **WHEN** its pixels are read
- **THEN** it has low walls on the back and sides and none in front, two posts, a sagging tin edge, a dark window hole and a red slogan band, and it is no taller than 48 px

#### Scenario: Behind the garita's roof
- **GIVEN** the coast cay built for one offline player, standing one tile north of the post
- **WHEN** the post is drawn
- **THEN** the garita's roof is drawn over them

### Requirement: Signs show what they are
An island sign SHALL be drawn by its data's optional look: a dead radio on a crate, two crossed sticks in a sand mound, a concrete fragment with a painted band, or, with no look or an unknown one, today's board. A new look is an art data entry with no script edit. The coast cay's radio, its two wall slogans and its crossed sticks use their looks. A solo reader sees the same signs.

#### Scenario: The coast cay's signs, solo
- **GIVEN** the coast cay built for one offline player
- **WHEN** its four signs are drawn
- **THEN** the radio sign shows the radio, the two slogans show the slogan fragment, the crossed-stick sign shows the sticks, and reading any of them opens its note as before

#### Scenario: A sign with no look
- **GIVEN** a layout whose sign has no look
- **WHEN** it is drawn
- **THEN** it shows the board

### Requirement: The hidden cay's scenery is drawn
Each scenery cell of a handmade layout SHALL be drawn from art data keyed by its decor id and its terrain: upright pieces as sprites sorted by foot position with the actors, flat pieces under every actor, and a waterline foot on a piece in the shallows. A decor id with no art still draws its layout colour, so a new decor kind stays a data edit. Nothing drawn reads as a grave or a memorial. A solo player sees the same scene.

#### Scenario: A solo player on the hidden cay
- **GIVEN** the hidden cay built for one offline player
- **WHEN** its scenery is drawn
- **THEN** the embers, the smoking stub with its wisp, the drag mark, the cut line, the post with its waterline foot and Platino on the chest's ledge each show their piece, none as a coloured square, and the post and Platino sort with the player by foot position

#### Scenario: A decor kind with no art
- **GIVEN** a layout with a decor id that has a colour and no art entry
- **WHEN** it is drawn
- **THEN** its cell shows its colour square, with no script edited

### Requirement: Outline colour by family
Characters, creatures, item icons and pick-ups SHALL be outlined in the palette's black, the only outline colour that reaches 3:1 against deep water. Structures and scenery SHALL be outlined in one of the palette's dark tones. The art check reads each sheet's family from its folder and names any file and pixel that breaks the rule.

#### Scenario: A plum-rimmed creature
- **GIVEN** a creature sheet whose edge pixels are the plum outline colour
- **WHEN** the art check runs
- **THEN** it fails and names the file and the pixel, while the same plum edge on a structure passes

#### Scenario: The solo player's look
- **GIVEN** the look of a solo player
- **WHEN** its composed frames are checked
- **THEN** every outline pixel is black

### Requirement: Item icons read at a glance
Every part of an item icon SHALL be at least 3 px thick, so the outline never swallows it, and outline pixels are at most half of an icon's opaque pixels. The nails, the tarp, the cooked crab, the cooked hutía and the cooked iguana are redrawn to meet it, and the dry-grass sheaf is kept. A solo player sees the same icons.

#### Scenario: Thick enough to read
- **GIVEN** every item icon
- **WHEN** its opaque and outline pixels are counted
- **THEN** no icon is more than half outline, and no two icons share a silhouette

#### Scenario: A solo player picks up nails
- **GIVEN** a solo player on the coast cay's post
- **WHEN** they pick up the nails
- **THEN** the redrawn nails icon shows on the ground and then in their strip slot

### Requirement: Palms vary
Each palm SHALL be drawn in one of several looks picked from a hash of the layout and its cell, never from a random generator the simulation uses, so every peer and every rebuild shows the same palm. Every look keeps its trunk base on the palm's position, its foot shade centred under it, and its nest and perch point at the same height, so a perched gull and the coconuts sit where they did. A solo player sees the same palms.

#### Scenario: The sandbar's palms, solo
- **GIVEN** the sandbar built for one offline player, twice
- **WHEN** its six palms are drawn
- **THEN** more than one look is used, every palm has the same look both times, and every nest palm's nest point is at the same height

#### Scenario: A gull perches on any look
- **GIVEN** a solo player near a nest palm of each look
- **WHEN** a gull perches
- **THEN** it stands on the crown's nest point of that look, drawn over the crown

### Requirement: The rain catcher shows its tarp
The rain catcher SHALL be drawn with a tarp funnel tied over its barrel in every frame, the water showing in the funnel's mouth while it holds at least one cup, in the same frame size. A solo player sees the same.

#### Scenario: A solo player's catcher fills
- **GIVEN** a solo player who built a rain catcher
- **WHEN** it is empty and then holds one cup
- **THEN** both frames show the tarp funnel, and the second shows water in its mouth
