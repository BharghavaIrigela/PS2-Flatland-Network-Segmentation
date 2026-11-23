# MITRE ATT&CK / D3FEND mapping

| Stage | Behaviour | ATT&CK technique | Tactic | Before (flat) | After (segmented) | D3FEND | Mitigation |
|---|---|---|---|---|---|---|---|
| A1 | Service discovery from the workstation | T1046 Network Service Discovery, T1018 Remote System Discovery | Discovery | SUCCEEDED: 9 internal services visible | BLOCKED: only web:443 visible | Network Isolation | M1030 Network Segmentation |
| A2 | Remote login to the database host | T1021.004 Remote Services: SSH | Lateral Movement | SUCCEEDED | BLOCKED | Inbound Traffic Filtering | M1037 Filter Network Traffic |
| A3 | Session to the file share | T1021.002 SMB/Windows Admin Shares | Lateral Movement | SUCCEEDED | BLOCKED | Inbound Traffic Filtering | M1037 |
| A4 | Copy a file to another host | T1570 Lateral Tool Transfer | Lateral Movement | SUCCEEDED | BLOCKED | Network Isolation | M1030 |
| A5 | Unauthorised change to a payroll record | T1565.001 Stored Data Manipulation | Impact | SUCCEEDED: DATA TAMPERED | BLOCKED: DATA INTACT | Network Isolation, Inbound Traffic Filtering | M1030, M1037 |

Hardening beyond the core tasks:

| Control | Where | Counters |
|---|---|---|
| Egress filtering: server/DMZ hosts cannot initiate outbound connections | router default policy | Outbound Traffic Filtering, M1037 |
| SSH rate limiting on the management path (≤10 new/min) | router F3 | M1037 |
| Reverse-path anti-spoofing (`fib saddr . iif oif missing drop`) | router prerouting | Inbound Traffic Filtering |
| Host micro-segmentation on db (`MICROSEG=1`): only app:5432 and admin:22 | db host nftables | Network Isolation, M1030 |

IDs taken from the hackathon statement's mapping. Confirm against the current ATT&CK release when submitting. Machine-readable copy: `attack-mapping.csv`.
