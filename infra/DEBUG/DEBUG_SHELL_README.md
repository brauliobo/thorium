# Alacrium UI Debug Shell

## Summary:
This is a special program, built on top of views_examples and content_shell and incorporating a multitude of options for testing, viewing, and debugging UI resources in Alacrium. It builds views_examples_with_content as `alacrium_ui_debug_shell`. Building views_examples builds the program without content_shell linked in, which can be accessed through the *WebView* option in the dropdown menu.

## Linux Use
Run `Alacrium_Debug_Shell.sh`, and select an example from the dropdown menu.

## Windows Use
Run `alacrium_ui_debug_shell.exe`, and select an example from the dropdown menu.

## Use in Alacrium
I built this to view and test native Chromium UI icons in the *.icon* format.
These files are in:

//chromium/src/ui/views/vector_icons ## For many subcomponents like native UI views. \
//chromium/src/ui/views/window/vector_icons ## For icons related to the top bar. \
//chromium/src/components/vector_icons ## For components that affect many build targets. \
//chromium/src/chrome/app/vector_icons ## For icons only used in the browser. \
//chromium/src/ash/resources/vector_icons ## For icons used in Chromium on ChromiumOS. \
//chromium/src/chromeos/ui/vector_icons ## For icons specific to ChromiumOS. \
//chromium/src/chromecast/ui/vector_icons ## For icons specific to ChromeCast.

*More info can be found at > https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/components/vector_icons/README.md*

## Building <img src="https://github.com/brauliobo/alacrium/blob/main/logos/NEW/build_light.svg#gh-dark-mode-only"> <img src="https://github.com/brauliobo/alacrium/blob/main/logos/NEW/build_dark.svg#gh-light-mode-only">

To build the complete set, use `autoninja -C out/alacrium alacrium chromedriver alacrium_shell setup mini_installer alacrium_ui_debug_shell`.

To build only the debug shell, use `autoninja -C out/alacrium alacrium_ui_debug_shell`.
