#!/bin/bash
# A build of N split parts from a git source must clone once, not N times.
#
# The split loop cloned the repository into ${NHOPKG_TMPDIR}/.gitclone, but
# cleanup_tmp_dir() wipes ${NHOPKG_TMPDIR} at the top of every part. The cache
# branch of nhoget_vcs_git(), "Repository already exists. Updating...", could
# therefore never fire inside that loop: [[ -d "${dest}/.git" ]] was always
# false and every part did a full clone of the whole history.
#
# Nothing about this is visible from the outside. Each part's .nho is correct,
# the build succeeds, and the only symptom is that a 150-part build downloads
# the upstream 150 times. It is the difference between O(1) and O(N) clones,
# and it scales with the size of the history.
#
# Two things are checked here:
#
#   1. The clone destination in the split loop is not under ${NHOPKG_TMPDIR},
#      the loop does not delete the clone it just made, and it copies the nhoid
#      out instead of moving it. Together those are what make the cache branch
#      reachable, so they are asserted on the generated tool.
#   2. nhoget_vcs_git() really does reuse a destination that already holds a
#      clone. Run against a local repository, so no network and no remote.
#
#   See "What is not covered" in tests/README.md.

set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
DLIB_SRC="${BUILDDIR}/src/libnhopkg_download"
LIB_SRC="${BUILDDIR}/src/libnhopkg"
for f in "${TOOL_SRC}" "${DLIB_SRC}" "${LIB_SRC}"; do
	[[ -f "${f}" ]] || die "not found: ${f} (run meson setup first)"
done

# ---------------------------------------------------------------------------
# Taking the pieces apart
# ---------------------------------------------------------------------------

# cleanup_build_dir(), verbatim.
cleanup_build_dir_fn() { # <file>
	awk '
		/^cleanup_build_dir\(\)/ { grab = 1 }
		grab { print }
		grab && /^}$/ { exit }
	' "$1"
}

# nhoget_vcs() and the two dispatch targets it reaches, verbatim.
vcs_git_fn() { # <file>
	awk '
		/^nhoget_vcs\(\)/ { grab = 1 }
		grab { print }
		grab && /^}$/ { fns++; if (fns == 3) exit }
	' "$1"
}

# The git split loop of the client: from its "Preparing split package" banner
# to the "Retrieve data from the main package" line after the clone. Both split
# loops carry that banner, so the one that has a clone in it is the one wanted.
git_split_clone_block() { # <file>
	awk '
		/Preparing split package:/ { grab = 1; buf = ""; next }
		grab {
			buf = buf $0 "\n"
			if (/Retrieve data from the main package/) {
				grab = 0
				if (buf ~ /build_clone_dir/) printf "%s", buf
			}
		}
	' "$1"
}

# ---------------------------------------------------------------------------
# 1. Where the clone lands
# ---------------------------------------------------------------------------

CLONE_BLOCK="$(git_split_clone_block "${TOOL_SRC}")"
assert_eq "1" "$(grep -c 'build_clone_dir=' <<<"${CLONE_BLOCK}")" \
	"the git split loop is found, and not the tarball one"

# The destination has to survive cleanup_tmp_dir(), which only ever removes
# ${NHOPKG_TMPDIR}. Asserted on the variable rather than on a literal path, so
# this does not go stale when the build directory moves.
dest_dir=''
if [[ "${CLONE_BLOCK}" =~ build_clone_dir=\"[^}]*\$\{NHOPKG_(TMPDIR|BUILDIR) ]]; then
	dest_dir="${BASH_REMATCH[1]}"
fi
assert_eq "BUILDIR" "${dest_dir}" "the clone is kept outside \${NHOPKG_TMPDIR}"

# A clone deleted right after being made is no cache, whatever the path.
assert_missing "${CLONE_BLOCK}" 'rm -rf "${build_clone_dir}"' \
	"the split loop does not delete the clone it just made"

# Moving the nhoid out of the clone only worked because the clone was thrown
# away afterwards. Once it is reused, a tracked file the build took out of it
# has to be copied, or the next part reads a half-populated clone.
assert_missing "${CLONE_BLOCK}" 'mv "${build_clone_dir}/nhoid"' \
	"the nhoid is copied out of the clone, not moved"
assert_contains "${CLONE_BLOCK}" 'cp "${build_clone_dir}/nhoid"' \
	"and the copy is there"

# ---------------------------------------------------------------------------
# 2. That the cache branch actually reuses
# ---------------------------------------------------------------------------

VCS_GIT="$(vcs_git_fn "${DLIB_SRC}")"
[[ -n "${VCS_GIT}" ]] || die "nhoget_vcs_git() not found in ${DLIB_SRC}"

# One repository, asked for three times into one destination, the way the split
# loop asks for it. A "git clone" of a local path needs no network.
GIT_SB="$(mktemp -d "${WORK}/git.XXXXXX")"
UPSTREAM="${GIT_SB}/upstream"
DEST="${GIT_SB}/cache"
VCS_LOG="${GIT_SB}/vcs.log"
GIT_LOG="${GIT_SB}/git.log"

if (
	mkdir -p "${UPSTREAM}"
	cd "${UPSTREAM}" || exit 1
	git init -q .
	git config user.email t@t
	git config user.name t
	mkdir -p others patches
	printf '# NHO-0.5\n# Name:\tdemo\n' > nhoid
	printf -- '--- a/diff\n' > patches/fix.patch
	printf 'extra\n' > others/note
	git add -A
	git commit -qm one
); then
	ok "a local repository with an nhoid, patches/ and others/"
else
	bad "could not build the local repository"
	# ---------------------------------------------------------------------------
# 3. That the clone does not outlive the build tree
# ---------------------------------------------------------------------------

# The clone is a cache, not a work product, but it has to survive between parts,
# so it cannot live under ${NHOPKG_TMPDIR} either. That leaves the build tree as
# the only thing with a lifetime attached to it, so the clone is cleaned with
# the tree and with the same answer. Without this it is a full clone of the
# upstream left on disk with nothing able to remove it.
CLEAN_FN="$(cleanup_build_dir_fn "${LIB_SRC}")"
assert_contains "${CLEAN_FN}" '.gitclone-' "cleanup_build_dir knows about the clone"
assert_contains "${CLEAN_FN}" 'dirs+=' "and collects it with the build tree"
assert_missing "${CLEAN_FN}" 'rm -rf "${build_clone_dir}"' \
	"it does not go back to deleting the per-part clone"

# One prompt for both, not one each: the loop that calls this runs once per part
# and a second question would be a new interruption in a build.
assert_eq "1" "$(grep -c 'nhopkg_ask_follow' <<<"${CLEAN_FN}")" \
	"one question covers the build tree and the clone"

# With nothing to remove it must say nothing at all.
(
	echog() { echo "$*" >> "${GIT_SB}/spoken"; }
	nhopkg_ask_follow() { echo "should not appear" >> "${GIT_SB}/spoken"; }
	eval "${CLEAN_FN}"
	NHOPKG_BUILDIR="${GIT_SB}/empty"
	pkgname=demo
	pkgversion=1.0
	cleanup_build_dir
) >/dev/null 2>&1
assert_no_file "${GIT_SB}/spoken" "nothing is asked when there is nothing to remove"

exit "$(t_summary)"
fi

# git is resolved through PATH and shimmed, so the clones are counted where
# they happen. nhoget_vcs_git() prints "Cloning Git repository" on every call,
# including the ones that go on to reuse a clone, so its log line cannot tell a
# clone from a reuse.
REAL_GIT="$(command -v git)"
mkdir -p "${GIT_SB}/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\nexec %s "$@"\n' \
	"${GIT_LOG}" "${REAL_GIT}" > "${GIT_SB}/bin/git"
chmod 0755 "${GIT_SB}/bin/git"

# The split loop's "copy the nhoid out" step is not repeated between calls: it
# is a plain cp into the tmpdir and it does not touch the clone.
(
	PATH="${GIT_SB}/bin:${PATH}"
	nhoget_msg() { printf '%s\n' "$*" >>"${VCS_LOG}"; }
	eval "${VCS_GIT}"
	for _ in 1 2 3; do
		nhoget_vcs git "${UPSTREAM}" "${DEST}"
		cd "${GIT_SB}" || exit 1
	done
	exit 0
) >/dev/null 2>&1

clones="$(grep -c '^clone ' "${GIT_LOG}" 2>/dev/null || echo 0)"
updates="$(grep -c 'Repository already exists' "${VCS_LOG}" 2>/dev/null || echo 0)"

assert_eq "1" "${clones}" "three parts run git clone once"
assert_eq "2" "${updates}" "and the other two take the reuse branch"

# Reuse has to leave the clone usable: a later part still finds the nhoid and
# the extra directories the build copies out of it.
assert_file "${DEST}/nhoid" "the reused clone still holds the nhoid"
assert_file "${DEST}/others/note" "and others/"
assert_file "${DEST}/patches/fix.patch" "and patches/"

# ---------------------------------------------------------------------------
# 3. That the clone does not outlive the build tree
# ---------------------------------------------------------------------------

# The clone is a cache, not a work product, but it has to survive between parts,
# so it cannot live under ${NHOPKG_TMPDIR} either. That leaves the build tree as
# the only thing with a lifetime attached to it, so the clone is cleaned with
# the tree and with the same answer. Without this it is a full clone of the
# upstream left on disk with nothing able to remove it.
CLEAN_FN="$(cleanup_build_dir_fn "${LIB_SRC}")"
assert_contains "${CLEAN_FN}" '.gitclone-' "cleanup_build_dir knows about the clone"
assert_contains "${CLEAN_FN}" 'dirs+=' "and collects it with the build tree"
assert_missing "${CLEAN_FN}" 'rm -rf "${build_clone_dir}"' \
	"it does not go back to deleting the per-part clone"

# One prompt for both, not one each: the loop that calls this runs once per part
# and a second question would be a new interruption in a build.
assert_eq "1" "$(grep -c 'nhopkg_ask_follow' <<<"${CLEAN_FN}")" \
	"one question covers the build tree and the clone"

# With nothing to remove it must say nothing at all.
(
	echog() { echo "$*" >> "${GIT_SB}/spoken"; }
	nhopkg_ask_follow() { echo "should not appear" >> "${GIT_SB}/spoken"; }
	eval "${CLEAN_FN}"
	NHOPKG_BUILDIR="${GIT_SB}/empty"
	pkgname=demo
	pkgversion=1.0
	cleanup_build_dir
) >/dev/null 2>&1
assert_no_file "${GIT_SB}/spoken" "nothing is asked when there is nothing to remove"

exit "$(t_summary)"