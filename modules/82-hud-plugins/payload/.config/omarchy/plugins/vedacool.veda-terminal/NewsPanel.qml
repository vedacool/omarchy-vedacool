import QtQuick

// Tech / science / space / security headlines in the VEDA terminal style. Shows seven at
// a time, turns the page every ~20s, and a highlight steps down the list.
// Clicking a headline opens it in the browser (this panel is the HUD's only
// clickable area).
Item {
  id: np

  // Cached as one texture: it only changes on page turns, highlight steps
  // and hover, not on every HUD animation frame.
  layer.enabled: true

  property var hud
  property real u: 1
  property int t: 0
  property var now: new Date()

  readonly property var items: hud.news
  readonly property int perPage: 7
  readonly property int pages: Math.max(1, Math.ceil(items.length / perPage))
  readonly property int page: Math.floor(t / 200) % pages
  readonly property int lit: Math.floor(t / 40) % Math.max(1, pageItems.length)
  readonly property var pageItems: items.slice(page * perPage, page * perPage + perPage)
  readonly property int sourceCount: {
    var seen = ({})
    for (var i = 0; i < items.length; i++) seen[items[i].source] = true
    return Object.keys(seen).length
  }
  // Headlines from the cache: the link is down, or fetches keep failing.
  readonly property bool cached: stale || hud.link === "offline" || hud.link === "local"
  readonly property bool stale: hud.newsFetched > 0 && (now.getTime() / 1000 - hud.newsFetched) > 90 * 60

  function slash(s) { return String(s).replace(/0/g, "Ø") }

  function age(ts) {
    if (!ts) return ""
    var mins = Math.max(0, Math.floor((now.getTime() / 1000 - ts) / 60))
    if (mins < 60) return mins + "M"
    if (mins < 48 * 60) return Math.floor(mins / 60) + "H"
    return Math.floor(mins / 1440) + "D"
  }

  function tagColor(cat) { return hud.catColor(cat, false) || "#c9a0f0" }

  onPageChanged: pageFade.restart()

  // ---------------------------------------------------------------- header
  Rectangle {
    id: strip
    width: stripText.width + 14 * np.u; height: 14 * np.u
    color: np.hud.sig
    Text {
      id: stripText
      anchors.centerIn: parent
      text: "SCI-TECH FEED  //  " + np.slash(np.sourceCount) + " SOURCES"
      font.family: "Michroma"; font.pixelSize: 8 * np.u; font.letterSpacing: 1 * np.u
      color: np.hud.panel
    }
  }
  Text {
    id: status
    y: strip.height + 4 * np.u
    text: np.items.length === 0 ? "AWAITING FEED"
      : np.cached ? "CACHED " + np.slash(np.age(np.hud.newsFetched)) + " AGO  //  PAGE " + np.slash(np.page + 1) + "/" + np.slash(np.pages)
      : "UPDATED " + np.slash(np.age(np.hud.newsFetched)) + " AGO  //  PAGE " + np.slash(np.page + 1) + "/" + np.slash(np.pages)
    font.family: "Michroma"; font.pixelSize: 8 * np.u; font.letterSpacing: 1 * np.u
    color: np.cached ? np.hud.gold : Qt.alpha(np.hud.sig, 0.75)
  }

  // ---------------------------------------------------------------- list
  Column {
    id: list
    y: status.y + status.height + 8 * np.u
    width: parent.width
    spacing: 6 * np.u

    SequentialAnimation {
      id: pageFade
      NumberAnimation { target: list; property: "opacity"; to: 0; duration: 150 }
      NumberAnimation { target: list; property: "opacity"; to: 1; duration: 250 }
    }

    Repeater {
      model: np.pageItems

      Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool active: index === np.lit || hover.containsMouse
        width: list.width
        height: body.height + 10 * np.u

        Rectangle {
          anchors.fill: parent
          radius: 4 * np.u
          color: row.active ? Qt.alpha(np.hud.sig, 0.14) : Qt.alpha(np.hud.panel, 0.55)
          border.width: 1
          border.color: row.active ? Qt.alpha(np.hud.sig, 0.7) : Qt.alpha(np.hud.sig, 0.18)
        }
        Rectangle {
          x: 0; y: 4 * np.u
          width: 2 * np.u; height: parent.height - 8 * np.u
          color: np.tagColor(row.modelData.category)
          opacity: row.active ? 1 : 0.5
        }

        Column {
          id: body
          x: 8 * np.u; y: 5 * np.u
          width: parent.width - 14 * np.u
          spacing: 3 * np.u

          Row {
            spacing: 5 * np.u
            Rectangle {
              width: tag.width + 8 * np.u; height: tag.height + 2 * np.u
              color: np.tagColor(row.modelData.category)
              Text {
                id: tag
                anchors.centerIn: parent
                text: row.modelData.category
                textFormat: Text.PlainText
                font.family: "Michroma"; font.pixelSize: 8 * np.u   // the 8px minimum, like labelPx
                color: np.hud.panel
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.source + "  ·  " + np.slash(np.age(row.modelData.time)) + "  ↗"
              textFormat: Text.PlainText   // feed text: never render markup
              font.family: "Michroma"; font.pixelSize: 8 * np.u; font.letterSpacing: 0.5 * np.u
              color: Qt.alpha(np.hud.sig, 0.8)
            }
          }
          Text {
            width: parent.width
            text: row.modelData.title
            textFormat: Text.PlainText   // feed text: never render markup
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            lineHeight: 1.1
            font.family: "Noto Sans"; font.pixelSize: 10.5 * np.u
            color: row.active ? np.hud.textBright : Qt.alpha(np.hud.textBright, 0.82)
          }
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: np.hud.openLink(row.modelData.link)
        }
      }
    }
  }
}
