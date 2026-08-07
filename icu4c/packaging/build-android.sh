#!/usr/bin/env bash
# Copyright (c) 2026 SIL Global
# Cross-compile this checkout's ICU4C sources for Android APK packaging.
# Adapted from https://github.com/patrickgold/icu4c-android (Apache 2.0).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICU4C_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ICU_SRC_DIR="$ICU4C_DIR/source"
OUTPUT_DIR="$ICU4C_DIR/out/android-icu"
HOST_BUILD_DIR="$OUTPUT_DIR/build/host"
ARCHS="${ARCHS:-x86_64}"
API_LEVEL="${API_LEVEL:-21}"

usage() {
    cat <<EOF
Usage: $0 [options]

Build the checked-out ICU4C source for Android. No ICU release is downloaded.

Data packaging uses --with-data-packaging=archive: libicudata.so is the stub
library, and locale data is the separate icudt*l.dat file (for AndroidAsset /
udata_setCommonData). Shared libraries are linked with unversioned SONAMEs so
APK packaging of lib*.so alone works with the Android loader.

Options:
  --arch=LIST       Comma-separated ABIs: x86_64, arm64-v8a (default: x86_64)
  --api=LEVEL       Minimum Android API (default: 21)
  --clean           Remove all generated Android ICU output
  --clean-arch=LIST Remove generated output for the listed ABI(s)
  --help            Show this help

Environment:
  ANDROID_NDK_HOME  Path to an Android NDK installation
  ANDROID_HOME      Android SDK root; its latest ndk/<version> is used
  ARCHS             Default ABI list when --arch is omitted
  API_LEVEL         Default API level when --api is omitted
EOF
}

log() { echo "[build-android] $*"; }
die() { echo "[build-android] ERROR: $*" >&2; exit 1; }

host_platform() {
    case "$(uname -s)" in
        Linux) echo Linux ;;
        Darwin) echo MacOSX ;;
        MINGW*|MSYS*|CYGWIN*) echo MinGW ;;
        *) die "Unsupported host OS: $(uname -s)" ;;
    esac
}

detect_ndk_host_tag() {
    case "$(uname -s)" in
        Linux) echo "linux-$(uname -m)" ;;
        Darwin) echo "darwin-$(uname -m)" ;;
        MINGW*|MSYS*|CYGWIN*) echo windows-x86_64 ;;
        *) die "Unsupported host OS for NDK toolchain: $(uname -s)" ;;
    esac
}

resolve_ndk_toolchain_tag() {
    local ndk="$1" preferred host_os
    preferred="$(detect_ndk_host_tag)"
    if [[ -d "$ndk/toolchains/llvm/prebuilt/$preferred" ]]; then
        echo "$preferred"
        return
    fi
    host_os="$(uname -s)"
    if [[ "$host_os" == Linux && -d "$ndk/toolchains/llvm/prebuilt/windows-x86_64" ]]; then
        die "NDK at $ndk has the Windows toolchain. WSL/Linux requires a Linux NDK installation; set ANDROID_NDK_HOME to it."
    fi
    if [[ "$host_os" =~ ^(MINGW|MSYS|CYGWIN) && -d "$ndk/toolchains/llvm/prebuilt/linux-x86_64" ]]; then
        die "NDK at $ndk has the Linux toolchain. Git Bash requires a Windows NDK installation."
    fi
    die "NDK toolchain not found under $ndk/toolchains/llvm/prebuilt/ (expected $preferred)"
}

resolve_ndk() {
    if [[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]]; then
        echo "$ANDROID_NDK_HOME"
        return
    fi
    if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/ndk" ]]; then
        local latest
        latest="$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)"
        [[ -n "$latest" ]] && echo "$latest" && return
    fi
    die "Android NDK not found. Set ANDROID_NDK_HOME or ANDROID_HOME."
}

arch_to_target() {
    case "$1" in
        x86_64) echo x86_64-linux-android ;;
        arm64-v8a) echo aarch64-linux-android ;;
        *) die "Unsupported ABI '$1'. Supported ABIs: x86_64, arm64-v8a" ;;
    esac
}

icu_major() {
    sed -n 's/^#define U_ICU_VERSION_MAJOR_NUM \([0-9][0-9]*\)$/\1/p' \
        "$ICU_SRC_DIR/common/unicode/uvernum.h" | head -1
}

parallel_jobs() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4
}

copy_ndk_cpp_shared() {
    local ndk="$1" host_tag="$2" target="$3" install_dir="$4"
    local cxx_lib="$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot/usr/lib/$target/libc++_shared.so"
    [[ -f "$cxx_lib" ]] || die "NDK libc++ not found: $cxx_lib"
    cp -f "$cxx_lib" "$install_dir/"
}

# Copy versioned ICU shared objects to the unversioned lib*.so names Android
# packages. SONAMEs are already unversioned (see build_android_arch make override).
install_android_apk_libs() {
    local install_dir="$1" lib src
    for lib in icuuc icui18n icudata; do
        src="$(find "$install_dir" -maxdepth 1 -type f -name "lib${lib}.so.*" -print 2>/dev/null | sort -V | tail -1 || true)"
        [[ -n "$src" ]] || die "Missing lib${lib} in $install_dir"
        cp -f "$src" "$install_dir/lib${lib}.so"
    done
}

build_host_icu() {
    local host_plat
    mkdir -p "$HOST_BUILD_DIR"
    pushd "$HOST_BUILD_DIR" >/dev/null
    if [[ ! -f config/icucross.mk ]]; then
        host_plat="$(host_platform)"
        log "Configuring host ICU tools from $ICU_SRC_DIR"
        "$ICU_SRC_DIR/runConfigureICU" "$host_plat" \
            --enable-static=no --enable-shared=yes --enable-tests=no \
            --enable-samples=no --enable-extras=no --enable-draft=yes \
            --prefix="$HOST_BUILD_DIR/icu_build"
    else
        log "Host ICU already configured; rebuilding incrementally"
    fi
    make -j"$(parallel_jobs)"
    [[ -f config/icucross.mk ]] || die "Host build did not produce config/icucross.mk"
    popd >/dev/null
}

install_icu_data_file() {
    # Declare separately: bash unsets all names in one `local` before assigning.
    local major="$1"
    local dat_name="icudt${major}l.dat"
    local dat_src
    dat_src="$(find "$HOST_BUILD_DIR/data/out" -type f -name "$dat_name" -print -quit 2>/dev/null || true)"
    [[ -n "$dat_src" ]] || die "Missing generated ICU data file $dat_name under $HOST_BUILD_DIR/data/out"
    cp -f "$dat_src" "$OUTPUT_DIR/$dat_name"
}

build_android_arch() {
    local abi="$1" ndk="$2" host_tag="$3"
    local target build_dir install_dir toolchain
    target="$(arch_to_target "$abi")"
    build_dir="$OUTPUT_DIR/build/android/$abi"
    install_dir="$OUTPUT_DIR/$abi"
    toolchain="$ndk/toolchains/llvm/prebuilt/$host_tag"
    mkdir -p "$build_dir" "$install_dir"
    log "Cross-compiling ICU for $abi ($target, API $API_LEVEL)"
    pushd "$build_dir" >/dev/null
    export PATH="$toolchain/bin:$PATH"
    export CC="$toolchain/bin/${target}${API_LEVEL}-clang"
    export CXX="$toolchain/bin/${target}${API_LEVEL}-clang++"
    export AR="$toolchain/bin/llvm-ar"
    export RANLIB="$toolchain/bin/llvm-ranlib"
    export LDFLAGS="-Wl,--gc-sections -Wl,-z,max-page-size=16384"
    if [[ ! -f config.status ]] || ! grep -qE '^PKGDATA_MODE=common$' icudefs.mk 2>/dev/null; then
        # archive packaging => PKGDATA_MODE=common (stub libicudata + .dat)
        rm -f config.status
        "$ICU_SRC_DIR/configure" \
            --with-cross-build="$HOST_BUILD_DIR" --host="$target" \
            --enable-static=no --enable-shared=yes --enable-tests=no \
            --enable-samples=no --enable-extras=no --enable-draft=yes \
            --with-data-packaging=archive
    fi
    # Override mh-linux SONAME (MIDDLE_SO_TARGET / libicu*.so.N) so DT_NEEDED
    # entries match the unversioned lib*.so names Android packages into the APK.
    make -j"$(parallel_jobs)" \
        'LD_SONAME=-Wl,-soname -Wl,$(notdir $(SO_TARGET))'

    rm -f "$install_dir"/libicu*.so*
    # With archive packaging, libicudata is the stub (data lives in icudt*l.dat).
    # Prefer stubdata/ explicitly; also copy other ICU libs from lib/.
    cp -f "$build_dir/lib"/libicuuc.so* "$install_dir/" 2>/dev/null || die "Missing libicuuc in $build_dir/lib"
    cp -f "$build_dir/lib"/libicui18n.so* "$install_dir/" 2>/dev/null || die "Missing libicui18n in $build_dir/lib"
    if [[ -d "$build_dir/stubdata" ]]; then
        cp -f "$build_dir/stubdata"/libicudata.so* "$install_dir/" \
            || die "Missing stub libicudata in $build_dir/stubdata"
    else
        die "Missing stubdata directory in $build_dir"
    fi
    copy_ndk_cpp_shared "$ndk" "$host_tag" "$target" "$install_dir"
    install_android_apk_libs "$install_dir"
    popd >/dev/null
}

CLEAN=no
CLEAN_ARCHS=""
for arg in "$@"; do
    case "$arg" in
        --help|-h) usage; exit 0 ;;
        --clean) CLEAN=yes ;;
        --clean-arch=*) CLEAN_ARCHS="${arg#*=}" ;;
        --arch=*) ARCHS="${arg#*=}" ;;
        --api=*) API_LEVEL="${arg#*=}" ;;
        *) die "Unknown option: $arg" ;;
    esac
done

[[ "$API_LEVEL" =~ ^[0-9]+$ ]] || die "API level must be a positive integer"
[[ -f "$ICU_SRC_DIR/configure" ]] || die "Local ICU source is missing: $ICU_SRC_DIR"
MAJOR="$(icu_major)"
[[ -n "$MAJOR" ]] || die "Could not determine ICU major version from uvernum.h"

if [[ "$CLEAN" == yes ]]; then
    rm -rf "$OUTPUT_DIR"
    log "Cleaned $OUTPUT_DIR"
    exit 0
fi
if [[ -n "$CLEAN_ARCHS" ]]; then
    IFS=',' read -ra CLEAN_ARCH_LIST <<< "$CLEAN_ARCHS"
    for abi in "${CLEAN_ARCH_LIST[@]}"; do
        abi="$(echo "$abi" | xargs)"; [[ -z "$abi" ]] && continue
        arch_to_target "$abi" >/dev/null
        rm -rf "$OUTPUT_DIR/build/android/$abi" "$OUTPUT_DIR/$abi"
        log "Cleaned $abi"
    done
fi

for cmd in make sed find sort; do command -v "$cmd" >/dev/null || die "Required command not found: $cmd"; done
NDK="$(resolve_ndk)"
HOST_TAG="$(resolve_ndk_toolchain_tag "$NDK")"
log "Using local ICU $MAJOR.x sources, NDK $NDK, ABIs $ARCHS"
build_host_icu
install_icu_data_file "$MAJOR"
IFS=',' read -ra ARCH_LIST <<< "$ARCHS"
for abi in "${ARCH_LIST[@]}"; do
    abi="$(echo "$abi" | xargs)"; [[ -z "$abi" ]] && continue
    build_android_arch "$abi" "$NDK" "$HOST_TAG"
done
log "Done. APK-ready libraries are in $OUTPUT_DIR/{abi}/"
