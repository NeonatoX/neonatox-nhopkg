#!/bin/bash
# The capture of a build: what a recipe installs has to reach the package.
#
# build_package_install() stamps a marker and then runs ninstall();
# build_search_for_files() lists what find reports as newer than that marker.
# Three things have gone wrong around that, and all are silent -- the build
# carries on and either publishes a package that installs and brings nothing, or
# refuses to create one at all with "Nhopkg can't install any file from this
# package":
#
#   1. Stamping the marker *after* the install instead of before it. find
#      compares against the marker, and once the marker is the newest thing on
#      disk, nothing installed is newer than it. It hit the base package and
#      every split alike, because they all go through this function.
#
#   2. Comparing with -newer instead of -cnewer. cp -p, install -p, rsync -a
#      and tar -x all preserve the modification time, so -newer drops exactly
#      those files. -cnewer reads the inode change time, which the creation of
#      the file always moves forward, so it keeps them.
#
# A third has gone wrong in build_search_for_files() itself: it drops the
# NOUPGRADE_FILES and the paths that vanished since the search with an
# unanchored "sed -e \"s@^<path>@@\"". A captured path that is a prefix of
# another -- libdemo.so.0 against libdemo.so.0.15.0, which every libtool build
# tree holds -- is clipped into a relative fragment (".0.15.0") instead of
# removed, and the fragment reaches tar, which then refuses the archive. It only
# bites when the build tree sits under FIND_DIRS, which it does by default:
# NHOPKG_BUILDIR is /usr/src/nhopkg, under the /usr that FIND_DIRS scans.
#
# The client needs root, so the three functions are extracted from the generated
# tool and run verbatim in a sandbox: install, then build the binary package --
# which searches and packages by itself. What comes out is a whole .nho for the
# base package and a whole .nho for a split, which is the coverage
# tests/README.md says was missing.
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
# Taking the capture apart
# ---------------------------------------------------------------------------

# fn_body <file> <name>: the function, header and closing brace included,
# verbatim. None of the three bodies has a "}" of its own at column 0.
fn_body() { # <file> <name>
	awk -v fn="$2" '
		$0 == fn "()" { grab = 1 }
		grab { print }
		grab && /^}$/ { exit }
	' "$1"
}

INSTALL_FN="$(fn_body "${TOOL_SRC}" build_package_install)"
SEARCH_FN="$(fn_body "${TOOL_SRC}" build_search_for_files)"
MAKE_FN="$(fn_body "${TOOL_SRC}" build_make_binary_package)"
for var in INSTALL_FN SEARCH_FN MAKE_FN; do
	[[ -n "${!var}" ]] || die "${var} was not found in ${TOOL_SRC}. If a function
    moved or was renamed, update fn_body() here, otherwise nothing below is
    testing anything."
done

# ---------------------------------------------------------------------------
# The sandbox
# ---------------------------------------------------------------------------

# capture_run <part> [install] [search] [make]
#
# Runs the three functions the way the build does, against a find root under
# the sandbox. Results land in CAPTURE_SB (the sandbox) and CAPTURE_RC.
#
# The fixture recipe writes into that root the way a real recipe writes into
# /usr: one file with a fresh timestamp, one copied with -p (old mtime, new
# ctime) -- the file -newer loses and -cnewer keeps.
CAPTURE_SB=''
CAPTURE_RC=0
# Two knobs for the prefix-clipping case, off for every other run:
#   CAPTURE_BUILD_IN_ROOT   the build tree sits under the find root, the way
#                           NHOPKG_BUILDIR (/usr/src/nhopkg) sits under /usr
#   CAPTURE_NOUPGRADE_BUILD the build tree is listed in NOUPGRADE_FILES
CAPTURE_BUILD_IN_ROOT="${CAPTURE_BUILD_IN_ROOT:-no}"
CAPTURE_NOUPGRADE_BUILD="${CAPTURE_NOUPGRADE_BUILD:-no}"
capture_run() { # <part> [install] [search] [make]
	local part="$1"
	local install_fn="${2:-${INSTALL_FN}}"
	local search_fn="${3:-${SEARCH_FN}}"
	local make_fn="${4:-${MAKE_FN}}"

	CAPTURE_SB="$(mktemp -d "${WORK}/capture.XXXXXX")"
	mkdir -p "${CAPTURE_SB}/root" "${CAPTURE_SB}/src" \
		"${CAPTURE_SB}/tmp" "${CAPTURE_SB}/build" "${CAPTURE_SB}/out"

	export CAPTURE_BUILD_IN_ROOT CAPTURE_NOUPGRADE_BUILD

	# Sources for the copied files, with an old mtime. It is only their ctime
	# that is new once cp -p has copied them, which is exactly what -cnewer and
	# -newer disagree about. They sit outside the find root, so they are never
	# captured themselves.
	: > "${CAPTURE_SB}/src/old.conf"
	: > "${CAPTURE_SB}/src/old.so"
	touch -t 200001010000 "${CAPTURE_SB}/src/old.conf" "${CAPTURE_SB}/src/old.so"

	export CAPTURE_SB
	(
		cd "${CAPTURE_SB}" || exit 1
		# The extracted functions run as src/nhopkg.in runs it: the tool has
		# no "set -u", and the empty-argument path reads "$1".
		set +u

		pkgname=demo
		pkgversion=1.0
		pkgrevision=1
		NHOPKG_TMPDIR="${CAPTURE_SB}/tmp"
		NHOPKG_BUILDIR="${CAPTURE_SB}/build"
		FIND_DIRS="${CAPTURE_SB}/root"
		if [[ "${CAPTURE_BUILD_IN_ROOT}" = yes ]]; then
			# The build tree lives under the find root, so the search walks
			# it too. This is the real layout: FIND_DIRS scans /usr and
			# NHOPKG_BUILDIR is /usr/src/nhopkg.
			NHOPKG_BUILDIR="${CAPTURE_SB}/root/src/build"
			mkdir -p "${NHOPKG_BUILDIR}"
		fi
		NOUPGRADE_FILES=""
		if [[ "${CAPTURE_NOUPGRADE_BUILD}" = yes ]]; then
			NOUPGRADE_FILES="${NHOPKG_BUILDIR}"
		fi
		CWD="${CAPTURE_SB}/out"
		PACKAGE_OS=linux
		final_arch=x86_64
		DIROWNER="$(id -un)"
		VERBOSE_MODE=no
		STRIP_BINARIES=no
		NHOPKG_PACKAGING=no

		echog() { printf '%s\n' "$*"; }
		echogn() { printf '%s' "$*"; }
		# build_package_install() sleeps 3 seconds on purpose. Keep the
		# ordering between the marker and the installed files, drop the wait.
		sleep() { command sleep 0.02; }
		# Not what is under test: things a real build does around the capture.
		chown() { :; }
		crypto_sign_package() { :; }
		get_build_time() { BUILD_TIME=0; }
		build_nhoid_to_bin() {
			printf '#%%NHO-0.5\n# Name:\t%s\n' "${PKG_DISPLAY_NAME}" \
				> "${NHOPKG_TMPDIR}/nhoid"
		}
		get_package_display_name() {
			if [[ "$1" = "lib32" ]]; then
				PKG_DISPLAY_NAME="lib32-${pkgname}"
			else
				PKG_DISPLAY_NAME="${pkgname}${1:+-}${1}"
			fi
		}

		# The fixture. The "*-preserved" files are the ones copied with -p.
		ninstall() {
			mkdir -p "${CAPTURE_SB}/root/usr/bin" "${CAPTURE_SB}/root/etc"
			printf 'binary\n' > "${CAPTURE_SB}/root/usr/bin/demo"
			chmod 0755 "${CAPTURE_SB}/root/usr/bin/demo"
			cp -p "${CAPTURE_SB}/src/old.conf" "${CAPTURE_SB}/root/etc/demo-preserved.conf"
		}
		ninstall_lib32() {
			mkdir -p "${CAPTURE_SB}/root/usr/lib32"
			printf 'library\n' > "${CAPTURE_SB}/root/usr/lib32/libdemo.so"
			cp -p "${CAPTURE_SB}/src/old.so" "${CAPTURE_SB}/root/usr/lib32/libdemo-preserved.so"
			if [[ "${CAPTURE_BUILD_IN_ROOT}" = yes ]]; then
				# What a libtool build tree holds: soname links whose names
				# are prefixes of one another. Captured by the search, they
				# are dropped through NOUPGRADE_FILES, and dropping them must
				# not clip their longer neighbours.
				: > "${NHOPKG_BUILDIR}/libdemo.so"
				: > "${NHOPKG_BUILDIR}/libdemo.so.0"
				: > "${NHOPKG_BUILDIR}/libdemo.so.0.15.0"
			fi
		}

		eval "${install_fn}"
		eval "${search_fn}"
		eval "${make_fn}"

		build_package_install "${part}"
		build_make_binary_package "${part}"
	) > "${CAPTURE_SB}/run.log" 2>&1
	CAPTURE_RC=$?
	return 0
}

# The installed paths a .nho records, as data.tar.zst has them. The sandbox
# prefix comes off, so they read like the paths a recipe installs.
nho_members() { # <nho>
	tar xfO "$1" data.tar.zst 2>/dev/null | zstd -dc 2>/dev/null | tar tf - 2>/dev/null |
		sed -e 's#^/##' -e 's#^.*/root/##' | sort
}
nho_has_data() { # <nho>
	tar tf "$1" 2>/dev/null | grep -qx 'data.tar.zst'
}

# ---------------------------------------------------------------------------
# The base package
# ---------------------------------------------------------------------------

head1 "the base package: every installed file reaches the .nho"
capture_run ""
BASE_NHO="${CAPTURE_SB}/out/demo-1.0-1.linux-x86_64.nho"
assert_status 0 "${CAPTURE_RC}" "the build carries on"
assert_file "${BASE_NHO}" "a .nho is produced"
nho_has_data "${BASE_NHO}" && ok "it carries a data.tar.zst" || bad "no data.tar.zst in the .nho"
MEMBERS="$(nho_members "${BASE_NHO}")"
assert_in_list "${MEMBERS}" "usr/bin/demo" "the file written now is in it"
assert_in_list "${MEMBERS}" "etc/demo-preserved.conf" "so is the one copied with -p"
assert_eq "2" "$(wc -l <<<"${MEMBERS}" | tr -d ' ')" "and nothing else"

# ---------------------------------------------------------------------------
# A split package
# ---------------------------------------------------------------------------

head1 "a split part captures its own files, and only its own"
capture_run lib32
LIB_NHO="${CAPTURE_SB}/out/lib32-demo-1.0-1.linux-x86_64.nho"
assert_status 0 "${CAPTURE_RC}" "the build carries on"
assert_file "${LIB_NHO}" "a .nho is produced for the split"
nho_has_data "${LIB_NHO}" && ok "it carries a data.tar.zst" || bad "no data.tar.zst in the split"
MEMBERS="$(nho_members "${LIB_NHO}")"
assert_in_list "${MEMBERS}" "usr/lib32/libdemo.so" "the library written now is in it"
assert_in_list "${MEMBERS}" "usr/lib32/libdemo-preserved.so" "so is the one copied with -p"
assert_not_in_list "${MEMBERS}" "usr/bin/demo" "the base files are not in the split"
assert_eq "2" "$(wc -l <<<"${MEMBERS}" | tr -d ' ')" "and nothing else"

# ---------------------------------------------------------------------------
# A build tree under the find root
# ---------------------------------------------------------------------------

# The build tree sits under FIND_DIRS (NHOPKG_BUILDIR is /usr/src/nhopkg under
# the /usr that is scanned) and NOUPGRADE_FILES points at it. The search walks
# it, so it must be dropped cleanly: dropping with an unanchored sed clipped
# the longer names into fragments (".0.15.0") that tar then refused.
head1 "a build tree under the find root is filtered, not clipped"
CAPTURE_BUILD_IN_ROOT=yes
CAPTURE_NOUPGRADE_BUILD=yes
capture_run lib32
CAPTURE_BUILD_IN_ROOT=no
CAPTURE_NOUPGRADE_BUILD=no
FIND_NHO="${CAPTURE_SB}/out/lib32-demo-1.0-1.linux-x86_64.nho"
CAPTURE_LOG="${CAPTURE_SB}/tmp/.lib32-demo-1.0-1-installed.log"
assert_status 0 "${CAPTURE_RC}" "the build carries on"
assert_file "${FIND_NHO}" "a .nho is produced"
nho_has_data "${FIND_NHO}" && ok "it carries a data.tar.zst" || bad "no data.tar.zst"
MEMBERS="$(nho_members "${FIND_NHO}")"
assert_in_list "${MEMBERS}" "usr/lib32/libdemo.so" "the library is in it"
assert_in_list "${MEMBERS}" "usr/lib32/libdemo-preserved.so" "and the one copied with -p"
assert_eq "2" "$(wc -l <<<"${MEMBERS}" | tr -d ' ')" "and nothing else"
assert_eq "0" "$(grep -c 'build/libdemo' "${CAPTURE_LOG}" 2>/dev/null || true)" \
	"no build-tree file is left in the capture"
assert_eq "0" "$(grep -c '^\.' "${CAPTURE_LOG}" 2>/dev/null || true)" \
	"no clipped relative fragment is left in the capture"

# ---------------------------------------------------------------------------
# The invariants the two defects broke, stated on their own
# ---------------------------------------------------------------------------

head1 "the marker is stamped once, before the install"
assert_eq "1" "$(grep -c 'nho-preinstall' <<<"${INSTALL_FN}")" "the marker is stamped once"
MARKER_LINE="$(grep -n 'nho-preinstall' <<<"${INSTALL_FN}" | head -n1 | cut -d: -f1)"
INSTALL_LINE="$(grep -n 'ninstall' <<<"${INSTALL_FN}" | head -n1 | cut -d: -f1)"
[[ "${MARKER_LINE}" -lt "${INSTALL_LINE}" ]] &&
	ok "and before ninstall() runs ($MARKER_LINE < $INSTALL_LINE)" ||
	bad "the marker is not stamped before ninstall() ($MARKER_LINE vs $INSTALL_LINE)"

head1 "the search compares the inode change time"
assert_contains "${SEARCH_FN}" '-cnewer "$ref"' "the GNU find branch uses -cnewer"
assert_missing "${SEARCH_FN}" '-newer "$ref"' "and not -newer"
assert_contains "$(cat "${TOOL_SRC}")" 'stat -c %Z' "the BusyBox branch reads the change time (%Z)"
assert_missing "$(cat "${TOOL_SRC}")" 'stat -c %Y' "not the modification time (%Y)"

# ---------------------------------------------------------------------------
# The defects, reproduced
# ---------------------------------------------------------------------------

head1 "mutant: a marker stamped after the install loses everything"
MUT="${TOOLDIR}/nhopkg-mutant"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-preinstall-after-install
MUT_INSTALL="$(fn_body "${MUT}" build_package_install)"
[[ "${MUT_INSTALL}" == "${INSTALL_FN}" ]] &&
	bad "the mutant did not change the install step" ||
	ok "the mutant stamps the marker a second time, after the install"
capture_run "" "${MUT_INSTALL}"
assert_status 0 "${CAPTURE_RC}" "the build still reports success (this is the bug)"
assert_eq "0" "$(wc -l < "${CAPTURE_SB}/tmp/.demo-1.0-1-installed.log" 2>/dev/null | tr -d ' ')" \
	"not a single file was captured"
assert_contains "$(cat "${CAPTURE_SB}/run.log")" "can't install any file" \
	"and the build says so (this is the bug)"
assert_no_file "${CAPTURE_SB}/out/demo-1.0-1.linux-x86_64.nho" \
	"and no .nho is produced (this is the bug)"

head1 "mutant: -newer instead of -cnewer drops the preserved files"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-newer-not-cnewer
MUT_SEARCH="$(fn_body "${MUT}" build_search_for_files)"
[[ "${MUT_SEARCH}" == "${SEARCH_FN}" ]] &&
	bad "the mutant did not change the search" ||
	ok "the mutant compares the modification time instead"
capture_run "" "${INSTALL_FN}" "${MUT_SEARCH}"
assert_status 0 "${CAPTURE_RC}" "the build carries on"
MEMBERS="$(nho_members "${CAPTURE_SB}/out/demo-1.0-1.linux-x86_64.nho")"
assert_in_list "${MEMBERS}" "usr/bin/demo" "the file with a fresh mtime survives"
assert_not_in_list "${MEMBERS}" "etc/demo-preserved.conf" \
	"the file copied with -p is silently lost (this is the bug)"

head1 "mutant: clipping prefix-sharing paths loses the whole package"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-prefix-clip
MUT_SEARCH="$(fn_body "${MUT}" build_search_for_files)"
[[ "${MUT_SEARCH}" == "${SEARCH_FN}" ]] &&
	bad "the mutant did not change the search" ||
	ok "the mutant uses unanchored sed to strip paths again"
CAPTURE_BUILD_IN_ROOT=yes
CAPTURE_NOUPGRADE_BUILD=yes
capture_run lib32 "${INSTALL_FN}" "${MUT_SEARCH}"
CAPTURE_BUILD_IN_ROOT=no
CAPTURE_NOUPGRADE_BUILD=no
assert_no_file "${CAPTURE_SB}/out/lib32-demo-1.0-1.linux-x86_64.nho" "no .nho is produced (this is the bug)"
assert_contains "$(cat "${CAPTURE_SB}/run.log")" "Unable to compress" "and the build says so (this is the bug)"

exit "$(t_summary)"
