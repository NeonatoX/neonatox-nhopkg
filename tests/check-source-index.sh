#!/bin/bash
# source-index: Etapa 0 (golden fixtures), Etapa 1 (offline generator) and
# Etapa 2 (live GitLab collector against a local REST stub).
#
# Etapa 0 proves the contract inputs are real: the two kinfocenter nhoids
# fetched from GitLab validate with the real nhopkg-src, and a deliberately
# broken one is rejected.
#
# Etapa 1 proves the generator publishes exactly that contract: one plain tar
# per ref with the byte-identical nhoid and a sidecar describing provenance,
# invalid entries excluded and reported, signatures optional, and NO .srcnho
# artefacts at this stage.
#
# Etapa 2 drives the GitLab collector without touching gitlab.com: the stub
# serves the four used endpoints from the same golden fixtures, and its request
# log proves pagination, caching, rate limiting and the HTTP 429 retry path.
#
# Usage: check-source-index.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
setup_tool clean

FIXTURES="${TESTS_DIR}/fixtures/source-index"
GENERATOR="${SRC_ROOT}/scripts/nhopkg-source-index.sh"
NHO_SRC="${BUILDDIR}/src/nhopkg-src"
OUT="${WORK}/source-index"

# ---------------------------------------------------------------------------
head1 "Etapa 0: the golden fixtures are real nhoids"
# ---------------------------------------------------------------------------

for ref in main musl; do
	out=$(bash "${NHO_SRC}" --validate "${FIXTURES}/kinfocenter/${ref}/nhoid" 2>&1)
	rc=$?
	printf '%s\n' "${out}" > "${LOGS}/source-index-fixture-${ref}.log"
	assert_status 0 "${rc}" "${ref}: kinfocenter validates"
	assert_contains "${out}" "nhoid is valid" "${ref}: validator confirms it"
done

out=$(bash "${NHO_SRC}" --validate "${FIXTURES}/broken/main/nhoid" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/source-index-fixture-broken.log"
assert_status 1 "${rc}" "broken: validator rejects it"
assert_contains "${out}" "nhoid has 6 error(s)" "broken: rejection reason is specific"

# ---------------------------------------------------------------------------
head1 "Etapa 1: the offline generator publishes the index"
# ---------------------------------------------------------------------------

out=$(SOURCE_INDEX_TIMESTAMP=1763822400 \
	"${GENERATOR}" --fixture "${FIXTURES}" --output "${OUT}" \
		--nhopkg-src "${NHO_SRC}" --no-sign 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/source-index-generate.log"
assert_status 0 "${rc}" "generator exits 0"
assert_contains "${out}" "indexed=2 reused=0 invalid=1 skipped=0 failed=0" "the summary counts every row"

assert_file "${OUT}/core.sources.tar.zst" "core.sources.tar.zst published"
assert_file "${OUT}/content.source.db.zst" "content.source.db.zst published"
assert_file "${OUT}/lastsync" "lastsync published"
assert_file "${OUT}/report.txt" "report.txt published"

entries=$(zstd -dc "${OUT}/core.sources.tar.zst" 2>/dev/null | tar tf - 2>/dev/null |
	sed 's#^\./##' | grep -v '/$' | sort)
expected=$(printf '%s\n' \
	'main/kinfocenter' 'main/kinfocenter.sourceinfo' \
	'musl/kinfocenter' 'musl/kinfocenter.sourceinfo' | sort)
assert_eq "${expected}" "${entries}" "the tar holds only the two valid entries and their sidecars"

# ---------------------------------------------------------------------------
head1 "the published nhoids are byte-identical to the fixtures"
# ---------------------------------------------------------------------------

for ref in main musl; do
	indexed="${TOOLDIR}/indexed-${ref}-nhoid"
	zstd -dc "${OUT}/core.sources.tar.zst" | tar xfO - "${ref}/kinfocenter" > "${indexed}"
	cmp -s "${FIXTURES}/kinfocenter/${ref}/nhoid" "${indexed}" &&
		ok "${ref}: published nhoid is byte-identical" ||
		bad "${ref}: published nhoid is byte-identical"
done

# ---------------------------------------------------------------------------
head1 "the sidecar carries provenance and no artefact"
# ---------------------------------------------------------------------------

si=$(zstd -dc "${OUT}/core.sources.tar.zst" | tar xfO - main/kinfocenter.sourceinfo)
for field in \
	"Source-Project: kinfocenter" \
	"Source-Ref: main" \
	"Source-Commit: 013963ff9f07c2b5bb392ae536a1abd9de2f73a2" \
	"Source-Url: https://gitlab.com/neonatox-sources/kinfocenter.git" \
	"Source-Extra-Files: none" \
	"Source-Validated: yes" \
	"Source-Indexed: 1763822400"
do
	assert_contains "${si}" "${field}" "sidecar field: ${field}"
done
grep -qE '^Source-Artifact:[[:space:]]*$' <<<"${si}" &&
	ok "Source-Artifact is empty (no .srcnho in Etapas 0-1)" ||
	bad "Source-Artifact is empty (no .srcnho in Etapas 0-1)"

expected_sha=$(awk -F': ' '/^Source-Nhoid-SHA256:/{print $2}' <<<"${si}")
actual_sha=$(sha256sum "${FIXTURES}/kinfocenter/main/nhoid" | awk '{print $1}')
assert_eq "${actual_sha}" "${expected_sha}" "sidecar hash matches the cached nhoid"

si_musl=$(zstd -dc "${OUT}/core.sources.tar.zst" | tar xfO - musl/kinfocenter.sourceinfo)
assert_contains "${si_musl}" "Source-Ref: musl" "musl sidecar has the canonical ref"
assert_contains "${si_musl}" "Source-Commit: 8861717582cca888832dba0473e68986a1a60ae5" \
	"musl sidecar has the real commit"

# ---------------------------------------------------------------------------
head1 "invalid entries are excluded and reported"
# ---------------------------------------------------------------------------

report=$(cat "${OUT}/report.txt")
assert_contains "${report}" "indexed: 2" "report counts the valid entries"
assert_contains "${report}" "invalid: 1" "report counts the rejection"
assert_contains "${report}" "invalid-entry: main/broken" "report names the rejected entry"
if grep -q 'broken' <<<"${entries}"; then
	bad "the broken entry is not published"
else
	ok "the broken entry is not published"
fi

# ---------------------------------------------------------------------------
head1 "lastsync and the content db describe the published bytes"
# ---------------------------------------------------------------------------

assert_eq "1763822400" "$(cat "${OUT}/lastsync")" "lastsync is the deterministic epoch"
db=$(zstd -dc "${OUT}/content.source.db.zst")
for ref in main musl; do
	size=$(wc -c < "${FIXTURES}/kinfocenter/${ref}/nhoid")
	assert_contains "${db}" "${size} ${ref}/kinfocenter" "${ref}: db declares the nhoid size"
	assert_contains "${db}" "${ref}/kinfocenter.sourceinfo" "${ref}: db lists the sidecar"
done

# ---------------------------------------------------------------------------
head1 "no .srcnho and no signatures in this stage"
# ---------------------------------------------------------------------------

assert_eq "" "$(find "${OUT}" -name '*.srcnho' -print)" "Etapas 0-1 generate no .srcnho"
assert_eq "" "$(find "${OUT}" -name '*.asc' -print)" "--no-sign creates no signatures"

# ---------------------------------------------------------------------------
head1 "signing works when a key and gpg are available"
# ---------------------------------------------------------------------------

mkdir -p "${TOOLDIR}/fakebin"
cat > "${TOOLDIR}/fakebin/gpg" <<'FAKE'
#!/bin/bash
# Minimal stand-in: write the requested --output file. The test only checks
# that the generator asks gpg to sign each published file.
out=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--output) out="$2"; shift 2 ;;
		*) shift ;;
	esac
done
[[ -n "${out}" ]] && printf 'fake detached signature\n' > "${out}"
FAKE
chmod +x "${TOOLDIR}/fakebin/gpg"

SIGNED="${WORK}/source-index-signed"
out=$(PATH="${TOOLDIR}/fakebin:${PATH}" NHOPKG_SIGN_KEY=test-key \
	SOURCE_INDEX_TIMESTAMP=1763822400 \
	"${GENERATOR}" --fixture "${FIXTURES}" --output "${SIGNED}" \
		--nhopkg-src "${NHO_SRC}" 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/source-index-sign.log"
assert_status 0 "${rc}" "signed generation exits 0"
for file in core.sources.tar.zst content.source.db.zst lastsync; do
	assert_file "${SIGNED}/${file}.asc" "signature published for ${file}"
done

# ---------------------------------------------------------------------------
head1 "Etapa 2: the GitLab collector publishes from a REST stub"
# ---------------------------------------------------------------------------

FAKE_PID=""
FAKE_PORT=""
stop_fake_gitlab() {
	[[ -n "${FAKE_PID}" ]] || return 0
	kill "${FAKE_PID}" 2>/dev/null || true
	wait "${FAKE_PID}" 2>/dev/null || true
	FAKE_PID=""
}
trap 'stop_fake_gitlab' EXIT

start_fake_gitlab() { # <request log> [429 path substring]
	local log="$1" rate_path="${2:-}" i
	FAKE_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')" ||
		{ bad "could not allocate a port for the fake API"; return 1; }
	: > "${log}"
	FAKE_GITLAB_PORT="${FAKE_PORT}" FAKE_GITLAB_LOG="${log}" \
		FAKE_GITLAB_429="${rate_path}" \
		python3 "${FIXTURES}/gitlab-stub.py" > "${LOGS}/fake-gitlab.out" 2>&1 &
	FAKE_PID=$!
	for i in $(seq 1 50); do
		python3 -c "import socket,sys;s=socket.socket();s.settimeout(0.2);sys.exit(0 if s.connect_ex(('127.0.0.1',${FAKE_PORT}))==0 else 1)" &&
			return 0
		sleep 0.1
	done
	bad "fake GitLab API did not start"
	return 1
}

LIVE_OUT="${WORK}/source-index-live"
LIVE_CACHE="${WORK}/source-index-live-cache"
LIVE_LOG="${LOGS}/fake-gitlab-requests.log"

start_fake_gitlab "${LIVE_LOG}"
api="http://127.0.0.1:${FAKE_PORT}/api/v4"

out=$(SOURCE_INDEX_TIMESTAMP=1763822400 \
	"${GENERATOR}" --api-url "${api}" --output "${LIVE_OUT}" \
		--cache "${LIVE_CACHE}" --nhopkg-src "${NHO_SRC}" \
		--limit 2 --rate 0 --no-sign 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/source-index-gitlab.log"
assert_status 0 "${rc}" "the live generator exits 0"
assert_contains "${out}" "indexed=4 reused=0 invalid=0 skipped=0 failed=0" \
	"both refs of both projects are indexed"
assert_file "${LIVE_OUT}/core.sources.tar.zst" "live: index published"

live_entries=$(zstd -dc "${LIVE_OUT}/core.sources.tar.zst" | tar tf - 2>/dev/null |
	sed 's#^\./##' | grep -v '/$' | sort)
expected=$(printf '%s\n' \
	'main/kinfocenter' 'main/kinfocenter.sourceinfo' \
	'musl/kinfocenter' 'musl/kinfocenter.sourceinfo' \
	'main/qt6-graphs' 'main/qt6-graphs.sourceinfo' \
	'musl/qt6-graphs' 'musl/qt6-graphs.sourceinfo' | sort)
assert_eq "${expected}" "${live_entries}" "live: four projects refs with their sidecars"

live_si=$(zstd -dc "${LIVE_OUT}/core.sources.tar.zst" | tar xfO - main/kinfocenter.sourceinfo)
assert_contains "${live_si}" "Source-Extra-Files: others/extra.txt patches/fix.patch" \
	"tree entries become Source-Extra-Files"
assert_contains "${live_si}" "Source-Url: ${api%\/api\/v4}/neonatox-sources/kinfocenter.git" \
	"the clone URL points at the source server"
qt6_si=$(zstd -dc "${LIVE_OUT}/core.sources.tar.zst" | tar xfO - main/qt6-graphs.sourceinfo)
assert_contains "${qt6_si}" "Source-Extra-Files: none" "a 404 tree means no extras"

requests=$(cat "${LIVE_LOG}")
assert_contains "${requests}" 'groups/neonatox-sources/projects?per_page=100&page=1' \
	"the first projects page is fetched"
assert_missing "${requests}" 'page=2' "--limit stops before the next page"
assert_eq 4 "$(wc -l < "${LIVE_CACHE}/projects.tsv")" "four cache rows are written"

# ---------------------------------------------------------------------------
head1 "Etapa 2: a second run reuses the committed cache"
# ---------------------------------------------------------------------------

LIVE_OUT2="${WORK}/source-index-live2"
LIVE_LOG2="${LOGS}/fake-gitlab-cached-requests.log"
stop_fake_gitlab
start_fake_gitlab "${LIVE_LOG2}"

out=$(SOURCE_INDEX_TIMESTAMP=1763822401 \
	"${GENERATOR}" --api-url "http://127.0.0.1:${FAKE_PORT}/api/v4" \
		--output "${LIVE_OUT2}" --cache "${LIVE_CACHE}" \
		--nhopkg-src "${NHO_SRC}" --limit 2 --rate 0 --no-sign 2>&1)
rc=$?
printf '%s\n' "${out}" > "${LOGS}/source-index-gitlab-cached.log"
assert_status 0 "${rc}" "the cached generator exits 0"
assert_contains "${out}" "indexed=4 reused=4 invalid=0 skipped=0 failed=0" \
	"all four rows are reported as reused"
assert_eq 0 "$(grep -c 'repository/files/nhoid/raw' "${LIVE_LOG2}" || true)" \
	"a cache hit makes no raw nhoid requests"
assert_eq 4 "$(wc -l < "${LIVE_CACHE}/projects.tsv")" \
	"a reuse-only run does not wipe the cache"
zstd -dc "${LIVE_OUT}/core.sources.tar.zst" | tar xfO - musl/kinfocenter > "${TOOLDIR}/live-first"
zstd -dc "${LIVE_OUT2}/core.sources.tar.zst" | tar xfO - musl/kinfocenter > "${TOOLDIR}/live-second"
cmp -s "${TOOLDIR}/live-first" "${TOOLDIR}/live-second" &&
	ok "the reused nhoid is byte-identical" ||
	bad "the reused nhoid is byte-identical"

# ---------------------------------------------------------------------------
head1 "Etapa 2: pagination, 429 retry and invalid entries"
# ---------------------------------------------------------------------------

LIVE_OUT3="${WORK}/source-index-live3"
LIVE_CACHE3="${WORK}/source-index-live3-cache"
LIVE_LOG3="${LOGS}/fake-gitlab-rate-limited-requests.log"
stop_fake_gitlab
start_fake_gitlab "${LIVE_LOG3}" '/projects/3/repository/files/nhoid/raw'

started=$(date +%s%N)
out=$(SOURCE_INDEX_TIMESTAMP=1763822402 \
	"${GENERATOR}" --api-url "http://127.0.0.1:${FAKE_PORT}/api/v4" \
		--output "${LIVE_OUT3}" --cache "${LIVE_CACHE3}" \
		--nhopkg-src "${NHO_SRC}" --rate 4 --retries 2 --no-sign 2>&1)
rc=$?
elapsed=$(awk -v a="${started}" -v b="$(date +%s%N)" 'BEGIN{printf "%.2f", (b-a)/1000000000}')
printf '%s\n' "${out}" > "${LOGS}/source-index-gitlab-rate.log"
assert_status 0 "${rc}" "the full collector exits 0"
assert_contains "${out}" "indexed=4 reused=0 invalid=1 skipped=0 failed=0" \
	"the third project is rejected without losing the valid ones"
assert_contains "${out}" "HTTP 429" "the 429 response is retried"
assert_contains "${out}" "retry 1/2 in 1s" "Retry-After is honoured"
assert_contains "$(cat "${LIVE_OUT3}/report.txt")" "invalid-entry: main/broken" \
	"the invalid live nhoid is named in the report"
assert_contains "$(cat "${LIVE_LOG3}")" 'groups/neonatox-sources/projects?per_page=100&page=2' \
	"without --limit all project pages are fetched"
assert_eq 1 "$(awk -v e="${elapsed}" 'BEGIN{print (e>=1)?1:0}')" \
	"--rate throttles requests (elapsed ${elapsed}s)"
assert_eq 0 "$(zstd -dc "${LIVE_OUT3}/core.sources.tar.zst" | tar tf - | grep -c broken || true)" \
	"the invalid live entry is not published"

stop_fake_gitlab
trap - EXIT

exit "$(t_summary)"
