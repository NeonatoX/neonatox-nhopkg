#!/bin/bash
# A split package built again must be checked for an installed copy first.
#
# check_if_installed_package("<part>") builds the installed name as
# "<base>-<part>". The split loop runs check_package_conflicts() before it, and
# that reads the split nhoid through get_basic_data(), which overwrites the
# global $pkgname with the split name. The lookup then asked for
# "<base>-<part>-<part>", found nothing and returned without checking: no
# UPDATE/REINSTALL prompt, no config backup and no removal of the old split,
# which was then installed over without being retired.
#
# The client needs root, so the per-part block is taken out of the generated
# tool and run verbatim in a sandbox. get_basic_data(), get_package_display_name(),
# check_if_installed_package() and dep_check_conflicts() are the real ones; the
# rest is stubbed to a canary so the run reports what it would have touched.
#
#   See "What is not covered" in tests/README.md.

set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
LIB_SRC="${BUILDDIR}/src/libnhopkg"
UDEP_SRC="${BUILDDIR}/src/libnhopkg_udepsys"
for f in "${TOOL_SRC}" "${LIB_SRC}" "${UDEP_SRC}"; do
	[[ -f "${f}" ]] || die "not found: ${f} (run meson setup first)"
done

# ---------------------------------------------------------------------------
# Taking the pieces apart
# ---------------------------------------------------------------------------

# fn_body <file> <name> : the function, from its header to the closing brace.
fn_body() {
	awk -v fn="$2" '
		$0 == fn"()" || $0 == fn"() {" { grab = 1 }
		grab { print }
		grab && /^}/ { exit }
	' "$1"
}

# The two per-part blocks (build and super-build), from the source nhoid read
# to build_prepare(), separated by NUL bytes. Both are run: the defect was in
# the pair, not in one of them.
split_blocks() { # <file>
	awk '
		function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
		{
			if (!open && trim($0) == "# Retrieve data from the main package") {
				open = 1
				buf = ""
			}
			if (open) buf = buf $0 "\n"
			if (open && trim($0) == "build_prepare") {
				printf "%s%c", buf, 0
				open = 0
			}
		}
	' "$1"
}

mapfile -d '' BLOCKS < <(split_blocks "${TOOL_SRC}")
(( ${#BLOCKS[@]} == 2 )) ||
	die "expected the two split blocks in ${TOOL_SRC}, found ${#BLOCKS[@]}.
    If they moved, update split_blocks() here, otherwise nothing below is
    testing anything."

GET_BASIC="$(fn_body "${LIB_SRC}" get_basic_data)"
DISPLAY="$(fn_body "${TOOL_SRC}" get_package_display_name)"
CHECK="$(fn_body "${TOOL_SRC}" check_if_installed_package)"
CONFLICTS="$(fn_body "${UDEP_SRC}" dep_check_conflicts)"
CONFLICTS_WRAPPER="$(fn_body "${UDEP_SRC}" check_package_conflicts)"
for name in GET_BASIC DISPLAY CHECK CONFLICTS CONFLICTS_WRAPPER; do
	[[ -n "${!name}" ]] ||
		die "${name} was not found. If it moved, update fn_body() here,
    otherwise nothing below is testing anything."
done

# ---------------------------------------------------------------------------
# The sandbox
# ---------------------------------------------------------------------------

SB=''
OUT=''
RC=0

split_init() {
	SB="$(mktemp -d "${WORK}/splitinst.XXXXXX")"
	mkdir -p "${SB}/state/packages" "${SB}/tmpdir"
	: > "${SB}/canary"

	# The source nhoid, as the loop reads it before generating the split one.
	cat > "${SB}/base.nhoid" <<'EOF'
# Name:	demo-base
# Version:	1.0
# Release:	1
# Description:	demo base
EOF
	# The split nhoid that build_nhoid_to_bin() leaves behind.
	cat > "${SB}/split.nhoid" <<'EOF'
# Name:	demo-base-extra
# Version:	1.0
# Release:	1
# Description:	demo base extra
EOF
	cp "${SB}/base.nhoid" "${SB}/tmpdir/nhoid"

	# An installed copy of the split: the check has to find this one.
	cat > "${SB}/state/packages/demo-base-extra" <<'EOF'
# Name:	demo-base-extra
# Version:	1.0
# Release:	1
# Description:	demo base extra
EOF
}

# split_run <block> : run the block as the tool does, with only the calls it
# makes around the check stubbed.
split_run() {
	OUT="$(
		set +u
		NHOPKG_LOCALSTATEDIR="${SB}/state"
		NHOPKG_TMPDIR="${SB}/tmpdir"
		ROOT_PKG_STATE_DIR="${SB}/state"
		NHOPKG_PACKAGING=no
		REPLACES_PACKAGE=""
		BOLD=
		NORMAL=
		CANARY="${SB}/canary"
		part=extra

		echog() { printf '%s\n' "$*"; }
		echogn() { printf '%s' "$*"; }
		check_if_ok() { :; }
		nhopkg_ask_follow() { return 0; }
		backup_config_files() { echo backup >> "${CANARY}"; }
		remove_package() { echo remove >> "${CANARY}"; }
		remove_package_config_files() { echo removeconf >> "${CANARY}"; }
		remove_replaced_package() { echo replace >> "${CANARY}"; }
		cleanup_tmp_dir() { :; }
		build_prepare() { :; }
		build_nhoid_to_bin() { cp "${SB}/split.nhoid" "${NHOPKG_TMPDIR}/nhoid"; }

		eval "${GET_BASIC}"
		eval "${DISPLAY}"
		eval "${CHECK}"
		eval "${CONFLICTS}"
		eval "${CONFLICTS_WRAPPER}"

		eval "$1"
		echo "display=${PKG_DISPLAY_NAME}"
	)"
	RC=$?
}

canary() { cat "${SB}/canary" 2>/dev/null; }
display_of() { sed -n 's/^display=//p' <<<"${OUT}"; }

# ---------------------------------------------------------------------------
# The check
# ---------------------------------------------------------------------------

head1 "the installed split is looked up as <base>-<part>"
for i in "${!BLOCKS[@]}"; do
	split_init
	split_run "${BLOCKS[$i]}"
	assert_status 0 "${RC}" "block $((i + 1)): the per-part block runs"
	assert_eq "demo-base-extra" "$(display_of)" \
		"block $((i + 1)): the lookup name is <base>-<part>"
	assert_contains "$(canary)" "backup" \
		"block $((i + 1)): the old split's config files are backed up"
	assert_contains "$(canary)" "remove" \
		"block $((i + 1)): the old split is removed before reinstalling"
done

# ---------------------------------------------------------------------------
# The defect, written down as a test
# ---------------------------------------------------------------------------

head1 "mutant: without the reload the installed check is silently skipped"
MUT_DIR="${WORK}/split-installed-mutant"
rm -rf "${MUT_DIR}"
mkdir -p "${MUT_DIR}"
MUT="${MUT_DIR}/nhopkg"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-split-installed-name

mapfile -d '' MUT_BLOCKS < <(split_blocks "${MUT}")
(( ${#MUT_BLOCKS[@]} == 2 )) || die "the mutant lost the split blocks"
[[ "${MUT_BLOCKS[0]}" != "${BLOCKS[0]}" ]] &&
	ok "the mutant changed the per-part block" ||
	bad "the mutant did not change the per-part block"

split_init
split_run "${MUT_BLOCKS[0]}"
assert_status 0 "${RC}" "the build carries on"
assert_eq "demo-base-extra-extra" "$(display_of)" \
	"the lookup asks for a name that cannot exist (this is the bug)"
assert_eq "" "$(canary)" \
	"and nothing is backed up or removed (this is the bug)"

exit "$(t_summary)"
