import QtQuick

Item {
  id: root

  visible: false
  width: 0
  height: 0

  readonly property color voidColor: "#090a09"
  readonly property color ground: "#0e0f0d"
  readonly property color surface: "#141510"
  readonly property color raised: "#1b1c16"
  readonly property color field: "#10110e"

  readonly property color ink: "#e5dcc1"
  readonly property color inkStrong: "#f4ecd6"
  readonly property color inkMuted: "#beb59e"
  readonly property color inkFaint: "#918a78"
  readonly property color rule: "#48473e"
  readonly property color ruleStrong: "#6b6758"

  readonly property color authority: "#603536"
  readonly property color authorityBright: "#965354"
  readonly property color authorityText: "#ca7f81"
  readonly property color alive: "#b4c796"
  readonly property color warning: "#c19b58"
  readonly property color distance: "#958da6"
  readonly property color selectionMark: "#ada2c4"
  readonly property color selection: "#2b2833"
  readonly property color errorField: "#321714"

  readonly property string machineFont: machineRegular.status === FontLoader.Ready
    ? machineRegular.name : "monospace"
  readonly property string archiveFont: archiveRegular.status === FontLoader.Ready
    ? archiveRegular.name : "serif"
  readonly property string displayFont: machineFont

  readonly property int unit: 4
  readonly property int margin: 16
  readonly property int controlHeight: 34
  readonly property int sectionHeight: 30

  function serial(value, digits) {
    var result = String(Math.max(0, Number(value) || 0))
    while (result.length < digits) result = "0" + result
    return result
  }

  function playbackState(hasMedia, playing) {
    if (!hasMedia) return "STANDBY"
    return playing ? "TRANSMITTING" : "HELD"
  }

  function playbackColor(hasMedia, playing) {
    if (!hasMedia) return inkMuted
    return playing ? authorityText : warning
  }

  function integrationLabel(mode) {
    var value = String(mode || "auto").toUpperCase()
    return value === "OFF" ? "GENERIC" : "CODA " + value
  }

  FontLoader {
    id: machineRegular
    source: Qt.resolvedUrl("assets/fonts/DINish-Regular.ttf")
  }

  FontLoader {
    source: Qt.resolvedUrl("assets/fonts/DINish-Bold.ttf")
  }

  FontLoader {
    source: Qt.resolvedUrl("assets/fonts/DINish-Italic.ttf")
  }

  FontLoader {
    id: archiveRegular
    source: Qt.resolvedUrl("assets/fonts/HakkouMincho.ttf")
  }
}
