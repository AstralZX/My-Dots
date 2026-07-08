#!/usr/bin/env bash
cpu=$(top -bn1 2>/dev/null | awk '/^%Cpu/ {print 100-$8; exit}' || echo 0)
cpu=${cpu%.*}
mem=$(free -m | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
echo " ${cpu}% ﬙ ${mem}%"
