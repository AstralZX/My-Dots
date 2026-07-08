#!/usr/bin/env bash
PEACHMSG="/usr/local/bin/peachmsg"

output=$("$PEACHMSG" -g -c 2>/dev/null) || { echo '{"text":""}'; exit 0; }
[ -z "$output" ] && { echo '{"text":""}'; exit 0; }

while IFS= read -r line; do
    case "$line" in
        *title\ *) title="${line#*title }" ;;
        *appid\ *) appid="${line#*appid }" ;;
    esac
done <<< "$output"

appid_lower="${appid,,}"
case "$appid_lower" in
    *firefox*)        icon="󰈹" ;;
    *kitty*)          icon="" ;;
    *alacritty*|*foot*) icon="" ;;
    *spotify*)        icon="" ;;
    *discord*)        icon="󰙯" ;;
    *thunar*|*nautilus*|*dolphin*) icon="󰉋" ;;
    *code*|*vscode*)  icon="󰨞" ;;
    *slack*)          icon="󰒱" ;;
    *telegram*)       icon="" ;;
    *chromium*|*google-chrome*|*brave*|*zen*) icon="󰊯" ;;
    *thunderbird*)    icon="󰴃" ;;
    *obsidian*)       icon="󱓧" ;;
    *libreoffice*)    icon="󰈙" ;;
    *mpv*|*vlc*)      icon="󰕼" ;;
    *feh*|*imv*|*sxiv*) icon="󰋩" ;;
    *steam*)          icon="󰓓" ;;
    *signal*)         icon="󰭹" ;;
    *whatsapp*)       icon="󰖣" ;;
esac

echo "{\"text\":\"${icon:-}\",\"tooltip\":\"${appid:-}${title:+ - $title}\",\"class\":\"window\"}"
