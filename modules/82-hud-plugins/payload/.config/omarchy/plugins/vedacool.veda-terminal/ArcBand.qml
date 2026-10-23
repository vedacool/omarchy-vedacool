import QtQuick
import QtQuick.Shapes

// Segmented arc band, like the Twin Drive particle gauge. Angles are in
// degrees, clockwise from 3 o'clock; a negative sweep runs counter-clockwise.
//
// All lit segments share one path and all unlit ones another, so a band is
// two draw calls however many segments it has — on the legacy radeon driver
// one Shape per segment cost ~15% CPU across the HUD.
Shape {
  id: band

  property real cx: 0
  property real cy: 0
  property real rOuter: 100
  property real rInner: 80
  property real startAngle: 0
  property real sweep: 90
  property int segments: 20
  property real gap: 1.4
  property real value: 0
  property color colorLow: "cyan"
  property color colorHigh: "blue"
  property color colorOff: "#20ffffff"

  readonly property int litCount: Math.max(0, Math.min(segments, Math.floor(value * segments + 0.5)))

  function pt(r, deg) {
    var a = deg * Math.PI / 180
    return (cx + r * Math.cos(a)).toFixed(2) + " " + (cy + r * Math.sin(a)).toFixed(2)
  }

  function segPath(from, to) {
    var step = sweep / segments
    var half = (step > 0 ? gap : -gap) / 2
    var cw = step > 0 ? 1 : 0
    var d = ""
    for (var i = from; i < to; i++) {
      var a0 = startAngle + i * step + half
      var a1 = a0 + step - 2 * half
      d += "M " + pt(rOuter, a0)
        + " A " + rOuter + " " + rOuter + " 0 0 " + cw + " " + pt(rOuter, a1)
        + " L " + pt(rInner, a1)
        + " A " + rInner + " " + rInner + " 0 0 " + (1 - cw) + " " + pt(rInner, a0)
        + " Z "
    }
    return d
  }

  readonly property real midR: (rOuter + rInner) / 2
  readonly property real ga: startAngle * Math.PI / 180
  // A full ring would give a zero-length gradient; run it across instead.
  readonly property real gb: (startAngle + (Math.abs(sweep) >= 359 ? 180 : sweep)) * Math.PI / 180

  ShapePath {
    strokeColor: "transparent"
    fillGradient: LinearGradient {
      x1: band.cx + band.midR * Math.cos(band.ga); y1: band.cy + band.midR * Math.sin(band.ga)
      x2: band.cx + band.midR * Math.cos(band.gb); y2: band.cy + band.midR * Math.sin(band.gb)
      GradientStop { position: 0; color: band.colorLow }
      GradientStop { position: 1; color: band.colorHigh }
    }
    PathSvg { path: band.segPath(0, band.litCount) }
  }

  ShapePath {
    strokeColor: "transparent"
    fillColor: band.colorOff
    PathSvg { path: band.segPath(band.litCount, band.segments) }
  }
}
