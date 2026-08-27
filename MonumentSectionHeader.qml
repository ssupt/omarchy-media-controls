import QtQuick
import QtQuick.Layouts

Item {
  id: root

  required property var monument
  property string code: "00"
  property string title: "UNTITLED SECTION"
  property string status: ""
  property color statusColor: monument.inkMuted

  implicitHeight: monument.sectionHeight

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: root.monument.ruleStrong
  }

  RowLayout {
    anchors.fill: parent
    spacing: 8

    Rectangle {
      Layout.preferredWidth: 4
      Layout.fillHeight: true
      color: root.monument.authority
    }

    Text {
      text: root.code
      color: root.monument.authorityText
      font.family: root.monument.machineFont
      font.pixelSize: 11
      font.letterSpacing: 1.1
    }

    Text {
      text: root.title.toUpperCase()
      color: root.monument.ink
      font.family: root.monument.machineFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.letterSpacing: 1.0
      elide: Text.ElideRight
    }

    Item { Layout.fillWidth: true }

    Rectangle {
      visible: root.status !== ""
      Layout.preferredWidth: 5
      Layout.preferredHeight: 5
      color: root.statusColor
    }

    Text {
      visible: root.status !== ""
      text: root.status.toUpperCase()
      color: root.statusColor
      font.family: root.monument.machineFont
      font.pixelSize: 11
      font.letterSpacing: 0.65
      elide: Text.ElideRight
    }
  }
}
