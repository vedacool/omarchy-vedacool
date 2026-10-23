# VEDA theme: audit findings

Source of truth for audit findings. Severity is P0–P3. Tick an item when it's fixed.
Full audit 2026-10-05: **no P0**. Verdict: GO for the current setup (terminal screensaver). Native screensaver mode was NO-GO until #1 and #2 were fixed.
**All items fixed on 2026-10-05** (the user asked for P1–P3). Native mode is now GO from the audit side; its idle/lock path still needs a first real-world run. Run `~/Work/bin/veda-selftest` after changes. Pre-fix copies are in `~/.local/share/veda-backups/2026-10-05/pre-audit-fixes/`.

## P1
- [x] **#1 Native: a manual or lid lock leaves the idle cycle armed, so the user can be locked again after unlocking.** `VedaTerminal.qml` lockCheck calls `screensaverHide(false)` and never sends `screensaverClosed`, so `vedacool.idle/Service.qml` handleActiveSignal keeps the cycle armed. Fix: use `screensaverHide(true)` in the backstop.

## P2
- [x] **#2 Native: the "closed" notice can be dropped on a quick dismiss.** A single `idleNotify` Process is reused, and `running = true` is ignored while it's busy. Fix: use `Quickshell.execDetached`, or one Process per message.
- [x] **#3 Feed HTML is rendered.** No Text sets `textFormat`, so AutoText applies. `fetch-news.py` `clean()` strips tags before unescaping, so a double-encoded `&amp;lt;img…&amp;gt;` comes through as a real `<img>` (verified). Impact: a remote image fetch (beacon/IP leak) and layout abuse. Fix: set `textFormat: Text.PlainText` on feed Texts (NewsPanel, VedaScreensaver), and in `clean()` unescape first, then strip tags, then drop `<>`.
- [x] **#4 Clicked links: xdg-open runs as a child Process of the shell.** Later clicks are ignored while it runs, and the browser can die on a shell restart. Fix: `Quickshell.execDetached(["xdg-open", url])`.
- [x] **#5 Native: the battery state freezes while the screensaver shows.** The sampler stops when idle. Fix: a slow battery-only read while `ssShown`.
- [x] **#6 Native: a repeated `screensaver preview` resets `time` without resetting the schedule.** Fix: reset the pools when `time < lastTime`.
- [x] **#7 Native: sources aren't re-placed on a height change.** Only `onWidthChanged` calls placeSources(). Fix: add `onHeightChanged`.

## P3
- [x] fetch-news.py: no response size cap or overall deadline (`resp.read()`). A hung fetch blocks later fetches.
- [x] fetch-news.py: both plugins share a fixed `news.json.tmp`. Use mkstemp.
- [x] Terminal screensaver: no control-character filter on titles. Only reachable through a tampered news.json.
- [x] snapshot/ssSnapshot IPC writes to any path. Restrict to `~/.cache/vedaterm-snaps`.
- [x] Terminal screensaver: `Veda()` / `_load_news` run outside the try. A non-object news.json raises AttributeError, and `except Exception: rc = 1` hides errors.
- [x] Terminal screensaver: the node pulse is missed 40–70% of the time (`elif age < 0.66`). QML uses a `pulsed` flag.
- [x] Projection screen: `fastSpin: hs.hud.burst` still speeds the lattice up.
- [x] NewsPanel: the highlight lands on empty rows on a short last page.
- [x] QML source labels have no truncation (python uses [:17]).
- [x] Stale comments: VedaScreen "three batched paths", the screensaver state comments, python "matches VedaScreen.qml" and the "0.2s steps" comment. The unused `dim`, and an unreachable branch in wrap().
- [x] Duplication: category colours defined in 3 places; two byte-identical fetch-news.py copies.
- [x] Clutter: 25 `.bak.*` files (~830KB) and SoftKey.qml.unused.
- [x] No tests. A golden test for wrap/buildRow and clean() would be cheap.

## How each item was fixed (2026-10-05)
- #1: the lockCheck backstop now calls `screensaverHide(true)`.
- #2: idle notices go through an in-order queue (one Process; the next notice is sent from `onExited`). No drops and no reordering.
- #3: `textFormat: Text.PlainText` on every feed Text (NewsPanel, VedaScreensaver). The shared fetcher's `clean()` now unescapes, then strips tag-like text, turns a `<` before a letter into `‹`, collapses whitespace, and drops control characters.
- #4: `Quickshell.execDetached(["xdg-open", url])`.
- #5: a battery status read every 10s while the screensaver shows.
- #6: `reset()` runs when `time < lastTime`. Verified by sending preview twice.
- #7: `onHeightChanged: placeSources()`.
- P3:
  - The fetcher is now one shared copy at `~/.local/share/veda-news/fetch-news.py`, used by both plugins. It has a 2MB cap, a 30s per-feed deadline and uses mkstemp.
  - Terminal screensaver: `_printable()` filter; the load is robust and inside the try; tracebacks go to `~/.cache/veda-screensaver.log`; a `pulsed` flag; `--fps 4` is respected on battery.
  - Snapshot IPC only writes into `~/.cache/vedaterm-snaps/` (a bare name, or a path inside it).
  - `fastSpin: hs.burst` (off in projection); the grid copy of the core skips spin work.
  - NewsPanel highlight wraps on the real page length.
  - Source labels are cut to 17 characters.
  - Category colours come from `VedaTerminal.catColor()`/`catTag`; the python copy stays in CAT_COL.
  - Comments fixed; the unused `dim` and the dead wrap() branch removed; the hits pool reuses the oldest slot.
  - Backups archived to `~/.local/share/veda-backups/2026-10-05/archived/`.
  - Tests: `~/Work/bin/veda-selftest` (cleaning, size cap, escape filter, wrap, malformed caches, script syntax).
- Kept as designed:
  - ARCHIVED counts streams as well as headlines ("everything that reached the core").
  - Each non-mirrored screen runs its own screensaver instance.
  - The Exia NewsPanel still uses AutoText, but its data is now cleaned by the shared fetcher.
