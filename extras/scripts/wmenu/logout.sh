#!/usr/bin/env bash


session="unknown"
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    session="hyprland"
elif [ -n "$NIRI_SOCKET" ]; then
    session="niri"
fi

echo "$session"


if [ "$session" = "unknown" ]; then
    options='Lock session\x00icon\x1flock\nShutdown\x00icon\x1fpower\nReboot\x00icon\x1freboot\nReboot to UEFI Settings\x00icon\x1fuefi'
else
    options='Log out\x00icon\x1flogout\nLock session\x00icon\x1flock\nShutdown\x00icon\x1fpower\nReboot\x00icon\x1freboot\nReboot to UEFI Settings\x00icon\x1fuefi'
fi

answer=$(echo -e "$options" | fuzzel -d -p 'Action: ')
# answer=$(echo -e "$options" | wmenu -l "$(echo -e "$options" | wc -l)" -i -p 'Action:')

case $answer in
	'Log out')
        [ "$session" = "hyprland" ] && hyprctl dispatch exit
        [ "$session" = "niri" ] && niri msg action quit -s
		;;
    'Lock session')
        loginctl lock-session || exit
        [ "$session" = "hyprland" ] && sleep 3 && hyprctl dispatch dpms off
        [ "$session" = "niri" ] && sleep 3 && niri msg action power-off-monitors
        ;;
	'Shutdown')
		systemctl poweroff
		;;
	'Reboot')
		systemctl reboot
		;;
    'Reboot to UEFI Settings')
        run0 bootctl reboot-to-firmware true
        systemctl reboot
        ;;
esac
