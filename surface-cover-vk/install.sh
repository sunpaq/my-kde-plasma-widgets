#!/bin/bash
# Install the Surface Cover Virtual Keyboard Plasma 6 widget and run the
# one-time setup helper that registers the cover-aware input-method switcher.
#
# Usage: ./install.sh [TAKE_OVER_SYSTEMD]   (0 or 1, default 1)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$SCRIPT_DIR/org.kde.plasma.surface-cover-vk"
TAKE_OVER_SYSTEMD="${1:-1}"

if [ ! -d "$WIDGET_DIR" ]; then
    echo "Error: widget directory not found at $WIDGET_DIR"
    exit 1
fi

echo "Installing Surface Cover Virtual Keyboard widget..."

# Install the plasmoid
if command -v kpackagetool6 &>/dev/null; then
    kpackagetool6 --type=Plasma/Applet -i "$WIDGET_DIR" 2>/dev/null || \
    kpackagetool6 --type=Plasma/Applet -u "$WIDGET_DIR"
    echo "Plasmoid installed via kpackagetool6"
else
    mkdir -p ~/.local/share/plasma/plasmoids/
    rm -rf ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk
    cp -r "$WIDGET_DIR" ~/.local/share/plasmoids/
    echo "Plasmoid installed via manual copy to ~/.local/share/plasma/plasmoids/"
fi

# Make bundled scripts executable
INSTALLED="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk"
chmod +x "$INSTALLED/contents/code/"*.sh "$INSTALLED/contents/code/kwin-im-switcher" 2>/dev/null || true

# Run the one-time setup helper (registers kwin-im-switcher in kwinrc)
echo ""
echo "Running setup helper (TAKE_OVER_SYSTEMD=$TAKE_OVER_SYSTEMD)..."
bash "$INSTALLED/contents/code/setup-helper.sh" "$TAKE_OVER_SYSTEMD"

echo ""
echo "Installation complete!"
echo ""
echo "To use the widget:"
echo "  1. Right-click your panel or desktop"
echo "  2. Select 'Add Widgets...'"
echo "  3. Search for 'Surface Cover Virtual Keyboard'"
echo "  4. Drag it to your panel"
echo ""
echo "If the widget does not appear, restart plasmashell:"
echo "  systemctl --user restart plasma-plasmashell.service"
echo "  or: kquitapp6 plasmashell && kstart plasmashell"
echo ""
echo "Prerequisites:"
echo "  - KDE Plasma 6 (plasmashell 6.x, Wayland)"
echo "  - Fcitx 5 (fcitx5 + fcitx5-wayland-launcher) for the attached state"
echo "  - plasma-keyboard for the detached state"
echo "  - kwriteconfig6, busctl, kreadconfig6 (KDE / systemd packages)"