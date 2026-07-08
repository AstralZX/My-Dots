#!/usr/bin/env bash

volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%.0f", $2 * 100}')
[[ -z "$volume" ]] && volume=0

if command -v brightnessctl &>/dev/null; then
  bright=$(brightnessctl get 2>/dev/null)
  max=$(brightnessctl max 2>/dev/null)
  if [[ -n "$bright" && -n "$max" && "$max" -gt 0 ]]; then
    pct=$(( bright * 100 / max ))
  else
    pct=100
  fi
else
  pct=100
fi

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
  bt="on"
else
  bt="off"
fi

if nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -q '^yes'; then
  wifi_str="Wifi"
else
  wifi_str="--"
fi

bat_pct=$(cat /sys/class/power_supply/*/capacity 2>/dev/null | head -1)
[[ -z "$bat_pct" ]] && bat_pct="--"

clock=$(date "+%I:%M %p")

echo "{\"text\":\" ${volume}%   ${pct}%   ${bt}   ${wifi_str}  ${bat_pct}%    ${clock}\",\"class\":\"right-pill\"}"
