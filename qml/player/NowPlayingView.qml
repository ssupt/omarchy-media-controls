import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Model.js" as Model
import "../components"
import "../style"

FocusScope {
  id: root
  required property var controller
  required property var monument
  property var controlsService: null
  implicitHeight: content.implicitHeight
  signal browserRequested()
  signal closeRequested()

  function resetLyricsScroll() {
    var flick = lyricsScroll.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) closeRequested()
    else if (event.key === Qt.Key_Space) controller.runAction("playPause")
    else if (event.key === Qt.Key_N || event.key === Qt.Key_MediaNext) controller.runAction("next")
    else if (event.key === Qt.Key_P || event.key === Qt.Key_MediaPrevious) controller.runAction("previous")
    else if (event.key === Qt.Key_B) browserRequested()
    else return
    event.accepted = true
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: 8

    MonumentSectionHeader {
      Layout.fillWidth: true
      monument: root.monument
      code: "T-01"
      title: "Transmission chamber"
      status: root.monument.playbackState(root.controller.showingMedia, root.controller.playing)
      statusColor: root.monument.playbackColor(root.controller.showingMedia, root.controller.playing)
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 116
      spacing: 12

      TrackArtwork {
        Layout.preferredWidth: 112
        Layout.preferredHeight: 112
        source: root.controller.presentation.displayedArtUrl
        foreground: root.monument.distance
        fallbackFontFamily: root.monument.machineFont
        fallbackFontSize: 36
        backgroundColor: root.monument.field
        outlineColor: root.monument.ruleStrong
      }

      ColumnLayout {
        objectName: "playerTrackDetails"
        opacity: root.controller.presentation.contentOpacity
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 2

        Text {
          Layout.fillWidth: true
          text: root.controller.showingMedia
            ? "CURRENT RECORD / AUTHORIZED FOR OUTPUT"
            : "CHAMBER AVAILABLE / AWAITING SELECTION"
          color: root.controller.showingMedia ? root.monument.authorityText : root.monument.inkFaint
          font.family: root.monument.machineFont
          font.pixelSize: 10
          font.letterSpacing: 0.75
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: root.controller.presentation.displayedTitle || "No active transmission"
          color: root.monument.inkStrong
          font.family: root.monument.archiveFont
          font.pixelSize: 21
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        Text {
          text: "ATTRIBUTED TO"
          color: root.monument.inkMuted
          font.family: root.monument.machineFont
          font.pixelSize: 9
          font.letterSpacing: 0.75
        }

        Text {
          Layout.fillWidth: true
          text: root.controller.showingMedia
            ? (root.controller.presentation.displayedArtist || "Attribution not registered")
            : "Select a record from the archive"
          color: root.monument.ink
          font.family: root.monument.archiveFont
          font.pixelSize: 13
          elide: Text.ElideRight
        }

        Text {
          text: "CATALOGUE VOLUME"
          color: root.monument.inkMuted
          font.family: root.monument.machineFont
          font.pixelSize: 9
          font.letterSpacing: 0.75
        }

        Text {
          Layout.fillWidth: true
          text: root.controller.presentation.displayedAlbum || "Unregistered volume"
          color: root.monument.inkMuted
          font.family: root.monument.archiveFont
          font.pixelSize: 12
          font.italic: true
          elide: Text.ElideRight
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 5

      MonumentButton {
        Layout.fillWidth: true
        monument: root.monument
        text: "Prev"
        enabled: root.controller.canGoPrevious
        Accessible.name: "Previous track"
        onClicked: root.controller.runAction("previous")
      }

      MonumentButton {
        Layout.fillWidth: true
        monument: root.monument
        text: root.controller.playing ? "Hold" : "Play"
        prominent: true
        enabled: root.controller.canPlayPause
        Accessible.name: root.controller.playing ? "Pause" : "Play"
        onClicked: root.controller.runAction("playPause")
      }

      MonumentButton {
        Layout.fillWidth: true
        monument: root.monument
        text: "Next"
        enabled: root.controller.canGoNext
        Accessible.name: "Next track"
        onClicked: root.controller.runAction("next")
      }

    }

    MonumentSectionHeader {
      Layout.fillWidth: true
      monument: root.monument
      code: "T-02"
      title: "Transmission position"
      status: root.controller.duration > 0
        ? Model.formatDuration(root.controller.displayedPosition) + " / "
          + Model.formatDuration(root.controller.duration) : "UNMEASURED"
      statusColor: root.monument.inkMuted
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 18
      color: root.monument.field
      border.width: 1
      border.color: root.controller.duration > 0 ? root.monument.ruleStrong : root.monument.rule

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1,
          root.controller.duration > 0
            ? root.controller.displayedPosition / root.controller.duration : 0))
        height: parent.height
        color: root.monument.authority
        opacity: 0.88
      }

      Repeater {
        model: 5

        Rectangle {
          required property int index
          x: Math.round(index * (parent.width - 1) / 4)
          width: 1
          height: parent.height
          color: root.monument.ruleStrong
          opacity: 0.65
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: root.controller.canSeek && root.controller.duration > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) { root.controller.seekRatio(mouse.x / width) }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: root.controller.lyricsSource !== ""
          ? root.controller.lyricsSource.toUpperCase() : "TRANSCRIPT REGISTER"
        color: root.monument.inkFaint
        font.family: root.monument.machineFont
        font.pixelSize: 9
        font.letterSpacing: 0.65
      }

      Item { Layout.fillWidth: true }

      MonumentButton {
        objectName: "lyricsRetryButton"
        compact: true
        monument: root.monument
        enabled: root.controller.showingMedia && root.controlsService
          && (root.controlsService.lyricsState.status === "not-found"
            || root.controlsService.lyricsState.status === "error")
        // Reserve the button's space while lyrics load so the panel never reflows.
        opacity: enabled ? 1 : 0
        code: "↻"
        text: "Retry"
        Accessible.name: "Retry lyrics lookup"
        onClicked: if (root.controlsService) root.controlsService.requestLyrics(true)
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 100
      Layout.preferredHeight: 210
      color: root.monument.field
      border.width: 1
      border.color: root.monument.rule

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
          color: root.controller.lyrics !== "" ? root.monument.ink : root.monument.inkMuted
          font.family: root.monument.archiveFont
          font.pixelSize: 13
          wrapMode: TextEdit.Wrap
          textFormat: TextEdit.PlainText
          readOnly: true
          selectByMouse: true
          selectionColor: root.monument.selectionMark
          selectedTextColor: root.monument.inkStrong
          rightPadding: 10
          bottomPadding: 10
        }
      }
    }
  }
}
