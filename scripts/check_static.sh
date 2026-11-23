#!/usr/bin/env bash
# Static checks: required files exist, scripts parse, compose files valid, rulesets valid.
cd "$(dirname "$0")/.."
fail=0; ok(){ echo "OK    $1"; }; bad(){ echo "FAIL  $1"; fail=1; }; skip(){ echo "SKIP  $1"; }

echo "== Deliverables present"
for f in README.md run.sh docker-compose.flat.yml docker-compose.seg.yml \
         lab/attack.sh lab/business.sh lab/integrity.sh lab/conf/router.nft lab/conf/db-host.nft \
         docs/report.md docs/demo-script.md docs/flow-matrix.md docs/flow-matrix.csv \
         docs/attack-mapping.md docs/attack-mapping.csv docs/diagrams/network-after.mmd \
         dashboard/server.py dashboard/index.html; do
  [ -s "$f" ] && ok "$f" || bad "$f missing"
done
[ -n "$(find docs/diagrams -maxdepth 1 \( -name "*.png" -o -name "*.svg" -o -name "*.pdf" \) -size +0 2>/dev/null)" ] \
  && ok "diagram image in docs/diagrams" || bad "no diagram image (PNG/SVG/PDF) in docs/diagrams - export network-after.mmd"

echo "== Shell scripts parse"
for f in run.sh hack_setup_ps2.sh lab/*.sh scripts/*.sh; do bash -n "$f" && ok "$f" || bad "$f"; done
for f in run.sh lab/*.sh scripts/*.sh; do [ -x "$f" ] || bad "$f not executable (chmod +x)"; done

echo "== Python compiles"
for f in dashboard/server.py lab/app.py; do python3 -c "import ast,sys;ast.parse(open('$f').read())" && ok "$f" || bad "$f"; done

echo "== Compose files valid"
if command -v docker >/dev/null; then
  for m in flat seg; do docker compose -f docker-compose.$m.yml config -q && ok "docker-compose.$m.yml" || bad "docker-compose.$m.yml"; done
else skip "docker not installed"; fi

echo "== nftables syntax"
if command -v nft >/dev/null && command -v unshare >/dev/null && sudo -n true 2>/dev/null; then
  for f in lab/conf/router.nft lab/conf/db-host.nft; do sudo -n unshare -n nft -c -f "$f" && ok "$f" || bad "$f"; done
else skip "nft/sudo not available (syntax is also checked when the router starts)"; fi

echo; [ $fail = 0 ] && echo "STATIC CHECKS PASSED" || echo "STATIC CHECKS FAILED"; exit $fail
