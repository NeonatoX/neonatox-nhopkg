#!/bin/bash
# A split build must not decompress the same tarball once per part.
#
# The split loop calls build_prepare() once per part, and build_prepare() calls
# fetch_tarball_source(), which downloads (from a cache), copies and
# decompresses the tarball into the compilation directory. Measured over a
# 150-part build that is 20s against a 0.13s unpack -- the most expensive step
# in the whole build, and it was being repeated N times for the same input.
#
# When the compilation directory survives between parts, that work is
# redundant. It does not always survive: cleanup_build_dir() runs at the end of
# every part and asks first, and under -R it answers for itself and deletes.
# So this is not "unpack once per build", it is "unpack once per tree", which
# is never worse than before and is a win only when the tree is kept.
#
# Two things this deliberately does NOT do:
#
#   - It does not treat an empty directory as a tree. build_prepare() creates
#     the directory before it knows whether the unpack will succeed, so on its
#     own it proves nothing, and skipping on it would turn a failed download
#     into a silent build against an empty tree.
#   - It does not apply to the VCS path. fetch_vcs_source() is left alone: its
#     update branch runs "git clean -fd" on the tree, so skipping it would also
#     stop each part from getting a clean tree, which is a different change and
#     not one to smuggle in here.
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

fetch_tarball_fn() { # <file>
	awk '
		/^fetch_tarball_source\(\)/ { grab = 1 }
		grab { print }
		grab && /^}$/ { exit }
	' "$1"
}

FETCH_FN="$(fetch_tarball_fn "${TOOL_SRC}")"
[[ -n "${FETCH_FN}" ]] || die "fetch_tarball_source() not found in ${TOOL_SRC}"

# ---------------------------------------------------------------------------
# Running it
# ---------------------------------------------------------------------------

# fetch_tarball_fn <tree state> <download result>
#
# Tree state is one of: absent, empty, filled. download_with_hash_check is
# stubbed to record that it was reached and then fail, so a run that skips the
# download is distinguishable from one that attempts it: the URL is not even
# resolvable, so nothing here needs the network.
#
# FETCH_RC and FETCH_TALKED are set by the subshell.
FETCH_TALKED=''
FETCH_RC=0
fetch_run() { # <tree state>
	local state="$1" sb
	sb="$(mktemp -d "${WORK}/fetch.XXXXXX")"
	mkdir -p "${sb}/tmp"
	case "${state}" in
		filled)
			mkdir -p "${sb}/build/demo-1.0"
			printf 'a source file\n' > "${sb}/build/demo-1.0/README"
			;;
		empty)
			mkdir -p "${sb}/build/demo-1.0"
			;;
	esac
	(
		NHOPKG_TMPDIR="${sb}/tmp"
		NHOPKG_BUILDIR="${sb}/build"
		pkgname=demo
		pkgversion=1.0
		echog() { :; }
		set_files_and_patches() { :; }
		download_with_hash_check() { echo talked > "${sb}/talked"; return 1; }
		eval "${FETCH_FN}"
		fetch_tarball_source "https://example.invalid/demo-1.0.tar.zst"
		exit $?
	) >/dev/null 2>&1
	FETCH_RC=$?
	[[ -e "${sb}/talked" ]] && FETCH_TALKED=yes || FETCH_TALKED=''
	return 0
}

# ---------------------------------------------------------------------------
# A tree with the source in it is kept, and nothing is downloaded
# ---------------------------------------------------------------------------

fetch_run filled
assert_eq "0" "${FETCH_RC}" "a tree with the source in it: fetch_tarball_source succeeds"
assert_eq "" "${FETCH_TALKED}" "and the tarball is not downloaded again"

# ---------------------------------------------------------------------------
# A tree that is not there, or is there but empty, is not a tree
# ---------------------------------------------------------------------------

fetch_run absent
assert_eq "1" "${FETCH_RC}" "no tree: it tries to fetch and reports the failure"
assert_eq "yes" "${FETCH_TALKED}" "and the download is actually attempted"

fetch_run empty
assert_eq "1" "${FETCH_RC}" "an empty tree is not a tree: it still tries to fetch"
assert_eq "yes" "${FETCH_TALKED}" "and the download is actually attempted"

# ---------------------------------------------------------------------------
# The VCS path is not caught by this
# ---------------------------------------------------------------------------

# fetch_vcs_source() runs "git clean -fd" on the tree when it updates it, so a
# guard in front of it would change what each part gets. Assert the reuse check
# is not there.
build_prepare_fn() { # <file>
	awk '
		/^build_prepare\(\)/ { grab = 1 }
		grab { print }
		grab && /^}$/ { exit }
	' "$1"
}
PREPARE_FN="$(build_prepare_fn "${TOOL_SRC}")"
assert_contains "${PREPARE_FN}" 'fetch_vcs_source git' "the VCS dispatch is still there"

vcs_pos="$(grep -n 'fetch_vcs_source git' <<<"${PREPARE_FN}" | head -n 1 | cut -d: -f1)"
tar_pos="$(grep -n 'fetch_tarball_source "' <<<"${PREPARE_FN}" | head -n 1 | cut -d: -f1)"
reuse_pos="$(grep -n 'Source already in' <<<"${PREPARE_FN}" | head -n 1 | cut -d: -f1)"

# The one reuse message inside build_prepare() guards the local-tarball loop,
# which comes after the VCS dispatch. If it ever moves above it, a git source
# would stop being refreshed between parts.
if [[ -n "${vcs_pos}" && -n "${tar_pos}" && -n "${reuse_pos}" ]] \
	&& (( vcs_pos < tar_pos && tar_pos < reuse_pos )); then
	ok "the reuse check sits after the VCS dispatch, in the local-tarball loop"
else
	bad "the reuse check is not where it should be (vcs=${vcs_pos} tarball=${tar_pos} reuse=${reuse_pos})"
fi

exit "$(t_summary)"