import QtQuick

Item {
  id: root
  visible: false
  width: 0
  height: 0

  property bool available: false
  property string title: ""
  property string artist: ""
  property string album: ""
  property string artUrl: ""
  property bool playing: false
  property bool canGoPrevious: false
  property bool canGoNext: false
  property bool canPlayPause: false
  property bool canSeek: false
  property real duration: 0
  property int settleDuration: 80
  property int gapDuration: 250
  property int transitionDuration: 140

  property var displayedTrack: null
  property bool initialized: false
  property real contentOpacity: 1
  readonly property bool showingMedia: displayedTrack !== null
  readonly property string displayedTitle: displayedTrack ? displayedTrack.title : ""
  readonly property string displayedArtist: displayedTrack ? displayedTrack.artist : ""
  readonly property string displayedAlbum: displayedTrack ? displayedTrack.album : ""
  readonly property string displayedArtUrl: displayedTrack ? displayedTrack.artUrl : ""
  readonly property bool displayedPlaying: displayedTrack ? displayedTrack.playing : false
  readonly property bool displayedCanGoPrevious: displayedTrack ? displayedTrack.canGoPrevious : false
  readonly property bool displayedCanGoNext: displayedTrack ? displayedTrack.canGoNext : false
  readonly property bool displayedCanPlayPause: displayedTrack ? displayedTrack.canPlayPause : false
  readonly property bool displayedCanSeek: displayedTrack ? displayedTrack.canSeek : false
  readonly property real displayedDuration: displayedTrack ? displayedTrack.duration : 0

  function schedule() {
    if (!initialized) return
    // Metadata and playback status can arrive in separate D-Bus messages.
    // Publish one settled snapshot instead of flashing each intermediate state.
    if (displayedTrack && (!available || (!title && !artist))) {
      settleTimer.stop()
      if (!gapTimer.running) gapTimer.start()
    } else {
      gapTimer.stop()
      settleTimer.restart()
    }
  }

  function sync(expired) {
    // MPRIS players can clear metadata briefly between tracks. Keep the last
    // complete display until metadata returns or the gap timeout expires.
    if (displayedTrack && (!available || (!title && !artist)) && !expired) {
      if (!gapTimer.running) gapTimer.start()
      return
    }
    gapTimer.stop()

    var next = available ? {
      title: title, artist: artist, album: album, artUrl: artUrl, playing: playing,
      canGoPrevious: canGoPrevious, canGoNext: canGoNext, canPlayPause: canPlayPause,
      canSeek: canSeek, duration: duration
    } : null
    var textChanged = !!next && (!displayedTrack
      || next.title !== displayedTrack.title || next.artist !== displayedTrack.artist
      || next.album !== displayedTrack.album)
    if (!next) {
      textFade.stop()
      contentOpacity = 1
    }
    displayedTrack = next
    if (initialized && textChanged && transitionDuration > 0) textFade.restart()
    initialized = true
  }

  onAvailableChanged: Qt.callLater(schedule)
  onTitleChanged: Qt.callLater(schedule)
  onArtistChanged: Qt.callLater(schedule)
  onAlbumChanged: Qt.callLater(schedule)
  onArtUrlChanged: Qt.callLater(schedule)
  onPlayingChanged: Qt.callLater(schedule)
  onCanGoPreviousChanged: Qt.callLater(schedule)
  onCanGoNextChanged: Qt.callLater(schedule)
  onCanPlayPauseChanged: Qt.callLater(schedule)
  onCanSeekChanged: Qt.callLater(schedule)
  onDurationChanged: Qt.callLater(schedule)
  onTransitionDurationChanged: if (transitionDuration === 0) {
    textFade.stop()
    contentOpacity = 1
  }
  Component.onCompleted: sync(false)

  Timer {
    id: settleTimer
    interval: root.settleDuration
    onTriggered: root.sync(false)
  }

  Timer {
    id: gapTimer
    interval: root.gapDuration
    onTriggered: root.sync(true)
  }

  NumberAnimation {
    id: textFade
    target: root
    property: "contentOpacity"
    from: 0.45
    to: 1
    duration: root.transitionDuration
    easing.type: Easing.OutCubic
  }
}
