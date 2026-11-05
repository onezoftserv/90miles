# Spec Delta

## MODIFIED Requirements

### Requirement: Endpoint
`POST /dialogue` on API Gateway SHALL accept `{npc_id|text_id, lang, addressed, context}` and return `{speaker, text, emotion, cached}` as JSON. `addressed` is `one` or `several`: how many players the line speaks to, always `one` in a 1-player run. Auth via a per-install API key issued at first launch; no AWS credentials in the client.

#### Scenario: Request for an NPC line
- GIVEN a client holding the per-install API key issued at first launch
- WHEN it sends `POST /dialogue` with `{npc_id, lang, addressed, context}`
- THEN the response is JSON `{speaker, text, emotion, cached}` and the client used no AWS credentials

#### Scenario: Solo request
- GIVEN a 1-player run
- WHEN the player talks to Ramón and the client requests a line
- THEN the request carries `addressed: one`

### Requirement: Caching
Responses SHALL be cached in DynamoDB keyed by hash(npc_id, lang, profanity, addressed, context_bucket) with 30-day TTL, where `context_bucket` coarsens the context (island index, companions alive, quest state) so similar states share lines. A line cached for one value of `addressed` SHALL never be served for the other.

#### Scenario: Similar state hits the cache
- GIVEN a line cached 10 days ago for (npc_id, lang, profanity, addressed, context_bucket)
- WHEN a request arrives with the same npc_id, lang, profanity and addressed and a context that coarsens to the same context_bucket
- THEN the cached line is returned from DynamoDB with `cached: true`

#### Scenario: A solo player never gets a group line
- GIVEN a line cached 10 days ago for `addressed: several`
- WHEN a 1-player run requests the same npc_id, lang, profanity and context_bucket with `addressed: one`
- THEN the cache misses and the response is a newly generated singular line or a singular fallback, with `cached: false`

## ADDED Requirements

### Requirement: Second person matches the players addressed
Lines that address the player or players SHALL use the grammatical number `addressed` gives: Spanish `tú` forms for `one` and `ustedes` forms for `several`, and English wording that matches. The style guide SHALL instruct this, and every handwritten fallback line that addresses the player or players SHALL exist in a singular and a plural form, served by `addressed`.

#### Scenario: Solo player offline
- GIVEN a 1-player run with no backend reachable and the language set to es
- WHEN Ramón greets the returning player
- THEN the singular fallback plays within 100 ms (for example "¿Tú otra vez?"), never its `ustedes` form

#### Scenario: Generated line for one player
- GIVEN a 1-player run and a request with `addressed: one` and `lang: es`
- WHEN the Lambda composes the system prompt
- THEN the prompt tells the model to address one player with `tú` forms
