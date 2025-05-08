#!/usr/bin/env bash


lines='-l 4'
options='Log out\nShutdown\nReboot\nCancel'

answer=$(echo -e "$options" | wmenu "$lines" -i -p 'Action:')

case $answer in
	'Log out')
		hyprctl dispatch exit
		;;
	'Shutdown')
		systemctl poweroff
		;;
	'Reboot')
		systemctl reboot
		;;
esac
