# Flow matrix (who must talk to whom)

Derived from the business requirements before any rule was written. Everything not listed is denied.

| ID | Source (zone) | Destination (zone) | Port | Purpose | Enforced by | Rule |
|---|---|---|---|---|---|---|
| B1 | ws 10.20.10.10 (USER) | web 10.20.20.20 (DMZ) | 443/tcp | Employees reach the web front end | router | F1 |
| B2 | ws → web → app → db | (USER → DMZ → SERVER) | 443 → 8080 → 5432 | End-to-end Employee Portal transaction | router + intra-zone | F1, F2 |
| B3 | web 10.20.20.20 (DMZ) | app 10.20.30.30 (SERVER) | 8080/tcp | Reverse proxy to portal | router | F2 |
| B4 | app 10.20.30.30 (SERVER) | db 10.20.30.40 (SERVER) | 5432/tcp | Portal queries payroll DB | intra-zone; db host firewall with `MICROSEG=1` | — |
| B5 | app 10.20.30.30 (SERVER) | files 10.20.30.50 (SERVER) | 445/tcp | Portal writes reports | intra-zone, **not filtered** (known weakness) | — |
| B6 | admin 10.20.99.60 (MGMT) | ws, web, app, db, files | 22/tcp | Administration via jump host | router, ≤10 new conn/min | F3 |
| — | any | any | any | everything else | router | default **DROP + log** |

## Zone-to-zone view (router decisions)

| from \ to | USER | DMZ | SERVER | MGMT |
|---|---|---|---|---|
| **USER** | (same L2) | 443 → web only | ✗ | ✗ |
| **DMZ** | ✗ | (same L2) | 8080 → app only | ✗ |
| **SERVER** | ✗ | ✗ | (same L2, unfiltered) | ✗ |
| **MGMT** | 22 | 22 | 22 | (same L2) |

Return traffic is allowed by `ct state established,related`. Source addresses are checked with a reverse-path (fib) anti-spoofing rule. Machine-readable copy: `flow-matrix.csv`.
