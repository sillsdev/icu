### Packaging icu4c.win.fw.lib
To build the Nuget package run: `msbuild icu4c.proj /t:Build;BuildPackage`

To control the version number of the package you can set the `BuildCounter` and the `PreRelease` properties.

e.g. `msbuild icu4c.proj /t:Build;BuildPackage /p:BuildCounter=22 /p:PreRelease=beta`