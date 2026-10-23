import Quickshell
import QtQuick
import QtQuick.Shapes

// Native VEDA screensaver: the same scene as ~/Work/bin/veda-screensaver, but
// drawn by the shell so the core is the desktop HUD's own VedaCore.
//
// VEDA gathers information from its network: the real feed sources sit as
// nodes on two arcs, data streams travel from the source of an actual
// headline into a lattice node, which lights and passes a pulse to the core.
// Every few seconds the core charges up and emits a headline: its letters fly
// out onto the archive's top row and older entries move down.
//
// Motion is time-based (`time`, seconds), so the 2.5fps battery mode moves at
// the same speed as 5fps on AC, just with fewer frames.
Item {
  id: ss

  property var hud
  property real time: 0
  readonly property int t: Math.floor(time * 10)   // VedaCore's tick units
  // Slow-moving things (particles, source fades) step 3 times a second.
  readonly property real slowTime: Math.floor(time * 3) / 3
  readonly property real u: Math.min(width / 1366, height / 768)
  // Battery: 3 streams without trails, 12 still particles, bigger letter
  // chunks, and a headline every ~10s instead of ~5s.
  readonly property bool lite: hud.unplugged
  signal dismissed()

  // Fixed VEDA palette (no burst amber here).
  readonly property color sig: hud.base.sig
  readonly property color sigBright: hud.base.sigBright
  readonly property color gold: hud.base.gold
  readonly property color fg: "#e3fbe9"
  readonly property color muted: "#76a88c"
  readonly property color bg: "#07120d"
  // Category colours and tags come from VedaTerminal (shared with NewsPanel).
  function catCol(cat) { return hud.catColor(cat, true) }
  readonly property var catTag: hud.catTag

  // ------------------------------------------------------------ layout
  readonly property real cx: width / 2
  readonly property real cy: 356 * u
  readonly property real rad: 244 * u          // VedaCore scales from this (latR = 0.46 rad)
  readonly property real mono: 12 * u
  readonly property real charW: metrics.advanceWidth
  readonly property int cols: 92
  readonly property real archX: Math.round(cx - cols * charW / 2)
  readonly property real archTop: 588 * u        // first archive line
  readonly property real lineH: 17 * u
  readonly property int maxLines: 7

  TextMetrics {
    id: metrics
    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
    text: "M"
  }

  // ------------------------------------------------------------ state
  property real lastTime: 0
  property real flash: 0
  property var sources: []        // {name, x, y, side}
  property var srcHits: ({})      // source name -> time a stream last left it
  property var streams: []        // fixed pool of slots: null or {x0, y0, bend, t0, dur, col, vi}
  property var hits: []           // fixed pool: null or {vi, t, pulsed}
  property real nextStreamAt: 0.8
  property var archive: []        // landed rows, newest first: buildRow() results
  property int archived: 0
  property var emit: null         // {item, row (buildRow), t0, outAt, doneAt, bends}
  property real nextEmitAt: 2.5
  property int emitIdx: 0

  readonly property var news: (hud.news || []).filter(function(i) { return i && i.title })
  readonly property var proj: core.proj

  function rand(a, b) { return a + Math.random() * (b - a) }

  onNewsChanged: placeSources()
  onWidthChanged: placeSources()
  onHeightChanged: placeSources()   // cy, u and ry all follow the height
  Component.onCompleted: {
    var s = [], h = []
    for (var i = 0; i < 7; i++) s.push(null)
    for (var j = 0; j < 6; j++) h.push(null)
    streams = s
    hits = h
    placeSources()
  }

  // Spread the sources over two arcs left and right of the core.
  function placeSources() {
    var seen = ({}), names = []
    news.forEach(function(i) { if (i.source && !seen[i.source]) { seen[i.source] = true; names.push(i.source) } })
    names.sort()
    var n = names.length, left = Math.ceil(n / 2)
    var rx = Math.min(width * 0.33, width / 2 - 160 * u), ry = 118 * u
    var out = []
    for (var k = 0; k < n; k++) {
      var side = k < left ? -1 : 1
      var idx = k < left ? k : k - left
      var m = k < left ? left : n - left
      var ang = (-50 + 100 * (idx + 0.5) / Math.max(1, m)) * Math.PI / 180
      out.push({ name: names[k], x: cx + side * rx * Math.cos(ang), y: cy + ry * Math.sin(ang), side: side })
    }
    sources = out
  }

  // Greedy word wrap into at most two lines; only text that still doesn't
  // fit gets an ellipsis.
  function wrap(text, first, rest) {
    var words = String(text).split(/\s+/).filter(function(w) { return w.length }), out = []
    while (words.length && out.length < 2) {
      var limit = out.length === 0 ? first : rest, line = ""
      while (words.length && line.length + (line ? 1 : 0) + words[0].length <= limit)
        line += (line ? " " : "") + words.shift()
      if (!line) { line = words[0].substring(0, limit); words[0] = words[0].substring(limit) }
      out.push(line)
    }
    // Words left over means both lines are full; the second is `rest` wide.
    if (words.length) out[1] = out[1].substring(0, rest - 1).replace(/\s+$/, "") + "…"
    return out
  }

  // One archive entry as monospace cells: tag, title over up to two lines,
  // source on the right of the first line.
  function buildRow(item) {
    var cat = String(item.category || "").toUpperCase()
    var tag = catTag[cat] || (cat + "    ").substring(0, 4)
    var col = catCol(cat) || muted
    var src = String(item.source || "").toUpperCase().substring(0, 17)
    var first = cols - 6 - src.length - 2
    if (first < 12) { first = cols - 6; src = "" }
    var lines = wrap(item.title, first, cols - 6)
    var cells = []
    function add(c, l, s, colr, kind) {
      for (var i = 0; i < s.length; i++) if (s[i] !== " ") cells.push({ c: c + i, l: l, ch: s[i], col: colr, kind: kind })
    }
    add(0, 0, tag, col, "tag")
    for (var l = 0; l < lines.length; l++) add(6, l, lines[l], fg, "title")
    add(cols - src.length, 0, src, muted, "src")
    // Letters fly in chunks of up to 4: every moving item costs ~0.1% CPU on
    // this GPU, and a whole headline is ~150 letters.
    var chunks = []
    cells.forEach(function(cl) {
      var last = chunks.length ? chunks[chunks.length - 1] : null
      if (last && last.l === cl.l && last.kind === cl.kind && last.c + last.text.length === cl.c && last.text.length < (lite ? 8 : 4))
        last.text += cl.ch
      else chunks.push({ c: cl.c, l: cl.l, text: cl.ch, col: cl.col, kind: cl.kind })
    })
    return { item: item, cells: chunks, height: lines.length, tag: tag, tagCol: col, lines: lines, src: src }
  }

  function bez(p0, p1, p2, q) {
    var a = (1 - q) * (1 - q), b = 2 * (1 - q) * q, c = q * q
    return [a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]]
  }

  // A stream's position on its curve at time tt (null before it starts).
  function streamPos(s, tt) {
    if (!s || tt < s.t0 || !proj.length) return null
    var end = proj[s.vi] || [cx, cy]
    var ctrl = [(s.x0 + end[0]) / 2 - (end[1] - s.y0) * s.bend, (s.y0 + end[1]) / 2 + (end[0] - s.x0) * s.bend]
    var v = Math.min(1, (tt - s.t0) / s.dur)
    return bez([s.x0, s.y0], ctrl, [end[0], end[1]], v * v * (3 - 2 * v))
  }

  // ------------------------------------------------------------ simulation
  onTimeChanged: step()

  function reset() {
    var s = [], h = []
    for (var i = 0; i < streams.length; i++) s.push(null)
    for (var j = 0; j < hits.length; j++) h.push(null)
    streams = s
    hits = h
    srcHits = ({})
    emit = null
    flash = 0
    lastTime = time
    nextStreamAt = time + 0.8
    nextEmitAt = time + 2.5
  }

  // Copy-on-write: most frames change nothing but the clock, so the pools
  // are only copied (and their delegates re-read) when a slot changes.
  function step() {
    // The clock restarted on a live instance (preview sent again, or the wall
    // clock stepped back): start the schedule over instead of stalling.
    if (time < lastTime) reset()
    var dt = Math.max(0, Math.min(0.5, time - lastTime))
    lastTime = time
    if (flash > 0.003) flash *= Math.pow(0.86, dt * 10)
    else if (flash !== 0) flash = 0

    var s = streams, h = hits, sNew = false, hNew = false
    // Arrivals: the node lights and hands a pulse to the core.
    for (var i = 0; i < s.length; i++) {
      var st = s[i]
      if (st && time >= st.t0 + st.dur) {
        if (!sNew) { s = s.slice(); sNew = true }
        if (!hNew) { h = h.slice(); hNew = true }
        s[i] = null
        archived += 1
        var slot = h.indexOf(null)
        if (slot < 0) {   // full: reuse the oldest hit, which has already pulsed
          slot = 0
          for (var q = 1; q < h.length; q++) if (h[q].t < h[slot].t) slot = q
        }
        h[slot] = { vi: st.vi, t: time, pulsed: false }
      }
    }
    for (var j = 0; j < h.length; j++) {
      if (!h[j]) continue
      var age = time - h[j].t
      if (age > 1.4) {
        if (!hNew) { h = h.slice(); hNew = true }
        h[j] = null
      } else if (age >= 0.6 && !h[j].pulsed) {
        h[j].pulsed = true
        flash = Math.min(1, flash + 0.2)
      }
    }

    // New stream from the source of a real headline into a near-side node.
    if (time >= nextStreamAt && proj.length && news.length) {
      var free = s.indexOf(null)
      if (free >= (lite ? 3 : s.length)) free = -1
      if (free >= 0) {
        nextStreamAt = time + rand(0.35, 0.9)
        var front = []
        for (var k = 0; k < proj.length; k++) if (proj[k][2] > 0.2) front.push(k)
        var vi = front.length ? front[Math.floor(Math.random() * front.length)] : 0
        var item = news[Math.floor(Math.random() * Math.min(40, news.length))]
        var src = null
        for (var m = 0; m < sources.length; m++) if (sources[m].name === item.source) src = sources[m]
        var x0 = src ? src.x : (Math.random() < 0.5 ? 10 * u : width - 10 * u)
        var y0 = src ? src.y : rand(100 * u, height - 100 * u)
        if (src) { var sh = Object.assign({}, srcHits); sh[src.name] = time; srcHits = sh }
        if (!sNew) { s = s.slice(); sNew = true }
        s[free] = { x0: x0, y0: y0, bend: rand(-0.3, 0.3), t0: time, dur: rand(2.4, 3.8),
                    col: catCol(item.category) || sig, vi: vi }
      }
    }
    if (sNew) streams = s
    if (hNew) hits = h

    // Emit: charge up, let the letters fly, then land the row in the archive.
    if (!emit && time >= nextEmitAt && news.length) {
      var it = news[emitIdx % news.length]
      emitIdx += 1
      var row = buildRow(it)
      var bends = row.cells.map(function() { return rand(-0.2, 0.2) })
      emit = { item: it, row: row, t0: time, outAt: time + 0.6,
               doneAt: time + 0.6 + row.cells.length * 0.06 + 1.0, bends: bends }
    }
    if (emit) {
      if (time < emit.outAt) flash = Math.max(flash, 0.5 * (time - emit.t0) / 0.6)
      else flash = Math.max(flash, 0.4)
      if (time >= emit.doneAt) {
        var a = archive.slice()
        a.unshift(emit.row)
        archive = a.slice(0, 6)
        archived += 1
        emit = null
        nextEmitAt = time + (lite ? rand(9, 11) : rand(4.5, 6.0))
      }
    }
  }

  readonly property string focusSource: emit ? String(emit.item.source || "") : ""
  readonly property bool emitting: !!emit && time >= emit.outAt
  readonly property int shiftLines: emitting ? emit.row.height : 0
  // Older rows make room for the incoming one over 0.3s (time-based, so no
  // animation keeps running after it lands).
  readonly property real shiftY: emitting ? emit.row.height * lineH * (1 - Math.pow(1 - Math.min(1, (time - emit.outAt) / 0.3), 3)) : 0

  // ------------------------------------------------------------ cached layer
  // Everything that changes only now and then (heading, date, network links,
  // source labels, archive) is cached as one texture, like the HUD's
  // staticLayer. Without it every glyph was redrawn each frame (~1.5% CPU at
  // battery rate). Things that move or tick every second stay outside.
  Item {
    id: staticLayer
    anchors.fill: parent
    layer.enabled: true

    Rectangle { anchors.fill: parent; color: ss.bg }

    // ------------------------------------------------------------ frame corners
    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: Qt.alpha(ss.sig, 0.5)
        strokeWidth: 1.5 * ss.u
        fillColor: "transparent"
        readonly property real m: 10 * ss.u
        readonly property real l: 60 * ss.u
        startX: m; startY: m + l
        PathLine { x: 10 * ss.u; y: 10 * ss.u }
        PathLine { x: 70 * ss.u; y: 10 * ss.u }
        PathMove { x: ss.width - 70 * ss.u; y: 10 * ss.u }
        PathLine { x: ss.width - 10 * ss.u; y: 10 * ss.u }
        PathLine { x: ss.width - 10 * ss.u; y: 70 * ss.u }
        PathMove { x: 10 * ss.u; y: ss.height - 70 * ss.u }
        PathLine { x: 10 * ss.u; y: ss.height - 10 * ss.u }
        PathLine { x: 70 * ss.u; y: ss.height - 10 * ss.u }
        PathMove { x: ss.width - 70 * ss.u; y: ss.height - 10 * ss.u }
        PathLine { x: ss.width - 10 * ss.u; y: ss.height - 10 * ss.u }
        PathLine { x: ss.width - 10 * ss.u; y: ss.height - 70 * ss.u }
      }
    }

    Column {
      id: headCol
      anchors.horizontalCenter: parent.horizontalCenter
      y: 20 * ss.u
      spacing: 4 * ss.u
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        // Same wordmark as the HUD's core caption (VedaScreen.qml), a size up.
        text: "V E D A"
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 18 * ss.u
        font.letterSpacing: 3 * ss.u
        color: ss.gold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "VAST EARTH DATA ANALYZER"
        font.family: "Michroma"; font.pixelSize: 11 * ss.u; font.letterSpacing: 5 * ss.u
        color: ss.sig
      }
      Item { width: 1; height: 4 * ss.u }
      Item { id: clockSlot; width: 1; height: clockRow.height }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(dayClock.date, "ddd").toUpperCase() + "  ·  " + Qt.formatDate(dayClock.date, "yyyy.MM.dd").replace(/0/g, "Ø")
        font.family: "Michroma"; font.pixelSize: 10 * ss.u; font.letterSpacing: 2 * ss.u
        color: ss.muted
      }
    }

    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: Qt.alpha(ss.sig, 0.22)
        strokeWidth: 1
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [2, 5]
        PathSvg {
          path: {
            var p = "", src = ss.sources
            for (var i = 1; i < src.length; i++)
              if (src[i].side === src[i - 1].side)
                p += "M " + src[i - 1].x.toFixed(1) + " " + src[i - 1].y.toFixed(1) + " L " + src[i].x.toFixed(1) + " " + src[i].y.toFixed(1) + " "
            return p || "M 0 0"
          }
        }
      }
    }

    Repeater {
      model: ss.sources
      Text {
        required property var modelData
        readonly property bool lit: modelData.name === ss.focusSource
        x: modelData.side > 0 ? modelData.x + 12 * ss.u : modelData.x - width - 12 * ss.u
        y: modelData.y - height / 2
        text: String(modelData.name).toUpperCase().substring(0, 17)
        textFormat: Text.PlainText   // feed text: never render markup
        font.family: "Michroma"; font.pixelSize: 9 * ss.u; font.letterSpacing: 1 * ss.u
        color: lit ? ss.fg : ss.muted
      }
    }

    Item {
      x: ss.archX
      y: ss.archTop - ss.lineH - 6 * ss.u
      width: ss.cols * ss.charW
      height: ss.lineH
      Text {
        text: "SCI-TECH FEED · ARCHIVED BY VEDA"
        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
        color: Qt.alpha(ss.sig, 0.75)
      }
    }

    Item {
      id: archiveBox
      x: ss.archX
      y: ss.archTop
      width: ss.cols * ss.charW
      height: ss.maxLines * ss.lineH
      clip: true

      Column {
        y: ss.shiftY
        Repeater {
          model: ss.archive
          Item {
            required property var modelData
            required property int index
            readonly property real f: index === 0 && ss.shiftLines === 0 ? 1 : 0.72
            width: archiveBox.width
            height: modelData.height * ss.lineH
            Text {
              text: modelData.tag
              textFormat: Text.PlainText
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
              color: modelData.tagCol; opacity: parent.f
            }
            Repeater {
              model: modelData.lines
              Text {
                required property var modelData
                required property int index
                x: 6 * ss.charW; y: index * ss.lineH
                text: modelData
                textFormat: Text.PlainText   // feed text: never render markup
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
                color: ss.fg; opacity: parent.f
              }
            }
            Text {
              anchors.right: parent.right
              text: modelData.src
              textFormat: Text.PlainText
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
              // Older entries fade, but the source name stays readable.
              color: ss.muted; opacity: Math.max(parent.f, 0.85)
            }
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: ss.height - 28 * ss.u
      text: "PRESS ANY KEY TO RESUME"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 * ss.u; font.letterSpacing: 1 * ss.u
      color: Qt.alpha(ss.muted, 0.9)
    }

  }

  // ------------------------------------------------------------ particles
  // Fixed colour per particle; the twinkle is opacity only, because a colour
  // change makes Qt rebuild the glyph node every frame (measured ~5% CPU).
  readonly property var particles: {
    var out = [], chars = ["·", "·", "·", "*", "-"]
    for (var i = 0; i < 22; i++) {
      var base = rand(0.3, 1)
      out.push({ x0: Math.random(), y0: Math.random(), vx: rand(-6, 6), vy: rand(-14, -4),
                 ph: rand(0, 6.28), base: base, bright: base > 0.8, ch: chars[i % chars.length] })
    }
    return out
  }
  Repeater {
    model: ss.lite ? ss.particles.slice(0, 12) : ss.particles
    Text {
      required property var modelData
      readonly property real px: modelData.x0 * ss.width + modelData.vx * (ss.lite ? 0 : ss.slowTime) * ss.u
      readonly property real py: modelData.y0 * ss.height + modelData.vy * (ss.lite ? 0 : ss.slowTime) * ss.u
      x: ((px % ss.width) + ss.width) % ss.width
      y: ((py % ss.height) + ss.height) % ss.height
      text: modelData.ch
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 * ss.u
      color: modelData.bright ? ss.sig : "#3f8f63"
      opacity: modelData.base * (ss.lite ? 0.6 : 0.35 + 0.4 * (0.55 + 0.45 * Math.sin(ss.slowTime * 2.2 + modelData.ph)))
    }
  }

  // ------------------------------------------------------------ clock source
  SystemClock { id: clock; precision: SystemClock.Seconds }
  // The date sits in the cached layer, so it reads a per-minute clock.
  SystemClock { id: dayClock; precision: SystemClock.Minutes }

  // ------------------------------------------------------------ live clock
  Row {
    id: clockRow
    anchors.horizontalCenter: parent.horizontalCenter
    y: headCol.y + clockSlot.y
    spacing: 0
    // Plain text pieces rather than rich text: only the changed piece is laid
    // out again each second, and the colons blink through opacity.
    Repeater {
      id: clockParts
      model: 5
      Text {
        required property int index
        readonly property var d: clock.date
        readonly property bool colon: index % 2 === 1
        text: {
          if (colon) return ":"
          var v = index === 0 ? (d.getHours() % 12 || 12) : index === 2 ? d.getMinutes() : d.getSeconds()
          return String(index > 0 && v < 10 ? "0" + v : v).replace(/0/g, "Ø")
        }
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 62 * ss.u
        color: ss.sig
        opacity: colon && d.getSeconds() % 2 === 1 ? 0.3 : 1
      }
    }
    Text {
      anchors.baseline: clockParts.count ? clockParts.itemAt(0).baseline : undefined
      leftPadding: 6 * ss.u
      text: Qt.formatTime(clock.date, "AP")
      font.family: "Michroma"; font.pixelSize: 14 * ss.u
      color: ss.sig
    }
  }

  Item {
    x: ss.archX
    y: ss.archTop - ss.lineH - 6 * ss.u
    width: ss.cols * ss.charW
    height: ss.lineH
    Text {
      anchors.right: parent.right
      text: "ARCHIVED " + ss.archived + "  ·  STREAMS " + ss.streams.filter(function(s) { return !!s }).length
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
      color: Qt.alpha(ss.sig, 0.75)
    }
  }

  // ------------------------------------------------------------ network
  Repeater {
    model: ss.sources
    Item {
      required property var modelData
      readonly property bool lit: modelData.name === ss.focusSource
      readonly property real f: lit ? 1 : ss.lite ? 0.6 : Math.max(0.45, 1 - (ss.slowTime - (ss.srcHits[modelData.name] || -9)) / 1.2)
      x: modelData.x; y: modelData.y
      Rectangle {
        width: 9 * ss.u; height: width; radius: width / 2
        x: -width / 2; y: -height / 2
        color: "transparent"
        border.width: 1.4 * ss.u
        border.color: parent.lit ? ss.gold : Qt.alpha(ss.sig, parent.f)
        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.4; height: width; radius: width / 2
          color: parent.parent.lit ? ss.gold : Qt.alpha(ss.sig, parent.parent.f)
        }
      }
    }
  }

  // ------------------------------------------------------------ the core
  VedaCore {
    id: core
    anchors.fill: parent
    part: "all"
    t: ss.t; u: ss.u; rad: ss.rad; ccx: ss.cx; ccy: ss.cy
    flash: ss.flash
    sig: ss.sig; sigBright: ss.sigBright; gold: ss.gold
  }

  // Streams: a fading trail behind a bright head.
  Repeater {
    model: ss.streams.length
    Item {
      id: stream
      required property int index
      readonly property var s: ss.streams[index]
      anchors.fill: parent
      visible: !!s
      Repeater {
        model: ss.lite ? [0] : [3, 2, 1, 0]
        Rectangle {
          required property var modelData
          readonly property var p: stream.s ? ss.streamPos(stream.s, ss.time - modelData * 0.12) : null
          readonly property real sz: (modelData === 0 ? 6 : modelData === 1 ? 4 : 3) * ss.u
          visible: !!p
          width: sz; height: sz; radius: sz / 2
          x: p ? p[0] - sz / 2 : 0
          y: p ? p[1] - sz / 2 : 0
          color: modelData === 0 ? Qt.tint(stream.s ? stream.s.col : ss.sig, Qt.alpha(ss.fg, 0.55)) : (stream.s ? stream.s.col : ss.sig)
          opacity: modelData === 0 ? 1 : 0.9 - modelData * 0.2
        }
      }
    }
  }

  // Nodes that just received a stream, and the pulse they hand to the core.
  Repeater {
    model: ss.hits.length
    Item {
      required property int index
      readonly property var h: ss.hits[index]
      readonly property var p: h && ss.proj[h.vi] ? ss.proj[h.vi] : null
      readonly property real age: h ? ss.time - h.t : 9
      anchors.fill: parent
      visible: !!p
      Rectangle {
        readonly property real sz: (parent.age < 0.5 ? 8 : 5) * ss.u
        width: sz; height: sz
        rotation: 45
        x: parent.p ? parent.p[0] - sz / 2 : 0
        y: parent.p ? parent.p[1] - sz / 2 : 0
        color: parent.age < 0.7 ? ss.gold : ss.sig
        opacity: 1 - 0.4 * parent.age / 1.4
      }
      Rectangle {
        readonly property real q: Math.min(1, parent.age / 0.6)
        visible: parent.age < 0.6
        width: 4 * ss.u; height: width; radius: width / 2
        x: parent.p ? parent.p[0] + (ss.cx - parent.p[0]) * q - width / 2 : 0
        y: parent.p ? parent.p[1] + (ss.cy - parent.p[1]) * q - height / 2 : 0
        color: ss.fg
      }
    }
  }

  // ------------------------------------------------------------ flying letters
  // Letters of the headline being emitted, flying from the core to their
  // place on the archive's top row.
  Repeater {
    model: ss.emit ? ss.emit.row.cells : []
    Text {
      required property var modelData
      required property int index
      readonly property real v: ss.emit ? (ss.time - ss.emit.outAt - index * 0.06) / 1.0 : 0
      readonly property real hx: ss.archX + modelData.c * ss.charW
      readonly property real hy: ss.archTop + modelData.l * ss.lineH
      readonly property real q: 1 - (1 - Math.min(1, v)) * (1 - Math.min(1, v))
      readonly property real bend: ss.emit ? ss.emit.bends[index] : 0
      readonly property var p: ss.bez([ss.cx, ss.cy],
        [(ss.cx + hx) / 2 + bend * Math.abs(hy - ss.cy) * 1.5, ss.cy + (hy - ss.cy) * 0.15], [hx, hy], q)
      visible: v > 0
      x: v >= 1 ? hx : p[0]
      y: v >= 1 ? hy : p[1]
      text: v < 0.25 ? "·" : v < 0.5 ? "•" : modelData.text
      textFormat: Text.PlainText
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: ss.mono
      // Gold while in flight, its own colour for the landing: one colour
      // change per chunk instead of one per frame.
      color: v >= 0.75 ? modelData.col : ss.gold
    }
  }

  // ------------------------------------------------------------ dismiss
  // Any key, a click, or a real mouse move ends it. The pointer is hidden.
  property bool interactive: false
  property real startX: -1
  property real startY: -1
  focus: interactive
  Keys.onPressed: function(event) { event.accepted = true; ss.dismissed() }
  MouseArea {
    anchors.fill: parent
    enabled: ss.interactive
    hoverEnabled: true
    cursorShape: Qt.BlankCursor
    onPressed: ss.dismissed()
    onPositionChanged: function(mouse) {
      if (ss.startX < 0) { ss.startX = mouse.x; ss.startY = mouse.y; return }
      if (Math.abs(mouse.x - ss.startX) + Math.abs(mouse.y - ss.startY) > 24 * ss.u) ss.dismissed()
    }
    onWheel: ss.dismissed()
  }
}
