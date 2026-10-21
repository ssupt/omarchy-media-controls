"""Check the production bar's geometry and metadata transitions in headless Qt."""

import os
from pathlib import Path
import resource
import shutil
import struct
import subprocess
import tempfile
import zlib


REPO = Path(__file__).resolve().parent.parent
RUNNER = shutil.which("qmltestrunner", path="/usr/lib/qt6/bin:" + os.environ.get("PATH", ""))

# Only the desktop host is replaced. The bar, popup, settings, and shared track
# components use production QML with real Qt controls, images, and timers.
STUBS = {
    "imports/qs/Commons/qmldir": "module qs.Commons\nsingleton Style 1.0 Style.qml\nsingleton Color 1.0 Color.qml\nsingleton Border 1.0 Border.qml\n",
    "imports/qs/Commons/Style.qml": '''pragma Singleton
import QtQml
QtObject {
  readonly property var font: ({family: "sans-serif", body: 14, bodySmall: 12, caption: 11, title: 18})
  readonly property var bar: ({sizeHorizontal: 32})
  property bool reduceMotion: false
  function space(value) { return value }
  function duration(value) { return reduceMotion ? 0 : value }
  function normalFillFor(foreground, accent) { return "transparent" }
}
''',
    "imports/qs/Commons/Color.qml": '''pragma Singleton
import QtQuick
QtObject { readonly property color foreground: "#eee"; readonly property color accent: "#c88" }
''',
    "imports/qs/Commons/Border.qml": '''pragma Singleton
import QtQml
QtObject {
  function controlSpec(kind, foreground, accent) { return ({}) }
  function none() { return ({}) }
}
''',
    "imports/qs/Ui/qmldir": "module qs.Ui\nBarWidget 1.0 BarWidget.qml\nBorderSurface 1.0 BorderSurface.qml\nButton 1.0 Button.qml\nKeyboardPanel 1.0 KeyboardPanel.qml\n",
    "imports/qs/Ui/BarWidget.qml": '''import QtQuick
Item {
  property QtObject bar: null
  property string moduleName: ""
  property var settings: ({})
  readonly property int barSize: bar ? bar.barSize : 32
  function setting(name, fallback) {
    var value = settings[name]
    return value === undefined || value === null ? fallback : value
  }
}
''',
    "imports/qs/Ui/BorderSurface.qml": '''import QtQuick
Rectangle { property var borderSpec: ({}) }
''',
    "imports/qs/Ui/Button.qml": '''import QtQuick
Item {
  id: button
  signal clicked()
  property color foreground: "#eee"
  property string fontFamily: "sans-serif"
  property string iconText: ""
  property real iconSize: 14
  property real horizontalPadding: 4
  property real verticalPadding: 2
  implicitWidth: label.implicitWidth + horizontalPadding * 2
  implicitHeight: label.implicitHeight + verticalPadding * 2
  Text {
    id: label
    anchors.fill: parent
    text: button.iconText
    color: button.foreground
    font.family: button.fontFamily
    font.pixelSize: button.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  MouseArea { anchors.fill: parent; onClicked: button.clicked() }
}
''',
    "imports/qs/Ui/KeyboardPanel.qml": '''import QtQuick
Item {
  id: panelHost
  default property alias contentItem: contentHolder.children
  property Item holder: Item {
    id: contentHolder
    parent: panelHost
    anchors.fill: parent
  }
  property var anchorItem
  property var bar
  property var owner
  property bool open: false
  property real padding: 0
  property var borderSpec
  property var focusTarget
  property real contentWidth: 480
  property real contentHeight: 640
  width: contentWidth
  height: contentHeight
  visible: open
  function fittedContentWidth(value) { return value }
  function fittedContentHeight(value, limit) { return Math.min(value, limit) }
}
''',
}

QML = '''import QtQuick
import QtTest
import qs.Commons
import "plugin" as Plugin
import "plugin/qml/components" as Components

Item {
  width: 620
  height: 480

  QtObject {
    id: player
    property bool isPlaying: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    property bool canTogglePlaying: true
    property bool canPlay: true
    property bool canPause: true
    property bool positionSupported: false
    property bool canSeek: true
  }
  QtObject {
    id: service
    property var activePlayer: player
    property bool hasMedia: true
    property string title: "Intro"
    property string artist: "M83"
    property string album: "Album"
    property string artUrl: ""
    property real duration: 120
    property string lyrics: ""
    property bool lyricsLoading: false
    property string lyricsSource: ""
    property string lyricsMessage: ""
    property var lyricsState: ({status: "not-found"})
    property string musicRoot: ""
    property string musicRootMessage: "Unavailable"
    property string launchState: "idle"
    property string launchMessage: ""
    property int lyricsRequests: 0
    property string lastAction: ""
    signal trackSignatureChanged()
    signal playbackStarted()
    function runAction(action) { lastAction = action; return true }
    function requestLyrics(force) { lyricsRequests++ }
    function launchPath(path, kind) {}
  }
  QtObject {
    id: fakeShell
    property int saveCount: 0
    property string savedId: ""
    property var savedSettings: ({})
    function serviceFor(id) { return service }
    function firstPartyServiceFor(id) { return null }
    function updateEntryInline(id, settings) {
      saveCount++
      savedId = id
      savedSettings = JSON.parse(JSON.stringify(settings))
      return true
    }
  }
  QtObject {
    id: fakeBar
    property QtObject shell: fakeShell
    property string position: "top"
    property int barSize: 32
    property color barForeground: "#eee"
    property color foreground: "#eee"
    property string fontFamily: "sans-serif"
    property string tooltipText: ""
    property int tooltipRequests: 0
    function showTooltip(owner, text) {
      tooltipRequests++
      tooltipText = text
    }
    function hideTooltip(owner) { tooltipText = "" }
    function registerClickTarget(item) {}
    function unregisterClickTarget(item) {}
  }
  Plugin.BarWidget {
    id: widget
    bar: fakeBar
    width: implicitWidth
    height: implicitHeight
  }
  Components.TrackPresentation {
    id: presentation
    gapDuration: 120
    transitionDuration: 0
  }

  TestCase {
    name: "MediaBar"
    when: windowShown

    SignalSpy {
      id: displayedChanges
      target: widget.presentation
      signalName: "displayedTrackChanged"
    }

    function find(item, predicate) {
      if (predicate(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var match = find(item.children[i], predicate)
        if (match) return match
      }
      return null
    }
    function nextButton() {
      return find(widget, item => item.visible && item.action === "next")
    }
    function hasTitle(text) {
      return !!find(widget, item => item.visible && item.text === text)
    }
    function init() {
      widget.close()
      service.hasMedia = true
      service.title = "Intro"
      service.artist = "M83"
      service.artUrl = ""
      service.activePlayer = player
      service.lastAction = ""
      service.duration = 120
      service.lyricsState = ({status: "not-found"})
      player.isPlaying = true
      fakeBar.position = "top"
      widget.settings = ({})
      fakeShell.saveCount = 0
      fakeBar.tooltipRequests = 0
      fakeBar.tooltipText = ""
      Style.reduceMotion = false
      tryCompare(widget, "showingMedia", true)
      tryVerify(() => hasTitle("Intro"))
      tryCompare(widget, "playing", true)
      mouseMove(widget, widget.width + 20, widget.height + 20)
      wait(100)
    }

    function test_appearance_controls() {
      widget.settings = ({customSetting: "preserved"})
      widget.openAppearance()
      var slider = findChild(widget, "barSizeSlider")
      verify(slider !== null)
      tryCompare(slider, "visible", true)
      var width = widget.implicitWidth
      slider.forceActiveFocus()
      keyClick(Qt.Key_Right)
      tryCompare(widget, "horizontalLabelWidth", 190)
      tryCompare(widget, "implicitWidth", width + 10)
      tryCompare(fakeShell, "saveCount", 1)
      compare(fakeShell.savedId, "ssupt.media-controls")
      compare(fakeShell.savedSettings.labelWidth, 190)
      compare(fakeShell.savedSettings.customSetting, "preserved")
      fakeBar.position = "left"
      tryCompare(slider, "value", 125)
      compare(slider.from, 72)
      compare(slider.to, 240)
      tryVerify(() => widget.implicitHeight > 125)
      wait(20)
      var height = widget.implicitHeight
      keyClick(Qt.Key_Right)
      tryCompare(widget, "verticalLabelLength", 126)
      tryCompare(widget, "implicitHeight", height + 1)
      tryCompare(fakeShell, "saveCount", 2)
      compare(fakeShell.savedSettings.labelWidth, 190)
      compare(fakeShell.savedSettings.verticalLabelLength, 126)
      fakeBar.position = "right"
      tryCompare(slider, "value", 126)
      fakeBar.position = "bottom"
      tryCompare(slider, "value", 190)
      compare(slider.from, 80)
      compare(slider.to, 320)
      compare(fakeShell.saveCount, 2, "Changing orientation must not save a slider adjustment")
      var spacing = findChild(widget, "barButtonSpacingSlider")
      verify(spacing !== null)
      compare(spacing.from, 0)
      compare(spacing.to, 8)
      spacing.forceActiveFocus()
      keyClick(Qt.Key_Right)
      tryCompare(widget, "buttonSpacing", 2)
      tryCompare(fakeShell, "saveCount", 3)
      compare(fakeShell.savedSettings.buttonSpacing, 2)
      compare(fakeShell.savedSettings.customSetting, "preserved")
      var toggle = findChild(widget, "showArchiveWhenIdle")
      toggle.forceActiveFocus()
      keyClick(Qt.Key_Space)
      tryCompare(widget, "showWhenIdle", false)
      tryCompare(fakeShell, "saveCount", 4)
      compare(fakeShell.savedSettings.showWhenIdle, false)
      widget.resetAppearance()
      tryCompare(widget, "horizontalLabelWidth", 180)
      tryCompare(fakeShell, "saveCount", 5)
      compare(fakeShell.savedSettings.verticalLabelLength, 125)
      compare(fakeShell.savedSettings.buttonSpacing, 1)
      compare(fakeShell.savedSettings.showWhenIdle, true)
      widget.close()
    }

    function test_hover_scroll() {
      service.title = "A complete title that is much wider than the bar label"
      tryCompare(widget.presentation, "displayedTitle", service.title)
      var title = findChild(widget, "barTitleScroll")
      var artist = findChild(widget, "barArtistScroll")
      verify(title !== null && artist !== null)
      verify(title.overflow > 1)
      var width = widget.implicitWidth
      var next = nextButton()
      var nextX = next.mapToItem(widget, 0, 0).x
      mouseMove(widget, 40, 8)
      tryCompare(widget, "trackHovered", true)
      verify(!title.scrolling, "A brief hover must keep the resting label")
      tryVerify(() => title.scrollOffset > 1, 1500)
      verify(!artist.scrolling, "Text that fits must stay still")
      compare(widget.implicitWidth, width)
      compare(next.mapToItem(widget, 0, 0).x, nextX)
      mouseMove(next, next.width / 2, next.height / 2)
      verify(title.scrolling, "Hovering the transport controls must keep the title scrolling")
      service.title = "Another full title while the pointer stays over the bar"
      tryCompare(widget.presentation, "displayedTitle", service.title)
      compare(title.scrollOffset, 0, "A new title must restart from its beginning")
      tryVerify(() => title.scrollOffset > 1, 1500)
      widget.openAppearance()
      tryCompare(widget, "trackHovered", false)
      compare(title.scrollOffset, 0)
      verify(!title.scrolling)
      widget.close()
      mouseMove(widget, 40, 8)
      tryVerify(() => title.scrollOffset > 1, 1500)
      mouseMove(widget, widget.width + 20, widget.height + 20)
      tryCompare(widget, "trackHovered", false)
      compare(title.scrollOffset, 0)
      verify(!title.scrolling)
      compare(fakeBar.tooltipText, "")
      compare(fakeBar.tooltipRequests, 0, "Hover must never request a tooltip box")
      for (var position of ["left", "right"]) {
        fakeBar.position = position
        tryVerify(() => widget.implicitHeight > 125)
        var side = findChild(widget, "barSideScroll")
        mouseMove(widget, 12, 60)
        tryVerify(() => side.scrollOffset > 1, 1500)
        Style.reduceMotion = true
        tryCompare(side, "scrollOffset", 0)
        verify(!side.scrolling)
        Style.reduceMotion = false
        mouseMove(widget, widget.width + 20, widget.height + 20)
      }
      fakeBar.position = "top"
      service.title = "Short"
      tryCompare(widget.presentation, "displayedTitle", "Short")
      mouseMove(widget, 40, 8)
      wait(500)
      verify(!title.scrolling)
      compare(title.scrollOffset, 0)
    }

    function test_button_spacing() {
      for (var position of ["top", "bottom", "left", "right"]) {
        fakeBar.position = position
        wait(20)
        var previous = find(widget, item => item.visible && item.action === "previous")
        var play = find(widget, item => item.visible && item.action === "playPause")
        var next = nextButton()
        verify(previous !== null && play !== null && next !== null)
        var vertical = position === "left" || position === "right"
        function gap(first, second) {
          var a = first.mapToItem(widget, 0, 0)
          var b = second.mapToItem(widget, 0, 0)
          return vertical ? b.y - a.y - first.height : b.x - a.x - first.width
        }
        for (var spacing of [0, 4, 8]) {
          widget.settings = ({buttonSpacing: spacing})
          tryCompare(widget, "buttonSpacing", spacing)
          tryVerify(() => gap(previous, play) === spacing && gap(play, next) === spacing)
          compare(play.width, previous.width)
          compare(next.width, previous.width)
        }
        widget.settings = ({buttonSpacing: 100})
        compare(widget.buttonSpacing, 8)
        widget.settings = ({buttonSpacing: "invalid"})
        compare(widget.buttonSpacing, 1)
      }
    }

    function test_panel_transitions() {
      widget.openNowPlaying()
      var barDetails = findChild(widget, "barTrackDetails")
      var panelDetails = findChild(widget, "playerTrackDetails")
      verify(barDetails !== null && panelDetails !== null)
      tryCompare(panelDetails, "visible", true)
      var retry = findChild(widget, "lyricsRetryButton")
      verify(retry !== null)
      var retryY = retry.mapToItem(widget, 0, 0).y
      service.lyricsState = ({status: "idle"})
      compare(retry.opacity, 0)
      compare(widget.lyricsDisplayText(), "Finding the words…")
      compare(retry.mapToItem(widget, 0, 0).y, retryY)
      wait(200)
      displayedChanges.clear()
      service.hasMedia = false
      service.activePlayer = null
      service.title = ""
      service.artist = ""
      service.duration = 0
      wait(30)
      verify(widget.playing)
      verify(widget.canPlayPause)
      compare(widget.duration, 120)
      compare(panelDetails.opacity, 1)
      service.hasMedia = true
      service.activePlayer = player
      service.title = "A new record"
      player.isPlaying = false
      wait(25)
      compare(widget.presentation.displayedTitle, "Intro")
      verify(widget.playing)
      service.artist = "A new artist"
      service.album = "A new album"
      service.duration = 180
      player.isPlaying = true
      tryCompare(widget.presentation, "displayedTitle", "A new record")
      compare(displayedChanges.count, 1, "A staggered track update must publish one snapshot")
      verify(widget.playing)
      verify(widget.canPlayPause)
      compare(widget.duration, 180)
      wait(20)
      compare(panelDetails.opacity, barDetails.opacity)
      verify(panelDetails.opacity < 1)
      verify(!!find(panelDetails, item => item.text === "A new record"))
      verify(!!find(panelDetails, item => item.text === "A new artist"))
      verify(!!find(panelDetails, item => item.text === "A new album"))
      tryCompare(panelDetails, "opacity", 1)
      service.lyricsState = ({status: "loading"})
      compare(retry.opacity, 0)
      compare(retry.mapToItem(widget, 0, 0).y, retryY)
      service.lyricsState = ({status: "not-found"})
      compare(retry.opacity, 1)
      compare(retry.mapToItem(widget, 0, 0).y, retryY)
      service.lyricsState = ({status: "ok"})
      compare(retry.opacity, 0)
      compare(retry.mapToItem(widget, 0, 0).y, retryY)
      player.isPlaying = false
      tryCompare(widget, "playing", false, 500)
      var next = find(widget, item => item.visible && item.text === "Next")
      verify(next !== null)
      mouseClick(next)
      compare(service.lastAction, "next")
      widget.close()
    }

    function test_horizontal_geometry() {
      var next = nextButton()
      verify(next !== null)
      var width = widget.implicitWidth
      var x = next.mapToItem(widget, 0, 0).x
      var titles = ["A", "Everything in Its Right Place", "Notturno in G-Flat Major: Intermezzo-Serenata"]
      for (var i = 0; i < titles.length; i++) {
        service.title = titles[i]
        service.artist = i === 0 ? "X" : "An artist with a very long name"
        tryVerify(() => hasTitle(service.title))
        compare(widget.implicitWidth, width)
        compare(next.mapToItem(widget, 0, 0).x, x)
        player.isPlaying = !player.isPlaying
        wait(1)
        compare(next.mapToItem(widget, 0, 0).x, x)
      }
      mouseClick(next)
      compare(service.lastAction, "next")
      widget.settings = ({labelWidth: 240})
      tryCompare(widget, "implicitWidth", width + 60)
      widget.settings = ({labelWidth: "invalid"})
      tryCompare(widget, "implicitWidth", width)
    }

    function test_metadata_gap() {
      var width = widget.implicitWidth
      var x = nextButton().mapToItem(widget, 0, 0).x
      service.hasMedia = false
      service.activePlayer = null
      service.title = ""
      service.artist = ""
      wait(100)
      verify(widget.showingMedia)
      verify(hasTitle("Intro"))
      compare(widget.implicitWidth, width)
      compare(nextButton().mapToItem(widget, 0, 0).x, x)
      service.title = "Next song"
      service.artist = "Next artist"
      service.activePlayer = player
      service.hasMedia = true
      tryVerify(() => hasTitle("Next song"))
      wait(180)
      verify(widget.showingMedia)
      compare(widget.implicitWidth, width)
      service.hasMedia = false
      tryCompare(widget, "showingMedia", false)
      verify(widget.visible)
      verify(widget.implicitWidth < width)
      widget.settings = ({showWhenIdle: false})
      verify(!widget.visible)
    }

    function test_vertical_geometry() {
      for (var position of ["left", "right"]) {
        fakeBar.position = position
        tryVerify(() => widget.implicitHeight > 125)
        wait(20)
        var height = widget.implicitHeight
        var next = nextButton()
        var y = next.mapToItem(widget, 0, 0).y
        service.title = "A much longer track title than before"
        service.artist = "Another artist"
        tryVerify(() => widget.label.includes(service.title))
        compare(widget.implicitWidth, fakeBar.barSize)
        compare(widget.implicitHeight, height)
        compare(next.mapToItem(widget, 0, 0).y, y)
        widget.settings = ({verticalLabelLength: 175})
        tryCompare(widget, "implicitHeight", height + 50)
        widget.settings = ({})
        tryCompare(widget, "implicitHeight", height)
      }
    }

    function test_artwork_and_motion() {
      var width = widget.implicitWidth
      var cover = find(widget, item => item.visible && item.hasArtwork !== undefined)
      verify(cover !== null)
      verify(!cover.hasArtwork)
      service.artUrl = Qt.resolvedUrl("cover.png").toString()
      tryCompare(cover, "hasArtwork", true)
      compare(widget.implicitWidth, width)
      service.artUrl = ""
      wait(140)
      verify(cover.hasArtwork, "A temporary empty artwork URL must retain the cover")
      service.artUrl = Qt.resolvedUrl("cover2.png").toString()
      tryCompare(cover, "displayedSource", service.artUrl)
      verify(cover.hasArtwork)
      service.artUrl = ""
      tryCompare(cover, "hasArtwork", false)
      compare(widget.implicitWidth, width)
      Style.reduceMotion = true
      compare(widget.transitionDuration, 0)
      presentation.available = true
      presentation.title = "First"
      presentation.artist = "Artist"
      tryCompare(presentation, "displayedTitle", "First")
      compare(presentation.contentOpacity, 1)
      presentation.title = "Second"
      tryCompare(presentation, "displayedTitle", "Second")
      compare(presentation.contentOpacity, 1)
      presentation.title = ""
      presentation.artist = ""
      wait(40)
      compare(presentation.displayedTitle, "Second")
      tryCompare(presentation, "displayedTitle", "")
      verify(presentation.showingMedia)
      presentation.available = false
      tryCompare(presentation, "showingMedia", false)
    }
  }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="media-controls-bar-") as directory:
        root = Path(directory)
        for relative, source in STUBS.items():
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(source)
        (root / "plugin").mkdir()
        shutil.copyfile(REPO / "BarWidget.qml", root / "plugin" / "BarWidget.qml")
        shutil.copytree(REPO / "qml", root / "plugin" / "qml")
        (root / "plugin" / "assets").symlink_to(REPO / "assets", target_is_directory=True)
        source = root / "tst_bar.qml"
        source.write_text(QML)

        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

        (root / "cover.png").write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x99\x55\x55\xff"))
            + chunk(b"IEND", b"")
        )
        shutil.copyfile(root / "cover.png", root / "cover2.png")
        environment = dict(
            os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
            QT_QUICK_BACKEND="software", QML_DISABLE_DISK_CACHE="1",
            QT_LOGGING_RULES="*.debug=false",
        )
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        result = subprocess.run(
            [RUNNER, "-input", str(source), "-import", str(root / "imports"), "-o", "-,txt"],
            env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", timeout=30,
        )
        print(result.stdout, end="")
        if result.returncode:
            raise SystemExit(f"FAIL: media bar runtime (exit {result.returncode})")


if __name__ == "__main__":
    main()
