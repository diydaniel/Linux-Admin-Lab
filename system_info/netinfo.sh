#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

echo "=== Interfaces (brief) ==="
if have ip; then
  ip -brief addr show | grep -v ' lo ' || true
else
  echo "ip(8) not found. Trying ifconfig..."
  if have ifconfig; then ifconfig -a; else echo "No ip/ifconfig available."; fi
fi

echo -e "\n=== Default Routes ==="
if have ip; then
  ip route show default || true
else
  echo "ip(8) not found; skipping route display."
fi

echo -e "\n=== DNS Resolvers ==="
# Try systemd-resolved first (more accurate on many modern distros)
if have resolvectl; then
  resolvectl dns || resolvectl status | sed -n '/DNS Servers/,+3p'
elif have systemd-resolve; then
  systemd-resolve --status | sed -n '/DNS Servers/,+3p'
elif [[ -e /etc/resolv.conf ]]; then
  grep -E '^nameserver' /etc/resolv.conf || echo "No nameservers in resolv.conf"
else
  echo "No resolv.conf and no resolvectl found."
fi

echo -e "\n=== Listening TCP/UDP (ports) ==="
if have ss; then
  ss -tulpen || true
elif have netstat; then
  netstat -tulpen || true
else
  echo "Neither ss(8) nor netstat(8) available."
fi
