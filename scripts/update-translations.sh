#!/bin/bash
# =============================================================
# update-translations.sh
# Automate extraction and synchronization of translation strings
# for nhopkg project.
#
# Usage: ./scripts/update-translations.sh [--new-lang LANG]
#   --new-lang LANG    Create a new .po file for the given language code
#
# Flow:
# 1. Extract all translatable strings from source files → nhopkg.pot
# 2. Merge existing .po files with the updated template
# 3. Optionally create a new .po file for a new language
#
# Requires: xgettext, msgmerge, msginit
# =============================================================

set -e

# Determine project root directory
# MESON_SOURCE_ROOT is set when running via Meson target, otherwise fallback to relative path
if [[ -n "$MESON_SOURCE_ROOT" ]]; then
    PROJECT_DIR="$MESON_SOURCE_ROOT"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

POT_DIR="${PROJECT_DIR}/po"
POT_FILE="${POT_DIR}/nhopkg.pot"

# Source files to extract strings from
SOURCES=(
    "${PROJECT_DIR}/src/libnhopkg.in"
    "${PROJECT_DIR}/src/libnhopkg_download.in"
    "${PROJECT_DIR}/src/libnhopkg_udepsys.in"
    "${PROJECT_DIR}/src/nhoget.in"
    "${PROJECT_DIR}/src/nhopkg.in"
    "${PROJECT_DIR}/src/nhopkg-overlay.in"
    "${PROJECT_DIR}/src/nhopkg-repos.in"
    "${PROJECT_DIR}/src/nhopkg-src.in"
    "${PROJECT_DIR}/src/nhouser.in"
    "${PROJECT_DIR}/src/nhopicker.in"
)

# Check required tools
for tool in xgettext msgmerge msginit; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: '$tool' is required but not installed."
        exit 1
    fi
done

# --- Create new language ---
if [[ "${1}" == "--new-lang" ]]; then
    LANG_CODE="${2}"
    if [[ -z "$LANG_CODE" ]]; then
        echo "ERROR: Language code required. Usage: $0 --new-lang XX"
        exit 1
    fi

    if [[ -f "${POT_DIR}/${LANG_CODE}.po" ]]; then
        echo "WARNING: ${LANG_CODE}.po already exists. Updating instead."
        msgmerge --update "${POT_DIR}/${LANG_CODE}.po" "${POT_FILE}"
        echo "Updated: ${POT_DIR}/${LANG_CODE}.po"
        exit 0
    fi

    echo "Creating new translation: ${LANG_CODE}.po"
    msginit -i "${POT_FILE}" -o "${POT_DIR}/${LANG_CODE}.po" -l "${LANG_CODE}" --no-translator
    echo "Created: ${POT_DIR}/${LANG_CODE}.po"
    echo "Remember to add '${LANG_CODE}' to the languages list in po/meson.build"
    exit 0
fi

# --- Step 1: Extract strings to .pot ---
echo "=== Extracting translatable strings ==="

xgettext \
    --keyword=echog \
    --keyword=echogn \
    --from-code=UTF-8 \
    --language=Shell \
    --output="${POT_FILE}" \
    "${SOURCES[@]}"

STRING_COUNT=$(grep -c "^msgid" "${POT_FILE}")
echo "  POT template updated: ${POT_FILE} (${STRING_COUNT} strings)"

# --- Step 2: Update existing .po files ---
echo "=== Updating existing translations ==="

UPDATED=0
FUZZY_COUNT=0

for po_file in "${POT_DIR}"/*.po; do
    [[ -f "$po_file" ]] || continue

    lang=$(basename "$po_file" .po)
    echo "  - ${lang}..."

    msgmerge --quiet --update "$po_file" "${POT_FILE}"

    # Count fuzzy entries
    fuzzy=$(grep -c '^#, fuzzy' "$po_file" 2>/dev/null | tr -d '[:space:]' || echo "0")
    if [[ "$fuzzy" -gt 0 ]]; then
        echo "    ⚠ ${fuzzy} fuzzy entries need review"
        FUZZY_COUNT=$((FUZZY_COUNT + fuzzy))
    fi

    UPDATED=$((UPDATED + 1))
done

echo ""
echo "=== Summary ==="
echo "  POT file: ${POT_FILE} (${STRING_COUNT} strings)"
echo "  Updated: ${UPDATED} translation files"
echo "  Total fuzzy entries: ${FUZZY_COUNT}"
echo ""

if [[ "$FUZZY_COUNT" -gt 0 ]]; then
    echo "  Review fuzzy entries with:"
    echo "    grep -n '^#, fuzzy' po/*.po"
fi

echo ""
echo "=== Next steps ==="
echo "  1. Translate any new empty msgstr entries in po/*.po"
echo "  2. Review and fix fuzzy entries"
echo "  3. Run 'ninja -C builddir' to rebuild .mo files"
echo ""
echo "  To add a new language:"
echo "    $0 --new-lang XX"
