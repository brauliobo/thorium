## Alacrium AppImage Generation <img src="https://raw.githubusercontent.com/brauliobo/alacrium/main/logos/STAGING/Appimage_Logo.svg" width="36">

### Instructions
This directory contains files to generate an .AppImage of Alacrium.

You __must__ place the .deb file (generated from running `package.sh`) in this directory, and then run `./make_appimage.sh`

When it is done, you will have an appimage in *out*, I.E. it should be something like `//alacrium/infra/APPIMAGE/out/Alacrium_Browser-104.0.5107.0.glibc2.17-x86_64.AppImage`

You can use it standalone, after making it executable with `sudo chmod +x Alacrium_Browser-*`, or (*recommended*) to integrate it with your system you can use [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher).

 - Running `./extract_appimage.sh` will extract the appimage contents to *out/Alacrium_squashfs-root*
 - The *files* subdir contains files needed for the 22px and 512px icons, and a alacrium-shell wrapper that allows alacrium_shell to run properly in an AppImage.

 - *See also:* [About AppImages](https://appimage.org/)

### About
&ndash; This infra project uses [*pkg2appimage*](https://github.com/AppImage/pkg2appimage/blob/master/pkg2appimage) from here > https://github.com/AppImage/pkg2appimage \
The [Alacrium recipe](Alacrium.yml) was modeled after the upstream
[Chromium pkg2appimage recipe](https://github.com/AppImage/pkg2appimage/blob/master/recipes/Chromium.yml).
