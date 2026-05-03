#!/bin/sh
# Generate a 500 MB file for clients to download, then start sshd.
echo "[scp-server] Generating 500 MB download file..."
dd if=/dev/urandom of=/tmp/testfile.bin bs=1M count=500 2>/dev/null
echo "[scp-server] Ready. Starting sshd."
exec /usr/sbin/sshd -D -e
