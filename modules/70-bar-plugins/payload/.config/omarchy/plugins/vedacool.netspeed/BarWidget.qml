import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Live download/upload throughput, sampled from the default route
// interface's /sys/class/net counters — cheap enough to poll continuously,
// unlike omarchy-network-status which also probes latency.
BarWidget {
  id: root
  moduleName: "vedacool.netspeed"

  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real prevSampleTime: 0
  property string prevIface: ""
  property real downloadRate: 0  // bytes/sec
  property real uploadRate: 0    // bytes/sec
  property bool hasSample: false

  readonly property string displayText: hasSample
    ? ("↓" + formatRate(downloadRate) + " ↑" + formatRate(uploadRate))
    : "↓-- ↑--"

  function formatRate(bytesPerSec) {
    var kb = bytesPerSec / 1024
    if (kb >= 1024) {
      var mb = kb / 1024
      return mb.toFixed(mb < 10 ? 1 : 0) + "MB/s"
    }
    return kb.toFixed(kb < 10 ? 1 : 0) + "KB/s"
  }

  function refresh() {
    if (!sampleProc.running) sampleProc.running = true
  }

  function updateSample(raw) {
    var lines = String(raw || "").split("\n")
    var data = {}
    for (var i = 0; i < lines.length; i++) {
      var idx = lines[i].indexOf("\t")
      if (idx === -1) continue
      data[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
    }

    var iface = data.iface || ""
    var now = Date.now() / 1000

    if (!iface) {
      hasSample = false
      prevSampleTime = 0
      return
    }

    var rx = parseFloat(data.rx_bytes || "0")
    var tx = parseFloat(data.tx_bytes || "0")

    // First sample after startup or an interface switch has no prior point
    // to diff against, so it reports 0 rather than a manufactured spike.
    if (iface !== prevIface || prevSampleTime === 0) {
      prevIface = iface
      prevRxBytes = rx
      prevTxBytes = tx
      prevSampleTime = now
      downloadRate = 0
      uploadRate = 0
      hasSample = true
      return
    }

    var dt = now - prevSampleTime
    if (dt > 0) {
      downloadRate = Math.max(0, (rx - prevRxBytes) / dt)
      uploadRate = Math.max(0, (tx - prevTxBytes) / dt)
    }

    prevIface = iface
    prevRxBytes = rx
    prevTxBytes = tx
    prevSampleTime = now
    hasSample = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: sampleProc
    command: ["bash", "-c",
      "iface=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i==\"dev\"){print $(i+1);exit}}'); " +
      "[ -z \"$iface\" ] && iface=$(ip -6 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i==\"dev\"){print $(i+1);exit}}'); " +
      "if [ -n \"$iface\" ] && [ -r \"/sys/class/net/$iface/statistics/rx_bytes\" ]; then " +
      "printf 'iface\\t%s\\n' \"$iface\"; " +
      "printf 'rx_bytes\\t%s\\n' \"$(cat /sys/class/net/$iface/statistics/rx_bytes)\"; " +
      "printf 'tx_bytes\\t%s\\n' \"$(cat /sys/class/net/$iface/statistics/tx_bytes)\"; " +
      "fi"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateSample(text)
    }
  }

  Timer {
    interval: 1500
    // Don't fork the sampler while the pill is hidden (e.g. bar auto-hidden).
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: "Network throughput (↓ download ↑ upload)"
    pressable: false
  }
}
