#!/bin/bash
# generate-frames.sh — (re)build the VEDA living-wallpaper frames.
#
# Produces a set of 2560x1440 frames that share ONE fixed starfield + quantum
# mesh, and differ only in which particles are lit bright. veda-wallpaper-cycle
# swaps between them every few seconds, so random stars "twinkle" across the
# field at near-zero GPU cost (no live/animated wallpaper -- this laptop's
# Radeon can't run one safely). A soft mist is baked in faintly, for depth only;
# on a HUD-heavy desktop the moving element has to be bright POINTS (they show
# through the thin gaps), not a soft glow (which needs open canvas it never has).
#
# Needs ImageMagick (`magick`). Usage: generate-frames.sh [frame_count]
set -u
command -v magick >/dev/null || { echo "generate-frames.sh: needs ImageMagick (magick)" >&2; exit 1; }

W=2560; H=1440
OUT="$HOME/.local/share/veda-wallpaper/frames"
FRAMES="${1:-6}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
cd "$TMP" || exit 1

# ---- fixed starfield base (same across every frame) ----
magick -size ${W}x${H} radial-gradient:'#0a1c15'-'#03060a' b.png
magick -size 48x48 xc:none -fill none -stroke '#0c2117' -strokewidth 1 -draw "line 0,0 0,48 line 0,0 48,0" gt.png
magick b.png \( -size ${W}x${H} tile:gt.png \) -compose over -composite s1.png
RINGS=""; for rad in 560 920 1300 1720; do RINGS+=" stroke-opacity 0.12 fill none stroke #2fa876 stroke-width 1.5 circle 2560,160 $((2560+rad)),160"; done
magick s1.png \( -size ${W}x${H} radial-gradient:'#124a33'-'#00000000' -gravity NorthEast -background none -extent ${W}x${H} -evaluate multiply 0.5 \) -compose screen -composite -draw "$RINGS" s2.png
# fixed quantum mesh + fixed dust (seeded so they never move)
RANDOM=42; N=110; declare -a xs ys
for ((i=0;i<N;i++)); do xs[$i]=$((RANDOM%W)); ys[$i]=$((RANDOM%H)); done
TH=245; LINES=""; for ((i=0;i<N;i++)); do for ((j=i+1;j<N;j++)); do dx=$((xs[i]-xs[j])); dy=$((ys[i]-ys[j])); if (( dx*dx+dy*dy < TH*TH )); then LINES+=" stroke-opacity 0.12 stroke #3fcf8e stroke-width 1 line ${xs[i]},${ys[i]} ${xs[j]},${ys[j]}"; fi; done; done
NODES=""; for ((i=0;i<N;i++)); do NODES+=" fill #6fe8b0 circle ${xs[i]},${ys[i]} $((xs[i]+2)),${ys[i]}"; done
DUST=""; for i in $(seq 1 460); do x=$((RANDOM%W)); y=$((RANDOM%H)); r=$((RANDOM%2+1)); if (( RANDOM%6==0 )); then c="d8b24e"; else c="46c892"; fi; a=$(printf '%02x' $((RANDOM%110+30))); DUST+=" fill #${c}${a} circle ${x},${y} $((x+r)),${y}"; done
magick s2.png -draw "$LINES" -draw "$NODES" -draw "$DUST" starbase.png
# faint static mist for depth (NOT the moving element)
magick -size 1600x1600 radial-gradient:'#2a9668'-'#00000000' -evaluate multiply 0.28 mist.png
magick starbase.png \( mist.png -repage +250+40 \) -compose screen -composite starbase2.png

# ---- per-frame twinkles: ~26 random bright particles, different each frame ----
for f in $(seq 1 "$FRAMES"); do
  TW=""
  for k in $(seq 1 26); do
    tx=$((RANDOM%W)); ty=$((RANDOM%H)); r=$((RANDOM%3+2))
    if (( RANDOM%5==0 )); then c="ffe9a6"; else c="d6ffe4"; fi
    TW+=" fill #${c} circle ${tx},${ty} $((tx+r)),${ty}"
  done
  magick starbase2.png -draw "$TW" \
    \( +clone -blur 0x5 -evaluate multiply 0.78 \) -compose screen -composite \
    \( -size ${W}x${H} radial-gradient:'#ffffff'-'#6a6a6a' \) -compose multiply -composite \
    -quality 92 "$OUT/frame-$f.jpg"
done
echo "generate-frames.sh: wrote $FRAMES frames to $OUT"
