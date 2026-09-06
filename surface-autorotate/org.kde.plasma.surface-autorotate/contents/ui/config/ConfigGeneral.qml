/*
 *   Configuration dialog for Surface Auto-Rotate Lock
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

    property bool cfg_locked
    property string cfg_outputName

    Kirigami.FormLayout {
        Layout.fillWidth: true

        PlasmaComponents3.CheckBox {
            Kirigami.FormData.label: i18n("Start locked:")
            checked: cfg_locked
            onCheckedChanged: cfg_locked = checked
        }

        PlasmaComponents3.TextField {
            Kirigami.FormData.label: i18n("Display output name:")
            text: cfg_outputName
            placeholderText: i18n("e.g. eDP-1 (auto-detected if empty)")
            onTextChanged: cfg_outputName = text.trim()
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        text: i18n("If the display output name is left empty, it will be auto-detected using kscreen-doctor. The output name is the connector name shown by `kscreen-doctor -o` (e.g. eDP-1).")
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }

    PlasmaComponents3.Button {
        Layout.alignment: Qt.AlignHCenter
        text: i18n("Detect now")
        icon.name: "view-refresh"
        onClicked: {
            // This triggers detection by running kscreen-doctor
            // The main widget handles the actual detection
            cfg_outputName = ""
        }
    }

    Item {
        Layout.fillHeight: true
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        text: i18n("Orientation mapping (iio-sensor-proxy → kscreen-doctor):\n  normal → none, left-up → right, right-up → left, bottom-up → inverted\n\nIf rotation seems wrong, adjust the mapping in the QML source.")
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }
}