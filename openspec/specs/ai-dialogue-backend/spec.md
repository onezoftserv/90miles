# ai-dialogue-backend

## Purpose
AWS backend that generates dialogue for important NPCs and found texts with Claude Haiku 4.5 on Bedrock.

## Requirements

### Requirement: Endpoint
`POST /dialogue` on API Gateway SHALL accept `{npc_id|text_id, lang, context}` and return `{speaker, text, emotion, cached}` as JSON. Auth via a per-install API key issued at first launch; no AWS credentials in the client.

#### Scenario: Request for an NPC line
- GIVEN a client holding the per-install API key issued at first launch
- WHEN it sends `POST /dialogue` with `{npc_id, lang, context}`
- THEN the response is JSON `{speaker, text, emotion, cached}` and the client used no AWS credentials

### Requirement: Model and prompt
The Lambda SHALL call Bedrock `anthropic.claude-haiku-4-5` with a system prompt composed of: the game style guide (`backend/prompts/style.md`), the Cuban slang glossary (`backend/prompts/slang.md`), the NPC or text profile, and the context. Output is constrained to JSON via a tool/schema; non-JSON responses are retried once then fall back.

#### Scenario: Non-JSON response
- GIVEN Bedrock returns a response that is not valid JSON
- WHEN the Lambda handles it
- THEN it retries the call once, and if the retry is also not JSON it falls back

### Requirement: Content rules in prompt
The style guide SHALL instruct: Spanish (or English keeping key slang), Cuban voice, satire of the system and daily life, no invented quotes attributed to real named politicians, profanity allowed and toggleable (`profanity: soft|full`), max 240 characters per line, emotion from a fixed set.

#### Scenario: Soft profanity prompt
- GIVEN `backend/prompts/style.md`
- WHEN the system prompt is composed with `profanity: soft`
- THEN it instructs Spanish (or English keeping key slang), Cuban voice, satire of the system and daily life, no invented quotes attributed to real named politicians, soft profanity, at most 240 characters per line, and an emotion from the fixed set

### Requirement: Caching
Responses SHALL be cached in DynamoDB keyed by hash(npc_id, lang, profanity, context_bucket) with 30-day TTL, where `context_bucket` coarsens the context (island index, companions alive, quest state) so similar states share lines.

#### Scenario: Similar state hits the cache
- GIVEN a line cached 10 days ago for (npc_id, lang, profanity, context_bucket)
- WHEN a request arrives with the same npc_id, lang and profanity and a context that coarsens to the same context_bucket
- THEN the cached line is returned from DynamoDB with `cached: true`

### Requirement: Rate limits and cost
Per API key: 60 requests/min, 2,000/day. Lambda timeout 6 s. Target cost ≤ $0.05 per run.

#### Scenario: Per-minute limit
- GIVEN an API key that has made 60 requests in the current minute
- WHEN it sends another request
- THEN the request is rejected by the rate limit

### Requirement: Voice
A separate offline tool (`tools/gen_voice.py`) SHALL pre-generate Chatterbox audio for all handwritten lines. Runtime TTS for AI lines (Kokoro) is a stretch goal behind a flag; v1 shows text with a short voice "grunt" clip per emotion.

#### Scenario: AI line in v1
- GIVEN the runtime TTS flag is off
- WHEN an AI-generated line with an emotion is shown
- THEN the text is displayed with that emotion's short voice "grunt" clip and no synthesized speech

### Requirement: Deployment
`backend/` SHALL be an AWS SAM template with `./deploy.sh`; the API URL is written to `game/config/backend.cfg`. A local mock (`backend/mock_server.py`) returns handwritten lines for development without AWS.

#### Scenario: Deploy writes the API URL
- GIVEN the SAM template in `backend/`
- WHEN `./deploy.sh` completes
- THEN the deployed API URL is written to `game/config/backend.cfg`
