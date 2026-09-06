#!/bin/bash
# Install the Surface Auto-Rotate Lock widget
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$SCRIPT_DIR/org.kde.plasma.surface-autorotate"

if [ ! -d "$WIDGET_DIR" ]; then
    echo "Error: widget directory not found at $WIDGET_DIR"
    exit 1
fi

echo "Installing Surface Auto-Rotate Lock widget..."

# Method 1: kpackagetool6 (preferred)
if command -v kpackagetool6 &>/dev/null; then
    kpackagetool6 --type=Plasma/Applet -i "$WIDGET_DIR" 2>/dev/null || \
    kpackagetool6 --type=Plasma/Applet -u "$WIDGET_DIR"
    echo "Installed via kpackagetool6"
elif command -v plasmapkg2 &>/dev/null; then
    plasmapkg2 --type=plasmoid -i "$WIDGET_DIR"
    echo "Installed via plasmapkg2"
else
    # Method 2: manual copy
    mkdir -p ~/.local/share/plasma/plasmoids/
    cp -r "$WIDGET_DIR" ~/.local/share/plasma/plasmoids/
    echo "Installed via manual copy to ~/.local/share/plasma/plasmoids/"
fi

echo ""
echo "Installation complete!"
echo ""
echo "To use the widget:"
echo "  1. Right-click on your panel or desktop"
echo "  2. Select 'Add Widgets...'"
echo "  3. Search for 'Surface Auto-Rotate' or 'Auto-Rotate Lock'"
echo "  4. Drag it to your panel"
echo ""
echo "Click the widget icon to toggle auto-rotate lock on/off."
echo ""
echo "Prerequisites:"
echo "  - iio-sensor-proxy service must be running (systemctl status iio-sensor-proxy)"
echo "  - kscreen-doctor must be installed (part of kscreen package)"
echo ""
echo "Note: You may need to restart plasmashell for the widget to appear:"
echo "  systemctl --user restart plasma-plasmashell.service"
echo "  or: kquitapp6 plasmashell && kstart plasmashell"