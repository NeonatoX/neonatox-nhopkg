#!/bin/sh
set -e

ZSTD_VERSION="${1:-1.5.7}"
SRC_DIR="${2:-/tmp/nhopkg-zstd-build}"
OUT_DIR="${3:-.}"
MUSLGCC="${4:-}"

# MUSLGCC lo pasa Meson (detección temprana); fallback solo para uso manual.
if [ -z "$MUSLGCC" ]; then
    for cc in musl-gcc x86_64-linux-musl-gcc aarch64-linux-musl-gcc; do
        MUSLGCC=$(command -v "$cc" 2>/dev/null || true)
        [ -n "$MUSLGCC" ] && break
    done
fi

if [ -z "$MUSLGCC" ]; then
    echo "ERROR: musl compiler not found." >&2
    exit 1
fi

# Resolve output dir to absolute path before any cd
case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="${PWD}/${OUT_DIR}" ;;
esac

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

ARCHIVE="zstd-${ZSTD_VERSION}.tar.gz"
URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ARCHIVE}"

# Get source: prefer local tarball, fallback to download
if [ ! -d "zstd-${ZSTD_VERSION}" ]; then
    if [ -f "$ARCHIVE" ]; then
        echo "Using local tarball: $ARCHIVE"
    elif command -v wget &>/dev/null; then
        echo "Downloading zstd ${ZSTD_VERSION}..."
        wget -q "$URL"
    elif command -v curl &>/dev/null; then
        echo "Downloading zstd ${ZSTD_VERSION}..."
        curl -sL -o "$ARCHIVE" "$URL"
    else
        echo "ERROR: No local tarball and wget/curl not available." >&2
        exit 1
    fi
    tar xf "$ARCHIVE"
fi

cd "zstd-${ZSTD_VERSION}"

[ -f programs/Makefile ] && make -C programs clean || true

JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)

echo "Compiling zstd ${ZSTD_VERSION} with musl-gcc..."
# CC va en la línea de comandos para que el Makefile no la ignore con una
# asignación propia (igual que en nhopkg-build-busybox.sh).
CFLAGS="-DZSTD_NO_TERMINAL_GUARD -Os -s -fno-link-libatomic" \
make -j"$JOBS" -C programs zstd CC="$MUSLGCC" ZSTD_LIBS="-static" LDFLAGS="-static"

# Verify static build
if ! readelf -d programs/zstd 2>/dev/null | grep -q "NEEDED"; then
    echo "OK: zstd is static"
else
    echo "ERROR: zstd is not static!" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
install -m755 programs/zstd "$OUT_DIR/zstd"
echo "OK: Static zstd installed to $OUT_DIR/zstd"
