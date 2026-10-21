"""Render the real player and appearance pages with sample metadata."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from bar import QML, REPO, STUBS


def main():
    runner = shutil.which("qml", path="/usr/lib/qt6/bin:" + os.environ.get("PATH", ""))
    with tempfile.TemporaryDirectory(prefix="media-controls-preview-") as directory:
        root = Path(directory)
        for relative, source in STUBS.items():
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(source)
        (root / "plugin").mkdir()
        shutil.copyfile(REPO / "BarWidget.qml", root / "plugin" / "BarWidget.qml")
        shutil.copytree(REPO / "qml", root / "plugin" / "qml")
        (root / "plugin" / "assets").symlink_to(REPO / "assets", target_is_directory=True)
        (root / "cover.svg").write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">
<defs><linearGradient id="ground" x2="0" y2="1"><stop stop-color="#19231f"/><stop offset="1" stop-color="#696c49"/></linearGradient></defs>
<rect width="400" height="400" fill="url(#ground)"/>
<circle cx="200" cy="190" r="128" fill="#d8d8bc"/><circle cx="200" cy="190" r="55" fill="#18201c"/>
<circle cx="200" cy="190" r="7" fill="#d8d8bc"/>
<text x="200" y="360" fill="#e5dcc1" font-size="18" text-anchor="middle" font-family="monospace">MIDNIGHT SIGNALS</text>
</svg>''')

        scene = QML.split("  TestCase {", 1)[0]
        scene = scene.replace("import QtTest", "import QtQuick.Window")
        scene = scene.replace("Item {\n  width: 620\n  height: 480", '''Window {
  id: previewWindow
  visible: true
  color: "#090a09"
  width: 1032
  height: 680''', 1)
        scene = scene.replace('  QtObject {', '  Rectangle { anchors.fill: parent; color: "#090a09"; z: -100 }\n\n  QtObject {', 1)
        scene = scene.replace('property bool positionSupported: false', 'property bool positionSupported: true\n    property real position: 119')
        scene = scene.replace('title: "Intro"', 'title: "Midnight Signals"')
        scene = scene.replace('artist: "M83"', 'artist: "Media Controls"')
        scene = scene.replace('album: "Album"', 'album: "Omarchy Sessions"')
        scene = scene.replace('artUrl: ""', 'artUrl: Qt.resolvedUrl("cover.svg").toString()')
        scene = scene.replace('duration: 120', 'duration: 300')
        scene = scene.replace('property string lyrics: ""', 'property string lyrics: ' + json.dumps(
            'Under a midnight terminal glow\nSmall signals travel row by row\n'
            'A quiet pulse, a borrowed light\nKeeps the desktop warm tonight.\n\n'
            'Turn the dial and let it play\nThe side bar carries sound your way\n'
            'Local words and distant streams\nMeet inside the same machine.'
        ))
        scene = scene.replace('lyricsSource: ""', 'lyricsSource: "Local lyrics file"')
        scene = scene.replace('({status: "not-found"})', '({status: "ok"})')
        scene = scene.replace('id: widget\n', 'id: widget\n    x: 24\n    y: 24\n', 1)
        scene += '''
  Plugin.BarWidget {
    id: appearanceWidget
    x: 528
    y: 24
    bar: fakeBar
    settings: ({labelWidth: 240})
    width: implicitWidth
    height: implicitHeight
  }

  function panel(item) {
    if (item.currentPage !== undefined) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = panel(item.children[i])
      if (found) return found
    }
    return null
  }

  Timer {
    interval: 250
    running: true
    onTriggered: {
      widget.displayedPosition = 119
      widget.openNowPlaying()
      appearanceWidget.openAppearance()
      panel(widget).y = 56
      panel(appearanceWidget).y = 56
      capture.start()
    }
  }
  Timer {
    id: capture
    interval: 600
    onTriggered: previewWindow.contentItem.grabToImage(function(result) {
      if (!result.saveToFile(@OUTPUT@)) Qt.exit(1)
      else Qt.quit()
    })
  }
}
'''
        source = root / "preview.qml"
        source.write_text(scene.replace("@OUTPUT@", json.dumps(str(REPO / "preview.png"))))
        environment = dict(
            os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
            QT_QUICK_BACKEND="software", QML_DISABLE_DISK_CACHE="1",
            QT_LOGGING_RULES="*.debug=false",
        )
        result = subprocess.run(
            [runner, "-I", str(root / "imports"), str(source)], env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=20,
        )
        print(result.stdout, end="")
        if result.returncode:
            raise SystemExit(f"Preview render failed (exit {result.returncode})")
        print(REPO / "preview.png")


if __name__ == "__main__":
    main()
