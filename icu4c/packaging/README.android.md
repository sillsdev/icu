# Android ICU4C build

`build-android.sh` cross-compiles the checked-out, SIL-modified ICU4C source in
`../source` for Android. It does not download, unpack, or substitute an
upstream ICU release. The current `fw` checkout determines the ICU version and
therefore the generated data file name.

The build creates host ICU tools first, then uses them with the Android NDK
toolchain to cross-compile each requested ABI. It validates native-library
output only; it does not build or run an Android application, emulator, or
device test.

CI packs the build into the `Icu4c.Android.Fw.Lib` NuGet package for MAUI /
.NET Android consumers.

## Prerequisites

On Linux or macOS install a POSIX shell environment with `bash`, `make`, `sed`,
`find`, `sort`, a C/C++ host compiler, and the Android NDK. Android API 21 is
the default minimum API. The CI configuration uses NDK `27.0.12077973`.

Set `ANDROID_NDK_HOME` to the NDK installation. Alternatively, set
`ANDROID_HOME` to the Android SDK root and the script selects the latest
installed `ndk/<version>` directory.

```bash
export ANDROID_NDK_HOME=/opt/android-ndk-r27
bash ./icu4c/packaging/build-android.sh --arch=x86_64,arm64-v8a,armeabi-v7a
```

On Windows, install Git for Windows and an Android NDK installed for Windows,
then run the script from Git Bash:

```bash
export ANDROID_NDK_HOME='C:\Android\Sdk\ndk\27.0.12077973'
bash ./icu4c/packaging/build-android.sh --arch=x86_64,arm64-v8a,armeabi-v7a
```

Git Bash and WSL need different NDKs: a Windows NDK cannot be reused from WSL,
and a Linux NDK cannot be used by Git Bash. Under WSL, run the same
`bash ./icu4c/packaging/build-android.sh` command with an NDK installed for
Linux inside WSL.

## Controls and cleanup

```bash
# Default fast validation ABI
bash ./icu4c/packaging/build-android.sh

# Select an API level and all supported ABIs
bash ./icu4c/packaging/build-android.sh --api=21 --arch=x86_64,arm64-v8a,armeabi-v7a

# Delete one ABI's build and installed output before rebuilding it
bash ./icu4c/packaging/build-android.sh --clean-arch=x86_64 --arch=x86_64

# Delete all generated host tools, cross-build trees, data, and libraries
bash ./icu4c/packaging/build-android.sh --clean
```

Supported ABI values are `x86_64`, `arm64-v8a`, and `armeabi-v7a`. Use `--help`
for the full command reference. The generated `icu4c/out/` directory is already
ignored by this repository.

## Output layout

For the checked-out ICU `70.1`, the output layout is:

```text
icu4c/out/android-icu/
  icudt70l.dat
  x86_64/
    libc++_shared.so
    libicuuc.so
    libicui18n.so
    libicudata.so
  arm64-v8a/
    libc++_shared.so
    libicuuc.so
    libicui18n.so
    libicudata.so
  armeabi-v7a/
    libc++_shared.so
    libicuuc.so
    libicui18n.so
    libicudata.so
```

Cross builds use `--with-data-packaging=archive`, so `libicudata.so` is the
**stub** data library. Locale data lives in `icudt*l.dat`. Consumers (for
example `AndroidIcuBootstrap` in icu-dotnet) must load that file via
`udata_setCommonData` (or equivalent) before using ICU.

Shared libraries are linked with **unversioned** SONAMEs (`libicuuc.so`, and so
on) so Android APK packaging of those file names alone satisfies `DT_NEEDED`.
The library major and data-file name are derived from the local ICU source, so
they change automatically when this branch advances to a different ICU major.

## NuGet package (MAUI / .NET Android)

CI packs unversioned ABI libraries plus `icudt*l.dat` into
[`Icu4c.Android.Fw.Lib`](https://www.nuget.org/packages/Icu4c.Android.Fw.Lib).
The major version of the package matches the ICU release (same scheme as
`Icu4c.Win.Fw.Lib`).

```xml
<ItemGroup>
  <PackageReference Include="Icu4c.Android.Fw.Lib" Version="[70.1.0,71.0.0)" />
</ItemGroup>
```

The package’s MSBuild targets add `AndroidNativeLibrary` entries for
`x86_64`, `arm64-v8a`, and `armeabi-v7a` and embed `icudt70l.dat` as an
`AndroidAsset`.
Consumers do not need manual `AndroidNativeLibrary` / `AndroidAsset`
ItemGroups. The props file also stamps `IcuFwAndroidMajorVersion` for
consumers that need the ICU major (for example aligning
`AndroidIcuBootstrap`).

Pack a local `.nupkg` after a successful Android build:

```bash
bash ./icu4c/packaging/pack-android-nuget.sh --version=70.1.0
```

Keep the consumer’s ICU major (for example `AndroidIcuBootstrap` in
icu-dotnet) aligned with the referenced package major.

## Troubleshooting

- If the script reports a missing NDK, set `ANDROID_NDK_HOME` explicitly.
- If it reports a mismatched NDK toolchain, install the NDK for the host that
  executes the script: Linux for Linux/WSL, Windows for Git Bash, or macOS for
  macOS.
- Use `--clean` after changing host compilers, NDK versions, or ICU source
  configuration to ensure host tools and cross-build output are recreated.
- ICU operations that need locale data will fail until the app loads
  `icudt*l.dat` into ICU (stub `libicudata.so` alone is not enough).
