#!/bin/bash
# A package must declare the size of what it installs, not twice that.
#
# The per-part file list can hold the same path more than once, and the loop
# that computes Installed-Size sums a "du" per line without deduplicating, so
# every split package declared twice its real size. On linux-firmware this was
# 3248 KB declared against 1617 KB of files: exactly 2.01x.
#
# The fix deduplicates the temporary copy the loop reads, not the log itself, so
# the packaging step keeps seeing the list it always saw.
#
#   See "What is not covered" in tests/README.md.

set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
[[ -f "${TOOL_SRC}" ]] || die "not found: ${TOOL_SRC} (run meson setup first)"

# ---------------------------------------------------------------------------
# Taking the piece apart
# ---------------------------------------------------------------------------

# The Installed-Size block, from its comment down to the rm of its temp file.
size_block() { # <file>
	awk '
		/^\t# Check if files exists and gets package size\.$/ { grab = 1 }
		grab { print }
		grab && /^\trm -f "\$__np_tmp"$/ { exit }
	' "$1"
}

SIZE_BLOCK="$(size_block "${TOOL_SRC}")"
[[ -n "${SIZE_BLOCK}" ]] || die "the Installed-Size block was not found in ${TOOL_SRC}"

# ---------------------------------------------------------------------------
# Running it
# ---------------------------------------------------------------------------

STAGING="${WORK}/staging"
LOG="${WORK}/.demo-1.0-1-installed.log"

# size_of <path>... -> the real total, the way a single pass would see it
real_size() {
	local total=0 f
	for f in "$@"; do
		[[ -f "${STAGING}/${f}" ]] || continue
		total=$(( total + $(du -- "${STAGING}/${f}" | awk '{print $1}') ))
	done
	printf '%d' "${total}"
}

# The block declares "local __np_tmp", so it has to be evaluated inside a
# function: "local" at the top level of a subshell is an error, and the temp file
# would never be created.
_size_block_run() {
	NHOPKG_TMPDIR="${WORK}"
	PKG_DISPLAY_NAME=demo
	pkgversion=1.0
	pkgrevision=1
	_srch_prefix="${STAGING}/"
	PACKAGE_SIZE=0
	eval "${SIZE_BLOCK}"
}

# run_with <repeats> <path>...
# Writes the given paths to the log once per repetition and runs the block.
# Not in a subshell: PACKAGE_SIZE is the thing under test and a subshell would
# throw the assignment away.
run_with() { # <repeats> <path>...
	local repeats="$1"; shift
	local path
	: > "${LOG}"
	for (( r = 0; r < repeats; r++ )); do
		for path in "$@"; do
			printf '%s\n' "${path}" >> "${LOG}"
		done
	done
	_size_block_run
	printf '%s' "${PACKAGE_SIZE}"
}

# ---------------------------------------------------------------------------
# The staging dir
# ---------------------------------------------------------------------------

mkdir -p "${STAGING}/usr/lib/firmware/demo" "${STAGING}/etc"
head -c 40000 /dev/zero | tr '\0' 'a' > "${STAGING}/usr/lib/firmware/demo/a.bin"
head -c 30000 /dev/zero | tr '\0' 'b' > "${STAGING}/usr/lib/firmware/demo/b.bin"
printf 'c\n' > "${STAGING}/etc/c.conf"

ONE=$(real_size usr/lib/firmware/demo/a.bin usr/lib/firmware/demo/b.bin etc/c.conf)
ok "staging prepared: three files totalling ${ONE} KB on disk"

# ---------------------------------------------------------------------------
# Listed once: the baseline
# ---------------------------------------------------------------------------

GOT=$(run_with 1 usr/lib/firmware/demo/a.bin usr/lib/firmware/demo/b.bin etc/c.conf)
assert_eq "${ONE}" "${GOT}" "listed once, Installed-Size is the real size"

# ---------------------------------------------------------------------------
# Listed twice: the same answer, not double
# ---------------------------------------------------------------------------

GOT=$(run_with 2 usr/lib/firmware/demo/a.bin usr/lib/firmware/demo/b.bin etc/c.conf)
assert_eq "${ONE}" "${GOT}" "listed twice, Installed-Size is still the real size"

# ---------------------------------------------------------------------------
# Many repetitions, as a real part accumulates
# ---------------------------------------------------------------------------

GOT=$(run_with 5 usr/lib/firmware/demo/a.bin usr/lib/firmware/demo/b.bin etc/c.conf)
assert_eq "${ONE}" "${GOT}" "listed five times, Installed-Size is still the real size"

# A single big file repeated, which is what a part with one big blob does.
ONE_A=$(real_size usr/lib/firmware/demo/a.bin)
GOT=$(run_with 4 usr/lib/firmware/demo/a.bin)
assert_eq "${ONE_A}" "${GOT}" "one file listed four times is counted once"

# ---------------------------------------------------------------------------
# The log is left alone
# ---------------------------------------------------------------------------

# The block deduplicates its own temporary copy, on purpose: the packaging step
# reads the log and must keep seeing what it saw before. If this changes, the
# tar file list changes with it.
: > "${LOG}"
for _r in 1 2; do
	printf '%s\n' usr/lib/firmware/demo/a.bin etc/c.conf >> "${LOG}"
done
_size_block_run > /dev/null
assert_eq "4" "$(wc -l < "${LOG}" | tr -d ' ')" "the log keeps its duplicates for the packaging step"

# ---------------------------------------------------------------------------
# A path that is not there is not counted, and is not fatal
# ---------------------------------------------------------------------------

GOT=$(run_with 2 etc/c.conf usr/lib/firmware/demo/vanished.bin)
C_ONLY=$(real_size etc/c.conf)
assert_eq "${C_ONLY}" "${GOT}" "a listed path that no longer exists is skipped"

# ---------------------------------------------------------------------------
# Dedup is in place, and not a pipe
# ---------------------------------------------------------------------------

assert_contains "${SIZE_BLOCK}" 'sort -u -o "$__np_tmp" "$__np_tmp"' \
	"the temp copy is deduplicated in place"

# A pipe would run the loop in a subshell and throw away the assignment, so
# Installed-Size would always come out as 0.
if printf '%s\n' "${SIZE_BLOCK}" | grep -qE 'sort -u[^|]*\|[[:space:]]*(while|read)'; then
	bad "the dedup pipes into the loop: PACKAGE_SIZE would be lost in a subshell"
else
	ok "the dedup does not pipe into the loop (PACKAGE_SIZE would be lost)"
fi

exit "$(t_summary)"
