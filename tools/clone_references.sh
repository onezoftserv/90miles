#!/usr/bin/env bash
# Clone the three reference games into reference/ (git-ignored).
# They are GPL (Brogue CE is AGPL-3.0): read them for ideas and structure, never copy code into game/
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reference
clone() {
  local url="$1" dir="$2"
  if [ -d "reference/$dir/.git" ]; then
    echo "update $dir"; git -C "reference/$dir" pull --ff-only
  else
    echo "clone  $dir"; git clone --depth 1 "$url" "reference/$dir"
  fi
}
clone https://github.com/00-Evan/shattered-pixel-dungeon.git shattered-pixel-dungeon
clone https://github.com/tmewett/BrogueCE.git BrogueCE
clone https://github.com/crawl/crawl.git crawl
cat > reference/README.md <<'EOF'
# Reference games (git-ignored)

GPL-licensed (Brogue CE: AGPL-3.0). Study only; never copy code into game/

| Repo | Study for | Start at |
| --- | --- | --- |
| shattered-pixel-dungeon | Actor/turn system, level builders + painters, items, buffs, hero classes | core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/{actors,levels,items} |
| BrogueCE | Dungeon features, Dijkstra maps, monster AI, stealth and noise, machines | src/brogue/{Architect.c,Monsters.c,Movement.c,Dijkstra.c} |
| crawl | Data-driven monsters/items, skills trained by use, branches | crawl-ref/source/{dat/mons/*.yaml,item-prop.cc,skills.cc,branch-data.h} |
EOF
echo "done -> reference/"
