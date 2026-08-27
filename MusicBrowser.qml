import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Qt.labs.folderlistmodel
import Quickshell
import qs.Commons
import "Model.js" as Model

FocusScope {
  id: root

  required property var service
  required property var bar
  required property var monument
  property string integrationMode: "auto"

  readonly property string musicRoot: service ? String(service.musicRoot || "") : ""
  readonly property string rootUrl: Model.pathToFileUrl(musicRoot)
  property string currentFolder: rootUrl
  readonly property bool atRoot: currentFolder === rootUrl
  readonly property bool codaRouteActive: integrationMode !== "off"
    && !!service && service.codaConnected
  readonly property bool busy: service && (service.launchState === "validating"
    || service.launchState === "launching" || service.launchState === "waiting")
  implicitWidth: 480
  implicitHeight: 560

  signal rootEscape()
  signal transmissionRequested()

  function currentPath() {
    return Model.fileUrlToPath(currentFolder)
  }

  function routeLabel() {
    if (integrationMode === "off") return "GENERIC MPRIS / CODA DISABLED"
    if (service && service.codaConnected) return "CODA LINK ACTIVE"
    if (integrationMode === "prefer") {
      return service && service.codaInstalled
        ? "CODA PREFERRED / FALLBACK READY" : "CODA UNAVAILABLE / FALLBACK READY"
    }
    return "AUTO ROUTING / GENERIC FALLBACK READY"
  }

  function sourceRow(proxyRow) {
    if (proxyRow < 0 || proxyRow >= sortedModel.rowCount()) return -1
    var sourceIndex = sortedModel.mapToSource(sortedModel.index(proxyRow, 0))
    return sourceIndex.valid ? sourceIndex.row : -1
  }

  function entryAt(proxyRow) {
    var row = sourceRow(proxyRow)
    if (row < 0) return null
    return {
      path: String(folderModel.get(row, "filePath") || ""),
      url: String(folderModel.get(row, "fileUrl") || ""),
      name: String(folderModel.get(row, "fileName") || ""),
      folder: !!folderModel.get(row, "fileIsDir")
    }
  }

  function launchEntry(entry) {
    if (!entry || !service) return
    service.launchPath(entry.path, entry.folder ? "folder" : "file", integrationMode)
  }

  function activateSelection(recursiveFolder) {
    var entry = entryAt(browser.currentIndex)
    if (!entry) return
    if (entry.folder && !recursiveFolder) {
      currentFolder = entry.url
      browser.currentIndex = sortedModel.rowCount() > 0 ? 0 : -1
    } else launchEntry(entry)
  }

  function goUp() {
    if (atRoot || String(folderModel.parentFolder || "") === "") return false
    currentFolder = String(folderModel.parentFolder)
    browser.currentIndex = sortedModel.rowCount() > 0 ? 0 : -1
    return true
  }

  onRootUrlChanged: {
    currentFolder = rootUrl
    browser.currentIndex = sortedModel.rowCount() > 0 ? 0 : -1
  }

  onVisibleChanged: if (visible) archiveTabs.currentIndex = 1

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Up) {
      browser.decrementCurrentIndex()
      browser.positionViewAtIndex(browser.currentIndex, ListView.Contain)
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      browser.incrementCurrentIndex()
      browser.positionViewAtIndex(browser.currentIndex, ListView.Contain)
      event.accepted = true
    } else if (event.key === Qt.Key_Home) {
      browser.currentIndex = sortedModel.rowCount() > 0 ? 0 : -1
      browser.positionViewAtBeginning()
      event.accepted = true
    } else if (event.key === Qt.Key_End) {
      browser.currentIndex = sortedModel.rowCount() - 1
      browser.positionViewAtEnd()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activateSelection((event.modifiers & Qt.ControlModifier) !== 0)
      event.accepted = true
    } else if (event.key === Qt.Key_Backspace) {
      goUp()
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      if (!goUp()) rootEscape()
      event.accepted = true
    } else if (event.key === Qt.Key_T) {
      transmissionRequested()
      event.accepted = true
    }
  }

  FolderListModel {
    id: folderModel
    folder: root.currentFolder
    rootFolder: root.rootUrl
    nameFilters: ["*.flac", "*.mp3", "*.ogg", "*.oga", "*.opus", "*.m4a",
      "*.mp4", "*.aac", "*.alac", "*.wav", "*.wave"]
    caseSensitive: false
    sortField: FolderListModel.Unsorted
    showDirs: true
    showFiles: true
    showDirsFirst: false
    showDotAndDotDot: false
    showHidden: false
    showOnlyReadable: true
  }

  SortFilterProxyModel {
    id: sortedModel
    model: folderModel
    dynamicSortFilter: true
    sorters: [
      RoleSorter {
        roleName: "fileIsDir"
        sortOrder: Qt.DescendingOrder
        priority: 0
      },
      StringSorter {
        roleName: "fileName"
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 1
      }
    ]
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8

    MonumentSectionHeader {
      Layout.fillWidth: true
      monument: root.monument
      code: "A-01"
      title: "Archive access"
      status: root.musicRoot === "" ? "REFUSED" : root.busy ? "PROCESSING" : "AVAILABLE"
      statusColor: root.musicRoot === "" ? root.monument.authorityText
        : root.busy ? root.monument.warning : root.monument.alive
    }

    TabBar {
      id: archiveTabs
      Layout.fillWidth: true
      implicitHeight: 42
      spacing: 2
      currentIndex: 1
      background: Rectangle { color: root.monument.ground }
      onCurrentIndexChanged: if (currentIndex === 0) root.transmissionRequested()

      MonumentTabButton {
        width: (archiveTabs.width - archiveTabs.spacing) / 2
        monument: root.monument
        code: "01"
        text: "Transmission"
      }

      MonumentTabButton {
        width: (archiveTabs.width - archiveTabs.spacing) / 2
        monument: root.monument
        code: "02"
        text: "Archive"
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      MonumentButton {
        monument: root.monument
        code: "↑"
        text: "Up"
        enabled: !root.atRoot
        Accessible.name: "Parent folder"
        onClicked: root.goUp()
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: root.monument.controlHeight
        color: root.monument.field
        border.width: 1
        border.color: root.monument.ruleStrong

        Text {
          anchors.fill: parent
          anchors.leftMargin: 9
          anchors.rightMargin: 9
          text: root.currentPath() || (root.service ? root.service.musicRootMessage : "")
          color: root.monument.inkMuted
          font.family: root.monument.machineFont
          font.pixelSize: 10
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideMiddle
        }
      }

      MonumentButton {
        monument: root.monument
        code: "▶"
        text: "Folder"
        prominent: true
        enabled: root.musicRoot !== "" && !root.busy
        Accessible.name: "Play current folder recursively"
        onClicked: if (root.service)
          root.service.launchPath(root.currentPath(), "folder", root.integrationMode)
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 7

      Rectangle {
        Layout.preferredWidth: 5
        Layout.preferredHeight: 5
        color: root.codaRouteActive
          ? root.monument.alive : root.monument.inkFaint
      }

      Text {
        Layout.fillWidth: true
        text: "OUTPUT ROUTE // " + root.routeLabel()
        color: root.codaRouteActive
          ? root.monument.alive : root.monument.inkFaint
        font.family: root.monument.machineFont
        font.pixelSize: 9
        font.letterSpacing: 0.6
        elide: Text.ElideRight
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: launchText.implicitHeight + 16
      visible: root.service && root.service.launchMessage !== ""
      color: root.service && root.service.launchState === "error"
        ? root.monument.errorField : root.monument.field
      border.width: 1
      border.color: root.service && root.service.launchState === "error"
        ? root.monument.authorityBright
        : root.service && root.service.launchState === "success"
          ? root.monument.alive : root.monument.ruleStrong

      Text {
        id: launchText
        anchors.fill: parent
        anchors.margins: 8
        text: root.service ? root.service.launchMessage : ""
        color: root.service && root.service.launchState === "error"
          ? root.monument.authorityText : root.monument.ink
        font.family: root.monument.machineFont
        font.pixelSize: 10
        font.letterSpacing: 0.35
        wrapMode: Text.Wrap
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 300

      Column {
        anchors.centerIn: parent
        width: Math.min(310, parent.width - 40)
        spacing: 12
        visible: root.musicRoot === "" || sortedModel.rowCount() === 0

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 52
          height: 52
          color: root.monument.field
          border.width: 1
          border.color: root.monument.ruleStrong

          Text {
            anchors.centerIn: parent
            text: "□"
            color: root.monument.inkFaint
            font.family: root.monument.machineFont
            font.pixelSize: 25
          }
        }

        Text {
          width: parent.width
          text: root.musicRoot === ""
            ? "ARCHIVE ROOT IS NOT AVAILABLE"
            : "NO RECORD EXISTS IN THIS DIRECTORY"
          color: root.monument.ink
          font.family: root.monument.machineFont
          font.pixelSize: 11
          font.letterSpacing: 0.9
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }

        Text {
          width: parent.width
          text: root.musicRoot === ""
            ? (root.service ? root.service.musicRootMessage : "Configure a readable Music folder.")
            : "Return to the preceding directory or choose another archive root."
          color: root.monument.inkMuted
          font.family: root.monument.archiveFont
          font.pixelSize: 13
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }
      }

      ListView {
        id: browser
        anchors.fill: parent
        visible: root.musicRoot !== "" && sortedModel.rowCount() > 0
        model: sortedModel
        clip: true
        reuseItems: true
        currentIndex: sortedModel.rowCount() > 0 ? 0 : -1
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: if (count > 0 && currentIndex < 0) currentIndex = 0
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Rectangle {
          id: delegateRoot
          required property int index
          required property string fileName
          required property string filePath
          required property url fileUrl
          required property bool fileIsDir
          width: Math.max(0, ListView.view.width - 10)
          height: 56
          color: ListView.isCurrentItem ? root.monument.selection
            : rowHover.containsMouse ? root.monument.raised : root.monument.ground
          Accessible.role: Accessible.Button
          Accessible.name: (fileIsDir ? "Open directory " : "Play ") + fileName
          Accessible.onPressAction: {
            browser.currentIndex = delegateRoot.index
            root.activateSelection(false)
          }

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: ListView.isCurrentItem ? 4 : 1
            color: ListView.isCurrentItem ? root.monument.selectionMark : root.monument.rule
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.monument.rule
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 7
            spacing: 9

            Text {
              Layout.preferredWidth: 28
              text: root.monument.serial(delegateRoot.index + 1, 3)
              color: ListView.isCurrentItem
                ? root.monument.selectionMark : root.monument.inkFaint
              font.family: root.monument.machineFont
              font.pixelSize: 10
              horizontalAlignment: Text.AlignRight
            }

            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              color: root.monument.field
              border.width: 1
              border.color: root.monument.ruleStrong
              clip: true

              Text {
                anchors.centerIn: parent
                text: delegateRoot.fileIsDir ? "□" : "♪"
                color: delegateRoot.fileIsDir
                  ? root.monument.warning : root.monument.distance
                font.family: root.monument.machineFont
                font.pixelSize: 17
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: delegateRoot.fileName
                color: root.monument.ink
                font.family: delegateRoot.fileIsDir
                  ? root.monument.machineFont : root.monument.archiveFont
                font.pixelSize: delegateRoot.fileIsDir ? 11 : 13
                font.weight: delegateRoot.fileIsDir ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }

              Text {
                text: delegateRoot.fileIsDir
                  ? "DIRECTORY / RECURSIVE ACCESS" : "AUDIO RECORD"
                color: root.monument.inkFaint
                font.family: root.monument.machineFont
                font.pixelSize: 9
                font.letterSpacing: 0.65
              }
            }

            MonumentButton {
              monument: root.monument
              compact: true
              code: "▶"
              text: "Play"
              enabled: !root.busy
              Accessible.name: "Play " + delegateRoot.fileName
              onClicked: root.launchEntry({
                path: delegateRoot.filePath,
                url: String(delegateRoot.fileUrl),
                name: delegateRoot.fileName,
                folder: delegateRoot.fileIsDir
              })
            }
          }

          MouseArea {
            id: rowHover
            anchors.fill: parent
            anchors.rightMargin: Style.space(68)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: browser.currentIndex = delegateRoot.index
            onDoubleClicked: {
              browser.currentIndex = delegateRoot.index
              root.activateSelection(false)
            }
          }
        }
      }
    }
  }
}
