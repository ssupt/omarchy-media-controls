import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "Model.js" as Model

KeyboardPanel {
  id: root

  required property var controller
  property var controlsService: null
  property string integrationMode: "auto"
  property bool showCodaDetails: true
  property bool requestedOpen: false
  property bool browserVisible: false
  readonly property bool codaDetailsEnabled: showCodaDetails
    && integrationMode !== "off" && !!controlsService && controlsService.codaInstalled

  signal closeRequested()
  signal browserRequested()
  signal nowPlayingRequested()

  owner: root
  open: requestedOpen
  padding: 0
  borderSpec: Border.none()
  focusTarget: browserVisible ? musicBrowser : keyScope
  contentWidth: root.fittedContentWidth(Style.space(480))
  contentHeight: browserVisible
    ? root.fittedContentHeight(musicBrowser.implicitHeight, Style.space(620))
    : root.fittedContentHeight(nowPlayingContent.implicitHeight + 26, Style.space(640))

  function close() {
    closeRequested()
  }

  function resetLyricsScroll() {
    var flick = lyricsScroll ? lyricsScroll.contentItem : null
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function codaQueueText() {
    if (controlsService && controlsService.codaStatusState === "loading")
      return "READING SESSION"
    if (controlsService && controlsService.codaStatusState === "error")
      return "STATUS UNAVAILABLE"
    var status = controlsService ? controlsService.codaStatus : null
    if (!status || !status.queueLength) return "SEQUENCE AVAILABLE"
    var index = Math.max(0, Number(status.currentIndex || 0)) + 1
    return "RECORD " + monument.serial(index, 2) + " / "
      + monument.serial(Number(status.queueLength), 2)
  }

  function codaSignalText() {
    if (controlsService && controlsService.codaStatusMessage !== "")
      return controlsService.codaStatusMessage.toUpperCase()
    var status = controlsService ? controlsService.codaStatus : null
    if (!status) return "SESSION BUS ONLINE"
    var signal = String(status.signal || status.format || "")
    return signal !== "" ? signal.toUpperCase() : "SESSION BUS ONLINE"
  }

  onOpenChanged: {
    if (!open) return
    if (browserVisible) musicBrowser.forceActiveFocus()
    else {
      resetLyricsScroll()
      controller.updatePosition()
      keyScope.forceActiveFocus()
      if (controlsService) {
        controlsService.requestLyrics(false)
        if (codaDetailsEnabled && controlsService.activeIsCoda)
          controlsService.requestCodaStatus()
      }
    }
  }

  onBrowserVisibleChanged: if (open) Qt.callLater(function() {
    if (root.browserVisible) musicBrowser.forceActiveFocus()
    else {
      transcriptTabs.currentIndex = 0
      keyScope.forceActiveFocus()
    }
  })

  Rectangle {
    id: terminal
    anchors.fill: parent
    color: monument.ground
    border.width: 1
    border.color: monument.ruleStrong
    clip: true

    Connections {
      target: root.controlsService

      function onHandoffSucceeded() {
        root.browserVisible = false
        root.nowPlayingRequested()
        Qt.callLater(function() {
          root.controller.updatePosition()
          root.resetLyricsScroll()
          keyScope.forceActiveFocus()
          if (root.controlsService) {
            root.controlsService.requestLyrics(false)
            if (root.codaDetailsEnabled) root.controlsService.requestCodaStatus()
          }
        })
      }
    }

    Timer {
      interval: 2000
      repeat: true
      triggeredOnStart: true
      running: root.open && !root.browserVisible && root.codaDetailsEnabled
        && root.controlsService && root.controlsService.activeIsCoda
      onTriggered: root.controlsService.requestCodaStatus()
    }

    MonumentStyle {
      id: monument
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      anchors.margins: 13
      focus: !root.browserVisible
      visible: !root.browserVisible

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.closeRequested()
          event.accepted = true
        } else if (event.key === Qt.Key_Space) {
          root.controller.runAction("playPause")
          event.accepted = true
        } else if (event.key === Qt.Key_N || event.key === Qt.Key_MediaNext) {
          root.controller.runAction("next")
          event.accepted = true
        } else if (event.key === Qt.Key_P || event.key === Qt.Key_MediaPrevious) {
          root.controller.runAction("previous")
          event.accepted = true
        } else if (event.key === Qt.Key_B) {
          root.browserRequested()
          event.accepted = true
        }
      }

      ColumnLayout {
        id: nowPlayingContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        MonumentSectionHeader {
          Layout.fillWidth: true
          monument: monument
          code: "T-01"
          title: "Transmission chamber"
          status: monument.playbackState(root.controller.hasMedia, root.controller.playing)
          statusColor: monument.playbackColor(root.controller.hasMedia, root.controller.playing)
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 116
          spacing: 12

          Rectangle {
            Layout.preferredWidth: 112
            Layout.preferredHeight: 112
            color: monument.field
            border.width: 1
            border.color: monument.ruleStrong
            clip: true

            Image {
              id: panelArtworkImage
              anchors.fill: parent
              anchors.margins: 1
              source: root.controller.artUrl
              asynchronous: true
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
              sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: panelArtworkImage.status !== Image.Ready
              text: "♪"
              color: monument.distance
              font.family: monument.machineFont
              font.pixelSize: 36
            }

            Text {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.margins: 7
              text: "IMG/01"
              color: monument.inkStrong
              font.family: monument.machineFont
              font.pixelSize: 10
              style: Text.Outline
              styleColor: monument.voidColor
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Text {
              Layout.fillWidth: true
              text: root.controller.hasMedia
                ? "CURRENT RECORD / AUTHORIZED FOR OUTPUT"
                : "CHAMBER AVAILABLE / AWAITING SELECTION"
              color: root.controller.hasMedia ? monument.authorityText : monument.inkFaint
              font.family: monument.machineFont
              font.pixelSize: 10
              font.letterSpacing: 0.75
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              text: root.controller.title || "No active transmission"
              color: monument.inkStrong
              font.family: monument.archiveFont
              font.pixelSize: 21
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }

            Text {
              text: "ATTRIBUTED TO"
              color: monument.inkMuted
              font.family: monument.machineFont
              font.pixelSize: 9
              font.letterSpacing: 0.75
            }

            Text {
              Layout.fillWidth: true
              text: root.controller.hasMedia
                ? (root.controller.artist || "Attribution not registered")
                : "Select a record from the archive"
              color: monument.ink
              font.family: monument.archiveFont
              font.pixelSize: 13
              elide: Text.ElideRight
            }

            Text {
              text: "CATALOGUE VOLUME"
              color: monument.inkMuted
              font.family: monument.machineFont
              font.pixelSize: 9
              font.letterSpacing: 0.75
            }

            Text {
              Layout.fillWidth: true
              text: root.controller.album || "Unregistered volume"
              color: monument.inkMuted
              font.family: monument.archiveFont
              font.pixelSize: 12
              font.italic: true
              elide: Text.ElideRight
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 42
          visible: root.codaDetailsEnabled && root.controlsService
            && root.controlsService.activeIsCoda
          color: monument.field
          border.width: 1
          border.color: monument.ruleStrong

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 5
            spacing: 8

            Rectangle {
              Layout.preferredWidth: 7
              Layout.preferredHeight: 7
              color: root.controlsService && root.controlsService.codaStatus.direct
                ? monument.alive : monument.warning
              border.width: 1
              border.color: monument.voidColor
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              Text {
                Layout.fillWidth: true
                text: "CODA LINK / " + (root.controlsService
                  && root.controlsService.codaStatus.direct ? "DIRECT" : "CONNECTED")
                color: root.controlsService && root.controlsService.codaStatus.direct
                  ? monument.alive : monument.warning
                font.family: monument.machineFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: root.codaQueueText() + " // " + root.codaSignalText()
                color: monument.inkMuted
                font.family: monument.machineFont
                font.pixelSize: 9
                font.letterSpacing: 0.35
                elide: Text.ElideRight
              }
            }

            MonumentButton {
              monument: monument
              compact: true
              code: "↗"
              text: "Coda"
              Accessible.name: "Open Coda"
              onClicked: if (root.controlsService) root.controlsService.showCoda()
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 5

          MonumentButton {
            Layout.fillWidth: true
            monument: monument
            text: "Prev"
            enabled: !!root.controller.activePlayer && root.controller.activePlayer.canGoPrevious
            Accessible.name: "Previous track"
            onClicked: root.controller.runAction("previous")
          }

          MonumentButton {
            Layout.fillWidth: true
            monument: monument
            text: root.controller.playing ? "Hold" : "Play"
            prominent: true
            enabled: !!root.controller.activePlayer && (root.controller.activePlayer.canTogglePlaying
              || root.controller.activePlayer.canPlay || root.controller.activePlayer.canPause)
            Accessible.name: root.controller.playing ? "Pause" : "Play"
            onClicked: root.controller.runAction("playPause")
          }

          MonumentButton {
            Layout.fillWidth: true
            monument: monument
            text: "Next"
            enabled: !!root.controller.activePlayer && root.controller.activePlayer.canGoNext
            Accessible.name: "Next track"
            onClicked: root.controller.runAction("next")
          }

          MonumentButton {
            Layout.fillWidth: true
            monument: monument
            code: "02"
            text: "Archive"
            Accessible.name: "Browse music archive"
            onClicked: root.browserRequested()
          }
        }

        MonumentSectionHeader {
          Layout.fillWidth: true
          monument: monument
          code: "T-02"
          title: "Transmission position"
          status: root.controller.duration > 0
            ? Model.formatDuration(root.controller.displayedPosition) + " / "
              + Model.formatDuration(root.controller.duration) : "UNMEASURED"
          statusColor: monument.inkMuted
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 18
          color: monument.field
          border.width: 1
          border.color: root.controller.duration > 0 ? monument.ruleStrong : monument.rule

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1,
              root.controller.duration > 0
                ? root.controller.displayedPosition / root.controller.duration : 0))
            height: parent.height
            color: monument.authority
            opacity: 0.88
          }

          Repeater {
            model: 5

            Rectangle {
              required property int index
              x: Math.round(index * (parent.width - 1) / 4)
              width: 1
              height: parent.height
              color: monument.ruleStrong
              opacity: 0.65
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: !!root.controller.activePlayer
              && root.controller.activePlayer.canSeek && root.controller.duration > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: function(mouse) { root.controller.seekRatio(mouse.x / width) }
          }
        }

        TabBar {
          id: transcriptTabs
          Layout.fillWidth: true
          implicitHeight: 42
          spacing: 2
          background: Rectangle { color: monument.ground }
          onCurrentIndexChanged: if (currentIndex === 1) root.browserRequested()

          MonumentTabButton {
            width: (transcriptTabs.width - transcriptTabs.spacing) / 2
            monument: monument
            code: "01"
            text: "Transcript"
          }

          MonumentTabButton {
            width: (transcriptTabs.width - transcriptTabs.spacing) / 2
            monument: monument
            code: "02"
            text: "Archive"
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            text: root.controller.lyricsSource !== ""
              ? root.controller.lyricsSource.toUpperCase() : "TRANSCRIPT REGISTER"
            color: monument.inkFaint
            font.family: monument.machineFont
            font.pixelSize: 9
            font.letterSpacing: 0.65
          }

          Item { Layout.fillWidth: true }

          MonumentButton {
            compact: true
            monument: monument
            visible: !root.controller.lyricsLoading && root.controller.hasMedia
              && root.controlsService && root.controlsService.lyricsState.status !== "ok"
            code: "↻"
            text: "Retry"
            Accessible.name: "Retry lyrics lookup"
            onClicked: if (root.controlsService) root.controlsService.requestLyrics(true)
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 210
          color: monument.field
          border.width: 1
          border.color: monument.rule

          ScrollView {
            id: lyricsScroll
            anchors.fill: parent
            anchors.margins: 9
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            TextEdit {
              width: lyricsScroll.availableWidth
              height: Math.max(lyricsScroll.height, contentHeight + 16)
              text: root.controller.lyricsDisplayText()
              color: root.controller.lyrics !== "" ? monument.ink : monument.inkMuted
              font.family: monument.archiveFont
              font.pixelSize: 13
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.PlainText
              readOnly: true
              selectByMouse: true
              selectionColor: monument.selectionMark
              selectedTextColor: monument.inkStrong
              rightPadding: 10
              bottomPadding: 10
            }
          }
        }
      }
    }

    MusicBrowser {
      id: musicBrowser
      anchors.fill: parent
      anchors.margins: 13
      visible: root.browserVisible
      focus: root.browserVisible
      service: root.controlsService
      bar: root.bar
      monument: monument
      integrationMode: root.integrationMode
      onTransmissionRequested: {
        root.browserVisible = false
        root.nowPlayingRequested()
      }
      onRootEscape: {
        if (root.controller.hasMedia) {
          root.browserVisible = false
          root.nowPlayingRequested()
        } else root.closeRequested()
      }
    }

    MonumentVeil {
      anchors.fill: parent
      z: 1000
    }
  }
}
