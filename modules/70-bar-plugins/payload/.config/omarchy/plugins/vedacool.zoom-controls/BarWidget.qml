import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Zoom Controls: one bar pill for the Zoom desktop app while it shares the
// screen. On Hyprland, Zoom (XWayland) never shrinks its big share toolbar to
// a small pill like on Windows. The idea comes from
// jkarmel/omarchy-zoom-controls (MIT), which only drives the Zoom web app.
//  - sharing: Zoom's share toolbar window (as_toolbar) exists only while
//    sharing;
//  - the toolbar is moved just above the screen (moved, not hidden: hiding
//    or unmapping it froze shares) whenever it isn't wanted;
//  - meeting window open: the toolbar stays tucked away and the meeting can
//    be maximised; its own bottom controls do the job. Clicking the pill
//    brings the meeting forward;
//  - meeting minimised: clicking the pill shows the toolbar (Audio, Video,
//    Stop share...) and hides it again. Clicks never stop the share, so a
//    touchpad slip can't end it;
//  - while the toolbar is shown, Zoom's other windows are moved below it and
//    put back afterwards (bin/zoom-fit): inside XWayland they stay above it
//    and take its clicks where they overlap, even minimised.
// The toolbar only takes clicks thanks to the allows_input rule in
// ~/.config/hypr/hyprland.lua.
BarWidget {
  id: root
  moduleName: "vedacool.zoom-controls"

  property bool inMeeting: false
  property bool sharing: false
  property bool meetingOpen: false
  // Each share opens a new toolbar window; a new address means a new share,
  // which starts with the toolbar tucked away again.
  property string toolbarAddr: ""
  property bool toolbarWanted: false
  readonly property bool toolbarShown: sharing && toolbarWanted && !meetingOpen
  property real lastMove: 0
  property real lastFit: 0

  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""))

  visible: sharing
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  // Toolbar tucked away, share ended or meeting opened again: put back the
  // Zoom windows that were moved out of the toolbar's way.
  onToolbarShownChanged: if (!toolbarShown) Quickshell.execDetached([root.pluginDir + "bin/zoom-fit", "restore"])

  // omarchy-shell zoomcontrols status | toolbar | show (also for key binds).
  IpcHandler {
    target: "zoomcontrols"
    function status(): string {
      return JSON.stringify({ inMeeting: root.inMeeting, sharing: root.sharing,
        meetingOpen: root.meetingOpen, toolbarShown: root.toolbarShown })
    }
    function show(): void { Quickshell.execDetached([root.pluginDir + "bin/zoom-show"]) }
    function toolbar(): void { root.press() }
  }

  function scan() {
    var list = Hyprland.toplevels.values
    var meeting = null, tb = null, others = []
    for (var i = 0; i < list.length; i++) {
      var o = list[i].lastIpcObject
      if (!o || o.class !== "zoom") continue
      if (o.title === "as_toolbar") tb = o
      else {
        if (o.title === "Meeting") meeting = o
        if (!/^(annotate_toolbar|zoom_linux_float_video_window|as_preview)$/.test(o.title)) others.push(o)
      }
    }
    sharing = tb !== null
    inMeeting = meeting !== null || sharing
    meetingOpen = !!(meeting && meeting.workspace && meeting.workspace.name !== "special:minimized")
    if (tb) { placeToolbar(tb); keepZoomClear(tb, others) }
  }

  function placeToolbar(o) {
    if (o.address !== toolbarAddr) { toolbarAddr = o.address; toolbarWanted = false; lastMove = 0 }
    if (!o.at || Date.now() - lastMove < 1500) return   // let the last move land first
    var tucked = o.at[1] < 0
    if (tucked === !toolbarShown) return
    lastMove = Date.now()
    var y = toolbarShown ? 26 : -400                    // 26 = just under the bar, where Zoom puts it
    Quickshell.execDetached(["hyprctl", "dispatch",
      "hl.dsp.window.move({ window = 'address:" + o.address + "', x = " + o.at[0] + ", y = " + y + " })"])
  }

  function keepZoomClear(tb, others) {
    if (!toolbarShown || !tb.at || tb.at[1] < 0) return
    var overlap = false
    for (var i = 0; i < others.length; i++)
      if (others[i].at && others[i].at[1] < tb.at[1] + tb.size[1]) overlap = true
    if (!overlap || Date.now() - lastFit < 1500) return
    lastFit = Date.now()
    Quickshell.execDetached([root.pluginDir + "bin/zoom-fit"])
  }

  function press() {
    if (!sharing) return
    if (meetingOpen) { Quickshell.execDetached([root.pluginDir + "bin/zoom-show"]); return }
    toolbarWanted = !toolbarWanted
    lastMove = 0
    scan()
  }

  // Window titles change without a toplevel event, so poll Hyprland's window
  // list (in-process IPC, no subprocess), like the VEDA terminal does.
  Timer {
    interval: root.inMeeting ? 1000 : 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { Hyprland.refreshToplevels(); Qt.callLater(root.scan) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.meetingOpen ? "● SHARING" : (root.toolbarShown ? "● SHARING · HIDE" : "● SHARING · CONTROLS")
    foreground: Color.urgent
    tooltipText: root.meetingOpen ? "Sharing · the meeting window has the controls (click to bring it forward)"
               : root.toolbarShown ? "Tuck Zoom's share toolbar away"
               : "Show Zoom's share toolbar (Audio, Video, Stop share…)"
    onPressed: root.press()
  }
}
