# 90 Millas — Session Handoff

Paste this file, or point Claude Code at it, to start a coding session. It says what the project is, what exists, what to do first, and how to work.

Shortcut: `START.md` holds the exact prompt to paste.

## 1. What you are building

A 1–4 player co-op survival roguelite in Godot 4 (GDScript). Cuban balseros island-hop across the Florida Straits. Each island is a level cleared by finding an escape route; a scrolling-sea crossing links islands; sharks, weather and the guardacostas are the threats; rescued NPCs change the ending. Hard from run 1; dying carries over a percentage of skills, knowledge and NPC trust, and eases the world slightly (capped). Spanish first, Cuban slang, political satire, swearing.

Read in this order: `CLAUDE.md` → `docs/GAME_DESIGN.md` → `openspec/project.md` → `TASKS.md`. Open `docs/CHARACTERS.md`, `docs/BESTIARY.md`, `docs/ISLANDS.md` when a task touches those.

## 2. What exists today

| Path | State |
| --- | --- |
| `docs/*.md` | Complete design: game, characters (24 NPCs), bestiary (40), islands (18 layouts, 15 set pieces), items (97), content manifest (~280 resources), assets |
| `openspec/project.md` + `openspec/specs/*/spec.md` | 13 capability specs with requirements and scenarios |
| `CLAUDE.md` | Conventions and don'ts |
| `TASKS.md` | Ordered task list, milestones 0–9 |
| `tools/fetch_assets.py`, `tools/clone_references.sh` | Asset and reference download scripts |
| `.gitignore` | Ignores `reference/`, downloaded assets, secrets |
| `game/`, `backend/` | Empty. Nothing is coded yet. |

## 3. First session: do these in order

Run from the repo root. Do not skip ahead to code.

1. **Tooling** (TASKS §0)
   - Confirm Godot 4.7.2 is installed; note its path.
   - In Claude Code: `/plugin marketplace add https://github.com/affaan-m/ECC` and `/plugin install ecc@ecc`. Copy rules: `git clone https://github.com/affaan-m/ECC.git /tmp/ecc && mkdir -p ~/.claude/rules/ecc && cp -R /tmp/ecc/rules/common ~/.claude/rules/ecc/`.
   - `npm install -g @fission-ai/openspec && openspec init` → choose Claude Code. Keep the existing `openspec/` files when it asks.
   - Godot MCP: `git clone https://github.com/Coding-Solo/godot-mcp.git ~/tools/godot-mcp && cd ~/tools/godot-mcp && npm install && npm run build`, then `claude mcp add godot -e GODOT_PATH=<path> -- node ~/tools/godot-mcp/build/index.js`. Restart Claude Code. Verify with `claude mcp list`.
   - AWS and GitHub MCPs (README §5). Verify both respond.
   - The repo already exists on GitHub (`onezoftserv/90miles`): clone it rather than running `git init`.
   - `./tools/clone_references.sh` → `reference/` (git-ignored).
2. **Assets** (TASKS §1): `python -I tools/fetch_assets.py`, then the manual downloads in `docs/ASSETS.md`. Write `game/assets/CREDITS.md`.
3. **Skeleton** (TASKS §2): `/opsx:propose project-skeleton`, review, `/opsx:apply`. Run the project through the Godot MCP; it must open and quit clean. `/opsx:archive`.
4. **Milestone A** (TASKS §3): one spec at a time, in the listed order, each as its own OpenSpec change. Stop at the playtest and report drain numbers.

## 4. How to work

- **One capability per change.** `/opsx:propose <spec-name>` → edit the proposal so its tasks match the spec's requirements → `/opsx:apply` → run via Godot MCP → tests → `/opsx:archive` → commit.
- **Specs are the contract.** If a requirement is wrong, change the spec in the proposal first, then the code. Never silently diverge.
- **Run after every change.** Use the Godot MCP to launch and read the debug output. GUT tests for anything pure (generation, meters, recipes).
- **Data, not code.** New creatures, items, NPCs, recipes and chains are `.tres` resources. If adding one needs a script edit, the design is wrong.
- **Host authority.** Every gameplay state lives on the host. Clients send intents.
- **Reference games are read-only.** Study the files listed in `reference/README.md`, then write GDScript from scratch. Never paste from them.
- **Writing.** Spanish first. Handwritten lines in `game/resources/dialogue/`. AI lines come from `backend/` with fallbacks. No invented quotes attributed to real politicians.
- **Keep TASKS.md current** and end each session by updating the "Done" section with dates.

## 5. Decisions already made (don't reopen)

- Engine Godot 4, GDScript, 2D top-down pixel art, 16×16 tiles, 640×360
- Real-time (not turn-based), host-and-join co-op, 1–4 players
- Movement sync: host authority with client prediction and reconciliation, driven by `MoveIntent` (2026-11-05)
- Heat rises 0 → 100 with sunstroke at 100; meter drains get retuned in `survival-meters` so thirst empties in about 1–1.5 in-game days (2026-11-05)
- Characters are 16×16 (Kenney CC0 bases) for now (2026-11-05)
- The seven provisional `player-movement` choices (crawl 1 tile/s, free treading, drag on press, per-interactable holds, 16×16 placeholder, 1 tile/s east current, dives need >10 energy) are confirmed (2026-11-05)
- Multiple endings by who you saved; secret ending if Yunior lives
- AI dialogue: Claude Haiku 4.5 on Bedrock for important NPCs and recurring texts only; Nova Micro as cheap fallback
- Voice: Chatterbox clones for handwritten lines; Kokoro runtime TTS is a stretch goal
- Difficulty: brutal on run 1; Experiencia carry-over (50% skills/trust on death, 100% on win) plus capped world easing (8 levels max)
- No faith/religion mechanic
- Reference games are GPL (Brogue CE: AGPL-3.0) and are never copied

## 6. Open questions to settle during the first playtest

- Day length 12 minutes and the §4 drain numbers are first guesses; tune so 2 players survive about 3 days on the sandbar with effort.
- Does the patrol loop at 3:00 feel fair on island 1? If not, start at 3:30 and let Experiencia shorten the gap instead.
- Haiku's Cuban Spanish: test 50 contexts before building the NPC UI around it.

## 7. Session end checklist

- [ ] Project runs clean through the Godot MCP
- [ ] Tests pass (`godot --headless --path game -s res://tests/smoke.gd`, then GUT; see CLAUDE.md Testing)
- [ ] OpenSpec change archived or left clearly in progress in `openspec/changes/`
- [ ] `TASKS.md` updated, including "Done"
- [ ] Commit with a conventional message; push
- [ ] Note any spec you changed in the commit body
