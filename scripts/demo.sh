#!/bin/bash
# demo.sh — Orchestrates all 12 phases of the bandwidth-sharing demonstration.
#
# Each phase lasts PHASE_DURATION seconds. The stream-client logs throughput
# every 2 seconds, producing ~10 data points per phase (120 rows total).
#
# Usage: bash scripts/demo.sh [--duration SECONDS]
#   --duration  Seconds per phase (default: 20)

set -euo pipefail

PHASE_DURATION=20
while [[ $# -gt 0 ]]; do
  case $1 in
    --duration) PHASE_DURATION="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

COMPOSE="docker compose"
RESULTS_DIR="$(dirname "$0")/../results"
mkdir -p "$RESULTS_DIR"

# ── helpers ────────────────────────────────────────────────────────────────────

log() { echo "[$(date +%H:%M:%S)] $*"; }

advance_phase() {
  local num=$1 label=$2
  log ""
  log "══════════════════════════════════════════════════"
  log " PHASE $num/12 — $label"
  log "══════════════════════════════════════════════════"
  # Write phase number into the shared volume so measure.sh annotates the CSV
  $COMPOSE exec -T stream-client sh -c "echo $num > /results/phase.txt"
  sleep "$PHASE_DURATION"
}

start_scp() {
  local name=$1
  local num=${name: -1}
  log "Starting $name..."
  $COMPOSE --profile scp run -d --name "$name" --rm --no-deps "scp-client-${num}" /transfer.sh
}

stop_scp() {
  local name=$1
  log "Stopping $name..."
  docker stop "$name" 2>/dev/null || true
}

# ── startup ────────────────────────────────────────────────────────────────────

log "Building images (if needed)..."
$COMPOSE --profile scp build --quiet

log "Starting core services: router, stream-server, scp-server, stream-client..."
$COMPOSE up -d router stream-server scp-server stream-client

log "Waiting 15s for services to initialize and routing to settle..."
sleep 15

log "Initialising phase counter..."
$COMPOSE exec -T stream-client sh -c "mkdir -p /results && echo 1 > /results/phase.txt"

log "Starting throughput measurement loop in stream-client..."
$COMPOSE exec -d stream-client /measure.sh

sleep 3  # let measure.sh write its CSV header

# ── phases ─────────────────────────────────────────────────────────────────────

advance_phase 1 "Baseline — stream only @ 50 Mbps"

start_scp scp1 || true
advance_phase 2 "+1 SCP client @ 50 Mbps"

start_scp scp2 || true
advance_phase 3 "+2 SCP clients @ 50 Mbps"

start_scp scp3 || true
advance_phase 4 "+3 SCP clients @ 50 Mbps (peak congestion)"

docker stop scp3 2>/dev/null || true
advance_phase 5 "−1 SCP client (partial recovery)"

docker stop scp2 2>/dev/null || true
advance_phase 6 "−2 SCP clients (further recovery)"

docker stop scp1 2>/dev/null || true
advance_phase 7 "All SCP stopped — stream fully recovers @ 50 Mbps"

log "Reducing bandwidth cap to 20 Mbps..."
bash "$(dirname "$0")/set_bandwidth.sh" 20mbit
advance_phase 8 "Cap reduced to 20 Mbps — stream only"

start_scp scp1 || true
advance_phase 9 "+1 SCP client @ 20 Mbps"

start_scp scp2 || true
advance_phase 10 "+2 SCP clients @ 20 Mbps (congested low-cap link)"

docker stop scp1 scp2 2>/dev/null || true
advance_phase 11 "SCP stopped — stream recovers @ 20 Mbps"

log "Restoring bandwidth cap to 50 Mbps..."
bash "$(dirname "$0")/set_bandwidth.sh" 50mbit
advance_phase 12 "Cap restored to 50 Mbps — full restoration confirmed"

# ── collect results ────────────────────────────────────────────────────────────

log ""
log "=== Demo complete ==="
log "Copying results CSV from stream-client..."
$COMPOSE cp stream-client:/results/stream_throughput.csv "$RESULTS_DIR/stream_throughput.csv"
log "Saved: $RESULTS_DIR/stream_throughput.csv"

log "Generating chart..."
python3 "$(dirname "$0")/plot_results.py" "$RESULTS_DIR/stream_throughput.csv" \
  "$RESULTS_DIR/throughput_chart.png" && \
  log "Chart saved: $RESULTS_DIR/throughput_chart.png"

log ""
log "Results summary:"
echo "----------------------------------------------------"
echo "phase,avg_mbps,min_mbps,max_mbps"
tail -n +2 "$RESULTS_DIR/stream_throughput.csv" | \
  awk -F',' '
    {
      phase=$2; mbps=$3
      sum[phase]+=mbps; cnt[phase]++
      if (cnt[phase]==1 || mbps<min[phase]) min[phase]=mbps
      if (cnt[phase]==1 || mbps>max[phase]) max[phase]=mbps
    }
    END {
      for (p=1; p<=12; p++)
        if (cnt[p]>0)
          printf "%d,%.2f,%.2f,%.2f\n", p, sum[p]/cnt[p], min[p], max[p]
    }
  '
echo "----------------------------------------------------"
