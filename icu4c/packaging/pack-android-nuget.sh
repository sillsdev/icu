#!/usr/bin/env bash
# Copyright (c) 2026 SIL Global
# Stage Android ICU build output and pack Icu4c.Android.Fw.Lib.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICU4C_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INPUT_DIR="${INPUT_DIR:-$ICU4C_DIR/out/android-icu}"
ASSETS_DIR="$ICU4C_DIR/nugetpackage/assets/android"
OUTPUT_DIR="${OUTPUT_DIR:-$ICU4C_DIR/nugetpackage}"
PKG_VERSION=""
ABIS="${ABIS:-x86_64,arm64-v8a}"

usage() {
    cat <<EOF
Usage: $0 --version=VERSION [options]

Options:
  --version=VERSION   Package version (required), e.g. 70.1.123
  --input=DIR         Android ICU output (default: icu4c/out/android-icu)
  --output=DIR        Directory for the .nupkg (default: icu4c/nugetpackage)
  --abis=LIST         Comma-separated ABIs to include (default: x86_64,arm64-v8a)
  --help              Show this help
EOF
}

log() { echo "[pack-android-nuget] $*"; }
die() { echo "[pack-android-nuget] ERROR: $*" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --help|-h) usage; exit 0 ;;
        --version=*) PKG_VERSION="${arg#*=}" ;;
        --input=*) INPUT_DIR="${arg#*=}" ;;
        --output=*) OUTPUT_DIR="${arg#*=}" ;;
        --abis=*) ABIS="${arg#*=}" ;;
        *) die "Unknown option: $arg" ;;
    esac
done

[[ -n "$PKG_VERSION" ]] || die "Missing --version"
[[ -d "$INPUT_DIR" ]] || die "Input directory not found: $INPUT_DIR"
[[ -f "$ASSETS_DIR/build/Icu4c.Android.Fw.Lib.targets" ]] || die "Missing targets under $ASSETS_DIR/build"
[[ -f "$ICU4C_DIR/LICENSE" ]] || die "Missing LICENSE at $ICU4C_DIR/LICENSE"

command -v dotnet >/dev/null || die "dotnet SDK is required to pack the NuGet package"
command -v unzip >/dev/null || die "unzip is required to verify the NuGet package layout"

STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/icu-android-nuget.XXXXXX")"
cleanup() { rm -rf "$STAGE_DIR"; }
trap cleanup EXIT

mkdir -p "$STAGE_DIR/build/native" "$STAGE_DIR/build/assets"
cp -f "$ICU4C_DIR/LICENSE" "$STAGE_DIR/"
cp -f "$ASSETS_DIR/build/Icu4c.Android.Fw.Lib.props" "$STAGE_DIR/build/"
cp -f "$ASSETS_DIR/build/Icu4c.Android.Fw.Lib.targets" "$STAGE_DIR/build/"

dat_files=("$INPUT_DIR"/icudt*l.dat)
[[ -f "${dat_files[0]}" ]] || die "Missing icudt*l.dat under $INPUT_DIR"
cp -f "${dat_files[@]}" "$STAGE_DIR/build/assets/"

dat_base="$(basename "${dat_files[0]}")"
[[ "$dat_base" =~ ^icudt([0-9]+)l\.dat$ ]] || die "Unexpected data file name: $dat_base"
ICU_MAJOR="${BASH_REMATCH[1]}"
sed -i.bak "s/<IcuFwAndroidMajorVersion Condition=\"'\$(IcuFwAndroidMajorVersion)' == ''\">[0-9][0-9]*<\/IcuFwAndroidMajorVersion>/<IcuFwAndroidMajorVersion Condition=\"'\$(IcuFwAndroidMajorVersion)' == ''\">${ICU_MAJOR}<\/IcuFwAndroidMajorVersion>/" \
    "$STAGE_DIR/build/Icu4c.Android.Fw.Lib.props"
rm -f "$STAGE_DIR/build/Icu4c.Android.Fw.Lib.props.bak"
grep -q ">${ICU_MAJOR}</IcuFwAndroidMajorVersion>" "$STAGE_DIR/build/Icu4c.Android.Fw.Lib.props" \
    || die "Failed to stamp IcuFwAndroidMajorVersion=${ICU_MAJOR} into props"

IFS=',' read -ra ABI_LIST <<< "$ABIS"
for abi in "${ABI_LIST[@]}"; do
    abi="$(echo "$abi" | xargs)"
    [[ -z "$abi" ]] && continue
    src="$INPUT_DIR/$abi"
    [[ -d "$src" ]] || die "Missing ABI directory: $src"
    dest="$STAGE_DIR/build/native/$abi"
    mkdir -p "$dest"
    for library in libc++_shared.so libicuuc.so libicui18n.so libicudata.so; do
        [[ -f "$src/$library" ]] || die "Missing $src/$library"
        cp -f "$src/$library" "$dest/"
    done
done

# SDK-style pack project so Linux CI can pack without mono/nuget.exe.
# Metadata intentionally mirrors icu-android-fw-lib.nuspec (reference copy).
# PackagePath must include %(RecursiveDir) or native/<abi>/ and assets/ flatten
# into build/ and the consumer Exists() checks silently fail.
cat > "$STAGE_DIR/Icu4c.Android.Fw.Lib.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <NoBuild>true</NoBuild>
    <IncludeBuildOutput>false</IncludeBuildOutput>
    <SuppressDependenciesWhenPacking>true</SuppressDependenciesWhenPacking>
    <PackageId>Icu4c.Android.Fw.Lib</PackageId>
    <Version>$PKG_VERSION</Version>
    <Title>ICU - International Components for Unicode (Android)</Title>
    <Authors>SIL International</Authors>
    <Copyright>Copyright (c) 2016-2026 SIL International</Copyright>
    <PackageProjectUrl>https://github.com/sillsdev/icu</PackageProjectUrl>
    <PackageLicenseFile>LICENSE</PackageLicenseFile>
    <PackageTags>native;android;maui</PackageTags>
    <Description>FieldWorks ICU4C shared libraries for Android (x86_64, arm64-v8a) for MAUI / .NET Android apps. The major version number corresponds to the ICU release.</Description>
    <PackageReleaseNotes>$PKG_VERSION - FieldWorks ICU $ICU_MAJOR Android natives (x86_64, arm64-v8a) plus icudt${ICU_MAJOR}l.dat</PackageReleaseNotes>
    <GeneratePackageOnBuild>false</GeneratePackageOnBuild>
  </PropertyGroup>
  <ItemGroup>
    <None Include="LICENSE" Pack="true" PackagePath="" />
    <None Include="build/**/*" Pack="true" PackagePath="build/%(RecursiveDir)" />
  </ItemGroup>
</Project>
EOF

mkdir -p "$OUTPUT_DIR"
log "Packing Icu4c.Android.Fw.Lib $PKG_VERSION from $INPUT_DIR"
dotnet pack "$STAGE_DIR/Icu4c.Android.Fw.Lib.csproj" \
    -o "$OUTPUT_DIR" \
    --nologo

nupkg="$OUTPUT_DIR/Icu4c.Android.Fw.Lib.$PKG_VERSION.nupkg"
[[ -f "$nupkg" ]] || die "Expected package not found: $nupkg"

verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/icu-android-nuget-verify.XXXXXX")"
unzip -q "$nupkg" -d "$verify_dir"
[[ -f "$verify_dir/build/Icu4c.Android.Fw.Lib.props" ]] || die "nupkg missing build props"
[[ -f "$verify_dir/build/Icu4c.Android.Fw.Lib.targets" ]] || die "nupkg missing build targets"
[[ -f "$verify_dir/build/assets/icudt${ICU_MAJOR}l.dat" ]] || die "nupkg missing build/assets/icudt${ICU_MAJOR}l.dat"
for abi in "${ABI_LIST[@]}"; do
    abi="$(echo "$abi" | xargs)"
    [[ -z "$abi" ]] && continue
    for library in libc++_shared.so libicuuc.so libicui18n.so libicudata.so; do
        [[ -f "$verify_dir/build/native/$abi/$library" ]] \
            || die "nupkg missing build/native/$abi/$library"
    done
done
rm -rf "$verify_dir"

log "Created $nupkg"
