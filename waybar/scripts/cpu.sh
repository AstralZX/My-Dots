#!/usr/bin/env bash
cpu_usage=$(top -bn1 2>/dev/null | awk '/^%Cpu/ {printf "%.0f", 100-$8; exit}' || echo 0)
cpu_temp=$(sensors 2>/dev/null | awk '/^Package id/ {print $4}' | sed 's/[^0-9.]//g' | cut -d. -f1)
[[ -z "$cpu_temp" ]] && cpu_temp=$(sensors 2>/dev/null | awk '/^CPU/ {print $2}' | sed 's/[^0-9.]//g' | cut -d. -f1)
[[ -z "$cpu_temp" ]] && cpu_temp="--"

echo " ${cpu_usage}%  ${cpu_temp}°C"
