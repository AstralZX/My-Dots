#!/usr/bin/env bash
if command -v nvidia-smi &>/dev/null; then
  data=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
  IFS=',' read -r temp usage mem_used mem_total <<< "$data"
  if [[ -n "$temp" ]]; then
    echo "󰢮 ${temp}°C ${usage}% ﬙ ${mem_used}/${mem_total}MiB"
  else
    echo "󰢮 --"
  fi
else
  echo ""
fi
