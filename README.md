# Nhopkg – Universal Package Manager for Linux

<img width="512" height="512" alt="logo" src="https://github.com/user-attachments/assets/e4da8c40-22eb-42f1-a361-3761afb3965b" />

[![License: GPLv3+](https://img.shields.io/badge/license-GPLv3%2B-blue.svg)](COPYING)
[![Language: Bash](https://img.shields.io/badge/language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Build system: Meson](https://img.shields.io/badge/build-Meson-orange.svg)](https://mesonbuild.com/)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/cargabsj175/neonatox-nhopkg)

🌐 [English](README.md) | [Español](docs/es/README.md)

**Nhopkg** is a universal package manager designed to work on any GNU/Linux distribution. It uses binary packages (`.nho`) and source packages (`.srcnho`), allowing you to create, install, convert, and manage software in a simple, consistent, and portable way.

Originally developed in 2010, Nhopkg combines simplicity, power, and full control over packaging, making it especially useful for Slackware-like systems or minimal environments.

## History & Maintenance

* **Original creator (2010):** [Jaime Gil de Sagredo Luna](https://github.com/jaimegildesagredo)
* **Maintenance & evolution (2010 – present):** [Carlos Sánchez](https://github.com/cargabsj175) for the **NeonatoX** distribution

This project has been actively maintained for over a decade, adapting to new tools, standards, and modern packaging needs.

## Features

* Binary (`.nho`) and source (`.srcnho`) package support
* Advanced dependency resolution (required & optional)
* Automatic compilation and installation from source
* Local repository creation and management
* Internationalization (i18n) via `gettext` (English, Spanish, Portuguese, French, Catalan, Russian)
* System integration: MIME types, icons, GSettings schemas, fonts, etc.
* Create packages from already installed software (`--backup`)
* Compatible with **any Linux distribution**
* Modern build system with **Meson/Ninja**

## Package Formats

| Extension | Type | Contents |
|-----------|------|----------|
| `.nho` | Binary package | Ready-to-install files, metadata (`nhoid`), and post-install scripts |
| `.srcnho` | Source package | Source code, build configuration (`nbuild`, `ninstall`), and dependencies |

## System Requirements

Nhopkg requires the following tools to be installed:

| Tool | Purpose |
|------|---------|
| `bash` | Main script interpreter |
| `tar`, `zstd` | Packaging and compression (Zstandard) |
| `sha256sum` | Integrity verification |
| `make`, `autoconf` | Source package compilation |
| `ldconfig` | Shared library cache update |
| `grep`, `awk`, `sed`, `find` | Text and path processing |
| `wget` or `curl` | Package and repository downloads |
| `plocate` / `mlocate` | File search for dependency resolution |

> **Tip:** Use `plocate` on modern systems (Arch, Fedora), or `mlocate` on Debian/Ubuntu.
>
> **musl variant:** Pass `-D repo-version=n27 -D repo-arch=x86_64-musl -D libc=musl -D git-branch=musl` for the musl-based build (see example in the configuration section).

Optional tools: `git`, `gettext` (for i18n support).

**For building with BusyBox support (recommended for rolling release):** `musl-gcc` is required to compile static binaries.

## BusyBox Private PATH

Nhopkg can use its own **statically-linked BusyBox + zstd** binaries, providing a self-contained toolset that survives C library (musl/glibc) updates during rolling release.

When enabled, nhopkg prepends `/usr/lib/nhopkg/bin/` to `PATH` at runtime. This directory contains:

```
/usr/lib/nhopkg/bin/
├── busybox     # Static BusyBox (musl-gcc)
├── zstd        # Static zstd (musl-gcc)
├── awk → busybox
├── sed → busybox
├── grep → busybox
├── sort → busybox
├── cp → busybox
├── tar → busybox
├── wget → busybox
└── ... (37 applets total)
```

### Why?

On a rolling release system, updating musl/glibc overwrites dynamic `.so` files, breaking every dynamically-linked tool — including the package manager itself. With static binaries, nhopkg keeps working even when the C library is replaced.

### Activation

Edit `/etc/nhopkg/nhopkg.conf`:

```bash
NHOPKG_USE_BUSYBOX=yes
```

Then restart nhopkg. The private PATH is active on the next run.

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `static-busybox` | `yes` | Build static BusyBox with musl-gcc during `ninja` |
| `static-zstd` | `yes` | Build static zstd with musl-gcc during `ninja` |
| `use-busybox` | `no` | Enable private PATH at runtime (user enables in config) |

Example with BusyBox enabled:

```bash
meson setup builddir \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  -D static-busybox=yes \
  -D static-zstd=yes \
  -D use-busybox=yes
```

### BusyBox Applets

nhopkg uses these BusyBox applets (all from the private PATH when enabled):

| Category | Applets |
|----------|---------|
| Text processing | `awk`, `sed`, `grep`, `sort`, `cut`, `tr`, `head`, `tail`, `wc`, `xargs` |
| File management | `mkdir`, `cp`, `mv`, `rm`, `ln`, `ls`, `du`, `stat`, `basename`, `dirname`, `mktemp` |
| Archive | `tar`, `gzip`, `gunzip` |
| Crypto | `md5sum`, `sha1sum`, `sha256sum`, `sha512sum` |
| Network | `wget` |
| System | `id`, `date`, `sleep`, `cat`, `nproc`, `unshare`, `od`, `realpath`, `chroot` |

> **Note:** `find`, `file`, `gpg`, `curl`, `git`, `make`, and `plocate` are NOT included — they are used from the system.

## Installation

Nhopkg uses **Meson** for building (not Autotools).

### 1. Prerequisites

```bash
# Debian / Ubuntu
sudo apt install meson ninja-build

# Arch Linux / Manjaro
sudo pacman -S meson ninja

# Fedora / RHEL
sudo dnf install meson ninja-build
```

### 2. Configure the project

```bash
meson setup builddir \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  -D binlocate=plocate
```

> Use `-D binlocate=locate` if you have `mlocate` or `slocate` instead.
>
> **For musl-based systems**, use the following configuration:
>
> ```bash
> meson setup builddir \
>   --prefix=/usr \
>   --sysconfdir=/etc \
>   --localstatedir=/var \
>   -D binlocate=plocate \
>   -D repo-version=n27 \
>   -D repo-arch=x86_64-musl \
>   -D libc=musl \
>   -D git-branch=musl
> ```

### 3. Build

```bash
ninja -C builddir
```

### 4. Install

```bash
sudo ninja -C builddir install
```

This installs:

| Path | Description |
|------|-------------|
| `/usr/bin/nhopkg` | Main package manager |
| `/usr/bin/nhopkg-src` | Source package project tool |
| `/usr/bin/nhouser` | User/group management tool |
| `/usr/bin/nhopkg-repos` | Repository management tool |
| `/usr/bin/nhopkg-overlay` | Isolated build environment (overlayfs) |
| `/usr/lib/nhopkg/libnhopkg` | Shared library with common functions |
| `/usr/lib/nhopkg/nhopkg-bb-setup` | BusyBox symlink generator (post-install) |
| `/usr/lib/nhopkg/bin/busybox` | Static BusyBox binary (when `static-busybox=yes`) |
| `/usr/lib/nhopkg/bin/zstd` | Static zstd binary (when `static-zstd=yes`) |
| `/etc/nhopkg/nhopkg.conf` | Configuration file |
| `/usr/share/man/man8/nhopkg.8` | Man page (nhopkg) |
| `/usr/share/man/man8/nhopkg-src.8` | Man page (nhopkg-src) |
| `/usr/share/man/man8/nhopkg-repos.8` | Man page (nhopkg-repos) |
| `/usr/share/man/man8/nhouser.8` | Man page (nhouser) |
| `/usr/share/man/man8/nhopkg-overlay.8` | Man page (nhopkg-overlay) |
| `/usr/share/man/man5/nhopkg.conf.5` | Man page (configuration) |
| `/var/nhopkg/` | Runtime data (cache, packages, logs, database) |

### 5. Post-install (system integration)

```bash
sudo update-mime-database /usr/share/mime
sudo update-desktop-database /usr/share/applications  # if applicable
```

## Directory Structure

```
/var/nhopkg/
├── cache/          # Downloaded and temporary packages
├── files/          # Compressed file lists per installed package
├── logs/           # Build and installation logs
├── packages/       # Metadata of installed packages
└── repo/
    ├── files/      # Repository file database
    └── packages/   # Available package metadata
```

## Basic Usage

```bash
# Install a local binary package
sudo nhopkg -i package-1.0-1.nho

# Install from repository
sudo nhopkg -S package-name

# Build and install from source
sudo nhopkg -b package.srcnho

# Upgrade all installed packages
sudo nhopkg -y

# Remove a package
sudo nhopkg -r package-name

# Create a package from installed software
sudo nhopkg -B package-name

# Create a source package project
nhopkg-src --init myapp

# Build a source package
cd myapp && nhopkg-src --createpackage

# Create a local repository
sudo nhopkg-repos -g /path/to/repository

# Search for packages
nhopkg -s name

# List installed packages
nhopkg -l

# Manage users/groups for package scripts
sudo nhouser --create --user myuser --uid 1000 --group mygroup --gid 1000

# Enter isolated overlay environment
sudo nhopkg-overlay
```

### Managing Repositories

```bash
# Create a repository from .nho packages
sudo nhopkg-repos -g /path/to/packages

# Add packages to an existing repository
sudo nhopkg-repos -A --repo-dir /var/www/repo *.nho

# Synchronise repository databases
sudo nhopkg -U
```

### Development & Translation Workflow

```bash
# Update translation files after modifying source strings
meson compile update-translations -C builddir

# Or run directly
./scripts/update-translations.sh

# Add a new language
./scripts/update-translations.sh --new-lang XX
```

## Configuration

Default config is at `/etc/nhopkg/nhopkg.conf`. Key options:

| Option | Default | Description |
|--------|---------|-------------|
| `NHOPKG_ACTIVE_REPOS` | `core extra multilib` | Active repository names |
| `NHOPKG_LOCALSTATEDIR` | `/var/nhopkg` | Runtime data directory |
| `NHOPKG_CHECKDEPS` | `yes` | Enable dependency resolution |
| `NHOPKG_GETTEXT` | `yes` | Enable i18n translations |
| `NHOPKG_USE_BUSYBOX` | `no` | Enable BusyBox private PATH (see [BusyBox Private PATH](#busybox-private-path)) |
| `NHOHOLD` | `nhopkg glibc gcc` | Packages never deleted on uninstall (varies per `-D libc=`) |
| `NHOPKG_GIT_BRANCH` | *(empty)* | Default git branch for `--super-build` |

## Contributing

Contributions are welcome! You can:

* Report bugs
* Add translations
* Improve packaging logic
* Optimize scripts

* Original project: [https://github.com/jaimegildesagredo](https://github.com/jaimegildesagredo)
* Current maintenance: [https://github.com/cargabsj175](https://github.com/cargabsj175)
* NeonatoX website: [https://neonatox.github.io](https://neonatox.github.io)

## License

This software is licensed under the **GNU General Public License v3 or later (GPL-3.0+)**.

See the [COPYING](COPYING) file for details.

**Nhopkg – Because packaging should be easy, universal, and free.**
