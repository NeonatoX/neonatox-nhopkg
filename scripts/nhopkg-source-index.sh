#!/bin/bash
# nhopkg-source-index.sh - generate the signed source metadata index.
#
# Server-side/CI tool, not a user-facing nhopkg command. It builds
# core.sources.tar.zst, content.source.db.zst, lastsync and report.txt from
# validated nhoid files. No .srcnho artefacts are produced at this stage.
#
# Two collectors feed the same publisher:
#   * --fixture DIR  offline, for tests (Etapa 1)
#   * (no --fixture) live GitLab REST API (Etapa 2)
#
# Usage:
#   scripts/nhopkg-source-index.sh --output DIR [options]
#   scripts/nhopkg-source-index.sh --fixture DIR --output DIR [options]
#
# Options:
#   --fixture DIR     read projects.tsv and <project>/<ref>/nhoid from DIR
#   --output DIR      publish the generated index into DIR
#   --nhopkg-src PATH validator to use (default: nhopkg-src from PATH)
#   --refs LIST       refs to index (default: "main musl")
#   --group NAME      GitLab group (default: neonatox-sources)
#   --api-url URL     GitLab API base (default: https://gitlab.com/api/v4)
#   --cache DIR       commit-SHA cache (default: <output>/.cache)
#   --limit N         process at most N projects (0 = all)
#   --rate N          max HTTP requests per second (0 = unlimited, default 2)
#   --retries N       retries after HTTP 429 (default 3)
#   --no-sign         do not create detached GPG signatures
#   -h, --help        show this help
#
# Environment:
#   GITLAB_TOKEN           access token with read_api/read_repository (optional
#                          for the anonymous API, required for full runs)
#   NHOPKG_SIGN_KEY        GPG key id used when signing (unless --no-sign)
#   SOURCE_INDEX_TIMESTAMP override the epoch written to lastsync (for tests)
#
# Fixture manifest format (tab separated, '#' starts a comment):
#   project  ref  commit  url  extra_files

set -uo pipefail

PROG="$(basename "$0")"

die() { printf '%s: error: %s\n' "${PROG}" "$*" >&2; exit 1; }
note() { printf '%s: %s\n' "${PROG}" "$*" >&2; }

usage() { sed -n '2,/^set -uo pipefail$/p' "$0" | sed 's/^# \{0,1\}//'; }

FIXTURE_DIR=""
OUTPUT_DIR=""
NHO_SRC="nhopkg-src"
REFS="main musl"
GROUP="neonatox-sources"
API_URL="https://gitlab.com/api/v4"
CACHE_DIR=""
LIMIT=0
RATE=2
RETRIES=3
DO_SIGN=1

while [[ $# -gt 0 ]]; do
	case "$1" in
		--fixture)     FIXTURE_DIR="${2:?--fixture needs an argument}"; shift 2 ;;
		--output)      OUTPUT_DIR="${2:?--output needs an argument}"; shift 2 ;;
		--nhopkg-src)  NHO_SRC="${2:?--nhopkg-src needs an argument}"; shift 2 ;;
		--refs)        REFS="${2:?--refs needs an argument}"; shift 2 ;;
		--group)       GROUP="${2:?--group needs an argument}"; shift 2 ;;
		--api-url)     API_URL="${2:?--api-url needs an argument}"; shift 2 ;;
		--cache)       CACHE_DIR="${2:?--cache needs an argument}"; shift 2 ;;
		--limit)       LIMIT="${2:?--limit needs an argument}"; shift 2 ;;
		--rate)        RATE="${2:?--rate needs an argument}"; shift 2 ;;
		--retries)     RETRIES="${2:?--retries needs an argument}"; shift 2 ;;
		--no-sign)     DO_SIGN=0; shift ;;
		-h|--help)     usage; exit 0 ;;
		*)             die "unknown option: $1 (try --help)" ;;
	esac
done

[[ -n "${OUTPUT_DIR}" ]] || die "--output is required"
[[ "${LIMIT}" =~ ^[0-9]+$ ]] || die "--limit must be a non-negative integer"
[[ "${RATE}" =~ ^[0-9]+$ ]] || die "--rate must be a non-negative integer"
[[ "${RETRIES}" =~ ^[0-9]+$ ]] || die "--retries must be a non-negative integer"
if [[ -n "${FIXTURE_DIR}" && ! -d "${FIXTURE_DIR}" ]]; then
	die "fixture directory not found: ${FIXTURE_DIR}"
fi
MANIFEST="${FIXTURE_DIR:+${FIXTURE_DIR}/projects.tsv}"
if [[ -n "${FIXTURE_DIR}" && ! -f "${MANIFEST}" ]]; then
	die "manifest not found: ${MANIFEST}"
fi

for tool in tar zstd sha256sum date mktemp; do
	command -v "${tool}" >/dev/null 2>&1 || die "required tool not found: ${tool}"
done

if command -v "${NHO_SRC}" >/dev/null 2>&1; then
	VALIDATOR="$(command -v "${NHO_SRC}")"
elif [[ -f "${NHO_SRC}" ]]; then
	VALIDATOR="${NHO_SRC}"
else
	die "nhopkg-src validator not found: ${NHO_SRC}"
fi

run_validator() { # <nhoid file>
	if [[ -x "${VALIDATOR}" ]]; then
		"${VALIDATOR}" --validate "$1"
	else
		bash "${VALIDATOR}" --validate "$1"
	fi
}

REFS="$(echo "${REFS}" | tr ',' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')"
[[ -n "${REFS}" ]] || die "--refs may not be empty"
API_URL="${API_URL%/}"
CACHE_DIR="${CACHE_DIR:-${OUTPUT_DIR}/.cache}"

mkdir -p "${OUTPUT_DIR}" || die "cannot create output directory: ${OUTPUT_DIR}"
STAGE="$(mktemp -d "${OUTPUT_DIR}/.staging.XXXXXX")" || die "cannot create staging directory"
trap 'rm -rf "${STAGE}"' EXIT
ROOT="${STAGE}/root"
mkdir -p "${ROOT}"

INDEXED=0
REUSED=0
INVALID=0
SKIPPED=0
FAILED=0
ACTIVE_REFS=""
DB_LINES=()
INVALID_LINES=()

# ---------------------------------------------------------------------------
# Shared publisher: validate one nhoid and add it to the index.
# ---------------------------------------------------------------------------
ingest_row() { # <project> <ref> <commit> <url> <extra> <nhoid file> [reused]
	local project="$1" ref="$2" commit="$3" url="$4" extra="$5" nhoid="$6" reused="${7:-no}"
	local validation reason sha indexed_at dest info

	validation=$(run_validator "${nhoid}" 2>&1)
	if [[ $? -ne 0 ]]; then
		reason="$(echo "${validation}" | grep '^\s*\*\*\*' | tail -1)"
		[[ -n "${reason}" ]] || reason="validation failed"
		INVALID_LINES+=("${ref}/${project}: ${reason}")
		INVALID=$((INVALID + 1))
		return 0
	fi

	[[ -n "${commit}" ]] || commit="unknown"
	[[ -n "${url}" ]] || url="unknown"
	[[ -n "${extra}" ]] || extra="none"
	sha="$(sha256sum "${nhoid}" | awk '{print $1}')"
	indexed_at="${SOURCE_INDEX_TIMESTAMP:-$(date +%s)}"

	mkdir -p "${ROOT}/${ref}" || die "cannot create ${ROOT}/${ref}"
	dest="${ROOT}/${ref}/${project}"
	info="${dest}.sourceinfo"
	cp -- "${nhoid}" "${dest}" || die "cannot copy nhoid for ${ref}/${project}"

	cat > "${info}" <<EOF
Source-Project: ${project}
Source-Ref: ${ref}
Source-Commit: ${commit}
Source-Url: ${url}
Source-Extra-Files: ${extra}
Source-Nhoid-SHA256: ${sha}
Source-Artifact:
Source-Validated: yes
Source-Indexed: ${indexed_at}
EOF

	DB_LINES+=("$(wc -c < "${dest}") ${ref}/${project}")
	DB_LINES+=("$(wc -c < "${info}") ${ref}/${project}.sourceinfo")
	INDEXED=$((INDEXED + 1))
	[[ "${reused}" == "yes" ]] && REUSED=$((REUSED + 1))
	case " ${ACTIVE_REFS} " in
		*" ${ref} "*) ;;
		*) ACTIVE_REFS="${ACTIVE_REFS} ${ref}" ;;
	esac
}

# ---------------------------------------------------------------------------
# Collector 1: offline fixtures (Etapa 1).
# ---------------------------------------------------------------------------
collect_fixture() { # <manifest>
	local project ref commit url extra nhoid
	while IFS=$'\t' read -r project ref commit url extra || [[ -n "${project:-}" ]]; do
		[[ -z "${project:-}" || "${project}" == \#* ]] && continue

		case " ${REFS} " in
			*" ${ref} "*) ;;
			*) SKIPPED=$((SKIPPED + 1)); continue ;;
		esac

		nhoid="${FIXTURE_DIR}/${project}/${ref}/nhoid"
		if [[ ! -f "${nhoid}" ]]; then
			note "missing nhoid for ${ref}/${project}: ${nhoid}"
			FAILED=$((FAILED + 1))
			continue
		fi
		ingest_row "${project}" "${ref}" "${commit}" "${url}" "${extra}" "${nhoid}"
	done < "$1"
}

# ---------------------------------------------------------------------------
# Collector 2: live GitLab REST API (Etapa 2).
# ---------------------------------------------------------------------------
AUTH_ARGS=()
[[ -n "${GITLAB_TOKEN:-}" ]] && AUTH_ARGS=(-H "PRIVATE-TOKEN: ${GITLAB_TOKEN}")

LAST_REQUEST_NS=0
MIN_INTERVAL_NS=0
[[ ${RATE} -gt 0 ]] && MIN_INTERVAL_NS=$(( 1000000000 / RATE ))

http_throttle() {
	local now elapsed
	now="$(date +%s%N)"
	if [[ "${LAST_REQUEST_NS}" -gt 0 ]]; then
		elapsed=$(( now - LAST_REQUEST_NS ))
		if [[ "${elapsed}" -lt "${MIN_INTERVAL_NS}" ]]; then
			sleep "$(awk -v ns=$(( MIN_INTERVAL_NS - elapsed )) \
				'BEGIN{printf "%.3f", ns/1000000000}')"
		fi
	fi
	LAST_REQUEST_NS="$(date +%s%N)"
}

http_get() { # <url> <outfile> [soft]
	local url="$1" out="$2" soft="${3:-no}" code hdr attempt=1 retry_after curl_rc
	hdr="$(mktemp)"
	while :; do
		http_throttle
		code="$(curl -sS -o "${out}.tmp" -D "${hdr}" -w '%{http_code}' \
			--connect-timeout 10 --max-time 60 "${AUTH_ARGS[@]}" -- "${url}")"
		curl_rc=$?
		if [[ ${curl_rc} -ne 0 ]]; then
			rm -f "${hdr}" "${out}.tmp"
			die "request failed (curl ${curl_rc}): ${url}"
		fi
		if [[ "${code}" == "429" && ${attempt} -le ${RETRIES} ]]; then
			retry_after="$(awk 'tolower($1)=="retry-after:"{gsub(/\r/,"",$2);print $2;exit}' "${hdr}")"
			[[ -n "${retry_after}" ]] || retry_after=60
			note "HTTP 429 for ${url}; retry ${attempt}/${RETRIES} in ${retry_after}s"
			sleep "${retry_after}"
			attempt=$((attempt + 1))
			continue
		fi
		break
	done
	rm -f "${hdr}"
	mv -f "${out}.tmp" "${out}" || die "cannot store response for ${url}"
	if [[ "${code}" != 2* ]]; then
		[[ "${soft}" == "yes" ]] && return 1
		die "HTTP ${code} from ${url}: $(head -c 200 "${out}")"
	fi
	return 0
}

# JSON parsing is done with python3 (already a build/test dependency of the
# project). Each helper prints tab-separated rows on stdout.
json_projects() { python3 - "$1" <<'PY'
import json, sys
for p in json.load(open(sys.argv[1], encoding="utf-8")):
    if not isinstance(p, dict):
        continue
    print("\t".join(str(p.get(k, "") or "") for k in
                    ("id", "path", "archived", "empty_repo")))
PY
}

json_branches() { python3 - "$1" "$2" <<'PY'
import json, sys
refs = set(sys.argv[2].split())
for b in json.load(open(sys.argv[1], encoding="utf-8")):
    name = b.get("name", "")
    if name in refs:
        print("%s\t%s" % (name, (b.get("commit") or {}).get("id", "")))
PY
}

json_extras() { python3 - "$1" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    data = []
files = [e.get("path", "") for e in data if isinstance(e, dict)
         and e.get("type") == "blob"
         and e.get("path", "").startswith(("patches/", "others/"))]
print(" ".join(sorted(files)) if files else "none")
PY
}

# Cache helpers. A hit needs both the matching commit and a cached file whose
# SHA256 still matches what was recorded, so a corrupted cache is re-fetched.
# The whole table is loaded up front: a run that only reuses entries must not
# overwrite the cache with an empty file.
declare -A CACHE_MAP=()
cache_load() {
	[[ -f "${CACHE_DIR}/projects.tsv" ]] || return 0
	local line p r c rest
	while IFS= read -r line || [[ -n "${line}" ]]; do
		[[ -n "${line}" ]] || continue
		IFS=$'\t' read -r p r c rest <<<"${line}"
		[[ -n "${p}" ]] || continue
		CACHE_MAP["${p}"$'\t'"${r}"$'\t'"${c}"]="${line}"
	done < "${CACHE_DIR}/projects.tsv"
}

cache_lookup() { # <project> <ref> <commit> -> prints url<TAB>extra<TAB>sha
	local key="$1"$'\t'"$2"$'\t'"$3" line p r c rest
	[[ -v 'CACHE_MAP[$key]' ]] || return 1
	line="${CACHE_MAP[$key]}"
	IFS=$'\t' read -r p r c rest <<<"${line}"
	printf '%s\n' "${rest}"
	return 0
}

cache_remember() { # <project> <ref> <commit> <url> <extra> <sha>
	CACHE_MAP["$1"$'\t'"$2"$'\t'"$3"]="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$@")"
}

cache_commit() {
	mkdir -p "${CACHE_DIR}" || die "cannot create cache directory: ${CACHE_DIR}"
	local tmp="${CACHE_DIR}/.projects.$$" key
	: > "${tmp}"
	if ((${#CACHE_MAP[@]})); then
		for key in "${!CACHE_MAP[@]}"; do
			printf '%s\n' "${CACHE_MAP[$key]}" >> "${tmp}"
		done
	fi
	mv -f "${tmp}" "${CACHE_DIR}/projects.tsv" || die "cannot write the cache index"
}

collect_gitlab() {
	# Separate temporaries: the projects list is read across the whole outer
	# loop, so it must never be overwritten by a per-project query.
	local resp="$(mktemp)" proj_list="$(mktemp)" branch_list="$(mktemp)" tree_file="$(mktemp)"
	local page=1 processed=0
	local id path archived empty ref commit cached url extra sha
	local cached_file cached_sha base extra_set project_refs first_ref

	base="${API_URL%/api/v4}"
	[[ "${base}" == "${API_URL}" ]] && base="https://gitlab.com"
	cache_load

	while [[ ${page} -le 50 ]]; do
		http_get "${API_URL}/groups/${GROUP}/projects?per_page=100&page=${page}" "${resp}"
		json_projects "${resp}" > "${proj_list}"
		[[ -s "${proj_list}" ]] || break

		while IFS=$'\t' read -r id path archived empty || [[ -n "${id:-}" ]]; do
			[[ -n "${id}" ]] || continue
			[[ "${archived}" == "True" || "${archived}" == "true" ]] && continue
			[[ "${empty}" == "True" || "${empty}" == "true" ]] && continue
			[[ "${path}" =~ ^[A-Za-z0-9._-]+$ ]] || {
				note "unsafe project path, skipped: ${path}"
				FAILED=$((FAILED + 1)); continue
			}
			if [[ ${LIMIT} -gt 0 && ${processed} -ge ${LIMIT} ]]; then
				break 2
			fi
			processed=$((processed + 1))
			url="${base}/${GROUP}/${path}.git"

			http_get "${API_URL}/projects/${id}/repository/branches?per_page=100" "${resp}"
			json_branches "${resp}" "${REFS}" > "${branch_list}"
			project_refs="$(cat "${branch_list}")"
			[[ -n "${project_refs}" ]] || continue

			# One tree call per project: extras are detected on the first
			# requested ref and reused for the other refs of the same project.
			# A 404 means "no tree", which is not fatal for the index.
			first_ref="$(echo "${project_refs}" | head -1 | cut -f1)"
			: > "${tree_file}"
			http_get "${API_URL}/projects/${id}/repository/tree?ref=${first_ref}&recursive=1" \
				"${tree_file}" "yes" || : > "${tree_file}"
			extra_set="$(json_extras "${tree_file}")"
			[[ -n "${extra_set}" ]] || extra_set="none"

			while IFS=$'\t' read -r ref commit || [[ -n "${ref:-}" ]]; do
				[[ -n "${ref}" ]] || continue
				extra="${extra_set}"
				[[ -n "${extra}" ]] || extra="none"
				cached_file="${CACHE_DIR}/nhoids/${path}/${ref}/nhoid"
				cached_sha=""
				if cached="$(cache_lookup "${path}" "${ref}" "${commit}")"; then
					IFS=$'\t' read -r _ cached_extra cached_sha <<<"${cached}"
					extra="${cached_extra}"
					if [[ -f "${cached_file}" ]] &&
					   [[ "$(sha256sum "${cached_file}" | awk '{print $1}')" == "${cached_sha}" ]]; then
						ingest_row "${path}" "${ref}" "${commit}" "${url}" "${extra}" \
							"${cached_file}" "yes"
						continue
					fi
				fi

				http_get "${API_URL}/projects/${id}/repository/files/nhoid/raw?ref=${ref}" "${resp}"
				mkdir -p "${CACHE_DIR}/nhoids/${path}/${ref}" ||
					die "cannot create cache directory for ${path}/${ref}"
				cp -- "${resp}" "${cached_file}" || die "cannot cache nhoid for ${path}/${ref}"
				sha="$(sha256sum "${cached_file}" | awk '{print $1}')"
				ingest_row "${path}" "${ref}" "${commit}" "${url}" "${extra}" "${cached_file}"
				cache_remember "${path}" "${ref}" "${commit}" "${url}" "${extra}" "${sha}"
			done <<<"${project_refs}"
		done < "${proj_list}"

		[[ ${LIMIT} -gt 0 && ${processed} -ge ${LIMIT} ]] && break
		page=$((page + 1))
	done
	rm -f "${resp}" "${proj_list}" "${branch_list}" "${tree_file}"
	cache_commit
}

# ---------------------------------------------------------------------------
# Collect and publish.
# ---------------------------------------------------------------------------
if [[ -n "${FIXTURE_DIR}" ]]; then
	collect_fixture "${MANIFEST}"
else
	collect_gitlab
fi

if [[ -n "${ACTIVE_REFS}" ]]; then
	( cd "${ROOT}" && tar cf - ${ACTIVE_REFS} ) |
		zstd -q -c > "${STAGE}/core.sources.tar.zst" ||
		die "could not create core.sources.tar.zst"
else
	die "no valid nhoid entries: refusing to publish an empty index"
fi

if ((${#DB_LINES[@]})); then
	printf '%s\n' "${DB_LINES[@]}" > "${STAGE}/content.source.db"
else
	: > "${STAGE}/content.source.db"
fi
zstd -q -c "${STAGE}/content.source.db" > "${STAGE}/content.source.db.zst" ||
	die "could not create content.source.db.zst"

echo "${SOURCE_INDEX_TIMESTAMP:-$(date +%s)}" > "${STAGE}/lastsync"

{
	echo "indexed: ${INDEXED}"
	echo "reused: ${REUSED}"
	echo "skipped: ${SKIPPED}"
	echo "invalid: ${INVALID}"
	echo "failed: ${FAILED}"
	echo "refs: $(echo "${REFS}" | tr ' ' ',')"
	for line in "${INVALID_LINES[@]}"; do
		echo "invalid-entry: ${line}"
	done
} > "${STAGE}/report.txt"

if [[ ${DO_SIGN} -eq 1 ]]; then
	[[ -n "${NHOPKG_SIGN_KEY:-}" ]] || die "signing needs NHOPKG_SIGN_KEY (or use --no-sign)"
	command -v gpg >/dev/null 2>&1 || die "signing needs gpg (or use --no-sign)"
	for file in core.sources.tar.zst content.source.db.zst lastsync; do
		gpg --batch --yes --default-key "${NHOPKG_SIGN_KEY}" --detach-sign --armor \
			--output "${STAGE}/${file}.asc" "${STAGE}/${file}" || die "could not sign ${file}"
	done
fi

if [[ ${DO_SIGN} -eq 0 ]]; then
	rm -f "${OUTPUT_DIR}"/*.asc
fi
for file in core.sources.tar.zst content.source.db.zst lastsync report.txt; do
	mv -f "${STAGE}/${file}" "${OUTPUT_DIR}/${file}" || die "cannot publish ${file}"
done
if [[ ${DO_SIGN} -eq 1 ]]; then
	for file in core.sources.tar.zst content.source.db.zst lastsync; do
		mv -f "${STAGE}/${file}.asc" "${OUTPUT_DIR}/${file}.asc" || die "cannot publish ${file}.asc"
	done
fi

printf '%s: indexed=%d reused=%d invalid=%d skipped=%d failed=%d -> %s\n' \
	"${PROG}" "${INDEXED}" "${REUSED}" "${INVALID}" "${SKIPPED}" "${FAILED}" "${OUTPUT_DIR}"
exit 0
