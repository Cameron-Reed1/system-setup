#!/usr/bin/env bash


if pkill wf-recorder; then
    pkill -RTMIN+12 waybar
    exit
fi

# options='Selection\x00icon\x1fselection\nWindow\x00icon\x1fwindow\nMonitor\x00icon\x1fmonitor'
options='Selection\x00icon\x1fselection\nMonitor\x00icon\x1fmonitor'

answer=$(echo -e "$options" | fuzzel -d -p 'Record: ')

case $answer in
	'Selection')
        selection=$(slurp)
        [ -z "$selection" ] && exit

        wf-recorder -a -f "$HOME/Videos/recordings/$(date '+%Y_%m_%d_%H%M%S').mkv" -g "$selection" &
		;;
    'Window')
        selected_id=$(~/scripts/niri/select_window.sh)
        [ -z "$selected_id" ] && exit

        notify-send "Haven't found a way to do this with niri yet"
        exit
        ;;
	'Monitor')
        selected_monitor=$(niri msg --json outputs \
            | jq -r '.[] | [.name, .make, .model] | @csv' \
            | sed 's/"\(.*\)","\(.*\)","\(.*\)"/\1\t\1 [\2 \3]\x00icon\x1fmonitor/' \
            | fuzzel --dmenu --with-nth=2 --accept-nth=1)
        [ -z "$selected_monitor" ] && exit

        wf-recorder -a -f "$HOME/Videos/recordings/$(date '+%Y_%m_%d_%H%M%S').mkv" -o "$selected_monitor" &
        ;;
esac

pkill -RTMIN+12 waybar
wait
pkill -RTMIN+12 waybar
