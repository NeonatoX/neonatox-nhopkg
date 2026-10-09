#!/bin/bash
# A runtime Dep(post) on a split built in the same run must not break the build.
#
# `nhopkg -b foo.srcnho` (or -C) builds the base package first, and resolves its
# dependencies before that. When the base declares a runtime dependency on one of
# its own splits ("# Splitpackage: lib" and "# Dep(post): foo-lib"), the split is
# neither installed nor in a repo yet, so the resolver failed and the build
# aborted with "dependency resolution failed for: foo-lib" -- even though the
# split was about to be built later in the same run.
#
# The fix is a self-provide check that runs inside _dep_resolve_single for
# runtime deps only. The names are resolved by src/nhopkg.in while $pkgname is
# still the source package (get_basic_data() overwrites it during resolution), so
# the library only compares strings.
#
# The resolver is plain library code, so it runs here without root: the generated
# libnhopkg_udepsys is sourced against an empty state directory. If the hooks
# move, the mutant marker in tests/lib.sh stops matching and this test dies with
# a message instead of passing quietly.

set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build

LIB_SRC="${BUILDDIR}/src/libnhopkg_udepsys"
[[ -f "${LIB_SRC}" ]] || die "not found: ${LIB_SRC} (run meson setup first)"

SBROOT="${WORK}/self-provide"
mkdir -p "${SBROOT}/packages" "${SBROOT}/repo" "${TOOLDIR}" "${LOGS}"

# ---------------------------------------------------------------------------
# Running one resolution in isolation
# ---------------------------------------------------------------------------

# resolve_probe <libfile> <spec> <type> -> "rc|repo|queue"
#
# Runs in a subshell so each case starts from a clean resolver state. The parent
# sets PROBE_NAMES (space-separated self-provided names) and PROBE_VER before the
# call; they are applied AFTER sourcing, because the library declares them.
resolve_probe() { # <libfile> <spec> <type>
	local libfile="$1" spec="$2" type="$3"
	(
		set -o pipefail
		set +u
		NHOPKG_ACTIVE_REPOS=""
		ROOT_PKG_STATE_DIR="${SBROOT}"
		source "${libfile}"
		RCASEPACKAGES=()
		ORCASEPACKAGES=()
		DEP_RESOLVED_CACHE=()
		DEP_REPO_CACHE=()
		SELF_PROVIDED_NAMES=()
		SELF_PROVIDED_VERSION=""
		if [[ -n "${PROBE_NAMES:-}" ]]; then
			read -r -a SELF_PROVIDED_NAMES <<< "${PROBE_NAMES}"
		fi
		SELF_PROVIDED_VERSION="${PROBE_VER:-}"
		_dep_resolve_single "$spec" "$type" "yes" "yes" ""
		local rc=$?
		printf '%d|%s|%s\n' "$rc" "${DEP_REPO_CACHE[$spec]:-}" "${RCASEPACKAGES[*]:-}"
	)
}

probe_field() { # <probe output> <field number> -> value
	printf '%s\n' "$1" | cut -d'|' -f"$2"
}

# ---------------------------------------------------------------------------
# The hook itself
# ---------------------------------------------------------------------------

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-lib" "required")
assert_status 0 "$(probe_field "${out}" 1)" "a required dep on a self-provided split resolves"
assert_eq "self-split" "$(probe_field "${out}" 2)" "it is tagged as self-provided, not a repo"
assert_eq "" "$(probe_field "${out}" 3)" "nothing is queued for install"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-lib>=1.0" "required")
assert_status 0 "$(probe_field "${out}" 1)" "the version constraint is compared, and 1.5 satisfies >=1.0"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-lib>=99" "required")
assert_status 1 "$(probe_field "${out}" 1)" "a split too old does not satisfy the dep: normal (failing) resolution"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-lib" "optional")
assert_status 0 "$(probe_field "${out}" 1)" "an optional dep on a split resolves too"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-lib" "build")
assert_status 1 "$(probe_field "${out}" 1)" "a BuildDep is never self-provided (nbuild needs the files)"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${LIB_SRC}" "foo-dev" "required")
assert_status 1 "$(probe_field "${out}" 1)" "a different name is not self-provided"

# With no splits being built, the resolver behaves exactly as before.
out=$(resolve_probe "${LIB_SRC}" "foo-lib" "required")
assert_status 1 "$(probe_field "${out}" 1)" "an empty self-provide list changes nothing"

# ---------------------------------------------------------------------------
# dep_resolve_from_nhoid: the positive path must not abort the build
# ---------------------------------------------------------------------------

echog()  { printf '%s\n' "$*"; }
echogn() { printf '%s\n' "$*"; }

NHOID="${SBROOT}/self.nhoid"
{
	printf '#%%NHO-0.5\n'
	printf '# Package Maintainer:\ttester\ttester@example.invalid\n'
	printf '# Name:\tfoo\n'
	printf '# Version:\t1.5\n'
	printf '# Release:\t1\n'
	printf '# Description:\tfixture\n'
	printf '# Splitpackage:\tlib\n'
	printf '# Dep(post):\tfoo-lib\n'
} > "${NHOID}"

(
	set -o pipefail
	set +u
	NHOPKG_ACTIVE_REPOS=""
	ROOT_PKG_STATE_DIR="${SBROOT}"
	source "${LIB_SRC}"
	read -r -a SELF_PROVIDED_NAMES <<< "foo-lib"
	SELF_PROVIDED_VERSION="1.5-1"
	dep_resolve_from_nhoid "${NHOID}" "required" "yes" ""
) > "${LOGS}/self-provide-dep.log" 2>&1
assert_status 0 "$?" "dep_resolve_from_nhoid returns 0 for a self-provided required dep"

# ---------------------------------------------------------------------------
# Reverting the hook reproduces the original failure
# ---------------------------------------------------------------------------

MUT_LIB="${TOOLDIR}/libnhopkg_udepsys-self"
cp "${LIB_SRC}" "${MUT_LIB}"
apply_mutant_to "${MUT_LIB}" "pre-self-provide"

out=$(PROBE_NAMES="foo-lib" PROBE_VER="1.5-1" resolve_probe "${MUT_LIB}" "foo-lib" "required")
assert_status 1 "$(probe_field "${out}" 1)" "the mutant (no hook) fails to resolve the split"

exit "$(t_summary)"
