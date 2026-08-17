import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omarchy.media"

  readonly property var controlsService: bar && bar.shell
    ? bar.shell.serviceFor("ssupt.media-controls") : null
  readonly property var mediaService: bar && bar.shell
    ? bar.shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var activePlayer: controlsService ? controlsService.activePlayer
    : (mediaService ? mediaService.activePlayer : null)
  readonly property bool hasMedia: controlsService ? controlsService.hasMedia
    : !!(activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist))
  readonly property string title: controlsService ? controlsService.title
    : (activePlayer ? String(activePlayer.trackTitle || "") : "")
  readonly property string artist: controlsService ? controlsService.artist
    : (activePlayer ? String(activePlayer.trackArtist || "") : "")
  readonly property string artUrl: controlsService ? controlsService.artUrl
    : (activePlayer ? String(activePlayer.trackArtUrl || "") : "")
  readonly property bool playing: !!(activePlayer && activePlayer.isPlaying)
  readonly property bool vertical: bar ? Model.isVerticalPosition(bar.position) : false
  readonly property string label: Model.nowPlayingLabel(title, artist)
  property real maxHorizontalLabelWidth: Style.space(180)
  property real maxVerticalLabelLength: Style.space(125)

  function runAction(action) {
    if (controlsService) return controlsService.runAction(action)
    if (!mediaService) return false
    return mediaService.runAction(action, false,
      activePlayer ? mediaService.playerKey(activePlayer) : "")
  }

  function openDetails() {
    if (!hasMedia || !bar || !bar.shell) return
    bar.shell.summon("ssupt.media-controls", "{}")
  }

  function showTrackTooltip() {
    if (bar) bar.showTooltip(root, label)
  }

  function hideTrackTooltip() {
    if (bar) bar.hideTooltip(root)
  }

  visible: hasMedia
  implicitWidth: hasMedia ? (vertical ? barSize : horizontalLayout.implicitWidth) : 0
  implicitHeight: hasMedia ? (vertical ? verticalLayout.implicitHeight : barSize) : 0

  Row {
    id: horizontalLayout
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.space(7)

    Item {
      id: horizontalIdentity
      implicitWidth: horizontalIdentityRow.implicitWidth
      implicitHeight: Math.max(root.barSize - Style.space(8), horizontalIdentityRow.implicitHeight)
      anchors.verticalCenter: parent.verticalCenter

      Row {
        id: horizontalIdentityRow
        anchors.centerIn: parent
        spacing: Style.space(7)

        Artwork {
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
        }

        Column {
          width: Math.min(root.maxHorizontalLabelWidth,
            Math.max(Style.space(72), Math.max(horizontalTitle.implicitWidth, horizontalArtist.implicitWidth)))
          spacing: Style.space(1)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: horizontalTitle
            width: parent.width
            text: root.title || "Unknown track"
            color: root.bar.barForeground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: horizontalArtist
            width: parent.width
            text: root.artist || "Unknown artist"
            color: Qt.darker(root.bar.barForeground, 1.35)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
        onWheel: function(wheel) {
          if (wheel.angleDelta.y > 0) root.runAction("previous")
          else if (wheel.angleDelta.y < 0) root.runAction("next")
        }
        onEntered: root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Row {
      spacing: Style.space(1)
      anchors.verticalCenter: parent.verticalCenter

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        tooltipText: "Previous"
        enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        tooltipText: root.playing ? "Pause" : "Play"
        enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
          || root.activePlayer.canPlay || root.activePlayer.canPause)
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
        tooltipText: "Next"
        enabled: !!root.activePlayer && root.activePlayer.canGoNext
      }
    }
  }

  Column {
    id: verticalLayout
    visible: root.vertical
    width: root.barSize
    spacing: Style.space(4)

    Item {
      width: parent.width
      height: Math.max(Style.space(24), root.barSize - Style.space(8))

      Artwork {
        extent: parent.height
        anchors.centerIn: parent
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
        onEntered: root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Item {
      width: parent.width
      height: Math.min(root.maxVerticalLabelLength, Math.max(Style.space(72), verticalLabel.implicitWidth))
      clip: true

      Text {
        id: verticalLabel
        width: parent.height - Style.space(8)
        text: root.label
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        rotation: root.bar && root.bar.position === "right" ? 90 : -90
        transformOrigin: Item.Center
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
        onWheel: function(wheel) {
          if (wheel.angleDelta.y > 0) root.runAction("previous")
          else if (wheel.angleDelta.y < 0) root.runAction("next")
        }
        onEntered: root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(1)

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        tooltipText: "Previous"
        enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        tooltipText: root.playing ? "Pause" : "Play"
        enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
          || root.activePlayer.canPlay || root.activePlayer.canPause)
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
        tooltipText: "Next"
        enabled: !!root.activePlayer && root.activePlayer.canGoNext
      }
    }
  }

  component Artwork: BorderSurface {
    required property real extent
    width: extent
    height: extent
    radius: Style.spacing.labelGap
    color: Style.normalFillFor(root.bar.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
    clip: true

    Image {
      anchors.fill: parent
      anchors.margins: Style.space(1)
      source: root.artUrl
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      visible: source !== ""
    }

    Text {
      anchors.centerIn: parent
      visible: root.artUrl === ""
      text: "󰝚"
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  component MediaButton: Button {
    required property string action
    foreground: root.bar.barForeground
    fontFamily: root.bar.fontFamily
    iconSize: Style.font.body
    horizontalPadding: Style.space(4)
    verticalPadding: Style.space(2)
    opacity: enabled ? 1 : 0.38
    onClicked: root.runAction(action)
  }
}
