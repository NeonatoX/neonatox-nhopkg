#!/bin/sh
set -e

BB_VERSION="${1:-1.37.0}"
SRC_DIR="${2:-/tmp/nhopkg-bb-build}"
OUT_DIR="${3:-.}"
BB_CONFIG="${4:-busybox.config}"
MUSLGCC="${5:-}"

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

# Resolve config to absolute path before any cd
case "$BB_CONFIG" in
    /*) ;;
    *) BB_CONFIG="${PWD}/${BB_CONFIG}" ;;
esac
case "$OUT_DIR" in
    /*) ;;
    *) OUT_DIR="${PWD}/${OUT_DIR}" ;;
esac

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# Get source: prefer local tarball, fallback to git clone
# NOTE: build dir is named busybox-src to avoid colliding with
# the meson output path (builddir/src/busybox).
ARCHIVE="busybox-${BB_VERSION}.tar.bz2"
if [ -f "$ARCHIVE" ]; then
    echo "Using local tarball: $ARCHIVE"
    if [ ! -d "busybox-${BB_VERSION}" ]; then
        tar xf "$ARCHIVE"
    fi
elif [ ! -d busybox-src ]; then
    echo "Cloning BusyBox..."
    BB_TAG=$(echo "$BB_VERSION" | tr '.' '_')
    git clone --depth 1 --branch "$BB_TAG" \
        https://git.busybox.net/busybox busybox-src
fi

# Use tarball dir or git clone dir
if [ -d "busybox-${BB_VERSION}" ]; then
    cd "busybox-${BB_VERSION}"
else
    cd busybox-src
fi

# Apply config
cp "$BB_CONFIG" .config

# Force static build
sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config || true

# Avoid auto-linking of libatomic: on some toolchains (e.g. GCC 16 + arch
# musl-gcc specs) the driver emits a broken -latomic merge that kills the
# static link; musl post-libc has all atomics built in, so it is unneeded.
sed -i 's/^CONFIG_EXTRA_CFLAGS=.*/CONFIG_EXTRA_CFLAGS="-fno-link-libatomic"/' .config || true

# Resolve any new config options
yes "" | make oldconfig

JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)

echo "Compiling BusyBox ${BB_VERSION} with musl-gcc..."
# CC must go on the make command line: BusyBox's Makefile assigns
# "CC = $(CROSS_COMPILE)gcc", so an exported CC would be ignored and the
# build would link against glibc instead of musl (result aborts on fresh
# boots with rtld_static_init).
make -j"$JOBS" CC="$MUSLGCC"

# Verify static build (use readelf since 'file' may not exist yet)
if ! readelf -d busybox 2>/dev/null | grep -q "NEEDED"; then
    echo "OK: BusyBox is static"
else
    echo "ERROR: BusyBox is not static!" >&2
    exit 1
fi

# Reject glibc-linked results: a musl static BusyBox never carries these
# strings. If the musl toolchain is broken and falls back to glibc, the
# resulting binary can abort (rtld_static_init) on the target system.
if grep -aq 'rtld_static_init\|GNU C Library' busybox; then
    echo "ERROR: built BusyBox is linked against glibc, not musl (musl toolchain not working)." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
install -m755 busybox "$OUT_DIR/busybox"
echo "OK: Static BusyBox installed to $OUT_DIR/busybox"
