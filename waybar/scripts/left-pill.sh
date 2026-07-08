#!/usr/bin/env bash
cpu=$(top -bn1 2>/dev/null | awk '/^%Cpu/ {printf "%.0f", 100-$8; exit}' || echo 0)
mem_used=$(free -b | awk '/^Mem:/ {printf "%.1f", $3/1073741824}')
disk_used=$(df -B1 / | awk 'NR==2 {printf "%.1f", $3/1073741824}')
sep="<span foreground='#2A2A2A'>●</span>"
echo "{\"text\":\"  ${sep}  ${cpu}%  ${sep}  ${mem_used}G  ${sep}  ${disk_used}GiB\",\"class\":\"left-pill\"}"
