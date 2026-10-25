/*
 *   Configuration dialog for Surface Cover Virtual Keyboard
 *   SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: configPage
    spacing: Kirigami.Units.largeSpacing

    property bool cfg_autoDetect
    property int cfg_pollInterval
    property int cfg_attachedMode
    property int cfg_detachedMode
    property bool cfg_takeOverSystemd
    property string cfg_fcitx5Launcher
    property string cfg_plasmaKeyboard

    Kirigami.FormLayout {
        Layout.fillWidth: true

        PlasmaComponents3.CheckBox {
            Kirigami.FormData.label: i18n("Auto-detect cover:")
            checked: cfg_autoDetect
            onCheckedChanged: cfg_autoDetect = checked
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Poll interval (s):")
            from: 1
            to: 60
            value: cfg_pollInterval
            onValueModified: cfg_pollInterval = value
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Mode when attached:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Never"), value: 0 },
                { text: i18n("With Touch and Tablet"), value: 1 },
                { text: i18n("With Touch, Tablet, and Mouse"), value: 2 }
            ]
            onActivated: cfg_attachedMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_attachedMode)
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Mode when detached:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Never"), value: 0 },
                { text: i18n("With Touch and Tablet"), value: 1 },
                { text: i18n("With Touch, Tablet, and Mouse"), value: 2 }
            ]
            onActivated: cfg_detachedMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_detachedMode)
        }

        PlasmaComponents3.CheckBox {
            Kirigami.FormData.label: i18n("Take over from systemd:")
            checked: cfg_takeOverSystemd
            onCheckedChanged: cfg_takeOverSystemd = checked
        }

        PlasmaComponents3.TextField {
            Kirigami.FormData.label: i18n("Fcitx 5 launcher:")
            text: cfg_fcitx5Launcher
            placeholderText: i18n("auto-detect (e.g. /usr/libexec/fcitx5-wayland-launcher)")
            onTextChanged: cfg_fcitx5Launcher = text.trim()
            Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        }

        PlasmaComponents3.TextField {
            Kirigami.FormData.label: i18n("Plasma keyboard:")
            text: cfg_plasmaKeyboard
            placeholderText: i18n("auto-detect (e.g. /usr/bin/plasma-keyboard)")
            onTextChanged: cfg_plasmaKeyboard = text.trim()
            Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        text: i18n("VirtualKeyboardMode values (System Settings → Keyboard → Virtual Keyboard): 0 = Never, 1 = With Touch and Tablet, 2 = With Touch, Tablet, and Mouse. The default setup uses Fcitx 5 when the cover is attached and the Plasma touch keyboard when detached. Click 'Run setup helper' in the widget's right-click menu after installing to register the cover-aware input-method switcher in kwinrc.")
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    Item { Layout.fillHeight: true }
}