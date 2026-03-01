#!/usr/bin/env bash


app_id="$1"
command="$2"


function usage() {
    echo "Usage: $0 [app_id] [command]"
}


if [ -z "$app_id" ] || [ -z "$command" ]; then
    usage "$0" >&2
    exit 1
fi

window_id=$(niri msg -j windows | jq ".[] | select(.app_id == \"$app_id\").id" | head -n 1)
if [ -n "$window_id" ]; then
    niri msg action focus-window --id "$window_id"
else
    niri msg action spawn -- "$command"
fi
