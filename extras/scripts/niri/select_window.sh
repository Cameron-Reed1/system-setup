#!/usr/bin/env bash


niri msg --json windows \
    | jq -r '.[] | [.id, .title, .app_id] | @csv' \
    | sed 's/\(.*\),"\(.*\)","\(.*\)"/\1\t\2\t\3\x00icon\x1f\3/' \
    | fuzzel --dmenu --with-nth=2 --accept-nth=1 --match-nth='{1..}'
