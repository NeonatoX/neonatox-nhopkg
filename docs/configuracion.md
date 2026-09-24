# Nhopkg Configuration

## Configuration Precedence

Settings are resolved in the following order (later sources override earlier ones):

1. **Command-line options** — highest priority, always win
2. **System config** — `/etc/nhopkg/nhopkg.conf`
3. **Default config** — `/usr/share/nhopkg/nhopkg.conf` — shipped with the package, lowest priority

The file uses standard **bash syntax**:

- `#` for comments
- `VAR="value"` for assignments
- Variable substitution (e.g. `${SYSCONFDIR}/nhopkg`) is supported

---

## 1. Main — Paths

Core directories and base paths used internally by nhopkg.

| Variable | Default | Description |
|---|---|---|
| `prefix` | `@prefix@` | Installation prefix (set by Meson) |
| `datarootdir` | `@datarootdir@` | Base data directory (Meson) |
| `SYSCONFDIR` | `@sysconfdir@` | System configuration directory (usually `/etc`) |
| `NHOPKG_SYSCONFDIR` | `${SYSCONFDIR}/nhopkg` | nhopkg-specific config directory |
| `NHOPKG_DATADIR` | `${datarootdir}/@PACKAGE@` | nhopkg data directory |
| `LOCALSTATEDIR` | `@localstatedir@` | Local state data directory (usually `/var`) |
| `NHOPKG_LOCALSTATEDIR` | `${LOCALSTATEDIR}/nhopkg` | nhopkg state directory (e.g. `/var/nhopkg`) |
| `TMPDIR` | `/tmp` | Temporary directory for extraction |
| `TEMPLATE_TMPDIR` | `.nhopkg.XXXXXXXXXX` | Template pattern for temporary subdirectories |
| `BUILDIR` | `/usr/src` | Base source build directory |
| `NHOPKG_BUILDIR` | `${BUILDIR}/nhopkg` | nhopkg build directory |
| `NHOPKG_LIB` | `@prefix@/lib/nhopkg/libnhopkg` | Path to the `libnhopkg` library |
| `NHOPKG_LOCKFILE` | `/var/lock/nhopkg` | Lock file preventing concurrent nhopkg instances |

**Accepted values:** Any valid absolute path.

---

## 2. Options — Behavior

General behavior options for dependency handling, verification, verbosity, and experimental features.

| Variable | Default | Accepted Values | Description |
|---|---|---|---|
| `NHOPKG_CHECKDEPS` | `yes` | `yes`, `no` | Enable dependency checking (required and optional) |
| `NHOPKG_PURGE` | `no` | `yes`, `no` | Enable inverse dependency removal when uninstalling packages |
| `NHOPKG_CHECKSHA256` | `yes` | `yes`, `no` | Verify SHA256 checksums of packages |
| `NHOPKG_CHECKARCH` | `yes` | `yes`, `no` | Verify package architecture compatibility |
| `VERBOSE_MODE` | `no` | `yes`, `no` | Enable verbose output |
| `STRIP_BINARIES` | `no` | `yes`, `no` | Strip binaries and libraries after installation (experimental) |
| `NHOHOLD` | `"nhopkg glibc gcc"` | Space-separated package names | Packages to hold — never delete their files on uninstall |
| `NHOPKG_USE_BUSYBOX` | `no` | `yes`, `no` | Use the static BusyBox private PATH (see [BusyBox Private PATH](#busybox-private-path)) |
| `NHOPKG_DOWNLOAD_JOBS` | `4` | Positive integer | Maximum simultaneous binary (`.nho`) downloads when installing the full dependency graph. `1` = sequential (exact previous behavior). Requires `bash` ≥ 4.3 for values > 1 (`wait -n`) |

### BusyBox Private PATH

When `NHOPKG_USE_BUSYBOX=yes`, nhopkg prepends `/usr/lib/nhopkg/bin` to
`PATH` (via `setup_busybox_path()` in `libnhopkg`). That directory holds a
**statically linked** BusyBox plus symlinks to its applets, generated at
install time by the helper **`nhopkg-bb-setup`** (installed as
`/usr/lib/nhopkg/nhopkg-bb-setup` and invoked automatically as a
post-install step).

This is critical for rolling releases: because BusyBox and zstd are statically
linked, nhopkg keeps working even across a C library (musl/glibc) update that
would otherwise break every dynamic binary. The applets provisioned are:
`awk`, `sed`, `grep`, `sort`, `cut`, `tr`, `head`, `tail`, `wc`, `xargs`,
`mkdir`, `cp`, `mv`, `rm`, `ln`, `ls`, `du`, `stat`, `basename`, `dirname`,
`mktemp`, `chmod`, `chown`, `tar`, `gzip`, `gunzip`, `md5sum`, `sha1sum`,
`sha256sum`, `sha512sum`, `wget`, `id`, `date`, `sleep`, `cat`, `nproc`,
`unshare`, `od`, `realpath`, `chroot`, `adduser`, `addgroup` and `passwd`.

The helper skips any applet not compiled into the installed BusyBox, cleans up
stale symlinks from previous versions, and reports how many symlinks it
created.

---

## 3. Init System

Selects the init system used by the target system. Affects which service files or scripts are installed.

| Variable | Default | Accepted Values | Description |
|---|---|---|---|
| `INITSYSTEM` | `systemd` | `systemd`, `sysvinit` | Init system to use |

---

## 4. BLFS Systemd Units

Configuration for BLFS-provided systemd unit files. Used only when `INITSYSTEM=systemd`.

| Variable | Default | Description |
|---|---|---|
| `BLFS_DIR` | `${NHOPKG_LOCALSTATEDIR}/cache/blfs` | Base cache directory for extracted BLFS bundles (outside `FIND_DIRS`) |
| `SYSTEMD_BLFS_VER` | `20251204` | Version of the BLFS systemd units bundle |
| `SYSTEMD_BLFS_DIR` | `${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}` | Local directory for the extracted units |
| `SYSTEMD_BLFS_URL` | `https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz` | Download URL |

---

## 5. BLFS SysVinit Scripts

Configuration for BLFS SysVinit boot scripts. Used only when `INITSYSTEM=sysvinit`.

| Variable | Default | Description |
|---|---|---|
| `SYSV_BLFS_VER` | `20251220` | Version of the BLFS bootscripts bundle |
| `SYSV_BLFS_DIR` | `${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}` | Local directory for the extracted scripts |
| `SYSV_BLFS_URL` | `https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz` | Download URL |

---

## 6. Package Signing & Verification

GPG configuration for signing and verifying binary packages.

| Variable | Default | Accepted Values | Description |
|---|---|---|---|
| `NHOPKG_TRUSTED_KEYS_DIR` | `"${NHOPKG_SYSCONFDIR}/trusted-keys/"` | Valid directory path | Directory containing trusted public keys |
| `NHOPKG_SIGN_PACKAGES` | `yes` | `yes`, `no` | Sign packages during build (typically for maintainers) |
| `NHOPKG_SIGN_KEY` | `"repo@neonatox.vegnux.com"` | GPG key ID or email | Key used for signing |
| `NHOPKG_VERIFY_SIGNATURE` | `yes` | `yes`, `no` | Verify package signatures during installation |
| `NHOPKG_REQUIRE_SIGNATURE` | `no` | `yes`, `no` | Abort installation if signature is missing or invalid |

---

## 7. Repositories

Repository configuration: which repos are active and where they are located.

| Variable | Default | Description |
|---|---|---|
| `NHOPKG_ACTIVE_REPOS` | `"core extra multilib"` | Space-separated list of active repository names |
| `NHOPKG_REPO_CORE` | `@NHOPKG_REPO_CORE@` | URL for the **core** repository (set at configure time) |
| `NHOPKG_REPO_EXTRA` | `@NHOPKG_REPO_EXTRA@` | URL for the **extra** repository |
| `NHOPKG_REPO_MULTILIB` | `@NHOPKG_REPO_MULTILIB@` | URL for the **multilib** repository |

**Accepted values for `NHOPKG_ACTIVE_REPOS`:** Any space-separated list of lowercase repository names (must match a corresponding `NHOPKG_REPO_*` variable).

Repository URLs can include multiple mirrors per repo (check nhopkg source for mirror syntax).

---

## 8. Git Sources

Default Git repository used to fetch sources for `.srcnho` packages.

| Variable | Default | Description |
|---|---|---|
| `NHOPKG_GIT_SOURCES` | `https://gitlab.com/neonatox-sources` | Git repository URL for source packages |

---

## 9. Language Support

gettext-based internationalization support.

| Variable | Default | Accepted Values | Description |
|---|---|---|---|
| `NHOPKG_GETTEXT` | `yes` | `yes`, `no` | Enable gettext translations |
| `TEXTDOMAIN` | `@PACKAGE_NAME@` | Text domain name | gettext text domain (do not edit) |
| `TEXTDOMAINDIR` | `@localedir@` | Directory path | gettext locale directory (do not edit) |

---

## 10. Build Configuration — Compilation Optimizations

Variables read by nhopkg and exported before `nbuild()` execution. Used when building packages from source.

| Variable | Default | Description |
|---|---|---|
| `NHOPKG_MACHINE` | `generic` | CPU tuning target (e.g. `generic`, `sandybridge`, `native`, `x86-64`). If empty, nhopkg falls back to `generic` |
| `NHOPKG_CFLAGS` | `"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"` | Base C compiler flags |
| `NHOPKG_CXXFLAGS` | `$NHOPKG_CFLAGS` | C++ compiler flags. If empty, defaults to `NHOPKG_CFLAGS` |
| `NHOPKG_CPPFLAGS` | `""` (empty) | C preprocessor flags |
| `NHOPKG_LDFLAGS` | `"-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"` | Linker flags |
| `NHOPKG_BUILD_JOBS` | `""` (empty) | Parallel build jobs. If empty, auto-detected as `nproc - 2` (minimum 1) |
| `NHOPKG_MAKEFLAGS` | `""` (empty) | Make flags. If empty, auto-generated from `NHOPKG_BUILD_JOBS` |
| `NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL` | `""` (empty) | CMake parallel level. If empty, set from `NHOPKG_BUILD_JOBS` |

---

## 11. Source Package Creation

Settings used when generating binary packages from source.

| Variable | Default | Description |
|---|---|---|
| `FIND_DIRS` | `/bin /boot /etc /lib /opt /sbin /srv /usr` | Space/newline-separated list of directories scanned to detect installed files |
| `NOUPGRADE_FILES` | `mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache ${NHOPKG_BUILDIR} /etc/mtab /etc/fstab` | Space/newline-separated list of files/directories never overwritten on upgrade |

---

## 12. Packaging Mode

Build binary packages without touching the running system. Only applies to the build flows (`-b`/`--build` and `-C`/`--super-build`); any other action fails at startup.

| Variable | Default | Accepted Values | Description |
|---|---|---|---|
| `NHOPKG_PACKAGING` | `no` | `yes`, `no` | Build the `.nho` into a staging `DESTDIR`: recipes install into `NHOPACKAGING`, the package is not registered in the database and no install hook runs |
| `NHOPACKAGING` | `""` (empty) | Valid directory path | Staging directory. If empty, auto-created with `mktemp` inside `TMPDIR` and removed after the build; a user-provided directory is never removed |
| `NHOPKG_TARGET_ARCH` | `""` (empty) | Arch label (`aarch64`, `x86_64-musl`, ...) | Use this architecture for `# Arch:` and the `.nho` filename instead of `uname -m`. **Only applies with `NHOPKG_PACKAGING=yes`** (otherwise ignored, so a native build never registers a mismatched Arch). Metadata only; no toolchain/sysroot changes. Overridable with `--arch` (also requires packaging) |

Recipes must honor `DESTDIR` (e.g. `make install DESTDIR="$DESTDIR"`). If the
recipe installs nothing into the staging dir, the build aborts with a clear
message (no fallback to scanning `/`). Can also be activated per-invocation
with `nhopkg -b paquete.srcnho --packaging`. To build the `.nho` for another
architecture (aarch64, x86_64-musl, ...) set `NHOPKG_TARGET_ARCH` or pass
`--arch <arch>` — **only valid in packaging mode** (it would make the Arch of an
installed/registered package mismatch the host). Only `# Arch:` and the
filename change, the toolchain is untouched:

---

## 13. Database

nhopkg internal file database configuration.

| Variable | Default | Description |
|---|---|---|
| `NHOPKG_DB` | `${NHOPKG_LOCALSTATEDIR}/nhopkg.db` | Path to the package database file |
| `NO_DIRS_IN_DB` | `/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var` | Space/newline-separated list of directories excluded from database indexing |

`NO_DIRS_IN_DB` directories are never tracked in the package database, even if a package installs files there.

---

## Example Configuration

```bash
#====================================================================
# /etc/nhopkg/nhopkg.conf
#====================================================================

# --- Main ---
NHOPKG_SYSCONFDIR=/etc/nhopkg
NHOPKG_LOCALSTATEDIR=/var/nhopkg
TMPDIR=/tmp
NHOPKG_BUILDIR=/usr/src/nhopkg

# --- Options ---
NHOPKG_CHECKDEPS=yes
NHOPKG_PURGE=no
NHOPKG_CHECKSHA256=yes
NHOPKG_CHECKARCH=yes
VERBOSE_MODE=no
STRIP_BINARIES=no
NHOHOLD="nhopkg glibc gcc"
NHOPKG_USE_BUSYBOX=no

# --- Init System ---
INITSYSTEM=systemd

# --- BLFS Systemd Units ---
BLFS_DIR=${NHOPKG_LOCALSTATEDIR}/cache/blfs
SYSTEMD_BLFS_VER=20251204
SYSTEMD_BLFS_DIR=${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}
SYSTEMD_BLFS_URL=https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz

# --- BLFS SysVinit Scripts ---
SYSV_BLFS_VER=20251220
SYSV_BLFS_DIR=${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}
SYSV_BLFS_URL=https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz

# --- Package Signing ---
NHOPKG_TRUSTED_KEYS_DIR="${NHOPKG_SYSCONFDIR}/trusted-keys/"
NHOPKG_SIGN_PACKAGES=yes
NHOPKG_SIGN_KEY="repo@neonatox.vegnux.com"
NHOPKG_VERIFY_SIGNATURE=yes
NHOPKG_REQUIRE_SIGNATURE=no

# --- Repositories ---
NHOPKG_ACTIVE_REPOS="core extra multilib"
NHOPKG_REPO_CORE="https://repo.neonatox.vegnux.com/core"
NHOPKG_REPO_EXTRA="https://repo.neonatox.vegnux.com/extra"
NHOPKG_REPO_MULTILIB="https://repo.neonatox.vegnux.com/multilib"

# --- Git Sources ---
NHOPKG_GIT_SOURCES=https://gitlab.com/neonatox-sources

# --- Language ---
NHOPKG_GETTEXT=yes

# --- Build Configuration ---
NHOPKG_MACHINE="generic"
NHOPKG_CFLAGS="-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"
NHOPKG_CXXFLAGS="$NHOPKG_CFLAGS"
NHOPKG_CPPFLAGS=""
NHOPKG_LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"
NHOPKG_BUILD_JOBS=""
NHOPKG_MAKEFLAGS=""
NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL=""

# --- Packaging Mode ---
# NHOPKG_PACKAGING=yes   # build .nho into a staging DESTDIR (no install)
# NHOPACKAGING=/path/to/staging  # custom staging dir (left in place)
# NHOPKG_TARGET_ARCH=aarch64    # # Arch: + .nho name (packaging only; else uname -m) --arch variant

# --- Source Package Creation ---
FIND_DIRS="/bin /boot /etc /lib /opt /sbin /srv /usr"
NOUPGRADE_FILES="mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache /usr/src/nhopkg /etc/mtab /etc/fstab"

# --- Database ---
NHOPKG_DB=/var/nhopkg/nhopkg.db
NO_DIRS_IN_DB="/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var"
```
