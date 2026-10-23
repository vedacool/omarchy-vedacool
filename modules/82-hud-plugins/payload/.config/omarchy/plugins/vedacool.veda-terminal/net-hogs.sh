#!/usr/bin/env bash
# net-hogs.sh — per-process network bandwidth, no root, no python.
#
# Two `ss` snapshots ~SAMPLE apart, diff each socket's byte counters, sum by
# process name. Covers your own apps (~all a laptop's traffic); transfers ss
# can't attribute group as "system". Pure bash+awk — lighter than a python
# interpreter and avoids spawning one every few seconds.
#
# Output (rates in bytes/sec), parsed by the VEDA HUD:
#   TOTAL <dl> <ul> <nactive>
#   <name> <dl> <ul>        (top processes, busiest first)

SAMPLE=1.2
THRESH=2048      # hide < 2 KB/s (dl+ul)
TOPN=6

snap() {
  # emit "local|peer proc bytes_received bytes_acked" per socket
  ss -tinupH 2>/dev/null | awk '
    /^[^ \t]/ {
      proc = "system"
      if (match($0, /\(\("[^"]+"/)) proc = substr($0, RSTART + 3, RLENGTH - 4)
      key = $4 "|" $5
      next
    }
    /bytes_received:|bytes_acked:/ {
      rx = 0; tx = 0
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^bytes_received:/) { split($i, a, ":"); rx = a[2] }
        if ($i ~ /^bytes_acked:/)    { split($i, b, ":"); tx = b[2] }
      }
      if (key != "") print key, proc, rx, tx
    }'
}

A=$(snap)
sleep "$SAMPLE"
B=$(snap)

awk -v s="$SAMPLE" -v th="$THRESH" -v topn="$TOPN" '
  NR == FNR { arx[$1] = $3; atx[$1] = $4; seen1[$1] = 1; next }
  {
    if ($1 in seen1) {
      drx = $3 - arx[$1]; dtx = $4 - atx[$1]
      if (drx > 0) dl[$2] += drx
      if (dtx > 0) ul[$2] += dtx
      if (drx > 0 || dtx > 0) procs[$2] = 1
    }
  }
  END {
    n = 0; td = 0; tu = 0; nactive = 0
    for (p in procs) {
      d = dl[p] / s; u = ul[p] / s
      if (d + u >= th) { name[n] = p; dd[n] = d; uu[n] = u; n++; td += d; tu += u; nactive++ }
    }
    # tiny list: selection sort by (dl+ul) desc
    for (i = 0; i < n; i++)
      for (j = i + 1; j < n; j++)
        if (dd[j] + uu[j] > dd[i] + uu[i]) {
          t = name[i]; name[i] = name[j]; name[j] = t
          t = dd[i]; dd[i] = dd[j]; dd[j] = t
          t = uu[i]; uu[i] = uu[j]; uu[j] = t
        }
    printf "TOTAL %d %d %d\n", td, tu, nactive
    for (i = 0; i < n && i < topn; i++) {
      gsub(/ /, "_", name[i])
      printf "%s %d %d\n", name[i], dd[i], uu[i]
    }
  }
' <(printf '%s\n' "$A") <(printf '%s\n' "$B")
