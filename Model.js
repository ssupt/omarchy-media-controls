function textValue(value) {
  if (value === undefined || value === null) return ""
  if (Array.isArray(value)) return value.map(textValue).filter(Boolean).join(", ")
  return String(value).trim()
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

function nowPlayingLabel(title, artist) {
  var cleanTitle = textValue(title)
  var cleanArtist = textValue(artist)
  if (cleanTitle && cleanArtist) return cleanTitle + "  ·  " + cleanArtist
  return cleanTitle || cleanArtist || "Nothing playing"
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
    metadataText: metadataText,
    durationSeconds: durationSeconds,
    formatDuration: formatDuration,
    normalizeLyrics: normalizeLyrics,
    plainLyricsFromSynced: plainLyricsFromSynced,
    emptyLyricsResponse: emptyLyricsResponse,
    parseLyricsResponse: parseLyricsResponse,
    trackSignature: trackSignature,
    nowPlayingLabel: nowPlayingLabel,
    isVerticalPosition: isVerticalPosition,
    lyricsSourceLabel: lyricsSourceLabel
  }
}
