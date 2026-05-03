# Network Bandwidth Sharing Demo

## Overview

This project demonstrates how a **streaming application's throughput degrades** when
background file transfers (SCP) compete for the same network link — the same effect
seen on home and enterprise networks when multiple applications run concurrently.

A simulated router enforces a total bandwidth cap using Linux `tc` (Traffic Control
with HTB queuing discipline). All client containers must route traffic through this
bottleneck to reach the servers. As SCP transfers are added, TCP's congestion control
(CUBIC) distributes the available capacity fairly, starving the stream. The demo runs
12 timed phases and produces a timestamped CSV and chart showing the full effect.

---

## Architecture

```
┌───────────────────────────────────────────────────────┐
│                  client-net (172.20.0.0/24)           │
│                                                       │
│  [stream-client]  [scp-client-1]  [scp-client-2]     │
│   172.20.0.10      172.20.0.20     172.20.0.21        │
│         │               │               │             │
│         └───────────────┴───────────────┘             │
│                         │                             │
└─────────────────────────┼─────────────────────────────┘
                          │
              ┌───────────▼───────────┐
              │       [router]        │
              │    172.20.0.1 (eth0)  │  ← tc HTB: 50 or 20 Mbps cap
              │    172.21.0.1 (eth1)  │    shared by ALL client flows
              └───────────┬───────────┘
                          │
┌─────────────────────────┼─────────────────────────────┐
│                  server-net (172.21.0.0/24)            │
│                         │                             │
│         ┌───────────────┴───────────────┐             │
│         │                               │             │
│  [stream-server]                  [scp-server]        │
│   172.21.0.10                     172.21.0.11         │
│  nginx serves a                  sshd accepts         │
│  500 MB binary file              SCP uploads          │
└───────────────────────────────────────────────────────┘
```

### Component Summary

| Container | Role |
|-----------|------|
| `router` | Routes packets between the two networks; applies `tc` HTB bandwidth cap |
| `stream-server` | nginx serves a 500 MB binary file (represents a video stream source) |
| `stream-client` | Downloads the file in a loop every 2 s; logs throughput to CSV |
| `scp-server` | OpenSSH server that accepts file uploads from SCP clients |
| `scp-client-1/2/3` | Each continuously SCPs a 100 MB file to the server (background traffic) |

---

## How the Bandwidth Control Works

The router uses Linux **HTB (Hierarchical Token Bucket)** via `tc`:

```
tc qdisc add dev eth0 root handle 1: htb default 10
tc class add dev eth0 parent 1: classid 1:10 htb rate 50mbit ceil 50mbit
tc qdisc add dev eth0 parent 1:10 handle 10: sfq perturb 10
```

- All traffic from the client network shares **one HTB class** capped at the configured rate.
- TCP's CUBIC congestion control converges to a **roughly equal share** per active flow.
- Adding an SCP client adds a new TCP flow, shrinking each existing flow's share.
- The cap can be changed live with `scripts/set_bandwidth.sh` without restarting containers.

---

## Demo Phases (12 stages)

Each phase lasts 20 seconds, giving ~10 throughput samples per phase (~120 CSV rows total).

| # | Event | Cap | Active SCP | Expected Stream Throughput |
|---|-------|-----|-----------|---------------------------|
| 1 | Baseline — stream only | 50 Mbps | 0 | ~48–50 Mbps |
| 2 | +1 SCP client | 50 Mbps | 1 | ~23–25 Mbps |
| 3 | +2 SCP clients | 50 Mbps | 2 | ~15–17 Mbps |
| 4 | +3 SCP clients | 50 Mbps | 3 | ~11–13 Mbps |
| 5 | −1 SCP client | 50 Mbps | 2 | ~15–17 Mbps |
| 6 | −2 SCP clients | 50 Mbps | 1 | ~23–25 Mbps |
| 7 | All SCP stopped | 50 Mbps | 0 | ~48–50 Mbps |
| 8 | Cap reduced to 20 Mbps | 20 Mbps | 0 | ~18–20 Mbps |
| 9 | +1 SCP client | 20 Mbps | 1 | ~9–10 Mbps |
| 10 | +2 SCP clients | 20 Mbps | 2 | ~6–7 Mbps |
| 11 | All SCP stopped | 20 Mbps | 0 | ~18–20 Mbps |
| 12 | Cap restored to 50 Mbps | 50 Mbps | 0 | ~48–50 Mbps |

**Key observations the data illustrates:**
- **Phases 1–4**: Progressive degradation as more SCP flows compete.
- **Phases 5–7**: Symmetric recovery — TCP fairly releases bandwidth as flows disappear.
- **Phases 8–12**: The same competition pattern repeats at a reduced cap, isolating the cap variable from container state.

---

## Project Structure

```
resource-plan/
├── docker-compose.yml     # Service definitions, static IPs, named networks
├── README.md
├── results/               # Created at runtime — CSV + chart land here
├── scripts/
│   ├── demo.sh            # Orchestrates all 12 phases (~4 min total)
│   ├── monitor.sh         # Live dashboard (run in a second terminal)
│   ├── set_bandwidth.sh   # Change tc rate on the router without restart
│   └── plot_results.py    # Reads results CSV, produces PNG chart
├── router/
│   ├── Dockerfile         # alpine + iproute2 + iptables
│   └── entrypoint.sh      # Applies tc rules and NAT at startup
├── stream-server/
│   ├── Dockerfile         # nginx:alpine + generated 500 MB file
│   └── nginx.conf
├── stream-client/
│   ├── Dockerfile         # alpine + curl + bc
│   └── measure.sh         # Throughput logging loop
├── scp-server/
│   └── Dockerfile         # alpine + openssh-server
└── scp-client/
    ├── Dockerfile          # alpine + openssh-client + sshpass
    └── transfer.sh         # Continuous SCP loop
```

---

## Quick Start

### Prerequisites
- Docker Desktop (Mac/Windows) or Docker Engine + Compose v2 on Linux
- Python 3 + matplotlib for cha:q!
rt generation: `pip install matplotlib`

### Run the demo

```bash
# 1. Build all images (~2 minutes first time; nginx image downloads large file)
docker compose build

# 2. Run the full 12-phase demo (~4 minutes with default 20s phases)
bash scripts/demo.sh

# Optionally: shorten phases for a quick test (5s each, ~1 min total)
bash scripts/demo.sh --duration 5

# 3. In a separate terminal, watch the live dashboard
bash scripts/monitor.sh
```

### Results

After `demo.sh` completes:

```
results/
├── stream_throughput.csv   # timestamp, phase, Mbps per row
└── throughput_chart.png    # annotated chart with phase shading
```

```bash
# View chart on macOS
open results/throughput_chart.png

# Print per-phase summary to terminal
python3 scripts/plot_results.py results/stream_throughput.csv
```

### Manually adjust bandwidth

```bash
# Throttle to 10 Mbps (while containers are running)
bash scripts/set_bandwidth.sh 10mbit

# Restore to 50 Mbps
bash scripts/set_bandwidth.sh 50mbit
```

---

## Teardown

```bash
docker compose down --volumes --remove-orphans
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `tc` commands fail | Ensure `NET_ADMIN` capability is present (already in compose file) |
| Stream throughput shows 0 | Wait 5–10 s for nginx and routing to settle; re-run |
| SCP clients can't connect | `scp-server` needs ~5 s to start sshd; `demo.sh` waits 15 s automatically |
| `set_bandwidth.sh` fails to find interface | Router container must be fully started first |
| Chart not generated | Install matplotlib: `pip install matplotlib` |
