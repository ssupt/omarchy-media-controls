import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  readonly property var mediaService: shell ? shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []
  readonly property bool hasMedia: activePlayer !== null
    && (activePlayer.trackTitle || activePlayer.trackArtist || activePlayer.trackAlbum)
  readonly property string playerKey: mediaService && activePlayer
    ? mediaService.playerKey(activePlayer) : ""
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

  function runAction(action) {
    if (!mediaService) return false
    return mediaService.runAction(action, false, playerKey)
  }

  function selectPlayer(key) {
    return mediaService ? mediaService.selectPlayer(key) : false
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
}
