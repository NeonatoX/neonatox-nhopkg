# Main Commands — nhopkg v1.0

nhopkg is a universal binary and source package manager. This page documents every command and option accepted by the `nhopkg` binary. Administrative tasks (package building, repository management, user creation) are handled by companion tools referenced at the end.

## Command reference

| Short | Long | Description |
|-------|------|-------------|
| `-i` | `--install` | Install a local `.nho` binary package |
| `-S` | `--super-install` | Install a package from a remote repository |
| `-d` | `--dios` | Same as `-S` / `--super-install` |
| `-b` | `--build` | Build and install a `.srcnho` source package |
| `-C` | `--super-build` | Clone a Git repository and build/install from its `nhoid` recipe |
| `-r` | `--remove` | Remove an installed package |
| | `--purge` | Remove a package plus all its inverse dependencies |
| `-B` | `--backup` | Recreate a `.nho` binary package from an already-installed package |
| `-l` | `--list` | List all packages installed by nhopkg |
| `-n` | `--info` | Show detailed information about a package (installed, in repo, or local `.nho`) |
| `-w` | `--show` | List every file owned by an installed package |
| `-s` | `--search` | Search for packages in local repository metadata |
| `-t` | `--list-repo` | List all packages available in configured repositories |
| `-k` | `--check` | Verify the integrity of an installed package (check every listed file exists) |
| `-y` | `--upgrade` | Upgrade all installed packages to the latest version available in repositories |
| `-U` | `--update` | Synchronise all configured repository databases (`core.packages.tar.zst`, `core.files.tar.zst`, `lastsync`) |
| `-u` | `--update-db` | Rebuild the local file-location database (`updatedb` / `plocate`) |
| `-x` | `--update-shooters` | Refresh system caches: GLib schemas, icon cache, desktop database, MIME database, man pages, font cache, shared library cache, and GDK pixbuf loaders |
| `-e` | `--clean` | Remove cached `.nho` packages from the download cache; with `-R` also cleans the build directory |
| `-X` | `--strip-binaries` | Strip debug symbols from ELF binaries and shared objects during `--build` (experimental) |

## Options (flags)

| Long | Description |
|------|-------------|
| `-v`, `--verbose` | Enable verbose output |
| `-p`, `--preserve-files` | Force retention of package files when removing a package |
| `-R`, `--recursive` | Answer "yes" to all prompts (non-interactive mode) |
| `-o`, `--output DIR` | Write command output (list, info, show) to a log file in DIR |
| `--root DIR` | Operate on an alternate root directory (for bootstrap, chroot, or containers); state, repositories, and dependencies are resolved inside the target, and post-install hooks / cache updates run there via chroot |
| `--no-check-deps` | Skip dependency resolution |
| `--force-check-deps` | Force dependency resolution even if disabled in config |
| `--no-check-arch` | Skip architecture validation |
| `--force-check-arch` | Force architecture validation even if disabled in config |
| `--no-check-sha256` | Skip SHA-256 checksum verification |
| `--force-check-sha256` | Force checksum verification even if disabled in config |
| `--sign-package` | Sign the binary package with GPG during `--build` |
| `--no-sign-package` | Skip GPG signing |
| `--verify-package-signature` | Verify the GPG signature of a package before installing it |
| `--no-verify-package-signature` | Skip signature verification |
| `--license` | Display a short license notice |
| `--license-all` | Display the full GPL license text |
| `--version` | Show nhopkg version and copyright |
| `--help` | Show the built-in help page |
| `--` | Stop argument parsing (everything after is treated as a package name) |

> **Note:** The options `--no-check-sums` and `--force-check-sums` are aliases for `--no-check-sha256` and `--force-check-sha256` respectively.

## Examples

```bash
# Install a local .nho package
sudo nhopkg -i gimp-3.0.4-n20260523.linux-x86_64.nho

# Install from repository (with dependency resolution)
sudo nhopkg -S gimp

# Same as above
sudo nhopkg --super-install gimp
sudo nhopkg -d gimp

# Build from a source recipe
sudo nhopkg -b foo.srcnho

# Build directly from a Git repository
sudo nhopkg -C foo

# Remove a package
sudo nhopkg -r gimp

# Remove a package and everything that depends on it
sudo nhopkg --purge gimp

# Update repository metadata
sudo nhopkg -U

# Upgrade all installed packages
sudo nhopkg -y

# List installed packages
nhopkg -l

# Show detailed info (searches repos, installed, or local .nho)
nhopkg -n gimp

# Show files owned by a package
nhopkg -w gimp

# Search for packages matching a pattern
nhopkg -s gimp

# Check integrity of an installed package
sudo nhopkg -k gimp

# Clean download cache
sudo nhopkg -e

# Clean cache and build directory
sudo nhopkg -e -R

# Install with alternate root (e.g. for a chroot)
sudo nhopkg -i foo.nho --root /mnt/chroot

# Enable verbose output
nhopkg -v -n gimp

# Write list output to a file
nhopkg -l -o /tmp

# Strip debug symbols during build
sudo nhopkg -X -b foo.srcnho

# Remove a package keeping its files
sudo nhopkg -r gimp -p
```

## Root mode (`--root`)

`--root DIR` installs, upgrades, or removes packages on an **alternate root directory** instead of the live system. Useful for bootstrapping a new system, chroots, or containers. The target directory must already exist.

- Package state (`/var/nhopkg/packages`, `files`, `repo`, `cache`) lives **inside the target** (`DIR/var/nhopkg`).
- Repository synchronization (`--update`), dependency resolution, and conflict checks operate against the target root, not the host.
- Files are extracted into `DIR`.
- `npostinstall()` hooks and cache updates (`shooter_updates`: GLib schemas, icon/MIME/desktop caches, fonts, `ldconfig`) are **not** run on the host. They are executed **inside the target** through a chroot in a private mount namespace that bind-mounts `/dev`, `/proc`, `/sys`, and `/run` from the host. This requires `/bin/sh` inside the target.
- If nhopkg is not yet installed inside the target, cache updates are skipped with a warning; run `nhopkg -x` once inside the target afterwards.
- `# Backup:` files are read from and restored into the target root.
- Non-interactive: prompts are skipped during repository installs.

```bash
# Install into a chroot target
sudo nhopkg -i foo.nho --root /mnt/chroot

# Install from a repository into the target (with dependency resolution)
sudo nhopkg -S foo --root /mnt/chroot

# Upgrade everything inside the target
sudo nhopkg -y --root /mnt/chroot
```

> **Note:** `--root` is not a full `chroot` wrapper. It must be run as root, and the target must already contain the essential packages (e.g. glibc, bash, nhopkg) before hooks can be executed inside it.

## Companion tools

| Tool | Purpose | Reference |
|------|---------|-----------|
| `nhoget` | Unified download tool (HTTP/HTTPS + VCS) for builds and CLI | [`docs/nhoget.md`](nhoget.md) |
| `nhopkg-src` | Source-package creation wizard | [`docs/nhopkg-src.md`](nhopkg-src.md) |
| `nhopkg-repos` | Repository creation and maintenance (`--create-repo`, `--add-to-repo`) | [`docs/repositorios.md`](repositorios.md) |
| `nhouser` | Idempotent system user/group creation (used in `npostinstall()`) | [`docs/usuarios-servicios.md`](usuarios-servicios.md) |
| `nhopkg-overlay` | Isolated overlay build environment | [`docs/nhopkg-overlay.md`](nhopkg-overlay.md) |

## See also

- [Configuration reference](configuracion.md)
- [Package format (nhoid)](formato-nhoid.md)
- [Package groups](grupos.md)
- [Architecture overview](arquitectura.md)
