#!/bin/bash
# monitor.sh — Live dashboard showing router tc stats and latest stream throughput.
# Run this in a separate terminal while demo.sh is running.

COMPOSE="docker compose"

while true; do
  clear
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║        LIVE BANDWIDTH MONITOR  $(date +%H:%M:%S)           ║"
  echo "╚══════════════════════════════════════════════════════╝"

  echo ""
  echo "── Router tc class stats ─────────────────────────────"
  CLIENT_IF=$($COMPOSE exec -T router ip -br addr 2>/dev/null | \
    awk '/172\.20\./ {print $1}' | tr -d '\r')
  if [ -n "$CLIENT_IF" ]; then
    $COMPOSE exec -T router tc -s class show dev "$CLIENT_IF" 2>/dev/null || \
      echo "(router not ready)"
  else
    echo "(router not ready)"
  fi

  echo ""
  echo "── Stream client — last 10 measurements ─────────────"
  $COMPOSE exec -T stream-client tail -10 /results/stream_throughput.csv 2>/dev/null || \
    echo "(stream-client not running or no data yet)"

  echo ""
  echo "── Active containers ─────────────────────────────────"
  docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | \
    grep -E "NAME|router|stream|scp" || true

  sleep 2
done
