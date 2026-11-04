#!/bin/bash
# Build a host-architecture static libopus for the macOS target.
# The visionOS, iOS, and tvOS libraries in libs/opus/lib are left alone.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/libs/opus/lib/macOS"
LIB="$OUT/libopus.a"
VERSION="1.5.2"
URL="https://github.com/xiph/opus/releases/download/v${VERSION}/opus-${VERSION}.tar.gz"

if [ -f "$LIB" ]; then
  echo "libopus for macOS already built at $LIB"
  exit 0
fi

mkdir -p "$OUT"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/opus-macos.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Downloading opus ${VERSION}"
curl -fsSL "$URL" -o "$WORKDIR/opus.tar.gz"
tar -xzf "$WORKDIR/opus.tar.gz" -C "$WORKDIR"
SRC="$(find "$WORKDIR" -maxdepth 1 -type d -name 'opus-*' | head -n 1)"

ARCH="$(uname -m)"
pushd "$SRC" >/dev/null
./configure \
  --disable-shared \
  --enable-static \
  --disable-doc \
  --disable-extra-programs \
  CFLAGS="-O2 -arch ${ARCH} -mmacosx-version-min=14.0"
make -j"$(sysctl -n hw.ncpu)"
cp .libs/libopus.a "$LIB"
popd >/dev/null

echo "Built $LIB"
