#!/usr/bin/env bash


selected_id=$(~/scripts/niri/select_window.sh)

[ -n "$selected_id" ] && niri msg action focus-window --id "$selected_id"
