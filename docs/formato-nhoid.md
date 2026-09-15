# nhoid File Format — nhopkg v1.0

The nhoid file is the metadata descriptor used in both binary (`.nho`) and source (`.srcnho`) packages. It defines package identity, dependencies, build steps, installation logic, and post-installation tasks.

## Format Rules

- Fields use `# FieldName:\tvalue` syntax (tab-separated)
- Comments use `##` (double hash) — ignored by the parser
- The file must start with `#%NHO-0.5` header
- Functions (`nbuild()`, `ninstall()`, etc.) define executable code

## Header

```nhoid
#%NHO-0.5
# Package Maintainer:	Name <email>
```

If the header version does not match `NHOID_VERSION`, the package is rejected.

## Metadata Fields

| Field | Required | Description |
|---|---|---|
| `# Name:` | Yes | Package name |
| `# Version:` | Yes | Package version (e.g. `1.0`, `2.15.6`) |
| `# Release:` | Yes | Package release (e.g. `n2026`) |
| `# License:` | No | Software license (e.g. `GPL-3.0-only`, `MIT`) |
| `# Group:` | No | Package group classification (may appear more than once; a package can belong to multiple groups) |
| `# Repository:` | No | Target repository (`core`, `extra`, `multilib`) |
| `# Arch:` | No | Target architecture(s), space-separated (e.g. `i686 x86_64`) |
| `# OS:` | No | Target operating system |
| `# Url:` | No | Upstream project website |
| `# Description:` | No | Package description |
| `# Installed-Size:` | No | Installed size in bytes (auto-calculated during build) |
| `# Build-Duration:` | No | Build time (auto-recorded) |
| `# Build-Date:` | No | Build timestamp (auto-recorded) |
| `# Build-Host:` | No | Build hostname (auto-recorded) |

### Source Metadata

| Field | Required | Description |
|---|---|---|
| `# Packageurl:` | Yes | Source URL. For tarballs: `https://...tar.gz`. For version-control sources, use a scheme prefix: `git+`, `svn+` or `hg+` (a URL ending in `.git` is also treated as Git) |
| `# Packageref:` | Only if VCS | Version-control reference: tag, commit or branch (git); revision (svn, hg) |
| `# SHA256:` | Recommended for tarballs | SHA256 checksum + filename. Alternative: `# MD5:`, `# SHA512:`, `# BSUM:` |

Example:

```nhoid
# Packageurl:	https://example.com/pkg-1.0.tar.gz
# SHA256:	a1b2c3d4...  pkg-1.0.tar.gz
```

For version-control sources, the scheme prefix selects the system:

```nhoid
# Packageurl:	git+https://github.com/user/repo
# Packageref:	v1.0

# Packageurl:	svn+https://svn.example.com/project
# Packageref:	r42

# Packageurl:	hg+https://hg.example.com/project
# Packageref:	1.0
```

### Split Packages

Split packages allow a single source to produce multiple sub-packages.

```nhoid
# Splitpackage:	dev lib docs
```

Each split part has its own set of metadata fields using the `_<part>` suffix:

```nhoid
# Description_dev:	Development headers
# Description_lib:	Shared libraries
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
# Group_docs:	doc
# Repository_dev:	extra
# Dep_dev(post):	somepackage
# Backup_dev:	/etc/foo-dev.conf
```

Split-specific `# Backup_<part>:` fields work like the main `# Backup:` field: the sub-package's files are preserved before extraction and restored afterward. `# Group_<part>:`, `# Repository_<part>:` and `# Provides_<part>:` / `# Conflicts_<part>:` override the corresponding main fields for the sub-package.

### Provides and Conflicts

```nhoid
# Provides:	sdl2
# Provides_lib32:	lib32-sdl2
# Conflicts:	sdl2
# Conflicts_lib32:	lib32-sdl2
```

### Backup

Files listed in `# Backup:` are preserved before extraction and restored afterward. Useful for config files.

```nhoid
# Backup:	/etc/foo.conf /etc/foo.d/*
```

Split sub-packages use their own `# Backup_<part>:` field (see the Split Packages section above).

### Dependencies

All dependency fields are optional. Multiple packages are space-separated. Version operators: `>=`, `<=`, `!=`, `>`, `<`, `=`.

```nhoid
# BuildDep:	cmake ninja
# OptionalBuildDep:	gtk4>=4.10
# Dep(post):	libfoo
# OptionalDep(post):	bar<2.0
```

Split-specific dependencies use the `_<part>` suffix:

```nhoid
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
```

### Dependency Types

| Field | When evaluated | Description |
|---|---|---|
| `# BuildDep:` | Before `nbuild()` | Required build dependencies |
| `# OptionalBuildDep:` | Before `nbuild()` | Optional build dependencies |
| `# Dep(post):` | Before `ninstall()` | Required runtime dependencies |
| `# OptionalDep(post):` | Before `ninstall()` | Optional runtime dependencies |

---

## Functions

Functions define executable code. They must be valid bash.

### nbuild()

Build commands. Must have real content (not just `noemptyfuncs`).

```bash
nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}
```

### ninstall()

Installation commands. Must have real content.

Files are installed directly onto the live system root. Newly installed files are then detected by scanning `FIND_DIRS`.

```bash
ninstall() {
    ninja -C build install
}
```

### ninstall_\<part\>()

Installation commands for a split sub-package.

```bash
ninstall_dev() {
    cp -r include/* /usr/include/
}
```

### npostinstall()

Post-installation commands (ldconfig, hardlinks, etc.). Can be `noemptyfuncs`.

```bash
npostinstall() {
    ldconfig
}
```

### npostinstall_\<part\>()

Post-installation for a split sub-package.

### npostremove()

Post-removal commands. Can be `noemptyfuncs`.

```bash
npostremove() {
    rm -f /etc/ld.so.cache
}
```

### npostremove_\<part\>()

Post-removal for a split sub-package.

### noemptyfuncs

Placeholder for optional functions. Prevents bash errors when a function body is intentionally empty.

```bash
npostinstall() {
    noemptyfuncs
}
```

---

## Examples

### Simple tarball package

```nhoid
#%NHO-0.5
# Package Maintainer:	user <user@host>

# Name:	mktorrent
# Version:	1.1
# Release:	n2026
# License:	GPL-2.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://github.com/pobrn/mktorrent
# Description:	Simple command line utility to create BitTorrent metainfo files.
# Packageurl:	https://github.com/pobrn/mktorrent/archive/v1.1/mktorrent-1.1.tar.gz
# SHA256:	d0f47500192605d01b5a2569c605e51ed319f557d24cfcbcb23a26d51d6138c9  mktorrent-1.1.tar.gz

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
```

### Git source with split packages

```nhoid
#%NHO-0.5
# Package Maintainer:	cargabsj175 <cargabsj175@gmail.com>

# Name:	qt6
# Version:	6.10.2
# Release:	n2026
# License:	GPL-3.0-only LGPL-3.0-only
# Repository:	extra
# Arch:	i686 x86_64
# Url:	https://www.qt.io/
# Description:	A cross-platform application and UI framework.
# Description_xcb_private_headers:	Private headers for Qt6 Xcb.
# Packageurl:	git+https://github.com/qt/qtbase
# Packageref:	v6.10.2
# Splitpackage:	xcb_private_headers

nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}

ninstall() {
    ninja -C build install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_xcb_private_headers() {
    cp -r include/* /usr/include/
}

npostinstall_xcb_private_headers() {
    noemptyfuncs
}

npostremove_xcb_private_headers() {
    noemptyfuncs
}
```
