import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var service: null
  property bool closingFromHost: false
  readonly property bool opened: window.visible
  readonly property var controlsService: service || (shell ? shell.serviceFor("ssupt.media-controls") : null)
  readonly property var activePlayer: controlsService ? controlsService.activePlayer : null
  readonly property bool hasMedia: controlsService ? controlsService.hasMedia : false
  readonly property string title: controlsService ? controlsService.title : ""
  readonly property string artist: controlsService ? controlsService.artist : ""
  readonly property string album: controlsService ? controlsService.album : ""
  readonly property string artUrl: controlsService ? controlsService.artUrl : ""
  readonly property real duration: controlsService ? controlsService.duration : 0
  readonly property bool playing: !!(activePlayer && activePlayer.isPlaying)
  readonly property string lyrics: controlsService ? controlsService.lyrics : ""
  readonly property bool lyricsLoading: controlsService ? controlsService.lyricsLoading : false
  readonly property string lyricsSource: controlsService ? controlsService.lyricsSource : ""
  readonly property string lyricsMessage: controlsService ? controlsService.lyricsMessage : ""
  property real displayedPosition: 0

  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color mutedForeground: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: Style.font.family

  function open(_payloadJson) {
    closingFromHost = false
    window.visible = true
    Qt.callLater(function() {
      keyScope.forceActiveFocus()
      root.updatePosition()
      if (root.controlsService) root.controlsService.requestLyrics(false)
    })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("ssupt.media-controls")
    else window.visible = false
  }

  function runAction(action) {
    if (controlsService) controlsService.runAction(action)
  }

  function updatePosition() {
    displayedPosition = activePlayer && activePlayer.positionSupported
      ? Math.max(0, Number(activePlayer.position || 0)) : 0
  }

  function seekRatio(ratio) {
    if (!activePlayer || !activePlayer.canSeek || duration <= 0) return
    var next = Math.max(0, Math.min(1, ratio)) * duration
    activePlayer.position = next
    displayedPosition = next
  }

  function lyricsDisplayText() {
    if (lyrics !== "") return lyrics
    if (lyricsLoading) return "Finding the words…"
    if (lyricsMessage !== "") return lyricsMessage
    return hasMedia ? "No lyrics available for this track." : "Start a song to see its lyrics."
  }

  onActivePlayerChanged: updatePosition()

  Connections {
    target: root.controlsService
    function onTrackSignatureChanged() {
      root.updatePosition()
      if (window.visible) Qt.callLater(function() {
        if (root.controlsService) root.controlsService.requestLyrics(false)
      })
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: window.visible && root.playing
    triggeredOnStart: true
    onTriggered: root.updatePosition()
  }

  FloatingWindow {
    id: window
    title: root.hasMedia && root.title ? root.title + " — Media Controls" : "Media Controls"
    visible: false
    color: root.background
    implicitWidth: 760
    implicitHeight: 680
    minimumSize: Qt.size(560, 500)

    onVisibleChanged: {
      if (visible) {
        root.updatePosition()
        if (root.controlsService) root.controlsService.requestLyrics(false)
      } else if (!root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide("ssupt.media-controls")
      }
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Space) {
          root.runAction("playPause")
          event.accepted = true
        } else if (event.key === Qt.Key_N || event.key === Qt.Key_MediaNext) {
          root.runAction("next")
          event.accepted = true
        } else if (event.key === Qt.Key_P || event.key === Qt.Key_MediaPrevious) {
          root.runAction("previous")
          event.accepted = true
        }
      }

      Column {
        id: frame
        anchors.fill: parent
        anchors.margins: Style.space(24)
        spacing: Style.space(16)

        Item {
          id: nowPlaying
          width: parent.width
          height: Math.min(Style.space(220), Math.max(Style.space(170), frame.height * 0.34))

          Row {
            anchors.fill: parent
            spacing: Style.space(22)

            BorderSurface {
              id: artwork
              width: nowPlaying.height
              height: nowPlaying.height
              radius: Style.cornerRadius
              color: Style.normalFillFor(root.foreground, Color.accent)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              clip: true

              Image {
                anchors.fill: parent
                anchors.margins: Style.space(2)
                source: root.artUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: source !== ""
              }

              Text {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "󰝚"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.space(70)
              }
            }

            Column {
              width: parent.width - artwork.width - parent.spacing
              height: parent.height
              spacing: Style.space(8)

              Item { width: 1; height: Math.max(0, (parent.height - metadataColumn.implicitHeight
                - transportControls.implicitHeight - progressColumn.implicitHeight
                - parent.spacing * 2) / 2) }

              Column {
                id: metadataColumn
                width: parent.width
                spacing: Style.space(5)

                Text {
                  width: parent.width
                  text: root.title || "Nothing playing"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: root.artist || "Unknown artist"
                  color: root.mutedForeground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: root.album
                  visible: text !== ""
                  color: Qt.darker(root.foreground, 1.65)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              Row {
                id: transportControls
                spacing: Style.space(8)

                Button {
                  iconText: "󰒮"
                  tooltipText: "Previous"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
                  opacity: enabled ? 1 : 0.38
                  onClicked: root.runAction("previous")
                }

                Button {
                  iconText: root.playing ? "󰏤" : "󰐊"
                  tooltipText: root.playing ? "Pause" : "Play"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  iconSize: Style.font.iconLarge
                  horizontalPadding: Style.space(18)
                  enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
                    || root.activePlayer.canPlay || root.activePlayer.canPause)
                  opacity: enabled ? 1 : 0.38
                  onClicked: root.runAction("playPause")
                }

                Button {
                  iconText: "󰒭"
                  tooltipText: "Next"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !!root.activePlayer && root.activePlayer.canGoNext
                  opacity: enabled ? 1 : 0.38
                  onClicked: root.runAction("next")
                }
              }

              Column {
                id: progressColumn
                width: parent.width
                spacing: Style.space(5)
                visible: root.duration > 0

                Rectangle {
                  width: parent.width
                  height: Style.space(5)
                  radius: height / 2
                  color: Util.alpha(root.foreground, 0.18)

                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                      root.duration > 0 ? root.displayedPosition / root.duration : 0))
                    height: parent.height
                    radius: height / 2
                    color: Color.accent
                  }

                  MouseArea {
                    anchors.fill: parent
                    enabled: !!root.activePlayer && root.activePlayer.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function(mouse) { root.seekRatio(mouse.x / width) }
                  }
                }

                Row {
                  width: parent.width

                  Text {
                    id: elapsedLabel
                    text: Model.formatDuration(root.displayedPosition)
                    color: root.mutedForeground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item { width: parent.width - elapsedLabel.width - durationLabel.width; height: 1 }

                  Text {
                    id: durationLabel
                    text: Model.formatDuration(root.duration)
                    color: root.mutedForeground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }
        }

        PanelSeparator {
          id: sectionSeparator
          foreground: root.foreground
        }

        Row {
          id: lyricsHeader
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            id: lyricsTitle
            text: "LYRICS"
            foreground: root.foreground
            fontFamily: root.fontFamily
            anchors.verticalCenter: parent.verticalCenter
          }

          BorderSurface {
            id: sourceBadge
            visible: root.lyricsSource !== ""
            implicitWidth: sourceLabel.implicitWidth + Style.space(14)
            implicitHeight: sourceLabel.implicitHeight + Style.space(6)
            radius: height / 2
            color: Util.alpha(root.foreground, 0.08)
            borderSpec: Border.none()
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: sourceLabel
              anchors.centerIn: parent
              text: root.lyricsSource
              color: root.mutedForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Item {
            width: Math.max(0, parent.width - lyricsTitle.width - sourceBadge.width
              - retryButton.width - parent.spacing * 2)
            height: 1
          }

          Button {
            id: retryButton
            visible: !root.lyricsLoading && root.hasMedia
              && root.controlsService && root.controlsService.lyricsState.status !== "ok"
            iconText: "󰑓"
            text: "Retry"
            tooltipText: "Try the lyrics lookup again"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (root.controlsService) root.controlsService.requestLyrics(true)
          }
        }

        ScrollView {
          id: lyricsScroll
          width: parent.width
          height: Math.max(0, frame.height - nowPlaying.height - lyricsHeader.height
            - sectionSeparator.height - frame.spacing * 3)
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          TextEdit {
            width: lyricsScroll.availableWidth
            implicitHeight: Math.max(lyricsScroll.height, contentHeight + Style.space(20))
            text: root.lyricsDisplayText()
            color: root.lyrics !== "" ? root.foreground : root.mutedForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            readOnly: true
            selectByMouse: true
            selectionColor: Color.accent
            selectedTextColor: root.background
            leftPadding: Style.space(4)
            rightPadding: Style.space(12)
            topPadding: Style.space(4)
            bottomPadding: Style.space(12)
          }
        }
      }
    }
  }
}
