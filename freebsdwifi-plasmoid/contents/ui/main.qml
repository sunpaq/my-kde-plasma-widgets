import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    // ── config ────────────────────────────────────────────────────────
    property string iface: Plasmoid.configuration.interface || "wlan0"
    property int refreshSecs: Plasmoid.configuration.refreshInterval || 10

    // ── parsed state ─────────────────────────────────────────────────
    property string ssid: "—"
    property string ipAddr: "—"
    property string channel: "—"
    property bool associated: false
    property bool ifaceUp: false
    property string lastError: ""

    // ── commands (dynamically use configured interface) ─────────────
    readonly property string cmdStop:     "sudo service netif stop " + root.iface
    readonly property string cmdStart:    "sudo service netif start " + root.iface
    readonly property string cmdRestart:  "sudo service netif restart " + root.iface
    readonly property string cfgPath:     "/etc/wpa_supplicant.conf"
    readonly property string cmdChangeSsid: "sudo service netif restart " + root.iface

    // ── plasmoid metadata ────────────────────────────────────────────
    Plasmoid.icon: root.associated
        ? "network-wireless-connected-100"
        : "network-wireless-disconnected"
    Plasmoid.title: i18n("FreeBSD WiFi Status")
    toolTipMainText: root.associated ? root.ssid : i18n("Not connected")
    toolTipSubText: root.associated
        ? i18n("%1\nChannel %2\nStatus: associated", root.ipAddr, root.channel)
        : i18n("Interface %1", root.iface)

    compactRepresentation: compactRep
    fullRepresentation: fullRep

    // ── data engine: run ifconfig via plasma5support executable engine ─
    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: (sourceName, data) => {
            var raw = (data["stdout"] || "") + (data["stderr"] || "");
            root.parseIfconfig(raw);
            ds.disconnectSource(sourceName);
        }
    }

    Timer {
        id: refreshTimer
        interval: Math.max(2, root.refreshSecs) * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            var cmd = "ifconfig " + root.iface + " 2>&1";
            ds.connectSource(cmd);
        }
    }

    function refresh() {
        var cmd = "ifconfig " + root.iface + " 2>&1";
        ds.connectSource(cmd);
    }

    function parseIfconfig(text) {
        if (text.indexOf("does not exist") !== -1 || text.trim() === "") {
            root.ssid = "—";
            root.ipAddr = "—";
            root.channel = "—";
            root.associated = false;
            root.ifaceUp = false;
            root.lastError = "Interface " + root.iface + " not found";
            return;
        }
        root.lastError = "";

        // flags
        var flagsMatch = text.match(/flags=[0-9a-f]+<([^>]*)>/);
        var flags = flagsMatch ? flagsMatch[1].toLowerCase() : "";
        root.ifaceUp = flags.indexOf("up") !== -1;

        // status: associated
        var statusMatch = text.match(/status:\s*(.+)/);
        var statusStr = statusMatch ? statusMatch[1].trim() : "";
        root.associated = statusStr.indexOf("associated") !== -1;

        // ssid — word boundary so "bssid" doesn't match; handle quoted SSIDs with spaces
        var ssidMatch = text.match(/\bssid\s+"([^"]*)"/i) || text.match(/\bssid\s+(\S+)/i);
        root.ssid = ssidMatch && ssidMatch[1] !== undefined ? ssidMatch[1] : "—";

        // channel N (freq ...)
        var chanMatch = text.match(/channel\s+(\d+)\s+\(([^)]+)\)/i);
        root.channel = chanMatch ? chanMatch[1] + " (" + chanMatch[2] + ")" : "—";

        // inet IP
        var inetMatch = text.match(/inet\s+([0-9.]+)/);
        root.ipAddr = inetMatch ? inetMatch[1] : "—";
    }

    // ── helper: copy text to clipboard ───────────────────────────────
    function copyToClipboard(text) {
        clipHelper.text = text;
        clipHelper.selectAll();
        clipHelper.copy();
    }

    // hidden TextField for clipboard operations
    Controls.TextField {
        id: clipHelper
        visible: false
        width: 0
        height: 0
    }

    // ── compact representation ────────────────────────────────────────
    Component {
        id: compactRep
        MouseArea {
            id: compactMouse

            // canonical Plasma 6 sizing: square icon in horizontal/vertical panels
            Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                ? height : Kirigami.Units.iconSizes.small
            Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical
                ? width : Kirigami.Units.iconSizes.small

            hoverEnabled: true
            // NOTE: `expanded` lives on the PlasmoidItem itself in Plasma 6,
            // NOT on the Plasmoid attached object (Plasmoid.expanded is undefined)
            onClicked: root.expanded = !root.expanded

            Kirigami.Icon {
                anchors.fill: parent
                source: root.associated
                    ? "network-wireless-connected-100"
                    : "network-wireless-disconnected"
                active: compactMouse.containsMouse
            }
        }
    }

    // ── full representation ──────────────────────────────────────────
    Component {
        id: fullRep
        Item {
            implicitWidth: 380
            implicitHeight: 520

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: root.associated
                            ? "network-wireless-connected-100"
                            : "network-wireless-disconnected"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                    }
                    Kirigami.Heading {
                        text: root.associated ? root.ssid : i18n("Disconnected")
                        level: 3
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── Section: Status info ──
                Kirigami.Heading {
                    text: i18n("Status")
                    level: 5
                    opacity: 0.7
                    Layout.fillWidth: true
                }

                Repeater {
                    model: [
                        { label: i18n("Interface"), value: root.iface + (root.ifaceUp ? " (up)" : " (down)") },
                        { label: i18n("SSID"), value: root.ssid },
                        { label: i18n("IP Address"), value: root.ipAddr },
                        { label: i18n("Channel"), value: root.channel },
                        { label: i18n("Status"), value: root.associated ? "associated" : "no association" }
                    ]
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.Label {
                            text: modelData.label
                            opacity: 0.6
                            Layout.preferredWidth: 100
                        }
                        Controls.Label {
                            text: modelData.value
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── Section: Commands ──
                Kirigami.Heading {
                    text: i18n("Commands")
                    level: 5
                    opacity: 0.7
                    Layout.fillWidth: true
                }

                // Stop WiFi
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("Stop WiFi:")
                        opacity: 0.6
                        Layout.preferredWidth: 100
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        text: root.cmdStop
                        font.family: "monospace"
                    }
                    Controls.Button {
                        icon.name: "edit-copy"
                        implicitWidth: Kirigami.Units.iconSizes.small + 8
                        Controls.ToolTip.text: i18n("Copy")
                        Controls.ToolTip.visible: hovered
                        onClicked: root.copyToClipboard(root.cmdStop)
                    }
                }

                // Start WiFi
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("Start WiFi:")
                        opacity: 0.6
                        Layout.preferredWidth: 100
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        text: root.cmdStart
                        font.family: "monospace"
                    }
                    Controls.Button {
                        icon.name: "edit-copy"
                        implicitWidth: Kirigami.Units.iconSizes.small + 8
                        Controls.ToolTip.text: i18n("Copy")
                        Controls.ToolTip.visible: hovered
                        onClicked: root.copyToClipboard(root.cmdStart)
                    }
                }

                // Restart WiFi
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("Restart WiFi:")
                        opacity: 0.6
                        Layout.preferredWidth: 100
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        text: root.cmdRestart
                        font.family: "monospace"
                    }
                    Controls.Button {
                        icon.name: "edit-copy"
                        implicitWidth: Kirigami.Units.iconSizes.small + 8
                        Controls.ToolTip.text: i18n("Copy")
                        Controls.ToolTip.visible: hovered
                        onClicked: root.copyToClipboard(root.cmdRestart)
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ── Section: Configuration ──
                Kirigami.Heading {
                    text: i18n("Configuration")
                    level: 5
                    opacity: 0.7
                    Layout.fillWidth: true
                }

                // Config file path
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("Config file:")
                        opacity: 0.6
                        Layout.preferredWidth: 100
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        text: root.cfgPath
                        font.family: "monospace"
                    }
                    Controls.Button {
                        icon.name: "edit-copy"
                        implicitWidth: Kirigami.Units.iconSizes.small + 8
                        Controls.ToolTip.text: i18n("Copy")
                        Controls.ToolTip.visible: hovered
                        onClicked: root.copyToClipboard(root.cfgPath)
                    }
                }

                // Change SSID instruction
                Controls.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 100
                    text: i18n("Edit the config file to set a new SSID and PSK, then run:")
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("Apply:")
                        opacity: 0.6
                        Layout.preferredWidth: 100
                    }
                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        text: root.cmdChangeSsid
                        font.family: "monospace"
                    }
                    Controls.Button {
                        icon.name: "edit-copy"
                        implicitWidth: Kirigami.Units.iconSizes.small + 8
                        Controls.ToolTip.text: i18n("Copy")
                        Controls.ToolTip.visible: hovered
                        onClicked: root.copyToClipboard(root.cmdChangeSsid)
                    }
                }

                Item { Layout.fillHeight: true }

                // Error (if any)
                Controls.Label {
                    visible: root.lastError.length > 0
                    text: root.lastError
                    color: Kirigami.Theme.negativeTextColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Refresh button
                Controls.Button {
                    Layout.alignment: Qt.AlignHCenter
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    onClicked: root.refresh()
                }
            }
        }
    }
}