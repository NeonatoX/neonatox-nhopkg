#!/bin/bash
# Runs the whole suite and prints one line per test file.
#
# Usage: tests/run-all.sh [test-file...]
#        tests/run-all.sh check-add-to-repo.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [[ $# -gt 0 ]]; then
	tests=("$@")
else
	tests=()
	for t in "${TESTS_DIR}"/check-*.sh; do
		[[ -f "${t}" ]] && tests+=("$(basename "${t}")")
	done
fi

if [[ ${#tests[@]} -eq 0 ]]; then
	die "no test files found in ${TESTS_DIR}"
fi

clean_workspace
ensure_build
"${TESTS_DIR}/make-packages.sh" >/dev/null || die "could not generate the test packages"

failed=0
printf 'nhopkg test suite\n'
printf '  source:   %s\n' "${SRC_ROOT}"
printf '  build:    %s\n' "${BUILDDIR}"
printf '  scratch:  %s\n\n' "${WORK}"

for t in "${tests[@]}"; do
	path="${t}"
	[[ -f "${path}" ]] || path="${TESTS_DIR}/${t}"
	[[ -f "${path}" ]] || { printf '%s: not found\n' "${t}" >&2; failed=$((failed + 1)); continue; }
	printf -- '---- %s\n' "$(basename "${path}")"
	if bash "${path}" 2>&1 | sed 's/^/  /'; then
		:
	else
		failed=$((failed + 1))
	fi
	printf '\n'
done

if [[ ${failed} -eq 0 ]]; then
	printf 'all %d test file(s) passed\n' "${#tests[@]}"
else
	printf '%d of %d test file(s) FAILED\n' "${failed}" "${#tests[@]}" >&2
fi
exit "${failed}"
