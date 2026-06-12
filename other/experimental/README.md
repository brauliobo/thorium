# Experimental Patches

Patches in this directory are optional experiments. They are intentionally not
applied by `setup.sh`; apply and validate them manually against the Chromium
checkout before promoting them into the default patch list.

## Session Restore Throttle

`session-restore-throttle.patch` reduces concurrent background tab restore work
to help reproduce and bisect session restore pressure.
