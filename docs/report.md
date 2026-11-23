# Flatland: segmenting a flat network with a default-deny router

**Secure Networks Hackathon · PS-2 · Team report**

## 1. Problem and scope
The company runs six hosts on one flat Docker bridge (10.10.0.0/24): workstation `ws`, `web` (nginx, TLS 443), `app` (Employee Portal, 8080), `db` (PostgreSQL 16, payroll table), `files` (Samba, 445) and `admin` (jump host). There is no layer-3 boundary and no filtering, so any host reaches any port on any other host. Threat model: an ordinary employee workstation is compromised (a shell plus a reused password and an application database credential found on disk). Goal: show that this foothold reaches the payroll data, then redesign the network so the same foothold fails while every legitimate flow keeps working.

## 2. Method and evidence
Everything is reproducible from the repository (`./run.sh`, `make test`, dashboard at `localhost:8000`).

- **Attack script** (`lab/attack.sh`, runs inside `ws`): five stages A1–A5 covering service discovery, SSH, SMB, file transfer and an unauthorised update of one payroll row. Each stage prints `SUCCEEDED` or `BLOCKED`, and a PCAP of the run is saved to `evidence/`.
- **Business script** (`lab/business.sh`, runs on the host): 10 flows, each executed from its real source container. These are B1 HTTPS to web, B2 the full portal chain web→app→db, B3 web→app, B4 app→db, B5 app→files, and B6 admin SSH to all five hosts.
- **Integrity check** (`lab/integrity.sh`): reads `employees` from inside the db container (trusted path, not over the network) and diffs it against `lab/conf/employees.baseline`. Prints `DATA INTACT` or `DATA TAMPERED` with the changed row.

## 3. Results on the flat network
| Metric | Result |
|---|---|
| Attack stages succeeded | **5/5** |
| Internal services visible from ws (A1) | 9 (22 on five hosts, 8080, 5432, 139, 445) |
| Payroll integrity | **TAMPERED** (id 3 salary 72000 → an attacker-chosen value, e.g. 430000) |
| Business flows | 10/10 |

The flat design has no single failure: the problem is that nothing distinguishes a workstation from a server. Reachability equals trust.

## 4. Design
**Flow matrix first** (`docs/flow-matrix.md`): only six flow types are needed. The design then assigns hosts to zones so that every cross-zone flow is one narrow router rule.

| Zone | Subnet | Hosts | Trust |
|---|---|---|---|
| USER | 10.20.10.0/24 | ws | low, assume compromised |
| DMZ | 10.20.20.0/24 | web | public-facing |
| SERVER | 10.20.30.0/24 | app, db, files | high |
| MGMT | 10.20.99.0/24 | admin | privileged |

**Implementation.** Each zone is a separate Docker network. A `router` container is attached to all four as `.254`, with `net.ipv4.ip_forward=1`. Every host replaces its default route with the router at start-up, so all inter-zone traffic must cross it. Docker's own inter-bridge isolation drops any attempt to bypass the router via the Docker gateway. The networks are deliberately not `internal: true`, because Docker's internal-network rules also drop routed traffic.

**Ruleset** (`lab/conf/router.nft`, table `inet lab`):
- `forward` policy **drop**; `ct state established,related accept`; `ct state invalid drop`.
- F1 `USER → web:443`, F2 `web → app:8080`, F3 `admin → managed hosts:22` (rate limit: above 10 new/min logged and dropped), ICMP echo from admin.
- Final rule `counter log group 0 prefix "FWD-DROP " drop`, sent via NFLOG to ulogd2 (`/var/log/ulog/syslogemu.log`). NFLOG is used because the kernel's plain `log` is disabled by default inside non-init network namespaces.
- `input` policy drop (only admin ICMP); `prerouting` reverse-path anti-spoofing `fib saddr . iif oif missing drop`, so `ws` cannot forge admin's source address.
- The loader degrades gracefully: without NFLOG it loads without logging (counters remain); without `fib` it loads without anti-spoofing; if nothing loads it prints an explicit ERROR.

**Stretch controls.** Egress filtering is inherent: DMZ and SERVER hosts cannot initiate anything outbound. With `MICROSEG=1`, the db host's own nftables accepts only app→5432 and admin→22.

## 5. Results after segmentation
| Metric | Flat | Segmented |
|---|---|---|
| Attack stages succeeded | 5/5 | **0/5** (all time out at the router) |
| Services visible from ws | 9 | 0 (web:443 only, by design) |
| Payroll integrity | TAMPERED | **INTACT** |
| Business flows | 10/10 | **10/10** |
| Firewall evidence | none | FWD-DROP log lines with SRC/DST/DPT; ~94 drops per attack run |

Before submission, the router was rebuilt in plain Linux network namespaces with the same ruleset. It allowed all 9 cross-zone and intra-zone business connections, blocked all 9 attack and egress probes, and dropped forged-source packets (`SPOOF-DROP` counter).

## 6. Known weaknesses and next steps
1. **Intra-zone traffic is unfiltered.** `app`, `db` and `files` share one SERVER segment, so their traffic is bridged at L2 and never reaches the router. `app` and `files` can still reach each other on any port. A compromised `app` (for example via the web→app path) can therefore move laterally to `files`, and to `db` unless `MICROSEG=1` is on. *Fix:* split SERVER into APP / DATA / FILE zones, so B4 and B5 become explicit router rules. Alternatively, apply host firewalls on `files` as already done for `db`, or bridge-level filtering (`nft bridge` family) on the segment.
2. **Allowed paths remain attack paths.** F1 and F2 permit exactly the chain an attacker needs if `web` is exploited. The mitigation belongs at the application layer: WAF/reverse-proxy hardening, patching, least-privilege DB role for the portal.
3. **Credentials.** Password SSH with a reused password and a DB password readable on the workstation are the actual enablers. Next steps: key-only SSH through the jump host, unique secrets in a vault, a DB role without UPDATE on payroll for anything but the HR path.
4. **Lab artefacts.** Containers hold `NET_ADMIN` so they can set their default route. In production, routes come from the network, not from the host. A root user on `ws` could change its route, but Docker's inter-bridge isolation still drops the bypass.
5. **Single enforcement point.** The router is one container. Production would add redundancy and central log shipping (SIEM) for the NFLOG stream.

## 7. Reproducibility
`make test` runs static checks. `make smoke` runs both labs end to end and asserts flat 5/5 + TAMPERED, segmented 0/5 + INTACT, and business 10/10 in both. `make zip` builds the submission archive. `make test-fresh` unpacks that archive into a temporary directory and runs the checks there, proving a clean copy works.
