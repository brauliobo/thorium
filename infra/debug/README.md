# Alacrium Debug Tools

This directory contains ad hoc diagnostics for browser, renderer, and profile
issues. These tools are not part of the canonical build flow.

## Renderer CPU Snapshot

Capture the busiest Alacrium renderer processes and optional profiler data:

```bash
infra/debug/debug_alacrium_renderer_cpu.sh
```

The script writes logs under `/tmp/alacrium-renderer-debug-*`.

## History CPU Sampler

Build the helper outside the repository, then open `chrome://history` and sample
Alacrium process CPU usage:

```bash
cc -O2 -Wall -Wextra -o /tmp/debug_alacrium_history infra/debug/debug_alacrium_history.c
/tmp/debug_alacrium_history
```

Use `--monitor-only` to sample an already-running browser without opening a new
history tab.
