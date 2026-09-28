# Test suite

Tests for nhopkg, run against the **real generated tools** from the build
directory. There is no mock of the code under test: `tests/lib.sh` copies
`builddir/src/nhopkg-repos` and only replaces the two gates that are not what
is being tested, the root check and GPG.

```sh
tests/run-all.sh                        # everything
tests/run-all.sh check-add-to-repo.sh   # one file
meson compile -C builddir check         # the same, through meson
```

Everything lands in `builddir/tests-tmp/` (override with `NHOPKG_TEST_TMPDIR`),
which is inside the ignored build directory, so the source tree stays clean.
Logs of the tool's own output are written to `builddir/tests-tmp/logs/`.

## Files

| File | What it does |
|---|---|
| `lib.sh` | Shared harness. Not a test. Build freshness, the tool under test, the crypto stub, reading a repository, assertions. |
| `make-packages.sh` | Generates the `.nho` packages. Run on its own to look at them. |
| `check-add-to-repo.sh` | Validation, rejection, and index consistency. |
| `check-retired-metadata.sh` | Retiring a version must not leave its entry behind. |
| `run-all.sh` | Runs every `check-*.sh` and summarises. |

Naming matters: the files are `check-*.sh`, not `test-*.sh`, because
`.gitignore` has a `test-*` rule that would swallow them.

## What `check-add-to-repo.sh` covers

- **A valid batch lands.** Five packages are added in one call and every id on
  disk is in `core.packages`. Includes a metapackage, which has no
  `data.tar.zst` and therefore no file list by design, and a package whose file
  name contains a space.
- **A name that is a prefix of another does not eat it.** `alpha-devel` is
  published first and `alpha` second, because the old purge used a `name-*`
  glob and unindexed `alpha-devel` for good as soon as `alpha` was added.
- **Hostile packages are rejected with a reason.** Six of them, each breaking a
  different rule: a corrupt archive, a glob in the name, a slash, a traversal,
  an empty version, a shell metacharacter in the version. The batch keeps
  going, the valid package in it still goes in, and the exit status is 1.
- **The audit catches what it was written for.** See "mutants" below.

## What `check-retired-metadata.sh` covers

Publishing `zeta 1.0-rc1` and then adding `zeta 1.0` retires the prerelease.

- **The metadata goes with the package.** The retired id leaves `core.packages`
  and `core.files`, and the name aliases are still published, pointing at the
  version that survived. Before this, the index advertised a version that could
  not be downloaded.
- **An entry with no archive behind it is reported, not failed.** The message
  names the exact id and says which index it is in, the summary counts them, and
  the exit status stays 0. Failing would break every repository already damaged,
  with no way out.
- **2a does not repair an already damaged repository.** Purging is coupled to
  retiring, and the retired `.nho` is long gone, so nothing triggers it. Stated
  as a test so it stays a known limitation rather than a surprise.

## Mutants

Some tests run the tool against a deliberately broken copy, to prove the test
would fail if the fix were reverted. The mutant is applied to the copy in
`builddir/tests-tmp/bin/`, never to the source.

| Mutant | Restores | Used by |
|---|---|---|
| `pre-fase1` | the `name-*` purge globs | `check-add-to-repo.sh` |
| `pre-fase2a` | retiring a version without purging its index metadata | `check-retired-metadata.sh` |

`setup_tool <mutant>` in `lib.sh` holds the markers. They are exact lines of
`src/nhopkg-repos.in`, so **reformatting those lines breaks the mutants**: the
harness stops with a message naming the marker instead of failing the test for
an unrelated reason. If that happens, update the marker in `lib.sh`.

The same applies to the two root checks that `lib.sh` neutralises.

## A trap worth knowing about

meson generates the scripts with `configure_file()`, which runs at **configure**
time. `ninja` alone does not pick up an edit to a `.in` file, so a test run
against a stale binary reports a working fix as a broken one. `ensure_build` in
`lib.sh` compares the timestamps of `src/*.in` against their output in
`builddir/src/` and reconfigures when they differ. Do not remove that check.

## What is not covered

- **The client.** Everything here drives `nhopkg-repos`. `nhopkg` itself
  (`nhopkg -S <pkg>`) needs real root, and the client reads the repository from
  a different path than the publisher writes it: `nhopkg-repos` writes
  `repo/<repo>/packages/`, the search and `-t` read the flat `repo/packages/`.
  Two layouts coexist; resolving that is a prerequisite for testing the client
  at all.
- **`nhopkg`, `nhouser`, `nhopicker`, `nhoget`, `nhopkg-src`** and the overlay
  tool: no tests yet.
- **Package hooks inside a chroot.** The prelude that gives `npostinstall` and
  `npostremove` the target's config and `libnhopkg` is only verified statically
  (syntax, `@prefix@` substitution, invocation from both hooks). Running it
  needs root and a real `.nho` with hooks.

## Adding a test

1. Put it in `check-<what-it-checks>.sh` and source `lib.sh`.
2. `clean_workspace`, `ensure_build`, `setup_tool clean`, then generate packages
   with `make-packages.sh` if you need them.
3. Use the assertions (`assert_status`, `assert_contains`, `assert_in_list`,
   `assert_file`, ...) and end with `exit "$(t_summary)"`.
4. Run it. Then make sure it fails when it should: break the tool, or use a
   mutant, and check that the test notices.
