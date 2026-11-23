#!/bin/bash
# source-index: Etapa 4 (local index queries and --get-source --from-index).
#
# Drives the real generated `nhopkg-src` against an index produced by the real
# generator and installed under a simulated NHOPKG_LOCALSTATEDIR. No network is
# used: `--show-source` and the plain `--from-index` path must never call git,
# and the cases that do need a clone go through a logging stub.
#
# Usage: check-source-index-client.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
setup_tool clean

FIXTURES="${TESTS_DIR}/fixtures/source-index"
GENERATOR="${SRC_ROOT}/scripts/nhopkg-source-index.sh"
NHO_SRC="${BUILDDIR}/src/nhopkg-src"
LIB="${BUILDDIR}/src/libnhopkg"
GEN_OUT="${WORK}/gen"
GEN_MAIN="${WORK}/gen-main"
STATE="${WORK}/state"
STATE_BAD="${WORK}/state-bad"
STATE_EXTRA="${WORK}/state-extra"
STATE_MAIN="${WORK}/state-main"
CONF="${WORK}/nhopkg.conf"
VCS_LOG="${LOGS}/vcs.log"
export VCS_LOG

# The generated nhopkg-src loads libnhopkg_download from NHOPKG_DOWNLOAD_LIB.
# Replacing just that library lets a clone be observed without touching git.
cat > "${WORK}/vcs-stub" <<'STUB'
nhoget_vcs() {
	printf 'NHOGET_REF=%s %s\n' "${NHOGET_REF:-}" "$*" >> "${VCS_LOG}"
	local dest="$3"
	mkdir -p "${dest}/patches" "${dest}/others"
	printf 'CLONED\n' > "${dest}/nhoid"
	printf 'patch\n' > "${dest}/patches/fix.patch"
	printf 'extra\n' > "${dest}/others/data.txt"
}
STUB

write_config() { # <state dir> <branch>
	local state="$1" branch="$2"
	cp "${BUILDDIR}/src/nhopkg.conf" "${CONF}" || die "cannot copy the config"
	cat >> "${CONF}" <<EOF
NHOPKG_LOCALSTATEDIR="${state}"
NHOPKG_GIT_BRANCH="${branch}"
NHOPKG_DOWNLOAD_LIB="${WORK}/vcs-stub"
NHOPKG_GIT_SOURCES="http://no-network.invalid/sources"
EOF
	export NHOPKG_CONF="${CONF}"
}

run_src() { # <workdir> <args...>
	local dir="$1"
	shift
	( cd "${dir}" && bash "${NHO_SRC}" "$@" 2>&1 )
}

install_index() { # <generator output> <state dir>
	local output="$1" state="$2" stage="$2/.unpack" ref_dir ref
	rm -rf "${stage}"
	mkdir -p "${stage}" "${state}/sources" ||
		die "cannot prepare the state directory $2"
	zstd -dc "${output}/core.sources.tar.zst" | tar xf - -C "${stage}" ||
		die "cannot install the generated index into $2"
	# Same layout sync_sources_repo() publishes: <state>/sources/<ref>/packages/.
	for ref_dir in "${stage}"/*; do
		[[ -d "${ref_dir}" ]] || continue
		ref="$(basename "${ref_dir}")"
		mkdir -p "${state}/sources/${ref}/packages" ||
			die "cannot create the packages directory for ${ref}"
		cp -a "${ref_dir}/." "${state}/sources/${ref}/packages/" ||
			die "cannot copy the packages of ${ref}"
	done
	cp "${output}/lastsync" "${state}/sources/lastsync" || die "cannot publish lastsync"
	rm -rf "${stage}"
}

# ---------------------------------------------------------------------------
head1 "Etapa 4: branch mapping and its call sites"
# ---------------------------------------------------------------------------

cat > "${WORK}/map.sh" <<'EOF'
. "$1"
printf 'empty=%s\n' "$(nhopkg_map_git_ref '')"
printf 'glibc=%s\n' "$(nhopkg_map_git_ref glibc)"
printf 'musl=%s\n' "$(nhopkg_map_git_ref musl)"
printf 'other=%s\n' "$(nhopkg_map_git_ref v1.2)"
printf 'clone_empty=[%s]\n' "$(nhopkg_git_clone_ref '')"
printf 'clone_glibc=%s\n' "$(nhopkg_git_clone_ref glibc)"
printf 'clone_musl=%s\n' "$(nhopkg_git_clone_ref musl)"
EOF
out=$(bash "${WORK}/map.sh" "${LIB}")
rc=$?
assert_status 0 "${rc}" "the generated library exposes nhopkg_map_git_ref"
assert_eq "empty=main" "$(echo "${out}" | grep '^empty=')" "empty branch resolves to main"
assert_eq "glibc=main" "$(echo "${out}" | grep '^glibc=')" "literal glibc resolves to main"
assert_eq "musl=musl" "$(echo "${out}" | grep '^musl=')" "musl stays musl"
assert_eq "other=v1.2" "$(echo "${out}" | grep '^other=')" "unknown refs pass through"
assert_eq "clone_empty=[]" "$(echo "${out}" | grep '^clone_empty=')" \
	"an empty branch leaves the clone ref to git's default"
assert_eq "clone_glibc=main" "$(echo "${out}" | grep '^clone_glibc=')" \
	"the clone helper maps an explicit glibc alias to main"
assert_eq "clone_musl=musl" "$(echo "${out}" | grep '^clone_musl=')" \
	"the clone helper passes explicit refs through"

assert_contains "$(cat "${BUILDDIR}/src/nhopkg-src")" \
	'nhopkg_git_clone_ref "${ref:-${NHOPKG_GIT_BRANCH:-}}"' \
	"nhopkg-src --get-source leaves an empty branch to git"

# ---------------------------------------------------------------------------
head1 "Etapa 4: build the local index from the real generator"
# ---------------------------------------------------------------------------

out=$(SOURCE_INDEX_TIMESTAMP=200 "${GENERATOR}" \
	--fixture "${FIXTURES}" --output "${GEN_OUT}" \
	--nhopkg-src "${NHO_SRC}" --no-sign 2>&1)
rc=$?
assert_status 0 "${rc}" "the real generator published the fixture index"
install_index "${GEN_OUT}" "${STATE}"
assert_file "${STATE}/sources/main/packages/kinfocenter" "the glibc recipe is installed"
assert_file "${STATE}/sources/musl/packages/kinfocenter" "the musl recipe is installed"

out=$(SOURCE_INDEX_TIMESTAMP=200 "${GENERATOR}" \
	--fixture "${FIXTURES}" --output "${GEN_MAIN}" --refs main \
	--nhopkg-src "${NHO_SRC}" --no-sign 2>&1)
rc=$?
assert_status 0 "${rc}" "a main-only index can be generated"
install_index "${GEN_MAIN}" "${STATE_MAIN}"
assert_file "${STATE_MAIN}/sources/main/packages/kinfocenter" "main-only: recipe installed"
assert_no_file "${STATE_MAIN}/sources/musl/packages/kinfocenter" "main-only: no musl recipe"

# ---------------------------------------------------------------------------
head1 "Etapa 4: --list-sources and --search-sources need no network"
# ---------------------------------------------------------------------------

write_config "${STATE}" ""
out=$(run_src "${WORK}" --list-sources)
rc=$?
assert_status 0 "${rc}" "--list-sources exits 0"
assert_eq "kinfocenter" "${out}" "--list-sources lists exactly the valid fixture"
assert_missing "${out}" "broken" "--list-sources hides the invalid fixture"
assert_no_file "${VCS_LOG}" "listing did not call git"

out=$(run_src "${WORK}" --search-sources plasma)
rc=$?
assert_status 0 "${rc}" "--search-sources finds a group"
assert_contains "${out}" "kinfocenter" "group 'plasma' resolves to kinfocenter"

out=$(run_src "${WORK}" --search-sources qt6-base)
rc=$?
assert_status 0 "${rc}" "--search-sources finds a dependency"
assert_contains "${out}" "kinfocenter" "BuildDep qt6-base resolves to kinfocenter"

out=$(run_src "${WORK}" --search-sources "information about")
rc=$?
assert_status 0 "${rc}" "--search-sources finds a description"
assert_contains "${out}" "kinfocenter" "description text resolves to kinfocenter"

out=$(run_src "${WORK}" --search-sources no-such-recipe-xyz)
rc=$?
assert_status 1 "${rc}" "--search-sources fails when nothing matches"
assert_eq "" "${out}" "no output for an unmatched pattern"

out=$(run_src "${WORK}" --list-sources --from-index)
rc=$?
assert_status 1 "${rc}" "--from-index is rejected for commands other than --get-source"

# ---------------------------------------------------------------------------
head1 "Etapa 4: --show-source reads metadata and verifies the hash"
# ---------------------------------------------------------------------------

out=$(run_src "${WORK}" --show-source kinfocenter)
rc=$?
assert_status 0 "${rc}" "--show-source exits 0"
assert_contains "${out}" "Source: main/kinfocenter" "the resolved ref is shown"
assert_contains "${out}" "Source-Project: kinfocenter" "the sidecar is shown"
assert_contains "${out}" "Source-Ref: main" "provenance is shown"
assert_contains "${out}" $'# Name:\tkinfocenter' "the cached nhoid is shown"
assert_no_file "${VCS_LOG}" "--show-source did not call git"

out=$(run_src "${WORK}" --show-source no-such-recipe-xyz)
rc=$?
assert_status 1 "${rc}" "--show-source fails for an unknown recipe"
assert_contains "${out}" "Run 'nhopkg -U' first" "the error suggests syncing the index"

cp -a "${STATE}" "${STATE_BAD}"
printf '\n' >> "${STATE_BAD}/sources/main/packages/kinfocenter"
write_config "${STATE_BAD}" ""
out=$(run_src "${WORK}" --show-source kinfocenter)
rc=$?
assert_status 1 "${rc}" "a corrupt cached nhoid is refused"
assert_contains "${out}" "SHA256" "the hash mismatch is reported"
write_config "${STATE}" ""

# ---------------------------------------------------------------------------
head1 "Etapa 4: --get-source --from-index"
# ---------------------------------------------------------------------------

GET1="${WORK}/get-index"
mkdir -p "${GET1}"
out=$(run_src "${GET1}" --get-source kinfocenter --from-index)
rc=$?
assert_status 0 "${rc}" "--get-source --from-index exits 0"
cmp -s "${FIXTURES}/kinfocenter/main/nhoid" "${GET1}/kinfocenter/nhoid" &&
	ok "the deployed nhoid is byte-identical to the fixture" ||
	bad "the deployed nhoid is byte-identical to the fixture"
assert_no_file "${VCS_LOG}" "a recipe without extras did not call git"

GET2="${WORK}/get-missing"
mkdir -p "${GET2}"
out=$(run_src "${GET2}" --get-source no-such-recipe-xyz --from-index)
rc=$?
assert_status 1 "${rc}" "--from-index fails for an unknown recipe"
assert_contains "${out}" "or drop --from-index" "the error offers the online alternative"

# A recipe with extras still clones, but with the mapped ref and the index
# recipe overwriting whatever the repository happens to carry.
cp -a "${STATE}" "${STATE_EXTRA}"
for ref in main musl; do
	sed -i 's|^Source-Extra-Files: none$|Source-Extra-Files: patches/fix.patch others/data.txt|' \
		"${STATE_EXTRA}/sources/${ref}/packages/kinfocenter.sourceinfo"
done

GET3="${WORK}/get-extras"
mkdir -p "${GET3}"
: > "${VCS_LOG}"
write_config "${STATE_EXTRA}" "musl"
out=$(run_src "${GET3}" --get-source kinfocenter --from-index)
rc=$?
assert_status 0 "${rc}" "a recipe with extras is materialised"
assert_contains "$(cat "${VCS_LOG}")" "NHOGET_REF=musl" "explicit musl is passed to the clone"
assert_contains "$(cat "${VCS_LOG}")" "git " "the clone backend ran"
assert_file "${GET3}/kinfocenter/patches/fix.patch" "the patch was copied"
assert_file "${GET3}/kinfocenter/others/data.txt" "the extra file was copied"
cmp -s "${FIXTURES}/kinfocenter/musl/nhoid" "${GET3}/kinfocenter/nhoid" &&
	ok "the index recipe replaced the cloned nhoid" ||
	bad "the index recipe replaced the cloned nhoid"

GET4="${WORK}/get-glibc"
mkdir -p "${GET4}"
: > "${VCS_LOG}"
write_config "${STATE_EXTRA}" "glibc"
out=$(run_src "${GET4}" --get-source kinfocenter --from-index)
rc=$?
assert_status 0 "${rc}" "glibc still works with extras"
assert_contains "$(cat "${VCS_LOG}")" "NHOGET_REF=main" "literal glibc maps to main for the clone"

GET5="${WORK}/get-online"
mkdir -p "${GET5}"
: > "${VCS_LOG}"
write_config "${STATE_EXTRA}" ""
out=$(run_src "${GET5}" --get-source kinfocenter)
rc=$?
assert_status 0 "${rc}" "plain --get-source still works"
assert_contains "$(cat "${VCS_LOG}")" "NHOGET_REF= git" \
	"an empty branch leaves the clone ref to git's own default"
assert_missing "$(cat "${VCS_LOG}")" "NHOGET_REF=main" \
	"an empty branch does not force main on non-indexed projects"

# ---------------------------------------------------------------------------
head1 "Etapa 4: the ref comes from --ref or from the configured branch"
# ---------------------------------------------------------------------------

write_config "${STATE_MAIN}" "musl"
out=$(run_src "${WORK}" --list-sources)
rc=$?
assert_status 1 "${rc}" "a musl config does not see the main-only index"
assert_contains "${out}" "No local source index" "the missing ref is explained"

out=$(run_src "${WORK}" --show-source kinfocenter --ref musl)
rc=$?
assert_status 1 "${rc}" "--ref musl does not fall back to main"

write_config "${STATE_MAIN}" "glibc"
out=$(run_src "${WORK}" --list-sources)
rc=$?
assert_status 0 "${rc}" "glibc config sees the main index"
assert_contains "${out}" "kinfocenter" "the recipes of main are listed"

write_config "${STATE}" "musl"
out=$(run_src "${WORK}" --show-source kinfocenter --ref main)
rc=$?
assert_status 0 "${rc}" "an explicit --ref overrides the configured branch"
assert_contains "${out}" "Source: main/kinfocenter" "the explicit ref wins"

exit "$(t_summary)"
