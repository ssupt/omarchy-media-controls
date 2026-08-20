import QtQuick
import QtQuick.Controls
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
  readonly property string album: controlsService ? controlsService.album
    : (activePlayer ? String(activePlayer.trackAlbum || "") : "")
  readonly property string artUrl: controlsService ? controlsService.artUrl
    : (activePlayer ? String(activePlayer.trackArtUrl || "") : "")
  readonly property real duration: controlsService ? controlsService.duration
    : (activePlayer && activePlayer.lengthSupported
      ? Model.durationSeconds(activePlayer.length) : 0)
  readonly property bool playing: !!(activePlayer && activePlayer.isPlaying)
  readonly property string lyrics: controlsService ? controlsService.lyrics : ""
  readonly property bool lyricsLoading: controlsService ? controlsService.lyricsLoading : false
  readonly property string lyricsSource: controlsService ? controlsService.lyricsSource : ""
  readonly property string lyricsMessage: controlsService ? controlsService.lyricsMessage : ""
  property real displayedPosition: 0
  property bool opened: false

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

  function updatePosition() {
    displayedPosition = activePlayer && activePlayer.positionSupported
      ? Math.max(0, Number(activePlayer.position || 0)) : 0
  }

  function resetLyricsScroll() {
    var flick = lyricsScroll ? lyricsScroll.contentItem : null
    if (flick && flick.contentY !== undefined) flick.contentY = 0
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

  function open() {
    if (hasMedia) {
      hideTrackTooltip()
      resetLyricsScroll()
      opened = true
      updatePosition()
      if (controlsService) controlsService.requestLyrics(false)
    }
  }

  function close() {
    opened = false
    hideTrackTooltip()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function openDetails() {
    hideTrackTooltip()
    toggle()
  }

  function showTrackTooltip() {
    if (bar && !opened) bar.showTooltip(root, label)
  }

  function hideTrackTooltip() {
    if (bar) bar.hideTooltip(root)
  }

  onOpenedChanged: {
    if (opened) hideTrackTooltip()
  }

  onHasMediaChanged: if (!hasMedia && opened) close()
  onActivePlayerChanged: updatePosition()

  Connections {
    target: root.controlsService
    function onTrackSignatureChanged() {
      root.updatePosition()
      root.resetLyricsScroll()
      if (root.opened && root.controlsService) Qt.callLater(function() {
        root.controlsService.requestLyrics(false)
      })
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.playing
    triggeredOnStart: true
    onTriggered: root.updatePosition()
  }

  visible: hasMedia
  implicitWidth: hasMedia ? (vertical ? barSize : horizontalLayout.implicitWidth) : 0
  implicitHeight: hasMedia ? (vertical ? verticalLayout.implicitHeight : barSize) : 0

  onBarChanged: {
    if (horizontalIdentity) horizontalIdentity.syncClickRegistration()
    if (verticalArtworkContainer) verticalArtworkContainer.syncClickRegistration()
    if (verticalLabelContainer) verticalLabelContainer.syncClickRegistration()
  }

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

      property bool pressable: true
      property bool interactive: true
      property bool concealed: false
      property var registeredBar: null

      function triggerPress(button) {
        if (button === Qt.LeftButton) root.openDetails()
      }

      function syncClickRegistration() {
        if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(horizontalIdentity)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(horizontalIdentity)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(horizontalIdentity)

      Row {
        id: horizontalIdentityRow
        anchors.centerIn: parent
        spacing: Style.space(7)

        Artwork {
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
          anchors.verticalCenter: parent.verticalCenter
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
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: horizontalArtist
            width: parent.width
            text: root.artist || "Unknown artist"
            color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
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
        onEntered: if (!root.opened) root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Row {
      spacing: Style.space(1)
      anchors.verticalCenter: parent.verticalCenter

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
          || root.activePlayer.canPlay || root.activePlayer.canPause)
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
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
      id: verticalArtworkContainer
      width: parent.width
      height: Math.max(Style.space(24), root.barSize - Style.space(8))

      property bool pressable: true
      property bool interactive: true
      property bool concealed: false
      property var registeredBar: null

      function triggerPress(button) {
        if (button === Qt.LeftButton) root.openDetails()
      }

      function syncClickRegistration() {
        if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(verticalArtworkContainer)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(verticalArtworkContainer)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(verticalArtworkContainer)

      Artwork {
        extent: parent.height
        anchors.centerIn: parent
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
        onEntered: if (!root.opened) root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Item {
      id: verticalLabelContainer
      width: parent.width
      height: Math.min(root.maxVerticalLabelLength, Math.max(Style.space(72), verticalLabel.implicitWidth))
      clip: true

      property bool pressable: true
      property bool interactive: true
      property bool concealed: false
      property var registeredBar: null

      function triggerPress(button) {
        if (button === Qt.LeftButton) root.openDetails()
      }

      function syncClickRegistration() {
        if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(verticalLabelContainer)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(verticalLabelContainer)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(verticalLabelContainer)

      Text {
        id: verticalLabel
        width: parent.height - Style.space(8)
        text: root.label
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
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
        onEntered: if (!root.opened) root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(1)

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
          || root.activePlayer.canPlay || root.activePlayer.canPause)
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
        enabled: !!root.activePlayer && root.activePlayer.canGoNext
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root
    bar: root.bar
    // Keep popup coordination without marking the full two-line widget as
    // panel-open: the host indicator would cover the artist row.
    owner: panel
    open: root.opened && root.hasMedia
    focusTarget: keyScope
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(frame.implicitHeight, Style.space(560))

    function close() {
      root.close()
    }

    onOpenChanged: {
      if (open) {
        root.resetLyricsScroll()
        root.updatePosition()
        if (root.controlsService) root.controlsService.requestLyrics(false)
      }
    }

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close()
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(16)

          BorderSurface {
            id: panelArtwork
            width: Style.space(100)
            height: Style.space(100)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            clip: true

            Image {
              id: panelArtworkImage
              anchors.fill: parent
              anchors.margins: Style.space(1)
              source: root.artUrl
              asynchronous: true
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
              sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: panelArtworkImage.status !== Image.Ready
              text: "󰝚"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(40)
            }
          }

          Column {
            width: parent.width - panelArtwork.width - parent.spacing
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: root.title || "Nothing playing"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.artist || "Unknown artist"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.album
              visible: text !== ""
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.65)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              spacing: Style.space(6)

              Button {
                iconText: "󰒮"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
                opacity: enabled ? 1 : 0.38
                onClicked: root.runAction("previous")
              }

              Button {
                iconText: root.playing ? "󰏤" : "󰐊"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                iconSize: Style.font.iconLarge
                horizontalPadding: Style.space(16)
                enabled: !!root.activePlayer && (root.activePlayer.canTogglePlaying
                  || root.activePlayer.canPlay || root.activePlayer.canPause)
                opacity: enabled ? 1 : 0.38
                onClicked: root.runAction("playPause")
              }

              Button {
                iconText: "󰒭"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                enabled: !!root.activePlayer && root.activePlayer.canGoNext
                opacity: enabled ? 1 : 0.38
                onClicked: root.runAction("next")
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.duration > 0

          Rectangle {
            width: parent.width
            height: Style.space(4)
            radius: height / 2
            color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.18)

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
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Item { width: Math.max(0, parent.width - elapsedLabel.width - durationLabel.width); height: 1 }

            Text {
              id: durationLabel
              text: Model.formatDuration(root.duration)
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            id: lyricsTitle
            text: "LYRICS"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            anchors.verticalCenter: parent.verticalCenter
          }

          BorderSurface {
            id: sourceBadge
            visible: root.lyricsSource !== ""
            implicitWidth: sourceLabel.implicitWidth + Style.space(12)
            implicitHeight: sourceLabel.implicitHeight + Style.space(4)
            radius: height / 2
            color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.08)
            borderSpec: Border.none()
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: sourceLabel
              anchors.centerIn: parent
              text: root.lyricsSource
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
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
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onClicked: if (root.controlsService) root.controlsService.requestLyrics(true)
          }
        }

        ScrollView {
          id: lyricsScroll
          width: parent.width
          height: Style.space(260)
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          TextEdit {
            width: lyricsScroll.availableWidth
            height: Math.max(lyricsScroll.height, contentHeight + Style.space(20))
            text: root.lyricsDisplayText()
            color: root.lyrics !== ""
              ? (root.bar ? root.bar.foreground : Color.foreground)
              : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            readOnly: true
            selectByMouse: true
            selectionColor: Color.accent
            selectedTextColor: Color.background
            leftPadding: Style.space(4)
            rightPadding: Style.space(12)
            topPadding: Style.space(4)
            bottomPadding: Style.space(12)
          }
        }
      }
    }
  }

  component Artwork: BorderSurface {
    required property real extent
    width: extent
    height: extent
    radius: Style.spacing.labelGap
    color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
    clip: true

    Image {
      id: artworkImage
      anchors.fill: parent
      anchors.margins: Style.space(1)
      source: root.artUrl
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
      sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
      visible: status === Image.Ready
    }

    Text {
      anchors.centerIn: parent
      visible: artworkImage.status !== Image.Ready
      text: "󰝚"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.title
    }
  }

  component MediaButton: Button {
    required property string action
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    iconSize: Style.font.body
    horizontalPadding: Style.space(4)
    verticalPadding: Style.space(2)
    opacity: enabled ? 1 : 0.38
    onClicked: root.runAction(action)
  }
}
