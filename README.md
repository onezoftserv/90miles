# 90 Millas

A 1–4 player co-op survival roguelite built in Godot 4. You are Cuban *balseros* whose raft sinks off the coast; you survive island to island across the Florida Straits, dodging sharks, storms and the *guardacostas*, until you reach land. The ending depends on who you saved along the way.

Spanish is the original language. The writing is full of Cuban slang, political satire and swearing, and the game is rated for mature audiences.

## Documents

| File | What it is |
| --- | --- |
| `docs/GAME_DESIGN.md` | Full game description and every dynamic |
| `docs/CHARACTERS.md` | Every NPC with backstory, role, quests and voice |
| `docs/BESTIARY.md` | Every threat with lore, behavior and counters |
| `docs/ISLANDS.md` | Island chains, resource places and set pieces |
| `docs/ITEMS.md` | Every item: water, food, plants, tools, wearables, texts |
| `docs/CONTENT_MANIFEST.md` | Every `.tres` resource to create, as a checklist |
| `docs/ASSETS.md` | Free assets to download and where they go |
| `openspec/` | OpenSpec project context and capability specs |
| `TASKS.md` | Ordered task list, from tooling to first playable |
| `START.md` | The prompt to paste when starting a coding session |
| `CLAUDE.md` | Conventions Claude Code follows in this repo |

## Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Godot | 4.7.2 (standard build, GDScript; CI pins this release) | https://godotengine.org/download |
| Git + GitHub account | any | Repo lives on GitHub |
| Node.js | 22.12+ | Needed by OpenSpec 1.x and the Godot MCP server |
| Python | 3.12+ | Asset scripts and the AWS Lambda (Python 3.12 runtime) |
| uv | any | Runs the AWS MCP server (`uvx`) |
| AWS account | — | Bedrock (Claude Haiku 4.5), Lambda, API Gateway |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |

## Setup

### 1. Clone and open

```bash
git clone https://github.com/onezoftserv/90miles.git
cd 90miles
```

Open `game/project.godot` in Godot once so it imports assets, then close it.

### 2. Install ECC (Everything Claude Code)

Inside Claude Code, run:

```
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin install ecc@ecc
```

Plugins cannot ship rules, so copy the common rule pack manually:

```bash
git clone https://github.com/affaan-m/ECC.git /tmp/ecc
mkdir -p ~/.claude/rules/ecc
cp -R /tmp/ecc/rules/common ~/.claude/rules/ecc/
```

Only install from the official sources (`affaan-m/ECC`, `ecc@ecc`, `ecc-universal`). Do not also do a full manual install on top of the plugin.

### 3. Install OpenSpec

```bash
npm install -g @fission-ai/openspec
openspec init
```

Pick **Claude Code** when prompted. This writes the `/opsx:propose`, `/opsx:apply` and `/opsx:archive` commands into `.claude/`. The `openspec/` folder in this repo already holds the project context and the first capability specs.

Workflow for every feature:

1. `/opsx:propose <feature>` creates a change with proposal, spec delta, design and tasks.
2. Review and edit the proposal.
3. `/opsx:apply` implements the tasks.
4. `/opsx:archive` folds the change into the permanent specs.

### 4. Install the Godot MCP server

Lets Claude Code launch the editor, run the project, read errors and create scenes.

```bash
git clone https://github.com/Coding-Solo/godot-mcp.git ~/tools/godot-mcp
cd ~/tools/godot-mcp && npm install && npm run build
```

Then register it (adjust `GODOT_PATH` to your binary):

```bash
claude mcp add godot -e GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot -- node ~/tools/godot-mcp/build/index.js
```

Optional: the `cc-godot` plugin (https://github.com/Zate/cc-godot) wraps the same server with `/gd:setup`, `/gd:run` and `/gd:stop` commands plus a Godot expert agent.

### 5. Install the AWS and GitHub MCP servers

```bash
# AWS: the AWS MCP Server through AWS's proxy; it uses your AWS CLI credentials
claude mcp add aws-mcp -- uvx mcp-proxy-for-aws@latest https://aws-mcp.us-east-1.api.aws/mcp
# GitHub: GitHub's remote MCP server, authenticated with a fine-grained personal access token
claude mcp add --transport http github https://api.githubcopilot.com/mcp -H "Authorization: Bearer <your token>"
```

The older `@modelcontextprotocol/server-github` package is archived and `awslabs.aws-api-mcp-server` is superseded. Give the agent least privilege: an AWS profile limited to this project's resources, and a fine-grained GitHub token scoped to this repo with a short expiry (Claude Code stores the header in its config in plain text). If the AWS server fails to connect, the profile in its `AWS_MCP_PROXY_PROFILES` setting probably needs `aws login --profile <name>`. The `gh` CLI covers issues and PRs without an MCP server.

Set `AWS_PROFILE` for the project profile before starting Claude Code. Keep tokens out of shell profiles and dotfiles.

### 6. Clone the reference games

```bash
./tools/clone_references.sh
```

This clones Shattered Pixel Dungeon, Brogue CE and Dungeon Crawl Stone Soup into `reference/`, which is git-ignored. They are GPL (Brogue CE is AGPL-3.0): read them to understand a mechanism, then write it in GDScript from scratch. `reference/README.md` lists where to start in each.

### 7. Download free assets

Follow `docs/ASSETS.md`. The script `tools/fetch_assets.py` downloads the Kenney packs and the two OFL pixel fonts; OpenGameArt, itch.io and freesound assets need a manual download.

### 8. AWS backend

```bash
cd backend
cp .env.example .env    # fill in AWS region and profile
./deploy.sh             # SAM deploy of the dialogue Lambda + API Gateway
```

The game reads the API URL from `game/config/backend.cfg`. Never put AWS keys in the game.

## Repo layout

```
90-millas/
  game/                 Godot 4 project
    project.godot
    scenes/             one folder per area: main, player, islands, enemies, ui
    scripts/
      autoload/         GameState, NetManager, WeatherManager, DialogueService, AudioManager
      content/          ContentCatalog (finds .tres by folder), ContentValidator
      data/             Resource classes for every content folder
    resources/          .tres data, one folder per content type (see docs/CONTENT_MANIFEST.md)
    assets/             sprites, audio, fonts (see docs/ASSETS.md)
    addons/gut/         GUT 9.7.1 test framework (vendored)
    tests/              smoke.gd and unit/test_*.gd
    config/             backend.cfg, build settings
  backend/              AWS SAM app: dialogue Lambda calling Bedrock
  docs/                 design docs (this folder)
  openspec/             OpenSpec context and specs
  tools/                asset fetch, reference clone and audio scripts
  reference/            git-ignored clones of the reference games
  CLAUDE.md
  HANDOFF.md            start here for a coding session
  TASKS.md
```

## Running

- From Godot: open `game/project.godot`, press F5.
- From Claude Code with the Godot MCP: "run the project and show me the errors".
- Co-op test: run two instances; one hosts (`--host`), one joins (`--join 127.0.0.1`).

## License

Code: MIT. Design docs and writing: all rights reserved. Third-party assets keep their own licenses (listed in `docs/ASSETS.md`).
