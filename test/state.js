const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const Model = require('../qml/Model.js')

const serviceSource = fs.readFileSync(path.join(__dirname, '../qml/services/MediaService.qml'), 'utf8')
const playerSource = fs.readFileSync(path.join(__dirname, '../qml/player/PlayerWindow.qml'), 'utf8')

// Execute the production QML functions with player and timer stand-ins.
function service(overrides = {}) {
  const state = {
    Model, pausedPlayerKey: '', pausedPlayerWasPlaying: false,
    preferredPlayerKey: '', launchState: 'launching', launchKind: 'folder',
    launchTarget: '/Music/Album',
    launchHandled: false, launchBackend: '', launchMessage: '',
    hasMedia: true,
    trackSignature: 'track', lyricsTrackSignature: '', lyricsState: Model.emptyLyricsResponse(),
    embeddedLyrics: '', title: 'Song', artist: 'Artist', album: 'Album',
    duration: 120, trackUrl: 'file:///Music/Album/01.mp3',
    lyricsProc: { running: false },
    playbackStarted() {}, launchResultChanged() {},
    playerKey: Model.playerKey, hasTrackMetadata: Model.hasTrackMetadata,
    pluginScript: name => '/plugin/scripts/' + name,
    ...overrides
  }
  state.root = state
  vm.createContext(state)
  for (const name of ['pauseForHandoff', 'resumePausedPlayer', 'handleLaunchResponse',
                      'requestLyrics']) {
    const definition = serviceSource.match(new RegExp('  function ' + name + '\\([^)]*\\) \\{[\\s\\S]*?\\n  \\}'))
    assert.ok(definition, 'Missing production function: ' + name)
    vm.runInContext(definition[0], state)
  }
  return state
}

let pauses = 0
let plays = 0
const previous = {
  dbusName: 'org.mpris.MediaPlayer2.previous', isPlaying: true,
  canPause: false, canTogglePlaying: false, canPlay: true,
  pause() { pauses++ }, play() { plays++ }
}
const handoff = service({ activePlayer: previous, playerForKey: () => previous })
handoff.pauseForHandoff()
handoff.resumePausedPlayer()
assert.equal(plays, 0, 'An unpaused player must not be restarted')
previous.canPause = true
handoff.pauseForHandoff()
assert.equal(pauses, 1)
handoff.handleLaunchResponse({ status: 'accepted', backend: 'xdg-open', expectsMpris: false })
assert.equal(plays, 1, 'Opening a folder in a file manager must restore playback')

let successes = 0
const local = service({ playbackStarted() { successes++ } })
local.handleLaunchResponse({ status: 'accepted', backend: 'mpv', expectsMpris: false })
assert.equal(local.launchState, 'success')
assert.equal(successes, 1, 'Accepted local playback must open the player view')
local.handleLaunchResponse({ status: 'accepted', backend: 'mpv' })
assert.equal(successes, 1, 'The helper result must only be processed once')
const failed = service({
  pausedPlayerKey: previous.dbusName, pausedPlayerWasPlaying: true,
  playerForKey: () => previous
})
failed.handleLaunchResponse({ status: 'error', backend: 'xdg-open', message: 'Unavailable' })
assert.equal(failed.launchState, 'error')
assert.equal(plays, 2, 'A failed launch must resume the previous player')

let starts = 0
let running = false
const lyricsProc = {
  get running() { return running },
  set running(value) { running = value; if (value) starts++ }
}
const lyrics = service({ lyricsProc })
lyrics.requestLyrics(false)
lyrics.requestLyrics(false)
assert.equal(starts, 1, 'Opening the popup must reuse a pending lyrics lookup')
lyrics.requestLyrics(true)
assert.equal(starts, 2, 'An explicit retry must restart the helper')
assert.ok(lyricsProc.command.includes('--refresh'), 'Retry must bypass cached missing lyrics')

let positionUpdates = 0
let lyricRequests = 0
let appearanceFocus = 0
const view = {
  open: true, browserVisible: false, settingsVisible: false, resetLyricsScroll() {},
  controller: { updatePosition() { positionUpdates++ } },
  controlsService: { requestLyrics() { lyricRequests++ } },
  nowPlaying: { forceActiveFocus() {} },
  musicBrowser: { forceActiveFocus() {} },
  appearance: { forceActiveFocus() { appearanceFocus++ } }
}
view.root = view
vm.createContext(view)
const focusFunction = playerSource.match(/  function focusCurrentPage\(\) \{[\s\S]*?\n  \}/)
assert.ok(focusFunction, 'Missing production page-focus handler')
vm.runInContext(focusFunction[0], view)
view.focusCurrentPage()
assert.equal(positionUpdates, 1)
assert.equal(lyricRequests, 1)
view.settingsVisible = true
view.focusCurrentPage()
assert.equal(appearanceFocus, 1)
assert.equal(lyricRequests, 1, 'Opening appearance must not fetch lyrics')
view.open = false
view.focusCurrentPage()
assert.equal(lyricRequests, 1, 'A queued view update must not fetch lyrics after closing')

console.log('PASS: playback handoff, pending lyrics, and popup state')
