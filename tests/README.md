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
| `check-package-compress.sh` | The client's packaging step: the installed file list has to reach `data.tar.zst` whole, and a split must search it once. |
| `check-splits-scale.sh` | Split packages: a hook body has to survive, and a per-part field has to be found literally. |
| `check-split-git-clone.sh` | Split packages from a git source: N parts must clone once, not N times. |
| `check-split-source-reuse.sh` | Split packages from a tarball: N parts must not decompress it once each. |
| `check-installed-size.sh` | `Installed-Size` must count each installed path once, however often the list names it. |
| `check-packaging-no-host-writes.sh` | `--packaging` must not touch the live system: the installed package, the dependencies, the caches and the locate database. |
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

## What `check-package-compress.sh` covers

The last step of a build: the list of installed files becomes `data.tar.zst`.

`tar -C dir cp --files-from=list` is a trap. The `cp` is GNU tar's old-style
bundling of `-c` and `-p`, and it is only parsed when the first argument is not
an option. With `-C` in front, GNU tar and BusyBox tar both read the line as "no
operation letter", write nothing and exit non-zero. The error went to
`/dev/null` and the status a pipeline returns is `zstd`'s, not `tar`'s, so the
build carried on and published an archive that was valid and completely empty: a
package that installs and brings nothing.

- **Both branches of the step run whole.** `--packaging` (file list relative to
  DESTDIR, `tar -C`) and a live install (absolute paths, no `-C`). The archive
  holds both files, the mode survives, and the hardlink between them survives.
  This is checked with GNU tar and, when `builddir/.nhopkg-tools/busybox` is
  there, with the BusyBox applet as well.
- **The status is not lost again.** `tar`'s own exit status is read through
  `PIPESTATUS[0]`, and an empty `data.tar.zst` is refused: the mutants below
  show the guard aborting the build instead of shipping the empty archive.
- **The defect itself is written down as a test.** With both changes reverted,
  the step is asserted to exit 0 and leave a 0-byte payload. That is the bug,
  kept visible so it is not forgotten rather than so it is tolerated.
- **A split searches the files once.** `build_make_binary_package()` has always
  done the search itself. The split loops used to do it as well, right before
  calling it, and `installed.log` is opened with `>>`: every path went in twice,
  so each split shipped duplicate members in `data.tar.zst` and an
  `Installed-Size` summed over the doubled list. Both split loops are asserted
  to have no extra search, and the mutation is demonstrated by appending the
  same path twice and watching the archive grow a second member. This was not a
  `--packaging` defect: it hit every split, packaging or not, because the
  packaging guard plays no part in it.

The client needs root, so the tool is not run as a program. The step is
*extracted* from the generated `builddir/src/nhopkg` and run verbatim in a
sandbox, against the same file list the build writes. If the step in
`src/nhopkg.in` moves or is renamed, `compress_step()` stops finding it and the
test dies with a message instead of passing quietly.

## What `check-splits-scale.sh` covers

A split part is not an opaque token: it is part of a field name
(`# Group_dev:`), of a function name (`npostinstall_dev()`) and of a file name
(`foo-dev.conf`). Two places interpolated it straight into a pattern, and both
failed silently -- the package built, was signed, was published, and only
broke later.

- **A hook body survives its own name.** The hook was taken with
  `sed -n '/^npostinstall_dev() {/,/^}/p' | sed "s|_dev||g"`, the substitution
  being meant to rename the header. It is global and unanchored, so it rewrote
  the body too: a hook installing `foo_dev.conf` shipped a hook installing
  `foo.conf`. The body, the braces and the `$` in it are now checked to arrive
  untouched, and the base package still falls back to the generic hook.
- **A per-part field is found literally.** `grep "^# Group_${part}:"` took the
  part raw. `Group_foo.bar:` also matches `Group_fooXbar:`, the first match wins,
  and the split shipped with the wrong group. Both the literal lookup and the
  repeated/suffixed forms (`Dep_dev(post)` twice becoming two `Dep(post)`) are
  checked, with a decoy field in the fixture.
- **A split lands in `extra` unless it asks for another repository.** The
  fallback used to be a `|| echo` after a pipeline, which never fired: without
  `pipefail` a pipeline returns its last command's status and `sed` exits 0 even
  when `grep` matched nothing. A split with no `Repository_<part>:` was published
  with no `Repository` field at all. The test pins the difference between the
  harness, which runs with `pipefail`, and `src/nhopkg.in`, which does not.
- **A split takes its own license, or inherits the package's.** `License` is not
  optional, so this is the one field where having none of your own is not the same
  as having none. A `docs` split under `CC-BY-SA-4.0` is the case that motivates
  it.
- **Split names are validated.** A part with a `/`, a part not starting
  alphanumeric and a duplicated part are refused, and a part named like the
  package is reported as a collision. `docs`, `python3.12`, `foo+bar` and `a-b`
  are accepted, and `docs` gets its `Arch: any` notice instead of an error.
- **150 splits are not truncated.** A 150-part nhoid validates, and removing
  three `ninstall_<part>()` out of the 150 yields exactly three errors -- if the
  loop stopped early or walked off, the count would not be three.
- **The defects are written down as tests.** The mutants below put both
  interpolations back and are asserted to reproduce the damage.

The client needs root, so the hook block is *extracted* from the generated
`builddir/src/nhopkg` and run verbatim in a sandbox, the way
`check-package-compress.sh` does; the three `nhoid_*` helpers are extracted from
the generated `builddir/src/libnhopkg`. If any of them move, the test dies with a
message instead of passing quietly. The validation half runs `nhopkg-src
--validate` for real, against the generated tool.

## What `check-split-git-clone.sh` covers

- **The clone outlives the per-part cleanup.** The split loop keeps its clone
  outside `${NHOPKG_TMPDIR}`, which `cleanup_tmp_dir()` wipes at the top of
  every part. This is asserted on the generated client, because the failure is
  that the destination *looks* fine and the cache branch is simply never
  reached.
- **The loop does not delete the clone it just made**, and copies the nhoid out
  instead of moving it. Both used to be harmless because the clone was thrown
  away afterwards; once it is reused, a tracked file taken out of it has to
  leave a clone the next part can still read.
- **`nhoget_vcs_git()` really does reuse a destination that already holds a
  clone.** One local repository asked for three times into one destination: one
  `git clone`, two `Repository already exists. Updating...`. `git` is shimmed
  through `PATH` to count the clones, because that function prints "Cloning Git
  repository" on every call, reuse included, so its log line cannot tell the two
  apart. The repository is a local path, so the test needs no network.

- **The clone is cleaned with the build tree.** It has to survive
  `${NHOPKG_TMPDIR}` to be reused, so its lifetime is tied to the build tree's:
  `cleanup_build_dir()` collects both and asks once about both. Without that it
  would be a full clone of the upstream left on disk with nothing able to remove
  it. The test also checks that nothing is asked when there is nothing to remove,
  since that function runs once per part.

Reverting the clone fix makes four of its assertions fail, one per changed line.

This is a pure performance fix, so there is no mutant here and there is nothing
to compare byte for byte: the same `.nho` comes out either way, only the number
of clones differs. What is asserted is the invariant that makes the fix
possible -- a clone that survives to the next part.

## What `check-split-source-reuse.sh` covers

- **A tree with the source in it is kept.** `fetch_tarball_source()` returns
  without reaching `download_with_hash_check()`, which is asserted by making
  the download fail: a run that skips it succeeds, a run that attempts it does
  not. The URL is unresolvable, so the test needs no network.
- **An empty directory is not a tree.** `build_prepare()` creates the directory
  before it knows whether the unpack will succeed, so skipping on its presence
  would turn a failed download into a silent build against nothing. With no tree
  and with an empty one, the download is attempted and its failure is reported.
- **The VCS path is not caught by it.** `fetch_vcs_source()` runs `git clean
  -fd` on the tree when it updates, so a guard in front of it would change what
  each part gets. The test asserts the reuse check stays below the VCS dispatch.

Removing the guard fails two assertions; restoring it makes them pass again.

What this is not: it does not unpack once per build. `cleanup_build_dir()` runs
at the end of every part and deletes the tree under `-R`, so in recursive mode
the work is still repeated. The win is there only when the tree is kept between
parts.

## What `check-installed-size.sh` covers

- **A path listed more than once is counted once.** The per-part file list can
  name the same path several times, and the loop summing a `du` per line used to
  add it every time, so a split package declared about twice its real size. On
  linux-firmware that was 3248 KB declared against 1617 KB of files, 2.01x. The
  test covers the same path listed twice, five times, and a single large file
  listed four times, and pins the answer to the real on-disk total.
- **A listed path that no longer exists is skipped** without failing the block.
- **The log keeps its duplicates.** The block deduplicates the temporary copy it
  reads, on purpose: the packaging step reads the log and must keep seeing what
  it always saw. If that ever changes, the tar file list changes with it.
- **The dedup is in place, and not a pipe.** The loop assigns `PACKAGE_SIZE`, so
  piping the sorted output into it would run the loop in a subshell and the
  assignment would be lost, leaving `Installed-Size` at 0. The test fails if a
  pipe appears between the `sort` and the loop.

Removing the `sort -u` fails five assertions. `sort -u` with `-o FILE` works in
both GNU and BusyBox, and the codebase already uses it elsewhere.

## What `check-packaging-no-host-writes.sh` covers

`--packaging` promises a build that does not touch the live system, and it used
to mutate it in four places: it uninstalled the package that was already
installed, installed dependencies into `/`, refreshed the system caches and
rewrote the locate database. The build kept going in every case, so the only
warning was the damage itself.

- **The installed package is left alone.** The guard is inside
  `check_if_installed_package()`, so all four call sites get it. In packaging
  mode the run returns 0 with no prompt, no `backup_config_files` and no
  `remove_package`; outside packaging mode all three still happen.
- **Dependencies are never installed.** `dep_packaging_stop_if_missing()`
  names the missing required ones and exits 1 (the build's own `cleanup_tmp_dir`
  first), warns and carries on when only optional ones are missing, and says
  nothing when there is nothing to install. Both call sites, build and
  super-build, are extracted as a block and run three ways: packaging decides,
  packaging stops, live installs.
- **The locate database is left alone**, and `updatedb` still rewrites it
  outside packaging mode.
- **No cache of this system is touched.** All eight commands the shooter runs
  are shimmed through `PATH`, which is also what makes the control run safe to
  do on this machine: outside packaging mode the shims are what runs.
- **The defects are written down as tests.** The four mutants below put each
  guard back to the code it replaced, and each run reproduces the damage.

The build needs root, so nothing here runs as a program. Each function is
*extracted* from the generated tool and run verbatim in a sandbox, with
everything it calls stubbed to write into a canary file: a missing guard shows
up as a canary that is no longer empty. The dependency guard lives at its call
sites rather than inside a function, so the enclosing block is extracted whole.
If any of them move, `fn_body()` and `dep_block()` stop finding them and the
test dies with a message instead of passing quietly.

## Mutants

Some tests run the tool against a deliberately broken copy, to prove the test
would fail if the fix were reverted. The mutant is applied to the copy in
`builddir/tests-tmp/bin/`, never to the source.

| Mutant | Restores | Used by |
|---|---|---|
| `pre-fase1` | the `name-*` purge globs | `check-add-to-repo.sh` |
| `pre-fase2a` | retiring a version without purging its index metadata | `check-retired-metadata.sh` |
| `pre-explicit-tar-opts` | the old-style `cp` bundling after `-C` | `check-package-compress.sh` |
| `pre-compress-guard` | no `PIPESTATUS` check, no refusal of an empty archive | `check-package-compress.sh` |
| `pre-split-double-search` | the extra `build_search_for_files` in both split loops | `check-package-compress.sh` |
| `pre-split-hook-mangling` | the `s|_${part}||g` header rewrite in the split hooks | `check-splits-scale.sh` |
| `pre-split-field-regex` | the `grep "^# Group_${part}:"` per-part field lookup | `check-splits-scale.sh` |
| `pre-packaging-keep-installed` | the packaging guard in `check_if_installed_package()` | `check-packaging-no-host-writes.sh` |
| `pre-packaging-install-deps` | the packaging guard at both dependency call sites | `check-packaging-no-host-writes.sh` |
| `pre-packaging-shooter` | the packaging guard in `shooter_updates()` | `check-packaging-no-host-writes.sh` |
| `pre-packaging-updatedb` | the packaging guard in `update_local_db()` | `check-packaging-no-host-writes.sh` |

`setup_tool <mutant>` in `lib.sh` applies a mutant to `nhopkg-repos`;
`apply_mutant_to <file> <mutant>` applies one to any other copy, which is what
the client's mutants use. Their markers are exact lines of the source, so
**reformatting those lines breaks the mutants**: the harness stops with a
message naming the marker instead of failing the test for an unrelated reason.
If that happens, update the marker in `lib.sh`.

The same applies to the two root checks that `lib.sh` neutralises.

## A trap worth knowing about

meson generates the scripts with `configure_file()`, which runs at **configure**
time. `ninja` alone does not pick up an edit to a `.in` file, so a test run
against a stale binary reports a working fix as a broken one. `ensure_build` in
`lib.sh` compares the timestamps of `src/*.in` against their output in
`builddir/src/` and reconfigures when they differ. Do not remove that check.

## What is not covered

- **The client.** Everything here drives `nhopkg-repos`. `nhopkg` itself
  (`nhopkg -S <pkg>`) needs real root, and that is the only reason it is not
  covered: the rest of the path is the same code under a different entry point.
  The layout is not a problem, by the way, and it is worth writing down so
  nobody wastes time on it: the publisher copies the `.nho` flat into
  `$REPO_ROOT/<repo>/` (`nhopkg-repos.in:701`) and the client builds exactly
  that remote filename from the `# OS:`/`# Arch:` fields in the index
  (`libnhopkg_udepsys.in:674`). The `repo/<repo>/packages/` directory the
  client uses holds the *unpacked* index, the plain nhoid files, not payloads.
- **`nhouser`, `nhopicker`, `nhoget`** and the overlay tool: no tests yet.
- **The client's build and install path**, beyond the packaging step of
  `check-package-compress.sh`, the split hooks of `check-splits-scale.sh`, the
  clone destination of `check-split-git-clone.sh` and the four packaging guards
  of `check-packaging-no-host-writes.sh`. Those four take what they check out of
  the generated tool and run it in a sandbox; the rest of a build, and the
  install itself, still needs root. In particular, no test builds a whole
  `.nho` from a split, so "the same package builds the same bytes before and
  after a performance fix" is asserted by reading the code, not by running it.
- **`nhopkg-src`**, beyond `--validate`'s split handling.
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
