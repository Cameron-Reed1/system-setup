#!/usr/bin/env bash


options='Log out\nLock Session\nShutdown\nReboot\nCancel'

answer=$(echo -e "$options" | wmenu -l "$(echo -e "$options" | wc -l)" -i -p 'Action:')

case $answer in
	'Log out')
		hyprctl dispatch exit
		;;
    'Lock Session')
        loginctl lock-session && hyprctl dispatch dpms off
        ;;
	'Shutdown')
		systemctl poweroff
		;;
	'Reboot')
		systemctl reboot
		;;
esac
