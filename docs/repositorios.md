[← Index](README.md)

# 11\. Multiple repositories

**nhopkg** supports multiple repositories to organize packages by purpose and lifecycle.

## Active repositories
    
    
    NHOPKG_ACTIVE_REPOS="extra multilib"

## Repository URLs
    
    
    NHOPKG_REPO_EXTRA=https://example.com/extra
    NHOPKG_REPO_MULTILIB=https://example.com/multilib

## Package assignment
    
    
    # Repository: extra

Only repositories listed in `NHOPKG_ACTIVE_REPOS` are searched.

## Creating repositories

Repositories are created and maintained with the companion tool `nhopkg-repos`:

    
    
    sudo nhopkg-repos -A /path/to/packages/*.nho --repo-dir /path/to/packages

## Source metadata index

Besides the binary repositories, `nhopkg -U` can sync an optional index of
source recipes published by `nhopkg-source-index.sh`. Set `NHOPKG_SOURCES_REPO`
to the published directory to enable it; an empty value is a no-op, so existing
installations are unaffected and clients need no GitLab credentials.

The index contains `core.sources.tar.zst`, `content.source.db.zst`, `lastsync`,
their detached signatures and `report.txt`, which names any `nhoid` rejected
during generation. Recipes are cached under
`${NHOPKG_LOCALSTATEDIR}/sources/<ref>/packages/` and can be queried with
`nhopkg-src --list-sources`, `--search-sources` and `--show-source`, or deployed
with `nhopkg-src --get-source <project> --from-index`. See
[`configuracion.md`](configuracion.md), [`nhopkg-src.md`](nhopkg-src.md) and the
[generation and publication guide](indice-fuentes.md).
