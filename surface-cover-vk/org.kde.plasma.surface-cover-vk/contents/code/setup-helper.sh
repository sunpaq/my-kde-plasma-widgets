#!/usr/bin/env bash
# setup-helper.sh - one-time setup for the Surface Cover Virtual Keyboard widget.
#
# Installs the cover-aware KWin input-method switcher (kwin-im-switcher) and
# registers it in kwinrc so KWin launches it as its Wayland virtual keyboard /
# input method. Optionally disables the standalone surface-cover-vk systemd
# user service, since the widget itself now runs the detection loop.
#
# Usage: setup-helper.sh [TAKE_OVER_SYSTEMD]   (0 or 1, default 1)
set -u

TAKE_OVER_SYSTEMD="${1:-1}"
DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
SRC_LAUNCHER="$DIR/kwin-im-switcher"
SRC_DESKTOP="$DIR/kwin-im-switcher.desktop"
DST_LAUNCHER="$BIN_DIR/kwin-im-switcher"
DST_DESKTOP="$APP_DIR/kwin-im-switcher.desktop"

[ -f "$SRC_LAUNCHER" ] || { echo "setup-helper: missing $SRC_LAUNCHER" >&2; exit 1; }
[ -f "$SRC_DESKTOP" ] || { echo "setup-helper: missing $SRC_DESKTOP" >&2; exit 1; }

mkdir -p "$BIN_DIR" "$APP_DIR"

# 1. Install the launcher script (rm first: never write through existing symlinks)
rm -f "$DST_LAUNCHER"
install -m0755 "$SRC_LAUNCHER" "$DST_LAUNCHER"
echo "setup-helper: installed launcher -> $DST_LAUNCHER"

# 2. Write the .desktop entry, substituting the absolute bin dir into Exec=
rm -f "$DST_DESKTOP"
sed "s|@HOMEBIN@|$BIN_DIR|g" "$SRC_DESKTOP" > "$DST_DESKTOP"
echo "setup-helper: installed desktop entry -> $DST_DESKTOP"

# 3. Register it in kwinrc and ensure the virtual keyboard is enabled
kwriteconfig6 --file kwinrc --group Wayland --key InputMethod "$DST_DESKTOP"
kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true
echo "setup-helper: kwinrc [Wayland] InputMethod = $DST_DESKTOP"
echo "setup-helper: kwinrc [Wayland] VirtualKeyboardEnabled = true"

# 4. Optionally let the widget take over from the standalone systemd daemon
if [ "$TAKE_OVER_SYSTEMD" = "1" ]; then
    if systemctl --user list-unit-files surface-cover-vk.service >/dev/null 2>&1; then
        systemctl --user disable --now surface-cover-vk.service 2>/dev/null || true
        echo "setup-helper: disabled+stopped surface-cover-vk.service (widget now manages detection)"
    fi
fi

# 5. Tell KWin to reload its input method (best-effort; harmless if it fails)
busctl --user call org.kde.KWin /VirtualKeyboard org.freedesktop.DBus.Properties \
    Set ssv org.kde.kwin.VirtualKeyboard active b true >/dev/null 2>&1 || true

echo "setup-helper: done"