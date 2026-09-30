#!/bin/bash

# Builds libopus for visionOS device and Apple silicon visionOS Simulator.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OPUS_VERSION="${OPUS_VERSION:-1.3.1}"
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/moonlight-opus-build}"
ARCHIVE="$WORK_DIR/opus-$OPUS_VERSION.tar.gz"
SRC_DIR="$WORK_DIR/opus-$OPUS_VERSION"
OUT_DEVICE="$REPO_ROOT/libs/opus/lib/visionOS"
OUT_SIM="$REPO_ROOT/libs/opus/lib/visionOS-Sim"
OUT_INCLUDE="$REPO_ROOT/libs/opus/include"
XROS_MIN="${XROS_MIN:-1.0}"

mkdir -p "$WORK_DIR"
if [ ! -f "$ARCHIVE" ]; then
    curl -fL "https://downloads.xiph.org/releases/opus/opus-$OPUS_VERSION.tar.gz" -o "$ARCHIVE"
fi

rm -rf "$SRC_DIR"
tar -xzf "$ARCHIVE" -C "$WORK_DIR"

build_one() {
    local platform="$1"
    local sdk="$2"
    local target="$3"
    local out_dir="$4"
    local build_dir="$WORK_DIR/build-$platform"
    local sdk_path
    local compiler

    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    compiler="$(xcrun --sdk "$sdk" --find clang)"

    rm -rf "$build_dir"
    mkdir -p "$build_dir" "$out_dir"

    (
        cd "$build_dir"
        "$SRC_DIR/configure" \
            --host=arm-apple-darwin \
            --disable-shared \
            --enable-static \
            --with-pic \
            --disable-extra-programs \
            --disable-doc \
            --prefix="$build_dir/install" \
            CC="$compiler" \
            CFLAGS="-target $target -arch arm64 -isysroot $sdk_path -O3 -fPIC" \
            LDFLAGS="-target $target -arch arm64 -isysroot $sdk_path"
    )

    make -C "$build_dir" -j"$(sysctl -n hw.ncpu)"
    make -C "$build_dir" install
    cp "$build_dir/install/lib/libopus.a" "$out_dir/libopus.a"
}

build_one "visionOS" "xros" "arm64-apple-xros$XROS_MIN" "$OUT_DEVICE"
build_one "visionOS-Sim" "xrsimulator" "arm64-apple-xros$XROS_MIN-simulator" "$OUT_SIM"

rm -rf "$OUT_INCLUDE"
mkdir -p "$OUT_INCLUDE"
cp -R "$WORK_DIR/build-visionOS-Sim/install/include/." "$OUT_INCLUDE/"

echo "Built visionOS libopus archives in $OUT_DEVICE and $OUT_SIM"
