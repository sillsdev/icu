# Android ICU4C build

`build-android.sh` cross-compiles the checked-out, SIL-modified ICU4C source in
`../source` for Android. It does not download, unpack, or substitute an
upstream ICU release. The current `fw` checkout determines the ICU version and
therefore the generated data file name.

The build creates host ICU tools first, then uses them with the Android NDK
toolchain to cross-compile each requested ABI. It validates native-library
output only; it does not build or run an Android application, emulator, or
device test.

## Prerequisites

On Linux or macOS install a POSIX shell environment with `bash`, `make`, `sed`,
`find`, `sort`, a C/C++ host compiler, and the Android NDK. Android API 21 is
the default minimum API. The CI configuration uses NDK `27.0.12077973`.

Set `ANDROID_NDK_HOME` to the NDK installation. Alternatively, set
`ANDROID_HOME` to the Android SDK root and the script selects the latest
installed `ndk/<version>` directory.

```bash
export ANDROID_NDK_HOME=/opt/android-ndk-r27
bash ./icu4c/packaging/build-android.sh --arch=x86_64,arm64-v8a
```

On Windows, install Git for Windows and an Android NDK installed for Windows.
From PowerShell, run:

```powershell
$env:ANDROID_NDK_HOME = 'C:\Android\Sdk\ndk\27.0.12077973'
.\icu4c\packaging\build-android.ps1 -Arch x86_64,arm64-v8a
```

The PowerShell wrapper deliberately invokes Git Bash. It does not use WSL:
WSL must run `bash ./icu4c/packaging/build-android.sh` and use an NDK
installed for Linux inside WSL. A Windows NDK cannot be reused from WSL, and a
Linux NDK cannot be used by Git Bash.

## Controls and cleanup

```bash
# Default fast validation ABI
bash ./icu4c/packaging/build-android.sh

# Select an API level and both supported ABIs
bash ./icu4c/packaging/build-android.sh --api=21 --arch=x86_64,arm64-v8a

# Delete one ABI's build and installed output before rebuilding it
bash ./icu4c/packaging/build-android.sh --clean-arch=x86_64 --arch=x86_64

# Delete all generated host tools, cross-build trees, data, and libraries
bash ./icu4c/packaging/build-android.sh --clean
```

Supported ABI values are `x86_64` and `arm64-v8a`. Use `--help` for the full
command reference. The generated `icu4c/out/` directory is already ignored by
this repository.

## Output and Android integration

For the checked-out ICU `70.1`, the output layout is:

```text
icu4c/out/android-icu/
  icudt70l.dat
  x86_64/
    libc++_shared.so
    libicuuc.so
    libicui18n.so
    libicudata.so
    libicu*.so.70[.1]
  arm64-v8a/
    libc++_shared.so
    libicuuc.so
    libicui18n.so
    libicudata.so
    libicu*.so.70[.1]
```

The library major and data-file name are derived from the local ICU source, so
they change automatically when this branch advances to a different ICU major.
The unversioned `.so` files are the names Android APK packaging expects; the
versioned copies remain alongside them for native dependency compatibility.

Android consumers are responsible for embedding `icudt70l.dat` (or the
locally-derived replacement after an ICU update) as an app data asset and for
packaging the ABI-specific, unversioned `libc++_shared.so`, `libicuuc.so`,
`libicui18n.so`, and `libicudata.so` files in their APK/AAB. This repository
only produces the native inputs; it does not publish a package or validate an
application's integration.

## Troubleshooting

- If the script reports a missing NDK, set `ANDROID_NDK_HOME` explicitly.
- If it reports a mismatched NDK toolchain, install the NDK for the host that
  executes the script: Linux for Linux/WSL, Windows for Git Bash, or macOS for
  macOS.
- Use `--clean` after changing host compilers, NDK versions, or ICU source
  configuration to ensure host tools and cross-build output are recreated.