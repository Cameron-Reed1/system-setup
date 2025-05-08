#!/usr/bin/env bash

ip=$(adb shell ip a s | grep 'inet ' | grep -v "\blo\b" | awk '{print $2}' | cut -d '/' -f 1)
adb tcpip 5555

sleep 1
adb connect "${ip}:5555"
