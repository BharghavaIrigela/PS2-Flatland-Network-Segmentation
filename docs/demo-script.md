# Demo script (7 minutes)

**Before judges arrive (5 min earlier):**
- `make smoke` passed today (or at least `./run.sh flat up` works).
- `python3 dashboard/server.py` is running and http://localhost:8000 is open full-screen.
- Flat lab is up with clean data: dashboard **BEFORE**, then **↺ Reset data**.
- A second tab is open at https://localhost:8443 (Employee Portal).
- `lab/conf/router.nft` is open in VS Code.

Roles: **Driver** clicks and types. **Speaker** talks. **Backup** answers rule questions.

| Time | Driver does | Speaker says |
|---|---|---|
| 0:00–0:30 | Dashboard on BEFORE; point at the map | "Corp runs six hosts on one flat network. One employee PC is compromised. Our question: what can that one PC reach, and can we stop it without breaking the business?" |
| 0:30–1:10 | Portal tab: show Meera Iyer, salary 72000. Back to dashboard, click **✔ Business test** | "This is the payroll portal employees use. The business test runs 10 real flows from their real sources: 10/10 pass." |
| 1:10–2:20 | Click **☠ Attack**; let the map animate | "From the workstation: discovery finds 9 internal services; it logs into the DB host, opens the file share, copies a file and changes one payroll row. 5 of 5 stages succeed. Integrity check: DATA TAMPERED, 72000 became the figure the attacker just set." Refresh the portal to show the changed salary. |
| 2:20–3:30 | Open `docs/flow-matrix.md`, then `router.nft` | "We started from the flow matrix: only six flow types are needed. Four zones: user, DMZ, server, management. The router is default-deny: three allow rules, stateful return traffic, anti-spoofing, and every drop is logged." |
| 3:30–4:00 | Dashboard: switch to **AFTER**, click **▶ Start lab** | "Same hosts, same attacker, now in four Docker networks joined by the router." |
| 4:00–5:10 | Click **⚡ Run full demo** | "Attack: 0 of 5. Every attempt stops at the router. DATA INTACT. Business test: still 10/10. The portal works and the salary is untouched." |
| 5:10–6:00 | Scroll to the Firewall panel | "Proof from the router itself: drop counters and log lines with source, destination and port. These are the workstation's attempts to reach db on 5432 and 22 and files on 445." |
| 6:00–6:40 | Show the before/after comparison table | "Before: 5/5, tampered, 10/10. After: 0/5, intact, 10/10. Stretch: db host firewall, egress filtering, SSH rate limit." |
| 6:40–7:00 | — | "Known weakness: inside the server zone, app and files still reach each other because the router never sees that traffic. Next step is splitting that zone. Questions?" |

## If something goes wrong
| Problem | Fix |
|---|---|
| Dashboard not loading | Rerun `python3 dashboard/server.py` from the project folder |
| A lab won't start / port 8443 busy | `./run.sh flat down; ./run.sh seg down`, then start the one you need |
| Portal tab fails in AFTER | `docker compose -p seg -f docker-compose.seg.yml exec ws curl -sk https://web/` |
| Data still tampered at start | Dashboard **↺ Reset data** (or `./run.sh flat reset`) |
| Firewall log empty | Show the counters (`./run.sh seg fw`): drops are enforced either way |

## Likely judge questions
- **"Run your own scan."** `docker compose -p seg -f docker-compose.seg.yml exec ws nmap -Pn -p- db` shows filtered ports.
- **"Why not `internal: true`?"** Docker's internal-network rules drop routed traffic between subnets.
- **"Can ws spoof admin's IP?"** No: the router's reverse-path (fib) check drops it, as the `SPOOF-DROP` counter shows.
- **"What if web is compromised?"** It can reach app:8080 only (F2). The next step is application-layer controls and splitting the server zone.
