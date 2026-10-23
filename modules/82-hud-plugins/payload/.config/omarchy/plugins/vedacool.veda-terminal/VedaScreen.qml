import Quickshell
import QtQuick
import QtQuick.Shapes

// One screen's worth of the VEDA terminal: a rotating quantum-core lattice in
// the middle (a geodesic shell around a counter-turning inner shell and a gold
// core), the load gauge as a U beneath it, donut readouts at its shoulders,
// softkey columns on both edges, the sci-tech feed on the left and system
// panels plus a live terminal log on the right.
//
// Rendering budget: everything that only changes when data arrives (every
// 2s) lives in `staticLayer`, which Qt caches as one texture. The lattice
// (VedaCore.qml) is four batched paths rebuilt per tick; blinking bits stay
// outside the layers.
Item {
  id: hs

  property var hud

  readonly property real u: Math.min(width / 1366, height / 768)
  readonly property real cx: width / 2
  // Projection drops the core a little and shrinks it, so the clock fits above.
  readonly property real cy: height * (projection ? 0.58 : 0.54)
  readonly property real rad: height * (projection ? 0.32 : 0.35)
  property int t: hud.tick

  // Projection: the external screen in extend mode faces an audience, so it
  // shows only the core, the clock pill and the power plate, and never turns
  // amber in a burst. Everything else hides; the layout stays identical.
  property bool projection: false
  property bool external: false
  readonly property bool burst: !projection && hud.burst
  readonly property color sig: projection ? hud.base.sig : hud.sig
  readonly property color sigBright: projection ? hud.base.sigBright : hud.sigBright
  readonly property color deep: projection ? hud.base.deep : hud.deep
  readonly property color gold: projection ? hud.base.gold : hud.gold
  readonly property color textBright: projection ? hud.base.textBright : hud.textBright
  readonly property color panel: projection ? hud.base.panel : hud.panel
  readonly property color warn: hud.warn

  // Calm mode (laptop mirrored to a projector): the log keeps system lines
  // only, and a display-link block takes the news panel's place.
  readonly property var logView: hud.calm ? hud.logLines.filter(function(l) { return !l.archive }) : hud.logLines

  // The core sits a little above the gauge centre, inside its U.
  readonly property real ccx: cx
  readonly property real ccy: cy - rad * 0.12
  readonly property real latR: rad * 0.46

  // Load chart ceiling: the recent peak rounded up to 25%, so an idle
  // machine still shows its activity instead of 1px bars.
  readonly property int chartMax: {
    var h = hud.cpuHistory, peak = 0
    for (var i = 0; i < h.length; i++) peak = Math.max(peak, h[i])
    return Math.min(100, Math.max(25, Math.ceil(peak / 25) * 25))
  }

  // Load gauge arcs (left = processing, mirrored right = memory). They start
  // at 118° so the bottom ends stop short of the battery plate.
  readonly property real gStart: 118
  readonly property real gSweep: 90

  // Celestial Being screens print zeros slashed.
  function slash(s) { return String(s).replace(/0/g, "Ø") }
  function pad(n, w) { var s = String(Math.round(n)); while (s.length < w) s = "0" + s; return s }
  function polar(r, deg) { var a = deg * Math.PI / 180; return { x: hs.cx + r * Math.cos(a), y: hs.cy + r * Math.sin(a) } }

  readonly property real labelPx: 8 * u   // smallest text; Michroma below ~8px is hard to read at 1366x768

  Connections {
    target: hs.hud
    function onSnapshotRequested(path) {
      // An extended screen saves next to the laptop's: shot.png -> shot-ext.png
      var out = hs.external ? path.replace(/(\.png)?$/, "-ext.png") : path
      hs.grabToImage(function(result) { result.saveToFile(out) })
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // For the "dark for hh:mm" readout, which sits in staticLayer and so
  // should only change once a minute.
  SystemClock {
    id: minuteClock
    precision: SystemClock.Minutes
  }

  // Link state colour: green when VEDA's network answers, gold on a local
  // network with no way out, red when severed.
  // The severed red is brighter than hud.warn so 8px text clears 4.5:1.
  readonly property color linkColor: hud.link === "local" ? hud.gold
    : hud.link === "offline" ? "#ff6b7a" : hud.sig

  // ============================================================ animated: back
  // Sphere grid around the core with slowly turning meridians (VedaCore.qml).
  VedaCore {
    anchors.fill: parent
    part: "grid"
    t: hs.t; u: hs.u; rad: hs.rad; ccx: hs.ccx; ccy: hs.ccy
    sig: hs.sig; sigBright: hs.sigBright; gold: hs.gold
  }

  // Outer dashed ring turning around the gauge centre.
  Shape {
    width: hs.rad * 3; height: width; x: hs.cx - width / 2; y: hs.cy - height / 2
    rotation: hs.t * 0.25
    ShapePath {
      strokeColor: Qt.alpha(hs.sig, 0.30)
      strokeWidth: 1.5 * hs.u
      fillColor: "transparent"
      strokeStyle: ShapePath.DashLine
      dashPattern: [2, 6]
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.17; radiusY: hs.rad * 1.17; startAngle: 0; sweepAngle: 360 }
    }
  }
  Shape {
    width: hs.rad * 3; height: width; x: hs.cx - width / 2; y: hs.cy - height / 2
    rotation: -hs.t * 0.15
    ShapePath {
      strokeColor: Qt.alpha(hs.gold, 0.35)
      strokeWidth: 3 * hs.u
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 10; sweepAngle: 50 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 130; sweepAngle: 20 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 190; sweepAngle: 50 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 310; sweepAngle: 20 }
    }
  }

  // Burst split ring: behind the static layer so readouts stay on top.
  Shape {
    width: hs.rad * 3; height: width; x: hs.cx - width / 2; y: hs.cy - height / 2
    rotation: hs.t * 0.8
    opacity: burstFade.opacity * (0.6 + 0.4 * Math.abs(Math.sin(hs.t * 0.15)))
    visible: opacity > 0
    ShapePath {
      strokeColor: Qt.alpha(hs.sigBright, 0.8)
      strokeWidth: 10 * hs.u
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.2; radiusY: hs.rad * 1.2; startAngle: 15; sweepAngle: 150 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.2; radiusY: hs.rad * 1.2; startAngle: 195; sweepAngle: 150 }
    }
  }

  // ============================================================ static layer
  Item {
    id: staticLayer
    anchors.fill: parent
    layer.enabled: true

    // -------------------------------------------------- load gauge
    ArcBand {
      visible: !hs.projection
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad; rInner: hs.rad * 0.86
      startAngle: hs.gStart; sweep: hs.gSweep; segments: 24
      value: hs.hud.cpu / 100
      colorLow: hs.sig; colorHigh: hs.deep
      colorOff: Qt.alpha(hs.sig, 0.10)
    }
    ArcBand {
      visible: !hs.projection
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad * 0.84; rInner: hs.rad * 0.81
      startAngle: hs.gStart; sweep: hs.gSweep; segments: 48; gap: 0.8
      value: hs.hud.cpu / 100
      colorLow: hs.sigBright; colorHigh: hs.sigBright
      colorOff: Qt.alpha(hs.sig, 0.08)
    }
    ArcBand {
      visible: !hs.projection
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad; rInner: hs.rad * 0.86
      startAngle: 180 - hs.gStart; sweep: -hs.gSweep; segments: 24
      value: hs.hud.mem / 100
      colorLow: hs.sig; colorHigh: hs.deep
      colorOff: Qt.alpha(hs.sig, 0.10)
    }
    ArcBand {
      visible: !hs.projection
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad * 0.84; rInner: hs.rad * 0.81
      startAngle: 180 - hs.gStart; sweep: -hs.gSweep; segments: 48; gap: 0.8
      value: hs.hud.mem / 100
      colorLow: hs.sigBright; colorHigh: hs.sigBright
      colorOff: Qt.alpha(hs.sig, 0.08)
    }

    // Scale ticks: one path for all ten, then labels.
    Shape {
      visible: !hs.projection
      anchors.fill: parent
      ShapePath {
        strokeColor: Qt.alpha(hs.sig, 0.8)
        strokeWidth: 1.5 * hs.u
        fillColor: "transparent"
        PathSvg {
          path: {
            var d = ""
            var marks = [0, 30, 50, 80, 100]
            for (var s = 0; s < 2; s++) {
              for (var i = 0; i < marks.length; i++) {
                var ang = s === 0 ? hs.gStart + hs.gSweep * marks[i] / 100 : 180 - hs.gStart - hs.gSweep * marks[i] / 100
                var p1 = hs.polar(hs.rad * 1.02, ang), p2 = hs.polar(hs.rad * 1.07, ang)
                d += "M " + p1.x + " " + p1.y + " L " + p2.x + " " + p2.y + " "
              }
            }
            return d
          }
        }
      }
    }
    Repeater {
      model: [0, 30, 50, 80, 100, 0, 30, 50, 80, 100]
      Text {
        visible: !hs.projection
        required property int index
        required property int modelData
        readonly property var pl: hs.polar(hs.rad * 1.12, index < 5 ? hs.gStart + hs.gSweep * modelData / 100 : 180 - hs.gStart - hs.gSweep * modelData / 100)
        x: pl.x - width / 2; y: pl.y - height / 2
        text: hs.slash(modelData)
        font.family: "Michroma"; font.pixelSize: 9 * hs.u
        color: Qt.alpha(hs.sig, 0.85)
      }
    }

    // Processor load (left) and memory (right), outside the gauge's upper ends.
    Repeater {
      model: [{ label: "CPU LOAD", side: -1 }, { label: "MEMORY BANK", side: 1 }]
      Item {
        id: readout
        visible: !hs.projection
        required property var modelData
        x: modelData.side < 0 ? hs.cx - hs.rad * 1.02 - width : hs.cx + hs.rad * 1.02
        y: hs.cy - hs.rad * 0.64 - height
        width: 120 * hs.u; height: 52 * hs.u
        Row {
          anchors.right: readout.modelData.side < 0 ? parent.right : undefined
          anchors.left: readout.modelData.side > 0 ? parent.left : undefined
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 12 * hs.u
          spacing: 2 * hs.u
          Text {
            id: readoutNum
            text: hs.slash(hs.pad(readout.modelData.side < 0 ? hs.hud.cpu : hs.hud.mem, 2))
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 30 * hs.u
            color: hs.textBright
          }
          Text {
            anchors.baseline: readoutNum.baseline
            text: "%"
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 14 * hs.u
            color: hs.sig
          }
        }
        Text {
          anchors.right: readout.modelData.side < 0 ? parent.right : undefined
          anchors.left: readout.modelData.side > 0 ? parent.left : undefined
          anchors.bottom: parent.bottom
          text: readout.modelData.label
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.5 * hs.u
          color: Qt.alpha(hs.sig, 0.8)
        }
      }
    }

    // Core caption under the lattice.
    Column {
      x: hs.ccx - width / 2
      y: hs.ccy + hs.latR + 16 * hs.u
      spacing: 2 * hs.u
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "V E D A"
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15 * hs.u
        font.letterSpacing: 3 * hs.u
        color: hs.gold
      }
      // What the letters stand for, then the core's own spec line, dimmer.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "VAST EARTH DATA ANALYZER"
        font.family: "Michroma"; font.pixelSize: 9 * hs.u; font.letterSpacing: 1.5 * hs.u
        color: hs.textBright
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "QUANTUM CORE  //  " + hs.slash(hudCore.nodeCount) + " NODES"
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
        // Brighter on the projector, which washes out dim text for the audience.
        color: Qt.alpha(hs.sig, hs.projection ? 0.85 : 0.6)
      }
    }

    // -------------------------------------------------- donut readouts
    Repeater {
      model: [
        { side: -1, head: "SENSOR", tag: "TEMP", unit: "°C", warnAt: 85 },
        { side: 1, head: "COOLING", tag: "FAN", unit: "%", warnAt: 101 }
      ]
      Item {
        id: donut
        visible: !hs.projection
        required property var modelData
        readonly property real dr: hs.rad * 0.23
        readonly property real dcx: hs.cx + modelData.side * hs.rad * 0.67
        readonly property real dcy: hs.cy - hs.rad * 0.6
        readonly property real val: modelData.side < 0 ? hs.hud.temp : hs.hud.fan
        readonly property bool hot: val >= modelData.warnAt
        anchors.fill: parent

        Rectangle {
          x: donut.dcx - donut.dr * 0.8; y: donut.dcy - donut.dr * 0.8
          width: donut.dr * 1.6; height: width; radius: width / 2
          color: Qt.alpha(hs.panel, 0.8)
          border.color: Qt.alpha(hs.sig, 0.35)
          border.width: 1
        }
        ArcBand {
          anchors.fill: parent
          cx: donut.dcx; cy: donut.dcy
          rOuter: donut.dr; rInner: donut.dr * 0.82
          startAngle: -90; sweep: 360; segments: 30; gap: 2
          value: Math.min(1, donut.val / 100)
          colorLow: donut.hot ? hs.warn : hs.sig
          colorHigh: donut.hot ? hs.warn : hs.gold
          colorOff: Qt.alpha(hs.sig, 0.12)
        }
        Column {
          x: donut.dcx - width / 2
          y: donut.dcy - height / 2
          spacing: 2 * hs.u
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: donut.modelData.head
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 0.5 * hs.u
            color: hs.sig
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tagText.width + 8 * hs.u; height: tagText.height + 2 * hs.u
            color: donut.hot ? hs.warn : hs.sig
            Text {
              id: tagText
              anchors.centerIn: parent
              text: donut.modelData.tag
              font.family: "Michroma"; font.pixelSize: hs.labelPx
              color: hs.panel
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: hs.slash(hs.pad(donut.val, 2)) + donut.modelData.unit
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 20 * hs.u
            color: donut.hot ? hs.warn : hs.textBright
          }
        }
      }
    }

    // -------------------------------------------------- right panel
    Item {
      id: rightPanel
      visible: !hs.projection
      width: 262 * hs.u
      x: hs.width - 16 * hs.u - width
      y: 64 * hs.u
      height: hs.height - y - 60 * hs.u

      Column {
        id: header
        width: parent.width
        spacing: 4 * hs.u

        Row {
          anchors.right: parent.right
          spacing: 8 * hs.u
          Text {
            anchors.baseline: vedaWord.baseline
            text: "CELESTIAL BEING"
            font.family: "Michroma"; font.pixelSize: 9 * hs.u; font.letterSpacing: 1.5 * hs.u
            color: Qt.alpha(hs.sig, 0.85)
          }
          Text {
            id: vedaWord
            text: "VEDA"
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 24 * hs.u; font.letterSpacing: 3 * hs.u
            color: hs.textBright
          }
        }
        Rectangle { width: parent.width; height: 1.5 * hs.u; color: hs.gold }
        // Severed shows as a red chip, in the same badge language as ACCESS
        // LEVEL 7; the padding is always there so the layout doesn't jump.
        Rectangle {
          id: linkChip
          anchors.right: parent.right
          readonly property real padX: hs.hud.link === "offline" ? 6 * hs.u : 0
          width: linkRow.width + 2 * padX; height: linkRow.height + 6 * hs.u
          color: hs.hud.link === "offline" ? "#3a0d16" : "transparent"
          border.color: hs.hud.link === "offline" ? hs.linkColor : "transparent"
          border.width: 1
          Row {
            id: linkRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: linkChip.padX
            spacing: 6 * hs.u
            Rectangle {
              id: vedaDot
              anchors.verticalCenter: parent.verticalCenter
              width: 6 * hs.u; height: width; radius: width / 2
              color: "transparent"
              border.color: hs.linkColor; border.width: 1
            }
            Text {
              text: hs.hud.link === "online" ? "QUANTUM LINK ESTABLISHED"
                : hs.hud.link === "local" ? "QUANTUM LINK UNSTABLE"
                : hs.hud.link === "offline" ? "QUANTUM LINK SEVERED"
                : "QUANTUM LINK SYNCHRONISING"
              font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
              color: hs.linkColor
            }
          }
        }
        // What the link is riding on, or how long VEDA has been on its own.
        Row {
          anchors.right: parent.right
          spacing: 6 * hs.u
          Row {
            anchors.bottom: linkDetail.baseline
            spacing: 1.5 * hs.u
            Repeater {
              model: 4
              Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 2.5 * hs.u; height: (3 + index * 2) * hs.u
                color: index < hs.hud.linkBars ? hs.linkColor : Qt.alpha(hs.linkColor, 0.2)
              }
            }
          }
          Text {
            id: linkDetail
            readonly property string dev: hs.hud.linkMedium
            readonly property int dark: Math.max(0, Math.floor((minuteClock.date.getTime() - hs.hud.linkLostAt) / 60000))
            text: hs.slash(hs.hud.link === "online" ? dev + "  //  RTT " + hs.hud.linkRtt + "MS"
              : hs.hud.link === "local" ? dev + "  //  NO UPLINK  //  DARK " + hs.hud.darkText(dark)
              : hs.hud.link === "offline" ? "STANDALONE MODE  //  DARK " + hs.hud.darkText(dark)
              : "PROBING")
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.hud.link === "offline" ? hs.linkColor : Qt.alpha(hs.linkColor, 0.8)
          }
        }
        // This terminal holds VEDA's top clearance (levels run 1-7).
        Rectangle {
          anchors.right: parent.right
          width: lvText.width + 14 * hs.u; height: lvText.height + 4 * hs.u
          color: hs.gold
          Text {
            id: lvText
            anchors.centerIn: parent
            text: "ACCESS LEVEL 7"
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 9 * hs.u; font.letterSpacing: 1.5 * hs.u
            color: hs.panel
          }
        }
        Text {
          anchors.right: parent.right
          text: "TERMINAL  " + String(hs.hud.hostname).toUpperCase()
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: Qt.alpha(hs.sig, 0.8)
        }
        Text {
          anchors.right: parent.right
          readonly property int up: hs.hud.uptime
          // Same "1H 05M" style as the DARK timer: hh:mm was misread as mm:ss.
          text: "UPTIME  " + hs.slash(up < 3600 ? Math.floor(up / 60) + " MIN"
            : up < 86400 ? Math.floor(up / 3600) + "H " + hs.pad(Math.floor(up % 3600 / 60), 2) + "M"
            : Math.floor(up / 86400) + "D " + hs.pad(Math.floor(up % 86400 / 3600), 2) + "H")
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: Qt.alpha(hs.sig, 0.8)
        }
      }

      // CPU history bar chart: 40 samples x 2s.
      Item {
        id: chart
        y: header.height + 12 * hs.u
        width: parent.width
        height: 110 * hs.u

        Rectangle {
          width: chartTitle.width + 12 * hs.u; height: 14 * hs.u
          color: hs.sig
          Text {
            id: chartTitle
            anchors.centerIn: parent
            text: "CPU LOAD  //  8Ø SEC"
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.panel
          }
        }
        Rectangle {
          y: 20 * hs.u
          width: parent.width; height: parent.height - 20 * hs.u
          color: Qt.alpha(hs.panel, 0.65)
          border.color: Qt.alpha(hs.sig, 0.35)
          border.width: 1

          Text {
            anchors.right: parent.right
            anchors.rightMargin: 4 * hs.u
            y: 3 * hs.u
            text: "MAX " + hs.slash(hs.chartMax) + "%"
            font.family: "Michroma"; font.pixelSize: hs.labelPx
            color: Qt.alpha(hs.sig, 0.7)
          }
          Repeater {
            model: 4
            Rectangle {
              required property int index
              y: parent.height * (index + 1) / 5
              width: parent.width; height: 1
              color: Qt.alpha(hs.sig, 0.10)
            }
          }
          Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3 * hs.u
            x: 4 * hs.u
            spacing: 2 * hs.u
            Repeater {
              model: 40
              Rectangle {
                required property int index
                readonly property var h: hs.hud.cpuHistory
                readonly property real v: index >= 40 - h.length ? h[index - (40 - h.length)] : 0
                anchors.bottom: parent.bottom
                width: (chart.width - 8 * hs.u - 39 * 2 * hs.u) / 40
                height: Math.max(1, (chart.height - 28 * hs.u) * Math.min(1, v / hs.chartMax))
                color: v > 85 ? hs.gold : (index === 39 ? hs.sigBright : Qt.alpha(hs.sig, 0.75))
              }
            }
          }
        }
      }

      // Per-thread bars.
      Column {
        id: threads
        y: chart.y + chart.height + 12 * hs.u
        width: parent.width
        spacing: 4 * hs.u

        Rectangle {
          width: coreTitle.width + 12 * hs.u; height: 14 * hs.u
          color: hs.sig
          Text {
            id: coreTitle
            anchors.centerIn: parent
            text: "PROCESSOR THREADS"
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.panel
          }
        }
        Repeater {
          model: hs.hud.cores.length
          Row {
            id: coreRow
            required property int index
            readonly property real v: hs.hud.cores[index] || 0
            spacing: 6 * hs.u
            Text {
              width: 24 * hs.u
              text: "T" + (coreRow.index + 1)
              font.family: "Michroma"; font.pixelSize: hs.labelPx
              color: Qt.alpha(hs.sig, 0.85)
            }
            Item {
              width: rightPanel.width - 70 * hs.u; height: 6 * hs.u
              anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.fill: parent; color: Qt.alpha(hs.sig, 0.10) }
              Rectangle {
                height: parent.height
                width: parent.width * coreRow.v / 100
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: hs.deep }
                  GradientStop { position: 1; color: hs.sig }
                }
              }
            }
            Text {
              width: 28 * hs.u
              horizontalAlignment: Text.AlignRight
              text: hs.slash(hs.pad(coreRow.v, 2))
              font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 8 * hs.u
              color: hs.textBright
            }
          }
        }
      }
    }

    // -------------------------------------------------- bottom strip
    Item {
      visible: !hs.projection
      x: 16 * hs.u
      width: hs.width - 32 * hs.u
      y: hs.height - 34 * hs.u
      height: 20 * hs.u

      Rectangle { width: parent.width; height: 1; color: Qt.alpha(hs.sig, 0.4) }
      Text {
        y: 6 * hs.u
        readonly property var fetched: new Date(hs.hud.newsFetched * 1000)
        text: hs.hud.news.length === 0 ? "ARCHIVE  //  AWAITING FIRST SYNC"
          : "ARCHIVE  " + hs.slash(hs.hud.news.length) + " ITEMS  //  LAST SYNC " + hs.slash(Qt.formatTime(fetched, "h:mm AP")) + (hs.hud.link === "online" || hs.hud.link === "unknown" ? "  //  RESYNC EVERY 3Ø MIN" : "  //  LINK DOWN  //  SERVING LOCAL ARCHIVE")
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.2 * hs.u
        color: Qt.alpha(hs.sig, 0.75)
      }
      Text {
        anchors.right: parent.right
        y: 6 * hs.u
        text: "KERNEL " + hs.slash(String(hs.hud.kernel).toUpperCase())
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.2 * hs.u
        color: Qt.alpha(hs.sig, 0.75)
      }
    }
  }

  // ============================================================ core
  // The quantum core itself, shared with the native screensaver.
  VedaCore {
    id: hudCore
    anchors.fill: parent
    part: "core"
    t: hs.t; u: hs.u; rad: hs.rad; ccx: hs.ccx; ccy: hs.ccy
    fastSpin: hs.burst; burst: hs.burst; offline: hs.hud.link === "offline"   // hs.burst is off in projection
    sig: hs.sig; sigBright: hs.sigBright; gold: hs.gold
  }

  // ============================================================ live overlay
  // Things that blink or tick every second stay out of staticLayer, so they
  // don't force the whole cached layer to re-render.
  // -------------------------------------------------- bottom readout plate
  Item {
    width: hs.rad * 0.66
    height: 80 * hs.u
    x: hs.cx - width / 2
    y: hs.cy + hs.rad * 0.74

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 2 * hs.u
      width: batRow.width + 18 * hs.u; height: 38 * hs.u
      radius: height / 2
      color: Qt.alpha(hs.panel, 0.9)
    }
    Row {
      id: batRow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      spacing: 4 * hs.u
      Text {
        id: batBig
        text: hs.slash(hs.pad(hs.hud.battery, 2))
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 34 * hs.u
        color: hs.hud.battery <= 15 && hs.t % 14 < 7 ? hs.warn : hs.textBright
      }
      Text {
        anchors.baseline: batBig.baseline
        text: "%"
        font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 16 * hs.u
        color: hs.sig
      }
      // Plain-language tag so the themed plate below still reads as battery.
      Rectangle {
        anchors.verticalCenter: batBig.verticalCenter
        width: batTag.width + 10 * hs.u; height: batTag.height + 4 * hs.u
        color: hs.hud.battery <= 15 ? hs.warn : hs.sig
        Text {
          id: batTag
          anchors.centerIn: parent
          text: "BATTERY"
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: hs.panel
        }
      }
    }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: parent.width; height: 30 * hs.u
      radius: 4 * hs.u
      color: Qt.alpha(hs.panel, 0.9)
      border.color: hs.sig
      border.width: 1.2 * hs.u
      Column {
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "TERMINAL POWER"
          font.family: "Michroma"; font.pixelSize: 9 * hs.u; font.letterSpacing: 1 * hs.u
          color: hs.textBright
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          readonly property bool charging: hs.hud.batteryStatus === "Charging"
          text: charging ? "CELL CHARGING" : "CELL REMAINING"
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 0.8 * hs.u
          color: charging && hs.t % 20 < 10 ? hs.gold : Qt.alpha(hs.sig, 0.85)
        }
      }
    }
  }

  // -------------------------------------------------- clock pill
  // Top-left on the laptop; centred above the core on the projection screen.
  Item {
    x: hs.projection ? hs.cx - width / 2 : 16 * hs.u
    y: (hs.projection ? 40 : 64) * hs.u
    // Sized once for the widest time and weekday (Orbitron digits are not
    // monospaced), so a two-digit hour and WEDNESDAY never collide and the
    // pill holds still as the seconds tick.
    width: Math.max(300 * hs.u, 42 * hs.u + reserveW + 16 * hs.u + 22 * hs.u)
    height: 84 * hs.u

    property real reserveW: 0
    TextMetrics { id: tmBig; font: clockBig.font }
    TextMetrics { id: tmSmall; font: clockSecs.font }
    TextMetrics { id: tmDay; font: clockDay.font }
    function measureReserve() {
      var big = 0, small = 0, day = 0
      for (var d = 0; d < 10; d++) {
        tmBig.text = hs.slash("1" + d + ":" + d + d); big = Math.max(big, tmBig.advanceWidth)
        tmSmall.text = "." + hs.slash("" + d + d) + " AM"; small = Math.max(small, tmSmall.advanceWidth)
        tmSmall.text = "." + hs.slash("" + d + d) + " PM"; small = Math.max(small, tmSmall.advanceWidth)
      }
      for (var i = 0; i < 7; i++) {
        tmDay.text = Qt.formatDate(new Date(2026, 9, 18 + i), "dddd").toUpperCase()
        day = Math.max(day, tmDay.advanceWidth)
      }
      reserveW = Math.ceil(big + clockRow.spacing + small + day)
    }
    Component.onCompleted: measureReserve()

    Rectangle {
      x: hs.projection ? (parent.width - width) / 2 : 0
      width: stripText.width + 14 * hs.u; height: 14 * hs.u
      color: hs.sig
      Text {
        id: stripText
        anchors.centerIn: parent
        text: "VEDA STANDARD TIME"
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
        color: hs.panel
      }
    }
    Rectangle {
      y: 18 * hs.u
      width: parent.width; height: 60 * hs.u
      radius: height / 2
      color: Qt.alpha(hs.panel, 0.75)
      border.color: hs.sig
      border.width: 1.5 * hs.u

      // Thick left cap in gold, like the core.
      Shape {
        anchors.fill: parent
        ShapePath {
          strokeColor: hs.gold
          strokeWidth: 6 * hs.u
          fillColor: "transparent"
          capStyle: ShapePath.FlatCap
          PathAngleArc { centerX: 30 * hs.u; centerY: 30 * hs.u; radiusX: 24 * hs.u; radiusY: 24 * hs.u; startAngle: 110; sweepAngle: 140 }
        }
      }
      Row {
        id: clockRow
        anchors.verticalCenter: parent.verticalCenter
        x: 42 * hs.u
        spacing: 3 * hs.u
        Text {
          id: clockBig
          text: hs.slash(Qt.formatTime(clock.date, "h:mm AP").split(" ")[0])
          font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 36 * hs.u
          color: hs.textBright
        }
        Text {
          id: clockSecs
          anchors.baseline: clockBig.baseline
          text: "." + hs.slash(Qt.formatTime(clock.date, "ss")) + " " + Qt.formatTime(clock.date, "h AP").split(" ")[1]
          font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 16 * hs.u
          color: hs.sig
        }
      }
      Column {
        anchors.right: parent.right
        anchors.rightMargin: 22 * hs.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * hs.u
        Text {
          anchors.right: parent.right
          text: hs.slash(Qt.formatDate(clock.date, "yyyy.MM.dd"))
          font.family: "Michroma"; font.pixelSize: 8 * hs.u
          color: hs.sig
        }
        Text {
          id: clockDay
          anchors.right: parent.right
          text: Qt.formatDate(clock.date, "dddd").toUpperCase()
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: Qt.alpha(hs.sig, 0.8)
        }
      }
    }
  }

  // -------------------------------------------------- terminal log
  // Its own cached layer: it re-renders only while the newest line types in.
  Item {
    id: logPanel
    visible: !hs.projection
    x: rightPanel.x
    y: rightPanel.y + threads.y + threads.height + 14 * hs.u
    width: rightPanel.width
    height: hs.height - 60 * hs.u - y
    layer.enabled: true

    readonly property int typed: Math.max(0, (hs.t - hs.hud.logTick) * 3)

    Rectangle {
      id: logStrip
      width: logTitle.width + 12 * hs.u; height: 14 * hs.u
      color: hs.gold
      Text {
        id: logTitle
        anchors.centerIn: parent
        text: "VEDA://TERMINAL  LOG"
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
        color: hs.panel
      }
    }
    Rectangle {
      id: logBox
      y: 20 * hs.u
      width: parent.width; height: parent.height - 20 * hs.u
      color: Qt.alpha(hs.panel, 0.7)
      border.color: Qt.alpha(hs.sig, 0.35)
      border.width: 1
      clip: true

      // Newest at the bottom, just above the prompt; older lines scroll off the top.
      Column {
        x: 6 * hs.u
        width: parent.width - 12 * hs.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20 * hs.u
        spacing: 3 * hs.u
        Repeater {
          model: hs.logView
          Row {
            id: logRow
            required property var modelData
            required property int index
            readonly property bool newest: index === hs.logView.length - 1
            spacing: 5 * hs.u
            Text {
              text: logRow.modelData.stamp
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 * hs.u
              color: Qt.alpha(hs.sig, 0.7)   // 0.5 was 3.7:1; timestamps are what you scan by
            }
            Text {
              width: logBox.width - 48 * hs.u
              text: logRow.newest ? logRow.modelData.text.slice(0, logPanel.typed) : logRow.modelData.text
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 * hs.u
              color: logRow.newest ? hs.textBright : Qt.alpha(hs.sig, 0.75)
            }
          }
        }
      }
    }
  }

  // Prompt line with a blinking block cursor, outside the log's layer.
  Row {
    visible: !hs.projection
    x: logPanel.x + 6 * hs.u
    y: logPanel.y + logPanel.height - 16 * hs.u
    spacing: 4 * hs.u
    Text {
      text: "veda:// $"
      font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 * hs.u
      color: hs.sig
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 5 * hs.u; height: 8 * hs.u
      color: hs.sigBright
      visible: hs.t % 10 < 5
    }
  }

  // Link heartbeat: steady pulse when up, a fast flutter when unstable, and
  // a rare reacquire ping when severed.
  Rectangle {
    readonly property point p: { hs.width; hs.height; vedaDot.parent.x; vedaDot.parent.y; vedaDot.parent.width; linkChip.x; linkChip.y; linkChip.width; return vedaDot.mapToItem(hs, 0, 0) }
    x: p.x; y: p.y
    width: vedaDot.width; height: width; radius: width / 2
    color: hs.hud.link === "online" || hs.hud.link === "unknown" ? hs.sigBright : hs.linkColor
    visible: !hs.projection && (hs.hud.link === "local" ? hs.t % 6 < 3
      : hs.hud.link === "offline" ? hs.t % 30 < 3
      : hs.t % 16 < 10)
  }

  // Dashed rings turning around each donut.
  Repeater {
    model: [-1, 1]
    Shape {
      id: dring
      visible: !hs.projection
      required property int modelData
      readonly property real dr: hs.rad * 0.23
      width: dr * 2.4; height: width
      x: hs.cx + modelData * hs.rad * 0.67 - width / 2
      y: hs.cy - hs.rad * 0.6 - height / 2
      rotation: hs.t * 0.6 * modelData
      ShapePath {
        strokeColor: Qt.alpha(hs.sig, 0.5)
        strokeWidth: 1
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [1, 4]
        PathAngleArc { centerX: dring.dr * 1.2; centerY: dring.dr * 1.2; radiusX: dring.dr * 1.12; radiusY: dring.dr * 1.12; startAngle: 0; sweepAngle: 300 }
      }
    }
  }

  // Headlines panel in the left column (the HUD's only clickable area).
  property alias clickArea: newsPanel
  NewsPanel {
    id: newsPanel
    visible: !hs.projection && !hs.hud.calm
    x: 16 * hs.u
    y: 168 * hs.u
    width: 268 * hs.u
    height: hs.height - y - 56 * hs.u
    hud: hs.hud
    u: hs.u
    t: hs.t
    now: clock.date
  }

  // Display-link block shown in the news panel's place while calm.
  Item {
    x: newsPanel.x
    // Centred in the area the news panel leaves, so the left side isn't lopsided.
    y: newsPanel.y + Math.round((newsPanel.height - height) / 2)
    width: newsPanel.width
    height: 150 * hs.u
    visible: !hs.projection && hs.hud.calm

    Rectangle {
      width: dlTitle.width + 12 * hs.u; height: 14 * hs.u
      color: hs.gold
      Text {
        id: dlTitle
        anchors.centerIn: parent
        text: "VEDA://DISPLAY  LINK"
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
        color: hs.panel
      }
    }
    Rectangle {
      y: 20 * hs.u
      width: parent.width; height: parent.height - 20 * hs.u
      color: Qt.alpha(hs.panel, 0.7)
      border.color: Qt.alpha(hs.sig, 0.35)
      border.width: 1

      Column {
        x: 12 * hs.u; y: 10 * hs.u
        width: parent.width - 24 * hs.u
        spacing: 6 * hs.u
        Text {
          text: "MIRROR ACTIVE"
          font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 20 * hs.u
          font.letterSpacing: 1.5 * hs.u
          color: hs.textBright
        }
        Text {
          text: (hs.hud.mirrorOutput || "TEST OUTPUT") + (hs.hud.mirrorMode ? "  //  " + hs.slash(hs.hud.mirrorMode) : "")
          font.family: "Michroma"; font.pixelSize: 9 * hs.u; font.letterSpacing: 1 * hs.u
          color: hs.sig
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(hs.sig, 0.3) }
        Repeater {
          model: [["FEED", "HIDDEN"], ["BURST", "OFF"], ["FRAME RATE", "3 FPS"]]
          Item {
            required property var modelData
            width: parent.width; height: 12 * hs.u
            Text {
              text: modelData[0]
              font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
              color: Qt.alpha(hs.sig, 0.75)
            }
            Text {
              anchors.right: parent.right
              text: modelData[1]
              font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
              color: hs.gold
            }
          }
        }
      }
    }
  }

  // Burst banner.
  Item {
    id: burstFade
    anchors.fill: parent
    opacity: hs.burst ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 600 } }

    Rectangle {
      width: hs.width
      y: hs.ccy + hs.rad * 0.3 - height / 2
      height: 80 * hs.u
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.3; color: Qt.alpha("#b0620f", 0.55) }
        GradientStop { position: 0.7; color: Qt.alpha("#b0620f", 0.55) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      Column {
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "QUANTUM BURST"
          font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 46 * hs.u
          font.italic: true; font.letterSpacing: 4 * hs.u
          color: "#fffbe8"
          style: Text.Outline; styleColor: "#5a3005"
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "VEDA  //  FULL PROCESSING  //  ALL THREADS"
          font.family: "Michroma"; font.pixelSize: 8 * hs.u; font.letterSpacing: 2 * hs.u
          color: "#fff0c8"
        }
      }
    }
  }

}
