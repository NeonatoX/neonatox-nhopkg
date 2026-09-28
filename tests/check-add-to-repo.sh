#!/bin/bash
# nhopkg-repos add-to-repo: validation, rejection and index consistency.
#
# Three things are checked:
#
#   1. a batch of valid packages lands, and every id on disk is in the index
#   2. a batch with hostile packages rejects each one with a reason, keeps
#      going, and still exits 1
#   3. the integrity audit catches the defect it exists for, proven by
#      running the pre-fase1 mutant: the "name-*" purge glob that unindexed
#      alpha-devel as soon as alpha was added
#
# Usage: check-add-to-repo.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
setup_tool clean
"${TESTS_DIR}/make-packages.sh" >/dev/null

R="${REPOS}/main"

# ---------------------------------------------------------------------------
head1 "a batch of valid packages is added and indexed"
# ---------------------------------------------------------------------------

out=$(repos_add "${R}" \
	alpha-devel-1.0-n2026.linux-x86_64.nho \
	alpha-1.0-n2026.linux-x86_64.nho \
	beta-2.0-n2026.linux-x86_64.nho \
	gamma-1.0-n2026.linux-x86_64.nho \
	"epsilon 1.0-n2026.linux-x86_64.nho" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/add-valid.log"

assert_status 0 "${rc}" "exit 0"
assert_contains "${out}" "5 added, 0 skipped, 0 failed" "the summary counts every package"
assert_contains "${out}" "Integrity check passed" "the integrity check runs and passes"

on_disk=$(ids_on_disk "${R}/extra")
indexed=$(packages_index "${R}/extra")
for id in alpha-1.0-n2026 alpha-devel-1.0-n2026 beta-2.0-n2026; do
	assert_in_list "${on_disk}" "${id}" "${id} is on disk"
	assert_in_list "${indexed}" "${id}" "${id} is in core.packages"
done
# The metapackage ships no files, so it is in core.packages but by design not
# in core.files.
assert_in_list "${on_disk}" "gamma-1.0-n2026" "the metapackage is on disk"
assert_in_list "${indexed}" "gamma-1.0-n2026" "the metapackage is indexed"
assert_not_in_list "$(files_index "${R}/extra")" "gamma-1.0-n2026" \
	"the metapackage has no file list, as designed"
# Every id on disk is reachable through the index. This is the property the
# whole Fase 1 work was about.
for id in ${on_disk}; do
	assert_in_list "${indexed}" "${id}" "nothing on disk is left unindexed: ${id}"
done

# ---------------------------------------------------------------------------
head1 "a name that is a prefix of another does not eat it"
# ---------------------------------------------------------------------------

# alpha was added after alpha-devel above on purpose. If the purge still used
# a glob, alpha-devel would be on disk and missing from the index.
assert_in_list "$(ids_on_disk "${R}/extra")" "alpha-devel-1.0-n2026" \
	"alpha-devel is still on disk after adding alpha"
assert_in_list "${indexed}" "alpha-devel-1.0-n2026" \
	"alpha-devel is still indexed after adding alpha"

# ---------------------------------------------------------------------------
head1 "hostile packages are rejected with a reason and the batch survives"
# ---------------------------------------------------------------------------

R2="${REPOS}/hostile"
out=$(repos_add "${R2}" "${HOSTILE_PKGDIR}"/*.nho 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/add-hostile.log"

assert_status 1 "${rc}" "exit 1: not every requested package made it in"
assert_contains "${out}" "1 added, 6 skipped, 0 failed" "the valid one still went in"
for pair in \
	"corrupt.nho: unreadable or invalid tar archive" \
	"glob-1.0-n2026.nho: invalid package name" \
	"noversion-1.0-n2026.nho: incomplete nhoid metadata" \
	"slash-1.0-n2026.nho: invalid version/release" \
	"traversal-1.0-n2026.nho: invalid package name" \
	"weirdver-1.0-n2026.nho: invalid version/release"
do
	assert_contains "${out}" "${pair}" "rejected with a reason: ${pair%%:*}"
done
# The whole point of validating the name: nothing may be written outside the
# repository directory, and no stray entries may appear in the index.
assert_no_file "${REPOS}/escape" "the traversal name did not escape the repository"
assert_not_in_list "$(packages_index "${R2}/extra")" ".." "the index holds no path traversal"
assert_in_list "$(packages_index "${R2}/extra")" "goodpkg-1.0-n2026" \
	"the valid package in the hostile batch is indexed"

# ---------------------------------------------------------------------------
head1 "the audit catches the defect it was written for (pre-fase1 mutant)"
# ---------------------------------------------------------------------------

# The mutant restores the "name-*" purge globs. Nothing about the test changes;
# only the tool is older. If the audit did not fire, adding alpha would leave
# alpha-devel unindexed and the test would pass happily.
setup_tool pre-fase1
R3="${REPOS}/mutant"
out=$(repos_add "${R3}" alpha-devel-1.0-n2026.linux-x86_64.nho 2>&1)
out+=$(repos_add "${R3}" alpha-1.0-n2026.linux-x86_64.nho 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/add-mutant.log"

assert_status 1 "${rc}" "exit 1 with the buggy purge"
assert_contains "${out}" "alpha-devel-1.0-n2026 is not in core.packages.tar.zst" \
	"the audit names the package that went missing from the index"
assert_contains "${out}" "Repository integrity check FAILED" \
	"the audit fails the run instead of warning"

exit "$(t_summary)"
