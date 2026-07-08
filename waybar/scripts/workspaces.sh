#!/usr/bin/env bash
# PeachWM tags → waybar custom module (JSON + pango)

declare -A focused occupied visible

while read -r line; do
  if [[ $line =~ ^HDMI-A-1\ tag\ ([0-8])\ ([01])\ ([01])\ ([01])$ ]]; then
    idx="${BASH_REMATCH[1]}"
    focused[$idx]="${BASH_REMATCH[2]}"
    visible[$idx]="${BASH_REMATCH[3]}"
    occupied[$idx]="${BASH_REMATCH[4]}"
  fi
done < <(/usr/local/bin/peachmsg -g 2>/dev/null)

parts=()
for i in 1 2 3 4 5 6 7 8 9; do
  idx=$((i - 1))
  case "${focused[$idx]}-${occupied[$idx]}" in
    1-*)  parts+=("<span weight='bold' foreground='#e6e6e6'>$i</span>") ;;  # focused
    0-1)  parts+=("<span foreground='#8a8a8a'>$i</span>") ;;                # occupied, not focused
    0-0)  parts+=("<span foreground='#3a3a3a'>$i</span>") ;;                # empty
  esac
done

out=$(
  IFS=' '
  echo "${parts[*]}"
)
echo "{\"text\":\"$out\",\"class\":\"workspaces\",\"tooltip\":\"PeachWM tags\"}"
