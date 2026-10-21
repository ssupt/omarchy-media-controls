import QtQuick
import qs.Ui
import qs.Commons

BorderSurface {
  id: root
  property url source: ""
  property real extent: 24
  property color foreground: Color.foreground
  property color backgroundColor: Style.normalFillFor(foreground, Color.accent)
  property color outlineColor: "transparent"
  property string fallbackFontFamily: Style.font.family
  property real fallbackFontSize: Style.font.title
  property int transitionDuration: Style.duration(140)
  property bool hasArtwork: false
  property url displayedSource: ""
  width: extent
  height: extent
  radius: 0
  color: backgroundColor
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)
  clip: true

  onSourceChanged: {
    clearDelay.stop()
    if (String(source) !== "") displayedSource = source
    else clearDelay.restart()
  }

  Timer {
    id: clearDelay
    interval: 250
    onTriggered: root.displayedSource = ""
  }

  onTransitionDurationChanged: if (transitionDuration === 0) {
    fade.stop()
    image.opacity = 1
  }

  Image {
    id: image
    anchors.fill: parent
    anchors.margins: Style.space(1)
    source: root.displayedSource
    asynchronous: true
    retainWhileLoading: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
    sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
    visible: root.hasArtwork
    onStatusChanged: {
      if (status === Image.Ready) {
        root.hasArtwork = true
        fade.restart()
      } else if (status === Image.Null || status === Image.Error) {
        root.hasArtwork = false
      }
    }
  }

  NumberAnimation {
    id: fade
    target: image
    property: "opacity"
    from: 0.45
    to: 1
    duration: root.transitionDuration
    easing.type: Easing.OutCubic
  }

  Text {
    anchors.centerIn: parent
    visible: !root.hasArtwork
    text: "♪"
    color: root.foreground
    font.family: root.fallbackFontFamily
    font.pixelSize: root.fallbackFontSize
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: root.outlineColor.a > 0 ? 1 : 0
    border.color: root.outlineColor
  }
}
