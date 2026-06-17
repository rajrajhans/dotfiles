#!/usr/bin/env bash
# tailscaled as an exit node, then gost (SOCKS5 + HTTP) bound to the tailnet IP only.
set -euo pipefail

: "${TS_AUTHKEY:?TS_AUTHKEY must be set as a Fly secret (flyctl secrets set)}"
TS_HOSTNAME="${TS_HOSTNAME:-fly-us-exit}"
SOCKS_PORT="${SOCKS_PORT:-1080}"
HTTP_PORT="${HTTP_PORT:-8080}"

# exit-node routing needs IP forwarding
sysctl -w net.ipv4.ip_forward=1 || true
sysctl -w net.ipv6.conf.all.forwarding=1 || true

mkdir -p /var/lib/tailscale /var/run/tailscale

# kernel/tun mode — userspace mode can't be an exit node
tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock &

# wait for the control socket
for _ in $(seq 1 60); do
  [ -S /var/run/tailscale/tailscaled.sock ] && break
  sleep 0.5
done

tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TS_HOSTNAME}" \
  --advertise-exit-node \
  --accept-dns=false \
  --accept-routes=false

# resolve the tailnet IP so the proxy can bind to it alone
TS_IP=""
for _ in $(seq 1 60); do
  TS_IP="$(tailscale ip -4 2>/dev/null || true)"
  [ -n "$TS_IP" ] && break
  sleep 0.5
done
[ -n "$TS_IP" ] || { echo "fatal: could not determine tailnet IP" >&2; exit 1; }

echo "tailnet IP ${TS_IP}: gost socks5://${TS_IP}:${SOCKS_PORT} + http://${TS_IP}:${HTTP_PORT}"

exec gost \
  -L "socks5://${TS_IP}:${SOCKS_PORT}" \
  -L "http://${TS_IP}:${HTTP_PORT}"
