@ECHO OFF
START "" "%cd%\BIN\alacrium.exe" --user-data-dir="%~dp0%\USER_DATA" --allow-outdated-plugins --disable-logging --disable-breakpad --disable-encryption --disable-machine-id
