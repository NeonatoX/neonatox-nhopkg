# nhopkg-src — Source Package Project Tool

## Overview

`nhopkg-src` creates, validates, and builds source package projects for nhopkg. It works with `.srcnho` files — flat tarballs containing the `nhoid` metadata file plus patches and extra files, which `nhopkg -bv` uses to download, compile, and install binary packages.

## Commands

### `--init [<name>]`

Creates a new source package project directory. Interactive prompts guide you through the required and optional fields. If `<name>` is given as an argument, it is used as the package name and directory name without prompting.

**Prompts:**

| Field | Required | Default | Notes |
|---|---|---|---|
| Name | Yes | — | From argument or interactive prompt |
| Version | No | `1.0` | |
| Release | No | `n2026` | |
| Maintainer name | No | `$USER` | Predefine with `PKG_MAINTAINER_NAME` |
| Maintainer email | No | `$USER@$HOSTNAME` | Predefine with `PKG_MAINTAINER_EMAIL` |
| License | No | `GPL-3.0-only` | |
| Arch | No | `x86_64` | |
| URL | No | (empty) | Upstream project website |
| Description | No | (empty) | |
| Packageurl | **Yes** | — | Tarball URL or `git+<url>` for git sources |
| Packageref | **Yes** if git | — | Tag, commit, or branch reference |
| SHA256 download | Only for tarballs | Y/n | Downloads the tarball and calculates SHA256 automatically. If skipped, writes `## SHA256:` as a reminder |
| Splitpackage | No | (space-separated) | e.g. `dev lib docs` |
| Provides | No | (space-separated) | |
| Conflicts | No | (space-separated) | |

**Project structure created:**

```
<name>/
├── nhoid              # Package metadata and build functions
├── sources/           # Downloaded tarballs (not included in .srcnho)
├── patches/           # *.patch and *.diff files (included in .srcnho)
├── others/            # Extra files (included in .srcnho)
└── build/             # Build directory (not included in .srcnho)
```

**Generated nhoid template:**

The `nhoid` file includes:
- Header `#%NHO-0.5` with all metadata fields
- Placeholder functions: `nbuild()`, `ninstall()`, `npostinstall()`, `npostremove()` (all set to `noemptyfuncs`)
- For split packages: generated `ninstall_<part>()`, `npostinstall_<part>()`, `npostremove_<part>()` for each part
- Commented-out dependency fields (`## BuildDep:`, `## Dep(post):`, etc.) for manual editing

See [`formato-nhoid.md`](formato-nhoid.md) for detailed field descriptions.

**Examples:**

```bash
# Create a project interactively
nhopkg-src --init

# Create a project with a given name (skips name prompt)
nhopkg-src --init myapp

# Create a metapackage project (targets a package group, no source)
nhopkg-src --init myapp --meta
```

With `--meta`, the tool creates a **metapackage**: a package with no source
files that only depends on the packages of a target group. Metadata is filled
automatically (`License: CUSTOM`, `Arch: any`, URL and description derived from
the name), the `Target group name` prompt is shown, the group's packages are
resolved from repository metadata and written as `# BuildDep:`/`# Dep(post):`
entries, and no Packageurl/hash/VCS prompts are asked. The resulting project
packages and installs normally, but `nbuild()` stays `noemptyfuncs` and a
`README.meta` is generated on install.

Tarball nhoid (after download for SHA256):

```nhoid
#%NHO-0.5
# Package Maintainer:	user <user@host>

# Name:	myapp
# Version:	1.0
# Release:	n2026
# License:	GPL-3.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://example.com/myapp
# Description:	My application
# Packageurl:	https://example.com/myapp-1.0.tar.gz
# SHA256:	abc123def456...  myapp-1.0.tar.gz
## BuildDep:	(add your build dependencies here)
## OptionalBuildDep:	(add your optional build dependencies)
## Dep(post):	(add your runtime dependencies)
## OptionalDep(post):	(add your optional runtime dependencies)

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
```

Tarball without SHA256 (reminder left):

```nhoid
# Packageurl:	https://example.com/myapp-1.0.tar.gz
## SHA256:	<pendiente>  myapp-1.0.tar.gz
```

Git source nhoid:

```nhoid
# Packageurl:	git+https://github.com/user/myapp
# Packageref:	v1.0
```

With split packages:

```nhoid
# Splitpackage:	dev lib

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_dev() {
    noemptyfuncs
}

npostinstall_dev() {
    noemptyfuncs
}

npostremove_dev() {
    noemptyfuncs
}

ninstall_lib() {
    noemptyfuncs
}

npostinstall_lib() {
    noemptyfuncs
}

npostremove_lib() {
    noemptyfuncs
}
```

---

### Predefined answers via environment variables

Every `--init` prompt can be pre-answered by exporting the matching environment
variable. When the variable is already set, `nhopkg-src` prints its value and
skips the question. This lets packagers define defaults once (for example in
their shell profile) and generate projects in one shot.

| Variable | Replaces prompt | Example value |
|---|---|---|
| `PKG_NAME` | Package name | `myapp` |
| `PKG_VERSION` | Version | `1.0` |
| `PKG_RELEASE` | Release | `n2026` |
| `PKG_MAINTAINER_NAME` | Maintainer name | `Jane Doe` |
| `PKG_MAINTAINER_EMAIL` | Maintainer email | `jane@example.com` |
| `PKG_GROUP` | Package group | `apps libs` |
| `PKG_REPOSITORY` | Repository | `extra` |
| `PKG_LICENSE` | License | `GPL-3.0-only` |
| `PKG_ARCH` | Architecture | `x86_64` |
| `PKG_URL` | Upstream URL | `https://example.com` |
| `PKG_DESCRIPTION` | Description | `My application` |
| `PKG_PACKAGEURL` | Package URL (tarball or `git+<url>`) | `https://example.com/myapp-1.0.tar.gz` |
| `PKG_PACKAGEREF` | VCS reference (git/svn/hg) | `v1.0` |
| `PKG_HASH_TYPE` | Checksum type | `sha256` |
| `PKG_DOWNLOAD` | Download to calculate checksum | `no` |
| `PKG_META_GROUP` | Target group (only with `--meta`) | `ttf-fonts` |
| `PKG_SPLIT`, `PKG_PROVIDES`, `PKG_CONFLICTS` | Space-separated lists | `dev lib` |

Notes:
- An export counts as "set" even when empty is not allowed (required fields); to
  keep the prompt you must `unset` the variable.
- `PKG_DOWNLOAD` accepts `y`/`yes`/`n`/`no` (case-insensitive).
- Space-separated lists (`PKG_GROUP`, `PKG_SPLIT`, `PKG_PROVIDES`,
  `PKG_CONFLICTS`) are used as-is.
- The maintainer email defaults to `$USER@$HOSTNAME`; the name defaults to
  `$USER`. They are written to the nhoid as a single `# Package Maintainer:
  Name <email>` field.

**Example:** create a metapackage without any prompt:

```bash
export PKG_MAINTAINER_NAME="Jane Doe"
export PKG_MAINTAINER_EMAIL="jane@example.com"
export PKG_META_GROUP="ttf-fonts"
nhopkg-src --init fonts-meta --meta
```

---

### `--createpackage [--force]`

Packages the current project directory into a flat `.srcnho` tarball.

**What is included:**
- `nhoid` (required, validated first via `--validate`)
- `patches/*.patch` and `patches/*.diff` files
- `others/*` files (any type)

**What is NOT included:**
- `sources/` directory
- `build/` directory

**Behavior:**
- Refuses to overwrite an existing `.srcnho` file unless `--force` is given
- The output file is named `<name>-<version>-<release>.srcnho`

**Example:**

```bash
cd myapp/
nhopkg-src --createpackage
# Creates: myapp-1.0-n2026.srcnho

# Overwrite existing:
nhopkg-src --createpackage --force
```

---

### `--buildpackage`

Builds the `.srcnho` package using `nhopkg -bv` with `sudo -k` (always prompts for password).

**Flow:**
1. Reads `nhoid` in the current directory to get `<name>-<version>-<release>`
2. Looks for `<name>-<version>-<release>.srcnho`
3. Aborts if the `.srcnho` file is not found
4. Executes `sudo -k nhopkg -bv <file>.srcnho`

**Example:**

```bash
cd myapp/
nhopkg-src --createpackage
nhopkg-src --buildpackage
# Runs: sudo -k nhopkg -bv myapp-1.0-n2026.srcnho
```

---

### `--validate [<nhoid_file>]`

Validates a nhoid file (defaults to `./nhoid`). Returns exit code 0 if valid, 1 if errors.

**Checks performed:**

| Check | Type | Description |
|---|---|---|
| Header `#%NHO-0.5` | Error | Must be present |
| `# Name:` | Error | Must be present and non-empty |
| `# Version:` | Error | Must be present and non-empty |
| `# Release:` | Error | Must be present and non-empty |
| `# Packageurl:` | Error | Must be present and non-empty (not required for metapackages) |
| `# Packageref:` | Error | Required if Packageurl starts with `git+` (not required for metapackages) |
| `# SHA256:` | Warning | Recommended for tarball sources, not required |
| `nbuild()` content | Error | Must have real build commands (not just `noemptyfuncs`), except for metapackages |
| `ninstall()` content | Error | Must have real install commands (not just `noemptyfuncs`), except for metapackages |
| `npostinstall()` existence | Error | Function must be defined |
| `npostremove()` existence | Error | Function must be defined |
| Split function existence | Error | `ninstall_<part>()` must exist for each split part |
| Provides/Conflicts overlap | Error | Same name must not appear in both |

**Examples:**

```bash
nhopkg-src --validate
nhopkg-src --validate ./nhoid
nhopkg-src --validate /path/to/nhoid
```

## .srcnho File Format

The `.srcnho` file is a flat tar archive (no compression, no subdirectories). Its contents are extracted by `nhopkg -bv` into a temporary directory, where `nhopkg` reads the `nhoid`, downloads the source via `Packageurl`, verifies `SHA256`, executes `nbuild()` and `ninstall()`, and produces the final `.nho` binary package.

**Contents:**

```
nhoid
some.patch
another.diff
extra_file
```

### `--get-source <project> [--ref <ref>]`

Clone a source project from the `NHOPKG_GIT_SOURCES` repository.

The project is cloned into a subdirectory named after the project. If `--ref` is given, it is passed to git as a tag, branch, or commit reference. After cloning, the standard `patches/` and `others/` directories are created so the project is ready for editing and packaging.

The repository URL is built as `${NHOPKG_GIT_SOURCES}/${project}.git`.

**Examples:**

```bash
# Clone the gcc project
nhopkg-src --get-source gcc

# Clone with a specific branch/tag
nhopkg-src --get-source gcc --ref n2027
```

## See Also

- [`formato-nhoid.md`](formato-nhoid.md) — full nhoid field reference
- `nhopkg -bv` — builds a binary package from a `.srcnho` source package
