/*
 *   Surface Cover Virtual Keyboard - KDE Plasma 6 widget
 *   Auto-detect the Microsoft Surface Type Cover and switch Plasma's virtual
 *   keyboard / input method between Fcitx 5 (cover attached) and the Plasma
 *   touch keyboard (cover detached), keeping VirtualKeyboardMode in sync.
 *
 *   This widget replaces the standalone surface-cover-vk systemd daemon: the
 *   detection poll loop runs inside the widget. A bundled setup helper
 *   installs the cover-aware kwin-im-switcher and registers it in kwinrc.
 *
 *   SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // ---- configuration ----
    property bool autoDetect: Plasmoid.configuration.autoDetect
    property int pollInterval: Plasmoid.configuration.pollInterval
    property int attachedMode: Plasmoid.configuration.attachedMode
    property int detachedMode: Plasmoid.configuration.detachedMode
    property bool takeOverSystemd: Plasmoid.configuration.takeOverSystemd

    // ---- runtime state ----
    // coverState: "unknown" | "attached" | "detached"
    property string coverState: "unknown"
    property int currentMode: -1
    property bool helperInstalled: false
    property string lastMessage: ""
    property string lastSetupOutput: ""

    // ---- bundled helper paths (resolved relative to this main.qml) ----
    // Local filesystem paths for shell commands; Qt.resolvedUrl yields
    // "file://…" URLs which the shell cannot open directly.
    readonly property string detectScript: {
        var u = Qt.resolvedUrl("../code/detect-cover.sh").toString()
        return decodeURIComponent(u.replace(/^file:\/\//, ""))
    }
    readonly property string setupScript: {
        var u = Qt.resolvedUrl("../code/setup-helper.sh").toString()
        return decodeURIComponent(u.replace(/^file:\/\//, ""))
    }

    // derived
    readonly property string stateIcon: coverState === "attached" ? "input-keyboard"
                                      : coverState === "detached" ? "input-keyboard-virtual"
                                      : "input-keyboard-virtual"
    readonly property string activeIm: coverState === "attached" ? i18n("Fcitx 5 (physical keyboard)")
                                      : coverState === "detached" ? i18n("Plasma touch keyboard")
                                      : i18n("Unknown")
    readonly property string modeLabel: currentMode === 0 ? i18n("Never")
                                      : currentMode === 1 ? i18n("With Touch and Tablet")
                                      : currentMode === 2 ? i18n("With Touch, Tablet, and Mouse")
                                      : i18n("—")

    Plasmoid.icon: stateIcon
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("Surface Cover VK")
    toolTipMainText: coverState === "attached" ? i18n("Type Cover attached — Fcitx 5")
                   : coverState === "detached" ? i18n("Type Cover detached — Plasma keyboard")
                   : i18n("Surface Cover VK")
    toolTipSubText: {
        if (!helperInstalled) return i18n("Setup helper not run yet — right-click → Run setup helper")
        if (coverState === "unknown") return i18n("Detecting cover state…")
        return i18n("Input method: %1\nMode: %2", activeIm, modeLabel)
    }

    // ---- config change handling ----
    onAutoDetectChanged: {
        Plasmoid.configuration.autoDetect = autoDetect
        Plasmoid.configuration.writeConfig()
        if (autoDetect) startPolling(); else stopPolling()
    }
    onPollIntervalChanged: {
        Plasmoid.configuration.pollInterval = pollInterval
        Plasmoid.configuration.writeConfig()
        pollTimer.interval = Math.max(1, pollInterval) * 1000
    }
    onAttachedModeChanged: { Plasmoid.configuration.attachedMode = attachedMode; Plasmoid.configuration.writeConfig(); reapply() }
    onDetachedModeChanged: { Plasmoid.configuration.detachedMode = detachedMode; Plasmoid.configuration.writeConfig(); reapply() }
    onTakeOverSystemdChanged: { Plasmoid.configuration.takeOverSystemd = takeOverSystemd; Plasmoid.configuration.writeConfig() }

    Component.onCompleted: {
        pollTimer.interval = Math.max(1, pollInterval) * 1000
        checkHelper()
        detectNow()
        readMode()
        if (autoDetect) startPolling()
    }

    // ---- command executors (Plasma5Support executable engine) ----
    // The "executable" engine treats the ENTIRE source string as the shell
    // command (setShellCommand(objectName())). Commands therefore carry their
    // routing tag as a trailing comment marker, never as a prefix. Markers
    // also make every invocation a unique source — reconnecting a reused
    // source would replay the stale cached reply and lose the fresh one.
    // Each command family gets its own runner so concurrent commands never
    // clobber each other's connectedSources list.
    property int runSeq: 0

    Plasma5Support.DataSource {
        id: detectRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim()
            if (out === "attached" || out === "detached") {
                if (out !== root.coverState) {
                    root.coverState = out
                    root.lastMessage = i18n("Cover %1", out)
                    applyForState(out)
                }
            }
        }
    }

    Plasma5Support.DataSource {
        id: probeRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            probeRunner.connectedSources = []
            var out = (data["stdout"] || "").trim()
            root.helperInstalled = (out === "yes")
        }
    }

    Plasma5Support.DataSource {
        id: setupRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            setupRunner.connectedSources = []
            root.lastSetupOutput = (data["stdout"] || "").trim()
            root.lastMessage = i18n("Setup helper finished")
            checkHelper()
        }
    }

    Plasma5Support.DataSource {
        id: modeRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            modeRunner.connectedSources = []
            var n = parseInt((data["stdout"] || "").trim(), 10)
            if (!isNaN(n)) root.currentMode = n
        }
    }

    Plasma5Support.DataSource {
        id: applyRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            applyRunner.connectedSources = []
        }
    }

    Timer {
        id: pollTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: detectNow()
    }

    // ---- actions ----
    function startPolling() { pollTimer.running = true }
    function stopPolling()  { pollTimer.running = false }

    function detectNow() {
        root.runSeq += 1
        detectRunner.connectedSources = [ "bash " + detectScript + " ; #SVK-detect-" + root.runSeq ]
    }

    function reapply() {
        if (coverState === "attached" || coverState === "detached")
            applyForState(coverState)
    }

    // target mode for a given cover state
    function modeForState(state) {
        return state === "attached" ? root.attachedMode : root.detachedMode
    }

    function applyForState(state) {
        var mode = modeForState(state)
        root.currentMode = mode
        // 1. persist for next login / KWin restart
        var cmd = "kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardMode " + mode
                 + " && kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true"
        // 2. apply live value via DBus (tolerated when logged out)
        cmd += " && busctl --user call org.kde.KWin /VirtualKeyboard org.freedesktop.DBus.Properties"
             + " Set ssv org.kde.kwin.VirtualKeyboard mode i " + mode
        // 3. terminate KWin's current input method so it re-spawns the switcher
        cmd += " ; pkill -TERM -x plasma-keyboard 2>/dev/null"
        cmd += " ; pkill -TERM -f 'kwin-im-switcher' 2>/dev/null"
        cmd += " ; pkill -TERM -f 'fcitx5-wayland-launcher' 2>/dev/null"
        cmd += " ; true"
        runCmd(cmd, "apply")
    }

    property var runners: ({
        probe: probeRunner,
        setup: setupRunner,
        mode: modeRunner,
        apply: applyRunner
    })

    function runCmd(cmd, tag) {
        root.runSeq += 1
        runners[tag].connectedSources = [ cmd + " ; #SVK-" + tag + "-" + root.runSeq ]
    }

    function checkHelper() {
        runCmd("[ -x \"$HOME/.local/bin/kwin-im-switcher\" ] && [ -f \"$HOME/.local/share/applications/kwin-im-switcher.desktop\" ] && echo yes || echo no", "probe")
    }

    function runSetup() {
        var arg = root.takeOverSystemd ? "1" : "0"
        runCmd("bash " + setupScript + " " + arg, "setup")
    }

    function readMode() {
        runCmd("kreadconfig6 --file kwinrc --group Wayland --key VirtualKeyboardMode 2>/dev/null || echo -1", "mode")
    }

    function toggleAutoDetect() {
        root.autoDetect = !root.autoDetect
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            id: setupAction
            text: i18n("Run setup helper")
            icon.name: "system-run"
            onTriggered: root.runSetup()
        },
        PlasmaCore.Action {
            id: detectAction
            text: i18n("Re-detect now")
            icon.name: "view-refresh"
            onTriggered: root.detectNow()
        },
        PlasmaCore.Action {
            id: pauseAction
            text: root.autoDetect ? i18n("Pause auto-detect") : i18n("Resume auto-detect")
            icon.name: root.autoDetect ? "media-playback-pause" : "media-playback-start"
            onTriggered: root.toggleAutoDetect()
        }
    ]

    // ---- compact representation (panel icon) ----
    compactRepresentation: Item {
        id: compactItem

        Kirigami.Icon {
            id: panelIcon
            anchors.fill: parent
            source: Plasmoid.icon
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // ---- full representation (popup / desktop) ----
    fullRepresentation: Item {
        id: fullRep
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16

        ColumnLayout {
            anchors.centerIn: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                source: root.stateIcon
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
            }

            PlasmaExtras.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 2
                text: root.coverState === "attached" ? i18n("Type Cover attached")
                    : root.coverState === "detached" ? i18n("Type Cover detached")
                    : i18n("Detecting…")
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Input method: %1", root.activeIm)
                color: Kirigami.Theme.textColor
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("VirtualKeyboardMode: %1 (%2)", root.currentMode >= 0 ? root.currentMode : "—", root.modeLabel)
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.smallFont
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    source: root.helperInstalled ? "emblem-default" : "dialog-warning"
                }

                PlasmaComponents3.Label {
                    text: root.helperInstalled ? i18n("Helper installed")
                                              : i18n("Helper not installed — run setup")
                    color: root.helperInstalled ? Kirigami.Theme.positiveTextColor
                                                : Kirigami.Theme.neutralTextColor
                }
            }

            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
                text: i18n("Run setup helper")
                icon.name: "system-run"
                enabled: !root.helperInstalled
                onClicked: root.runSetup()
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: i18n("Re-detect now")
                    icon.name: "view-refresh"
                    onClicked: root.detectNow()
                }

                PlasmaComponents3.Button {
                    text: root.autoDetect ? i18n("Pause auto-detect") : i18n("Resume auto-detect")
                    icon.name: root.autoDetect ? "media-playback-pause" : "media-playback-start"
                    onClicked: root.toggleAutoDetect()
                }
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: root.lastMessage
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillHeight: true }  // spacer
        }
    }
}