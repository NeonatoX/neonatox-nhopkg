#!/bin/bash
# The lock directory has to be creatable where /var/lock is a dangling symlink.
#
# /var/lock is usually a symlink to /run/lock. On a running system /run is a
# tmpfs mount, so /run/lock exists or mkdir -p can create it. Inside a chroot
# /run is often not mounted at all, so /var/lock points at a directory that does
# not exist: mkdir -p does not create the parents of a symlink target, it fails
# with "No such file or directory", and nhopkg refused to start.
#
# check_if_running() now resolves the symlink and creates the target. The
# function needs no root, so it is extracted from the generated tool and run in
# a sandbox. See "What is not covered" in tests/README.md.

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}" "${LOGS}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
[[ -f "${TOOL_SRC}" ]] || die "not found: ${TOOL_SRC} (run meson setup first)"

# The function, from its header to the closing brace at column 0.
lock_fn() { # <file>
	awk '/^check_if_running\(\)$/ { grab = 1 } grab { print; if (/^}$/) exit }' "$1"
}

LOCK_TOOL="${TOOL_SRC}"

# run_lock <lockfile> <logname>
# Runs the extracted function in a subshell, the way the tool runs it, and
# returns its status. The lock file and the sandbox are left behind for the
# assertions to inspect.
run_lock() { # <lockfile> <logname>
	local lockfile="$1" logname="$2" fn
	fn="$(lock_fn "${LOCK_TOOL}")"
	[[ -n "${fn}" ]] ||
		die "check_if_running() not found in ${LOCK_TOOL}; update lock_fn()"
	(
		NHOPKG_LOCKFILE="${lockfile}"
		NHOPKG_LOCK_WAIT=1
		OLDPID=""
		echog() { printf ' * %s\n' "$*" >&2; }
		eval "${fn}"
		check_if_running
	) >"${LOGS}/lock-${logname}.log" 2>&1
}

# ---------------------------------------------------------------------------
# The chroot case: /var/lock -> /run/lock and /run does not exist
# ---------------------------------------------------------------------------

# Absolute target. It points inside the sandbox, not at the host's /run, so the
# run is safe; the branch that resolves an absolute link is the one taken.
SB="${WORK}/lock-abs"
mkdir -p "${SB}/root/var"
ln -s "${SB}/root/run/lock" "${SB}/root/var/lock"
run_lock "${SB}/root/var/lock/nhopkg" "abs"
assert_status 0 "$?" "an absolute dangling /var/lock no longer aborts the start"
assert_file "${SB}/root/run/lock/nhopkg" "the symlink target directory is created, and the lock with it"
assert_eq "$$" "$(cat "${SB}/root/run/lock/nhopkg" 2>/dev/null)" "the lock file holds the PID"

# Relative target, as some layouts ship it (../run/lock).
SB="${WORK}/lock-rel"
mkdir -p "${SB}/root/var"
ln -s "../run/lock" "${SB}/root/var/lock"
run_lock "${SB}/root/var/lock/nhopkg" "rel"
assert_status 0 "$?" "a relative dangling /var/lock is resolved too"
assert_file "${SB}/root/run/lock/nhopkg" "the relative target is created"

# ---------------------------------------------------------------------------
# What already worked, and must keep working
# ---------------------------------------------------------------------------

# Target already exists: the normal case on a booted system.
SB="${WORK}/lock-existing"
mkdir -p "${SB}/root/var" "${SB}/root/run/lock"
ln -s "../run/lock" "${SB}/root/var/lock"
run_lock "${SB}/root/var/lock/nhopkg" "existing"
assert_status 0 "$?" "a symlink to an existing directory still works"
assert_file "${SB}/root/run/lock/nhopkg" "the lock lands in the target"

# No symlink at all.
SB="${WORK}/lock-plain"
mkdir -p "${SB}/var/lock"
run_lock "${SB}/var/lock/nhopkg" "plain"
assert_status 0 "$?" "a plain lock directory still works"
assert_file "${SB}/var/lock/nhopkg" "the lock lands in the plain directory"

# A path that cannot be created must still fail loudly, not be ignored.
SB="${WORK}/lock-broken"
mkdir -p "${SB}"
: > "${SB}/notadir"
run_lock "${SB}/notadir/lock/nhopkg" "broken"
assert_status 1 "$?" "an impossible lock directory still aborts"
assert_contains "$(cat "${LOGS}/lock-broken.log")" "Cannot create lock directory" \
	"and the reason is reported"

# ---------------------------------------------------------------------------
# Reverting the fix reproduces the original failure
# ---------------------------------------------------------------------------

MUT_TOOL="${TOOLDIR}/nhopkg-lock-mutant"
cp "${TOOL_SRC}" "${MUT_TOOL}"
apply_mutant_to "${MUT_TOOL}" "pre-dangling-lock"
LOCK_TOOL="${MUT_TOOL}"

SB="${WORK}/lock-mutant"
mkdir -p "${SB}/root/var"
ln -s "${SB}/root/run/lock" "${SB}/root/var/lock"
run_lock "${SB}/root/var/lock/nhopkg" "mutant"
assert_status 1 "$?" "the mutant (plain mkdir -p) aborts on a dangling symlink"
assert_no_file "${SB}/root/run/lock/nhopkg" "and leaves no lock behind"

exit "$(t_summary)"
