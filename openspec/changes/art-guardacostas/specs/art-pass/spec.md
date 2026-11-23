## ADDED Requirements

### Requirement: Shore soldier look
Every peer SHALL draw each shore soldier as a person of the people pack recoloured into an olive uniform, boots and a patrol cap, outlined in black. Three looks tell soldiers apart by skin and build, and each soldier keeps one look, the same on every peer. Soldiers walk with the player's walk frames, stand still when still and face the way they move. Drawing reads the soldier's synced state only. A solo player sees the same soldiers.

#### Scenario: A solo player meets the squad
- **GIVEN** a solo player on the sandbar whose spot brings a squad
- **WHEN** the three soldiers walk up the beach
- **THEN** each is drawn as an olive-uniformed figure with a cap, about as tall as the player, in a walk facing its motion, and no two of the three share a look

#### Scenario: A client sees the same soldier
- **GIVEN** a host and a client on the sandbar with a squad ashore
- **WHEN** both peers draw the island
- **THEN** each soldier shows the same look on both peers, and the client draws it from the synced position and state alone

#### Scenario: Outlined like an actor
- **GIVEN** the composed frames of every soldier look
- **WHEN** their edge pixels are read
- **THEN** every edge pixel is the palette's black

### Requirement: Patrol boat and dinghy look
Every peer SHALL draw the patrol boat, while it is in sight, as a launch whose opaque bounds are wider and taller than the raft's frame, seen side-on and mirrored by its heading, with its searchlight starting at the lamp on its roof. Its dinghy, while out, SHALL show with oars: rowing between the boat and the landing, and lying on the landing beach while the squad is ashore, sorted by its own place on the beach. Both are outlined in black.

#### Scenario: The boat is bigger than the raft
- **GIVEN** the boat's frames and the raft's frames
- **WHEN** their opaque bounds are measured
- **THEN** the boat's are wider and taller than the raft's in every frame

#### Scenario: A solo player sees the dinghy land
- **GIVEN** a solo player on the sandbar whose spot brings a squad
- **WHEN** the dinghy reaches the landing and the squad steps ashore
- **THEN** the dinghy shows rowing on the way in, then lying on the landing beach with its oars in, and a player walking past it sorts in front of or behind it by foot position

#### Scenario: A client sees the dinghy beached
- **GIVEN** a host and a client on the sandbar with a squad ashore
- **WHEN** both peers draw the island
- **THEN** both show the dinghy lying at the same landing cell and the boat docked offshore, and drawing them changes no synced value

### Requirement: Searchlight edge
Every peer SHALL draw the searchlight's cone with a soft rim centred on the true edge of the cells it lights: every lit cell shows the light at half its strength or more, and no light shows beyond the rim's outer half. A solo player sees the same cone.

#### Scenario: Lit cells look lit
- **GIVEN** the cone drawn for the patrol boat's searchlight at night
- **WHEN** each cell the searchlight lights and each cell beyond its rim is read
- **THEN** every lit cell's centre is drawn at half strength or more, and no cell more than the rim's outer half beyond the edge is drawn lit

#### Scenario: A solo player at the edge
- **GIVEN** a solo player at night standing just inside the cone's edge
- **WHEN** the beam holds still on them
- **THEN** light shows on the sand under them and their spot meter fills
