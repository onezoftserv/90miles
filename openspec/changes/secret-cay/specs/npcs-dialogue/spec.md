# Spec Delta

## MODIFIED Requirements

### Requirement: AI lines
Important NPCs SHALL request lines from `DialogueService` with a context object (island, weather, party, companions alive/dead, quests, run history, recent events). The service returns `{speaker, text, emotion}` or a handwritten fallback within 3 s. The context SHALL never name, describe or count a secret item or the secret cay (secret-cay): a player carrying one, or a run that visited the cay, sends the same context as one that did not. This holds for 1 player as for 4. (Changes docs/GAME_DESIGN.md §16 "AI dialogue and voice" input for secret items and the cay.)

#### Scenario: Offline
- GIVEN no backend reachable
- WHEN Ramón is talked to
- THEN a handwritten fallback line plays within 100 ms and the UI shows no error

#### Scenario: Secrets stay out of the context
- **GIVEN** a 1-player run whose player carries the broken compass and the red-band yarey hat and visited the secret cay
- **WHEN** they talk to Ramón and the client builds the request's context
- **THEN** the context mentions no secret item and no cay, and equals the context built without them
