#!/bin/bash
# Usage: ./scripts/set_bandwidth.sh <rate>
# Example: ./scripts/set_bandwidth.sh 20mbit
#
# Changes the HTB class rate on the router's client-facing interface.
# The router container must be running.

RATE=${1:-50mbit}

# Find the client-net interface inside the router container
CLIENT_IF=$(docker compose exec -T router ip -br addr | awk '/172\.20\./ {print $1}' | cut -d'@' -f1 | tr -d '\r')

if [ -z "$CLIENT_IF" ]; then
  echo "ERROR: Could not detect client interface in router container." >&2
  exit 1
fi

docker compose exec -T router \
  tc class change dev "$CLIENT_IF" parent 1: classid 1:1 htb rate "$RATE" ceil "$RATE"

echo "[$(date +%H:%M:%S)] Total bandwidth cap changed to $RATE on $CLIENT_IF"
