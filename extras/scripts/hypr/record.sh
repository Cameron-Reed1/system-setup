#!/usr/bin/env bash

wf-recorder "$@" &
pkill -RTMIN+12 waybar
wait; pkill -RTMIN+12 waybar
