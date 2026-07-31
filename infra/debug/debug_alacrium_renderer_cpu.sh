#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-/tmp/alacrium-renderer-debug-$(date +%Y%m%d-%H%M%S)}"
SAMPLE_SECONDS="${SAMPLE_SECONDS:-5}"
TOP_N="${TOP_N:-5}"

mkdir -p "$OUT_DIR"

ps -eo pid,ppid,pcpu,pmem,stat,etime,args --sort=-pcpu \
  > "$OUT_DIR/processes.ps"
awk 'index($0, "/opt/alacrium-browser/alacrium") && index($0, "--type=renderer") {print}' \
  "$OUT_DIR/processes.ps" | head -"$TOP_N" > "$OUT_DIR/renderers.ps"

awk '{print $1}' "$OUT_DIR/renderers.ps" > "$OUT_DIR/renderers.pids"

while read -r pid; do
  [[ -n "$pid" && -d "/proc/$pid" ]] || continue
  pid_dir="$OUT_DIR/pid-$pid"
  mkdir -p "$pid_dir"

  tr '\0' ' ' < "/proc/$pid/cmdline" > "$pid_dir/cmdline.txt" || true
  cat "/proc/$pid/status" > "$pid_dir/status.txt" || true
  cat "/proc/$pid/smaps_rollup" > "$pid_dir/smaps_rollup.txt" 2>/dev/null || true
  ps -L -p "$pid" -o pid,tid,psr,pcpu,pmem,stat,comm,wchan:40 \
    --sort=-pcpu > "$pid_dir/threads.ps" || true

  for tid in $(awk 'NR > 1 {print $2}' "$pid_dir/threads.ps" | head -8); do
    [[ -r "/proc/$pid/task/$tid/stack" ]] &&
      cat "/proc/$pid/task/$tid/stack" > "$pid_dir/thread-$tid.kernel-stack.txt" || true
    [[ -r "/proc/$pid/task/$tid/stat" ]] &&
      cat "/proc/$pid/task/$tid/stat" > "$pid_dir/thread-$tid.stat.txt" || true
  done

  if command -v gdb >/dev/null; then
    timeout 20s gdb -batch -q -p "$pid" \
      -ex 'set pagination off' \
      -ex 'thread apply all bt 20' \
      -ex detach \
      -ex quit > "$pid_dir/gdb-bt.txt" 2>&1 || true
  fi

  if command -v perf >/dev/null; then
    timeout "$((SAMPLE_SECONDS + 5))s" perf record -g -p "$pid" \
      -o "$pid_dir/perf.data" -- sleep "$SAMPLE_SECONDS" > "$pid_dir/perf-record.log" 2>&1 || true
    perf report -i "$pid_dir/perf.data" --stdio --no-children \
      > "$pid_dir/perf-report.txt" 2>&1 || true
  fi
done < "$OUT_DIR/renderers.pids"

echo "$OUT_DIR"
