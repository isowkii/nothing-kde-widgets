import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import Qt.labs.folderlistmodel // Tambahan untuk slideshow
import "components"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    NothingColors {
        id: nColors
        themeMode: plasmoid.configuration.themeMode
        useSystemAccent: plasmoid.configuration.useSystemAccent
    }

    // Configuration properties
    property string imagePath: plasmoid.configuration.imagePath
    property bool borderEnabled: plasmoid.configuration.borderEnabled
    property int borderSize: plasmoid.configuration.borderSize
    property bool pillShapeEnabled: plasmoid.configuration.pillShapeEnabled
    property int imageFillMode: plasmoid.configuration.imageFillMode
    property bool grayscaleEnabled: plasmoid.configuration.grayscaleEnabled

    // Konfigurasi Slideshow
    property bool isSlideshow: plasmoid.configuration.isSlideshow || false
    property string folderPath: plasmoid.configuration.folderPath || ""
    property int slideshowInterval: plasmoid.configuration.slideshowInterval || 5 // dalam detik

    // Properti Internal Slideshow
    property int _currentIndex: 0
    property string _currentSlideshowImage: ""
    property string activeImagePath: isSlideshow ? _currentSlideshowImage : imagePath

    FolderListModel {
        id: folderModel
        folder: root.folderPath ? (root.folderPath.startsWith("file://") ? root.folderPath : "file://" + root.folderPath) : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif"]
        showDirs: false
        onCountChanged: {
            if (count > 0 && root.isSlideshow) {
                root._currentIndex = 0;
                root._currentSlideshowImage = String(folderModel.get(root._currentIndex, "fileUrl"));
            }
        }
    }

    Timer {
        id: slideshowTimer
        interval: root.slideshowInterval * 1000
        running: root.isSlideshow && folderModel.count > 1
        repeat: true
        onTriggered: {
            root._currentIndex = (root._currentIndex + 1) % folderModel.count;
            root._currentSlideshowImage = String(folderModel.get(root._currentIndex, "fileUrl"));
        }
    }

    readonly property real outerRadius: {
        if (!pillShapeEnabled) return 20

            var w = root.width
            var h = root.height
            var aspectRatio = w / h

            if (aspectRatio >= 0.9 && aspectRatio <= 1.1) return Math.min(w, h) / 2
                if (w > h) return h / 2
                    return w / 2
    }

    readonly property real calculatedRadius: {
        var margin = borderEnabled ? borderSize : 0
        return Math.max(0, outerRadius - margin)
    }

    readonly property int qmlFillMode: {
        switch(imageFillMode) {
            case 0: return Image.PreserveAspectCrop
            case 1: return Image.PreserveAspectFit
            case 2: return Image.Stretch
            default: return Image.PreserveAspectCrop
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 200
        Layout.preferredHeight: 200
        Layout.minimumWidth: 200
        Layout.minimumHeight: 200
        anchors.margins: 10

        Rectangle {
            id: outerBackground
            anchors.fill: parent
            color: nColors.background
            opacity: 0.95
            radius: root.outerRadius
        }

        Rectangle {
            id: mainRect
            anchors.fill: parent
            anchors.margins: borderEnabled ? borderSize : 0
            color: nColors.background
            radius: root.calculatedRadius
            clip: true

            Image {
                id: photoImage
                anchors.fill: parent
                source: {
                    if (!root.activeImagePath) return ""
                        if (root.activeImagePath.startsWith("/") || root.activeImagePath.startsWith("file://")) {
                            return root.activeImagePath
                        }
                        return Qt.resolvedUrl("../" + root.activeImagePath)
                }
                fillMode: root.qmlFillMode
                smooth: true
                visible: false
                layer.enabled: true
                cache: true
            }

            Item {
                id: roundedMask
                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: root.calculatedRadius
                    color: "white"
                }
            }

            Rectangle {
                anchors.fill: parent
                color: nColors.background
                radius: root.calculatedRadius
                z: 1
            }

            Item {
                anchors.fill: parent
                z: 2

                MultiEffect {
                    id: photoEffect
                    anchors.fill: parent
                    source: photoImage
                    maskEnabled: true
                    maskSource: roundedMask
                    visible: root.activeImagePath !== ""
                }

                MultiEffect {
                    anchors.fill: parent
                    source: photoEffect
                    visible: root.grayscaleEnabled && root.activeImagePath !== ""
                    colorization: 1.0
                    colorizationColor: "#808080"
                    brightness: 0.5
                    contrast: 1
                }
            }

            Rectangle {
                anchors.fill: parent
                color: nColors.surface
                radius: root.calculatedRadius
                visible: root.activeImagePath === ""
                z: 2

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(parent.parent.width * 0.3, 64)
                        Layout.preferredHeight: Math.min(parent.parent.height * 0.3, 64)
                        source: "image-x-generic"
                        color: nColors.textDisabled
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n("No Image")
                        font.pixelSize: 14
                        color: nColors.textDisabled
                        visible: mainRect.width > 120 && mainRect.height > 120
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: nColors.surface
                radius: root.calculatedRadius
                visible: root.activeImagePath !== "" && photoImage.status === Image.Error
                z: 3

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(parent.parent.width * 0.3, 64)
                        Layout.preferredHeight: Math.min(parent.parent.height * 0.3, 64)
                        source: "dialog-error"
                        color: nColors.error
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: i18n("Image Error")
                        font.pixelSize: 14
                        color: nColors.error
                        visible: mainRect.width > 120 && mainRect.height > 120
                    }
                }
            }
        }
    }
}
