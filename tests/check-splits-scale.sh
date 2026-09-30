#!/bin/bash
# Split packages: a per-part hook body must survive, and a per-part field must
# be found literally.
#
# Two defects, both in how a split part is handled by src/nhopkg.in, and both
# silent: the package built, signed, published, and only broke later.
#
#   1. The hook was extracted with
#        sed -n '/^npostinstall_dev() {/,/^}/p' | sed "s|_dev||g"
#      The substitution was meant to rename the header line, but it is global
#      and unanchored, so it rewrote the body too. A hook that installed
#      "foo_dev.conf" shipped a hook that installed "foo.conf".
#
#   2. Every per-part field was located with a grep whose pattern interpolated
#      the part name raw:
#        grep "^# Group_${part}:"
#      A part holding a metacharacter therefore matched foreign fields.
#      "Group_foo.bar:" matches "Group_fooXbar:", the first match wins, and the
#      split shipped with the wrong group without a word of warning.
#
# The client needs root and a real build, so the two steps are taken out of the
# generated tool and run verbatim in a sandbox, the way check-package-compress.sh
# does. The nhopkg-src validation runs for real, against the generated tool.
#
#   See "What is not covered" in tests/README.md.

set -u

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

clean_workspace
ensure_build
mkdir -p "${TOOLDIR}"

TOOL_SRC="${BUILDDIR}/src/nhopkg"
LIB_SRC="${BUILDDIR}/src/libnhopkg"
SRC_TOOL="${BUILDDIR}/src/nhopkg-src"
for f in "${TOOL_SRC}" "${LIB_SRC}" "${SRC_TOOL}"; do
	[[ -f "${f}" ]] || die "not found: ${f} (run meson setup first)"
done

# ---------------------------------------------------------------------------
# Taking the pieces apart
# ---------------------------------------------------------------------------

# The three nhoid helpers, verbatim, out of the generated library.
nhoid_helpers() { # <file>
	awk '
		/^nhoid_has_function\(\)/ { grab = 1 }
		grab { print }
		grab && /^}$/ { helpers++; if (helpers == 3) exit }
	' "$1"
}

# The hook block of build_nhoid_to_bin(): the part that decides which
# npostinstall()/npostremove() the binary nhoid carries.
hook_block() { # <file>
	awk '
		/^# === npostinstall logic for splitpackages ===$/ { grab = 1 }
		grab { print }
		grab && /^# === npostremove logic/ { remove = 1 }
		remove && /^fi$/ { exit }
	' "$1"
}

# The Repository block of build_nhoid_to_bin(): which repository a split lands in.
repo_block() { # <file>
	awk '
		/^\t# Force "multilib" as repo in lib32 packages$/ { grab = 1 }
		grab { print }
		grab && /^\tfi$/ { exit }
	' "$1"
}

[[ -n "$(nhoid_helpers "${LIB_SRC}")" ]] ||
	die "the nhoid helpers were not found in ${LIB_SRC}. If they moved,
    update nhoid_helpers() here, otherwise nothing below is testing anything."
HOOKS="$(hook_block "${TOOL_SRC}")"
[[ -n "${HOOKS}" ]] ||
	die "the split hook block was not found in ${TOOL_SRC}. If it moved,
    update hook_block() here, otherwise nothing below is testing anything."

# ---------------------------------------------------------------------------
# The sandbox
# ---------------------------------------------------------------------------

SB=''

# A .nhoid holding the per-part hooks and fields the two defects care about.
# "foo_dev.conf" and "lib_dev" are the body text the mangling rewrote;
# "Group_fooXbar:" is the foreign field the metacharacter picked up.
make_nhoid() { # <dir> [split names...]
	local dir="$1"; shift
	local parts="$*"
	{
		cat <<'EOF'
#%NHO-0.5
# Package Maintainer:	tester <tester@example.com>

# Name:	foo
# Version:	1.0
# Release:	1
# License:	GPL-2.0-only
# Arch:	x86_64
# Repository:	extra
# Repository_docs:	doc
# Repository_fooXbar:	DECOY-REPO
# Repository_foo.bar:	coding
# Group:	libs
# Group_dev:	devel
# Group_docs:	doc
# Group_fooXbar:	DECOY-GROUP
# Group_foo.bar:	REAL-GROUP
# Provides_dev:	foo-devel
# Provides_fooXbar:	DECOY-PROVIDES
# Provides_foo.bar:	REAL-PROVIDES
# Conflicts_dev:	foo-devel
# Backup_dev:	/etc/foo-dev.conf
# Dep_dev(post):	libc
# Dep_dev(post):	zlib
# OptionalDep_dev(post):	bash
# Dep(post):	base-runtime
# License_dev:	GPL-2.0-only AND MIT
# License_docs:	CC-BY-SA-4.0
# License_fooXbar:	DECOY-LICENSE
# License_foo.bar:	X11
# Description:	test package foo
EOF
		printf '# Splitpackage:\t%s\n' "${parts}"
		cat <<'EOF'

nbuild() {
    make
}

ninstall() {
    make install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
EOF
		local p
		for p in ${parts}; do
			cat <<EOF

ninstall_${p}() {
    make install-${p}
}

npostinstall_${p}() {
    install -Dm644 foo_dev.conf /etc/foo.conf
    ldconfig
}

npostremove_${p}() {
    rm -f /var/lib/foo_dev.state
    noemptyfuncs
}
EOF
		done
	} > "${dir}/.nhoid"
	: > "${dir}/nhoid"
}

# hook_run <part> <hook block>
#
# The block only reads the variables set here, so it runs as it runs inside
# build_nhoid_to_bin(). RESULTS holds the binary nhoid it produced.
RESULTS=''
hook_run() { # <part> <block>
	local part="$1" block="$2"
	SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
	make_nhoid "${SB}" "${part}"
	RESULTS="${SB}/nhoid"
	(
		# shellcheck disable=SC1090
		eval "$(nhoid_helpers "${LIB_SRC}")"
		echog() { printf '%s\n' "$*"; }
		echogn() { printf '%s' "$*"; }
		NHOPKG_TMPDIR="${SB}"
		INSTALL_GENERIC="npostinstall"
		REMOVE_GENERIC="npostremove"
		INSTALL_SPECIFIC="npostinstall_${part}"
		REMOVE_SPECIFIC="npostremove_${part}"
		eval "${block}"
	)
	return 0
}

# repo_run <part> : the binary nhoid the Repository block produced
REPO_OUT=''
repo_run() { # <part> <block>
	local part="$1" block="$2"
	SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
	make_nhoid "${SB}" dev docs 'foo.bar'
	: > "${SB}/nhoid"
	REPO_OUT="${SB}/nhoid"
	(
		# shellcheck disable=SC1090
		eval "$(nhoid_helpers "${LIB_SRC}")"
		NHOPKG_TMPDIR="${SB}"
		part="${part}"
		eval "${block}"
	) > /dev/null 2>&1
}

# field_run <field> <suffix> <part> : stdout of nhoid_copy_split_field
field_run() { # <field> <suffix> <part>
	SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
	make_nhoid "${SB}" dev
	(
		# shellcheck disable=SC1090
		eval "$(nhoid_helpers "${LIB_SRC}")"
		nhoid_copy_split_field "$1" "$2" "$3" "${SB}/.nhoid"
	)
}

assert_file_contains() { # <file> <needle> <label>
	[[ -f "$1" ]] && grep -qF -- "$2" "$1" && ok "$3" || bad "$3 (not found: '$2')"
}

assert_file_lacks() { # <file> <needle> <label>
	[[ -f "$1" ]] && ! grep -qF -- "$2" "$1" && ok "$3" || bad "$3 (unexpectedly present: '$2')"
}

# ---------------------------------------------------------------------------
# 1. The hook body has to survive
# ---------------------------------------------------------------------------

head1 "a per-part hook keeps its body verbatim"

hook_run dev "${HOOKS}"
assert_file "${RESULTS}" "the binary nhoid was produced"
assert_file_contains "${RESULTS}" "foo_dev.conf" "foo_dev.conf survives in npostinstall()"
assert_file_contains "${RESULTS}" "rm -f /var/lib/foo_dev.state" "the post-remove body survives too"
assert_file_contains "${RESULTS}" "npostinstall() {" "the hook was renamed to the generic name"
assert_file_contains "${RESULTS}" "npostremove() {" "so was the post-remove hook"

head1 "a body with braces and $ of its own is not mistaken for the end"
printf 'npostinstall_odd() {\n    awk \x27{print $1}\x27 f\n}\n\nnpostremove_odd() {\n    sed -n \x271d\x27 f\n}\n' > "${WORK}/odd.txt"
cp "${WORK}/odd.txt" "${SB}/.nhoid"
: > "${SB}/nhoid"
(
	NHOPKG_TMPDIR="${SB}"
	INSTALL_GENERIC="npostinstall"
	REMOVE_GENERIC="npostremove"
	INSTALL_SPECIFIC="npostinstall_odd"
	REMOVE_SPECIFIC="npostremove_odd"
	echog() { printf '%s\n' "$*"; }
	echogn() { printf '%s' "$*"; }
	eval "$(nhoid_helpers "${LIB_SRC}")"
	eval "${HOOKS}"
) >/dev/null 2>&1
assert_file_contains "${SB}/nhoid" "awk '{print \$1}' f" "an inner brace does not cut the block short"

head1 "the base package still falls back to the generic hook"
# A nhoid that only has the generic hooks: asking for a part must fall back.
SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
make_nhoid "${SB}" dev
grep -v "_dev() {" "${SB}/.nhoid" > "${SB}/.nhoid.nopart"
: > "${SB}/nhoid"
(
	NHOPKG_TMPDIR="${SB}"
	INSTALL_GENERIC="npostinstall"
	REMOVE_GENERIC="npostremove"
	INSTALL_SPECIFIC="npostinstall_dev"
	REMOVE_SPECIFIC="npostremove_dev"
	echog() { printf '%s\n' "$*"; }
	echogn() { printf '%s' "$*"; }
	# Both helpers read the nhoid they are pointed at, so pointing them at the
	# stripped copy is enough to take the fallback branch.
	nhoid_has_function() { grep -qxF "$1() {" "${NHOPKG_TMPDIR}/.nhoid.nopart"; }
	nhoid_extract_function() { printf '%s() {\n    noemptyfuncs\n}\n' "$2"; }
	eval "${HOOKS}"
) > "${SB}/out" 2>&1
assert_contains "$(cat "${SB}/out")" "Using as fallback for post-install: npostinstall()" \
	"the generic npostinstall() is used when no npostinstall_dev() exists"
assert_file_contains "${SB}/nhoid" "npostinstall() {" "and it lands in the binary nhoid"

# ---------------------------------------------------------------------------
# 2. The per-part field has to be found literally
# ---------------------------------------------------------------------------

head1 "a part holding a metacharacter matches only its own field"
assert_eq "# Group:	REAL-GROUP" "$(field_run Group '' 'foo.bar')" \
	"foo.bar takes its own Group, not the fooXbar decoy"
assert_eq "# Provides:	REAL-PROVIDES" "$(field_run Provides '' 'foo.bar')" \
	"and its own Provides"

head1 "a part with no metacharacter is unaffected"
assert_eq "# Group:	devel" "$(field_run Group '' dev)" "Group_dev is copied as Group"
assert_eq "# Backup:	/etc/foo-dev.conf" "$(field_run Backup '' dev)" "Backup_dev is copied as Backup"
assert_eq "# Group:	libs" "$(field_run Group '' '')" "an empty part copies the base field"

head1 "repeated and suffixed fields keep one line per dependency"
assert_eq "# Dep(post):	libc
# Dep(post):	zlib" "$(field_run Dep '(post)' dev)" "two Dep_dev(post) become two Dep(post)"
assert_eq "# OptionalDep(post):	bash" "$(field_run OptionalDep '(post)' dev)" \
	"OptionalDep_dev(post) keeps its own name"
assert_eq "# Dep(post):	base-runtime" "$(field_run Dep '(post)' '')" \
	"the base package copies Dep(post) as is"

head1 "a per-part description survives a name that is not an identifier"
# The description used to be stashed with "eval pkgdescription_${part}=...".
# For the part "foo.bar" that is not an assignment but a command, so it failed
# with 127 -- and the lookup returned ".bar", because it expanded the valid
# prefix and kept the rest as literal text.
SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
cat > "${SB}/.nhoid" <<'EOF'
# Name:	foo
# Description:	base description
# Splitpackage:	32bit foo.bar dev
# Description_32bit:	32-bit libraries
# Description_foo.bar:	the dotted one
EOF
split_desc() { # <part>
	(
		# shellcheck disable=SC1090
		eval "$(nhoid_helpers "${LIB_SRC}")"
		declare -A nhoid_description_by_part=()
		local part_desc
		part_desc=$(nhoid_copy_split_field "Description" "" "${1}" "${SB}/.nhoid" | head -n 1)
		part_desc="${part_desc#\# Description:}"
		part_desc="${part_desc#"${part_desc%%[![:space:]]*}"}"
		[[ -z "${part_desc}" ]] && part_desc="${pkgdescription} (${1} files.)"
		nhoid_description_by_part["${1}"]="${part_desc}"
		printf '%s' "${nhoid_description_by_part[${1}]:-<none>}"
	)
}
pkgdescription="base description"
assert_eq "32-bit libraries" "$(split_desc 32bit)" "32bit takes its own description"
assert_eq "the dotted one" "$(split_desc foo.bar)" \
	"a dotted part takes its own description instead of '.bar'"
assert_eq "base description (dev files.)" "$(split_desc dev)" \
	"a part with no description of its own gets the base one"
assert_eq "0" "$(cat "${TOOL_SRC}" "${LIB_SRC}" | grep -Ec '^[[:space:]]*eval .*pkgdescription_')" \
	"nothing builds a description variable with eval any more"

head1 "the part name is no longer interpolated into a pattern"
leftovers=$(grep -c 'grep .*"[^"]*\${part}' "${TOOL_SRC}" 2>/dev/null || true)
assert_eq "0" "${leftovers:-0}" "src/nhopkg.in no longer greps with a raw \${part}"
stray=$(grep -c 'sed "s|_${part}||g"' "${TOOL_SRC}" 2>/dev/null || true)
assert_eq "0" "${stray:-0}" "the header-rewriting sed is gone"

# ---------------------------------------------------------------------------
# 3. Validation of split names, run for real
# ---------------------------------------------------------------------------

validate() { # <nhoid> : stdout+stderr of nhopkg-src --validate
	NHOPKG_LIB="${LIB_SRC}" bash "${SRC_TOOL}" --validate "$1" 2>&1
}

good_nhoid() { # <dir> <split list>
	mkdir -p "$1"
	{
		cat <<'EOF'
#%NHO-0.5
# Package Maintainer:	tester <tester@example.com>

# Name:	foo
# Version:	1.0
# Release:	1
# License:	GPL-2.0-only
# Arch:	x86_64
# Repository:	extra
# Description:	test package foo
# Packageurl:	https://example.com/foo-1.0.tar.gz
EOF
		printf '# Splitpackage:\t%s\n' "$2"
		printf '\nnbuild() {\n    make\n}\n\nninstall() {\n    make install\n}\n\nnpostinstall() {\n    noemptyfuncs\n}\n\nnpostremove() {\n    noemptyfuncs\n}\n'
		local p
		for p in $2; do
			printf '\nninstall_%s() {\n    make install-%s\n}\n\nnpostinstall_%s() {\n    noemptyfuncs\n}\n\nnpostremove_%s() {\n    noemptyfuncs\n}\n' \
				"$p" "$p" "$p" "$p"
		done
	} > "$1/nhoid"
}

V="${WORK}/validate"
good_nhoid "${V}" "dev docs lib32"
OUT="$(validate "${V}/nhoid")"
assert_contains "${OUT}" "nhoid is valid" "a well formed 3-split nhoid validates"

head1 "an invalid split name is refused"
good_nhoid "${V}" "bad/name"
assert_contains "$(validate "${V}/nhoid")" "Invalid split name: 'bad/name'" \
	"a part with a slash is refused"

good_nhoid "${V}" "-dev"
assert_contains "$(validate "${V}/nhoid")" "Invalid split name: '-dev'" \
	"a part that does not start alphanumeric is refused"

good_nhoid "${V}" "dev dev"
assert_contains "$(validate "${V}/nhoid")" "Duplicate split name: 'dev'" \
	"a duplicated part is refused"

good_nhoid "${V}" "foo"
assert_contains "$(validate "${V}/nhoid")" "collides with the base package name" \
	"a part named like the package is refused"

head1 "no false alarms"
good_nhoid "${V}" "dev docs lib32 python3.12 foo+bar a-b"
OUT="$(validate "${V}/nhoid")"
assert_contains "${OUT}" "nhoid is valid" "dotted, plus and dash names are accepted"
assert_contains "${OUT}" "split 'docs' is built with Arch: any" \
	"the docs split is announced, not rejected"
assert_missing "${OUT}" "Invalid split name" "and nothing is refused"

head1 "a part without its ninstall_<part>() is still reported"
good_nhoid "${V}" "dev docs"
sed -i '/^ninstall_docs() {$/,/^}$/d' "${V}/nhoid"
assert_contains "$(validate "${V}/nhoid")" "Missing function: ninstall_docs()" \
	"a missing ninstall_<part>() is an error"

# ---------------------------------------------------------------------------
# 4. License_<part>: the license of the split, or the package's
# ---------------------------------------------------------------------------

head1 "a split takes its own license, or inherits the package's"
# Unlike Group or Repository, License is not optional: a split with no
# License_<part> of its own has to inherit the package's, not end up with none.
license_of() { # <part>
	(
		# shellcheck disable=SC1090
		eval "$(nhoid_helpers "${LIB_SRC}")"
		local split_license=""
		split_license=$(nhoid_copy_split_field "License" "" "${1}" "${SB}/.nhoid" 2> /dev/null | head -n 1)
		if [ -n "${split_license}" ]; then
			printf '%s' "${split_license}"
		else
			grep '^# License:' "${SB}/.nhoid"
		fi
	)
}
SB="$(mktemp -d "${WORK}/splits.XXXXXX")"
make_nhoid "${SB}" dev docs
assert_eq "# License:	GPL-2.0-only AND MIT" "$(license_of dev)" \
	"a part with a license of its own keeps it"
assert_eq "# License:	CC-BY-SA-4.0" "$(license_of docs)" \
	"so does another one, here the usual docs license"
assert_eq "# License:	GPL-2.0-only" "$(license_of 32bit)" \
	"a part with no license of its own inherits the package's"
assert_eq "# License:	GPL-2.0-only" "$(license_of '')" \
	"and so does the base package"

head1 "the license of a split survives a part holding a metacharacter"
make_nhoid "${SB}" 'foo.bar'
assert_eq "2" "$(grep -c '^# License_foo.bar:' "${SB}/.nhoid")" \
	"the old pattern would match both the decoy and the real field"
assert_eq "# License:	X11" "$(license_of 'foo.bar')" \
	"and a dotted part finds only its own, not the DECOY-LICENSE"

# ---------------------------------------------------------------------------
# 5. Repository_<part>, or extra: never the base package's
# ---------------------------------------------------------------------------

head1 "a split lands in the repository it asks for, or in extra"
REPOS="$(repo_block "${TOOL_SRC}")"
[[ -n "${REPOS}" ]] ||
	die "the Repository block was not found in ${TOOL_SRC}. If it moved,
    update repo_block() here, otherwise nothing below is testing anything."

repo_run docs "${REPOS}"
assert_file_contains "${REPO_OUT}" "# Repository:	doc" \
	"a part with Repository_<part> of its own lands there"

repo_run 'foo.bar' "${REPOS}"
assert_file_contains "${REPO_OUT}" "# Repository:	coding" \
	"and a part with a metacharacter in its name finds only its own"

repo_run 32bit "${REPOS}"
assert_file_contains "${REPO_OUT}" "# Repository:	extra" \
	"a part with no Repository_<part> lands in extra"
assert_file_lacks "${REPO_OUT}" "# Repository:	lib32-" \
	"not in the base package's repository, and not nowhere"

repo_run lib32 "${REPOS}"
assert_file_contains "${REPO_OUT}" "# Repository:	multilib" \
	"lib32 keeps going to multilib"

repo_run '' "${REPOS}"
assert_file_contains "${REPO_OUT}" "# Repository:	extra" \
	"the base package still copies its own repository"

head1 "the dead '|| extra' after the pipeline is gone"
# The old line was "grep ... | sed ... >> nhoid || echo -e '# Repository:\textra'".
# A pipeline returns the status of its last command, and sed exits 0 even when
# grep matched nothing, so the || never fired and the split got no Repository
# field at all. This harness runs with pipefail (lib.sh), which is why the
# demonstration has to turn it off: src/nhopkg.in has no "set -o pipefail" and
# neither does any tool in this project.
OUT="$(grep '^# Repository_nope:' /dev/null | sed 's/x/y/' > /dev/null || echo "the || fired")"
assert_eq "the || fired" "${OUT}" \
	"with pipefail on, as this harness has it, the || does fire"

OUT="$(set +o pipefail; grep '^# Repository_nope:' /dev/null | sed 's/x/y/' > /dev/null || echo "the || fired")"
assert_eq "" "${OUT}" \
	"without it, as src/nhopkg.in runs, the || never does"
assert_eq "0" "$(grep -c 'set -o pipefail\|set -uo pipefail' "${TOOL_SRC}" 2>/dev/null || true)" \
	"and src/nhopkg.in really does not turn it on"

# ---------------------------------------------------------------------------
# 6. Scale: many splits are not truncated
# ---------------------------------------------------------------------------

head1 "150 splits validate and are all checked"
python3 - "${V}" <<'PY'
import io, sys
d = sys.argv[1]
N = 150
parts = ["part%d" % i for i in range(1, N + 1)]
L = ["#%NHO-0.5", "# Package Maintainer:\ttester <tester@example.com>", "",
     "# Name:\tfoo", "# Version:\t1.0", "# Release:\t1", "# License:\tGPL-2.0-only",
     "# Arch:\tx86_64", "# Repository:\textra", "# Description:\tscale test",
     "# Packageurl:\thttps://example.com/foo-1.0.tar.gz",
     "# Splitpackage:\t" + " ".join(parts), "",
     "nbuild() {", "    make", "}", "", "ninstall() {", "    make install", "}",
     "", "npostinstall() {", "    noemptyfuncs", "}", "",
     "npostremove() {", "    noemptyfuncs", "}", ""]
for p in parts:
    L += ["ninstall_%s() {" % p, "    make install", "}", "",
          "npostinstall_%s() {" % p, "    noemptyfuncs", "}", "",
          "npostremove_%s() {" % p, "    noemptyfuncs", "}", ""]
io.open(d + "/nhoid", "w", encoding="utf-8").write("\n".join(L))
PY
OUT="$(validate "${V}/nhoid")"
assert_contains "${OUT}" "nhoid is valid" "150 splits validate"

# Remove three ninstall_<part>() and expect exactly three errors: if the loop
# stopped early, or walked off, the count would not be three.
python3 - "${V}/nhoid" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
for part in ("part7", "part42", "part150"):
    s = s.replace("ninstall_%s() {\n    make install\n}\n\n" % part, "")
io.open(p, "w", encoding="utf-8").write(s)
PY
OUT="$(validate "${V}/nhoid")"
assert_eq "3" "$(grep -c 'Missing function: ninstall_part' <<<"${OUT}")" \
	"exactly the three missing ones are reported out of 150 splits"

# ---------------------------------------------------------------------------
# The defects, reproduced
# ---------------------------------------------------------------------------

head1 "mutants"

MUT="${TOOLDIR}/nhopkg-mutant"
cp "${TOOL_SRC}" "${MUT}"
apply_mutant_to "${MUT}" pre-split-hook-mangling
[[ "$(hook_block "${MUT}")" == "${HOOKS}" ]] &&
	bad "the mutant did not change the hook block" ||
	ok "the mutant puts the mangling sed back"
hook_run dev "$(hook_block "${MUT}")"
assert_file_lacks "${RESULTS}" "foo_dev.conf" \
	"the old sed renames the body: foo_dev.conf becomes foo.conf"
assert_file_contains "${RESULTS}" "/etc/foo.conf" "which is the damage, visible right here"

head1 "a part with a metacharacter used to pick a foreign field"
# The pattern the old code built for the part "foo.bar", run on the sandbox
# nhoid. index() is what the fix uses; this is the grep it replaced.
assert_eq "2" "$(grep -c "^# Group_foo.bar:" "${SB}/.nhoid")" \
	"the old pattern matches both the decoy and the real field"
assert_eq "# Group_fooXbar:	DECOY-GROUP" "$(grep "^# Group_foo.bar:" "${SB}/.nhoid" | head -n 1)" \
	"and the decoy comes first, so the old code shipped the wrong group"
assert_eq "1" "$(field_run Group '' 'foo.bar' | wc -l)" \
	"the helper returns one line instead"
