#!/usr/bin/env bash


uid=1000


if [ -z "$NIRI_SOCKET" ]; then
    export NIRI_SOCKET="$(echo /run/user/"$uid"/niri.wayland-1.*.sock)"

    if [ -z "$NIRI_SOCKET" ] || [ "$NIRI_SOCKET" = "/run/user/$uid/niri.wayland-1.*.sock" ]; then
        echo "Niri socket was not set and could not be found" >&2
        exit 1
    fi
fi

session=$(loginctl show-user "$uid" | grep Display | cut -d '=' -f 2)
if [ -n "$session" ]; then
    locked=$(loginctl show-session "$session" | grep LockedHint | cut -d '=' -f 2)
    if [ "$locked" = "no" ]; then
        loginctl lock-session "$session" || (echo "Locking session failed" >&2; exit 2)
    fi
fi
niri msg action power-off-monitors
