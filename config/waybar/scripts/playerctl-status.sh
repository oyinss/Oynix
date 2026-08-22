#!/bin/sh

status=$(playerctl status 2>/dev/null || true)
artist=$(playerctl metadata artist 2>/dev/null || true)
title=$(playerctl metadata title 2>/dev/null || true)

case "$status" in
  Playing) icon="" ;;
  *) icon="" ;;
esac

if [ -n "$artist" ] && [ -n "$title" ]; then
  tooltip="$artist - $title"
else
  tooltip=${title:-No media playing}
fi

jq --compact-output --null-input \
  --arg text "$icon" \
  --arg tooltip "$tooltip" \
  '{text: $text, tooltip: $tooltip}'
