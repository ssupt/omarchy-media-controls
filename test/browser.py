"""Exercise the real music browser in Qt, including its construction bindings."""

import os
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile
from threading import Timer


REPO = Path(__file__).resolve().parent.parent
RUNNER = shutil.which("qmltestrunner", path="/usr/lib/qt6/bin:" + os.environ.get("PATH", ""))

QML = '''import QtQuick
import QtTest
import "plugin/qml/player" as Player
import "plugin/qml/style" as Visuals

Item {
  width: 600
  height: 650

  QtObject {
    id: service
    property string musicRoot: "@MUSIC_ROOT@"
    property string musicRootMessage: "Unavailable"
    property string launchState: "idle"
    property string launchMessage: ""
    property bool toccataConnected: false
    property bool toccataInstalled: false
    property var launched: null
    function launchPath(path, kind, mode) { launched = [path, kind, mode] }
  }

  Visuals.MonumentStyle { id: monument }
  Player.MusicBrowser {
    id: archive
    width: 480
    height: 560
    service: service
    bar: null
    monument: monument
  }

  TestCase {
    name: "MusicBrowser"
    when: windowShown

    function findList(item) {
      if (item.positionViewAtIndex !== undefined && item.model
          && (item.model.folder !== undefined || item.model.mapToSource !== undefined)) return item
      for (var i = 0; i < item.children.length; i++) {
        var found = findList(item.children[i])
        if (found) return found
      }
      return null
    }

    function test_browser() {
      var list = findList(archive)
      verify(list !== null)
      tryCompare(list, "count", 5)
      verify(list.visible)
      compare(list.currentIndex, 0)
      // QCollator's C locale does not support numeric collation.
      var files = Qt.locale().name === "C"
        ? ["10 song.mp3", "2 song.MP3", "Alpha.flac"]
        : ["2 song.MP3", "10 song.mp3", "Alpha.flac"]
      var expected = ["a empty", "Z folder"].concat(files)
      for (var i = 0; i < expected.length; i++) {
        compare(archive.entryAt(i).name, expected[i])
        compare(archive.entryAt(i).folder, i < 2)
      }
      compare(archive.entryAt(-1), null)
      compare(archive.entryAt(list.count), null)
      verify(!archive.goUp())

      archive.forceActiveFocus()
      keyClick(Qt.Key_End)
      compare(list.currentIndex, 4)
      keyClick(Qt.Key_Home)
      compare(list.currentIndex, 0)

      // The selected row must launch its own file after sorting.
      list.currentIndex = expected.indexOf("2 song.MP3")
      archive.activateSelection(false)
      compare(service.launched[0], service.musicRoot + "/2 song.MP3")
      compare(service.launched[1], "file")
      compare(service.launched[2], "auto")

      list.currentIndex = 1
      archive.activateSelection(true)
      compare(service.launched[0], service.musicRoot + "/Z folder")
      compare(service.launched[1], "folder")
      archive.activateSelection(false)
      tryCompare(list, "count", 1)
      compare(archive.entryAt(0).name, "inside.ogg")
      verify(archive.goUp())
      tryCompare(list, "count", 5)

      list.currentIndex = 0
      archive.activateSelection(false)
      tryCompare(list, "count", 0)
      tryCompare(list, "currentIndex", -1)
      verify(!list.visible)
      compare(archive.entryAt(0), null)
      archive.activateSelection(false)

      // Python creates and removes a file in response to these markers.
      console.warn("BROWSER_TEST_ADD_FILE")
      tryCompare(list, "count", 1)
      tryCompare(list, "currentIndex", 0)
      verify(list.visible)
      compare(archive.entryAt(0).name, "new.mp3")
      console.warn("BROWSER_TEST_REMOVE_FILE")
      tryCompare(list, "count", 0)
      verify(!list.visible)

      verify(archive.goUp())
      tryCompare(list, "count", 5)
      service.musicRoot = ""
      verify(!list.visible)
      service.musicRoot = "@MUSIC_ROOT@"
      tryCompare(list, "count", 5)
      verify(list.visible)
      verify(archive.atRoot)
    }
  }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="media-controls-browser-") as directory:
        root = Path(directory)
        (root / "plugin").symlink_to(REPO, target_is_directory=True)
        music = root / "Music"
        music.mkdir()
        for name in ["10 song.mp3", "2 song.MP3", "Alpha.flac", "ignore.txt", ".hidden.mp3"]:
            (music / name).touch()
        empty = music / "a empty"
        empty.mkdir()
        (music / "Z folder").mkdir()
        (music / "Z folder" / "inside.ogg").touch()
        (music / ".hidden folder").mkdir()

        # Only Style.space is used from the shell; keep desktop services out of the test.
        commons = root / "imports" / "qs" / "Commons"
        commons.mkdir(parents=True)
        (commons / "qmldir").write_text("module qs.Commons\nsingleton Style 1.0 Style.qml\n")
        (commons / "Style.qml").write_text(
            "pragma Singleton\nimport QtQml\nQtObject { function space(value) { return value } }\n"
        )
        source = root / "tst_browser.qml"
        source.write_text(QML.replace("@MUSIC_ROOT@", str(music)))
        environment = dict(
            os.environ,
            QT_QPA_PLATFORM="offscreen",
            QT_QPA_PLATFORMTHEME="",
            QT_QUICK_BACKEND="software",
            QML_DISABLE_DISK_CACHE="1",
            QT_LOGGING_RULES="*.debug=false",
        )
        # A regression should fail the test without saving private process memory.
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        with subprocess.Popen(
            [RUNNER, "-input", str(source), "-import", str(root / "imports"), "-o", "-,txt"],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        ) as process:
            timeout = Timer(30, process.kill)
            timeout.start()
            try:
                assert process.stdout is not None
                for line in process.stdout:
                    print(line, end="", flush=True)
                    if "BROWSER_TEST_ADD_FILE" in line:
                        (empty / "new.mp3").touch()
                    elif "BROWSER_TEST_REMOVE_FILE" in line:
                        (empty / "new.mp3").unlink()
                if process.wait(timeout=15) != 0:
                    raise SystemExit(f"FAIL: music browser runtime (exit {process.returncode})")
            finally:
                timeout.cancel()
                if process.poll() is None:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    main()
