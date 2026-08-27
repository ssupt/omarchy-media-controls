import QtQuick
import QtQuick.Controls

TabButton {
  id: control

  required property var monument
  property string code: "00"

  implicitHeight: 42
  padding: 4
  hoverEnabled: true

  contentItem: Column {
    spacing: 1

    Text {
      width: parent.width
      text: control.code
      color: control.checked ? control.monument.selectionMark : control.monument.inkFaint
      font.family: control.monument.machineFont
      font.pixelSize: 10
      font.letterSpacing: 1.1
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      width: parent.width
      text: control.text.toUpperCase()
      color: control.checked ? control.monument.inkStrong
        : control.enabled ? control.monument.inkMuted : control.monument.inkFaint
      font.family: control.monument.machineFont
      font.pixelSize: 11
      font.weight: control.checked ? Font.DemiBold : Font.Normal
      font.letterSpacing: 0.5
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  background: Rectangle {
    color: control.checked ? control.monument.selection
      : control.hovered ? control.monument.raised : control.monument.ground
    border.width: control.activeFocus ? 2 : 1
    border.color: control.activeFocus ? control.monument.warning : control.monument.rule

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: control.checked ? 3 : 1
      color: control.checked ? control.monument.selectionMark : control.monument.rule
    }
  }
}
