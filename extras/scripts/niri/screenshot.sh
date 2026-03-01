#!/usr/bin/env bash


options='Selection\x00icon\x1fselection\nWindow\x00icon\x1fwindow\nMonitor\x00icon\x1fmonitor'

answer=$(echo -e "$options" | fuzzel -d -p 'Action: ')

case $answer in
	'Selection')
        niri msg action screenshot
		;;
    'Window')
        selected_id=$(~/scripts/niri/select_window.sh)

        [ -n "$selected_id" ] && niri msg action screenshot-window --id "$selected_id"
        ;;
	'Monitor')
        niri msg action screenshot-screen
		;;
esac
