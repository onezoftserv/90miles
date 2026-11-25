## ADDED Requirements

### Requirement: Crossing rocks and debris look
The crossing SHALL draw each rock and each piece of debris on the sea from its own hand-drawn art: an outlined body exactly as wide as the lane it hits, at the vessel's pixel scale, centred where the crossing places it, with a foam collar at its waterline that reaches at most 2 px past it a side. Each outline ring and collar reaches 3:1 on the deep ground, and no hazard uses the fin's white foam. A solo crossing draws the same.

#### Scenario: A solo raft crossing's rock and debris
- **GIVEN** one offline player on a raft crossing whose plan brings a rock in one lane and debris in another
- **WHEN** both are on the sea
- **THEN** each is drawn from its art, centred on the place the crossing gives it, its outlined body exactly its lane's width, with a collar at its waterline in light foam colours that are not white

#### Scenario: Readable on deep water
- **GIVEN** the rock, the debris and their collars
- **WHEN** their contrast is measured against the deep ground
- **THEN** each outline ring and each collar reaches at least 3:1

### Requirement: Crossing leak look
The crossing SHALL draw each open leak as a jet of water rising from a dark crack, at the leak's place, over the deck and under the riders. A solo crossing draws the same.

#### Scenario: A solo raft crossing's leak
- **GIVEN** one offline player aboard a raft crossing with an open leak
- **WHEN** it is drawn
- **THEN** a jet rising from a dark crack is drawn at the leak's place, over the deck and under the rider

### Requirement: Crossing hazard frames and drawing only
The hazards' collar and jet frames SHALL step with the crossing's plan clock, so every peer, a late joiner included, draws the same frame at the same moment. The hazards' drawing changes nothing the crossing simulates: a hazard's hit width, lane, timing, warning lead and drain stay the crossing's, and nothing drawn moves a hazard off its place. A solo crossing behaves the same.

#### Scenario: The same frames on every peer
- **GIVEN** a host and a client in a raft crossing with a rock on the sea and an open leak
- **WHEN** both draw it at the same plan time
- **THEN** both show the same collar frame and the same jet frame at the same places

#### Scenario: Drawing changes nothing the crossing simulates
- **GIVEN** a solo raft crossing with rocks, debris and a leak
- **WHEN** it runs with the hazards drawn and again with their drawing turned off
- **THEN** the vessel's integrity, the riders' states and every hazard's lane and time are the same in both runs
