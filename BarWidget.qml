import QtQuick
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.advocu.grokipedia"

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function toggle() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: ""
        labelVisible: false
        hasVisualContent: true
        fixedWidth: Math.max(20, Math.round(button.barSize * 0.84))
        tooltipText: "Search Grokipedia"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
        }

        Canvas {
            id: iconCanvas
            anchors.centerIn: parent
            width: Math.max(15, Math.round(button.barSize * 0.58))
            height: Math.max(14, Math.round(button.barSize * 0.54))
            scale: button.pressScale
            antialiasing: true

            readonly property color strokeColor: button.active && button.useActiveColor
                ? button.activeColor : button.foreground

            onStrokeColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.scale(width / 24, height / 24)
                ctx.strokeStyle = strokeColor
                ctx.fillStyle = strokeColor
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                // Book border (hardcover silhouette + left spine)
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.moveTo(2.4, 2.0)
                ctx.lineTo(20.0, 2.0)
                ctx.quadraticCurveTo(22.2, 2.0, 22.2, 4.2)
                ctx.lineTo(22.2, 19.8)
                ctx.quadraticCurveTo(22.2, 22.0, 20.0, 22.0)
                ctx.lineTo(2.4, 22.0)
                ctx.quadraticCurveTo(1.6, 22.0, 1.6, 21.1)
                ctx.lineTo(1.6, 2.9)
                ctx.quadraticCurveTo(1.6, 2.0, 2.4, 2.0)
                ctx.closePath()
                ctx.stroke()

                // Book spine groove
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(5.2, 2.2)
                ctx.lineTo(5.2, 21.8)
                ctx.stroke()

                // Grok singularity emblem (two tapered crescent-slash shapes)
                // Fit inside cover area x:[6.6..20.8], y:[3.6..20.4]
                ctx.save()
                ctx.translate(6.8, 4.0)
                ctx.scale(0.57, 0.57)

                // Left-top crescent tapering down-left into sharp tail
                ctx.beginPath()
                ctx.moveTo(1.4, 23.0)
                ctx.quadraticCurveTo(5.8, 17.6, 5.2, 15.0)
                ctx.bezierCurveTo(3.6, 11.2, 5.2, 5.8, 9.6, 4.2)
                ctx.bezierCurveTo(12.8, 3.0, 15.8, 3.8, 17.6, 5.4)
                ctx.lineTo(15.2, 7.0)
                ctx.bezierCurveTo(13.6, 5.8, 11.4, 5.6, 9.6, 6.8)
                ctx.bezierCurveTo(6.8, 8.6, 6.4, 12.6, 8.6, 15.4)
                ctx.lineTo(1.4, 23.0)
                ctx.closePath()
                ctx.fill()

                // Right-bottom crescent with sharp upward-right spike + inner needle
                ctx.beginPath()
                ctx.moveTo(22.8, 1.4)
                ctx.lineTo(10.0, 14.4)
                ctx.lineTo(17.4, 8.8)
                ctx.bezierCurveTo(19.0, 11.6, 18.0, 16.0, 14.6, 17.6)
                ctx.bezierCurveTo(12.2, 18.8, 9.4, 18.4, 7.6, 17.0)
                ctx.lineTo(5.6, 19.0)
                ctx.bezierCurveTo(8.4, 21.4, 13.0, 22.0, 16.6, 19.8)
                ctx.bezierCurveTo(20.6, 17.4, 22.0, 12.2, 20.4, 7.8)
                ctx.quadraticCurveTo(20.0, 5.6, 22.8, 1.4)
                ctx.closePath()
                ctx.fill()

                ctx.restore()
            }
        }
    }
}
