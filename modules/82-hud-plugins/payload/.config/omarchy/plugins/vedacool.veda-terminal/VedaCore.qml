import QtQuick
import QtQuick.Shapes

// VEDA's quantum core: the sphere grid, the rotating geodesic lattice with
// its counter-turning gold inner shell, the core glow and the two orbit rings.
// Shared by the desktop HUD (VedaScreen.qml) and the native screensaver
// (VedaScreensaver.qml), so both draw exactly the same core.
//
// The HUD keeps the sphere grid behind its cached gauge layer and the rest in
// front, so it uses two instances: part "grid" and part "core". Everything
// else uses part "all".
Item {
  id: core

  property string part: "all"
  property int t: 0                  // animation clock in ticks (10 per second)
  property real u: 1                 // layout scale (1 at 1366x768)
  property real rad: 100             // the HUD's gauge radius; the core scales from it
  property real ccx: width / 2
  property real ccy: height / 2
  readonly property real latR: rad * 0.46
  property bool fastSpin: false      // burst: the lattice turns faster
  property bool burst: false         // burst: the glow swells
  property bool offline: false       // link severed: dashed rings, no packets
  property real flash: 0             // 0..1 extra glow (screensaver charge-up)
  property color sig: "#6ee7a0"
  property color sigBright: "#c8ffd9"
  property color gold: "#e8c25a"
  readonly property int nodeCount: geo.outer.length

  // Frequency-2 geodesic sphere (42 nodes, 120 links) for the outer shell and
  // a plain icosahedron for the inner one, built once.
  readonly property var geo: {
    var p = (1 + Math.sqrt(5)) / 2
    var raw = [[-1, p, 0], [1, p, 0], [-1, -p, 0], [1, -p, 0], [0, -1, p], [0, 1, p],
               [0, -1, -p], [0, 1, -p], [p, 0, -1], [p, 0, 1], [-p, 0, -1], [-p, 0, 1]]
    function norm(v) { var l = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); return [v[0] / l, v[1] / l, v[2] / l] }
    var ico = raw.map(norm)
    var icoEdges = []
    for (var i = 0; i < 12; i++)
      for (var j = i + 1; j < 12; j++) {
        var dx = raw[i][0] - raw[j][0], dy = raw[i][1] - raw[j][1], dz = raw[i][2] - raw[j][2]
        if (Math.abs(dx * dx + dy * dy + dz * dz - 4) < 0.01) icoEdges.push([i, j])
      }
    var adj = ({})
    icoEdges.forEach(function(e) { adj[e[0] + "-" + e[1]] = true; adj[e[1] + "-" + e[0]] = true })
    var faces = []
    for (var a = 0; a < 12; a++)
      for (var b = a + 1; b < 12; b++)
        for (var c = b + 1; c < 12; c++)
          if (adj[a + "-" + b] && adj[b + "-" + c] && adj[a + "-" + c]) faces.push([a, b, c])

    var verts = ico.slice()
    var mid = ({})
    function midpoint(x, y) {
      var k = Math.min(x, y) + "-" + Math.max(x, y)
      if (mid[k] === undefined) {
        verts.push(norm([(ico[x][0] + ico[y][0]) / 2, (ico[x][1] + ico[y][1]) / 2, (ico[x][2] + ico[y][2]) / 2]))
        mid[k] = verts.length - 1
      }
      return mid[k]
    }
    var edges = []
    faces.forEach(function(f) {
      var ab = midpoint(f[0], f[1]), bc = midpoint(f[1], f[2]), ca = midpoint(f[2], f[0])
      edges.push([f[0], ab], [ab, f[1]], [f[1], bc], [bc, f[2]], [f[2], ca], [ca, f[0]], [ab, bc], [bc, ca], [ca, ab])
    })
    // Each face lists its outer half-edges, so shared ones appear twice; keep one.
    var seen = ({}), uniq = []
    edges.forEach(function(e) {
      var k = Math.min(e[0], e[1]) + "-" + Math.max(e[0], e[1])
      if (!seen[k]) { seen[k] = true; uniq.push(e) }
    })
    return { outer: verts, outerEdges: uniq, inner: ico, innerEdges: icoEdges }
  }

  // Spin accumulates so a burst speeds it up without the lattice jumping.
  property real spin: 0
  property int lastT: 0
  onTChanged: {
    if (part === "grid") return   // the grid copy never draws the lattice
    var dt = Math.max(0, Math.min(5, t - lastT))
    lastT = t
    spin += dt * (core.fastSpin ? 0.035 : 0.012)
  }

  function project(list, r, yaw, tilt) {
    var cy_ = Math.cos(yaw), sy = Math.sin(yaw), ct = Math.cos(tilt), st = Math.sin(tilt)
    var out = []
    for (var i = 0; i < list.length; i++) {
      var v = list[i]
      var x = v[0] * cy_ + v[2] * sy
      var z = -v[0] * sy + v[2] * cy_
      var y = v[1] * ct - z * st
      z = v[1] * st + z * ct
      out.push([core.ccx + x * r, core.ccy + y * r, z])
    }
    return out
  }

  // Back links dim, front links bright, front nodes as small squares.
  readonly property var proj: part === "grid" ? [] : project(geo.outer, latR, spin, 0.38)
  readonly property var lattice: {
    if (part === "grid") return { back: "M 0 0", front: "M 0 0", nodes: "M 0 0", inner: "M 0 0" }
    var o = proj
    var n = project(geo.inner, latR * 0.42, -spin * 1.6, -0.3)
    var back = "", front = "", nodes = "", inner = ""
    function f(v) { return v.toFixed(1) }
    geo.outerEdges.forEach(function(e) {
      var a = o[e[0]], b = o[e[1]]
      var seg = "M " + f(a[0]) + " " + f(a[1]) + " L " + f(b[0]) + " " + f(b[1]) + " "
      if (a[2] + b[2] > 0) front += seg; else back += seg
    })
    var s = 1.6 * u
    o.forEach(function(p) {
      if (p[2] > 0.05)
        nodes += "M " + f(p[0] - s) + " " + f(p[1] - s) + " h " + f(2 * s) + " v " + f(2 * s) + " h " + f(-2 * s) + " Z "
    })
    geo.innerEdges.forEach(function(e) {
      var a = n[e[0]], b = n[e[1]]
      inner += "M " + f(a[0]) + " " + f(a[1]) + " L " + f(b[0]) + " " + f(b[1]) + " "
    })
    return { back: back || "M 0 0", front: front || "M 0 0", nodes: nodes || "M 0 0", inner: inner || "M 0 0" }
  }

  // Sphere grid around the core with slowly turning meridians.
  Shape {
    id: grid
    visible: core.part !== "core"
    anchors.fill: parent
    opacity: 0.45
    readonly property real phase: core.t * 0.6 * Math.PI / 180
    readonly property real gr: core.rad * 0.8

    ShapePath {
      strokeColor: Qt.alpha(core.sig, 0.22)
      strokeWidth: 1
      fillColor: "transparent"
      PathAngleArc { centerX: core.ccx; centerY: core.ccy; radiusX: grid.gr; radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: core.ccx; centerY: core.ccy; radiusX: grid.gr; radiusY: core.rad * 0.22; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
      strokeColor: Qt.alpha(core.sig, 0.26)
      strokeWidth: 1
      fillColor: "transparent"
      PathAngleArc { centerX: core.ccx; centerY: core.ccy; radiusX: grid.gr * Math.abs(Math.sin(grid.phase)); radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
      PathAngleArc { centerX: core.ccx; centerY: core.ccy; radiusX: grid.gr * Math.abs(Math.sin(grid.phase + 1.571)); radiusY: grid.gr; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
      strokeColor: Qt.alpha(core.sig, 0.24)
      strokeWidth: 1
      fillColor: "transparent"
      startX: core.ccx - core.rad * 1.0; startY: core.ccy
      PathLine { x: core.ccx - core.rad * 0.84; y: core.ccy }
      PathMove { x: core.ccx + core.rad * 0.84; y: core.ccy }
      PathLine { x: core.ccx + core.rad * 1.0; y: core.ccy }
      PathMove { x: core.ccx; y: core.ccy - core.rad * 0.96 }
      PathLine { x: core.ccx; y: core.ccy - core.rad * 0.84 }
    }
  }

  // Data rings: two tilted orbits with a packet running along each.
  Repeater {
    model: core.part === "grid" ? [] : [{ tilt: -16, speed: 0.05, rx: 0.70, ry: 0.16 }, { tilt: 22, speed: -0.035, rx: 0.62, ry: 0.13 }]
    Item {
      id: orbit
      required property var modelData
      readonly property real rx: core.rad * modelData.rx
      readonly property real ry: core.rad * modelData.ry
      readonly property real phi: core.t * modelData.speed
      anchors.fill: parent

      Shape {
        width: orbit.rx * 2 + 4; height: orbit.ry * 2 + 4
        x: core.ccx - width / 2; y: core.ccy - height / 2
        rotation: orbit.modelData.tilt
        ShapePath {
          // Severed: the rings go dashed and the packets stop flowing.
          strokeColor: Qt.alpha(core.gold, core.offline ? 0.35 : 0.45)
          strokeWidth: 1.2 * core.u
          fillColor: "transparent"
          strokeStyle: core.offline ? ShapePath.DashLine : ShapePath.SolidLine
          dashPattern: [6, 6]
          PathAngleArc { centerX: orbit.rx + 2; centerY: orbit.ry + 2; radiusX: orbit.rx; radiusY: orbit.ry; startAngle: 0; sweepAngle: 360 }
        }
      }
      Rectangle {
        readonly property real a: orbit.modelData.tilt * Math.PI / 180
        readonly property real ex: orbit.rx * Math.cos(orbit.phi)
        readonly property real ey: orbit.ry * Math.sin(orbit.phi)
        width: 5 * core.u; height: width; radius: width / 2
        x: core.ccx + ex * Math.cos(a) - ey * Math.sin(a) - width / 2
        y: core.ccy + ex * Math.sin(a) + ey * Math.cos(a) - height / 2
        color: core.sigBright
        visible: !core.offline
      }
    }
  }

  // Core glow, pulsing gently (scale only, so it doesn't re-tessellate).
  Shape {
    id: glow
    visible: core.part !== "grid"
    readonly property real gr: core.rad * 0.2
    width: gr * 2; height: gr * 2
    x: core.ccx - gr; y: core.ccy - gr
    scale: 0.88 + 0.12 * Math.sin(core.t * 0.12) + (core.burst ? 0.15 : 0) + 0.35 * core.flash
    ShapePath {
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: glow.gr; centerY: glow.gr; centerRadius: glow.gr
        focalX: glow.gr; focalY: glow.gr
        GradientStop { position: 0.0; color: Qt.alpha(core.sigBright, 0.95) }
        GradientStop { position: 0.18; color: Qt.alpha(core.gold, 0.75) }
        GradientStop { position: 0.55; color: Qt.alpha(core.gold, 0.18) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      PathAngleArc { centerX: glow.gr; centerY: glow.gr; radiusX: glow.gr; radiusY: glow.gr; startAngle: 0; sweepAngle: 360 }
    }
  }

  // The lattice itself: four batched paths for ~170 links and nodes.
  Shape {
    visible: core.part !== "grid"
    anchors.fill: parent
    ShapePath {
      strokeColor: Qt.alpha(core.sig, 0.16)
      strokeWidth: 1
      fillColor: "transparent"
      PathSvg { path: core.lattice.back }
    }
    ShapePath {
      strokeColor: Qt.alpha(core.gold, 0.55)
      strokeWidth: 1
      fillColor: "transparent"
      PathSvg { path: core.lattice.inner }
    }
    ShapePath {
      strokeColor: Qt.alpha(core.sig, 0.6)
      strokeWidth: 1.1 * core.u
      fillColor: "transparent"
      PathSvg { path: core.lattice.front }
    }
    ShapePath {
      strokeColor: "transparent"
      fillColor: core.sigBright
      PathSvg { path: core.lattice.nodes }
    }
  }
}
