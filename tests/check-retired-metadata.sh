#!/bin/bash
# nhopkg-repos: retiring a version must not leave its entry behind (D7).
#
# The defect: adding a new version of a package deleted the old .nho from
# disk but left its metadata in core.packages.tar.zst and core.files.tar.zst.
# The repository then advertised a version that could not be downloaded, and
# nhopkg resolved it as the "lasted version available" before failing to
# install it. Retiring zeta-1.0-rc1 in favour of zeta-1.0 was enough.
#
# Two halves are checked:
#
#   1. the metadata of a retired version is purged with the package, so the
#      index never points at an archive that is gone
#   2. entries with no archive behind them are reported as stale, as a warning
#      that does not change the exit status
#
# The second half is proven against the pre-fase2a mutant, which reproduces the
# damage in a repository published by an older release.
#
# Usage: check-retired-metadata.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
setup_tool clean
"${TESTS_DIR}/make-packages.sh" >/dev/null

RC1=zeta-1.0-rc1-1-n2026.linux-x86_64.nho
NEW=zeta-1.0-1-n2026.linux-x86_64.nho
RC1ID=zeta-1.0-rc1-1
NEWID=zeta-1.0-1

# Publish the prerelease, then replace it with the release.
publish_then_replace() { # publish_then_replace <repo-dir>
	local repo="$1"
	rm -rf "${repo}"; mkdir -p "${repo}"
	repos_add "${repo}" "${RC1}" >/dev/null 2>&1
	repos_add "${repo}" "${NEW}"
}

# ---------------------------------------------------------------------------
head1 "the metadata of a retired version is purged with it"
# ---------------------------------------------------------------------------

R="${REPOS}/clean"
out=$(publish_then_replace "${R}" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/retire-clean.log"

assert_status 0 "${rc}" "exit 0"
assert_contains "${out}" "1 added" "the replacement was added"
assert_no_file "${R}/extra/${RC1ID}"*.nho "the retired .nho is gone from disk"
assert_file "${R}/extra/${NEWID}"*.nho "the new .nho is on disk"

indexed=$(packages_index "${R}/extra")
files=$(files_index "${R}/extra")
assert_in_list "${indexed}" "${NEWID}" "core.packages indexes the new version"
assert_not_in_list "${indexed}" "${RC1ID}" "core.packages no longer indexes the retired one"
assert_in_list "${files}" "${NEWID}" "core.files lists the new version"
assert_not_in_list "${files}" "${RC1ID}" "core.files no longer lists the retired one"
# The aliases are rebuilt from the version that survived.
aliases=$(index_all_entries "${R}/extra/core.packages.tar.zst")
assert_in_list "${aliases}" "zeta" "the name alias is still published"
assert_in_list "${aliases}" "zeta-1.0" "the name-version alias is still published"
assert_missing "${out}" "is indexed but no .nho" "a coherent repository raises no warning"
assert_contains "${out}" "Integrity check passed" "the integrity check passes"

# ---------------------------------------------------------------------------
head1 "an entry with no archive behind it is reported, not failed"
# ---------------------------------------------------------------------------

setup_tool pre-fase2a
R2="${REPOS}/damaged"
out=$(publish_then_replace "${R2}" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/retire-damaged.log"

assert_status 0 "${rc}" "exit 0: the damage is a warning, not a failure"
assert_in_list "$(packages_index "${R2}/extra")" "${RC1ID}" \
	"the phantom is really there, as an older release would leave it"
assert_contains "${out}" "is indexed but no .nho" "the stale entry is reported"
assert_contains "${out}" "${RC1ID}" "the report names the exact id"
assert_contains "${out}" "core.packages" "the report says which index it is in"
assert_contains "${out}" "stale index entr" "the summary counts the stale entries"
# The direction that has always been an error still is one: a package on disk
# that nothing in the index reaches.
assert_contains "${out}" "Integrity check passed" \
	"the disk to index direction still passes: only the orphans are a warning"

# ---------------------------------------------------------------------------
head1 "2a does not repair a repository that is already damaged"
# ---------------------------------------------------------------------------

# Worth stating out loud, because it is the obvious next question. Purging is
# coupled to retiring, and the retired .nho is long gone, so there is nothing
# left to trigger it. Repairs are a deliberate, destructive operation
# (--prune-orphans), not a side effect of the next add.
setup_tool clean
out=$(repos_add "${R2}" "${NEW}" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/retire-damage-persists.log"

assert_status 0 "${rc}" "exit 0"
assert_in_list "$(packages_index "${R2}/extra")" "${RC1ID}" \
	"the pre-existing stale entry is still there"
assert_contains "${out}" "is indexed but no .nho" \
	"the audit keeps pointing at it, which is its whole job"

exit "$(t_summary)"
