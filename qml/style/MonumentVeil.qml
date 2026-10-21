import QtQuick

Image {
  source: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='4' height='4'%3E%3Cpath d='M0 1.5H4' stroke='%23ddd4b9' stroke-opacity='.10'/%3E%3C/svg%3E"
  sourceSize: Qt.size(4, 4)
  fillMode: Image.Tile
  smooth: false
  cache: true
  opacity: 0.10
  enabled: false
}
