import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import "../style"

KeyboardPanel {
  id: root
  required property var controller
  property var controlsService: null
  property bool requestedOpen: false
  property bool browserVisible: false
  property bool settingsVisible: false
  readonly property int currentPage: settingsVisible ? 2 : browserVisible ? 1 : 0

  signal closeRequested()
  signal browserRequested()
  signal nowPlayingRequested()

  owner: root
  open: requestedOpen
  padding: 0
  borderSpec: Border.none()
  focusTarget: settingsVisible ? appearance : browserVisible ? musicBrowser : nowPlaying
  contentWidth: root.fittedContentWidth(Style.space(480))
  contentHeight: root.fittedContentHeight(
    (settingsVisible ? appearance.implicitHeight : browserVisible ? musicBrowser.implicitHeight
      : nowPlaying.implicitHeight) + 76, Style.space(640))

  function close() { closeRequested() }
  function resetLyricsScroll() { nowPlaying.resetLyricsScroll() }

  function selectPage(index) {
    settingsVisible = index === 2
    if (index === 0) {
      browserVisible = false
      nowPlayingRequested()
    } else if (index === 1) {
      browserVisible = true
      browserRequested()
    }
  }

  function focusCurrentPage() {
    if (!root.open) return
    if (settingsVisible) appearance.forceActiveFocus()
    else if (browserVisible) musicBrowser.forceActiveFocus()
    else {
      resetLyricsScroll()
      controller.updatePosition()
      nowPlaying.forceActiveFocus()
      if (controlsService) controlsService.requestLyrics(false)
    }
  }

  onOpenChanged: if (open) Qt.callLater(focusCurrentPage)
  onBrowserVisibleChanged: if (open) Qt.callLater(focusCurrentPage)
  onSettingsVisibleChanged: if (open) Qt.callLater(focusCurrentPage)

  Rectangle {
    anchors.fill: parent
    color: monument.ground
    border.width: 1
    border.color: monument.ruleStrong
    clip: true

    Connections {
      target: root.controlsService
      function onPlaybackStarted() { root.selectPage(0) }
    }

    MonumentStyle { id: monument }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 13
      spacing: 8

      TabBar {
        id: tabs
        Layout.fillWidth: true
        implicitHeight: 42
        spacing: 2
        currentIndex: root.currentPage
        background: Rectangle { color: monument.ground }
        onCurrentIndexChanged: if (currentIndex !== root.currentPage) root.selectPage(currentIndex)

        MonumentTabButton {
          width: (tabs.width - 2 * tabs.spacing) / 3
          monument: monument
          code: "01"
          text: "Player"
        }
        MonumentTabButton {
          width: (tabs.width - 2 * tabs.spacing) / 3
          monument: monument
          code: "02"
          text: "Archive"
        }
        MonumentTabButton {
          width: (tabs.width - 2 * tabs.spacing) / 3
          monument: monument
          code: "03"
          text: "Appearance"
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NowPlayingView {
          id: nowPlaying
          anchors.fill: parent
          visible: root.currentPage === 0
          controller: root.controller
          controlsService: root.controlsService
          monument: monument
          onBrowserRequested: root.selectPage(1)
          onCloseRequested: root.closeRequested()
        }
        MusicBrowser {
          id: musicBrowser
          anchors.fill: parent
          visible: root.currentPage === 1
          service: root.controlsService
          bar: root.bar
          monument: monument
          onTransmissionRequested: root.selectPage(0)
          onRootEscape: {
            if (root.controller.showingMedia) root.selectPage(0)
            else root.closeRequested()
          }
        }
        AppearanceView {
          id: appearance
          anchors.fill: parent
          visible: root.currentPage === 2
          controller: root.controller
          monument: monument
          onCloseRequested: root.closeRequested()
        }
      }
    }

    MonumentVeil { anchors.fill: parent; z: 1000 }
  }
}
