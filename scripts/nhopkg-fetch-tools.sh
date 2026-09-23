#!/bin/sh
set -e
# nhopkg-fetch-tools.sh: descarga, verifica y extrae un binario estático
# precompilado (busybox/zstd) de un release de NeonatoX tools.
#
# Uso:
#   nhopkg-fetch-tools.sh <URL> <INTERNAL_NAME> <OUT_BIN> <SHA256>
#     URL           - URL completa del asset .zip (tools-0.9.1)
#     INTERNAL_NAME - nombre del binario dentro del zip (busybox|zstd)
#     OUT_BIN       - ruta absoluta donde se escribe el binario verificado
#     SHA256        - sha256 del archivo .zip descargado (ancla de integridad, pin del release)

URL="${1:?Usage: nhopkg-fetch-tools.sh <URL> <NAME> <OUT_BIN> <SHA256>}"
NAME="${2:?missing internal binary name}"
OUT_BIN="${3:?missing output binary path}"
EXPECTED_SHA="${4:?missing pinned sha256}"

case "$OUT_BIN" in
    /*) ;;
    *) OUT_BIN="${PWD}/${OUT_BIN}" ;;
esac

WORK_DIR="$(dirname "$OUT_BIN")"
mkdir -p "$WORK_DIR"
ZIP="${WORK_DIR}/.$(basename "$URL")"
EXTRACT_DIR="${WORK_DIR}/.fetch-$$"
trap 'rm -rf "$EXTRACT_DIR"' EXIT
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# 1) Descargar (wget > curl)
if command -v wget >/dev/null 2>&1; then
    echo "Downloading ${URL} ..."
    wget -q -O "$ZIP" "$URL"
elif command -v curl >/dev/null 2>&1; then
    echo "Downloading ${URL} ..."
    curl -sL -o "$ZIP" "$URL"
else
    echo "ERROR: no wget/curl available to download ${URL}" >&2
    exit 1
fi

# 2) Verificar el archivo .zip contra el hash pinneado del release (fallo rápido)
echo "${EXPECTED_SHA}  ${ZIP}" | sha256sum -c - >/dev/null 2>&1 || {
    echo "ERROR: pinned sha256 verification failed for $(basename "$ZIP")" >&2
    exit 1
}

# 3) Extraer el binario (unzip > bsdtar)
if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "$ZIP" "$NAME" -d "$EXTRACT_DIR"
elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$ZIP" -C "$EXTRACT_DIR" "$NAME"
else
    echo "ERROR: no unzip/bsdtar available to extract ${ZIP}" >&2
    exit 1
fi

[ -f "${EXTRACT_DIR}/${NAME}" ] || {
    echo "ERROR: ${NAME} not present in archive" >&2
    exit 1
}

# Control extra: SHA256SUMS embebido en el zip (integridad del binario extraído)
cd "$EXTRACT_DIR"
if [ -f SHA256SUMS ]; then
    sha256sum -c SHA256SUMS >/dev/null 2>&1 || {
        echo "ERROR: embedded SHA256SUMS verification failed for ${NAME}" >&2
        exit 1
    }
fi

# 4) Instalar
install -m755 "${EXTRACT_DIR}/${NAME}" "$OUT_BIN"
rm -f "$ZIP"
echo "OK: ${NAME} fetched and verified -> ${OUT_BIN}"