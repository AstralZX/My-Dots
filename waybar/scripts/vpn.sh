#!/usr/bin/env bash
# VPN / tunnel status

if command -v mullvad &>/dev/null; then
  status=$(mullvad status 2>/dev/null | head -1)
  if echo "$status" | grep -qi "connected"; then
    echo '{"text":"  Mullvad","class":"connected"}'
    exit 0
  fi
fi

if ip link show tun0 &>/dev/null 2>&1; then
  echo '{"text":"  VPN","class":"connected"}'
  exit 0
fi

echo '{"text":"","class":"empty"}'
