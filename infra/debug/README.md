# Thorium Debug Tools

This directory contains ad hoc diagnostics for browser, renderer, and profile
issues. These tools are not part of the canonical build flow.

## Renderer CPU Snapshot

Capture the busiest Thorium renderer processes and optional profiler data:

```bash
infra/debug/debug_thorium_renderer_cpu.sh
```

The script writes logs under `/tmp/thorium-renderer-debug-*`.

## History CPU Sampler

Build the helper outside the repository, then open `chrome://history` and sample
Thorium process CPU usage:

```bash
cc -O2 -Wall -Wextra -o /tmp/debug_thorium_history infra/debug/debug_thorium_history.c
/tmp/debug_thorium_history
```

Use `--monitor-only` to sample an already-running browser without opening a new
history tab.
