import Quickshell
import QtQuick
import QtQuick.Shapes

// One screen's worth of HUD, laid out after the Celestial Being drive-status
// screen: a U-shaped particle gauge around the Exia hologram, two donut
// readouts at its shoulders, a readout plate at the bottom, softkey columns on
// both edges, and data panels in between.
//
// Rendering budget: everything that only changes when data arrives (every
// 2s) or on a blink lives in `staticLayer`, which Qt caches as one texture.
// Only the few moving pieces outside it are redrawn every animation tick.
Item {
  id: hs

  property var hud

  readonly property real u: Math.min(width / 1366, height / 768)
  readonly property real cx: width / 2
  readonly property real cy: height * 0.54
  readonly property real rad: height * 0.35
  readonly property int t: hud.tick

  // Celestial Being screens print zeros slashed.
  function slash(s) { return String(s).replace(/0/g, "Ø") }
  function pad(n, w) { var s = String(Math.round(n)); while (s.length < w) s = "0" + s; return s }
  function polar(r, deg) { var a = deg * Math.PI / 180; return { x: hs.cx + r * Math.cos(a), y: hs.cy + r * Math.sin(a) } }

  readonly property real labelPx: 7 * u   // smallest text; anything below ~7px is unreadable at 1366x768

  Connections {
    target: hs.hud
    function onSnapshotRequested(path) {
      hs.grabToImage(function(result) { result.saveToFile(path) })
    }
  }

  SystemClock {
    id: clock
    // Stop the per-second tick (and the pill/date/news bindings it drives) when
    // the HUD is paused/hidden — the rest of the HUD already freezes via `running`.
    enabled: hs.hud.running
    precision: SystemClock.Seconds
  }

  // ============================================================ animated: back
  // Static sphere-grid rings + crosshair, in their OWN Shape. A QtQuick Shape
  // re-triangulates whenever ANY of its ShapePaths changes, so keeping these
  // constant rings in the same Shape as the moving meridians rebuilt the whole
  // grid every tick on the weak r600 GPU. Split out, this geometry tessellates
  // once (on resize) and is reused each frame. Same z-order as before.
  Shape {
    id: gridStatic
    anchors.fill: parent
    opacity: 0.55
    readonly property real gr: hs.rad * 0.8

    ShapePath {
      strokeColor: Qt.alpha(hs.hud.cyan, 0.22)
      strokeWidth: 1
      fillColor: "transparent"
      PathAngleArc { centerX: hs.cx; centerY: hs.cy; radiusX: gridStatic.gr; radiusY: gridStatic.gr; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: hs.cx; centerY: hs.cy; radiusX: gridStatic.gr; radiusY: hs.rad * 0.22; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: hs.cx; centerY: hs.cy - hs.rad * 0.45; radiusX: hs.rad * 0.66; radiusY: hs.rad * 0.16; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: hs.cx; centerY: hs.cy + hs.rad * 0.45; radiusX: hs.rad * 0.66; radiusY: hs.rad * 0.16; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
      strokeColor: Qt.alpha(hs.hud.cyan, 0.28)
      strokeWidth: 1
      fillColor: "transparent"
      startX: hs.cx - hs.rad * 1.12; startY: hs.cy
      PathLine { x: hs.cx + hs.rad * 1.12; y: hs.cy }
      PathMove { x: hs.cx; y: hs.cy - hs.rad * 1.2 }
      PathLine { x: hs.cx; y: hs.cy + hs.rad * 1.2 }
    }
  }

  // Slowly turning meridians only — the sole per-tick tessellation here now.
  Shape {
    id: grid
    anchors.fill: parent
    opacity: 0.55
    readonly property real phase: hs.t * 0.9 * Math.PI / 180
    readonly property real gr: hs.rad * 0.8

    ShapePath {
      strokeColor: Qt.alpha(hs.hud.cyan, 0.30)
      strokeWidth: 1
      fillColor: "transparent"
      PathAngleArc { centerX: hs.cx; centerY: hs.cy; radiusX: grid.gr * Math.abs(Math.sin(grid.phase)); radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: hs.cx; centerY: hs.cy; radiusX: grid.gr * Math.abs(Math.sin(grid.phase + 1.047)); radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: hs.cx; centerY: hs.cy; radiusX: grid.gr * Math.abs(Math.sin(grid.phase + 2.094)); radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
    }
  }

  // Hologram rings, rotating about the gauge centre.
  Shape {
    width: hs.rad * 3; height: width; x: hs.cx - width / 2; y: hs.cy - height / 2
    rotation: hs.t * 0.25
    ShapePath {
      strokeColor: Qt.alpha(hs.hud.cyan, 0.35)
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
      strokeColor: Qt.alpha(hs.hud.cyanBright, 0.35)
      strokeWidth: 3 * hs.u
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 10; sweepAngle: 50 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 130; sweepAngle: 20 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 190; sweepAngle: 50 }
      PathAngleArc { centerX: hs.rad * 1.5; centerY: hs.rad * 1.5; radiusX: hs.rad * 1.23; radiusY: hs.rad * 1.23; startAngle: 310; sweepAngle: 20 }
    }
  }


  // Trans-Am split ring: behind the static layer so readouts stay on top.
  Shape {
    width: hs.rad * 3; height: width; x: hs.cx - width / 2; y: hs.cy - height / 2
    rotation: hs.t * 0.8
    opacity: transAmFade.opacity * (0.6 + 0.4 * Math.abs(Math.sin(hs.t * 0.15)))
    visible: opacity > 0
    ShapePath {
      strokeColor: "#c9c3f4"
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

    // Crosshair end markers.
    Repeater {
      model: [[-1.12, 0], [1.12, 0], [0, -1.2], [0, 1.2]]
      Rectangle {
        required property var modelData
        width: 6 * hs.u; height: width
        x: hs.cx + modelData[0] * hs.rad - width / 2
        y: hs.cy + modelData[1] * hs.rad - height / 2
        color: "transparent"
        border.color: Qt.alpha(hs.hud.cyan, 0.6)
        border.width: 1
      }
    }

    // -------------------------------------------------- particle gauge
    ArcBand {
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad; rInner: hs.rad * 0.86
      startAngle: 100; sweep: 108; segments: 24
      value: hs.hud.cpu / 100
      colorLow: hs.hud.cyan; colorHigh: hs.hud.blue
      colorOff: Qt.alpha(hs.hud.cyan, 0.10)
    }
    ArcBand {
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad * 0.84; rInner: hs.rad * 0.81
      startAngle: 100; sweep: 108; segments: 48; gap: 0.8
      value: hs.hud.cpu / 100
      colorLow: hs.hud.cyanBright; colorHigh: hs.hud.cyanBright
      colorOff: Qt.alpha(hs.hud.cyan, 0.08)
    }
    ArcBand {
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad; rInner: hs.rad * 0.86
      startAngle: 80; sweep: -108; segments: 24
      value: hs.hud.mem / 100
      colorLow: hs.hud.cyan; colorHigh: hs.hud.blue
      colorOff: Qt.alpha(hs.hud.cyan, 0.10)
    }
    ArcBand {
      anchors.fill: parent
      cx: hs.cx; cy: hs.cy
      rOuter: hs.rad * 0.84; rInner: hs.rad * 0.81
      startAngle: 80; sweep: -108; segments: 48; gap: 0.8
      value: hs.hud.mem / 100
      colorLow: hs.hud.cyanBright; colorHigh: hs.hud.cyanBright
      colorOff: Qt.alpha(hs.hud.cyan, 0.08)
    }

    // Scale ticks: one path for all ten, then labels.
    Shape {
      anchors.fill: parent
      ShapePath {
        strokeColor: Qt.alpha(hs.hud.cyan, 0.8)
        strokeWidth: 1.5 * hs.u
        fillColor: "transparent"
        PathSvg {
          path: {
            var d = ""
            var marks = [0, 30, 50, 80, 100]
            for (var s = 0; s < 2; s++) {
              for (var i = 0; i < marks.length; i++) {
                var ang = s === 0 ? 100 + 108 * marks[i] / 100 : 80 - 108 * marks[i] / 100
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
        required property int index
        required property int modelData
        readonly property var pl: hs.polar(hs.rad * 1.12, index < 5 ? 100 + 108 * modelData / 100 : 80 - 108 * modelData / 100)
        x: pl.x - width / 2; y: pl.y - height / 2
        text: hs.slash(modelData)
        font.family: "Michroma"; font.pixelSize: 9 * hs.u
        color: Qt.alpha(hs.hud.cyan, 0.85)
      }
    }

    // CPU (left) and MEM (right) readouts, outside the gauge's upper ends.
    Repeater {
      model: [{ label: "CPU LOAD", side: -1 }, { label: "MEMORY", side: 1 }]
      Item {
        id: readout
        required property var modelData
        x: modelData.side < 0 ? hs.cx - hs.rad * 0.97 - width : hs.cx + hs.rad * 0.97
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
            color: hs.hud.textBright
          }
          Text {
            anchors.baseline: readoutNum.baseline
            text: "%"
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 14 * hs.u
            color: hs.hud.cyan
          }
        }
        Text {
          anchors.right: readout.modelData.side < 0 ? parent.right : undefined
          anchors.left: readout.modelData.side > 0 ? parent.left : undefined
          anchors.bottom: parent.bottom
          text: readout.modelData.label
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.5 * hs.u
          color: Qt.alpha(hs.hud.cyan, 0.8)
        }
      }
    }

    // -------------------------------------------------- Exia hologram
    Image {
      id: exia
      height: hs.rad * 1.46
      width: height * 507 / 1000
      x: hs.cx - width / 2
      y: hs.cy - hs.rad * 0.9
      // Trans-Am tint is a pre-rendered sprite swap, NOT a MultiEffect. A
      // runtime-generated colorization shader + its FBO, created/destroyed on
      // this legacy Radeon (Mesa r600g) exactly when CPU is already pegged
      // (Trans-Am engages on sustained high load), is a known segfault / GPU-
      // reset vector. Swapping to an already-tinted texture is a cached, zero-
      // shader operation. exia-transam.png = exia.png colorized 85% -> #ff4fe6
      // with +10% brightness (ImageMagick), matching the old effect.
      source: Qt.resolvedUrl(hs.hud.transAm ? "exia-transam.png" : "exia.png")
      sourceSize.height: height
      smooth: true
      mipmap: true
      opacity: 0.95
    }

    // -------------------------------------------------- donut readouts
    Repeater {
      model: [
        { side: -1, head: "SENSOR", tag: "CORE", unit: "°C", warnAt: 85 },
        { side: 1, head: "GN DRIVE", tag: "FAN", unit: "%", warnAt: 101 }
      ]
      Item {
        id: donut
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
          color: Qt.alpha(hs.hud.panel, 0.8)
          border.color: Qt.alpha(hs.hud.cyan, 0.35)
          border.width: 1
        }
        ArcBand {
          anchors.fill: parent
          cx: donut.dcx; cy: donut.dcy
          rOuter: donut.dr; rInner: donut.dr * 0.82
          startAngle: -90; sweep: 360; segments: 30; gap: 2
          value: Math.min(1, donut.val / 100)
          colorLow: donut.hot ? hs.hud.warn : hs.hud.cyan
          colorHigh: donut.hot ? hs.hud.warn : hs.hud.cyanBright
          colorOff: Qt.alpha(hs.hud.cyan, 0.12)
        }
        Column {
          x: donut.dcx - width / 2
          y: donut.dcy - height / 2
          spacing: 2 * hs.u
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: donut.modelData.head
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 0.5 * hs.u
            color: hs.hud.cyan
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tagText.width + 8 * hs.u; height: tagText.height + 2 * hs.u
            color: donut.hot ? hs.hud.warn : hs.hud.cyan
            Text {
              id: tagText
              anchors.centerIn: parent
              text: donut.modelData.tag
              font.family: "Michroma"; font.pixelSize: hs.labelPx
              color: hs.hud.panel
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: hs.slash(hs.pad(donut.val, 2)) + donut.modelData.unit
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 20 * hs.u
            color: donut.hot ? hs.hud.warn : hs.hud.textBright
          }
        }
      }
    }

    // -------------------------------------------------- softkeys
    Repeater {
      model: 18
      SoftKey {
        required property int index
        readonly property bool onLeft: index < 9
        readonly property int row: index % 9
        hud: hs.hud
        u: hs.u
        width: hs.keyW; height: hs.keyH
        x: onLeft ? 16 * hs.u : hs.width - 16 * hs.u - width
        y: 64 * hs.u + row * (hs.keyH + hs.keyGap)
        code: (onLeft ? hs.leftKeys : hs.rightKeys)[row][0]
        caption: (onLeft ? hs.leftKeys : hs.rightKeys)[row][1]
        lit: !onLeft && row === 3 && hs.hud.transAm
      }
    }

    // -------------------------------------------------- right panel
    Item {
      id: rightPanel
      width: 240 * hs.u
      x: hs.width - 96 * hs.u - width
      y: 64 * hs.u
      height: hs.height - y - 60 * hs.u

      Column {
        width: parent.width
        spacing: 4 * hs.u

        Text {
          anchors.right: parent.right
          text: "CELESTIAL BEING"
          font.family: "Michroma"; font.pixelSize: 15 * hs.u; font.letterSpacing: 2 * hs.u
          color: hs.hud.textBright
        }
        Rectangle { width: parent.width; height: 1.5 * hs.u; color: hs.hud.gold }
        Row {
          anchors.right: parent.right
          spacing: 6 * hs.u
          Rectangle {
            id: vedaDot
            anchors.verticalCenter: parent.verticalCenter
            width: 6 * hs.u; height: width; radius: width / 2
            color: "transparent"
            border.color: hs.hud.cyan; border.width: 1
          }
          Text {
            text: "VEDA LINK ESTABLISHED"
            font.family: "Michroma"; font.pixelSize: 7.5 * hs.u; font.letterSpacing: 1 * hs.u
            color: hs.hud.cyan
          }
        }
        Text {
          anchors.right: parent.right
          text: "TERMINAL  " + String(hs.hud.hostname).toUpperCase()
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: Qt.alpha(hs.hud.cyan, 0.8)
        }
        Text {
          anchors.right: parent.right
          readonly property int up: hs.hud.uptime
          text: "OPERATION  " + hs.slash(hs.pad(Math.floor(up / 3600), 3) + ":" + hs.pad(Math.floor(up % 3600 / 60), 2))
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: Qt.alpha(hs.hud.cyan, 0.8)
        }
      }

      // CPU history bar chart: 40 samples x 2s.
      Item {
        id: chart
        y: 100 * hs.u
        width: parent.width
        height: 130 * hs.u

        Rectangle {
          width: chartTitle.width + 12 * hs.u; height: 14 * hs.u
          color: hs.hud.cyan
          Text {
            id: chartTitle
            anchors.centerIn: parent
            text: "GN PARTICLE OUTPUT  //  8Ø SEC"
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.hud.panel
          }
        }
        Rectangle {
          y: 20 * hs.u
          width: parent.width; height: parent.height - 20 * hs.u
          color: Qt.alpha(hs.hud.panel, 0.65)
          border.color: Qt.alpha(hs.hud.cyan, 0.35)
          border.width: 1

          Repeater {
            model: 4
            Rectangle {
              required property int index
              y: parent.height * (index + 1) / 5
              width: parent.width; height: 1
              color: Qt.alpha(hs.hud.cyan, 0.10)
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
                height: Math.max(1, (chart.height - 28 * hs.u) * v / 100)
                color: v > 85 ? hs.hud.gold : (index === 39 ? hs.hud.cyanBright : Qt.alpha(hs.hud.cyan, 0.75))
              }
            }
          }
        }
      }

      // Per-thread bars.
      Column {
        y: chart.y + chart.height + 16 * hs.u
        width: parent.width
        spacing: 5 * hs.u

        Rectangle {
          width: coreTitle.width + 12 * hs.u; height: 14 * hs.u
          color: hs.hud.cyan
          Text {
            id: coreTitle
            anchors.centerIn: parent
            text: "PROCESSOR THREADS"
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.hud.panel
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
              color: Qt.alpha(hs.hud.cyan, 0.85)
            }
            Item {
              width: rightPanel.width - 70 * hs.u; height: 8 * hs.u
              anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.fill: parent; color: Qt.alpha(hs.hud.cyan, 0.10) }
              Rectangle {
                height: parent.height
                width: parent.width * coreRow.v / 100
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: hs.hud.cyan }
                  GradientStop { position: 1; color: hs.hud.blue }
                }
              }
            }
            Text {
              width: 28 * hs.u
              horizontalAlignment: Text.AlignRight
              text: hs.slash(hs.pad(coreRow.v, 2))
              font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 8 * hs.u
              color: hs.hud.textBright
            }
          }
        }
      }
    }

    // -------------------------------------------------- bottom strip
    Item {
      x: 96 * hs.u
      width: hs.width - 192 * hs.u
      y: hs.height - 34 * hs.u
      height: 20 * hs.u

      Rectangle { width: parent.width; height: 1; color: Qt.alpha(hs.hud.cyan, 0.4) }
      Text {
        y: 6 * hs.u
        text: "GN-ØØ1  GUNDAM EXIA  //  CELESTIAL BEING MOBILE SUIT"
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.2 * hs.u
        color: Qt.alpha(hs.hud.cyan, 0.75)
      }
      Text {
        anchors.right: parent.right
        y: 6 * hs.u
        text: "KERNEL " + hs.slash(String(hs.hud.kernel).toUpperCase())
        font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1.2 * hs.u
        color: Qt.alpha(hs.hud.cyan, 0.75)
      }
    }
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
        width: batRow.width + 18 * hs.u; height: 46 * hs.u
        radius: height / 2
        color: Qt.alpha(hs.hud.panel, 0.9)
      }
      Row {
        id: batRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 4 * hs.u
        Text {
          id: batBig
          text: hs.slash(hs.pad(hs.hud.battery, 2))
          font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 44 * hs.u
          color: hs.hud.battery <= 15 && hs.t % 14 < 7 ? hs.hud.warn : hs.hud.textBright
        }
        Text {
          anchors.baseline: batBig.baseline
          text: "%"
          font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 16 * hs.u
          color: hs.hud.cyan
        }
        // Plain-language tag so the themed plate below still reads as battery.
        Rectangle {
          anchors.verticalCenter: batBig.verticalCenter
          width: batTag.width + 10 * hs.u; height: batTag.height + 4 * hs.u
          color: hs.hud.battery <= 15 ? hs.hud.warn : hs.hud.cyan
          Text {
            id: batTag
            anchors.centerIn: parent
            text: "BATTERY"
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: hs.hud.panel
          }
        }
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width; height: 30 * hs.u
        radius: 4 * hs.u
        color: Qt.alpha(hs.hud.panel, 0.9)
        border.color: hs.hud.cyan
        border.width: 1.2 * hs.u
        Column {
          anchors.centerIn: parent
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GN CONDENSER"
            font.family: "Michroma"; font.pixelSize: 9 * hs.u; font.letterSpacing: 1 * hs.u
            color: hs.hud.textBright
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property bool charging: hs.hud.batteryStatus === "Charging"
            text: charging ? "PARTICLES CHARGING" : "PARTICLES REMAINING"
            font.family: "Michroma"; font.pixelSize: hs.labelPx * 0.9; font.letterSpacing: 0.8 * hs.u
            color: charging && hs.t % 20 < 10 ? hs.hud.gold : Qt.alpha(hs.hud.cyan, 0.85)
          }
        }
      }
    }

    // -------------------------------------------------- clock pill
    Item {
      x: 96 * hs.u
      y: 64 * hs.u
      width: 300 * hs.u
      height: 84 * hs.u

      Rectangle {
        width: stripText.width + 14 * hs.u; height: 14 * hs.u
        color: hs.hud.cyan
        Text {
          id: stripText
          anchors.centerIn: parent
          text: "MISSION TIME  //  CB-STD"
          font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
          color: hs.hud.panel
        }
      }
      Rectangle {
        y: 18 * hs.u
        width: parent.width; height: 60 * hs.u
        radius: height / 2
        color: Qt.alpha(hs.hud.panel, 0.75)
        border.color: hs.hud.cyan
        border.width: 1.5 * hs.u

        // Thick left cap, as on the drive SYS readout.
        Shape {
          anchors.fill: parent
          ShapePath {
            strokeColor: hs.hud.cyan
            strokeWidth: 6 * hs.u
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: 30 * hs.u; centerY: 30 * hs.u; radiusX: 24 * hs.u; radiusY: 24 * hs.u; startAngle: 110; sweepAngle: 140 }
          }
        }
        Row {
          anchors.verticalCenter: parent.verticalCenter
          x: 42 * hs.u
          spacing: 3 * hs.u
          Text {
            id: clockBig
            text: hs.slash(Qt.formatTime(clock.date, "h:mm AP").split(" ")[0])
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 36 * hs.u
            color: hs.hud.textBright
          }
          Text {
            anchors.baseline: clockBig.baseline
            text: "." + hs.slash(Qt.formatTime(clock.date, "ss")) + " " + Qt.formatTime(clock.date, "h AP").split(" ")[1]
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 16 * hs.u
            color: hs.hud.cyan
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
            color: hs.hud.cyan
          }
          Text {
            anchors.right: parent.right
            text: Qt.formatDate(clock.date, "dddd").toUpperCase()
            font.family: "Michroma"; font.pixelSize: hs.labelPx; font.letterSpacing: 1 * hs.u
            color: Qt.alpha(hs.hud.cyan, 0.8)
          }
        }
      }
    }


    // Roaming softkey highlight.
    Rectangle {
      readonly property bool onLeft: hs.litKey < 9
      width: hs.keyW; height: hs.keyH
      x: onLeft ? 16 * hs.u : hs.width - 16 * hs.u - width
      y: 64 * hs.u + (hs.litKey % 9) * (hs.keyH + hs.keyGap)
      radius: 6 * hs.u
      color: Qt.alpha(hs.hud.cyan, 0.28)
      border.width: Math.max(1, 1.4 * hs.u)
      border.color: hs.hud.cyanBright
    }

    // VEDA link heartbeat.
    Rectangle {
      readonly property point p: { hs.width; hs.height; vedaDot.parent.x; vedaDot.parent.y; vedaDot.parent.width; return vedaDot.mapToItem(hs, 0, 0) }
      x: p.x; y: p.y
      width: vedaDot.width; height: width; radius: width / 2
      color: hs.hud.cyanBright
      visible: hs.t % 16 < 10
    }

  // ============================================================ animated: front
  // Scan line sweeping down the hologram.
  Item {
    x: exia.x; y: exia.y; width: exia.width; height: exia.height
    clip: true
    Rectangle {
      width: parent.width
      height: 3 * hs.u
      y: (hs.t * 4 * hs.u) % (parent.height + 60 * hs.u) - 30 * hs.u
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Qt.alpha(hs.hud.cyanBright, 0.85) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
  }

  // Dashed rings turning around each donut.
  Repeater {
    model: [-1, 1]
    Shape {
      id: dring
      required property int modelData
      readonly property real dr: hs.rad * 0.23
      width: dr * 2.4; height: width
      x: hs.cx + modelData * hs.rad * 0.67 - width / 2
      y: hs.cy - hs.rad * 0.6 - height / 2
      rotation: hs.t * 0.6 * modelData
      ShapePath {
        strokeColor: Qt.alpha(hs.hud.cyan, 0.5)
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
    x: 96 * hs.u
    y: 168 * hs.u
    width: 200 * hs.u
    height: hs.height - y - 56 * hs.u
    hud: hs.hud
    u: hs.u
    t: hs.t
    now: clock.date
  }

  // Trans-Am banner.
  Item {
    id: transAmFade
    anchors.fill: parent
    opacity: hs.hud.transAm ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 600 } }

    Rectangle {
      width: hs.width
      y: hs.cy + hs.rad * 0.2 - height / 2
      height: 86 * hs.u
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.3; color: Qt.alpha("#cf16c0", 0.55) }
        GradientStop { position: 0.7; color: Qt.alpha("#cf16c0", 0.55) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      Column {
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "TRANS-AM"
          font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 54 * hs.u
          font.italic: true; font.letterSpacing: 4 * hs.u
          color: "#fff0fd"
          style: Text.Outline; styleColor: "#640f59"
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "SYSTEM  //  MODE ACT  //  PARTICLE RELEASE"
          font.family: "Michroma"; font.pixelSize: 8 * hs.u; font.letterSpacing: 2 * hs.u
          color: "#ffe0fb"
        }
      }
    }
  }

  // ------------------------------------------------------------ softkey data
  readonly property var leftKeys: [["TAR", "TARGET"], ["TLD", "TELEMETRY"], ["HOR", "HORIZON"], ["OFT", "OFFSET"], ["MS", "MOBILE SUIT"], ["GND", "GN DRIVE"], ["SMS", "SYS MSG"], ["FNC", "FUNCTION"], ["LNK", "DATA LINK"]]
  readonly property var rightKeys: [["GNS", "GN SWORD"], ["VDA", "VEDA"], ["PTL", "PTOLEMAIOS"], ["TRS", "TRANS-AM"], ["HRO", "HARO"], ["CBS", "CELESTIAL"], ["ORB", "ORBIT"], ["DFS", "DEFENSE"], ["SYS", "SYSTEM"]]
  readonly property real keyW: 62 * u
  readonly property real keyH: 38 * u
  readonly property real keyGap: (height - 110 * u - 9 * keyH) / 8
  // A pseudo-random key lights every ~2s, as if someone is working the console.
  readonly property int litKey: Math.floor(t / 30) * 7 % 18
}
