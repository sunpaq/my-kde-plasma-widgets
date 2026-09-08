import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    width: childrenRect.width
    height: childrenRect.height

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Controls.TextField {
            Kirigami.FormData.label: i18n("Interface:")
            text: Plasmoid.configuration.interface
            onTextChanged: Plasmoid.configuration.interface = text
        }

        Controls.SpinBox {
            Kirigami.FormData.label: i18n("Refresh (seconds):")
            from: 2
            to: 3600
            value: Plasmoid.configuration.refreshInterval
            onValueModified: Plasmoid.configuration.refreshInterval = value
        }
    }
}