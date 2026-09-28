#!/bin/bash
# Generates the .nho packages the tests run against.
#
# Two sets, both synthetic and self-contained:
#
#   packages/   valid ones, including the awkward shapes: a metapackage with
#               no data.tar.zst, a name with a space in the file name, a
#               version containing dashes, a package whose name is a prefix
#               of another, and a stale nhoid version.
#   hostile/    ones that must be rejected rather than mangled, each breaking
#               a different rule: a corrupt archive, a name with a glob, a
#               name with a slash, a name that walks out of the staging
#               directory, an empty version, and a version carrying a shell
#               metacharacter.
#
# Usage: make-packages.sh
set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

rm -rf "${PKGDIR}" "${HOSTILE_PKGDIR}"
mkdir -p "${PKGDIR}" "${HOSTILE_PKGDIR}"

# mk_nho <output> <name> <version> <release> <withdata|nodata> [nhoid version]
mk_nho() {
	local out="$1" name="$2" ver="$3" rel="$4" data="$5" nhovid="${6:-0.5}"
	local d
	d=$(mktemp -d)
	cat > "${d}/nhoid" <<EOF
#%NHO-${nhovid}
# Package Maintainer:	tester <tester@example.com>

# Name:	${name}
# Version:	${ver}
# Release:	${rel}
# License:	GPL-2.0-only
# Repository:	extra
# Arch:	x86_64
# OS:	linux
# Installed-Size:	1 KB
# Build-Duration:	0 min
# Build-Date:	1784044930
# Build-Host:	test
# Url:	https://example.com
# Description:	test package ${name}
# SHA256:	deadbeef  data.tar.zst


npostinstall() {
    noemptyfuncs
}
npostremove() {
    noemptyfuncs
}
EOF
	if [[ "${data}" == "withdata" ]]; then
		printf 'hello from %s\n' "${name}" > "${d}/payload.txt"
		tar -C "${d}" -cf - payload.txt | zstd -q -o "${d}/data.tar.zst"
		rm -f "${d}/payload.txt"
	fi
	( cd "${d}" && tar -cf "${out}" * )
	rm -rf "${d}"
}

# --- valid -----------------------------------------------------------------

# alpha and alpha-devel: the second name starts with the first one, which is
# what the old "name-*" purge glob used to confuse.
mk_nho "${PKGDIR}/alpha-1.0-n2026.linux-x86_64.nho"        alpha        1.0 n2026 withdata
mk_nho "${PKGDIR}/alpha-devel-1.0-n2026.linux-x86_64.nho"  alpha-devel  1.0 n2026 withdata
mk_nho "${PKGDIR}/beta-2.0-n2026.linux-x86_64.nho"         beta         2.0 n2026 withdata
# A metapackage: valid, with no data.tar.zst and therefore no file list.
mk_nho "${PKGDIR}/gamma-1.0-n2026.linux-x86_64.nho"        gamma        1.0 n2026 nodata
# An nhoid from an older nhopkg: rejected, but only this package.
mk_nho "${PKGDIR}/delta-1.0-n2026.linux-x86_64.nho"        delta        1.0 n2026 withdata 0.4
# A space in the file name, which a naive for-loop word splitting eats.
mk_nho "${PKGDIR}/epsilon 1.0-n2026.linux-x86_64.nho"      epsilon      1.0 n2026 withdata
# zeta exists in two versions, one with dashes in the version. Replacing one
# with the other is what used to leave an index entry behind.
mk_nho "${PKGDIR}/zeta-1.0-rc1-1-n2026.linux-x86_64.nho"   zeta         1.0-rc1 1 withdata
mk_nho "${PKGDIR}/zeta-1.0-1-n2026.linux-x86_64.nho"       zeta         1.0 1 withdata

# --- hostile ---------------------------------------------------------------

# Traversal in the name: the name is used as a glob and to build paths.
mk_nho "${HOSTILE_PKGDIR}/traversal-1.0-n2026.nho"  '../../../escape' 1.0 n2026 withdata
# A glob in the name, which would expand against the staging directory.
mk_nho "${HOSTILE_PKGDIR}/glob-1.0-n2026.nho"        '*'              1.0 n2026 withdata
# A slash in the name, which would escape it.
mk_nho "${HOSTILE_PKGDIR}/slash-1.0-n2026.nho"       'foo/bar'        1.0 n2026 withdata
# An empty version: the id cannot be built, so nothing can be indexed.
mk_nho "${HOSTILE_PKGDIR}/noversion-1.0-n2026.nho"   'noversion'      ''   n2026 withdata
# A shell metacharacter in the version.
mk_nho "${HOSTILE_PKGDIR}/weirdver-1.0-n2026.nho"    'weirdver'       '1.0;rm -rf /' 1 withdata
# A perfectly valid one, to prove the batch survives its hostile neighbours.
mk_nho "${HOSTILE_PKGDIR}/good-1.0-n2026.nho"        'goodpkg'        1.0 n2026 withdata

# Not a tar archive at all.
printf 'this is not a tar archive\n' > "${HOSTILE_PKGDIR}/corrupt.nho"

printf 'valid:    %d packages in %s\n' "$(ls -1 "${PKGDIR}" | wc -l)" "${PKGDIR}"
printf 'hostile:  %d packages in %s\n' "$(ls -1 "${HOSTILE_PKGDIR}" | wc -l)" "${HOSTILE_PKGDIR}"
