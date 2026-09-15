# AGENTS.md - Nhopkg Development Guide

## Build System

**Meson/Ninja** is used (not Autotools).

```bash
# Configure
meson setup builddir \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  -D binlocate=plocate

# Build
ninja -C builddir

# Install
sudo ninja -C builddir install
```

## Key Options

- `-D binlocate=plocate` - Use plocate (Arch/Fedora), use `locate` for mlocate (Debian/Ubuntu)
- `-D repo-version=n2026` - Repository version segment (n2026, n27, etc.)
- `-D repo-arch=x86_64` - Repository architecture segment (x86_64, x86_64-musl, etc.)
- `-D repo-url-core`, `-D repo-url-extra`, `-D repo-url-multilib` - Override individual repo URLs (empty = auto-built from repo-version + repo-arch)
- `-D libc=glibc` - C library variant: `glibc` or `musl` (affects NHOHOLD, active repos, multilib)
- `-D git-branch=` - Default Git branch/tag for --super-build (e.g., glibc, musl)
- `-D git-url` - Default GIT source repository
- `-D download-jobs=N` - Parallel downloads for dependencies (default 4)

## Development Commands

```bash
# Reconfigure after editing meson.build
meson setup builddir --reconfigure

# Rebuild after changes
ninja -C builddir
```

## Required Tools

- bash, tar, zstd, sha256sum, make, autodf2
- grep, awk, sed, find
- plocate (or locate)

## Optional Tools

- gettext (i18n), wget/curl (downloads), git, ldconfig, gpg

## Entry Points

- Main script: `src/nhopkg.in` → installed as `/usr/bin/nhopkg`
- Download tool: `src/nhoget.in` → installed as `/usr/bin/nhoget`
- Source tool: `src/nhopkg-src.in` → installed as `/usr/bin/nhopkg-src`
- Repo tool: `src/nhopkg-repos.in` → installed as `/usr/bin/nhopkg-repos`
- Overlay tool: `src/nhopkg-overlay.in` → installed as `/usr/bin/nhopkg-overlay`
- User tool: `src/nhouser.in` → installed as `/usr/bin/nhouser`
- Picker tool: `src/nhopicker.in` → installed as `/usr/bin/nhopicker`
- Library: `src/libnhopkg.in` → `/usr/lib/nhopkg/libnhopkg`
- Config: `src/nhopkg.conf.in` → `/etc/nhopkg/nhopkg.conf`

## Library Architecture

- `libnhopkg.in`: Base functions (`echog`, `get_basic_data`, `get_nhoid_data`, `check_if_ok`, `check_package_hash`, `nhopicker`, etc.)
- `libnhopkg_udepsys.in`: Unified Dependency Resolution System (`dep_resolve_from_nhoid`, `dep_install_queue`, `dep_check_conflicts`, `version_compare`, `get_repo_url`, etc.)
- `libnhopkg_download.in`: Unified download system (nhoget backends: GNU wget, curl, BusyBox wget; VCS clone)
- `libnhopkg_crypto.in`: GPG signing/verification helpers
- `libnhopkg_nhouser.in`: `nhouser()` user/group management (shadow-utils + BusyBox dual backend)
- `_dep_install_single()` and `_dep_install_all_from_queue()` remain in `nhopkg.in` (too coupled to install/business logic)

## Legacy Code (always ignore)

`src/legacy/` contains old patches (autopackage, tgz2nho) that are **not** part of the
current codebase. Never analyze, reference, or document them, and never use them as a
source for current behavior or documentation updates.

## Internationalization

Translations in `po/*.po`. After adding new strings, regenerate with Meson build
(`meson compile -C builddir update-translations`).

## No Test Suite

This project has no automated tests. Verify manually with installed binary.

## PLAN / PROPOSAL Requests

When the user asks for a **PLAN** or **PROPOSAL**, ONLY plan/document. Do **not**
write, edit, or implement code. Write the plan as a document under `PROPOSALS/`
(see existing proposals there for format) and wait for explicit approval before
implementing anything.

## Git Workflow

- The user always runs `git push` themselves; never push to remote.
- Only commit when explicitly asked. Commit messages must follow Conventional
  Commits style — always prefix with one of `fix`, `feat`, `refactor`, `docs`,
  `chore`, `build`, `test`, `perf`, `style`, `revert` (optionally scoped, e.g.
  `fix(nhopkg):`). This machine-readable history is what drives NEWS entries and
  changelogs, so the prefix must reflect the change honestly.
- Keep commits small and atomic, as Linus Torvalds advocates: one logical change
  per commit, self-contained and reverable. No hidden/merged-in extras, no
  unrelated edits inside a commit.

## Versioning Strategy

Semantic-versioning-style `X.Y.Z` (version lives in `meson.build`). The cadence is
designed to keep changelogs small, readable and honest:

| Segment | What lands | Bump trigger |
|---|---|---|
| `X` (major) | Breaking changes: removed commands/options, incompatible nhoid or config format | Any breaking change |
| `Y` (minor) | New features / improvements | Every ~10–15 commits or ~1 month, whichever first |
| `Z` (patch) | Only bug fixes | Every ~5 fixes, or immediately for hotfixes |

Rules:

- Only **user-visible** changes get changelog bullets. Internal refactors and
  tooling churn are aggregated into a single bullet or omitted entirely.
- If a minor release would exceed ~30 bullets, cut it loose earlier (release
  more often, never let a changelog balloon).
- Generate the raw list with `git log <prev-tag>..HEAD --pretty=format:'- %s'`,
  group by scope/theme, then edit.
- `feat` = minor bump candidate, `fix` = patch candidate, breaking change = major.

## Release Workflow (v1.0+)

Always finish a release with this flow, in order:

1. Bump the version in `meson.build` (and docs if needed).
2. Add the release entry to `NEWS` (follow the existing format, cover all commits
   since the previous tag, grouped by theme).
3. Write the GitHub release notes file `changelog-<version>.md` following the
   format of `changelog-1.0.md` (this is the standard).
4. Commit the tracked changes (e.g. `docs: add <version> release notes to NEWS`).
   Changelog files (`changelog*`) are gitignored by design — keep them local.
5. **Create the annotated tag at the end of the flow**, pointing at the release
   commit:
   ```bash
   git tag -a <version> -m "<summary>"
   ```
   If the tag already exists, delete it first (`git tag -d <version>`) and recreate
   it so it points at the release commit.
6. Never push tags/commits; the user does that and creates the GitHub Release
   (with `gh release create <version> --notes-file changelog-<version>.md`).