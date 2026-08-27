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
  readonly property string integrationMode: Model.codaIntegrationMode(
    root.setting("codaIntegration", "auto"))
  readonly property bool showCodaDetails: Model.booleanValue(
    root.setting("showCodaDetails", true), true)
  readonly property bool showWhenIdle: Model.booleanValue(
    root.setting("showWhenIdle", true), true)
  readonly property bool vertical: bar ? Model.isVerticalPosition(bar.position) : false
  readonly property string label: Model.nowPlayingLabel(title, artist)
  property alias browsing: playerWindow.browserVisible
  property real displayedPosition: 0
  property bool opened: false
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
    playerWindow.resetLyricsScroll()
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
    hideTrackTooltip()
    opened = true
    if (!browsing && hasMedia) {
      resetLyricsScroll()
      updatePosition()
      if (controlsService) controlsService.requestLyrics(false)
    }
  }

  function openBrowser() {
    browsing = true
    open()
  }

  function openNowPlaying() {
    if (!hasMedia) {
      openBrowser()
      return
    }
    browsing = false
    open()
  }

  function close() {
    opened = false
    hideTrackTooltip()
  }

  function openDetails() {
    hideTrackTooltip()
    if (!hasMedia) {
      if (opened && browsing) close()
      else openBrowser()
      return
    }
    if (opened && browsing) openNowPlaying()
    else if (opened) close()
    else openNowPlaying()
  }

  function showTrackTooltip() {
    if (bar && !opened) bar.showTooltip(root, hasMedia ? label : "Browse music archive")
  }

  function hideTrackTooltip() {
    if (bar) bar.hideTooltip(root)
  }

  onOpenedChanged: if (opened) hideTrackTooltip()
  onHasMediaChanged: if (!hasMedia && opened) {
    if (showWhenIdle) browsing = true
    else close()
  }
  onShowWhenIdleChanged: if (!showWhenIdle && !hasMedia && opened) close()
  onActivePlayerChanged: updatePosition()

  Connections {
    target: root.controlsService
    function onTrackSignatureChanged() {
      root.updatePosition()
      root.resetLyricsScroll()
      if (root.opened && !root.browsing && root.controlsService) Qt.callLater(function() {
        root.controlsService.requestLyrics(false)
      })
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && !root.browsing && root.playing
    triggeredOnStart: true
    onTriggered: root.updatePosition()
  }

  visible: hasMedia || showWhenIdle
  implicitWidth: visible ? (vertical ? barSize : horizontalLayout.implicitWidth) : 0
  implicitHeight: visible ? (vertical ? verticalLayout.implicitHeight : barSize) : 0

  MonumentStyle {
    id: monument
  }

  onBarChanged: {
    if (horizontalIdentity) horizontalIdentity.syncClickRegistration()
    if (verticalIdentity) verticalIdentity.syncClickRegistration()
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
        if (registeredBar && registeredBar.unregisterClickTarget)
          registeredBar.unregisterClickTarget(horizontalIdentity)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget)
          registeredBar.registerClickTarget(horizontalIdentity)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget)
        registeredBar.unregisterClickTarget(horizontalIdentity)

      Row {
        id: horizontalIdentityRow
        anchors.centerIn: parent
        spacing: Style.space(7)

        Artwork {
          visible: root.hasMedia
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
          anchors.verticalCenter: parent.verticalCenter
        }

        BrowserIcon {
          visible: !root.hasMedia
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          visible: root.hasMedia
          width: Math.min(root.maxHorizontalLabelWidth,
            Math.max(Style.space(72), Math.max(horizontalTitle.implicitWidth,
              horizontalArtist.implicitWidth)))
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

        Text {
          visible: !root.hasMedia
          anchors.verticalCenter: parent.verticalCenter
          text: "ARCHIVE"
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.7
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDetails()
        onWheel: function(wheel) {
          if (!root.hasMedia) return
          if (wheel.angleDelta.y > 0) root.runAction("previous")
          else if (wheel.angleDelta.y < 0) root.runAction("next")
        }
        onEntered: if (!root.opened) root.showTrackTooltip()
        onExited: root.hideTrackTooltip()
      }
    }

    Rectangle {
      visible: root.hasMedia
      width: Style.space(3)
      height: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      color: root.playing ? monument.authorityText : monument.warning
    }

    Row {
      visible: root.hasMedia
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
      id: verticalIdentity
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
        if (registeredBar && registeredBar.unregisterClickTarget)
          registeredBar.unregisterClickTarget(verticalIdentity)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget)
          registeredBar.registerClickTarget(verticalIdentity)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget)
        registeredBar.unregisterClickTarget(verticalIdentity)

      Artwork {
        visible: root.hasMedia
        extent: parent.height
        anchors.centerIn: parent
      }

      BrowserIcon {
        visible: !root.hasMedia
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
      visible: root.hasMedia
      width: parent.width
      height: Math.min(root.maxVerticalLabelLength,
        Math.max(Style.space(72), verticalLabel.implicitWidth))
      clip: true

      property bool pressable: true
      property bool interactive: true
      property bool concealed: false
      property var registeredBar: null

      function triggerPress(button) {
        if (button === Qt.LeftButton) root.openDetails()
      }

      function syncClickRegistration() {
        if (registeredBar && registeredBar.unregisterClickTarget)
          registeredBar.unregisterClickTarget(verticalLabelContainer)
        registeredBar = root.bar
        if (registeredBar && registeredBar.registerClickTarget)
          registeredBar.registerClickTarget(verticalLabelContainer)
      }

      onVisibleChanged: syncClickRegistration()
      Component.onCompleted: syncClickRegistration()
      Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget)
        registeredBar.unregisterClickTarget(verticalLabelContainer)

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
      visible: root.hasMedia
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

  PlayerWindow {
    id: playerWindow
    anchorItem: root
    bar: root.bar
    controller: root
    controlsService: root.controlsService
    integrationMode: root.integrationMode
    showCodaDetails: root.showCodaDetails
    requestedOpen: root.opened
    onCloseRequested: root.close()
    onBrowserRequested: root.openBrowser()
    onNowPlayingRequested: root.browsing = false
  }

  component Artwork: BorderSurface {
    required property real extent
    width: extent
    height: extent
    radius: 0
    color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal",
      root.bar ? root.bar.foreground : Color.foreground, Color.accent)
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

  component BrowserIcon: BorderSurface {
    required property real extent
    width: extent
    height: extent
    radius: 0
    color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
    borderSpec: Border.controlSpec("normal",
      root.bar ? root.bar.foreground : Color.foreground, Color.accent)

    Text {
      anchors.centerIn: parent
      text: "□"
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
