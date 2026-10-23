import QtQuick

// Rounded side softkey from the Celestial Being consoles (TAR, TLD, HOR ...).
Rectangle {
  id: key

  property var hud
  property real u: 1
  property string code: ""
  property string caption: ""
  property bool lit: false

  radius: 6 * u
  color: lit ? Qt.alpha(hud.cyan, 0.30) : Qt.alpha(hud.panel, 0.55)
  border.width: Math.max(1, 1.4 * u)
  border.color: lit ? hud.cyanBright : Qt.alpha(hud.cyan, 0.45)
  Behavior on color { ColorAnimation { duration: 250 } }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 5 * key.u
    text: key.code
    font.family: "Michroma"
    font.pixelSize: 12 * key.u
    color: key.lit ? key.hud.textBright : key.hud.cyan
  }

  // Captions shrink to fit inside the key with padding, so long names
  // (PTOLEMAIOS, MOBILE SUIT) never touch the border.
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4 * key.u
    width: key.width - 10 * key.u
    horizontalAlignment: Text.AlignHCenter
    fontSizeMode: Text.HorizontalFit
    minimumPixelSize: 4
    text: key.caption
    font.family: "Michroma"
    font.pixelSize: 6.3 * key.u
    color: Qt.alpha(key.hud.cyan, 0.7)
  }
}
