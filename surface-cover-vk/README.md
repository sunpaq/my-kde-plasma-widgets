# Surface Cover Virtual Keyboard — KDE Plasma 6 Widget

A Plasma 6 widget that auto-detects the Microsoft Surface Type Cover and
switches KDE Plasma's virtual keyboard / input method accordingly, so you get
a physical-keyboard input method (Fcitx 5 → mozc/rime) when the cover is
attached and the Plasma touch keyboard when it is detached.

It packages the whole feature into one installable widget: the detection loop
runs inside the widget (no separate daemon), and a bundled setup helper
installs the cover-aware `kwin-im-switcher` and registers it in `kwinrc`.

## How it works

| Cover state | Input method | VirtualKeyboardMode |
|------------|--------------|---------------------|
| attached   | Fcitx 5 (via `fcitx5-wayland-launcher`) | 2 — With Touch, Tablet, and Mouse |
| detached   | Plasma touch keyboard (`plasma-keyboard`) | 1 — With Touch and Tablet |

Every `pollInterval` seconds the widget probes sysfs for the Type Cover:

- HID input devices whose name contains "Surface Type Cover", or
- the USB device `045e:07e8` (Microsoft Type Cover)

On a state change it:

1. Persists `VirtualKeyboardMode` + `VirtualKeyboardEnabled` to `kwinrc`
   (so the right mode survives relogin / KWin restart).
2. Sets the live value via the `org.kde.kwin.VirtualKeyboard` D-Bus property.
3. Terminates KWin's current input-method process, which makes KWin re-spawn
   `kwin-im-switcher` — and that wrapper re-decides between Fcitx 5 and the
   Plasma keyboard from the live cover state.

The `kwin-im-switcher` wrapper is what KWin launches as its Wayland input
method (registered through a `.desktop` entry). It auto-detects the
`fcitx5-wayland-launcher` and `plasma-keyboard` binaries; override with the
`FCITX5_WAYLAND_LAUNCHER` / `PLASMA_KEYBOARD` env vars if your distro places
them elsewhere.

## Prerequisites

- KDE Plasma 6 (plasmashell 6.x, Wayland session)
- `fcitx5` + `fcitx5-wayland-launcher` (for the attached/physical state)
- `plasma-keyboard` (Plasma touch keyboard, for the detached state)
- `kwriteconfig6`, `kreadconfig6` (KDE), `busctl` (systemd)

## Installation

```bash
./install.sh
```

`install.sh` does three things:

1. Installs the plasmoid to `~/.local/share/plasma/plasmoids/` (via
   `kpackagetool6` if available, else a manual copy).
2. Runs the bundled setup helper, which copies `kwin-im-switcher` to
   `~/.local/bin/`, writes `~/.local/share/applications/kwin-im-switcher.desktop`,
   and registers it in `kwinrc [Wayland] InputMethod`.
3. By default disables the standalone `surface-cover-vk.service` user unit
   (if present) so the widget manages detection. Pass `0` to keep it:
   `./install.sh 0`.

Then restart plasmashell if the widget doesn't appear:

```bash
systemctl --user restart plasma-plasmashell.service
```

### Manual install (without install.sh)

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r org.kde.plasma.surface-cover-vk ~/.local/share/plasma/plasmoids/
chmod +x ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk/contents/code/*.sh \
         ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk/contents/code/kwin-im-switcher
bash ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk/contents/code/setup-helper.sh 1
systemctl --user restart plasma-plasmashell.service
```

## Usage

1. Right-click your panel → **Add Widgets...**
2. Search for **"Surface Cover Virtual Keyboard"**
3. Drag it to your panel
4. Right-click the widget → **Run setup helper** (the first time, to register
   the IM switcher in `kwinrc`). The widget shows a warning badge until this
   is done.

The panel icon reflects the state:

- **`input-keyboard`** = Type Cover attached (Fcitx 5 active)
- **`input-keyboard-virtual`** = Type Cover detached (Plasma touch keyboard)

The popup shows the current cover state, active input method, and
`VirtualKeyboardMode` value. Right-click for quick actions:

- **Run setup helper** — register the IM switcher in `kwinrc`
- **Re-detect now** — probe the cover state immediately
- **Pause / Resume auto-detect** — stop or start the polling loop

## Configuration

Right-click the widget → **Configure...**

- **Auto-detect cover** — run the polling loop while the widget is loaded
- **Poll interval (s)** — seconds between probes (default 1)
- **Mode when attached / detached** — the `VirtualKeyboardMode` to apply
  (0 = Never, 1 = With Touch and Tablet, 2 = With Touch, Tablet, and Mouse)
- **Take over from systemd** — when running Setup, disable the standalone
  `surface-cover-vk.service` so the widget manages detection
- **Fcitx 5 launcher / Plasma keyboard** — override binary paths (empty =
  auto-detect)

## Migrating from the standalone daemon

If you previously used the `surface-cover-vk` systemd user service
(`~/.local/bin/surface-cover-vk` + `surface-cover-vk.service`), the widget
replaces the daemon — the poll loop now lives in the widget. Run
`./install.sh` (default) or the widget's **Run setup helper** action; it will
`systemctl --user disable --now surface-cover-vk.service` for you. The
`kwin-im-switcher` launcher is reinstalled by the helper. You can remove
`~/.local/bin/surface-cover-vk` and `~/.config/systemd/user/surface-cover-vk.service`
afterwards if you no longer want them.

## Files

```
org.kde.plasma.surface-cover-vk/
├── metadata.json                          # Widget metadata (Plasma 6)
├── contents/
│   ├── code/
│   │   ├── detect-cover.sh                # One-shot cover probe (attached/detached)
│   │   ├── kwin-im-switcher               # Cover-aware KWin IM launcher (installed to ~/.local/bin)
│   │   ├── kwin-im-switcher.desktop       # .desktop template (installed to ~/.local/share/applications)
│   │   └── setup-helper.sh                # One-time setup (install launcher + register in kwinrc)
│   ├── config/
│   │   ├── main.xml                       # KConfig schema
│   │   └── config.qml                     # Config dialog entry point
│   └── ui/
│       ├── main.qml                        # Widget logic + UI
│       └── config/
│           └── ConfigGeneral.qml           # Settings page
└── ../install.sh
```

## Troubleshooting

**Widget doesn't appear**: restart plasmashell:
```bash
systemctl --user restart plasma-plasmashell.service
```

**Helper not installed badge**: right-click → **Run setup helper**, or run
`bash ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk/contents/code/setup-helper.sh 1`.

**Wrong input method after switching**: verify the IM switcher is registered:
```bash
kreadconfig6 --file kwinrc --group Wayland --key InputMethod
# should be ~/.local/share/applications/kwin-im-switcher.desktop
ls -l ~/.local/bin/kwin-im-switcher
```
A Wayland session restart (logout/login) may be needed for KWin to pick up the
new `InputMethod` the first time.

**fcitx5-wayland-launcher / plasma-keyboard not found**: set the paths in the
widget config, or export `FCITX5_WAYLAND_LAUNCHER` / `PLASMA_KEYBOARD` in the
environment KWin inherits.

**Cover state stuck**: run `bash ~/.local/share/plasma/plasmoids/org.kde.plasma.surface-cover-vk/contents/code/detect-cover.sh`
to confirm detection, and check `grep -is 'type cover' /sys/class/input/input*/name`
plus `lsusb -d 045e:07e8`.

## License

GPL-3.0-or-later