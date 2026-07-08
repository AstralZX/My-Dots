#!/usr/bin/env bash
# Real-time network speed (requires /proc/net/dev)

IFACE=$(ip route | awk '/^default/ {print $5; exit}')

rx1=$(awk -v i="$IFACE" '$1 ~ i":" {print $2}' /proc/net/dev)
tx1=$(awk -v i="$IFACE" '$1 ~ i":" {print $10}' /proc/net/dev)
sleep 1
rx2=$(awk -v i="$IFACE" '$1 ~ i":" {print $2}' /proc/net/dev)
tx2=$(awk -v i="$IFACE" '$1 ~ i":" {print $10}' /proc/net/dev)

rx_diff=$((rx2 - rx1))
tx_diff=$((tx2 - tx1))

format() {
  local val=$1
  if   [ "$val" -gt 1048576 ]; then printf "%.1f MB/s" "$(echo "scale=1; $val/1048576" | bc)";
  elif [ "$val" -gt 1024 ];    then printf "%.0f KB/s" "$((val / 1024))";
  else                              printf "%d B/s" "$val";
  fi
}

down=$(format $rx_diff)
up=$(format $tx_diff)

echo " ${down}   ${up}"
