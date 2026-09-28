#!/bin/bash
# nhopkg-check-version.sh - versioning cadence reminder
#
# Flags a patch/minor/major candidate when the limits suggested in the
# "Versioning Strategy" of AGENTS.md are reached:
#   Z (patch)  after ~5 fixes
#   Y (minor)  after ~10-15 commits or ~1 month since the last tag
#   X (major)  on any breaking change (conventional commit "!" / BREAKING CHANGE)
#
# Usage:
#   scripts/nhopkg-check-version.sh          show full status
#   scripts/nhopkg-check-version.sh --quiet  only report when a bump is due
#   meson compile -C builddir version-check  same as plain invocation
#
# Limits can be overridden via environment variables:
#   PATCH_FIX_LIMIT, MINOR_COMMITS_LIMIT, MINOR_DAYS_LIMIT

set -euo pipefail

PATCH_FIX_LIMIT="${PATCH_FIX_LIMIT:-5}"
MINOR_COMMITS_LIMIT="${MINOR_COMMITS_LIMIT:-10}"
MINOR_DAYS_LIMIT="${MINOR_DAYS_LIMIT:-30}"

cd "$(git rev-parse --show-toplevel)"

# Newest tag by creation date (the release anchor); version-sort would rank
# legacy YYYY.n tags above semver tags (e.g. 2026.3 > 1.0).
LAST_TAG="$(git for-each-ref --sort=-creatordate --format='%(refname:short)' refs/tags | head -n1 || true)"
if [ -z "${LAST_TAG:-}" ]; then
	RANGE="HEAD"
	LAST_TAG_DATE="(no tags yet)"
	LAST_TAG_TS=""
else
	RANGE="${LAST_TAG}..HEAD"
	LAST_TAG_DATE="$(git log -1 --format='%ad' --date=short "${LAST_TAG}" 2>/dev/null || echo '?')"
	LAST_TAG_TS="$(git log -1 --format='%at' "${LAST_TAG}" 2>/dev/null || true)"
fi

commits_total="$(git rev-list --count "${RANGE}")"
commits_fix="$(git log --format='%s' "${RANGE}" | grep -cE '^fix(:|\()' || true)"
commits_feat="$(git log --format='%s' "${RANGE}" | grep -cE '^feat(:|\()' || true)"

# Breaking changes are counted per commit, and only where the convention
# actually lives: a "!" right after the type in the subject (feat!:,
# refactor(core)!:) or a BREAKING CHANGE footer in the body.
#
# Searching the whole message with grep -c counted matching *lines*, which
# got two things wrong. Any prose that merely mentioned the convention was
# taken for one: a commit explaining that feat!: marks a breaking change,
# or one warning "this does not break!", was reported as breaking. And a
# single commit mentioning it three times counted as three breaking
# changes, inflating the number shown to the user.
# A commit is one record: "git log -z" separates them with a NUL. Using
# "%B%x00" instead leaves the newline that git puts between records at the
# start of every chunk but the first, which hid the subject and made all but
# the newest commit look like a non-breaking one.
commits_breaking=0
while IFS= read -r -d '' _nh_msg; do
	_nh_subject="${_nh_msg%%$'\n'*}"
	_nh_body="${_nh_msg#*$'\n'}"
	if printf '%s\n' "${_nh_subject}" | grep -qE '^[A-Za-z]+(\([^)]*\))?!:' ||
		printf '%s\n' "${_nh_body}" | grep -qE '^BREAKING[ -]CHANGE:'; then
		commits_breaking=$((commits_breaking + 1))
	fi
done < <(git log -z --format='%B' "${RANGE}")

days="0"
if [ -n "${LAST_TAG_TS:-}" ]; then
	now_ts="$(date +%s)"
	days="$(( (now_ts - LAST_TAG_TS) / 86400 ))"
fi

notes="PATCH_FIX_LIMIT=${PATCH_FIX_LIMIT}, MINOR_COMMITS_LIMIT=${MINOR_COMMITS_LIMIT}, MINOR_DAYS_LIMIT=${MINOR_DAYS_LIMIT}"

due=0
if [ "${commits_breaking}" -gt 0 ]; then
	due=1
	verdict="MAJOR bump due: ${commits_breaking} breaking change(s) since ${LAST_TAG:-the beginning}"
elif [ "${commits_fix}" -ge "${PATCH_FIX_LIMIT}" ]; then
	due=1
	verdict="PATCH bump candidate: ${commits_fix} fixes since ${LAST_TAG:-the beginning} (limit ${PATCH_FIX_LIMIT})"
fi
if [ "${commits_total}" -ge "${MINOR_COMMITS_LIMIT}" ] || [ "${days}" -ge "${MINOR_DAYS_LIMIT}" ]; then
	due=1
	[ -n "${verdict:-}" ] && verdict="${verdict}; "
	verdict="${verdict:-}MINOR bump candidate: ${commits_total} commits and ${days} days since ${LAST_TAG:-the beginning}"
fi

if [ "${due}" -eq 1 ]; then
	# --quiet silences the "nothing due" report, not this one: a bump being
	# due is the only thing the post-commit hook exists to say out loud.
	echo "Nhopkg versioning reminder"
	echo "  Range:          ${RANGE}"
	echo "  Commits:        ${commits_total} (fixes: ${commits_fix}, features: ${commits_feat}, breaking: ${commits_breaking})"
	echo "  Days since tag: ${days}"
	echo
	echo "  >>> ${verdict} <<<"
	echo "  Run the Release Workflow: bump meson.build version, update NEWS,"
	echo "  write changelog-<version>.md, commit and create the annotated tag."
	echo "  (limits: ${notes})"
	exit 0
fi

[ "${1:-}" = "--quiet" ] && exit 0
echo "Nhopkg versioning reminder"
echo "  Range:          ${RANGE}"
echo "  Commits:        ${commits_total} (fixes: ${commits_fix}, features: ${commits_feat}, breaking: ${commits_breaking})"
echo "  Days since tag: ${days}"
echo "  Last tag:       ${LAST_TAG} (${LAST_TAG_DATE})"
echo
echo "  Nothing due yet. Can bump Z every ~${PATCH_FIX_LIMIT} fixes,"
echo "  Y every ~${MINOR_COMMITS_LIMIT} commits / ${MINOR_DAYS_LIMIT} days, X on any breaking change."
echo "  (limits: ${notes})"