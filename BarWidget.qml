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
        fixedWidth: Math.max(28, Math.round(button.barSize * 1.15))
        tooltipText: "Search Grokipedia"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
        }

        Canvas {
            id: iconCanvas
            anchors.centerIn: parent
            width: Math.max(22, Math.round(button.barSize * 0.90))
            height: Math.max(20, Math.round(button.barSize * 0.84))
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

                // Prominent book border (hardcover silhouette + left spine)
                ctx.lineWidth = 1.9
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
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(5.2, 2.2)
                ctx.lineTo(5.2, 21.8)
                ctx.stroke()

                // Large Grok singularity symbol inside the book cover
                var cx = 13.7
                var cy = 12.1
                var r = 5.4

                // Open singularity ring (broken at top-right for the slash)
                ctx.lineWidth = 2.0
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0.22 * Math.PI, 1.82 * Math.PI, false)
                ctx.stroke()

                // Bold diagonal singularity slash cutting through the ring
                ctx.lineWidth = 2.15
                ctx.beginPath()
                ctx.moveTo(cx - 5.9, cy + 5.4)
                ctx.lineTo(cx + 6.4, cy - 5.9)
                ctx.stroke()
            }
        }
    }
}
