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
