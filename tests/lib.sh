#!/bin/bash
# Shared harness for the nhopkg test suite.
#
# The tests exercise the REAL generated tools from the build directory, with
# two things stubbed out because they are not what is under test:
#
#   - the root check, which would otherwise make every test need sudo;
#   - GPG, through a stub library that never has a key, so signing is a no-op
#     and signature verification always succeeds.
#
# Source it from a test and call setup_tool before running anything.
#
#   . "$(dirname "$0")/lib.sh"
#   ensure_build
#   setup_tool clean
#
# Environment:
#   NHOPKG_BUILDDIR     build directory      (default: <source>/builddir)
#   NHOPKG_TEST_TMPDIR  scratch space        (default: <builddir>/tests-tmp)
#   NHOPKG_TEST_NO_BUILD=1  do not touch the build, use it as it is

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
BUILDDIR="${NHOPKG_BUILDDIR:-${SRC_ROOT}/builddir}"
WORK="${NHOPKG_TEST_TMPDIR:-${BUILDDIR}/tests-tmp}"
PKGDIR="${WORK}/packages"
HOSTILE_PKGDIR="${WORK}/hostile"
TOOLDIR="${WORK}/bin"
REPOS="${WORK}/repos"
LOGS="${WORK}/logs"

# The suite checks exit statuses on purpose, so -e is deliberately not set.
# Assertions report and count instead of aborting, so one failure does not
# hide the rest of the run.
set -uo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

note() { printf '  ..   %s\n' "$*"; }
head1() { printf '\n== %s ==\n' "$*"; }

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

# meson generates the scripts with configure_file(), which runs at CONFIGURE
# time. "ninja" alone therefore does not pick up an edit to a .in file, and a
# test run against a stale binary reports a fix as if it did not work. That
# happened while writing this suite, so the staleness is checked here instead
# of being left to whoever runs the tests.
ensure_build() {
	[[ -d "${BUILDDIR}" ]] || die "no build directory at ${BUILDDIR}. Create it with:
    meson setup ${BUILDDIR} --prefix=/usr --sysconfdir=/etc -D binlocate=plocate"
	[[ "${NHOPKG_TEST_NO_BUILD:-0}" == "1" ]] && return 0

	command -v meson >/dev/null 2>&1 || die "meson not found in PATH"
	command -v ninja >/dev/null 2>&1 || die "ninja not found in PATH"

	local stale=0 src out
	for src in "${SRC_ROOT}"/src/*.in; do
		out="${BUILDDIR}/src/$(basename "${src}" .in)"
		if [[ ! -f "${out}" ]]; then
			stale=1
		elif [[ "${src}" -nt "${out}" ]]; then
			stale=1
		fi
	done
	if [[ ${stale} -eq 1 ]]; then
		note "sources are newer than the build, reconfiguring"
		meson setup "${BUILDDIR}" --reconfigure >/dev/null || die "meson setup failed"
	fi
	ninja -C "${BUILDDIR}" >/dev/null || die "ninja failed"
	# A source that was touched without changing its content leaves the output
	# older forever, because ninja rewrites nothing when the content already
	# matches, and the next run would reconfigure again every time. The build
	# has just confirmed the output corresponds to the source, so the
	# timestamps are aligned here to let the check converge.
	for src in "${SRC_ROOT}"/src/*.in; do
		out="${BUILDDIR}/src/$(basename "${src}" .in)"
		[[ -f "${out}" ]] && [[ "${src}" -nt "${out}" ]] && touch "${out}"
	done
	return 0
}

# ---------------------------------------------------------------------------
# Tools under test
# ---------------------------------------------------------------------------

write_crypto_stub() {
	mkdir -p "${TOOLDIR}"
	cat > "${TOOLDIR}/crypto_stub" <<'STUB'
crypto_init_keyring() { return 0; }
crypto_sign_package_ext() { return 1; }
crypto_sign_repo_metadata() { return 0; }
crypto_verify_incoming() { return 0; }
crypto_verify_signature() { return 0; }
STUB
}

# Copy the generated nhopkg-repos and turn the two root gates into no-ops.
# The sed patterns are literal lines of the source: if the source moves, this
# silently stops neutralising anything and the tests would fail for the wrong
# reason, so the substitution is verified.
neuter_root_check() {
	local src="${BUILDDIR}/src/nhopkg-repos"
	local dst="${TOOLDIR}/nhopkg-repos"
	[[ -f "${src}" ]] || die "not found: ${src}"
	sed -e 's#^\tcheck_if_root_uid$#\ttrue#' \
	    -e 's#^\t\[\[ "${UID}" != "0" \]\] \&\& { echo " \* Root privileges required." >\&2; exit 1; }$#\ttrue#' \
	    "${src}" > "${dst}" || die "could not generate ${dst}"
	grep -qxF "$(printf '\ttrue')" "${dst}" ||
		die "the root check in ${src} no longer matches the pattern in tests/lib.sh.
    The two gates it replaces have to be found again and this sed updated,
    otherwise every test below would fail asking for root."
	chmod +x "${dst}"
}

# Mutants let a test reproduce a defect that is already fixed, to prove the
# test would catch it. Each one edits the generated tool in place, so the
# markers are the exact lines of src/nhopkg-repos.in.
#
#   pre-fase1   restore the "name-*" purge globs, which unindexed every
#               package whose name merely started with the one being added
#   pre-fase2a  stop purging the index metadata of a retired version, leaving
#               the entry of a .nho that is no longer on disk
apply_mutant() {
	local mutant="$1" tool="${TOOLDIR}/nhopkg-repos"
	[[ -f "${tool}" ]] || die "call setup_tool's neuter step first"
	python3 - "${tool}" "${mutant}" <<'PY'
import io, sys

path, mutant = sys.argv[1], sys.argv[2]
s = io.open(path, encoding="utf-8").read()

MUTANTS = {
    "pre-fase1": [
        ('\t\t\trm -f "$tmpbuild/$full" "$tmpbuild/$pkgname-$pkgversion" \\\n'
         '\t\t\t\t"$tmpbuild/$pkgname"',
         '\t\t\trm -f "$tmpbuild/$pkgname"-* "$tmpbuild/$pkgname"'),
        ('\t\t\trm -f "$tmpfiles/$(basename "$newfile")"',
         '\t\t\tname=$(basename "$newfile")\n'
         '\t\t\tpkgbase=$(echo "$name" | sed \'s/-[^-]*-[^-]*$//\')\n'
         '\t\t\trm -f "$tmpfiles/$pkgbase"-*'),
    ],
    "pre-fase2a": [
        ('>> "$NHOPKG_TMPDIR/$repo/retired"',
         '> /dev/null  # mutant: retirement leaves the metadata behind'),
    ],
}

for marker in MUTANTS.get(mutant, []):
    old, new = marker
    if old not in s:
        sys.exit("the marker for the '%s' mutant is no longer in src/nhopkg-repos.in:\n"
                 "  %r\n"
                 "Update tests/lib.sh, or the test below is not testing what it claims." % (mutant, old))
    s = s.replace(old, new)

io.open(path, "w", encoding="utf-8").write(s)
PY
	[[ $? -eq 0 ]] || die "could not apply the '${mutant}' mutant (see above)"
	note "applied the '${mutant}' mutant: this run reproduces a fixed defect on purpose"
}

# setup_tool [mutant]
# Only the tools are rebuilt here. The packages and the repositories a test
# has already produced stay put, so a later section can inspect what an
# earlier one left behind. Use clean_workspace for a blank slate.
setup_tool() {
	local mutant="${1:-clean}"
	rm -rf "${TOOLDIR}"
	mkdir -p "${TOOLDIR}" "${REPOS}" "${LOGS}"
	write_crypto_stub
	neuter_root_check
	case "${mutant}" in
		clean) : ;;
		*) apply_mutant "${mutant}" ;;
	esac
	# Point the tools at the build instead of at an installed copy. The
	# libraries are loaded from these, not from $prefix.
	export NHOPKG_CONF=/etc/nhopkg/nhopkg.conf
	export NHOPKG_LIB="${BUILDDIR}/src/libnhopkg"
	export NHOPKG_CRYPTO_LIB="${TOOLDIR}/crypto_stub"
}

clean_workspace() { rm -rf "${WORK}"; mkdir -p "${WORK}"; }

# add-to-repo refuses to create the repository directory, so a test that wants
# one creates it and then says what goes in it.
repos_add() { # repos_add <repo-dir> <package>...
	local repo="$1"; shift
	mkdir -p "${repo}"
	( cd "${PKGDIR}" && "${TOOLDIR}/nhopkg-repos" -o "${repo}" -A "$@" )
}

# ---------------------------------------------------------------------------
# Reading a repository
# ---------------------------------------------------------------------------

# Canonical identity of a .nho, from its own nhoid. Never parsed from the
# file name: names and versions contain dashes, and the file name carries the
# repository version rather than the release.
nho_id() {
	tar xfO "$1" nhoid 2>/dev/null | awk -F'\t' \
		'/^# Name:/{n=$2} /^# Version:/{v=$2} /^# Release:/{r=$2} END{print n"-"v"-"r}'
}

# Every id in a repository directory, as read from the packages on disk.
ids_on_disk() {
	local f out=""
	for f in "$1"/*.nho; do
		[[ -f "${f}" ]] || continue
		out="${out} $(nho_id "${f}")"
	done
	printf '%s\n' ${out}
}

# Regular entries of an index, aliases excluded. Plain "tar tf" does not say
# which entries are symlinks, so the long listing is used and the mode decides.
index_entries() {
	zstd -dc "$1" 2>/dev/null | tar tvf - 2>/dev/null |
		awk '$1 !~ /^l/ { n=$NF; sub(/^\.\//, "", n); print n }' |
		grep -v '^$' | sort -u
}

# Every entry of an index, aliases included. For a symlink the last field of
# the long listing is the target, not the name, so the " -> target" tail has to
# come off before reading it.
index_all_entries() {
	zstd -dc "$1" 2>/dev/null | tar tvf - 2>/dev/null |
		sed -e 's/ -> .*$//' |
		awk '{ n=$NF; sub(/^\.\//, "", n); print n }' |
		grep -v '^$' | sort -u
}

packages_index() { index_entries "$1/core.packages.tar.zst"; }
files_index()    { index_entries "$1/core.files.tar.zst"; }

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

T_PASS=0
T_FAIL=0

ok()  { T_PASS=$((T_PASS + 1)); printf '  ok    %s\n' "$*"; }
bad() { T_FAIL=$((T_FAIL + 1)); printf '  FAIL  %s\n' "$*"; }

assert_eq() { # <expected> <got> <label>
	[[ "$1" == "$2" ]] && ok "$3" || bad "$3 (expected '$1', got '$2')"
}

assert_status() { # <expected> <got> <label>
	assert_eq "$1" "$2" "$3"
}

assert_contains() { # <haystack> <needle> <label>
	grep -qF -- "$2" <<<"$1" && ok "$3" || bad "$3 (not found: '$2')"
}

assert_missing() { # <haystack> <needle> <label>
	grep -qF -- "$2" <<<"$1" && bad "$3 (unexpectedly present: '$2')" || ok "$3"
}

assert_in_list() { # <list> <item> <label>
	grep -qxF -- "$2" <<<"$1" && ok "$3" || bad "$3 ('$2' not in the list)"
}

assert_not_in_list() { # <list> <item> <label>
	grep -qxF -- "$2" <<<"$1" && bad "$3 ('$2' is in the list)" || ok "$3"
}

assert_file()    { [[ -f "$1" ]] && ok "$2" || bad "$2 (missing file: $1)"; }
assert_no_file() { [[ -e "$1" ]] && bad "$2 (still there: $1)" || ok "$2"; }

# Print the counts to stderr and return the number of failures, so a test can
# end with "exit $(t_summary)" without the report ending up in the exit status.
t_summary() {
	printf '\n  %d passed, %d failed\n' "${T_PASS}" "${T_FAIL}" >&2
	printf '%d' "${T_FAIL}"
}
