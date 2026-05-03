#!/bin/sh
set -e

# Identify the client-facing interface (172.20.x.x network)
CLIENT_IF=$(ip -br addr | awk '/172\.20\./ {print $1}' | cut -d'@' -f1)
SERVER_IF=$(ip -br addr | awk '/172\.21\./ {print $1}' | cut -d'@' -f1)

echo "[router] Client interface: $CLIENT_IF"
echo "[router] Server interface: $SERVER_IF"

# ── HTB hierarchy ──────────────────────────────────────────────────────────────
# Root qdisc; unclassified traffic falls into class 1:10 (stream-client).
tc qdisc add dev "$CLIENT_IF" root handle 1: htb default 10

# Parent class — total link cap (50 Mbps).  set_bandwidth.sh changes this rate.
tc class add dev "$CLIENT_IF" parent 1:  classid 1:1  htb rate 50mbit ceil 50mbit

# Stream-client (172.20.0.10) — gets whatever the SCP clients leave behind.
# Low guaranteed rate so HTB doesn't reserve the entire link for the stream.
tc class add dev "$CLIENT_IF" parent 1:1 classid 1:10 htb rate 1mbit ceil 50mbit

# SCP clients — hard per-client caps (rate == ceil means no borrowing).
tc class add dev "$CLIENT_IF" parent 1:1 classid 1:20 htb rate  5mbit ceil  5mbit
tc class add dev "$CLIENT_IF" parent 1:1 classid 1:30 htb rate 10mbit ceil 10mbit
tc class add dev "$CLIENT_IF" parent 1:1 classid 1:40 htb rate 15mbit ceil 15mbit

# SFQ inside each leaf class for per-flow fairness.
tc qdisc add dev "$CLIENT_IF" parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev "$CLIENT_IF" parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev "$CLIENT_IF" parent 1:30 handle 30: sfq perturb 10
tc qdisc add dev "$CLIENT_IF" parent 1:40 handle 40: sfq perturb 10

# ── Filters — classify by destination IP ──────────────────────────────────────
tc filter add dev "$CLIENT_IF" parent 1: protocol ip prio 1 u32 \
  match ip dst 172.20.0.10/32 flowid 1:10
tc filter add dev "$CLIENT_IF" parent 1: protocol ip prio 1 u32 \
  match ip dst 172.20.0.20/32 flowid 1:20
tc filter add dev "$CLIENT_IF" parent 1: protocol ip prio 1 u32 \
  match ip dst 172.20.0.21/32 flowid 1:30
tc filter add dev "$CLIENT_IF" parent 1: protocol ip prio 1 u32 \
  match ip dst 172.20.0.22/32 flowid 1:40

echo "[router] tc HTB qdisc applied: 50 Mbps total, SCP caps 5/10/15 Mbps on $CLIENT_IF"

# NAT: allow client-net containers to reach server-net
iptables -t nat -A POSTROUTING -o "$SERVER_IF" -j MASQUERADE

echo "[router] NAT configured. Router is ready."

# Keep container alive; demo.sh uses 'docker compose exec router ...' to change rate
exec tail -f /dev/null
