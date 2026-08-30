import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property string preferredPlayerKey: ""
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var sourcePlayers: orderedPlayers()
  readonly property var activePlayer: selectActivePlayer()
  readonly property bool hasMedia: activePlayer !== null
    && (activePlayer.trackTitle || activePlayer.trackArtist || activePlayer.trackAlbum)
  readonly property string activePlayerKey: playerKey(activePlayer)
  readonly property string title: activePlayer ? String(activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? String(activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer ? String(activePlayer.trackAlbum || "") : ""
  readonly property real duration: activePlayer && activePlayer.lengthSupported
    ? Model.durationSeconds(activePlayer.length) : 0
  readonly property var metadata: activePlayer && activePlayer.metadata ? activePlayer.metadata : ({})
  readonly property string trackUrl: Model.metadataText(metadata, "xesam:url")
  readonly property string embeddedLyrics: Model.metadataText(metadata, "xesam:asText")
  readonly property string primaryArtUrl: activePlayer ? String(activePlayer.trackArtUrl || "") : ""
  property string fallbackArtUrl: ""
  readonly property string artUrl: primaryArtUrl || fallbackArtUrl
  readonly property string trackSignature: Model.trackSignature(activePlayer)

  property var lyricsState: Model.emptyLyricsResponse()
  property string lyricsTrackSignature: ""
  property string coverRequestSignature: ""
  property string lyricsRequestSignature: ""
  readonly property bool lyricsLoading: lyricsState.status === "loading"
  readonly property string lyrics: String(lyricsState.lyrics || "")
  readonly property string syncedLyrics: String(lyricsState.syncedLyrics || "")
  readonly property string lyricsSource: Model.lyricsSourceLabel(lyricsState.source)
  readonly property string lyricsMessage: String(lyricsState.message || "")

  property string musicRoot: ""
  property string musicRootMessage: "Resolving the Music folder…"
  property bool toccataInstalled: false
  readonly property bool toccataConnected: toccataPlayer() !== null
  readonly property bool activeIsToccata: isToccataPlayer(activePlayer)
  property var toccataStatus: ({})
  property string toccataStatusState: "idle"
  property string toccataStatusMessage: ""
  property bool toccataStatusHandled: false
  property bool toccataShowHandled: false
  property string launchState: "idle"
  property string launchBackend: ""
  property string launchMessage: ""
  property string launchTarget: ""
  property string launchKind: ""
  property string launchToccataMode: "auto"
  property string pausedPlayerKey: ""
  property bool pausedPlayerWasPlaying: false
  property string toccataSignatureBeforeLaunch: ""
  property bool validateHandled: false
  property bool launchHandled: false

  signal handoffSucceeded()
  signal launchResultChanged()

  function pluginScript(name) {
    var url = String(Qt.resolvedUrl("scripts/" + name))
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  function resolveMusicRoot() {
    musicRoot = ""
    musicRootMessage = "Resolving the Music folder…"
    rootProc.command = [pluginScript("media-launch"), "--resolve-root"]
    rootProc.running = true
  }

  function isToccataPlayer(player) {
    if (!player) return false
    var key = playerKey(player).toLowerCase()
    return key === "org.mpris.mediaplayer2.toccata"
      || key.indexOf("org.mpris.mediaplayer2.toccata.") === 0
      || String(player.desktopEntry || "").toLowerCase() === "io.github.ssupt.toccata"
  }

  function toccataPlayer() {
    for (var i = 0; i < players.length; i++) {
      if (isToccataPlayer(players[i])) return players[i]
    }
    return null
  }

  function pauseForHandoff() {
    var player = activePlayer
    pausedPlayerKey = ""
    pausedPlayerWasPlaying = false
    if (!player || !player.isPlaying) return
    pausedPlayerKey = playerKey(player)
    pausedPlayerWasPlaying = true
    if (player.canPause) player.pause()
    else if (player.canTogglePlaying) player.togglePlaying()
  }

  function resumePausedPlayer() {
    if (!pausedPlayerWasPlaying || pausedPlayerKey === "") return
    var player = playerForKey(pausedPlayerKey)
    if (player) {
      if (player.canPlay) player.play()
      else if (player.canTogglePlaying && !player.isPlaying) player.togglePlaying()
      preferredPlayerKey = playerKey(player)
    }
    pausedPlayerKey = ""
    pausedPlayerWasPlaying = false
  }

  function launchPath(target, kind, toccataMode) {
    if (musicRoot === "") {
      launchState = "error"
      launchMessage = musicRootMessage || "The Music folder is unavailable."
      launchResultChanged()
      return false
    }
    if (launchState === "validating" || launchState === "launching" || launchState === "waiting")
      return false
    launchTarget = String(target || "")
    launchKind = String(kind || "")
    launchToccataMode = Model.toccataIntegrationMode(toccataMode)
    launchBackend = ""
    launchMessage = "Checking the selection…"
    launchState = "validating"
    validateHandled = false
    validateProc.command = [pluginScript("media-launch"), "--validate-only",
      "--root", musicRoot, "--target", launchTarget, "--kind", launchKind]
    validateProc.running = true
    launchResultChanged()
    return true
  }

  function beginValidatedLaunch() {
    toccataSignatureBeforeLaunch = Model.trackSignature(toccataPlayer())
    pauseForHandoff()
    launchState = "launching"
    launchMessage = "Starting playback…"
    launchHandled = false
    var command = [pluginScript("media-launch"), "--root", musicRoot,
      "--target", launchTarget, "--kind", launchKind,
      "--toccata-mode", launchToccataMode]
    if (launchToccataMode === "auto" && toccataConnected) command.push("--toccata-active")
    launchProc.command = command
    launchProc.running = true
    launchResultChanged()
  }

  function handleLaunchResponse(payload) {
    if (launchHandled) return
    launchHandled = true
    if (payload.status !== "accepted") {
      resumePausedPlayer()
      launchState = "error"
      launchBackend = String(payload.backend || "")
      launchMessage = String(payload.message || "Could not start playback.")
      launchResultChanged()
      return
    }
    launchBackend = String(payload.backend || "")
    launchMessage = String(payload.message || "Playback request accepted.")
    if (payload.expectsMpris && launchBackend === "toccata") {
      launchState = "waiting"
      handoffTimeout.restart()
      toccataPoll.start()
      tryToccataHandoff()
    } else {
      pausedPlayerKey = ""
      pausedPlayerWasPlaying = false
      toccataSignatureBeforeLaunch = ""
      launchState = "success"
      launchResultChanged()
    }
  }

  function tryToccataHandoff() {
    if (launchState !== "waiting") return false
    var player = toccataPlayer()
    if (!player || !hasTrackMetadata(player)) return false
    var metadataUrl = Model.metadataText(player.metadata || {}, "xesam:url")
    var targetMatches = metadataUrl.indexOf("file:") === 0
      && Model.fileUrlToPath(metadataUrl) === launchTarget
    if (Model.trackSignature(player) === toccataSignatureBeforeLaunch && !targetMatches)
      return false
    preferredPlayerKey = playerKey(player)
    pausedPlayerKey = ""
    pausedPlayerWasPlaying = false
    toccataSignatureBeforeLaunch = ""
    launchState = "success"
    launchBackend = "toccata"
    launchMessage = "Now playing with Toccata."
    handoffTimeout.stop()
    toccataPoll.stop()
    launchResultChanged()
    handoffSucceeded()
    return true
  }

  function requestToccataStatus() {
    if (!toccataInstalled || !activeIsToccata || toccataStatusProc.running) return false
    toccataStatusHandled = false
    toccataStatusState = "loading"
    toccataStatusMessage = ""
    toccataStatusProc.command = [pluginScript("media-launch"), "--toccata-status"]
    toccataStatusProc.running = true
    return true
  }

  function handleToccataStatusResponse(payload) {
    if (toccataStatusHandled) return
    toccataStatusHandled = true
    if (payload.status === "accepted" && payload.toccata) {
      toccataStatus = payload.toccata
      toccataStatusState = "ready"
      toccataStatusMessage = ""
    } else {
      toccataStatus = ({})
      toccataStatusState = "error"
      toccataStatusMessage = String(payload.message || "Toccata status is unavailable.")
    }
  }

  function showToccata() {
    if (!toccataInstalled || toccataShowProc.running) return false
    toccataShowHandled = false
    toccataShowProc.command = [pluginScript("media-launch"), "--show-toccata"]
    toccataShowProc.running = true
    return true
  }

  function handleToccataShowResponse(payload) {
    if (toccataShowHandled) return
    toccataShowHandled = true
    if (payload.status === "accepted") {
      toccataInstalled = true
      toccataStatusMessage = ""
    } else toccataStatusMessage = String(payload.message || "Toccata could not be opened.")
  }

  function isProxyPlayer(player) {
    return Model.isProxyPlayer(player)
  }

  function hasMetadata(player) {
    return Model.hasPlayerMetadata(player)
  }

  function hasTrackMetadata(player) {
    return Model.hasTrackMetadata(player)
  }

  function playerKey(player) {
    return Model.playerKey(player)
  }

  function playerForKey(key) {
    if (!key) return null
    for (var i = 0; i < players.length; i++) {
      if (playerKey(players[i]) === key) return players[i]
    }
    return null
  }

  function canHandleAction(player, action) {
    if (!player) return false
    if (action === "next") return !!player.canGoNext
    if (action === "previous") return !!player.canGoPrevious
    if (action === "play") return !!(player.canPlay || player.canTogglePlaying)
    if (action === "pause") return !!(player.canPause || player.canTogglePlaying)
    if (action === "playPause")
      return !!(player.canTogglePlaying || player.canPlay || player.canPause)
    return false
  }

  function orderedPlayers() {
    return Model.orderedPlayers(players, preferredPlayerKey)
  }

  function selectActivePlayer() {
    return Model.selectActivePlayer(players, preferredPlayerKey)
  }

  function playerForAction(action, targetKey) {
    var targeted = playerForKey(targetKey)
    if (targeted && canHandleAction(targeted, action)) return targeted

    if (action === "pause" || action === "playPause") {
      for (var i = 0; i < sourcePlayers.length; i++) {
        if (sourcePlayers[i].isPlaying && canHandleAction(sourcePlayers[i], action))
          return sourcePlayers[i]
      }
    }

    if (canHandleAction(activePlayer, action)) return activePlayer
    for (var j = 0; j < sourcePlayers.length; j++) {
      if (canHandleAction(sourcePlayers[j], action)) return sourcePlayers[j]
    }
    return activePlayer
  }

  function runAction(action) {
    var player = playerForAction(action, activePlayerKey)
    var handled = false
    if (action === "next" && player && player.canGoNext) {
      player.next()
      handled = true
    } else if (action === "previous" && player && player.canGoPrevious) {
      player.previous()
      handled = true
    } else if (action === "play" && player) {
      if (player.canPlay) player.play()
      else if (player.canTogglePlaying && !player.isPlaying) player.togglePlaying()
      else return false
      handled = true
    } else if (action === "pause" && player) {
      if (player.canPause) player.pause()
      else if (player.canTogglePlaying && player.isPlaying) player.togglePlaying()
      else return false
      handled = true
    } else if (action === "playPause" && player) {
      if (player.isPlaying && player.canPause) player.pause()
      else if (!player.isPlaying && player.canPlay) player.play()
      else if (player.canTogglePlaying) player.togglePlaying()
      else return false
      handled = true
    }
    if (handled) preferredPlayerKey = playerKey(player)
    return handled
  }

  function selectPlayer(key) {
    var player = playerForKey(key)
    if (!hasMetadata(player)) return false
    preferredPlayerKey = playerKey(player)
    return true
  }

  function statusJson() {
    var player = activePlayer
    return JSON.stringify({
      hasPlayer: player !== null,
      hasMedia: hasMedia,
      playing: player ? !!player.isPlaying : false,
      identity: player ? String(player.identity || "") : "",
      desktopEntry: player ? String(player.desktopEntry || "") : "",
      title: title,
      artist: artist,
      album: album,
      artUrl: artUrl,
      canGoNext: player ? !!player.canGoNext : false,
      canGoPrevious: player ? !!player.canGoPrevious : false,
      canTogglePlaying: player ? !!player.canTogglePlaying : false
    })
  }

  function refreshTrack() {
    if (coverProc.running) coverProc.running = false
    if (lyricsProc.running) lyricsProc.running = false
    fallbackArtUrl = ""
    coverRequestSignature = ""
    lyricsRequestSignature = ""
    lyricsTrackSignature = ""
    lyricsState = Model.emptyLyricsResponse()
    if (hasMedia && primaryArtUrl === "" && trackUrl.indexOf("file:") === 0)
      coverDelay.restart()
  }

  function requestLyrics(force) {
    if (!hasMedia) {
      lyricsState = {
        status: "not-found",
        lyrics: "",
        syncedLyrics: "",
        source: "",
        message: "Start a song to see its lyrics."
      }
      return
    }
    if (!force && lyricsTrackSignature === trackSignature
        && (lyricsState.status === "ok" || lyricsState.status === "not-found")) return

    if (embeddedLyrics !== "") {
      lyricsTrackSignature = trackSignature
      lyricsState = {
        status: "ok",
        lyrics: embeddedLyrics,
        syncedLyrics: "",
        source: "mpris",
        message: ""
      }
      return
    }

    if (lyricsProc.running) lyricsProc.running = false
    lyricsRequestSignature = trackSignature
    lyricsTrackSignature = trackSignature
    lyricsState = {
      status: "loading",
      lyrics: "",
      syncedLyrics: "",
      source: "",
      message: "Looking for lyrics…"
    }
    lyricsProc.command = [
      pluginScript("media-lyrics"),
      "--title", title,
      "--artist", artist,
      "--album", album,
      "--duration", String(Math.round(duration)),
      "--url", trackUrl
    ]
    lyricsProc.running = true
  }

  onTrackSignatureChanged: refreshTrack()
  onActiveIsToccataChanged: {
    if (!activeIsToccata) {
      if (toccataStatusProc.running) toccataStatusProc.running = false
      toccataStatusHandled = true
      toccataStatus = ({})
      toccataStatusState = "idle"
      toccataStatusMessage = ""
    }
  }
  onPrimaryArtUrlChanged: {
    if (primaryArtUrl !== "") {
      coverDelay.stop()
      if (coverProc.running) coverProc.running = false
    } else if (hasMedia && trackUrl.indexOf("file:") === 0 && fallbackArtUrl === "") {
      coverDelay.restart()
    }
  }
  Component.onCompleted: {
    refreshTrack()
    resolveMusicRoot()
  }

  Timer {
    id: handoffTimeout
    interval: 8000
    repeat: false
    onTriggered: {
      if (root.launchState !== "waiting") return
      toccataPoll.stop()
      root.resumePausedPlayer()
      root.launchState = "error"
      root.launchMessage = "Toccata did not expose playable media within eight seconds. The previous player was resumed."
      root.launchResultChanged()
    }
  }

  Timer {
    id: toccataPoll
    interval: 100
    repeat: true
    onTriggered: root.tryToccataHandoff()
  }

  Timer {
    id: coverDelay
    interval: 80
    repeat: false
    onTriggered: {
      if (!root.hasMedia || root.primaryArtUrl !== "" || root.trackUrl.indexOf("file:") !== 0)
        return
      root.coverRequestSignature = root.trackSignature
      coverProc.command = [root.pluginScript("media-cover"), "--url", root.trackUrl]
      coverProc.running = true
    }
  }

  Process {
    id: coverProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.coverRequestSignature !== root.trackSignature) return
        root.fallbackArtUrl = String(text || "").trim()
      }
    }
  }

  Process {
    id: lyricsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.lyricsRequestSignature !== root.trackSignature) return
        root.lyricsState = Model.parseLyricsResponse(text)
      }
    }
    onExited: function(exitCode) {
      if (root.lyricsRequestSignature !== root.trackSignature) return
      if (exitCode !== 0) {
        root.lyricsState = {
          status: "error",
          lyrics: "",
          syncedLyrics: "",
          source: "",
          message: "Could not run the lyrics helper."
        }
      }
    }
  }

  Process {
    id: rootProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = Model.parseHelperResponse(text)
        root.toccataInstalled = !!payload.toccataInstalled
        if (payload.status === "accepted" && payload.root) {
          root.musicRoot = String(payload.root)
          root.musicRootMessage = ""
        } else {
          root.musicRoot = ""
          root.musicRootMessage = String(payload.message || "The Music folder is unavailable.")
        }
      }
    }
  }

  Process {
    id: validateProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.validateHandled || root.launchState !== "validating") return
        root.validateHandled = true
        var payload = Model.parseHelperResponse(text)
        if (payload.status === "accepted") {
          root.launchTarget = String(payload.target || root.launchTarget)
          root.beginValidatedLaunch()
        }
        else {
          root.launchState = "error"
          root.launchMessage = String(payload.message || "The selection is not playable.")
          root.launchResultChanged()
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.validateHandled && root.launchState === "validating") {
        root.validateHandled = true
        root.launchState = "error"
        root.launchMessage = "Could not validate the selected music."
        root.launchResultChanged()
      }
    }
  }

  Process {
    id: launchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleLaunchResponse(Model.parseHelperResponse(text))
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.launchHandled)
        root.handleLaunchResponse({ status: "error", backend: "", expectsMpris: false,
          message: "The music launcher exited before accepting playback." })
    }
  }

  Process {
    id: toccataStatusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleToccataStatusResponse(Model.parseHelperResponse(text))
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.toccataStatusHandled)
        root.handleToccataStatusResponse({ status: "error",
          message: "Toccata status could not be read." })
    }
  }

  Process {
    id: toccataShowProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleToccataShowResponse(Model.parseHelperResponse(text))
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.toccataShowHandled)
        root.handleToccataShowResponse({ status: "error",
          message: "Toccata could not be opened." })
    }
  }

  IpcHandler {
    target: "media"

    function status(): string { return root.statusJson() }
    function playPause(): string { return root.runAction("playPause") ? "ok" : "unhandled" }
    function next(): string { return root.runAction("next") ? "ok" : "unhandled" }
    function previous(): string { return root.runAction("previous") ? "ok" : "unhandled" }
    function play(): string { return root.runAction("play") ? "ok" : "unhandled" }
    function pause(): string { return root.runAction("pause") ? "ok" : "unhandled" }
    function ping(): string { return "ok" }
  }
}
