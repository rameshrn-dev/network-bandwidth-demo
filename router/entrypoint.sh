#!/bin/sh
set -e

# Identify the client-facing interface (172.20.x.x network)
CLIENT_IF=$(ip -br addr | awk '/172\.20\./ {print $1}' | cut -d'@' -f1)
SERVER_IF=$(ip -br addr | awk '/172\.21\./ {print $1}' | cut -d'@' -f1)

echo "[router] Client interface: $CLIENT_IF"
echo "[router] Server interface: $SERVER_IF"

# Apply HTB qdisc to cap total bandwidth to 50 Mbps on client-facing interface.
# All clients share this single class, so TCP congestion control distributes it fairly.
tc qdisc add dev "$CLIENT_IF" root handle 1: htb default 10
tc class add dev "$CLIENT_IF" parent 1: classid 1:10 htb rate 50mbit ceil 50mbit
tc qdisc add dev "$CLIENT_IF" parent 1:10 handle 10: sfq perturb 10

echo "[router] tc HTB qdisc applied: 50 Mbps cap on $CLIENT_IF"

# NAT: allow client-net containers to reach server-net
iptables -t nat -A POSTROUTING -o "$SERVER_IF" -j MASQUERADE

echo "[router] NAT configured. Router is ready."

# Keep container alive; demo.sh uses 'docker compose exec router ...' to change rate
exec tail -f /dev/null
