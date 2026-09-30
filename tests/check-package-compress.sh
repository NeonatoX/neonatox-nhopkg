#!/bin/bash
# The packaging step of a build: the installed file list has to become
# data.tar.zst.
#
# "tar -C dir cp --files-from=list" looks right and is not. The "cp" is GNU
# tar's old-style bundling of -c and -p, and it is only parsed when the first
# argument is not an option. With -C in front, both GNU tar and BusyBox tar
# read the line as "no operation letter", write nothing and exit non-zero.
# The error was sent to /dev/null and the status that the pipeline returned is
# zstd's, not tar's, so the build carried on and published a data.tar.zst that
# was a valid, completely empty archive: a package that installs and brings
# nothing.
#
# The client itself needs root, so the code is not run as a program here.
# Instead the step is extracted from the generated tool and run verbatim in a
# sandbox, against the same file list the build writes, so the test fails if
# the invocation in src/nhopkg.in changes shape.
#
#   See "What is not covered" in tests/README.md.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
[[ -f "${TOOL_SRC}" ]] || die "not found: ${TOOL_SRC} (run meson setup first)"

# ---------------------------------------------------------------------------
# Taking the step apart
# ---------------------------------------------------------------------------

# The tar|zstd command, both branches, with the variable declarations it needs.
# Stopped at the "fi" that closes the packaging/live choice.
compress_step() { # <file>
	awk '
		/local _pkg_file_list=/ { grab = 1 }
		grab {
			print
			if (/^\t\tfi$/) exit
		}
	' "$1"
}

# The status check that follows it. Empty when the source does not have one,
# which is what the pre-compress-guard mutant is for.
compress_guard() { # <file>
	awk '
		/^\t\t_tar_status=/ { grab = 1 }
		grab {
			print
			if (/^\t\tfi$/) exit
		}
	' "$1"
}

# ---------------------------------------------------------------------------
# Running it
# ---------------------------------------------------------------------------

# compress_run <step> <guard> <packaging yes|no> <tar command line>
#
# The step is plain shell that only reads the variables set below, so it can be
# run as it runs inside build_make_binary_package(). Results land in
# COMPRESS_SB (the sandbox) and COMPRESS_RC.
#
# This is a function call and not a command substitution on purpose: the
# subshell of "$(...)" would swallow the exit status, which is half of what is
# being tested.
COMPRESS_SB=''
COMPRESS_RC=0
compress_run() {
	local step="$1" guard="$2" packaging="$3" tarlib="$4"
	local log shim
	COMPRESS_SB="$(mktemp -d "${WORK}/compress.XXXXXX")"
	mkdir -p "${COMPRESS_SB}/destdir/usr/bin" "${COMPRESS_SB}/tmpdir" "${COMPRESS_SB}/bin"
	printf '#!/bin/sh\nexit 0\n' > "${COMPRESS_SB}/destdir/usr/bin/prog"
	chmod 0755 "${COMPRESS_SB}/destdir/usr/bin/prog"
	ln "${COMPRESS_SB}/destdir/usr/bin/prog" "${COMPRESS_SB}/destdir/usr/bin/alias"

	log="${COMPRESS_SB}/tmpdir/.demo-1.0-1-installed.log"
	if [[ "${packaging}" == "yes" ]]; then
		# a packaging build records the paths as the staging dir sees them
		printf 'usr/bin/prog\nusr/bin/alias\n' > "${log}"
	else
		# a live install records absolute paths
		printf '%s\n' "${COMPRESS_SB}/destdir/usr/bin/prog" \
		    "${COMPRESS_SB}/destdir/usr/bin/alias" > "${log}"
	fi

	# tar is resolved through PATH, the way the build resolves it, and through
	# a shim because a multi-call binary needs its applet name as an argument.
	shim="${COMPRESS_SB}/bin"
	printf '#!/bin/sh\nexec %s "$@"\n' "${tarlib}" > "${shim}/tar"
	chmod +x "${shim}/tar"

	(
		cd "${COMPRESS_SB}" || exit 1
		PATH="${shim}:${PATH}"
		NHOPKG_TMPDIR="${COMPRESS_SB}/tmpdir"
		NHOPACKAGING="${COMPRESS_SB}/destdir"
		NHOPKG_PACKAGING="${packaging}"
		PKG_DISPLAY_NAME=demo
		pkgversion=1.0
		pkgrevision=1
		echog() { :; }
		cleanup_tmp_dir() { :; }
		# The step and the guard go into a single eval on purpose: the guard
		# reads ${PIPESTATUS[0]}, which is overwritten by every command, so
		# running them as two evals would throw the status away.
		_run() {
			eval "${step}
${guard}"
			return 0
		}
		_run
	)
	COMPRESS_RC=$?
	return 0
}

DATA_NAME=data.tar.zst
members() { # <data.tar.zst>
	zstd -dc "$1" 2>/dev/null | tar tf - 2>/dev/null | sed -e 's#^\./##' | sort | tr '\n' ' ' | sed -e 's/ $//'
}
data_size() { # <data.tar.zst> : uncompressed size, 0 when it holds nothing
	zstd -dc "$1" 2>/dev/null | wc -c | tr -d ' '
}
long_mode() { # <data.tar.zst> <member>
	zstd -dc "$1" 2>/dev/null | tar tvf - 2>/dev/null | awk -v m="$2" '$NF == m { print $1; exit }'
}
check_hardlink() { # <data.tar.zst>
	local out="${WORK}/extract.$$"
	rm -rf "${out}" && mkdir -p "${out}"
	zstd -dc "$1" 2>/dev/null | tar xf - -C "${out}" 2>/dev/null
	[[ -e "${out}/usr/bin/alias" ]] && [[ "${out}/usr/bin/alias" -ef "${out}/usr/bin/prog" ]]
}

# ---------------------------------------------------------------------------
# The step as it is written now
# ---------------------------------------------------------------------------

STEP="$(compress_step "${TOOL_SRC}")"
GUARD="$(compress_guard "${TOOL_SRC}")"
[[ -n "${STEP}" ]] || die "the packaging step was not found in ${TOOL_SRC}. If it moved,
    update compress_step() here, otherwise nothing below is testing anything."

head1 "packaging build (--packaging): the file list is relative to DESTDIR"
compress_run "${STEP}" "${GUARD}" yes "/usr/bin/tar"
DATA="${COMPRESS_SB}/tmpdir/${DATA_NAME}"
assert_status 0 "${COMPRESS_RC}" "the build carries on"
assert_file "${DATA}" "data.tar.zst is written"
assert_eq "1" "$([[ -s "${DATA}" ]] && echo 1 || echo 0)" "data.tar.zst is not empty"
assert_eq "usr/bin/alias usr/bin/prog" "$(members "${DATA}")" "both files are in the archive"
assert_eq "-rwxr-xr-x" "$(long_mode "${DATA}" usr/bin/prog)" "the mode survives (-p)"
check_hardlink "${DATA}" && ok "the hardlinked file survives" || bad "the hardlink was lost"

head1 "live install: the file list is absolute and there is no -C"
compress_run "${STEP}" "${GUARD}" no "/usr/bin/tar"
DATA="${COMPRESS_SB}/tmpdir/${DATA_NAME}"
assert_status 0 "${COMPRESS_RC}" "the build carries on"
# tar drops the leading "/", so what lands in the archive is the absolute path
# without it. Only the last two components are compared, and the leading "/"
# is checked separately.
assert_eq "usr/bin/alias usr/bin/prog" \
	"$(members "${DATA}" | tr ' ' '\n' | awk -F/ '{ print $(NF - 2) "/" $(NF - 1) "/" $NF }' | sort | tr '\n' ' ' | sed -e 's/ $//')" \
	"both files are in the archive"
assert_eq "0" "$(grep -c '^/' <<<"$(members "${DATA}")")" "no member keeps the leading /"

BB="${BUILDDIR}/.nhopkg-tools/busybox"
if [[ -x "${BB}" ]]; then
	head1 "same step, with tar resolved to the private BusyBox applet"
	compress_run "${STEP}" "${GUARD}" yes "${BB} tar"
	DATA="${COMPRESS_SB}/tmpdir/${DATA_NAME}"
	assert_status 0 "${COMPRESS_RC}" "BusyBox tar is accepted too"
	assert_eq "usr/bin/alias usr/bin/prog" "$(members "${DATA}")" "same members as GNU tar"
	check_hardlink "${DATA}" && ok "the hardlink survives BusyBox tar as well" || bad "the hardlink was lost"
else
	note "no BusyBox at ${BB}, skipping the applet run"
fi

# ---------------------------------------------------------------------------
# The defect, and the guard that now stops it
# ---------------------------------------------------------------------------

head1 "mutants"
MUT="${TOOLDIR}/nhopkg-mutant"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-explicit-tar-opts
MUT_STEP="$(compress_step "${MUT}")"
MUT_GUARD="$(compress_guard "${MUT}")"
[[ "${MUT_STEP}" == "${STEP}" ]] && bad "the mutant did not change the step" ||
	ok "the mutant puts the old-style bundling back"

# With the guard, the same mistake stops the build instead of shipping.
compress_run "${MUT_STEP}" "${MUT_GUARD}" yes "/usr/bin/tar"
assert_status 1 "${COMPRESS_RC}" "the guard aborts the build"
assert_no_file "${COMPRESS_SB}/tmpdir/${DATA_NAME}" "no empty data.tar.zst is left behind"

# Both changes reverted, which is how it was: exit 0 and an empty archive.
# Stated as a test, so the shape of the original defect stays written down.
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-explicit-tar-opts
apply_mutant_to "${MUT}" pre-compress-guard
MUT_STEP="$(compress_step "${MUT}")"
[[ -n "$(compress_guard "${MUT}")" ]] && bad "the mutant did not remove the guard" ||
	ok "the mutant removes the guard as well"
compress_run "${MUT_STEP}" "" yes "/usr/bin/tar"
DATA="${COMPRESS_SB}/tmpdir/${DATA_NAME}"
assert_status 0 "${COMPRESS_RC}" "pre-fix, the build reported success (this is the bug)"
assert_file "${DATA}" "pre-fix, a data.tar.zst was still written"
assert_eq "0" "$(data_size "${DATA}")" "pre-fix, and it was empty (this is the bug)"

# ---------------------------------------------------------------------------
# The two things that must not come back
# ---------------------------------------------------------------------------

head1 "the generated tool itself"
assert_missing "$(cat "${TOOL_SRC}")" 'tar -C "${NHOPACKAGING}" cp ' "no old-style bundling after -C"
assert_missing "$(cat "${TOOL_SRC}")" 'tar cp --files-from' "no old-style bundling in the live branch"
assert_contains "$(cat "${TOOL_SRC}")" 'PIPESTATUS[0]' "tar's own exit status is still read"
assert_contains "$(cat "${TOOL_SRC}")" '! -s "${_pkg_data}"' "an empty archive is still refused"

exit "$(t_summary)"
