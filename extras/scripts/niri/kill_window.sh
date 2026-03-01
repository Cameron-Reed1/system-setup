#!/usr/bin/env bash


selected_id=$(~/scripts/niri/select_window.sh)
[ -z "$selected_id" ] && exit

pid=$(niri msg --json windows | jq -r ".[] | select(.id==${selected_id}) | .pid")
[ -z "$pid" ] && exit


if [ "$2" = "force" ]; then
    kill -9 "$pid"
else
    kill "$pid"
fi
