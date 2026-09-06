# Surface Auto-Rotate Lock — KDE Plasma 6 Widget

A Plasma 6 widget that locks and unlocks automatic screen rotation on
Microsoft Surface devices (and any Linux device with `iio-sensor-proxy`).

## How it works

When **unlocked** (auto-rotate ON):
- Polls the accelerometer orientation from `iio-sensor-proxy` via D-Bus every second
- Applies the corresponding screen rotation using `kscreen-doctor`

When **locked** (auto-rotate OFF):
- Stops polling and freezes the screen at its current rotation

Click the panel icon to toggle between locked and unlocked.

## Prerequisites

- KDE Plasma 6 (plasmashell 6.x)
- `iio-sensor-proxy` service running:
  ```
  systemctl status iio-sensor-proxy
  ```
  If not active:
  ```
  sudo systemctl enable --now iio-sensor-proxy
  ```
- `kscreen-doctor` (part of the `kscreen` package)
- `gdbus` (part of glib2)

## Installation

```bash
./install.sh
```

Or manually:
```bash
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r org.kde.plasma.surface-autorotate ~/.local/share/plasma/plasmoids/
```

Then restart plasmashell:
```bash
systemctl --user restart plasma-plasmashell.service
```

## Usage

1. Right-click your panel → **Add Widgets...**
2. Search for **"Surface Auto-Rotate"** or **"Auto-Rotate Lock"**
3. Drag it to your panel
4. Click the icon to toggle:
   - **Lock icon** = auto-rotate is OFF (rotation frozen)
   - **Rotate icon** = auto-rotate is ON (following accelerometer)

## Configuration

Right-click the widget → **Configure...**

- **Start locked**: whether auto-rotate starts disabled on login
- **Display output name**: the connector name (e.g. `eDP-1`). Leave empty
  for auto-detection via `kscreen-doctor -o`.

## Orientation mapping

The widget maps `iio-sensor-proxy` orientations to `kscreen-doctor` rotations:

| iio-sensor-proxy | kscreen-doctor | Effect |
|-----------------|----------------|--------|
| `normal`        | `none`         | Upright landscape |
| `left-up`       | `right`        | Portrait, rotated right |
| `right-up`      | `left`         | Portrait, rotated left |
| `bottom-up`     | `inverted`     | Upside down |

If the rotation direction seems wrong for your device, edit the
`orientationToRotation` map in `contents/ui/main.qml` and swap `left`/`right`.

## Files

```
org.kde.plasma.surface-autorotate/
├── metadata.json                          # Widget metadata (Plasma 6 format)
├── contents/
│   ├── config/
│   │   ├── main.xml                       # KConfig schema (locked, outputName)
│   │   └── config.qml                     # Config dialog entry point
│   └── ui/
│       ├── main.qml                        # Main widget logic
│       └── config/
│           └── ConfigGeneral.qml           # General settings page
└── install.sh
```

## Troubleshooting

**Widget doesn't appear**: restart plasmashell:
```bash
systemctl --user restart plasma-plasmashell.service
```

**No accelerometer detected**: verify iio-sensor-proxy:
```bash
monitor-sensor --accel
# should show orientation changes as you tilt the device
```

**Rotation not applied**: check kscreen-doctor manually:
```bash
kscreen-doctor -o                        # list outputs, find the name
kscreen-doctor output.eDP-1.rotation.left  # test rotation
```

**Wrong rotation direction**: edit the `orientationToRotation` map in
`contents/ui/main.qml` and swap the `left`/`right` values.

## License

GPL-3.0-or-later