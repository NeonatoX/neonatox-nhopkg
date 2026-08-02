# nhopkg-overlay — Isolated Build Environment

`nhopkg-overlay` provides an **isolated build environment** by mounting the host root filesystem as an overlay with copy-on-write semantics. Builds performed inside it write only to a temporary upper layer, so the host system is never modified.

It takes no command-line arguments: run it and you get a shell inside the isolated environment, with the current working directory available at `/work`.

## Rationale

Compiling packages from source can modify the system directly (see `ninstall()` in the nhoid format). `nhopkg-overlay` lets maintainers test `.srcnho` recipes or run untrusted build steps without risking the host system:

- Copy-on-write root: nothing written inside the overlay reaches the real `/`
- Bind-mounted virtual filesystems (`/dev`, `/proc`, `/sys`, `/run`) keep the environment functional
- The current working directory is exposed at `/work`, so build sources are reachable from inside the overlay
- On exit everything is recursively unmounted and `/var/lib/nhopkg-overlay/` is removed

## Layout

The overlay is created under `/var/lib/nhopkg-overlay/`:

| Path | Role |
|------|------|
| `/var/lib/nhopkg-overlay/upper` | Copy-on-write upper layer (all changes go here) |
| `/var/lib/nhopkg-overlay/work` | Overlay work directory |
| `/var/lib/nhopkg-overlay/root` | Overlay mount point (the isolated root) |

It is mounted as:

```
mount -t overlay overlay \
  -o lowerdir=/,upperdir=upper,workdir=work \
  root
```

The following are bind-mounted into the isolated root:

- `/dev`, `/proc`, `/sys`, `/run`
- `devpts` on `/dev/pts` (for an interactive terminal)
- The current working directory on `/work`

## Usage

Must be run as **root**:

```
sudo nhopkg-overlay
```

You are dropped into a `chroot` shell at the overlay root, inside `/work`:

```
======================================
 Overlay active
 System: ISOLATED (overlay)
 Work: /work -> /home/user/pkg
======================================
```

From here you can build packages as usual (e.g. `nhopkg -b foo.srcnho`). All file writes land in the upper layer and disappear when you exit.

## Requirements

- Root privileges
- `nhopkg` installed and available on `PATH`
- `mount` available
- Kernel with overlayfs support
- A shell at `/bin/sh` in the overlay root

## Cleanup

On exit (EXIT, INT, TERM), `nhopkg-overlay`:

1. Kills processes still using the overlay (`fuser -km` if available)
2. Recursively unmounts the overlay root and known mount points
3. Removes `/var/lib/nhopkg-overlay/`

If the directory cannot be removed because it is still busy, a warning is printed.

## See also

- [Construction of packages](construccion.md) — building `.srcnho` packages
- [Source package format](formato-nhoid.md) — nhoid fields and functions
- [`nhopkg-src`](nhopkg-src.md) — creating source packages
