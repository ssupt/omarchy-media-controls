import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

FocusScope {
  id: root
  required property var controller
  required property var monument
  implicitHeight: content.implicitHeight
  signal closeRequested()
  Keys.onEscapePressed: closeRequested()

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 16

    MonumentSectionHeader {
      Layout.fillWidth: true
      monument: root.monument
      code: "S-01"
      title: "Bar appearance"
      status: "LIVE"
      statusColor: root.monument.alive
    }

    Text {
      Layout.fillWidth: true
      text: "Adjust the bar to fit your layout. Changes apply immediately and are saved automatically."
      color: root.monument.inkMuted
      font.family: root.monument.archiveFont
      font.pixelSize: 13
      wrapMode: Text.Wrap
    }

    SizeLabel {
      label: root.controller.vertical ? "SIDE-BAR TITLE LENGTH" : "BAR TITLE WIDTH"
      value: sizeSlider.value
    }
    SizeSlider {
      id: sizeSlider
      objectName: "barSizeSlider"
      Layout.fillWidth: true
      from: root.controller.vertical ? 72 : 80
      to: root.controller.vertical ? 240 : 320
      stepSize: root.controller.vertical ? 1 : 10
      snapMode: Slider.SnapAlways
      value: root.controller.vertical
        ? root.controller.labelExtent("verticalLabelLength", 125, 72, 240)
        : root.controller.labelExtent("labelWidth", 180, 80, 320)
      Accessible.name: root.controller.vertical ? "Side-bar title length" : "Bar title width"
      onMoved: root.controller.setAppearance(
        root.controller.vertical ? "verticalLabelLength" : "labelWidth", value)
    }

    SizeLabel { label: "BUTTON SPACING"; value: spacingSlider.value }
    SizeSlider {
      id: spacingSlider
      objectName: "barButtonSpacingSlider"
      Layout.fillWidth: true
      from: 0
      to: 8
      stepSize: 1
      snapMode: Slider.SnapAlways
      value: root.controller.labelExtent("buttonSpacing", 1, 0, 8)
      Accessible.name: "Playback button spacing"
      onMoved: root.controller.setAppearance("buttonSpacing", value)
    }

    Text {
      Layout.fillWidth: true
      text: "Artwork and buttons keep their size. Long titles scroll in place when you hover over the bar."
      color: root.monument.inkMuted
      font.family: root.monument.archiveFont
      font.pixelSize: 13
      wrapMode: Text.Wrap
    }

    CheckBox {
      id: idleToggle
      objectName: "showArchiveWhenIdle"
      Layout.fillWidth: true
      text: "Show Archive when idle"
      checked: root.controller.showWhenIdle
      spacing: 10
      indicator: Rectangle {
        x: idleToggle.leftPadding
        y: (idleToggle.height - height) / 2
        width: 20
        height: 20
        color: idleToggle.checked ? root.monument.selection : root.monument.field
        border.width: idleToggle.activeFocus ? 2 : 1
        border.color: idleToggle.activeFocus ? root.monument.warning : root.monument.ruleStrong
        Text {
          anchors.centerIn: parent
          text: idleToggle.checked ? "✓" : ""
          color: root.monument.selectionMark
          font.pixelSize: 13
        }
      }
      contentItem: Text {
        leftPadding: idleToggle.indicator.width + idleToggle.spacing
        text: idleToggle.text
        color: root.monument.ink
        font.family: root.monument.archiveFont
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
      }
      onToggled: root.controller.setAppearance("showWhenIdle", checked)
    }

    MonumentButton {
      monument: root.monument
      code: "↺"
      text: "Reset appearance"
      Accessible.name: "Reset bar appearance to defaults"
      onClicked: root.controller.resetAppearance()
    }
  }

  component SizeLabel: RowLayout {
    required property string label
    required property real value
    Layout.fillWidth: true
    Text {
      Layout.fillWidth: true
      text: parent.label
      color: root.monument.ink
      font.family: root.monument.machineFont
      font.pixelSize: 11
      font.letterSpacing: 0.6
    }
    Text {
      text: Math.round(parent.value) + " px"
      color: root.monument.selectionMark
      font.family: root.monument.machineFont
      font.pixelSize: 12
    }
  }

  component SizeSlider: Slider {
    id: control
    implicitHeight: 30
    background: Rectangle {
      x: control.leftPadding
      y: control.topPadding + control.availableHeight / 2 - height / 2
      width: control.availableWidth
      height: 4
      color: root.monument.rule
      Rectangle {
        width: control.visualPosition * parent.width
        height: parent.height
        color: root.monument.selectionMark
      }
    }
    handle: Rectangle {
      x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
      y: control.topPadding + (control.availableHeight - height) / 2
      width: 12
      height: 22
      color: control.pressed ? root.monument.inkStrong : root.monument.selectionMark
      border.width: control.activeFocus ? 2 : 1
      border.color: control.activeFocus ? root.monument.warning : root.monument.ruleStrong
    }
  }
}
