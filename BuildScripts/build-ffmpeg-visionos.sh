#!/bin/bash
#
# Builds lean FFmpeg static libs for visionOS (xros device + xrsimulator arm64),
# matching the iOS config used by moonlight-mobile-deps.
#
# Result: libavcodec.a, libavformat.a, libavutil.a for
#   libs/FFmpeg/lib/visionOS/       (arm64 device)
#   libs/FFmpeg/lib/visionOS-Sim/   (arm64 simulator)
#
# The important point: this build does NOT enable libswresample, libswscale,
# zlib, or iconv dependencies. This matches the iOS/tvOS archives shipped
# in this repo and eliminates the linker errors seen in Xcode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FFMPEG_VERSION="${FFMPEG_VERSION:-n6.1.1}"
FFMPEG_REPO="${FFMPEG_REPO:-https://git.ffmpeg.org/ffmpeg.git}"

WORK_DIR="$REPO_ROOT/BuildScripts/ffmpeg-build"
SRC_DIR="$WORK_DIR/ffmpeg"
OUT_DEVICE="$REPO_ROOT/libs/FFmpeg/lib/visionOS"
OUT_SIM="$REPO_ROOT/libs/FFmpeg/lib/visionOS-Sim"
OUT_INCLUDE="$REPO_ROOT/libs/FFmpeg/include"

XROS_MIN="${XROS_MIN:-1.0}"
XROS_SDK_PATH="$(xcrun --sdk xros --show-sdk-path)"
XRSIM_SDK_PATH="$(xcrun --sdk xrsimulator --show-sdk-path)"
CC="$(xcrun --sdk xros --find clang)"

if [ ! -d "$SRC_DIR" ]; then
    echo "==> Cloning FFmpeg ($FFMPEG_VERSION)"
    mkdir -p "$WORK_DIR"
    git clone --depth 1 --branch "$FFMPEG_VERSION" "$FFMPEG_REPO" "$SRC_DIR"
fi

# Common lean feature set (matches moonlight-mobile-deps iOS build).
# --disable-all + --disable-autodetect strips out libswresample, libswscale,
# libpostproc, libavdevice, libavfilter, and all decoders/encoders/muxers/demuxers.
# We then re-enable only what moonlight needs.
COMMON_CONFIGURE=(
    --disable-all
    --disable-autodetect
    --disable-x86asm
    --disable-programs
    --disable-doc
    --disable-avdevice
    --disable-swscale
    --disable-swresample
    --disable-postproc
    --disable-avfilter
    --enable-avcodec
    --enable-avformat
    --enable-muxer=flv
    --enable-decoder=av1
    --enable-cross-compile
    --arch=arm64
    --target-os=darwin
    --enable-pic
    --enable-static
    --disable-shared
    --disable-debug
)

build_one() {
    local platform="$1"      # visionOS | visionOS-Sim
    local sdk_path="$2"
    local min_flag="$3"      # e.g. -target arm64-apple-xros1.0
    local build_dir="$WORK_DIR/build-$platform"

    echo "==> Building FFmpeg for $platform"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    local cflags="$min_flag -arch arm64 -isysroot $sdk_path -fembed-bitcode=off"
    local ldflags="$min_flag -arch arm64 -isysroot $sdk_path"

    ( cd "$build_dir" && "$SRC_DIR/configure" \
        --prefix="$build_dir/install" \
        --cc="$CC" \
        --sysroot="$sdk_path" \
        --extra-cflags="$cflags" \
        --extra-ldflags="$ldflags" \
        "${COMMON_CONFIGURE[@]}"
    )

    make -C "$build_dir" -j"$(sysctl -n hw.ncpu)"
    make -C "$build_dir" install

    local out_dir
    if [ "$platform" = "visionOS" ]; then out_dir="$OUT_DEVICE"; else out_dir="$OUT_SIM"; fi
    mkdir -p "$out_dir"
    cp "$build_dir/install/lib/libavcodec.a"  "$out_dir/"
    cp "$build_dir/install/lib/libavformat.a" "$out_dir/"
    cp "$build_dir/install/lib/libavutil.a"   "$out_dir/"

    # Refresh headers (all three arches share the same public headers).
    mkdir -p "$OUT_INCLUDE"
    cp -R "$build_dir/install/include/." "$OUT_INCLUDE/"
}

# visionOS device (arm64)
build_one "visionOS" \
    "$XROS_SDK_PATH" \
    "-target arm64-apple-xros${XROS_MIN}"

# visionOS simulator (arm64, arm64 host)
build_one "visionOS-Sim" \
    "$XRSIM_SDK_PATH" \
    "-target arm64-apple-xros${XROS_MIN}-simulator"

echo "==> Done."
echo "    Device libs:    $OUT_DEVICE"
echo "    Simulator libs: $OUT_SIM"
echo "    Headers:        $OUT_INCLUDE"
