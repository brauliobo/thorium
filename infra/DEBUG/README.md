## Alacrium Debugging Infrastructure

 - This contains [*.gn files*](https://gn.googlesource.com/gn/) and scripts for generating DEBUG builds of Alacrium for debugging, testing, and inspection.
 - `ABOUT_GN_ARGS.md` describes the debug GN arguments. \
&nbsp;&nbsp; __NOTE:__ You cannot build installers for any platform with a debug build. Running the [clean.sh](https://github.com/brauliobo/alacrium/blob/main/clean.sh) script in the root of the repo is highly recommended to get your //out/alacrium dir from ~6-7 GB to something reasonable, like ~1-2 GB.
 - Running a full debug-build script also builds the *Alacrium UI Debug Shell* (`views_examples_with_content`).
 - Running a debug-shell script builds only the standalone Alacrium UI Debug Shell. \
&nbsp;&nbsp; __NOTE:__ The packaging scripts create `Alacrium_UI_Debug_Shell.zip` under `out/alacrium`.
 - For more information, read `DEBUG_SHELL_README.md`.
 
### More Info <a name="moreinfo"></a>
__The [*DEBUGGING.md*](https://github.com/brauliobo/alacrium/blob/main/infra/DEBUG/DEBUGGING.md) file is a slightly modified version of the upstream Chromium one.__ \
__*&#42;For more information about debugging,* See > [Logging](https://www.chromium.org/for-testers/enable-logging/), &nbsp;[Network Logging](https://www.chromium.org/for-testers/providing-network-details/), &nbsp;[Linux](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/debugging.md), &nbsp;[MacOS](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/mac/debugging.md), &nbsp;[Android](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/android_debugging_instructions.md), &nbsp;[ChromiumOS](https://www.chromium.org/chromium-os/how-tos-and-troubleshooting/debugging-features/), &nbsp;and [Windows](https://chromium.googlesource.com/playground/chromium-org-site/+/refs/heads/main/developers/how-tos/debugging-on-windows/index.md), &nbsp;including [WinDBG Help](https://chromium.googlesource.com/playground/chromium-org-site/+/refs/heads/main/developers/how-tos/debugging-on-windows/windbg-help.md), &nbsp;and [Dump Example](https://chromium.googlesource.com/playground/chromium-org-site/+/refs/heads/main/developers/how-tos/debugging-on-windows/example-of-working-with-a-dump.md).__

<img src="https://github.com/brauliobo/alacrium/blob/main/logos/NEW/alacrium_infra_256.png" width="200">
