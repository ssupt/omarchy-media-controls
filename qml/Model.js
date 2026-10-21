function textValue(value) {
  if (value === undefined || value === null) return ""
  if (Array.isArray(value)) return value.map(textValue).filter(Boolean).join(", ")
  return String(value).trim()
}

function booleanValue(value, fallback) {
  if (value === undefined || value === null || value === "") return !!fallback
  if (typeof value === "boolean") return value
  var normalized = String(value).trim().toLowerCase()
  if (normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on")
    return true
  if (normalized === "false" || normalized === "0" || normalized === "no" || normalized === "off")
    return false
  return !!fallback
}

function toccataIntegrationMode(value) {
  var mode = textValue(value).toLowerCase()
  return mode === "off" || mode === "prefer" ? mode : "auto"
}

function metadataText(metadata, key) {
  if (!metadata || typeof metadata !== "object") return ""
  return textValue(metadata[key])
}

function durationSeconds(value) {
  var duration = Number(value || 0)
  if (!isFinite(duration) || duration <= 0) return 0
  return Math.max(0, duration)
}

function formatDuration(value) {
  var total = Math.floor(durationSeconds(value))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var seconds = total % 60
  var secondText = seconds < 10 ? "0" + seconds : String(seconds)
  if (hours > 0) {
    var minuteText = minutes < 10 ? "0" + minutes : String(minutes)
    return hours + ":" + minuteText + ":" + secondText
  }
  return minutes + ":" + secondText
}

function normalizeLyrics(value) {
  return textValue(value).replace(/\r\n?/g, "\n").replace(/^\s+|\s+$/g, "")
}

function plainLyricsFromSynced(value) {
  var lines = normalizeLyrics(value).split("\n")
  var plain = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (/^\s*\[(ar|al|ti|by|offset|re|ve|length):/i.test(line)) continue
    line = line.replace(/^\s*(\[[0-9]{1,3}:[0-9]{2}(?:[.:][0-9]{1,3})?\])+\s*/, "")
    plain.push(line.replace(/<[^>]+>/g, ""))
  }
  return normalizeLyrics(plain.join("\n"))
}

function emptyLyricsResponse() {
  return {
    status: "idle",
    lyrics: "",
    syncedLyrics: "",
    source: "",
    message: ""
  }
}

function parseLyricsResponse(raw) {
  var parsed
  try {
    parsed = JSON.parse(String(raw || "{}"))
  } catch (e) {
    return {
      status: "error",
      lyrics: "",
      syncedLyrics: "",
      source: "",
      message: "The lyrics helper returned an invalid response."
    }
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) parsed = {}

  var synced = normalizeLyrics(parsed.syncedLyrics)
  var lyrics = normalizeLyrics(parsed.lyrics || parsed.plainLyrics)
  if (!lyrics && synced) lyrics = plainLyricsFromSynced(synced)
  var status = textValue(parsed.status)
  if (status !== "ok" && status !== "not-found" && status !== "error")
    status = lyrics ? "ok" : "not-found"

  return {
    status: status,
    lyrics: lyrics,
    syncedLyrics: synced,
    source: textValue(parsed.source),
    message: textValue(parsed.message)
  }
}

function trackSignature(player) {
  if (!player) return ""
  var metadata = player.metadata || {}
  var uniqueId = player.uniqueId === undefined || player.uniqueId === null
    ? "" : player.uniqueId
  var duration = player.lengthSupported === false
    ? "" : durationSeconds(player.length)
  return [
    player.dbusName || player.desktopEntry || player.identity || "",
    uniqueId,
    player.trackTitle || "",
    player.trackArtist || "",
    player.trackAlbum || "",
    duration,
    metadataText(metadata, "xesam:url")
  ].join("\u001f")
}

function playerKey(player) {
  return player ? String(player.dbusName || player.desktopEntry || player.identity || "") : ""
}

function isProxyPlayer(player) {
  if (!player) return false
  var dbusName = String(player.dbusName || "").toLowerCase()
  var desktopEntry = String(player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld"
}

function hasPlayerMetadata(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum
    || player.identity || player.desktopEntry))
}

function hasTrackMetadata(player) {
  return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum
    || player.trackArtUrl))
}

function orderedPlayers(players, preferredKey) {
  var ordered = []
  var values = players || []
  for (var i = 0; i < values.length; i++) {
    if (hasPlayerMetadata(values[i])) ordered.push(values[i])
  }
  ordered.sort(function(left, right) {
    var leftPreferred = playerKey(left) === preferredKey
    var rightPreferred = playerKey(right) === preferredKey
    if (!!left.isPlaying !== !!right.isPlaying) return left.isPlaying ? -1 : 1
    if (leftPreferred !== rightPreferred) return leftPreferred ? -1 : 1
    if (isProxyPlayer(left) !== isProxyPlayer(right)) return isProxyPlayer(left) ? 1 : -1
    var leftLabel = String(left.trackTitle || left.identity || left.desktopEntry || "")
    var rightLabel = String(right.trackTitle || right.identity || right.desktopEntry || "")
    return leftLabel.localeCompare(rightLabel)
  })
  return ordered
}

function selectActivePlayer(players, preferredKey) {
  var values = players || []
  var preferred = null
  for (var i = 0; i < values.length; i++) {
    if (playerKey(values[i]) === preferredKey) {
      preferred = values[i]
      break
    }
  }
  if (hasPlayerMetadata(preferred) && preferred.isPlaying) return preferred

  var playingProxy = null
  var trackPlayer = null
  var trackProxy = null
  var fallbackProxy = null
  var fallback = null
  for (var j = 0; j < values.length; j++) {
    var player = values[j]
    if (!hasPlayerMetadata(player)) continue
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
  return playingProxy || (hasPlayerMetadata(preferred) ? preferred : null)
    || trackPlayer || trackProxy || fallback || fallbackProxy
}

function nowPlayingLabel(title, artist) {
  var cleanTitle = textValue(title)
  var cleanArtist = textValue(artist)
  if (cleanTitle && cleanArtist) return cleanTitle + "  ·  " + cleanArtist
  return cleanTitle || cleanArtist || "Nothing playing"
}

function pathToFileUrl(path) {
  var value = textValue(path)
  if (value === "") return ""
  var parts = value.split("/")
  for (var i = 0; i < parts.length; i++) parts[i] = encodeURIComponent(parts[i])
  return "file://" + parts.join("/")
}

function fileUrlToPath(url) {
  var value = String(url || "")
  var match = /^file:(?:\/\/([^\/?#]*))?([^?#]*)/i.exec(value)
  if (!match || (match[1] && match[1].toLowerCase() !== "localhost")) return ""
  try {
    var path = decodeURIComponent(match[2])
    return path.indexOf("/") === 0 && path.indexOf("\u0000") === -1 ? path : ""
  }
  catch (error) { return "" }
}

function parseHelperResponse(value) {
  try {
    var payload = JSON.parse(String(value || ""))
    if (!payload || (payload.status !== "accepted" && payload.status !== "error"))
      throw new Error("invalid status")
    return payload
  } catch (error) {
    return { status: "error", backend: "", expectsMpris: false,
      message: "The music launcher returned an invalid response." }
  }
}

function isVerticalPosition(position) {
  return position === "left" || position === "right"
}

function lyricsSourceLabel(source) {
  var value = textValue(source)
  if (!value) return ""
  if (value === "mpris") return "From player metadata"
  if (value === "embedded") return "Embedded in audio file"
  if (value === "sidecar") return "Local lyrics file"
  if (value === "lrclib") return "LRCLIB"
  if (value === "lrclib-cache") return "LRCLIB · cached"
  return value
}

if (typeof module !== "undefined") {
  module.exports = {
    textValue: textValue,
    booleanValue: booleanValue,
    toccataIntegrationMode: toccataIntegrationMode,
    metadataText: metadataText,
    durationSeconds: durationSeconds,
    formatDuration: formatDuration,
    normalizeLyrics: normalizeLyrics,
    plainLyricsFromSynced: plainLyricsFromSynced,
    emptyLyricsResponse: emptyLyricsResponse,
    parseLyricsResponse: parseLyricsResponse,
    trackSignature: trackSignature,
    playerKey: playerKey,
    isProxyPlayer: isProxyPlayer,
    hasPlayerMetadata: hasPlayerMetadata,
    hasTrackMetadata: hasTrackMetadata,
    orderedPlayers: orderedPlayers,
    selectActivePlayer: selectActivePlayer,
    nowPlayingLabel: nowPlayingLabel,
    isVerticalPosition: isVerticalPosition,
    lyricsSourceLabel: lyricsSourceLabel,
    pathToFileUrl: pathToFileUrl,
    fileUrlToPath: fileUrlToPath,
    parseHelperResponse: parseHelperResponse
  }
}
