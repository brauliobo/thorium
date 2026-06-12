# Thorium Tools

This directory contains optional maintenance and reproduction helpers. The
canonical rebase/build flow remains documented in the repository root.

## Profiled Linux Build

Build a symbolized, profiling-friendly Thorium output directory:

```bash
infra/tools/build_profiled_thorium.sh 6
```

The script defaults to `$HOME/chromium/src`. Override with `CR_DIR`,
`CR_SRC_DIR`, or `OUT_DIR` when using another Chromium checkout or output dir.

## CDP Process Dump

Dump process, target, performance, and `chrome://discards` state from a running
Thorium instance with remote debugging enabled:

```bash
python -m pip install websockets
thorium-browser --remote-debugging-port=9222
infra/tools/cdp_process_dump.py 9222 /tmp/thorium-cdp-dump
```

## NVIDIA VP9 Decode Stress

Stress Chromium's VP9 hardware decode path while collecting NVIDIA telemetry:

```bash
autoninja -C out/thorium media/gpu/test:video_decode_accelerator_perf_tests
infra/tools/stress_nvidia_vp9_decode.sh
```

The script defaults to `$HOME/chromium/src` and `out/thorium`. Override
`CHROMIUM_SRC`, `CR_DIR`, `CR_SRC_DIR`, or `OUT_DIR` as needed.
