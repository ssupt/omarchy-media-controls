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
  readonly property real duration: activePlayer ? Model.durationSeconds(activePlayer.length) : 0
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

  function pluginScript(name) {
    var url = String(Qt.resolvedUrl("scripts/" + name))
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  function isProxyPlayer(player) {
    if (!player) return false
    var dbusName = String(player.dbusName || "").toLowerCase()
    var desktopEntry = String(player.desktopEntry || "").toLowerCase()
    return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld"
  }

  function hasMetadata(player) {
    return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum
      || player.identity || player.desktopEntry))
  }

  function hasTrackMetadata(player) {
    return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum
      || player.trackArtUrl))
  }

  function playerKey(player) {
    return player ? String(player.dbusName || player.desktopEntry || player.identity || "") : ""
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
    var ordered = []
    for (var i = 0; i < players.length; i++) {
      if (hasMetadata(players[i])) ordered.push(players[i])
    }
    ordered.sort(function(left, right) {
      var leftPreferred = playerKey(left) === preferredPlayerKey
      var rightPreferred = playerKey(right) === preferredPlayerKey
      if (!!left.isPlaying !== !!right.isPlaying) return left.isPlaying ? -1 : 1
      if (leftPreferred !== rightPreferred) return leftPreferred ? -1 : 1
      if (isProxyPlayer(left) !== isProxyPlayer(right)) return isProxyPlayer(left) ? 1 : -1
      var leftLabel = String(left.trackTitle || left.identity || left.desktopEntry || "")
      var rightLabel = String(right.trackTitle || right.identity || right.desktopEntry || "")
      return leftLabel.localeCompare(rightLabel)
    })
    return ordered
  }

  function selectActivePlayer() {
    var preferred = playerForKey(preferredPlayerKey)
    if (hasMetadata(preferred) && preferred.isPlaying) return preferred

    var playingProxy = null
    var trackPlayer = null
    var trackProxy = null
    var fallbackProxy = null
    var fallback = null

    for (var i = 0; i < players.length; i++) {
      var player = players[i]
      if (!hasMetadata(player)) continue
      var proxy = isProxyPlayer(player)
      if (player.isPlaying) {
        if (!proxy) return player
        if (!playingProxy) playingProxy = player
      } else if (hasTrackMetadata(player)) {
        if (!proxy && !trackPlayer) trackPlayer = player
        else if (proxy && !trackProxy) trackProxy = player
      } else if (!proxy && !fallback) {
        fallback = player
      } else if (proxy && !fallbackProxy) {
        fallbackProxy = player
      }
    }

    return playingProxy || (hasMetadata(preferred) ? preferred : null)
      || trackPlayer || trackProxy || fallback || fallbackProxy
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
  Component.onCompleted: refreshTrack()

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
