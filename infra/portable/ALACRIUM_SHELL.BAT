@ECHO OFF
START "" "%cd%\BIN\138.0.7204.306\alacrium_shell.exe" --user-data-dir="%~dp0%\USER_DATA\alacrium_shell" --allow-outdated-plugins --disable-logging --disable-breakpad --enable-experimental-web-platform-features --disable-encryption --disable-machine-id
