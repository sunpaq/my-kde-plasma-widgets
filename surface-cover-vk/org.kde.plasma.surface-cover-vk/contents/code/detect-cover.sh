#!/usr/bin/env bash
# detect-cover.sh - one-shot probe.
# Prints "attached" if a Microsoft Surface Type Cover is present, else "detached".
#
# Detection: the Type Cover enumerates HID input devices whose names contain
# "Surface Type Cover" (e.g. "Microsoft Surface Type Cover Keyboard"), and its
# USB device is 045e:07e8. All of these disappear when the cover is detached.
set -u

grep -qis 'type cover' /sys/class/input/input*/name && { echo attached; exit 0; }

for d in /sys/bus/usb/devices/*/; do
    [ -f "${d}idVendor" ] || continue
    if [ "$(cat "${d}idVendor" 2>/dev/null)" = 045e ] && \
       [ "$(cat "${d}idProduct" 2>/dev/null)" = 07e8 ]; then
        echo attached; exit 0
    fi
done

echo detached