#!/usr/bin/env bash
# Pacman / AUR update count

if command -v checkupdates &>/dev/null; then
  pac=$(checkupdates 2>/dev/null | wc -l)
elif command -v pacman &>/dev/null; then
  pac=$(pacman -Qu 2>/dev/null | wc -l)
else
  echo ""; exit 0
fi

aur=0
if command -v paru &>/dev/null; then
  aur=$(paru -Qua 2>/dev/null | wc -l)
elif command -v yay &>/dev/null; then
  aur=$(yay -Qua 2>/dev/null | wc -l)
fi

total=$((pac + aur))
[[ "$total" -eq 0 ]] && echo '{"text":"","class":"empty"}' && exit 0
echo "{\"text\":\"  ${total}\",\"class\":\"has-updates\"}"
