const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const Model = require('../Model.js')

const serviceSource = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8')
const playerSource = fs.readFileSync(path.join(__dirname, '../PlayerWindow.qml'), 'utf8')

// Execute the production QML functions with player and timer stand-ins.
function service(overrides = {}) {
  const state = {
    Model, pausedPlayerKey: '', pausedPlayerWasPlaying: false,
    preferredPlayerKey: '', launchState: 'waiting', launchKind: 'folder',
    launchTarget: '/Music/Album', launchFirstTrack: '/Music/Album/01.mp3',
    launchHandled: false, launchBackend: '', launchMessage: '',
    toccataSignatureBeforeLaunch: '', hasMedia: true,
    trackSignature: 'track', lyricsTrackSignature: '', lyricsState: Model.emptyLyricsResponse(),
    embeddedLyrics: '', title: 'Song', artist: 'Artist', album: 'Album',
    duration: 120, trackUrl: 'file:///Music/Album/01.mp3',
    lyricsProc: { running: false },
    handoffTimeout: { stop() {}, restart() {} },
    toccataPoll: { stop() {}, start() {} },
    handoffSucceeded() {}, launchResultChanged() {},
    tryToccataHandoff() {},
    playerKey: Model.playerKey, hasTrackMetadata: Model.hasTrackMetadata,
    pluginScript: name => '/plugin/scripts/' + name,
    ...overrides
  }
  state.root = state
  vm.createContext(state)
  for (const name of ['pauseForHandoff', 'resumePausedPlayer', 'handleLaunchResponse',
                      'tryToccataHandoff', 'requestLyrics']) {
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

const player = {
  dbusName: 'org.mpris.MediaPlayer2.toccata', trackTitle: 'Song',
  isPlaying: false, metadata: { 'xesam:url': 'file://localhost/Music/Album/01.mp3' }
}
let successes = 0
const waiting = service({
  toccataPlayer: () => player,
  toccataSignatureBeforeLaunch: Model.trackSignature(player),
  handoffSucceeded() { successes++ }
})
assert.equal(waiting.tryToccataHandoff(), false, 'Paused metadata is not a playback handoff')
player.isPlaying = true
player.metadata['xesam:url'] = 'file:///Music/Other.mp3'
assert.equal(waiting.tryToccataHandoff(), false, 'Unrelated metadata must not complete a handoff')
player.metadata['xesam:url'] = 'file://localhost/Music/Album/01.mp3'
assert.equal(waiting.tryToccataHandoff(), true, 'Restarting the first song of a folder must complete')
assert.equal(successes, 1)
assert.equal(waiting.preferredPlayerKey, player.dbusName)
assert.equal(waiting.launchState, 'success')

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

const viewChange = playerSource.match(/onBrowserVisibleChanged: if \(open\) Qt\.callLater\(function\(\) \{([\s\S]*?)\n  \}\)/)
assert.ok(viewChange, 'Missing production view-change handler')
let positionUpdates = 0
let lyricRequests = 0
const view = {
  root: {
    open: true, browserVisible: false, resetLyricsScroll() {},
    controller: { updatePosition() { positionUpdates++ } },
    controlsService: { requestLyrics() { lyricRequests++ } }
  },
  transcriptTabs: { currentIndex: 1 },
  keyScope: { forceActiveFocus() {} },
  musicBrowser: { forceActiveFocus() {} }
}
const viewCallback = '(function() {' + viewChange[1] + '\n})()'
vm.runInNewContext(viewCallback, view)
assert.equal(positionUpdates, 1)
assert.equal(lyricRequests, 1)
assert.equal(view.transcriptTabs.currentIndex, 0)
view.root.open = false
vm.runInNewContext(viewCallback, view)
assert.equal(lyricRequests, 1, 'A queued view update must not fetch lyrics after closing')

console.log('PASS: playback handoff, pending lyrics, and popup state')
