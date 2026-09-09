[← Index](README.md)

# 7\. Package groups and metapackages

**nhopkg** allows organizing packages into logical groups using the `# Group:` field in the `nhoid` file. Groups are metadata used for searching and reporting; to install a whole set of packages together you create a **metapackage** that depends on the group.

## Defining a group

The `# Group:` field may appear more than once in an `nhoid`; a package belongs to all groups listed.

    # Group:	graphics
    # Group:	development

## What is a metapackage

A metapackage is a `.nho` package that contains **no application files**: it only depends on a set of packages that are installed together. Once the metapackage is installed, installing and removing the whole set is managed normally by nhopkg; its dependencies are resolved when the metapackage is installed.

## Creating a metapackage

Use `nhopkg-src --init <name> --meta`. The tool asks for a **target group** and writes the group's package names as `# BuildDep:` and `# Dep(post):` entries:

```bash
# Create a project that depends on everything in the "base" group
nhopkg-src --init base-meta --meta

# Package it
nhopkg-src --createpackage

# Build and install it (resolves and installs all its dependencies)
sudo nhopkg-src --buildpackage
```

Metapackages use fixed metadata: `# License: CUSTOM`, `# Arch: any`, a project URL, and the description `Metapackage for <name> group.`. No source tarball or download URL is required.

## Installing and removing

A metapackage is installed and removed like any other package:

```bash
# Install a built metapackage locally
sudo nhopkg -i base-meta-1.0-n2026.linux-any.nho

# Uninstall it without affecting its packages
sudo nhopkg -r base-meta

# Completely remove it (no configuration exists, so plain -r is enough; --purge is optional for a definitive removal)
sudo nhopkg --purge base-meta
```

When the metapackage is removed, its packages are **not** removed automatically.

## Documentation

When a metapackage is built or installed, a `README.meta` file is generated in `/usr/share/doc/<package>/` (in the system's preferred language when a translation is available). It explains the purpose of the metapackage, the package list, and how to remove it safely.

## Use cases

Groups and metapackages are ideal for defining system profiles such as `base`, `desktop`, or `server`:

```bash
# Sync repositories
sudo nhopkg --update

# List packages of a group (search metadata)
nhopkg --search base | grep base

# Build and install the "base" metapackage
nhopkg-src --init base-meta --meta
nhopkg-src --createpackage
sudo nhopkg -b base-meta-1.0-n2026.srcnho
```