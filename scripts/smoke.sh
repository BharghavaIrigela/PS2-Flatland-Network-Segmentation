#!/usr/bin/env bash
# End-to-end test: runs both labs and asserts the expected before/after results.
# Saves all output under evidence/. Needs Docker. Takes ~3-5 minutes.
cd "$(dirname "$0")/.."
fail=0; T=$(mktemp -d)
expect(){ if grep -q -- "$2" "$1"; then echo "PASS  $3"; else echo "FAIL  $3  (expected: $2)"; fail=1; fi; }

./run.sh seg down >/dev/null 2>&1; ./run.sh flat down >/dev/null 2>&1

echo "== BEFORE: flat network"
./run.sh flat up        > "$T/up_flat" 2>&1 || { echo "FAIL  flat lab did not start"; cat "$T/up_flat"; exit 1; }
sleep 4
./run.sh flat business  > "$T/biz_flat" 2>&1
./run.sh flat attack    > "$T/att_flat" 2>&1
expect "$T/biz_flat" "RESULT: 10/10 business" "flat: 10/10 business flows"
expect "$T/att_flat" "RESULT: 5/5 attack"     "flat: 5/5 attack stages succeed (vulnerable baseline)"
expect "$T/att_flat" "DATA TAMPERED"          "flat: payroll data tampered"
./run.sh flat down >/dev/null 2>&1

echo "== AFTER: segmented network"
./run.sh seg up         > "$T/up_seg" 2>&1 || { echo "FAIL  seg lab did not start"; cat "$T/up_seg"; exit 1; }
sleep 4
docker compose -p seg -f docker-compose.seg.yml logs router 2>&1 | grep -E "\[nft\]|WARN|ERROR" | sed 's/^/      router: /'
./run.sh seg business   > "$T/biz_seg" 2>&1
./run.sh seg attack     > "$T/att_seg" 2>&1
./run.sh seg fw         > "$T/fw_seg" 2>&1
expect "$T/biz_seg" "RESULT: 10/10 business" "seg: 10/10 business flows"
expect "$T/att_seg" "RESULT: 0/5 attack"     "seg: 0/5 attack stages succeed"
expect "$T/att_seg" "DATA INTACT"            "seg: payroll data intact"
expect "$T/fw_seg"  "FWD-DROP"               "seg: firewall drop rule present with counters"
./run.sh seg down >/dev/null 2>&1

mkdir -p evidence/smoke && cp "$T"/* evidence/smoke/ && rm -rf "$T"
echo; [ $fail = 0 ] && echo "SMOKE TEST PASSED (outputs in evidence/smoke/)" || echo "SMOKE TEST FAILED (outputs in evidence/smoke/)"
exit $fail
