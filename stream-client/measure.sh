#!/bin/sh
# Continuously download the stream file and log throughput every 2 seconds.
# Phase number is read from /results/phase.txt so demo.sh can annotate the CSV.

LOG=/results/stream_throughput.csv
mkdir -p /results
echo "timestamp,phase,mbps" > "$LOG"

echo "[stream-client] Measurement started. Logging to $LOG"

# Ensure default route goes through router
ip route replace default via 172.20.0.1 2>/dev/null || true

while true; do
  # Read current phase (written by demo.sh); default to 1
  PHASE=$(cat /results/phase.txt 2>/dev/null || echo 1)

  # Download for 2 seconds and capture bytes transferred
  BYTES=$(curl -s -o /dev/null \
    --max-time 2 \
    --connect-timeout 3 \
    -w "%{size_download}" \
    "http://172.21.0.10/stream.bin" 2>/dev/null)

  # Convert bytes to Mbps (bytes / 2s / 1048576 * 8)
  if [ -n "$BYTES" ] && [ "$BYTES" -gt 0 ] 2>/dev/null; then
    MBPS=$(echo "scale=2; $BYTES * 8 / 2 / 1048576" | bc)
  else
    MBPS="0.00"
  fi

  TS=$(date +%H:%M:%S)
  echo "$TS,$PHASE,$MBPS"
  echo "$TS,$PHASE,$MBPS" >> "$LOG"
done
