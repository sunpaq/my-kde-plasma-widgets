/*
 *   Surface Auto-Rotate Lock - KDE Plasma 6 widget
 *   Toggles automatic screen rotation via kscreen-doctor autoRotatePolicy.
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

    // ---- public state ----
    // locked === true  => auto-rotate is OFF (rotation frozen, policy = never)
    // locked === false => auto-rotate is ON  (policy = inTabletMode)
    property bool locked: Plasmoid.configuration.locked
    property string currentOrientation: "normal"
    property bool hasAccelerometer: true
    property string outputName: Plasmoid.configuration.outputName || "eDP-1"

    // Icon for the panel
    Plasmoid.icon: locked ? "object-locked" : "object-unlocked"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: locked ? i18n("Auto-Rotate: Locked") : i18n("Auto-Rotate: On")

    readonly property string toolTipSubText: {
        if (!hasAccelerometer) return i18n("No accelerometer detected")
        if (locked) return i18n("Rotation locked — screen will not rotate")
        return i18n("Rotation unlocked — current orientation: %1", currentOrientation)
    }

    // ---- configuration change handling ----
    onLockedChanged: {
        Plasmoid.configuration.locked = locked
        Plasmoid.configuration.writeConfig()
        applyPolicy()
    }

    Component.onCompleted: {
        // Check accelerometer presence
        hasAccelCheck.connectedSources = [
            "gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy --method org.freedesktop.DBus.Properties.Get net.hadess.SensorProxy HasAccelerometer"
        ]
        // Start orientation polling for display purposes
        if (!locked) {
            pollTimer.running = true
            pollTimer.start()
        }
        // Apply policy on startup
        applyPolicy()
    }

    // ---- orientation polling (for display only) ----
    Plasma5Support.DataSource {
        id: orientationDbus
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"] || ""
            var m = stdout.match(/<'\s*([^']*)\s*'>/)
            if (m) {
                root.currentOrientation = m[1]
            }
        }
    }

    // has-accelerometer check
    Plasma5Support.DataSource {
        id: hasAccelCheck
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            root.hasAccelerometer = (stdout.indexOf("true") >= 0)
        }
    }

    // command executor — disconnect first to allow re-running same command
    Plasma5Support.DataSource {
        id: cmdRunner
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function(sourceName, data) {
            // command completed
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            if (!root.locked) {
                orientationDbus.connectedSources = []
                orientationDbus.connectedSources = [
                    "gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy --method org.freedesktop.DBus.Properties.Get net.hadess.SensorProxy AccelerometerOrientation"
                ]
            }
        }
    }

    // ---- core: set the KDE auto-rotate policy ----
    // locked   => autoRotatePolicy.never        (KDE won't auto-rotate)
    // unlocked => autoRotatePolicy.inTabletMode (KDE auto-rotates in tablet mode)
    function applyPolicy() {
        var policy = root.locked ? "never" : "inTabletMode"
        var cmd = "kscreen-doctor output." + root.outputName + ".autoRotatePolicy." + policy
        // Disconnect first so the same source can be re-triggered
        cmdRunner.connectedSources = []
        cmdRunner.connectedSources = [cmd]
    }

    // ---- toggle action ----
    function toggleLock() {
        root.locked = !root.locked
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            id: toggleAction
            text: root.locked ? i18n("Unlock Auto-Rotate") : i18n("Lock Auto-Rotate")
            icon.name: root.locked ? "object-unlocked" : "object-locked"
            onTriggered: root.toggleLock()
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
            onClicked: root.toggleLock()
        }
    }

    // ---- full representation (when opened in a panel popup or on desktop) ----
    fullRepresentation: Item {
        id: fullRep
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 12

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                source: root.locked ? "object-locked" : "object-unlocked"
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
            }

            PlasmaExtras.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 2
                text: root.locked ? i18n("Auto-Rotate Locked") : i18n("Auto-Rotate Active")
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.hasAccelerometer
                      ? i18n("Current orientation: %1", root.currentOrientation)
                      : i18n("No accelerometer detected")
                color: Kirigami.Theme.textColor
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Display: %1", root.outputName)
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.smallFont
            }

            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.largeSpacing
                text: root.locked ? i18n("Unlock Auto-Rotate") : i18n("Lock Auto-Rotate")
                icon.name: root.locked ? "object-unlocked" : "object-locked"
                onClicked: root.toggleLock()
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    source: root.locked ? "object-locked" : "object-unlocked"
                }

                PlasmaComponents3.Label {
                    text: root.locked ? i18n("Rotation is frozen") : i18n("Following accelerometer")
                    color: root.locked ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
                }
            }
        }
    }
}