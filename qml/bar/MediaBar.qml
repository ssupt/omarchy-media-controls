import QtQuick
import QtQuick.Controls
import qs.Ui
import qs.Commons
import "../Model.js" as Model
import "../components"
import "../style"
import "../player"

BarWidget {
  id: root
  moduleName: "ssupt.media-controls"

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
  readonly property real currentDuration: controlsService ? controlsService.duration
    : (activePlayer && activePlayer.lengthSupported
      ? Model.durationSeconds(activePlayer.length) : 0)
  readonly property real duration: trackPresentation.displayedDuration
  readonly property bool playing: trackPresentation.displayedPlaying
  readonly property bool canGoPrevious: trackPresentation.displayedCanGoPrevious
  readonly property bool canGoNext: trackPresentation.displayedCanGoNext
  readonly property bool canPlayPause: trackPresentation.displayedCanPlayPause
  readonly property bool canSeek: trackPresentation.displayedCanSeek
  readonly property string lyrics: controlsService ? controlsService.lyrics : ""
  readonly property bool lyricsLoading: controlsService ? controlsService.lyricsLoading : false
  readonly property string lyricsSource: controlsService ? controlsService.lyricsSource : ""
  readonly property string lyricsMessage: controlsService ? controlsService.lyricsMessage : ""
  readonly property bool showWhenIdle: Model.booleanValue(
    root.setting("showWhenIdle", true), true)
  readonly property bool vertical: bar ? Model.isVerticalPosition(bar.position) : false
  readonly property string label: Model.nowPlayingLabel(
    trackPresentation.displayedTitle, trackPresentation.displayedArtist)
  property alias browsing: playerWindow.browserVisible
  property real displayedPosition: 0
  property bool opened: false
  readonly property real horizontalLabelWidth: Style.space(labelExtent("labelWidth", 180, 80, 320))
  readonly property real verticalLabelLength: Style.space(labelExtent("verticalLabelLength", 125, 72, 240))
  readonly property real buttonSpacing: Style.space(labelExtent("buttonSpacing", 1, 0, 8))
  readonly property var presentation: trackPresentation
  readonly property bool showingMedia: trackPresentation.showingMedia
  readonly property int transitionDuration: Style.duration(140)
  readonly property bool trackHovered: trackHover.hovered && !opened

  function labelExtent(name, fallback, minimum, maximum) {
    var value = Number(root.setting(name, fallback))
    return isFinite(value) && (value > 0 || minimum === 0)
      ? Math.max(minimum, Math.min(maximum, value)) : fallback
  }

  function setAppearance(name, value) {
    if (["labelWidth", "verticalLabelLength", "buttonSpacing", "showWhenIdle"].indexOf(name) < 0) return
    var next = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") next[key] = root.settings[key]
    if (name === "showWhenIdle") next[name] = !!value
    else {
      var number = Number(value)
      if (!isFinite(number)) return
      if (name === "buttonSpacing") next[name] = Math.max(0, Math.min(8, Math.round(number)))
      else next[name] = name === "labelWidth" ? Math.max(80, Math.min(320, Math.round(number)))
        : Math.max(72, Math.min(240, Math.round(number)))
    }
    root.settings = next
    appearanceSave.restart()
  }

  function resetAppearance() {
    setAppearance("labelWidth", 180)
    setAppearance("verticalLabelLength", 125)
    setAppearance("buttonSpacing", 1)
    setAppearance("showWhenIdle", true)
  }

  Timer {
    id: appearanceSave
    interval: 250
    onTriggered: if (root.bar && root.bar.shell
        && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

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
    if (lyricsLoading || (showingMedia && controlsService
        && controlsService.lyricsState.status === "idle")) return "Finding the words…"
    if (lyricsMessage !== "") return lyricsMessage
    return showingMedia ? "No lyrics available for this track." : "Start a song to see its lyrics."
  }

  function open() {
    opened = true
    if (!browsing && !playerWindow.settingsVisible && hasMedia) {
      resetLyricsScroll()
      updatePosition()
      if (controlsService) controlsService.requestLyrics(false)
    }
  }

  function openAppearance() {
    playerWindow.settingsVisible = true
    open()
  }

  function openBrowser() {
    playerWindow.settingsVisible = false
    browsing = true
    open()
  }

  function openNowPlaying() {
    if (!hasMedia) {
      openBrowser()
      return
    }
    playerWindow.settingsVisible = false
    browsing = false
    open()
  }

  function close() {
    opened = false
  }

  function openDetails() {
    if (!hasMedia) {
      if (opened && browsing) close()
      else openBrowser()
      return
    }
    if (opened && browsing) openNowPlaying()
    else if (opened) close()
    else openNowPlaying()
  }

  onShowingMediaChanged: if (!showingMedia && opened) {
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
      if (root.opened && root.hasMedia && !root.browsing && !playerWindow.settingsVisible
          && root.controlsService) Qt.callLater(function() {
        if (root.hasMedia) root.controlsService.requestLyrics(false)
      })
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && !root.browsing && !playerWindow.settingsVisible && root.playing
    triggeredOnStart: true
    onTriggered: root.updatePosition()
  }

  visible: showingMedia || showWhenIdle
  implicitWidth: visible ? (vertical ? barSize : horizontalLayout.implicitWidth) : 0
  implicitHeight: visible ? (vertical ? verticalLayout.implicitHeight : barSize) : 0

  MonumentStyle {
    id: monument
  }

  TrackPresentation {
    id: trackPresentation
    available: root.hasMedia
    title: root.title
    artist: root.artist
    album: root.album
    artUrl: root.artUrl
    playing: !!(root.activePlayer && root.activePlayer.isPlaying)
    canGoPrevious: !!(root.activePlayer && root.activePlayer.canGoPrevious)
    canGoNext: !!(root.activePlayer && root.activePlayer.canGoNext)
    canPlayPause: !!(root.activePlayer && (root.activePlayer.canTogglePlaying
      || root.activePlayer.canPlay || root.activePlayer.canPause))
    canSeek: !!(root.activePlayer && root.activePlayer.canSeek)
    duration: root.currentDuration
    transitionDuration: root.transitionDuration
  }

  HoverHandler { id: trackHover }

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
        else if (button === Qt.RightButton) root.openAppearance()
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
          visible: root.showingMedia
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
          anchors.verticalCenter: parent.verticalCenter
        }

        BrowserIcon {
          visible: !root.showingMedia
          extent: Math.max(Style.space(24), root.barSize - Style.space(9))
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          objectName: "barTrackDetails"
          visible: root.showingMedia
          width: root.horizontalLabelWidth
          opacity: trackPresentation.contentOpacity
          spacing: Style.space(1)
          anchors.verticalCenter: parent.verticalCenter

          ScrollingLabel {
            id: horizontalTitle
            objectName: "barTitleScroll"
            width: parent.width
            hovered: root.trackHovered
            motionEnabled: root.transitionDuration > 0
            pixelsPerSecond: Style.space(28)
            text: trackPresentation.displayedTitle || "Unknown track"
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          ScrollingLabel {
            id: horizontalArtist
            objectName: "barArtistScroll"
            width: parent.width
            hovered: root.trackHovered
            motionEnabled: root.transitionDuration > 0
            pixelsPerSecond: Style.space(28)
            text: trackPresentation.displayedArtist || "Unknown artist"
            color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          visible: !root.showingMedia
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openAppearance()
          else root.openDetails()
        }
        onWheel: function(wheel) {
          if (!root.hasMedia) return
          if (wheel.angleDelta.y > 0) root.runAction("previous")
          else if (wheel.angleDelta.y < 0) root.runAction("next")
        }
      }
    }

    Rectangle {
      visible: root.showingMedia
      width: Style.space(3)
      height: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      color: root.playing ? monument.authorityText : monument.warning
    }

    Row {
      visible: root.showingMedia
      spacing: root.buttonSpacing
      anchors.verticalCenter: parent.verticalCenter

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        enabled: root.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        enabled: root.canPlayPause
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
        enabled: root.canGoNext
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
        else if (button === Qt.RightButton) root.openAppearance()
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
        visible: root.showingMedia
        extent: parent.height
        anchors.centerIn: parent
      }

      BrowserIcon {
        visible: !root.showingMedia
        extent: parent.height
        anchors.centerIn: parent
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openAppearance()
          else root.openDetails()
        }
      }
    }

    Item {
      id: verticalLabelContainer
      visible: root.showingMedia
      width: parent.width
      height: root.verticalLabelLength
      clip: true

      property bool pressable: true
      property bool interactive: true
      property bool concealed: false
      property var registeredBar: null

      function triggerPress(button) {
        if (button === Qt.LeftButton) root.openDetails()
        else if (button === Qt.RightButton) root.openAppearance()
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

      ScrollingLabel {
        id: verticalLabel
        objectName: "barSideScroll"
        width: parent.height - Style.space(8)
        hovered: root.trackHovered
        motionEnabled: root.transitionDuration > 0
        pixelsPerSecond: Style.space(28)
        text: root.label
        opacity: trackPresentation.contentOpacity
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        rotation: root.bar && root.bar.position === "right" ? 90 : -90
        transformOrigin: Item.Center
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openAppearance()
          else root.openDetails()
        }
        onWheel: function(wheel) {
          if (wheel.angleDelta.y > 0) root.runAction("previous")
          else if (wheel.angleDelta.y < 0) root.runAction("next")
        }
      }
    }

    Column {
      visible: root.showingMedia
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.buttonSpacing

      MediaButton {
        action: "previous"
        iconText: "󰒮"
        enabled: root.canGoPrevious
      }
      MediaButton {
        action: "playPause"
        iconText: root.playing ? "󰏤" : "󰐊"
        enabled: root.canPlayPause
      }
      MediaButton {
        action: "next"
        iconText: "󰒭"
        enabled: root.canGoNext
      }
    }
  }

  PlayerWindow {
    id: playerWindow
    anchorItem: root
    bar: root.bar
    controller: root
    controlsService: root.controlsService
    requestedOpen: root.opened
    onCloseRequested: root.close()
    onBrowserRequested: root.openBrowser()
    onNowPlayingRequested: root.browsing = false
  }

  component Artwork: TrackArtwork {
    source: trackPresentation.displayedArtUrl
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    fallbackFontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    transitionDuration: root.transitionDuration
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
    implicitWidth: Math.min(root.barSize, Style.space(22))
    implicitHeight: Math.max(Style.space(24), root.barSize - Style.space(8))
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    iconSize: Style.font.body
    horizontalPadding: Style.space(3)
    verticalPadding: Style.space(2)
    opacity: enabled ? 1 : 0.38
    onClicked: root.runAction(action)
  }
}
