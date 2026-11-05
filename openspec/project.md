# Project Context — 90 Millas

## Purpose

A 1–4 player co-op survival roguelite in Godot 4. Cuban balseros island-hop across the Florida Straits; each island is a level cleared by finding a way off it. Endings depend on who you saved. Full design in `docs/GAME_DESIGN.md`; characters, threats and islands in `docs/CHARACTERS.md`, `docs/BESTIARY.md`, `docs/ISLANDS.md`.

## Tech stack

- Godot 4.7 (CI pins 4.7.2), GDScript with static typing
- Godot high-level multiplayer (ENet), host-authoritative
- GUT for tests
- AWS: API Gateway + Lambda (Python 3.12) + Bedrock (Claude Haiku 4.5) for AI dialogue
- Chatterbox / Kokoro for voice generation (offline tooling in `tools/`)

## Project conventions

See `CLAUDE.md`. In short: data in `.tres` resources, components over inheritance, thin autoloads, host authority, Spanish-first writing, no copied GPL code from the reference games.

## Reference games (ideas only; GPL, Brogue CE AGPL-3.0)

Cloned into `reference/` (git-ignored):

- `reference/shattered-pixel-dungeon` — actors, level builders, items, buffs, hero classes
- `reference/BrogueCE` — dungeon features, Dijkstra maps, stealth/noise, machines
- `reference/crawl` — data-driven monsters/items, skills by use, branches

When a spec says "study X in Brogue", open that code to understand the mechanism, then write it in GDScript from scratch.

## Domain language

| Term | Meaning |
| --- | --- |
| Island | A level. Cleared by an escape route, not stairs. |
| Chain | An island template family (sandbar, coast, mangrove, reef, rock, lighthouse, storm, shipwreck, final). |
| Escape route | A POI that, when its requirements are met, starts a crossing. |
| Crossing | The scrolling-sea scene between islands. |
| POI | A placed point of interest: resource place, NPC camp, set piece or escape route. |
| Set piece | A scripted mini-situation (Brogue "machine"). |
| Meters | Thirst, hunger, heat, energy, morale, health. |
| Background | Player class: pescador, mecánico, médico, maestro, músico, ex-militar. |
| Companion | A rescued balsero NPC that follows the party. |
| Important NPC | One whose lines are AI-generated. |
| Found text | A readable item: bottle note, journal, letter, graffiti, radio fragment. |
| Keepsake | A between-runs unlock (memory). |

## Capability specs

Each folder under `openspec/specs/` holds one capability's `spec.md`. Changes are proposed under `openspec/changes/<name>/` with `proposal.md`, `tasks.md`, `design.md` and spec deltas, then archived.

Initial specs: `player-movement`, `coop-networking`, `survival-meters`, `island-generation`, `escape-routes`, `crossing`, `creatures-ai`, `guardacostas-stealth`, `npcs-dialogue`, `ai-dialogue-backend`, `weather-daynight`, `crafting-inventory`, `endings-progression`.
