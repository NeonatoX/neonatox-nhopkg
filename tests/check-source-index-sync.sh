#!/bin/bash
# source-index: Etapa 3 (client sync).
#
# Drives the real generated `nhopkg -U` against a local HTTP server that serves
# a binary repository and a source index produced by the real generator. Root
# is stubbed out through a patched copy of libnhopkg; everything else is the
# generated code.
#
# What it proves:
#   - with no NHOPKG_SOURCES_REPO, -U does exactly what it did before;
#   - with the variable set, -U downloads, verifies and installs the index;
#   - a second run does not download the index again;
#   - a bad signature is detected and does not break the binary update.
#
# Usage: check-source-index-sync.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
setup_tool clean

FIXTURES="${TESTS_DIR}/fixtures/source-index"
GENERATOR="${SRC_ROOT}/scripts/nhopkg-source-index.sh"
REPO_ROOT="${WORK}/http"
CONF="${WORK}/nhopkg.conf"
SERVER_PID=""

# The generated nhopkg loads libnhopkg from NHOPKG_LIB. Appending an override
# keeps the real library but avoids needing root for this test.
ROOTLESS_LIB="${TOOLDIR}/libnhopkg-rootless"
cp "${BUILDDIR}/src/libnhopkg" "${ROOTLESS_LIB}" || die "cannot copy libnhopkg"
printf '\ncheck_if_root_uid() { return 0; }\n' >> "${ROOTLESS_LIB}"
export NHOPKG_LIB="${ROOTLESS_LIB}"

write_config() { # <state dir> <sources url> <verify> <require>
	local state="$1" sources="$2" verify="$3" require="$4"
	mkdir -p "${state}" "${WORK}/lock" "${WORK}/keyring"
	: > "${WORK}/keyring/pubring.kbx"
	cp "${BUILDDIR}/src/nhopkg.conf" "${CONF}" || die "cannot copy the config"
	cat >> "${CONF}" <<EOF

# --- test overrides ---
NHOPKG_LOCALSTATEDIR="${state}"
NHOPKG_LOCKFILE="${WORK}/lock/nhopkg"
NHOPKG_ACTIVE_REPOS="core"
NHOPKG_REPO_CORE="${SERVER_BASE}/binary"
NHOPKG_REPO_EXTRA=""
NHOPKG_REPO_MULTILIB=""
NHOPKG_SOURCES_REPO="${sources}"
NHOPKG_VERIFY_REPO_METADATA="${verify}"
NHOPKG_REQUIRE_SIGNED_METADATA="${require}"
NHOPKG_TRUSTED_KEYS_DIR="${WORK}/keyring"
NHOGET_BACKEND="curl"
EOF
}

stop_server() {
	[[ -n "${SERVER_PID}" ]] || return 0
	kill "${SERVER_PID}" 2>/dev/null || true
	wait "${SERVER_PID}" 2>/dev/null || true
	SERVER_PID=""
}
trap 'stop_server' EXIT

start_server() { # <log file>
	local log="$1" i
	SERVER_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')" ||
		{ bad "cannot allocate a port for the repo server"; return 1; }
	SERVER_BASE="http://127.0.0.1:${SERVER_PORT}"
	: > "${log}"
	FAKE_REPO_ROOT="${REPO_ROOT}" FAKE_REPO_PORT="${SERVER_PORT}" FAKE_REPO_LOG="${log}" \
		python3 "${FIXTURES}/repo-server.py" > "${LOGS}/repo-server.out" 2>&1 &
	SERVER_PID=$!
	for i in $(seq 1 50); do
		python3 -c "import socket,sys;s=socket.socket();s.settimeout(0.2);sys.exit(0 if s.connect_ex(('127.0.0.1',${SERVER_PORT}))==0 else 1)" &&
			return 0
		sleep 0.1
	done
	bad "the repo server did not start"
	return 1
}

run_update() { # <log file>
	local log="$1"
	NHOPKG_CONF="${CONF}" bash "${BUILDDIR}/src/nhopkg" -U > "${log}" 2>&1
	rc=$?
	cat "${log}"
	return "${rc}"
}

# ---------------------------------------------------------------------------
# Build the two repositories the client will see.
# ---------------------------------------------------------------------------
mkdir -p "${REPO_ROOT}/binary" "${REPO_ROOT}/sources" "${WORK}/tarsrc"
printf '100\n' > "${REPO_ROOT}/binary/lastsync"
printf 'binary package database\n' > "${WORK}/tarsrc/pkgs"
printf 'binary file database\n' > "${WORK}/tarsrc/files"
( cd "${WORK}/tarsrc" && tar cf - pkgs ) | zstd -q -c > "${REPO_ROOT}/binary/core.packages.tar.zst"
( cd "${WORK}/tarsrc" && tar cf - files ) | zstd -q -c > "${REPO_ROOT}/binary/core.files.tar.zst"

GEN_OUT="${WORK}/generator-out"
out=$(SOURCE_INDEX_TIMESTAMP=200 "${GENERATOR}" \
	--fixture "${FIXTURES}" --output "${GEN_OUT}" \
	--nhopkg-src "${BUILDDIR}/src/nhopkg-src" --no-sign 2>&1)
assert_status 0 "$?" "the real generator produced the fixture index"
for file in core.sources.tar.zst content.source.db.zst lastsync report.txt; do
	cp "${GEN_OUT}/${file}" "${REPO_ROOT}/sources/${file}" || die "cannot stage ${file}"
done

# ---------------------------------------------------------------------------
head1 "Etapa 3: without NHOPKG_SOURCES_REPO nothing changes"
# ---------------------------------------------------------------------------

LOG1="${LOGS}/repo-no-sources.log"
start_server "${LOG1}"
STATE1="${WORK}/state-no-sources"
write_config "${STATE1}" "" "no" "no"

out=$(run_update "${LOGS}/nhopkg-u-no-sources.log")
rc=$?
assert_status 0 "${rc}" "nhopkg -U exits 0"
assert_file "${STATE1}/repo/core/lastsync" "the binary repository was synced"
assert_eq "100" "$(cat "${STATE1}/repo/core/lastsync")" "binary lastsync is published locally"
assert_no_file "${STATE1}/sources" "no source index directory is created"
assert_missing "$(cat "${LOG1}")" "/sources/lastsync" "no source index URL is requested"

# ---------------------------------------------------------------------------
head1 "Etapa 3: with NHOPKG_SOURCES_REPO the index is installed"
# ---------------------------------------------------------------------------

LOG2="${LOGS}/repo-with-sources.log"
stop_server
start_server "${LOG2}"
STATE2="${WORK}/state-with-sources"
write_config "${STATE2}" "${SERVER_BASE}/sources" "no" "no"

out=$(run_update "${LOGS}/nhopkg-u-with-sources.log")
rc=$?
assert_status 0 "${rc}" "nhopkg -U exits 0 with the source index enabled"
requests=$(cat "${LOG2}")
for url in /sources/lastsync /sources/core.sources.tar.zst /sources/content.source.db.zst; do
	assert_contains "${requests}" "GET ${url}" "downloaded ${url}"
done
assert_eq "200" "$(cat "${STATE2}/sources/lastsync" 2>/dev/null)" \
	"the source lastsync is published locally"
assert_file "${STATE2}/sources/main/packages/kinfocenter.sourceinfo" \
	"the glibc sidecar is installed"
assert_file "${STATE2}/sources/musl/packages/kinfocenter.sourceinfo" \
	"the musl sidecar is installed"
assert_file "${STATE2}/sources/content.source.db.zst" "the content db is installed"
for ref in main musl; do
	installed="${STATE2}/sources/${ref}/packages/kinfocenter"
	cmp -s "${FIXTURES}/kinfocenter/${ref}/nhoid" "${installed}" &&
		ok "${ref}: installed nhoid is byte-identical" ||
		bad "${ref}: installed nhoid is byte-identical"
done
assert_contains "$(cat "${STATE2}/sources/main/packages/kinfocenter.sourceinfo")" \
	"Source-Project: kinfocenter" "installed sidecar carries provenance"
assert_file "${STATE2}/repo/core/lastsync" "the binary update still happened"

# ---------------------------------------------------------------------------
head1 "Etapa 3: an unchanged index is not downloaded again"
# ---------------------------------------------------------------------------

LOG3="${LOGS}/repo-cached-sources.log"
: > "${LOG3}"
cp "${LOG2}" "${LOGS}/repo-with-sources-first.log"
# Restart on a new port, so point the config at it while keeping the state.
stop_server
start_server "${LOG3}"
write_config "${STATE2}" "${SERVER_BASE}/sources" "no" "no"

out=$(run_update "${LOGS}/nhopkg-u-cached.log")
rc=$?
# Both repositories are up to date: sync_repo() reports that without an error,
# and the source hook still has to run.
assert_status 0 "${rc}" "an unchanged binary repository is not an error"
assert_contains "${out}" "Source index already up to date." \
	"the source index skip is reported"
assert_missing "$(cat "${LOG3}")" "/sources/core.sources.tar.zst" \
	"the index tarball is not downloaded twice"
assert_eq "200" "$(cat "${STATE2}/sources/lastsync")" "the source lastsync is unchanged"

# ---------------------------------------------------------------------------
head1 "Etapa 3: a bad signature is detected but does not break -U"
# ---------------------------------------------------------------------------

mkdir -p "${TOOLDIR}/fakebin-gpg"
cat > "${TOOLDIR}/fakebin-gpg/gpg" <<'FAKE'
#!/bin/bash
# The test keyring is a stub: accept signatures containing GOOD only.
sig=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--verify) sig="$2"; shift 2 ;;
		*) shift ;;
	esac
done
[[ -n "${sig}" ]] && grep -q GOOD "${sig}"
FAKE
chmod +x "${TOOLDIR}/fakebin-gpg/gpg"

for file in core.sources.tar.zst content.source.db.zst lastsync; do
	printf 'GOOD\n' > "${REPO_ROOT}/sources/${file}.asc"
done
LOG4="${LOGS}/repo-signed.log"
stop_server
start_server "${LOG4}"
STATE4="${WORK}/state-signed"
write_config "${STATE4}" "${SERVER_BASE}/sources" "yes" "yes"

out=$(PATH="${TOOLDIR}/fakebin-gpg:${PATH}" NHOPKG_CRYPTO_LIB="${BUILDDIR}/src/libnhopkg_crypto" \
	run_update "${LOGS}/nhopkg-u-signed.log")
rc=$?
assert_status 0 "${rc}" "a correctly signed index is accepted"
assert_file "${STATE4}/sources/main/packages/kinfocenter" \
	"the signed index is installed"

for file in core.sources.tar.zst content.source.db.zst lastsync; do
	printf 'BAD\n' > "${REPO_ROOT}/sources/${file}.asc"
done
LOG5="${LOGS}/repo-bad-signature.log"
stop_server
start_server "${LOG5}"
STATE5="${WORK}/state-bad-signature"
write_config "${STATE5}" "${SERVER_BASE}/sources" "yes" "yes"

out=$(PATH="${TOOLDIR}/fakebin-gpg:${PATH}" NHOPKG_CRYPTO_LIB="${BUILDDIR}/src/libnhopkg_crypto" \
	run_update "${LOGS}/nhopkg-u-bad-signature.log")
rc=$?
assert_status 0 "${rc}" "a bad source signature does not change the exit status"
assert_contains "${out}" "Source index metadata verification failed" \
	"the bad signature is reported"
assert_contains "${out}" "binary repositories are unaffected" \
	"the binary update is explicitly declared unaffected"
assert_no_file "${STATE5}/sources/lastsync" "the unverified index is not installed"
assert_file "${STATE5}/repo/core/lastsync" "the binary repository was still synced"

stop_server
trap - EXIT

exit "$(t_summary)"
