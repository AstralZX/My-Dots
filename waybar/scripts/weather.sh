#!/usr/bin/env bash
cache="/tmp/waybar-weather.cache"
cache_max=600

if [[ -f "$cache" ]]; then
  mod=$(stat -c %Y "$cache")
  now=$(date +%s)
  diff=$((now - mod))
  if [[ $diff -lt $cache_max ]]; then
    cat "$cache"
    exit 0
  fi
fi

weather=$(curl -s --max-time 3 "wttr.in/?format=%C+%t&m" 2>/dev/null | tr -d '\n')
if [[ -n "$weather" ]]; then
  echo "$weather" > "$cache"
  echo "$weather"
else
  [[ -f "$cache" ]] && cat "$cache" || echo "󰖙 --"
fi
