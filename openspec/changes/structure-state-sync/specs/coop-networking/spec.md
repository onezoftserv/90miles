## ADDED Requirements

### Requirement: Structure state on every peer
The host's state of each palm (coconuts left), fire (lit or out) and rain catcher (cups waiting) SHALL reach every client in the run when it changes, and a client SHALL show that state: its look, whether it can be used, and whether a fire counts as lit there. A client never changes these itself. Exactly 1 player, offline, is their own host: their structures behave as before and nothing is sent.

#### Scenario: A solo player's structures
- **GIVEN** one offline player on the sandbar beside a palm with 2 coconuts, a lit fire they built and a rain catcher
- **WHEN** they climb the palm, a squall fills the catcher for 30 s, they take the cup and they put the fire out
- **THEN** the palm has 1 coconut, they carry the rain cup and the catcher holds none, the fire is out and no longer a lit fire, and no structure message was sent

#### Scenario: A client sees a palm climbed on the host
- **GIVEN** a host and a client on the sandbar, a palm with 2 coconuts on both
- **WHEN** the host's player climbs it
- **THEN** the client's palm has 1 coconut and draws 1

#### Scenario: A client sees a fire go out
- **GIVEN** a host and a client, and a fire the host built, lit on both
- **WHEN** a player puts it out on the host, or it burns its 360 s out there
- **THEN** on the client it is out: drawn as embers, not a lit fire, and no "[E] Apagar" prompt over it

#### Scenario: A client sees the catcher fill and empty
- **GIVEN** a host and a client, and a rain catcher the host built
- **WHEN** a squall fills it on the host and later the host's player takes the cup
- **THEN** the client's catcher first holds 1 cup and draws water, then holds none and draws empty

### Requirement: Structure state for joiners
A client that joins the run, or rejoins and takes back its player, SHALL get the host's current palm, fire and rain-catcher state once it stands on the host's island, also when that island is not the first. Raft sites and rafts keep reaching joiners as the host has them (crafting-inventory "Placed sites on every peer"). Exactly 1 player, offline, has no joiner and sends nothing.

#### Scenario: A late joiner sees what was used
- **GIVEN** a host who climbed a palm from 2 coconuts to 1, put out a fire it built and has a filled rain catcher
- **WHEN** a client joins the run
- **THEN** the client's palm has 1 coconut, its fire is out and its catcher holds 1 cup

#### Scenario: A rejoined player sees what changed while away
- **GIVEN** a client that dropped, and a palm the host climbed while it was away
- **WHEN** the client rejoins within 90 s and takes back its player
- **THEN** its palm has the host's count

#### Scenario: A joiner on the second island
- **GIVEN** a host whose party travelled to the coast cay, where the host's player climbed a palm
- **WHEN** a client joins the run
- **THEN** the client builds the coast cay and its palm has the host's count, not the layout's

#### Scenario: A joiner during the crossing
- **GIVEN** a host who built the raft at the sandbar's raft site and launched it, so the sandbar has a fresh, empty site and the raft is at sea
- **WHEN** a client joins during the crossing
- **THEN** the client's sandbar has an unbuilt raft site with nothing deposited and no raft, as the host's has

#### Scenario: A joiner before the launch
- **GIVEN** a host who built the raft at the sandbar's raft site and has not launched it
- **WHEN** a client joins the run
- **THEN** the client has the raft and no site

### Requirement: Structure messages come only from the host
A client SHALL apply a structure message only when the host sent it, and only to a structure on its own current island or in its own session, with each value held to what that structure can hold: a palm between 0 and its layout's count, cups at 0 or more. Anything else is dropped. A client cannot change another peer's structures, by a message or by changing its own copy. Exactly 1 player, offline, receives no messages.

#### Scenario: A client forges a structure message
- **GIVEN** a host and two clients
- **WHEN** one client sends the host and the other client a message saying a palm has 0 coconuts, and puts out its own copy of a lit fire
- **THEN** the host's and the other client's palm and fire are unchanged

#### Scenario: A count out of range
- **GIVEN** a client on the sandbar
- **WHEN** a message from the host gives a palm 9 coconuts, more than its layout's 2, or a negative count
- **THEN** the palm shows 2, or 0
