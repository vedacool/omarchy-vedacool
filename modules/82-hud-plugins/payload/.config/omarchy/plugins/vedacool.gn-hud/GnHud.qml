import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Gundam 00 Twin Drive HUD drawn on the bottom layer: above the wallpaper,
// below windows, click-through. Only runs while the gundam-00-raiser theme is
// active, so switching themes stops the sampler and the animation clock.
//
// Trans-Am engages on sustained high CPU, or by hand:
//   omarchy-shell -q gnhud transAm
Item {
  id: root

  property var shell
  property var manifest

  readonly property string home: Quickshell.env("HOME")
  property string themeName: ""
  readonly property bool active: themeName === "gundam-00-raiser"

  // ------------------------------------------------------------ pausing
  // Nobody can see the HUD while the user is away, under the screensaver, or
  // behind a fullscreen window, so the clock and sampler stop there; the last
  // frame stays up. (It otherwise kept ~6% CPU while hidden.)
  // Windows here all float, so a window dragged or resized to fill the screen
  // is never "fullscreen"; bigWindow catches that case too.
  readonly property var hudMonitor: hudScreens.length > 0 ? Hyprland.monitorFor(hudScreens[0]) : null
  readonly property bool covered: bigWindow || !!(hudMonitor && hudMonitor.activeWorkspace && hudMonitor.activeWorkspace.hasFullscreen)
  readonly property bool running: active && !idleMonitor.isIdle && !covered
  property bool bigWindow: false

  // True when one window on the HUD's workspace hides at least 85% of the screen.
  function checkBigWindow() {
    var m = hudMonitor
    var ws = m ? m.activeWorkspace : null
    if (!ws || !ws.toplevels) { bigWindow = false; return }
    var area = m.width * m.height
    var big = false
    var list = ws.toplevels.values
    for (var i = 0; i < list.length && !big; i++) {
      var o = list[i].lastIpcObject
      if (!o || !o.at || !o.size || o.hidden) continue
      var w = Math.min(o.at[0] + o.size[0], m.x + m.width) - Math.max(o.at[0], m.x)
      var h = Math.min(o.at[1] + o.size[1], m.y + m.height) - Math.max(o.at[1], m.y)
      if (w > 0 && h > 0 && w * h >= 0.85 * area) big = true
    }
    bigWindow = big
  }

  // Window moves and resizes don't arrive as events, so poll Hyprland's
  // window list (in-process IPC, no subprocess). Checked on the next tick,
  // after the refresh has landed.
  Timer {
    interval: 1500
    running: root.active
    repeat: true
    onTriggered: {
      root.checkBigWindow()
      Hyprland.refreshToplevels()
    }
  }

  IdleMonitor {
    id: idleMonitor
    timeout: 120
    respectInhibitors: true
  }

  // Live readings, refreshed every 2s.
  property real cpu: 0
  property real mem: 0
  property real temp: 0
  property real fan: 0
  property int battery: 0
  property string batteryStatus: ""
  property real uptime: 0
  property string hostname: ""
  property string kernel: ""
  property var cores: []
  property var cpuHistory: []
  property var prevTotals: ({})

  // ------------------------------------------------------------ news feed
  // fetch-news.py pulls public tech/science/space/security feeds into a
  // cache (it skips the network if the cache is under 25 min old); the panel
  // reads the cache, so it still has headlines offline.
  readonly property string newsCache: home + "/.cache/gn-hud/news.json"
  // One fetcher shared by the GN HUD and VEDA plugins (was a copy in each).
  readonly property string newsScript: home + "/.local/share/veda-news/fetch-news.py"
  property var news: []
  property int newsFetched: 0

  function openLink(url) {
    url = String(url || "")
    if (url.indexOf("https://") !== 0) return
    linkOpener.command = ["xdg-open", url]
    linkOpener.running = true
  }

  Process { id: linkOpener }

  Process {
    id: newsFetcher
    command: ["python3", root.newsScript, root.newsCache]
  }

  Timer {
    interval: 30 * 60 * 1000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!newsFetcher.running) newsFetcher.running = true
  }

  FileView {
    path: root.newsCache
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(text())
        root.news = Array.isArray(data.items) ? data.items : []
        root.newsFetched = data.fetched || 0
      } catch (e) {}
    }
  }

  // Animation clock at 10fps; everything that moves derives from it, which
  // caps redraws instead of letting each animation tick at vsync.
  property int tick: 0

  property int hotSamples: 0
  property int coolSamples: 0
  property bool autoTransAm: false
  property bool forcedTransAm: false
  readonly property bool transAm: autoTransAm || forcedTransAm

  // Saves just the HUD layer (no windows) to a PNG, for checking the layout.
  signal snapshotRequested(string path)

  // Palette: dark-hologram take on the Celestial Being consoles. Trans-Am
  // floods everything magenta like the in-show system screen.
  property color cyan: transAm ? "#ff4fe6" : "#5cd6ff"
  property color cyanBright: transAm ? "#ffb8f7" : "#b0f0ff"
  property color blue: transAm ? "#b0189c" : "#3b5de0"
  property color gold: transAm ? "#fdaa59" : "#f2c14e"
  property color textBright: transAm ? "#fff0fd" : "#e4f6ff"
  property color panel: transAm ? "#2a0626" : "#0a1024"
  property color warn: "#e8394f"
  Behavior on cyan { ColorAnimation { duration: 900 } }
  Behavior on cyanBright { ColorAnimation { duration: 900 } }
  Behavior on blue { ColorAnimation { duration: 900 } }
  Behavior on gold { ColorAnimation { duration: 900 } }
  Behavior on textBright { ColorAnimation { duration: 900 } }
  Behavior on panel { ColorAnimation { duration: 900 } }

  readonly property string sampleScript: [
    "grep '^cpu' /proc/stat",
    "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"mem %.1f\\n\",(t-a)*100/t}' /proc/meminfo",
    "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in",
    "  coretemp) echo \"temp $(cat $h/temp1_input)\";;",
    "  asus) [ -r $h/pwm1 ] && echo \"fan $(cat $h/pwm1)\";;",
    "esac; done",
    "for b in /sys/class/power_supply/BAT*; do [ -r $b/capacity ] && echo \"bat $(cat $b/capacity) $(cat $b/status)\"; break; done",
    "echo \"up $(cut -d' ' -f1 /proc/uptime)\"",
    "echo \"host $(cat /etc/hostname 2>/dev/null)\"",
    "echo \"kernel $(uname -r)\""
  ].join("\n")

  function ingest(raw) {
    var lines = String(raw || "").split("\n")
    var totals = ({})
    var nextCores = []
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      var key = f[0]
      if (key.indexOf("cpu") === 0) {
        var total = 0
        for (var j = 1; j <= 8 && j < f.length; j++) total += parseFloat(f[j]) || 0
        var idle = (parseFloat(f[4]) || 0) + (parseFloat(f[5]) || 0)
        totals[key] = { total: total, idle: idle }
        var prev = prevTotals[key]
        var usage = 0
        if (prev && total > prev.total)
          usage = 100 * (1 - (idle - prev.idle) / (total - prev.total))
        if (key === "cpu") cpu = Math.max(0, Math.min(100, usage))
        else nextCores.push(Math.max(0, Math.min(100, usage)))
      } else if (key === "mem") mem = parseFloat(f[1]) || 0
      else if (key === "temp") temp = (parseFloat(f[1]) || 0) / 1000
      else if (key === "fan") fan = (parseFloat(f[1]) || 0) * 100 / 255
      else if (key === "bat") { battery = parseInt(f[1]) || 0; batteryStatus = f.slice(2).join(" ") }
      else if (key === "up") uptime = parseFloat(f[1]) || 0
      else if (key === "host") hostname = f.slice(1).join(" ")
      else if (key === "kernel") kernel = f.slice(1).join(" ")
    }
    // An empty/failed sampler run parses no cpu lines; keep the previous
    // baseline and core list rather than wiping them, which zero-blipped CPU and
    // emptied the per-thread bars for a frame, then mis-computed the next sample.
    if (Object.keys(totals).length > 0) {
      prevTotals = totals
      cores = nextCores
    }

    var hist = cpuHistory.slice(-39)
    hist.push(cpu)
    cpuHistory = hist

    // Trans-Am: 3 samples (~6s) pinned high to engage, 2 samples calm to drop.
    if (cpu >= 85) { hotSamples += 1; coolSamples = 0 }
    else if (cpu < 60) { coolSamples += 1; hotSamples = 0 }
    else { hotSamples = 0; coolSamples = 0 }
    if (hotSamples >= 3) autoTransAm = true
    if (coolSamples >= 2) autoTransAm = false
  }

  FileView {
    id: themeFile
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.themeName = String(text() || "").trim()
  }

  // theme-set may replace theme.name rather than rewrite it, which a file
  // watch can miss; a slow re-read keeps the on/off switch honest.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: themeFile.reload()
  }

  Process {
    id: sampler
    command: ["bash", "-c", root.sampleScript]
    stdout: StdioCollector {
      onStreamFinished: root.ingest(text)
    }
  }

  // On battery the HUD keeps moving but at a third of the frame rate, and the
  // stats refresh every 6s instead of 2s. The tick steps by 3 so rotations and
  // blinks keep the same speed, just with fewer frames.
  readonly property bool unplugged: batteryStatus === "Discharging"

  Timer {
    interval: root.unplugged ? 6000 : 2000
    running: root.running
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!sampler.running) sampler.running = true
  }

  Timer {
    interval: root.unplugged ? 300 : 100
    running: root.running
    repeat: true
    onTriggered: root.tick += root.unplugged ? 3 : 1
  }

  Timer {
    id: forcedTimer
    interval: 15000
    onTriggered: root.forcedTransAm = false
  }

  IpcHandler {
    target: "gnhud"

    function transAm(): void {
      root.forcedTransAm = true
      forcedTimer.restart()
    }

    function status(): string {
      var ws = root.hudMonitor ? root.hudMonitor.activeWorkspace : null
      return JSON.stringify({
        active: root.active, running: root.running, idle: idleMonitor.isIdle, covered: root.covered, bigWindow: root.bigWindow, unplugged: root.unplugged,
        monitor: root.hudMonitor ? root.hudMonitor.name : null,
        workspace: ws ? ws.name : null, hasFullscreen: ws ? ws.hasFullscreen : null
      })
    }

    function snapshot(path: string): void {
      root.snapshotRequested(path)
    }
  }

  // Only the laptop's own panel gets the HUD. A projector or external
  // monitor keeps the plain base wallpaper: it saves CPU, avoids a moving
  // background behind presentations, and the layout assumes ~16:9.
  readonly property var hudScreens: {
    var all = Quickshell.screens
    var internal = all.filter(function(s) { return /^(eDP|LVDS|DSI)/.test(s.name) })
    return internal.length > 0 ? internal : all.slice(0, 1)
  }

  Variants {
    model: root.hudScreens

    PanelWindow {
      required property var modelData

      screen: modelData
      visible: root.active
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      // Click-through everywhere except the news panel.
      mask: Region { item: hudScreen.clickArea }

      WlrLayershell.namespace: "vedacool-gn-hud"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      HudScreen {
        id: hudScreen
        anchors.fill: parent
        hud: root
      }
    }
  }
}
