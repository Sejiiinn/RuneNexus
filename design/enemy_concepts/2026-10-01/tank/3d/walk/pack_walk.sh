#!/bin/sh
# Reuse the guardian's existing ffmpeg-based render packing path.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH= cd -- "$DIR/../../../../../.." && pwd)
cd "$DIR"
FFMPEG=${FFMPEG:-$REPO/build/startup-restoration-20260924/video-tools/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1}
QUALITY=${1:-final}
FONT=/System/Library/Fonts/Supplemental/Arial.ttf
if [ "$QUALITY" = draft ]; then
  COUNT=26
  OUTPUT=local/draft
else
  COUNT=52
  OUTPUT=.
fi
mkdir -p "$OUTPUT"
for view in three-quarter side; do
  test -f "local/$QUALITY/$view/$(printf '%04d' "$COUNT").png"
  "$FFMPEG" -hide_banner -loglevel error -y -framerate 60 -i "local/$QUALITY/$view/%04d.png" -vf "loop=loop=2:size=$COUNT:start=0,settb=expr=1/60,setpts=N,drawbox=x=0:y=0:w=iw:h=38:color=black@0.45:t=fill,drawtext=fontfile=$FONT:text='Tank - $view':fontcolor=white:fontsize=20:x=16:y=9,drawtext=fontfile=$FONT:text='0.65625 tile/s - $COUNT frames x 3 repeats':fontcolor=white:fontsize=17:x=16:y=h-26:box=1:boxcolor=black@0.45" -frames:v "$((COUNT*3))" -r 60 -fps_mode cfr -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUTPUT/walk-$view.mp4"
done
"$FFMPEG" -hide_banner -loglevel error -y -i "$OUTPUT/walk-three-quarter.mp4" -i "$OUTPUT/walk-side.mp4" -filter_complex '[0:v][1:v]hstack=inputs=2[v]' -map '[v]' -r 60 -fps_mode cfr -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart "$OUTPUT/tank-walk.mp4"
if [ "$QUALITY" = final ]; then
  for view in three-quarter side; do
    "$FFMPEG" -hide_banner -loglevel error -y -framerate 60 -i "local/final/$view/%04d.png" -vf "select='eq(n,0)+eq(n,7)+eq(n,13)+eq(n,20)',tile=4x1" -frames:v 1 "local/phase-$view.png"
  done
  "$FFMPEG" -hide_banner -loglevel error -y -i local/phase-three-quarter.png -i local/phase-side.png -filter_complex '[0:v][1:v]vstack=inputs=2[v]' -map '[v]' -frames:v 1 walk-phase-sheet.png
fi
