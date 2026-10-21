import QtQuick

Item {
  id: root
  property alias text: label.text
  property alias color: label.color
  property alias font: label.font
  property alias horizontalAlignment: label.horizontalAlignment
  property bool hovered: false
  property bool motionEnabled: true
  property real pixelsPerSecond: 28
  property int hoverDelay: 450
  property real scrollOffset: 0
  property bool scrolling: false
  readonly property real overflow: Math.max(0, label.implicitWidth - width)
  readonly property bool canScroll: hovered && visible && motionEnabled && overflow > 1
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight
  clip: true

  function restart() {
    startDelay.stop()
    motion.stop()
    scrolling = false
    scrollOffset = 0
    if (canScroll) startDelay.start()
  }

  onCanScrollChanged: restart()
  onTextChanged: restart()
  onOverflowChanged: restart()

  Text {
    id: label
    x: -root.scrollOffset
    width: root.scrolling ? implicitWidth : root.width
    textFormat: Text.PlainText
    elide: root.scrolling ? Text.ElideNone : Text.ElideRight
  }

  Timer {
    id: startDelay
    interval: root.hoverDelay
    onTriggered: {
      root.scrolling = true
      motion.start()
    }
  }

  SequentialAnimation {
    id: motion
    loops: Animation.Infinite
    NumberAnimation {
      target: root
      property: "scrollOffset"
      from: 0
      to: root.overflow
      duration: Math.max(1, Math.round(root.overflow / root.pixelsPerSecond * 1000))
    }
    PauseAnimation { duration: 900 }
    NumberAnimation {
      target: root
      property: "scrollOffset"
      from: root.overflow
      to: 0
      duration: Math.max(1, Math.round(root.overflow / root.pixelsPerSecond * 1000))
    }
    PauseAnimation { duration: 900 }
  }
}
