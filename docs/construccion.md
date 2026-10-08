[← Index](README.md)

# 9\. Package building

**nhopkg** can build binary packages (`.nho`) from source recipes (`.srcnho`) or directly from version-control repositories.

## Build workflow

  1. Source preparation
  2. Dependency resolution
  3. Compilation (`nbuild()`)
  4. Installation to staging directory (`ninstall()`)
  5. File detection
  6. Binary package generation
  7. Optional GPG signing



## Build commands
    
    
    # Build from local source package
    sudo nhopkg --build foo.srcnho
    
    # Build directly from a VCS repository
    sudo nhopkg --super-build foo
    
    # Build ONLY the binary package: install into a staging DESTDIR,
    # do not register it and do not run install hooks on this system
    sudo nhopkg --build foo.srcnho --packaging

## Packaging mode (`--packaging` / `NHOPKG_PACKAGING=yes`)

By default `ninstall()` runs directly against the live system. With
`--packaging` (or `NHOPKG_PACKAGING=yes` in `nhopkg.conf`) the build instead:

1. Exports `DESTDIR` pointing to a staging directory (`NHOPACKAGING`, auto-created
   with `mktemp` and removed afterwards, unless you set it yourself).
2. Generates the file list from the staging dir, producing relative paths.
3. Creates the `.nho` **without** registering the package in the database and
   **without** executing install/config hooks (they stay inside the `.nho`).
4. Saves the build/install logs next to the `.nho` instead of in
   `${NHOPKG_LOCALSTATEDIR}/logs`.
5. Leaves the rest of the live system alone: a package already installed is
   not removed or replaced, dependencies are not installed, the system caches
   (schemas, icons, mime, fonts, ldconfig) are not refreshed and the locate
   database is not rewritten.

Recipes must honor `DESTDIR` (e.g. `make install DESTDIR="$DESTDIR"`). If a
recipe installs nothing into the staging dir the build aborts with a clear
message — there is no fallback to scanning `/`. `--packaging` is only valid
with `--build`/`--super-build`.

A required dependency (`Dep(post)`, `BuildDep`) that is not installed stops
the build: nhopkg lists what is missing and exits with status 1 without
installing anything, so install those with `nhopkg -i` and build again. A
missing optional dependency (`OptionalDep(post)`, `OptionalBuildDep`) is only
reported and the build carries on. Once the `.nho` is installed,
`nhopkg -x` refreshes the caches and `nhopkg -u` the locate database.

> **If `NHOPKG_PACKAGING=yes` is set in `nhopkg.conf`**, nhopkg rejects `-i`,
> `-x` and `-u` too: the startup check looks at the variable and not at where
> it came from. Run them as `NHOPKG_PACKAGING=no nhopkg -x` in that case, or
> take the variable out of the conf first.

To label the `.nho` for another architecture (`# Arch:` and filename), use
`--arch <arch>` or `NHOPKG_TARGET_ARCH` — only valid in packaging mode and only
metadata changes (a package installed on a real system must keep its host
Arch); the toolchain is not touched.

## Source types

The `# Packageurl:` field in the `nhoid` selects how the source is fetched:

| Prefix | Source |
|---|---|
| `https://...tar.gz` (or another tarball) | Download and extract a tarball |
| `git+https://...` (or a URL ending in `.git`) | Git clone |
| `svn+https://...` | Subversion checkout |
| `hg+https://...` | Mercurial clone |

For version-control sources, `# Packageref:` pins the reference (tag, branch or commit for git; revision for svn and hg). Without a scheme prefix, the URL is treated as a tarball.

## Split packages

Multiple binary packages can be generated from a single recipe:
    
    
    # Splitpackage: dev docs

Each subpackage uses its own `ninstall_<name>()` function.
