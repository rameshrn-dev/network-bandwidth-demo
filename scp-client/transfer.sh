#!/bin/sh
# Continuously download the 500 MB test file from the server, discarding output.
# This simulates bulk download traffic competing with the stream on the shared link.

SCP_SERVER=172.21.0.11

echo "[scp-client] Starting continuous SCP downloads from $SCP_SERVER"

# Ensure default route goes through router
ip route replace default via 172.20.0.1 2>/dev/null || true

COUNT=0
while true; do
  COUNT=$((COUNT + 1))
  sshpass -p "pass1234" scp \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    "root@${SCP_SERVER}:/tmp/testfile.bin" /dev/null 2>/dev/null
  echo "[scp-client] Download #$COUNT complete"
done
