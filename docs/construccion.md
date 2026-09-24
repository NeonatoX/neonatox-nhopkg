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

Recipes must honor `DESTDIR` (e.g. `make install DESTDIR="$DESTDIR"`). If a
recipe installs nothing into the staging dir the build aborts with a clear
message — there is no fallback to scanning `/`. `--packaging` is only valid
with `--build`/`--super-build`.

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
