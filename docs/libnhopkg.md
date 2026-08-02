[← Index](README.md)

# The `libnhopkg` base library

**`libnhopkg`** is the core shared library of nhopkg. It is installed as
`/usr/lib/nhopkg/libnhopkg` and is sourced by the main script (`nhopkg`), by
the standalone tools (`nhoget`, `nhouser`, `nhopkg-src`, `nhopkg-repos`,
`nhopkg-overlay`) and by the specialized libraries (`libnhopkg_udepsys`,
`libnhopkg_download`, `libnhopkg_crypto`, `libnhopkg_nhouser`).

It provides the base functions: colored messages, temporary directories,
package data extraction, hash verification, repository/installed database
generation and version checks. It also defines the public version constants.

## Version constants

Variable | Value | Description
---|---|---
`NHOPKG_VERSION` | `@PACKAGE_VERSION@` | nhopkg version (from build).
`NHOID_VERSION` | `0.5` | nhoid format version supported by this release.
`BINLOCATE` | set at build time | `locate`/`plocate` binary used for the files database.

## Loading order

Tools that need `libnhopkg` locate it through `NHOPKG_LIB` (defined in
`nhopkg.conf`) and `source` it before any other library:

    source "${NHOPKG_LIB}"
    source "${NHOPKG_LIB%/libnhopkg}/libnhopkg_udepsys"

## Message functions

Function | Description
---|---
`echog()` | Prints a message in the system language with a new line (uses gettext when `NHOPKG_GETTEXT=yes`).
`echogn()` | Prints a message in the system language without a new line.

## Setup and environment

Function | Description
---|---
`setup_busybox_path()` | If `NHOPKG_USE_BUSYBOX=yes`, prepends `/usr/lib/nhopkg/bin` (BusyBox applets) to `PATH`. Called automatically at library load. See [BusyBox Private PATH](configuracion.md#busybox-private-path).

## Directory and permission helpers

Function | Description
---|---
`get_pwd_dir()` | Sets `CWD` (current working directory, or `/tmp` fallback) and `DIROWNER` (`user:group`).
`check_if_root_uid()` | Exits with an error unless running as root.
`make_tmp_dir()` | Creates a secure temporary directory and sets `NHOPKG_TMPDIR`.
`check_if_ok()` | Checks the previous command result; on failure prints a message, cleans up and exits 1.
`cleanup_tmp_dir()` | Removes `NHOPKG_TMPDIR` recursively.
`cleanup_all()` | Removes the nhopkg lockfile and temporary directory.
`cleanup_build_dir()` | Offers to delete the current build directory under `NHOPKG_BUILDIR`.

## Package data functions

Function | Description
---|---
`get_basic_data()` | Extracts `pkgname`, `pkgversion`, `pkgrevision` and `pkgdescription` from a package info file. Fails if any field is missing.
`get_nhoid_data()` | Extracts all package fields from a `.nhoid` file (`pkgname`, `pkgversion`, `pkgrevision`, `pkglicense`, `pkggroup`, `pkgrepo`, `pkgurl`, `pkgdescription`, `pkgsha256`, `pkgmd5`, `pkgsha512`, `pkgbsum`, `pkgarch`, `pkgos`, `pkginstalledsize`, `pkgsrcurl`, `pkggitref`). Handles split packages (`# Splitpackage:`) by creating `pkgdescription_<part>` variables. Validates the `#%NHO-` format marker against `NHOID_VERSION`.
`get_good_file_name()` | Derives a short file name from a full path, used to look up dependencies.
`nhopicker()` | Moves files from a source tree (staging) to a destination tree using `find -path` patterns. Used to split packages into subpackages (e.g. `nhopicker destdir pkg-dev "*.a" "*.h" "*.pc"`).
`noemptyfuncs()` | Empty no-op function used where a non-empty body is required.

## Hash verification and downloads

Function | Description
---|---
`verify_file_hash()` | Computes the hash (`md5`, `sha256`, `sha512` or `bsum`) of a file and compares it with the expected value. Returns 0 on match, 1 on mismatch, 2 if no hash tool is available.
`get_hash_from_nhoid()` | Reads the requested hash type from a `.nhoid` file.
`check_package_hash()` | Verifies the hash of a downloaded package against the nhoid metadata.
`download_with_hash_check()` | Downloads a URL and verifies the resulting file against the expected hash.
`verify_local_tarball_hash()` | Verifies a local tarball against the hash recorded in the nhoid.

## Database generation

Function | Description
---|---
`generate_repo_db()` | Builds `repo.db` for a repository (or all active repositories) under `${NHOPKG_LOCALSTATEDIR}/repo/<name>`, extracting the fields from each package `.nhoid`.
`generate_installed_db()` | Builds the installed-packages database.
`shooter_updates()` | Compares the local installed database against repository metadata and reports available updates.

## Related libraries

Library | Purpose | See also
---|---|---
`libnhopkg_udepsys` | Unified dependency resolution (`dep_resolve_from_nhoid`, `dep_install_queue`, `dep_check_conflicts`, `version_compare`, `get_repo_url`). | [`dependencias.md`](dependencias.md)
`libnhopkg_download` | Unified download system (GNU wget, curl, BusyBox wget backends; VCS clone; resume; hash check). | [`nhoget.md`](nhoget.md)
`libnhopkg_crypto` | GPG signing and verification helpers. | [`seguridad.md`](seguridad.md)
`libnhopkg_nhouser` | Idempotent user/group management (shadow-utils + BusyBox dual backend). | [`usuarios-servicios.md`](usuarios-servicios.md)
