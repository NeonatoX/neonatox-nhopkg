#!/bin/bash
# source-index: Etapa 5 (indexed recipes in `nhopkg -C` and opt-in fallback).
#
# Nothing here needs a network or root. The real generated libraries are used:
# `source_index_get_sources()` is driven with a logging `nhoget_vcs` stub, and
# `dep_resolve_from_nhoid()` is extracted from the generated udepsys library and
# run with stubs so its exit path can be observed without aborting the suite.
#
# Usage: check-source-index-build.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}" "${LOGS}"

LIB="${BUILDDIR}/src/libnhopkg"
UDEP="${BUILDDIR}/src/libnhopkg_udepsys"
TOOL="${BUILDDIR}/src/nhopkg"
CONF="${BUILDDIR}/src/nhopkg.conf"
GENERATOR="${SRC_ROOT}/scripts/nhopkg-source-index.sh"
NHO_SRC="${BUILDDIR}/src/nhopkg-src"
FIXTURES="${TESTS_DIR}/fixtures/source-index"
GEN_OUT="${WORK}/gen"
GEN_MAIN="${WORK}/gen-main"
STATE="${WORK}/state"
STATE_MAIN="${WORK}/state-main"
STATE_EMPTY="${WORK}/state-empty"
STATE_EXTRA="${WORK}/state-extra"
STATE_BAD="${WORK}/state-bad"
VCS_LOG="${LOGS}/vcs.log"
CHAIN_LOG="${LOGS}/chain.log"
export VCS_LOG CHAIN_LOG

for f in "${LIB}" "${UDEP}" "${TOOL}" "${CONF}"; do
	[[ -f "$f" ]] || die "not found: $f (run meson setup first)"
done

install_index() { # <generator output> <state dir>
	local output="$1" state="$2" stage="$2/.unpack" ref_dir ref
	rm -rf "${stage}"
	mkdir -p "${stage}" "${state}/sources" ||
		die "cannot prepare the state directory $2"
	zstd -dc "${output}/core.sources.tar.zst" | tar xf - -C "${stage}" ||
		die "cannot install the generated index into $2"
	for ref_dir in "${stage}"/*; do
		[[ -d "${ref_dir}" ]] || continue
		ref="$(basename "${ref_dir}")"
		mkdir -p "${state}/sources/${ref}/packages" ||
			die "cannot create the packages directory for ${ref}"
		cp -a "${ref_dir}/." "${state}/sources/${ref}/packages/" ||
			die "cannot copy the packages of ${ref}"
	done
	cp "${output}/lastsync" "${state}/sources/lastsync" ||
		die "cannot publish lastsync"
	rm -rf "${stage}"
}

# A small extra index: the fixture only has kinfocenter, and the fallback needs
# two independent dependency names to build an A -> B -> A cycle.
make_entry() { # <name> <ref>
	local name="$1" ref="$2" dir sha
	dir="${STATE}/sources/${ref}/packages"
	[[ -d "${dir}" ]] || mkdir -p "${dir}" || return 1
	printf '# Name: %s\n# Version: 1.0\n' "${name}" > "${dir}/${name}" || return 1
	sha="$(sha256sum "${dir}/${name}" | awk '{print $1}')" || return 1
	cat > "${dir}/${name}.sourceinfo" <<EOF || return 1
Source-Project: ${name}
Source-Ref: ${ref}
Source-Commit: deadbeef
Source-Url: http://no-network.invalid/sources/${name}.git
Source-Extra-Files: none
Source-Nhoid-SHA256: ${sha}
Source-Validated: yes
Source-Indexed: 200
EOF
}

# ---------------------------------------------------------------------------
head1 "Etapa 5: build an index and expose the opt-in flag"
# ---------------------------------------------------------------------------

out=$(SOURCE_INDEX_TIMESTAMP=200 "${GENERATOR}" \
	--fixture "${FIXTURES}" --output "${GEN_OUT}" \
	--nhopkg-src "${NHO_SRC}" --no-sign 2>&1)
rc=$?
assert_status 0 "${rc}" "the real generator published the fixture index"
install_index "${GEN_OUT}" "${STATE}"

out=$(SOURCE_INDEX_TIMESTAMP=200 "${GENERATOR}" \
	--fixture "${FIXTURES}" --output "${GEN_MAIN}" --refs main \
	--nhopkg-src "${NHO_SRC}" --no-sign 2>&1)
rc=$?
assert_status 0 "${rc}" "a main-only index can be generated"
install_index "${GEN_MAIN}" "${STATE_MAIN}"

make_entry libalpha main
make_entry libbeta main
assert_file "${STATE}/sources/main/packages/libalpha" "the alpha dependency is indexed"
assert_file "${STATE}/sources/main/packages/libbeta" "the beta dependency is indexed"

assert_contains "$(cat "${CONF}")" \
	'NHOPKG_USE_SOURCE_INDEX="${NHOPKG_USE_SOURCE_INDEX:-no}"' \
	"implicit source-index reuse is opt-in, defaulting to no"
assert_contains "$(cat "${CONF}")" \
	'NHOPKG_AUTO_SOURCE_FALLBACK="${NHOPKG_AUTO_SOURCE_FALLBACK:-no}"' \
	"source fallback is opt-in, defaulting to no"
assert_contains "$(cat "${TOOL}")" 'source_index_get_sources "${pkgname}"' \
	"the base super-build uses the shared source helper"
assert_contains "$(cat "${TOOL}")" 'source_index_get_sources "${pkg_base_name}"' \
	"the split super-build uses the same helper"

# ---------------------------------------------------------------------------
head1 "Etapa 5: -C reuses the cached nhoid, or clones when it must"
# ---------------------------------------------------------------------------

# run_get_sources <state> <branch> <name> [dest] [use-index]
get_rc=0
get_out=''
get_clones=0
get_dest=''
run_get_sources() {
	local state="$1" branch="$2" name="$3" dest="${4:-}" use_index="${5:-yes}"
	[[ -n "${dest}" ]] || dest="$(mktemp -d "${WORK}/get.XXXXXX")/dest"
	get_dest="${dest}"
	: > "${VCS_LOG}"
	(
		set +u
		NHOPKG_LOCALSTATEDIR="${state}"
		NHOPKG_GIT_BRANCH="${branch}"
		NHOPKG_GIT_SOURCES="http://no-network.invalid/sources"
		NHOPKG_USE_SOURCE_INDEX="${use_index}"
		. "${LIB}"
		nhoget_vcs() {
			printf '%s %s\n' "${NHOGET_REF:-}" "$*" >> "${VCS_LOG}"
			mkdir -p "$3" || return 1
			printf 'CLONED\n' > "$3/nhoid"
		}
		source_index_get_sources "${name}" "${get_dest}"
	) > "${WORK}/get.out" 2>&1
	get_rc=$?
	get_out="$(cat "${WORK}/get.out")"
	get_clones="$(wc -l < "${VCS_LOG}")"
}

run_get_sources "${STATE}" "" kinfocenter
assert_status 0 "${get_rc}" "an indexed recipe without extras succeeds"
assert_eq "0" "${get_clones}" "and performs zero clones"
assert_contains "${get_out}" "no clone" "the cache hit is reported"
cmp -s "${FIXTURES}/kinfocenter/main/nhoid" "${get_dest}/nhoid" &&
	ok "the cached nhoid is byte-identical to the published one" ||
	bad "the cached nhoid is byte-identical to the published one"

# The generated config defaults to "no": -C must follow the repository HEAD,
# even when a perfectly good indexed recipe is sitting in the state dir.
run_get_sources "${STATE}" "" kinfocenter "" no
assert_status 0 "${get_rc}" "NHOPKG_USE_SOURCE_INDEX=no still builds"
assert_eq "1" "${get_clones}" "and clones instead of reusing the cache"
assert_contains "$(cat "${VCS_LOG}")" " git http://no-network.invalid/sources/kinfocenter.git" \
	"the clone targets the configured Git source"
assert_eq "CLONED" "$(cat "${get_dest}/nhoid")" "the recipe comes from the clone"
assert_missing "${get_out}" "Using cached source metadata" "no cache hit is reported"

run_get_sources "${STATE}" glibc kinfocenter
assert_status 0 "${get_rc}" "the glibc alias also finds the main index"
assert_eq "0" "${get_clones}" "and needs no clone either"

mkdir -p "${STATE_EMPTY}/sources/main/packages"
run_get_sources "${STATE_EMPTY}" "" kinfocenter
assert_status 0 "${get_rc}" "without an index entry the clone path succeeds"
assert_eq "1" "${get_clones}" "and clones exactly once"
assert_contains "$(cat "${VCS_LOG}")" " git http://no-network.invalid/sources/kinfocenter.git" \
	"an empty branch leaves the ref to git's own default"
assert_eq "CLONED" "$(cat "${get_dest}/nhoid")" "the recipe comes from the clone"

cp -a "${STATE}" "${STATE_EXTRA}"
sed -i 's|^Source-Extra-Files: none$|Source-Extra-Files: patches/fix.patch others/data.txt|' \
	"${STATE_EXTRA}/sources/main/packages/kinfocenter.sourceinfo"
run_get_sources "${STATE_EXTRA}" "" kinfocenter
assert_status 0 "${get_rc}" "a recipe with extras succeeds"
assert_eq "1" "${get_clones}" "and clones exactly once to materialise them"
assert_contains "$(cat "${VCS_LOG}")" "main git" "the clone still uses the canonical ref"
cmp -s "${FIXTURES}/kinfocenter/main/nhoid" "${get_dest}/nhoid" &&
	ok "the published recipe replaces the repository's nhoid" ||
	bad "the published recipe replaces the repository's nhoid"
assert_missing "${get_out}" "no clone" "a recipe with extras is not announced as cached"

cp -a "${STATE}" "${STATE_BAD}"
printf '\n' >> "${STATE_BAD}/sources/main/packages/kinfocenter"
run_get_sources "${STATE_BAD}" "" kinfocenter
assert_status 0 "${get_rc}" "a corrupt cached recipe does not abort the build"
assert_eq "1" "${get_clones}" "a corrupt cached recipe falls back to one clone"
assert_missing "${get_out}" "no clone" "a corrupt cache is never announced as a hit"

run_get_sources "${STATE_MAIN}" musl kinfocenter
assert_status 0 "${get_rc}" "a musl build with only a main index still works"
assert_eq "1" "${get_clones}" "and clones once from musl"
assert_contains "$(cat "${VCS_LOG}")" "musl git" "an explicit musl branch is not remapped"

# A recipe published only under master (default branch of many GitLab repos)
# must be found with an empty NHOPKG_GIT_BRANCH, without forcing main.
STATE_MASTER="${WORK}/state-master"
mkdir -p "${STATE_MASTER}/sources/master/packages"
printf '# Name: masteronly\n# Version: 1.0\n' \
	> "${STATE_MASTER}/sources/master/packages/masteronly"
master_sha="$(sha256sum "${STATE_MASTER}/sources/master/packages/masteronly" | awk '{print $1}')"
cat > "${STATE_MASTER}/sources/master/packages/masteronly.sourceinfo" <<EOF
Source-Project: masteronly
Source-Ref: master
Source-Commit: deadbeef
Source-Url: http://no-network.invalid/sources/masteronly.git
Source-Extra-Files: none
Source-Nhoid-SHA256: ${master_sha}
Source-Validated: yes
Source-Indexed: 200
EOF
run_get_sources "${STATE_MASTER}" "" masteronly
assert_status 0 "${get_rc}" "a master-only indexed recipe is found with no branch set"
assert_eq "0" "${get_clones}" "and needs no clone"
assert_contains "${get_out}" "Using cached source metadata for masteronly (master, no clone)." \
	"the sidecar's ref is used, not a guessed main"

# A recipe published for both master and musl must resolve to master when no
# ref is configured; musl is a libc variant, not the default branch.
STATE_DUAL="${WORK}/state-dual"
for ref in master musl; do
	mkdir -p "${STATE_DUAL}/sources/${ref}/packages"
	printf '# Name: dualref\n# Version: 1.0\n' \
		> "${STATE_DUAL}/sources/${ref}/packages/dualref"
	dual_sha="$(sha256sum "${STATE_DUAL}/sources/${ref}/packages/dualref" | awk '{print $1}')"
	cat > "${STATE_DUAL}/sources/${ref}/packages/dualref.sourceinfo" <<EOF
Source-Project: dualref
Source-Ref: ${ref}
Source-Commit: deadbeef
Source-Url: http://no-network.invalid/sources/dualref.git
Source-Extra-Files: none
Source-Nhoid-SHA256: ${dual_sha}
Source-Validated: yes
Source-Indexed: 200
EOF
done
run_get_sources "${STATE_DUAL}" "" dualref
assert_status 0 "${get_rc}" "a master+musl recipe is found with no branch set"
assert_eq "0" "${get_clones}" "and needs no clone"
assert_contains "${get_out}" "Using cached source metadata for dualref (master, no clone)." \
	"the default branch wins over the musl variant"
run_get_sources "${STATE_DUAL}" musl dualref
assert_status 0 "${get_rc}" "an explicit musl ref still works"
assert_eq "0" "${get_clones}" "and needs no clone either"
assert_contains "${get_out}" "Using cached source metadata for dualref (musl, no clone)." \
	"the explicitly requested variant is honoured"

# ---------------------------------------------------------------------------
head1 "Etapa 5: the fallback is opt-in and cuts cycles"
# ---------------------------------------------------------------------------

# run_fallback <flag> <name> <tried> <depth> <chain rc> [packaging] [use-index]
fb_rc=0
fb_out=''
fb_tried=''
fb_depth=''
run_fallback() {
	local flag="$1" name="$2" tried="$3" depth="$4" chain_rc="$5" packaging="${6:-no}" use_index="${7:-yes}"
	rm -f "${CHAIN_LOG}"
	(
		set +u
		NHOPKG_LOCALSTATEDIR="${STATE}"
		NHOPKG_GIT_BRANCH=""
		NHOPKG_USE_SOURCE_INDEX="${use_index}"
		NHOPKG_AUTO_SOURCE_FALLBACK="${flag}"
		NHOPKG_PACKAGING="${packaging}"
		NHOPKG_BIN="chain-stub"
		SOURCE_FALLBACK_TRIED="${tried}"
		SOURCE_FALLBACK_DEPTH="${depth}"
		. "${LIB}"
		chain-stub() {
			printf '%s\n' "$*" >> "${CHAIN_LOG}"
			return "${chain_rc}"
		}
		source_fallback_for_build_dep "${name}" "build"
		fb_inner=$?
		printf 'TRIED=%s\nDEPTH=%s\n' "${SOURCE_FALLBACK_TRIED}" "${SOURCE_FALLBACK_DEPTH}"
		exit "${fb_inner}"
	) > "${WORK}/fallback.out" 2>&1
	fb_rc=$?
	fb_out="$(cat "${WORK}/fallback.out")"
	fb_tried="$(grep '^TRIED=' "${WORK}/fallback.out" || true)"
	fb_depth="$(grep '^DEPTH=' "${WORK}/fallback.out" || true)"
}

run_fallback no libalpha "" 0 0
assert_status 1 "${fb_rc}" "with the default no the fallback is inert"
assert_no_file "${CHAIN_LOG}" "and nothing is chained"
assert_eq "TRIED=" "${fb_tried}" "the tried set is untouched"

run_fallback yes libalpha "" 0 0 no no
assert_status 1 "${fb_rc}" "USE_SOURCE_INDEX=no also disables the fallback"
assert_missing "${fb_out}" "source available" "the local index is not consulted"
assert_no_file "${CHAIN_LOG}" "and no chained build is started"

run_fallback yes libalpha "" 0 0
assert_status 0 "${fb_rc}" "with yes an indexed dependency can be built"
assert_contains "${fb_out}" "source available: main/libalpha" "the source is announced"
assert_contains "$(cat "${CHAIN_LOG}")" "-C libalpha" "nhopkg -C is chained for the dependency"
assert_eq "TRIED=libalpha" "${fb_tried}" "the dependency is recorded as tried"
assert_eq "DEPTH=1" "${fb_depth}" "the chain depth is incremented"
assert_missing "$(cat "${CHAIN_LOG}")" "--packaging" "packaging is not passed by default"

run_fallback yes "libbeta>=1.0" "" 0 0
assert_status 0 "${fb_rc}" "a versioned build dep matches its indexed name"
assert_contains "$(cat "${CHAIN_LOG}")" "-C libbeta" "the version is stripped from the name"

run_fallback yes libalpha "libalpha:libbeta" 0 0
assert_status 1 "${fb_rc}" "a dependency already tried is refused"
assert_contains "${fb_out}" "already tried" "the cycle is reported"
assert_no_file "${CHAIN_LOG}" "and no second chain is started"

run_fallback yes libbeta "libalpha" 0 0 yes
assert_status 0 "${fb_rc}" "A -> B is allowed when only A was tried"
assert_contains "$(cat "${CHAIN_LOG}")" "-C libbeta --packaging" \
	"packaging mode is forwarded to the chained build"

run_fallback yes libbeta "libbeta:libalpha" 0 1 yes
assert_status 1 "${fb_rc}" "A -> B -> A is refused, cutting the cycle"
assert_contains "${fb_out}" "already tried" "the repeated package is named"

run_fallback yes libalpha "" 5 0
assert_status 1 "${fb_rc}" "the depth limit stops a long chain"
assert_contains "${fb_out}" "depth limit" "the limit is reported"
assert_no_file "${CHAIN_LOG}" "and nothing is chained past the limit"

run_fallback yes no-such-dep-xyz "" 0 0
assert_status 1 "${fb_rc}" "a dependency absent from the index is not built"
assert_missing "${fb_out}" "source available" "absence from the index is not announced as a source"
assert_no_file "${CHAIN_LOG}" "and nothing is chained"

run_fallback yes libalpha "" 0 1
assert_status 1 "${fb_rc}" "a failed chained build is not treated as success"
assert_contains "$(cat "${CHAIN_LOG}")" "-C libalpha" "the chain was still attempted once"

# ---------------------------------------------------------------------------
head1 "Etapa 5: dep_resolve_from_nhoid retries only after a real fallback"
# ---------------------------------------------------------------------------

RESOLVE_FN="$(awk '
	/^dep_resolve_from_nhoid\(\)/ { grab = 1 }
	grab { print }
	grab && /^}$/ { exit }
' "${UDEP}")"
[[ -n "${RESOLVE_FN}" ]] || die "dep_resolve_from_nhoid() not found in ${UDEP}"
NHOID_FIXTURE="${WORK}/dep.nhoid"
printf '# Name: demo\n# BuildDep:\tlibalpha\n# Dep(post):\tlibbeta\n# OptionalBuildDep:\tlibbeta\n' > "${NHOID_FIXTURE}"

# run_resolve <dep type> <hook behaviour> <resolve attempts>
# hook behaviour: absent | fail | ok ; resolve attempts: always | second
resolve_rc=0
resolve_out=''
run_resolve() {
	local dep_type="$1" hook="$2" resolve="$3" counter="${WORK}/resolve.calls"
	rm -f "${counter}"
	(
		set +u
		. "${LIB}"
		eval "${RESOLVE_FN}"
		_dep_resolve_single() {
			printf 'x\n' >> "${counter}"
			local n
			n="$(wc -l < "${counter}")"
			if [[ "${resolve}" = "second" && "${n}" -ge 2 ]]; then
				return 0
			fi
			printf ' *** %s (NOT FOUND)\n' "$1" >&2
			return 1
		}
		case "${hook}" in
			absent) : ;;
			fail) source_fallback_for_build_dep() { printf ' HOOK (%s)\n' "$1"; return 1; } ;;
			ok) source_fallback_for_build_dep() { printf ' HOOK (%s)\n' "$1"; return 0; } ;;
		esac
		dep_resolve_from_nhoid "${NHOID_FIXTURE}" "${dep_type}" "no"
	) > "${WORK}/resolve.out" 2>&1
	resolve_rc=$?
	resolve_out="$(cat "${WORK}/resolve.out")"
}

run_resolve build absent always
assert_status 1 "${resolve_rc}" "without the hook a missing BuildDep still aborts"
assert_contains "${resolve_out}" "Dependency resolution failed for: libalpha" "the original message is unchanged"
assert_eq "1" "$(wc -l < "${WORK}/resolve.calls")" "resolution was attempted once"

run_resolve build fail always
assert_status 1 "${resolve_rc}" "a refused fallback still aborts"
assert_contains "${resolve_out}" "HOOK (libalpha)" "the hook was consulted"
assert_contains "${resolve_out}" "Dependency resolution failed for: libalpha" "the failure is still reported"

run_resolve build ok second
assert_status 0 "${resolve_rc}" "a successful fallback lets the build continue"
assert_contains "${resolve_out}" "HOOK (libalpha)" "the fallback ran"
assert_missing "${resolve_out}" "Dependency resolution failed" "no failure is reported"
assert_eq "2" "$(wc -l < "${WORK}/resolve.calls")" "the dependency was resolved again after the chain"

run_resolve required ok second
assert_status 1 "${resolve_rc}" "the fallback never applies to runtime dependencies"
assert_contains "${resolve_out}" "Dependency resolution failed for: libbeta" "the runtime dep still aborts"
assert_missing "${resolve_out}" "HOOK" "the hook was not consulted"

run_resolve optional_build ok always
assert_status 0 "${resolve_rc}" "optional build deps keep their old soft-failure behaviour"
assert_contains "${resolve_out}" "Optional dependency not found" "the optional miss is only a notice"
assert_missing "${resolve_out}" "HOOK" "the fallback is not involved"

exit "$(t_summary)"
