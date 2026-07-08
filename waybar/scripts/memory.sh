#!/usr/bin/env bash
mem_used=$(free -h | awk '/Mem:/ {print $3}')
mem_total=$(free -h | awk '/Mem:/ {print $2}')
mem_pct=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
echo "﬙ ${mem_used}/${mem_total} (${mem_pct}%)"
