#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHROMIUM_SRC="${ROOT}/chromium/src"
OUT_DIR="${OUT_DIR:-out/alacrium}"
TEST_BIN="$CHROMIUM_SRC/$OUT_DIR/video_decode_accelerator_perf_tests"
WORK_DIR="${WORK_DIR:-$ROOT/.tmp/nvidia-vp9-decode}"
BASE_VIDEO="${BASE_VIDEO:-$CHROMIUM_SRC/media/test/data/test-25fps.vp9}"
VIDEO="$WORK_DIR/long-vp9.ivf"
META="$VIDEO.json"
LOOPS="${LOOPS:-180}"
ITERATIONS="${ITERATIONS:-0}"
GPU_PROBE_INTERVAL="${GPU_PROBE_INTERVAL:-30}"
LOG="$WORK_DIR/stress.log"
RENDER_NODE="${RENDER_NODE:-}"
OZONE_PLATFORM="${OZONE_PLATFORM:-wayland}"
DURATION="${DURATION:-}"

mkdir -p "$WORK_DIR"

if [[ -z "$RENDER_NODE" ]]; then
  RENDER_NODE="$(readlink -f /dev/dri/by-path/*-render 2>/dev/null | head -1 || true)"
fi

if [[ ! -x "$TEST_BIN" ]]; then
  echo "Missing $TEST_BIN; build media/gpu/test:video_decode_accelerator_perf_tests first." >&2
  exit 1
fi

if [[ ! -f "$VIDEO" || "$BASE_VIDEO" -nt "$VIDEO" ]]; then
  ffmpeg_duration=()
  if [[ -n "$DURATION" ]]; then
    ffmpeg_duration=(-t "$DURATION")
  fi
  ffmpeg -hide_banner -loglevel error -y -stream_loop "$LOOPS" \
    -i "$BASE_VIDEO" "${ffmpeg_duration[@]}" -map 0:v:0 -c:v copy -an "$VIDEO"
fi

width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO")"
height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO")"
frames="$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$VIDEO")"
rate="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$VIDEO")"
fps="$(awk -F/ 'NF == 2 && $2 != 0 { printf "%d", ($1 / $2) + 0.5; next } { print int($1 + 0.5) }' <<<"$rate")"

cat > "$META" <<JSON
{
  "profile": "VP9PROFILE_PROFILE0",
  "width": $width,
  "height": $height,
  "frame_rate": $fps,
  "num_frames": $frames,
  "md5_checksums": []
}
JSON

probe_gpu_once() {
  nvidia-smi --query-gpu=timestamp,index,name,pci.bus_id,utilization.gpu,utilization.memory,utilization.decoder,memory.used \
    --format=csv,noheader,nounits >> "$WORK_DIR/nvidia-smi.csv" 2>>"$LOG" || true
  nvidia-smi pmon -c 1 >> "$WORK_DIR/nvidia-pmon.log" 2>>"$LOG" || true
}

stress_gpu_once() {
  probe_gpu_once
  if command -v nvtop >/dev/null; then
    timeout 5s nvtop >/dev/null 2>>"$LOG" || true
  fi
  if command -v nvidia-smi >/dev/null; then
    timeout 5s nvidia-smi dmon -s u -c 3 >> "$WORK_DIR/nvidia-dmon.log" 2>>"$LOG" || true
  fi
}

run_one_decode() {
  LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-nvidia}" \
  NVD_BACKEND="${NVD_BACKEND:-direct}" \
  "$TEST_BIN" \
    --gtest_filter='VideoDecoderTest.MeasureCappedPerformance' \
    --ozone-platform="$OZONE_PLATFORM" \
    --use-gl=egl \
    ${RENDER_NODE:+--render-node-override="$RENDER_NODE"} \
    --enable-features=VaapiOnNvidiaGPUs,AcceleratedVideoDecodeLinux \
    --v=1 \
    "--vmodule=*media/gpu*=3,*vaapi*=3,*video_decoder*=3" \
    --output_folder="$WORK_DIR/perf" \
    "$VIDEO" "$META"
}

echo "video=$VIDEO" | tee "$LOG"
echo "metadata=$META" | tee -a "$LOG"
echo "iterations=$ITERATIONS, probe_interval=${GPU_PROBE_INTERVAL}s" | tee -a "$LOG"

i=0
while (( ITERATIONS == 0 || i < ITERATIONS )); do
  i=$((i + 1))
  echo "== decode iteration $i ==" | tee -a "$LOG"
  run_one_decode >>"$LOG" 2>&1 &
  decode_pid=$!

  while kill -0 "$decode_pid" 2>/dev/null; do
    stress_gpu_once
    sleep "$GPU_PROBE_INTERVAL"
  done

  set +e
  wait "$decode_pid"
  rc=$?
  set -e
  if (( rc != 0 )); then
    echo "decode failed: iteration=$i rc=$rc" | tee -a "$LOG"
    exit "$rc"
  fi
done
