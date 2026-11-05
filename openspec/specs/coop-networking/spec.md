# coop-networking

## Purpose
Host-and-join co-op for 1–4 players using Godot high-level multiplayer over ENet.

## Requirements

### Requirement: Host and join
A player SHALL host a session on a port (default 7777) and up to three others SHALL join by IP. Solo play runs the same code path with the host as the only peer.

#### Scenario: Second player joins mid-island
- GIVEN a host on island 2
- WHEN a client connects
- THEN the client receives the island seed, current weather, time of day and all entity states, and spawns on the beach

### Requirement: Host authority
All world state (meters, inventory, creature positions, weather, patrol state) SHALL live on the host. Clients send input intents via RPC; the host validates and applies them. `MultiplayerSynchronizer` replicates positions and meters to clients at 20 Hz.

#### Scenario: Client claims an item it is not near
- GIVEN a client whose player is 10 tiles from a coconut
- WHEN it sends a pick-up intent for that coconut
- THEN the host rejects the intent and the coconut stays

### Requirement: Spawning
Players, creatures, items and NPCs SHALL be spawned through `MultiplayerSpawner` so late joiners receive them.

### Requirement: Disconnect handling
If a client disconnects, its player SHALL stay in the world as downed for 90 s, then be removed with its inventory dropped. If the host disconnects, the session ends and clients see a "host lost" screen; migration is out of scope for v1.

### Requirement: Difficulty scaling
Resource spawn rates SHALL multiply by 0.8 per player beyond the first; patrol count adds 1 per 2 players.

### Requirement: Quick chat
Players SHALL have a radial quick-chat with 8 phrases (¡Dale!, ¡Agua!, ¡Pa'llá no!, ¡Tiburón!, ¡Patrulla!, ¡Ayuda!, ¡Comida aquí!, ¡Vámonos!) shown as speech bubbles and heard as a short voice clip.
