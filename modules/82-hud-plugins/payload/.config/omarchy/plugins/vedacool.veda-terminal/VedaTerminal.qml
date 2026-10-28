import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Gundam 00 VEDA terminal drawn on the bottom layer: above the wallpaper,
// below windows, click-through. Only runs while the veda-terminal theme is
// active, so switching themes stops the sampler and the animation clock.
// (The Exia HUD, vedacool.gn-hud, does the same for gundam-00-raiser.)
//
// Quantum burst engages on sustained high CPU, or by hand:
//   omarchy-shell -q vedaterm burst
Item {
  id: root

  property var shell
  property var manifest

  readonly property string home: Quickshell.env("HOME")
  property string themeName: ""
  readonly property bool active: themeName === "veda-terminal"

  // ------------------------------------------------------------ pausing
  // Nobody can see the HUD while the user is away, under the screensaver, or
  // behind a fullscreen window, so the clock and sampler stop there; the last
  // frame stays up. (It otherwise kept ~6% CPU while hidden.)
  // Windows here all float, so a window dragged or resized to fill the screen
  // is never "fullscreen"; bigWindow catches that case too.
  readonly property var hudMonitor: hudScreens.length > 0 ? Hyprland.monitorFor(hudScreens[0]) : null
  readonly property bool covered: bigWindow || !!(hudMonitor && hudMonitor.activeWorkspace && hudMonitor.activeWorkspace.hasFullscreen)
  readonly property bool running: active && !idleMonitor.isIdle && !covered && !ssShown && !ssPreview && !sharing
  property bool bigWindow: false

  // True while Zoom shares the screen (its share toolbar exists). The HUD
  // holds still then, so Zoom isn't encoding a moving desktop on this old CPU.
  property bool sharing: false
  function zoomSharing() {
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) {
      var o = list[i].lastIpcObject
      if (o && o.class === "zoom" && o.title === "as_toolbar") return true
    }
    return false
  }

  // True when one window on the monitor's workspace hides at least 85% of it.
  function hasBigWindow(m) {
    var ws = m ? m.activeWorkspace : null
    if (!ws || !ws.toplevels) return false
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
    return big
  }

  // Window moves and resizes don't arrive as events, so poll Hyprland's
  // window list (in-process IPC, no subprocess). Checked on the next tick,
  // after the refresh has landed.
  Timer {
    interval: 1500
    running: root.active
    repeat: true
    onTriggered: {
      root.checkMirror()
      Hyprland.refreshMonitors()
      // While the screensaver covers the outputs the HUD is hidden, so skip the
      // toplevel scan (refreshToplevels + the window-list loops) — exactly the
      // hidden-state cost the pause machinery exists to shed. Resumes the next
      // tick after the screensaver dismisses.
      if (root.ssShown || root.ssPreview) return
      root.bigWindow = root.hasBigWindow(root.hudMonitor)
      root.extBigWindow = root.hasBigWindow(root.extMonitor)
      root.sharing = root.zoomSharing()
      Hyprland.refreshToplevels()
    }
  }

  // ------------------------------------------------------------ calm mode
  // While the laptop panel is mirrored to a projector the class sees this
  // HUD, so it goes calm: the news panel gives way to a display-link block,
  // the log drops archived headlines, no quantum burst, and 3fps animation.
  // Test without a projector: omarchy-shell vedaterm calmTest on|off
  property bool mirrored: false
  property string mirrorOutput: ""
  property string mirrorMode: ""
  property bool calmTest: false
  readonly property bool calm: mirrored || calmTest
  onCalmChanged: log(calm ? "DISPLAY MIRROR  " + (mirrorOutput || "TEST") + "  CALM MODE ON" : "DISPLAY MIRROR RELEASED  CALM MODE OFF")

  function checkMirror() {
    var list = Hyprland.monitors.values
    var found = null
    for (var i = 0; i < list.length && !found; i++) {
      var o = list[i].lastIpcObject
      if (o && o.mirrorOf && o.mirrorOf !== "none") found = o
    }
    mirrorOutput = found ? found.name : ""
    mirrorMode = found ? found.width + "×" + found.height : ""
    mirrored = !!found
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
  property string lastSyncKey: ""
  property int newsFetched: 0

  function openLink(url) {
    url = String(url || "")
    if (url.indexOf("https://") !== 0) return
    // Detached, so the browser isn't a child of the shell: an attached Process
    // ignored later clicks while xdg-open waited on a cold-started browser.
    Quickshell.execDetached(["xdg-open", url])
  }

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
        // Only report a sync that brought something new, not every reload.
        var key = root.news.length + "|" + (root.news.length ? root.news[0].title : "")
        if (key !== root.lastSyncKey && root.news.length > 0) {
          root.lastSyncKey = key
          var seen = ({})
          for (var i = 0; i < root.news.length; i++) seen[root.news[i].source] = true
          root.log("FEED SYNC  " + root.news.length + " ITEMS / " + Object.keys(seen).length + " SOURCES")
        }
      } catch (e) {}
    }
  }

  // ------------------------------------------------------------ quantum link
  // A cheap reachability probe: is there a route out, and does a TCP connect
  // to a public resolver answer? "online" = it answered, "local" = a network
  // but no way out (captive portal, dead uplink), "offline" = no route at all.
  // Without a link VEDA runs standalone on its cached archive and probes more
  // often so the link comes back quickly; a restored link pulls a fresh feed.
  property string link: "unknown"
  property string linkDev: ""
  property int linkRtt: -1
  property int linkSignal: 0      // dBm on wifi, 0 on a wire
  property real linkLostAt: 0     // ms epoch when the link dropped
  property string linkOverride: ""
  readonly property int linkBars: linkDev === "" ? 0 : linkSignal === 0 ? 4
    : linkSignal >= -55 ? 4 : linkSignal >= -65 ? 3 : linkSignal >= -75 ? 2 : 1
  readonly property bool online: link === "online"
  readonly property string linkMedium: /^wl/.test(linkDev) ? "WLAN" : /^(en|eth)/.test(linkDev) ? "ETH"
    : /^(wg|tun|tap)/.test(linkDev) ? "TUNNEL" : String(linkDev).toUpperCase()

  readonly property string linkScript: [
    "dev=$(ip -o route get 1.1.1.1 2>/dev/null | grep -o 'dev [^ ]*' | cut -d' ' -f2)",
    "echo \"dev $dev\"",
    "[ -z \"$dev\" ] && exit 0",
    "awk -v d=\"$dev:\" '$1==d{print \"sig\", $4+0}' /proc/net/wireless",
    "for ip in 1.1.1.1 9.9.9.9; do s=$(date +%s%N)",
    "  if timeout 3 bash -c \"exec 3<>/dev/tcp/$ip/443\" 2>/dev/null; then echo \"rtt $(( ($(date +%s%N)-s)/1000000 ))\"; exit 0; fi",
    "done; echo 'rtt -1'"
  ].join("\n")

  // "<1 MIN", "12 MIN", "1H Ø5M": one format for the header and the log.
  function darkText(mins) {
    if (mins < 1) return "<1 MIN"
    if (mins < 60) return mins + " MIN"
    var m = mins % 60
    return Math.floor(mins / 60) + "H " + (m < 10 ? "0" : "") + m + "M"
  }

  function ingestLink(raw) {
    var dev = "", rtt = -1, sig = 0
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f[0] === "dev") dev = f[1] || ""
      else if (f[0] === "rtt") rtt = parseInt(f[1])
      else if (f[0] === "sig") sig = parseInt(f[1]) || 0
    }
    if (linkOverride === "offline") dev = ""
    else if (linkOverride === "local") rtt = -1
    var next = dev === "" ? "offline" : rtt >= 0 ? "online" : "local"
    linkDev = dev; linkRtt = rtt; linkSignal = sig
    if (next === link) return
    var prev = link
    link = next
    if (next === "online") {
      if (prev === "unknown") log("QUANTUM LINK ESTABLISHED  " + rtt + "MS")
      else {
        var mins = Math.round((Date.now() - linkLostAt) / 60000)
        log("QUANTUM LINK RESTORED  DARK " + darkText(mins))
        if (!newsFetcher.running) newsFetcher.running = true
      }
    } else {
      if (prev === "online" || prev === "unknown") linkLostAt = Date.now()
      if (next === "local") log("QUANTUM LINK UNSTABLE  NO UPLINK VIA " + linkMedium)
      else log("QUANTUM LINK SEVERED  STANDALONE MODE")
      if (prev === "online" || prev === "unknown") log("SERVING LOCAL ARCHIVE  " + news.length + " ITEMS")
    }
  }

  Process {
    id: linkProbe
    command: ["bash", "-c", root.linkScript]
    stdout: StdioCollector {
      onStreamFinished: root.ingestLink(text)
    }
  }

  // Online: every 30s (60s on battery). Without a link: every 10s (20s).
  Timer {
    interval: (root.online ? 30000 : 10000) * (root.unplugged ? 2 : 1)
    running: root.running
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!linkProbe.running) linkProbe.running = true
  }

  // Animation clock at 10fps; everything that moves derives from it, which
  // caps redraws instead of letting each animation tick at vsync.
  property int tick: 0

  property int hotSamples: 0
  property int coolSamples: 0
  property bool autoBurst: false
  property bool forcedBurst: false
  readonly property bool burst: !calm && (autoBurst || forcedBurst)
  onBurstChanged: log(burst ? "QUANTUM BURST  FULL PROCESSING" : "BURST RELEASED  CORE NOMINAL")

  // Saves just the HUD layer (no windows) to a PNG, for checking the layout.
  signal snapshotRequested(string path)
  readonly property string snapDir: home + "/.cache/vedaterm-snaps/"
  // A bare file name or a path inside snapDir; anything else is refused.
  function snapPath(path) {
    path = String(path || "")
    if (path.indexOf("/") < 0) path = snapDir + path
    if (path.indexOf(snapDir) !== 0 || path.indexOf("..") >= 0 || !/\.png$/.test(path)) return ""
    return path
  }

  // Palette: phosphor-green VEDA terminal with a gold core. A quantum burst
  // floods everything amber.
  readonly property var base: ({ sig: "#6ee7a0", sigBright: "#c8ffd9", deep: "#1f8a5a", gold: "#e8c25a", textBright: "#e3fbe9", panel: "#07120d" })
  property color sig: burst ? "#ffc64a" : base.sig
  property color sigBright: burst ? "#fff0b8" : base.sigBright
  property color deep: burst ? "#b0620f" : base.deep
  property color gold: burst ? "#ff8a3c" : base.gold
  property color textBright: burst ? "#fffbe8" : base.textBright
  property color panel: burst ? "#1e1405" : base.panel
  property color warn: "#e8394f"
  Behavior on sig { ColorAnimation { duration: 900 } }
  Behavior on sigBright { ColorAnimation { duration: 900 } }
  Behavior on deep { ColorAnimation { duration: 900 } }
  Behavior on gold { ColorAnimation { duration: 900 } }
  Behavior on textBright { ColorAnimation { duration: 900 } }
  Behavior on panel { ColorAnimation { duration: 900 } }

  // News category colours and short tags, shared by NewsPanel and the
  // screensaver (~/Work/bin/veda-screensaver keeps its own copy in CAT_COL).
  // SCIENCE follows the live signal colour on the HUD (amber in a burst);
  // pass base=true for the fixed palette.
  function catColor(cat, base) {
    cat = String(cat || "").toUpperCase()
    if (cat === "SPACE") return "#86c0f0"
    if (cat === "SCIENCE") return base ? root.base.sigBright : root.sigBright
    if (cat === "SECURITY") return "#ff8a3c"   // orange, so red stays for alarms
    if (cat === "TECH") return "#c9a0f0"
    return ""
  }
  readonly property var catTag: ({ SPACE: "SPACE", SCIENCE: "SCI ", TECH: "TECH", SECURITY: "SEC " })

  // ------------------------------------------------------------ terminal log
  // Short lines about things that really happened (feed syncs, power changes,
  // load reports, archived headlines); the newest types itself in on screen.
  property var logLines: []
  property int logTick: 0

  function log(msg, archive) {
    var d = new Date()
    var stamp = Qt.formatTime(d, "h:mm AP")
    var lines = logLines.slice(-11)
    lines.push({ stamp: stamp, text: String(msg).toUpperCase(), archive: !!archive })
    logLines = lines
    logTick = tick
  }

  property int sampleCount: 0
  property int archiveIndex: 0

  // Every ~20s the log alternates a load report with a cooling/link report.
  // Headlines stay in the news panel; the log only describes the system.
  function periodicLog() {
    sampleCount += 1
    if (sampleCount % 10 !== 0) return
    if ((sampleCount / 10) % 2 === 1) {
      log("LOAD " + Math.round(cpu) + "%  MEM " + Math.round(mem) + "%  TEMP " + Math.round(temp) + "°C")
    } else {
      var linkPart = link === "online" ? "LINK " + linkMedium + " " + linkRtt + "MS"
        : link === "local" ? "LINK UNSTABLE" : link === "offline" ? "LINK SEVERED" : "LINK PROBING"
      log("FAN " + Math.round(fan) + "%  " + linkPart + "  ARCHIVE " + news.length)
    }
  }

  onBatteryStatusChanged: {
    if (batteryStatus === "Charging") log("POWER  EXTERNAL SUPPLY  CHARGING")
    else if (batteryStatus === "Discharging") log("POWER  INTERNAL CELL  " + battery + "%")
    else if (batteryStatus === "Full") log("POWER  CELL FULL")
  }
  onActiveChanged: if (active) log("ACCESS LEVEL 7 GRANTED")
  onHostnameChanged: if (hostname) log("TERMINAL " + hostname + " ONLINE")

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
    // An empty/failed sampler run parses no cpu lines; keep the previous baseline
    // and core list rather than wiping them (which emptied the per-thread panel
    // for a frame and zero-blipped CPU on the next good sample).
    if (Object.keys(totals).length > 0) {
      prevTotals = totals
      cores = nextCores
    }

    var hist = cpuHistory.slice(-39)
    hist.push(cpu)
    cpuHistory = hist

    // Burst: 3 samples (~6s) pinned high to engage, 2 samples calm to drop.
    if (cpu >= 85) { hotSamples += 1; coolSamples = 0 }
    else if (cpu < 60) { coolSamples += 1; hotSamples = 0 }
    else { hotSamples = 0; coolSamples = 0 }
    if (hotSamples >= 3) autoBurst = true
    if (coolSamples >= 2) autoBurst = false

    periodicLog()
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

  // ----------------------------------------------------------- net monitor
  // Per-process bandwidth (down + up), sampled without root by diffing ss
  // socket counters. Covers your own apps (~all of a laptop's traffic);
  // root/system transfers group as "system". Feeds the NET MONITOR panel.
  readonly property string netScript: home + "/.config/omarchy/plugins/vedacool.veda-terminal/net-hogs.sh"
  property var netHogs: []      // [{ name, dl, ul }] bytes/sec, busiest first
  property real netDl: 0        // total bytes/sec down
  property real netUl: 0        // total bytes/sec up
  property int netActive: 0     // processes above the noise threshold

  function ingestNet(raw) {
    var lines = String(raw || "").split("\n")
    var hogs = []
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f[0] === "TOTAL") {
        netDl = parseFloat(f[1]) || 0
        netUl = parseFloat(f[2]) || 0
        netActive = parseInt(f[3]) || 0
      } else if (f.length >= 3 && f[0] && f[0].indexOf("#") !== 0) {
        hogs.push({ name: f[0].replace(/_/g, " "), dl: parseFloat(f[1]) || 0, ul: parseFloat(f[2]) || 0 })
      }
    }
    netHogs = hogs
  }

  Process {
    id: netSampler
    command: ["bash", root.netScript]
    stdout: StdioCollector { onStreamFinished: root.ingestNet(text) }
  }

  // The helper sleeps ~1.2s internally (two snapshots), so fire it less often
  // than the stats sampler. Off on battery-saver cadence; idle when hidden.
  Timer {
    interval: root.unplugged ? 8000 : 4000
    running: root.running
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!netSampler.running) netSampler.running = true
  }

  // Clear stale rows when the HUD stops so it doesn't resume on old numbers.
  onRunningChanged: if (!running) { netHogs = []; netDl = 0; netUl = 0; netActive = 0 }

  Timer {
    interval: root.unplugged || root.calm ? 300 : 100
    running: root.running
    repeat: true
    onTriggered: root.tick += root.unplugged || root.calm ? 3 : 1
  }

  // The projection screen keeps its own animation clock: in extend mode the
  // slides usually cover it while the laptop stays visible, or the reverse.
  readonly property var extMonitor: extScreens.length > 0 ? Hyprland.monitorFor(extScreens[0]) : null
  property bool extBigWindow: false
  readonly property bool extCovered: extBigWindow || !!(extMonitor && extMonitor.activeWorkspace && extMonitor.activeWorkspace.hasFullscreen)
  // Also stop when the screensaver covers the outputs. ssScreens covers every
  // non-mirror output incl. the projector, so without this the projection HUD
  // kept animating full-tilt under an opaque screensaver on a manual (non-idle)
  // trigger -- the !idleMonitor.isIdle term only caught the idle-launched path.
  readonly property bool extRunning: active && extScreens.length > 0 && !idleMonitor.isIdle && !extCovered && !sharing && !ssShown && !ssPreview
  property int extTick: 0

  Timer {
    interval: root.unplugged ? 300 : 100
    running: root.extRunning
    repeat: true
    onTriggered: root.extTick += root.unplugged ? 3 : 1
  }

  // Shows the projection layout on the laptop panel, to check it without a
  // second screen: omarchy-shell vedaterm extPreview on|off
  property bool extPreview: false

  // ------------------------------------------------------------ screensaver
  // Native screensaver (VedaScreensaver.qml): the terminal screensaver's scene
  // with the HUD's own core. ~/.local/bin/veda-launch-screensaver calls
  // `vedaterm screensaver on` when ~/.local/share/veda-screensaver/mode says
  // "native"; otherwise the foot/python one runs.
  // The idle service (vedacool.idle) only sees screensaver *windows*, so this
  // tells it by IPC when the overlay opens and closes; without that it would
  // cancel the lock timer.
  // ssPreview draws it on the bottom layer instead (no input grab, no idle
  // hand-off), to snapshot and measure it without taking over the screen.
  property bool ssShown: false
  property bool ssPreview: false
  property real ssTime: 0
  property double ssStart: 0
  signal ssSnapshotRequested(string path)

  // 5fps on AC, 2.5fps on battery: a screensaver
  // should cost less than the desktop it replaces. Motion is time-based, so
  // only the smoothness changes, not the speed.
  Timer {
    interval: root.unplugged ? 400 : 200
    running: root.ssShown || root.ssPreview
    repeat: true
    onTriggered: root.ssTime = (Date.now() - root.ssStart) / 1000
  }

  function screensaverShow() {
    if (root.ssShown || !root.active) return
    root.ssPreview = false
    root.ssStart = Date.now()
    root.ssTime = 0
    root.ssShown = true
    root.tellIdle("screensaverOpened")
  }

  function screensaverHide(notify) {
    if (!root.ssShown) return
    root.ssShown = false
    if (notify) {
      root.tellIdle("screensaverClosed")
    }
  }

  // Notices go through an in-order queue: a single shared Process used to drop
  // "closed" when it came while "opened" was still running, and separate
  // detached calls could arrive out of order on a very quick dismiss.
  property var idleQueue: []
  function tellIdle(fn) {
    root.idleQueue = root.idleQueue.concat([fn])
    if (!idleNotify.running) root.sendNextIdle()
  }
  function sendNextIdle() {
    if (root.idleQueue.length === 0) return
    idleNotify.command = ["omarchy-shell", "idle", root.idleQueue[0], "veda-native"]
    root.idleQueue = root.idleQueue.slice(1)
    idleNotify.running = true
  }
  Process {
    id: idleNotify
    onExited: root.sendNextIdle()
  }

  // The stat sampler stops while idle, so keep the power state fresh for the
  // screensaver's battery mode with a cheap read every 10s.
  Timer {
    interval: 10000
    running: root.ssShown
    repeat: true
    onTriggered: if (!powerCheck.running) powerCheck.running = true
  }
  Process {
    id: powerCheck
    command: ["bash", "-c", "for b in /sys/class/power_supply/BAT*; do cat $b/status; break; done"]
    stdout: StdioCollector {
      onStreamFinished: { var st = String(text).trim(); if (st) root.batteryStatus = st }
    }
  }

  // Backstop: if the session locks some other way while it is up, step aside.
  Timer {
    interval: 3000
    running: root.ssShown
    repeat: true
    onTriggered: if (!lockCheck.running) lockCheck.running = true
  }
  Process {
    id: lockCheck
    command: ["omarchy-shell", "lock", "isLocked"]
    stdout: StdioCollector {
      // Tell idle too: a lock from outside the idle plugin (lid, lock key) would
      // otherwise leave its cycle armed and lock again after the user unlocks.
      onStreamFinished: if (String(text).trim() === "true") root.screensaverHide(true)
    }
  }

  Timer {
    id: forcedTimer
    interval: 15000
    onTriggered: root.forcedBurst = false
  }

  IpcHandler {
    target: "vedaterm"

    function burst(): void {
      root.forcedBurst = true
      forcedTimer.restart()
    }

    function status(): string {
      var ws = root.hudMonitor ? root.hudMonitor.activeWorkspace : null
      return JSON.stringify({
        active: root.active, running: root.running, link: root.link, linkDev: root.linkDev, linkRtt: root.linkRtt, idle: idleMonitor.isIdle, covered: root.covered, sharing: root.sharing, bigWindow: root.bigWindow, unplugged: root.unplugged,
        monitor: root.hudMonitor ? root.hudMonitor.name : null,
        external: root.extMonitor ? root.extMonitor.name : null, extRunning: root.extRunning, extCovered: root.extCovered, extPreview: root.extPreview, calm: root.calm, mirrored: root.mirrored, mirrorOutput: root.mirrorOutput,
        workspace: ws ? ws.name : null, hasFullscreen: ws ? ws.hasFullscreen : null
      })
    }

    // Pretend the link is in a state, for checking the look without
    // unplugging anything: linkTest offline|local|online, or "" for real.
    function linkTest(state: string): void {
      root.linkOverride = state
      if (!linkProbe.running) linkProbe.running = true
    }

    function calmTest(state: string): void {
      root.calmTest = state === "on"
    }

    function extPreview(state: string): void {
      root.extPreview = state === "on"
    }

    // Snapshots only go to ~/.cache/vedaterm-snaps, so a local caller can't
    // make the shell overwrite arbitrary files.
    function snapshot(path: string): string {
      var p = root.snapPath(path)
      if (p) root.snapshotRequested(p)
      return p || "refused: snapshots go in " + root.snapDir
    }

    // on: show the native screensaver (what the idle launcher calls)
    // off: hide it; preview: draw it on the bottom layer, no input grab
    function screensaver(state: string): string {
      if (state === "on") root.screensaverShow()
      else if (state === "off") { root.screensaverHide(true); root.ssPreview = false }
      else if (state === "hide") root.screensaverHide(false)   // the session is locking
      else if (state === "preview" && !root.ssShown) { root.ssStart = Date.now(); root.ssTime = 0; root.ssPreview = true }
      return JSON.stringify({ active: root.active, shown: root.ssShown, preview: root.ssPreview })
    }

    function ssSnapshot(path: string): string {
      var p = root.snapPath(path)
      if (p) root.ssSnapshotRequested(p)
      return p || "refused: snapshots go in " + root.snapDir
    }
  }

  // The laptop's own panel gets the full HUD. An extended screen (usually a
  // projector) gets the projection layout: only the core, the clock and the
  // power plate. A mirrored output just copies the laptop panel.
  readonly property var hudScreens: {
    var all = Quickshell.screens
    var internal = all.filter(function(s) { return /^(eDP|LVDS|DSI)/.test(s.name) })
    return internal.length > 0 ? internal : all.slice(0, 1)
  }
  readonly property var extScreens: {
    var main = hudScreens
    return Quickshell.screens.filter(function(s) {
      if (main.indexOf(s) >= 0) return false
      var m = Hyprland.monitorFor(s)
      var o = m ? m.lastIpcObject : null
      return !(o && o.mirrorOf && o.mirrorOf !== "none")
    })
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

      WlrLayershell.namespace: "vedacool-veda-terminal"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      VedaScreen {
        id: hudScreen
        anchors.fill: parent
        hud: root
        projection: root.extPreview
      }

      Loader {
        anchors.fill: parent
        active: root.ssPreview
        sourceComponent: ssComponent
      }
    }
  }

  Variants {
    model: root.extScreens

    PanelWindow {
      required property var modelData

      screen: modelData
      visible: root.active
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      WlrLayershell.namespace: "vedacool-veda-terminal-ext"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      VedaScreen {
        anchors.fill: parent
        hud: root
        projection: true
        external: true
        t: root.extTick
      }
    }
  }

  Component {
    id: ssComponent
    VedaScreensaver {
      id: saver
      hud: root
      time: root.ssTime
      Connections {
        target: root
        function onSsSnapshotRequested(path) { saver.grabToImage(function(r) { r.saveToFile(path) }) }
      }
    }
  }

  // The screensaver covers every output except mirrors (which already copy
  // the laptop panel). The laptop's surface takes the keyboard.
  readonly property var ssScreens: Quickshell.screens.filter(function(s) {
    var m = Hyprland.monitorFor(s)
    var o = m ? m.lastIpcObject : null
    return !(o && o.mirrorOf && o.mirrorOf !== "none")
  })

  Variants {
    model: root.ssScreens

    PanelWindow {
      id: ssWin
      required property var modelData
      readonly property bool primary: root.hudScreens.indexOf(modelData) >= 0 || root.hudScreens.length === 0

      screen: modelData
      visible: root.ssShown
      color: "#07120d"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "vedacool-veda-screensaver"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      Loader {
        anchors.fill: parent
        active: root.ssShown
        sourceComponent: ssComponent
        onLoaded: {
          item.interactive = true
          item.forceActiveFocus()
          item.dismissed.connect(function() { root.screensaverHide(true) })
        }
      }
    }
  }
}
