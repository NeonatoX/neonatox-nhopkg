#!/bin/bash
# --packaging promises a build that does not touch the live system, and used to
# mutate it in four places anyway: it uninstalled the package that was already
# installed, installed dependencies into /, refreshed the system caches and
# rewrote the locate database. The build kept going in every case, so the only
# warning was the damage itself.
#
# The build path needs root, so the code is not run as a program here. Each
# function is extracted from the generated tool and run verbatim in a sandbox,
# with everything it calls stubbed to write into a canary file: the run reports
# what it would have touched instead of touching it, and a missing guard shows
# up as a canary that is no longer empty. The dependency guard lives at its two
# call sites rather than inside a function, so the enclosing block is extracted
# as a whole and run the same way.
#
#   See "What is not covered" in tests/README.md.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
LIB_SRC="${BUILDDIR}/src/libnhopkg"
UDEP_SRC="${BUILDDIR}/src/libnhopkg_udepsys"
for _src in "${TOOL_SRC}" "${LIB_SRC}" "${UDEP_SRC}"; do
	[[ -f "${_src}" ]] || die "not found: ${_src} (run meson setup first)"
done

# The markers outside the guarded code. Both build branches end with one, and
# the dependency block sits right in front of it, so the extraction below finds
# the same two blocks with or without the guard in place.
ANCHOR_BUILD='## 5. Restore package base tempdir for build package (*.srcnho)'
ANCHOR_SUPER='## 5. Restore package base tempdir for build package (Git)'

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

# dep_block <file> <anchor> : the NHOPKG_CHECKDEPS block that runs the
# dependency queue, that is, the last such block closed before the anchor.
# Selecting on dep_install_queue keeps the block readable in both states: with
# the guard (the call behind an else) and without it (the mutant), which is
# what the run below compares.
dep_block() {
	awk -v anchor="$2" '
		{
			raw = $0
			ind = raw
			sub(/[^ \t].*$/, "", ind)
			trim = raw
			sub(/^[ \t]+/, "", trim)
			line[NR] = raw
		}
		trim == anchor {
			if (keep) { for (i = start; i <= stop; i++) print line[i]; exit }
		}
		!open && trim == "if [[ \"${NHOPKG_CHECKDEPS}\" = \"yes\" ]]; then" {
			open = 1
			start = NR
			start_ind = ind
			buf = ""
			next
		}
		open {
			buf = buf $0 "\n"
			if (trim == "fi" && ind == start_ind) {
				open = 0
				stop = NR
				keep = (index(buf, "dep_install_queue") > 0)
			}
		}
	' "$1"
}

# ---------------------------------------------------------------------------
# Running it
# ---------------------------------------------------------------------------

# pack_init : a fresh sandbox with a shim dir and an empty canary.
SB=''
RC=0
OUT=''
pack_init() {
	SB="$(mktemp -d "${WORK}/pack.XXXXXX")"
	mkdir -p "${SB}/bin" "${SB}/state/packages"
	: > "${SB}/canary"
}

# pack_eval <program> : run the program as the tool would, only with the
# commands it reaches stubbed. Results land in OUT and RC. The functions are
# defined before the eval on purpose: a subshell of "$(...)" would swallow the
# exit status otherwise, and the status is half of what is tested here.
pack_eval() {
	OUT="$(
		PATH="${SB}/bin:${PATH}"
		NHOPKG_LOCALSTATEDIR="${SB}/state"
		NHOPKG_DB="${SB}/state/nhopkg.db"
		NHOPKG_TMPDIR="${SB}/state/tmpdir"
		NHOPKG_PACKAGING=yes
		NHOPKG_USE_BUSYBOX=no
		USE_INSTALL_ROOT=no
		BOLD=
		NORMAL=
		CANARY="${SB}/canary"
		set +u
		echog() { printf '%s\n' "$*"; }
		echogn() { printf '%s' "$*"; }
		check_if_ok() { :; }
		eval "$1"
	)"
	RC=$?
}

canary() { cat "${SB}/canary" 2>/dev/null; }
canary_touched() { [[ -s "${SB}/canary" ]] && printf 1 || printf 0; }

# The four cache commands, as shims that only write the canary: shooter_updates
# resolves every one of them through PATH, so a shim is what makes the
# packaging=no control run safe to do on this machine.
shim_cache_tools() {
	local cmd
	for cmd in glib-compile-schemas gtk-update-icon-cache update-desktop-database \
		update-mime-database mandb fc-cache ldconfig gdk-pixbuf-query-loaders; do
		printf '#!/bin/sh\necho "%s" >> "%s"\nexit 0\n' "${cmd}" "${SB}/canary" \
			> "${SB}/bin/${cmd}"
		chmod +x "${SB}/bin/${cmd}"
	done
}

# ---------------------------------------------------------------------------
# The four programs under test
# ---------------------------------------------------------------------------

# installed_program <body> <packaging> : a fake package on disk, the real
# function, and the three things it would call if it decided to remove it.
installed_program() {
	printf '%s\n' \
		"NHOPKG_PACKAGING=$2" \
		'get_package_display_name() { PKG_DISPLAY_NAME=demo; }' \
		'get_basic_data() { :; }' \
		'nhopkg_ask_follow() { echo prompt >> "${CANARY}"; return 1; }' \
		'backup_config_files() { echo backup >> "${CANARY}"; }' \
		'remove_package() { echo remove >> "${CANARY}"; }' \
		'remove_package_config_files() { echo removeconf >> "${CANARY}"; }' \
		'mkdir -p "${NHOPKG_LOCALSTATEDIR}/packages"' \
		'echo installed > "${NHOPKG_LOCALSTATEDIR}/packages/demo"' \
		"$1" \
		'check_if_installed_package' \
		'rc=$?' \
		'echo "rc=${rc}"' \
		'exit "${rc}"'
}

# dep_program <body> <required list> <optional list> : the two queues as they
# stand after resolution, and what the guard makes of them.
dep_program() {
	printf '%s\n' \
		"RCASEPACKAGES=($2)" \
		"ORCASEPACKAGES=($3)" \
		"$1" \
		'dep_packaging_stop_if_missing' \
		'rc=$?' \
		'echo "rc=${rc}"' \
		'echo "left=${#RCASEPACKAGES[@]}/${#ORCASEPACKAGES[@]}"' \
		'exit "${rc}"'
}

# dep_block_program <block> <packaging> <guard status> : the call site as it
# stands, with the queue installer and the guard replaced by canaries.
dep_block_program() {
	printf '%s\n' \
		"NHOPKG_PACKAGING=$2" \
		'NHOPKG_CHECKDEPS=yes' \
		'cleanup_tmp_dir() { echo cleanup >> "${CANARY}"; }' \
		'dep_resolve_from_nhoid() { :; }' \
		'dep_install_queue() { echo install >> "${CANARY}"; }' \
		'dep_packaging_stop_if_missing() { echo stop >> "${CANARY}"; return '"$3"'; }' \
		"$1" \
		'rc=$?' \
		'echo "rc=${rc}"' \
		'exit "${rc}"'
}

# updatedb_program <body> <packaging> : updatedb is a command, so it is a
# function here that leaves the database behind the way updatedb does.
updatedb_program() {
	printf '%s\n' \
		"NHOPKG_PACKAGING=$2" \
		'updatedb() { echo updatedb >> "${CANARY}"; touch "${NHOPKG_DB}"; }' \
		"$1" \
		'update_local_db' \
		'rc=$?' \
		'echo "rc=${rc}"' \
		'exit "${rc}"'
}

# shooter_program <body> <packaging>
shooter_program() {
	printf '%s\n' \
		"NHOPKG_PACKAGING=$2" \
		"$1" \
		'shooter_updates' \
		'rc=$?' \
		'echo "rc=${rc}"' \
		'exit "${rc}"'
}

# ---------------------------------------------------------------------------
# Taking the code apart, and what it says
# ---------------------------------------------------------------------------

INSTALLED_BODY="$(fn_body "${TOOL_SRC}" check_if_installed_package)"
DEP_BODY="$(fn_body "${UDEP_SRC}" dep_packaging_stop_if_missing)"
UPDATE_BODY="$(fn_body "${TOOL_SRC}" update_local_db)"
SHOOTER_BODY="$(fn_body "${LIB_SRC}" shooter_updates)"

[[ -n "${INSTALLED_BODY}" ]] || die "check_if_installed_package was not found in ${TOOL_SRC}. If it moved, update fn_body() here, otherwise nothing below is testing anything."
[[ -n "${DEP_BODY}" ]] || die "dep_packaging_stop_if_missing was not found in ${UDEP_SRC}. If it moved, update fn_body() here, otherwise nothing below is testing anything."
[[ -n "${UPDATE_BODY}" ]] || die "update_local_db was not found in ${TOOL_SRC}. If it moved, update fn_body() here, otherwise nothing below is testing anything."
[[ -n "${SHOOTER_BODY}" ]] || die "shooter_updates was not found in ${LIB_SRC}. If it moved, update fn_body() here, otherwise nothing below is testing anything."

BUILD_BLOCK="$(dep_block "${TOOL_SRC}" "${ANCHOR_BUILD}")"
SUPER_BLOCK="$(dep_block "${TOOL_SRC}" "${ANCHOR_SUPER}")"
[[ -n "${BUILD_BLOCK}" ]] || die "the build dependency block was not found in ${TOOL_SRC}."
[[ -n "${SUPER_BLOCK}" ]] || die "the super-build dependency block was not found in ${TOOL_SRC}."

head1 "the guard at the dependency call sites"
assert_contains "${BUILD_BLOCK}" 'dep_packaging_stop_if_missing' "the build block routes through the packaging guard"
assert_contains "${SUPER_BLOCK}" 'dep_packaging_stop_if_missing' "the super-build block routes through the packaging guard"

# ---------------------------------------------------------------------------
# 1. The package already installed is left alone
# ---------------------------------------------------------------------------

head1 "packaging build: the installed package is not uninstalled"
pack_init
pack_eval "$(installed_program "${INSTALLED_BODY}" yes)"
assert_status 0 "${RC}" "the build carries on"
assert_contains "${OUT}" "packaging leaves it untouched" "the build says why it stopped touching the package"
assert_contains "${OUT}" "nhopkg -i" "and says how to install it"
assert_eq "0" "$(canary_touched)" "nothing was prompted, backed up or removed"

head1 "live build: the installed package is still uninstalled"
pack_init
pack_eval "$(installed_program "${INSTALLED_BODY}" no)"
assert_status 0 "${RC}" "the build carries on"
assert_eq "1" "$(canary_touched)" "the package is removed, as it is outside packaging mode"
assert_contains "$(canary)" "remove" "remove_package is what ran"

# ---------------------------------------------------------------------------
# 2. Dependencies are not installed
# ---------------------------------------------------------------------------

head1 "packaging build: a missing required dependency stops the build"
pack_init
pack_eval "$(dep_program "${DEP_BODY}" "foo-1.0-1 bar-2.0-1" "")"
assert_status 1 "${RC}" "the build stops with status 1"
assert_contains "${OUT}" "Missing: foo-1.0-1 bar-2.0-1" "the missing packages are named"
assert_contains "${OUT}" "nhopkg -i" "and how to install them is said"
assert_contains "${OUT}" "left=0/0" "both queues are cleared"

head1 "packaging build: a missing optional dependency only warns"
pack_init
pack_eval "$(dep_program "${DEP_BODY}" "" "baz-3.0-1")"
assert_status 0 "${RC}" "the build carries on"
assert_contains "${OUT}" "optional: baz-3.0-1" "the optional package is named"
assert_contains "${OUT}" "left=0/0" "the queue is cleared anyway"

head1 "packaging build: nothing missing, nothing said"
pack_init
pack_eval "$(dep_program "${DEP_BODY}" "" "")"
assert_status 0 "${RC}" "the build carries on"
assert_missing "${OUT}" "Packaging mode does not install" "no warning when there is nothing to install"

for _block_name in build super; do
	if [[ "${_block_name}" == build ]]; then
		_block="${BUILD_BLOCK}"
	else
		_block="${SUPER_BLOCK}"
	fi

	head1 "packaging build ($_block_name): the queue is never installed"
	pack_init
	pack_eval "$(dep_block_program "${_block}" yes 0)"
	assert_status 0 "${RC}" "the build carries on"
	assert_contains "$(canary)" "stop" "the packaging guard decides"
	assert_missing "$(canary)" "install" "dep_install_queue is never reached"
	assert_missing "$(canary)" "cleanup" "nothing is torn down"

	head1 "packaging build ($_block_name): a required dependency stops it"
	pack_init
	pack_eval "$(dep_block_program "${_block}" yes 1)"
	assert_status 1 "${RC}" "the build stops with status 1"
	assert_contains "$(canary)" "cleanup" "the temporary directory is cleaned up first"
	assert_missing "$(canary)" "install" "dep_install_queue is never reached"

	head1 "live build ($_block_name): the queue is still installed"
	pack_init
	pack_eval "$(dep_block_program "${_block}" no 0)"
	assert_status 0 "${RC}" "the build carries on"
	assert_contains "$(canary)" "install" "dep_install_queue runs outside packaging mode"
	assert_missing "$(canary)" "stop" "the packaging guard is not consulted"
done

# ---------------------------------------------------------------------------
# 3. The locate database is left alone
# ---------------------------------------------------------------------------

head1 "packaging build: the locate database is not rewritten"
pack_init
pack_eval "$(updatedb_program "${UPDATE_BODY}" yes)"
assert_status 0 "${RC}" "the build carries on"
assert_contains "${OUT}" "nhopkg -u" "the build says how to refresh it"
assert_eq "0" "$(canary_touched)" "updatedb is never run"
assert_no_file "${SB}/state/nhopkg.db" "the database file is not written"

head1 "live build: the locate database is still rewritten"
pack_init
pack_eval "$(updatedb_program "${UPDATE_BODY}" no)"
assert_status 0 "${RC}" "the build carries on"
assert_eq "1" "$(canary_touched)" "updatedb runs outside packaging mode"
assert_file "${SB}/state/nhopkg.db" "the database file is written"

# ---------------------------------------------------------------------------
# 4. The system caches are left alone
# ---------------------------------------------------------------------------

head1 "packaging build: no cache of this system is touched"
pack_init
shim_cache_tools
pack_eval "$(shooter_program "${SHOOTER_BODY}" yes)"
assert_status 0 "${RC}" "the build carries on"
assert_contains "${OUT}" "nhopkg -x" "the build says how to refresh them"
assert_eq "0" "$(canary_touched)" "no schema, icon, mime, font or ldconfig command ran"

head1 "live build: the caches are still refreshed"
pack_init
shim_cache_tools
pack_eval "$(shooter_program "${SHOOTER_BODY}" no)"
assert_status 0 "${RC}" "the build carries on"
assert_eq "1" "$(canary_touched)" "the cache commands run outside packaging mode"

# ---------------------------------------------------------------------------
# The guards, taken out
# ---------------------------------------------------------------------------

head1 "mutants"
MUT_TOOL="${TOOLDIR}/nhopkg-mutant"
MUT_LIB="${TOOLDIR}/libnhopkg-mutant"

# 1. Without the guard the build uninstalls the package it finds installed.
cp "${TOOL_SRC}" "${MUT_TOOL}"
apply_mutant_to "${MUT_TOOL}" pre-packaging-keep-installed
MUT_INSTALLED="$(fn_body "${MUT_TOOL}" check_if_installed_package)"
[[ "${MUT_INSTALLED}" != "${INSTALLED_BODY}" ]] && ok "the mutant changed check_if_installed_package" ||
	bad "the mutant did not change check_if_installed_package"
pack_init
pack_eval "$(installed_program "${MUT_INSTALLED}" yes)"
assert_status 0 "${RC}" "without the guard the build still reported success"
assert_eq "1" "$(canary_touched)" "without the guard the package is removed (this is the bug)"

# 2. Without the guard the build installs dependencies into /.
cp "${TOOL_SRC}" "${MUT_TOOL}"
apply_mutant_to "${MUT_TOOL}" pre-packaging-install-deps
for _block_name in build super; do
	if [[ "${_block_name}" == build ]]; then
		_anchor="${ANCHOR_BUILD}"
	else
		_anchor="${ANCHOR_SUPER}"
	fi
	MUT_BLOCK="$(dep_block "${MUT_TOOL}" "${_anchor}")"
	[[ -n "${MUT_BLOCK}" ]] && ok "[$_block_name] the block is still found after the mutant" ||
		bad "[$_block_name] the block disappeared after the mutant"
	if [[ "${_block_name}" == build ]]; then
		[[ "${MUT_BLOCK}" != "${BUILD_BLOCK}" ]] && ok "the mutant changed the build block" ||
			bad "the mutant did not change the build block"
	else
		[[ "${MUT_BLOCK}" != "${SUPER_BLOCK}" ]] && ok "the mutant changed the super-build block" ||
			bad "the mutant did not change the super-build block"
	fi
	pack_init
	pack_eval "$(dep_block_program "${MUT_BLOCK}" yes 0)"
	assert_status 0 "${RC}" "[$_block_name] without the guard the build still reported success"
	assert_eq "1" "$(canary_touched)" "[$_block_name] without the guard the queue is installed (this is the bug)"
done

# 3. Without the guard the build refreshes the caches of this system.
cp "${LIB_SRC}" "${MUT_LIB}"
apply_mutant_to "${MUT_LIB}" pre-packaging-shooter
MUT_SHOOTER="$(fn_body "${MUT_LIB}" shooter_updates)"
[[ "${MUT_SHOOTER}" != "${SHOOTER_BODY}" ]] && ok "the mutant changed shooter_updates" ||
	bad "the mutant did not change shooter_updates"
pack_init
shim_cache_tools
pack_eval "$(shooter_program "${MUT_SHOOTER}" yes)"
assert_status 0 "${RC}" "without the guard the build still reported success"
assert_eq "1" "$(canary_touched)" "without the guard the caches are refreshed (this is the bug)"

# 4. Without the guard the build rewrites the locate database.
cp "${TOOL_SRC}" "${MUT_TOOL}"
apply_mutant_to "${MUT_TOOL}" pre-packaging-updatedb
MUT_UPDATE="$(fn_body "${MUT_TOOL}" update_local_db)"
[[ "${MUT_UPDATE}" != "${UPDATE_BODY}" ]] && ok "the mutant changed update_local_db" ||
	bad "the mutant did not change update_local_db"
pack_init
pack_eval "$(updatedb_program "${MUT_UPDATE}" yes)"
assert_status 0 "${RC}" "without the guard the build still reported success"
assert_eq "1" "$(canary_touched)" "without the guard the database is rewritten (this is the bug)"

exit "$(t_summary)"
