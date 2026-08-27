import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
  id: control

  required property var monument
  property string code: ""
  property bool prominent: false
  property bool danger: false
  property bool compact: false

  implicitWidth: Math.max(compact ? 46 : 58,
    contentItem.implicitWidth + leftPadding + rightPadding)
  implicitHeight: compact ? 28 : monument.controlHeight
  leftPadding: compact ? 6 : 8
  rightPadding: compact ? 6 : 8
  topPadding: 4
  bottomPadding: 4
  hoverEnabled: true

  contentItem: RowLayout {
    spacing: 5

    Text {
      visible: control.code !== ""
      text: control.code.toUpperCase()
      color: !control.enabled ? control.monument.inkFaint
        : control.prominent ? control.monument.inkStrong : control.monument.authorityText
      font.family: control.monument.machineFont
      font.pixelSize: control.compact ? 10 : 11
      font.weight: Font.DemiBold
      font.letterSpacing: 0.5
      verticalAlignment: Text.AlignVCenter
    }

    Rectangle {
      visible: control.code !== ""
      Layout.preferredWidth: 1
      Layout.preferredHeight: control.compact ? 11 : 13
      color: control.enabled ? control.monument.ruleStrong : control.monument.inkFaint
    }

    Text {
      Layout.fillWidth: true
      text: control.text.toUpperCase()
      color: !control.enabled ? control.monument.inkFaint
        : control.prominent ? control.monument.inkStrong : control.monument.ink
      font.family: control.monument.machineFont
      font.pixelSize: control.compact ? 10 : 11
      font.weight: control.prominent ? Font.DemiBold : Font.Medium
      font.letterSpacing: 0.45
      horizontalAlignment: control.code !== "" ? Text.AlignLeft : Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }

  background: Rectangle {
    color: !control.enabled ? control.monument.ground
      : control.down ? control.monument.rule
      : control.checked ? control.monument.selection
      : control.prominent ? control.monument.authority
      : control.hovered ? control.monument.raised : control.monument.surface
    border.width: control.activeFocus ? 2 : 1
    border.color: !control.enabled ? control.monument.inkFaint
      : control.danger ? control.monument.authorityBright
      : control.activeFocus ? control.monument.warning
      : control.checked ? control.monument.selectionMark : control.monument.ruleStrong

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: control.down ? 1 : (control.checked || control.prominent ? 3 : 2)
      color: !control.enabled ? control.monument.inkFaint
        : control.danger ? control.monument.authorityBright
        : control.checked ? control.monument.selectionMark
        : control.prominent ? control.monument.ink : control.monument.rule
    }
  }
}
