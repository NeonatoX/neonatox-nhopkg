[← Index](README.md)

# 13\. Next steps

Although **nhopkg v1.0** is stable, there is room for growth.

## Completed

The following roadmap items are now implemented:

| Item | Where |
|---|---|
| Create more `.srcnho` packages | `nhopkg-src` tool (`--init`, `--createpackage`, `--buildpackage`) |
| Improve split package definitions | Per-part fields `# Description_part:`, `# Group_part:`, `# Repository_part:`, `# Backup_part:` (plus `Provides_/Conflicts_/Dep_/OptionalDep_`) |
| Reproducible build flags | `nhopkg.conf` section "Build Configuration — Compilation Optimizations" (`NHOPKG_MACHINE`, `NHOPKG_CFLAGS`, ...) |
| Sandboxed builds | `nhopkg-overlay` (build-directory overlay) |
| Unified downloads | `libnhopkg_download` / `nhoget` (GNU wget, curl, BusyBox wget, VCS) |
| GPG signing and verification | `libnhopkg_crypto`, `nhopkg-repos` signing, `NHOPKG_REQUIRE_SIGNATURE` |
| Automate repository creation | `nhopkg-repos` (`--add-to-repo`) |
| Resilient private PATH | Static BusyBox in `lib/nhopkg/bin` with symlinks via `nhopkg-bb-setup` |
| Man pages | `nhopkg.8`, `nhoget.8`, `nhopkg-repos.8`, `nhopkg-src.8`, `nhopkg-overlay.8`, `nhouser.8`, `nhopkg.conf.5` |
| Clear package groups | Metapackages via `nhopkg-src\ \-\-init\ \-\-meta` / `get_packages_by_group_names()` |

## Still on the roadmap

  * Automated test suite
  * Delta downloads

**nhopkg** is a foundation — how far it goes depends on its users.
