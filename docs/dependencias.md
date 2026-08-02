[← Index](README.md)

# Dependency Resolution — nhopkg v0.5.1

The Unified Dependency Resolution System (UDEPSYS) is the module responsible for
resolving, downloading, and installing package dependencies. It is implemented
in the library **`libnhopkg_udepsys`** (installed as
`/usr/lib/nhopkg/libnhopkg_udepsys`) and sourced by the main `nhopkg` binary.
It exposes the public entry points `dep_resolve_from_nhoid()`,
`dep_install_queue()` and `dep_check_conflicts()`, plus the helpers
`version_compare()` (version comparisons via `sort -V`) and `get_repo_url()`
(repository URL construction). Package downloads are delegated to the unified
download backend `nhoget_url` from [`libnhopkg_download`](nhoget.md).

For the complete nhoid field syntax (including split-specific dependency fields)
see [formato-nhoid.md](formato-nhoid.md).

---

## Dependency Types

Four dependency types are supported, each evaluated at a different stage:

| Type | Internal key | When evaluated | Failure behavior |
|---|---|---|---|
| `# BuildDep:` | `build` | Before `nbuild()` | Hard fail if missing |
| `# OptionalBuildDep:` | `optional_build` | Before `nbuild()` | Warning only |
| `# Dep(post):` | `required` | Before `ninstall()` | Hard fail if missing |
| `# OptionalDep(post):` | `optional` | Before `ninstall()` | Warning only |

Hard failures (`required` and `build`) cause the installation or build to abort
with an error. Optional types (`optional` and `optional_build`) emit a warning
and continue.

---

## Version Operators

Every dependency specification may include a version constraint using one of
the following operators:

| Operator | Meaning |
|---|---|
| `=` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater or equal |

Comparison is performed by `version_compare()` which delegates to `sort -V`
(natural version sorting). The function compares the installed or repository
package version against the constraint and returns success if the constraint
is satisfied.

Examples:

```
foo>=2.0
bar<1.5
baz!=3.0
qux=1.0
quux>4.0
```

A spec without an operator matches any version.

---

## Resolution Order

When resolving a single dependency, UDEPSYS searches in the following order.
The first match wins.

**LEVEL 1 — Installed packages (exact name)**
Scans `${ROOT_PKG_STATE_DIR}/packages/` for a file whose internal `# Name:`
matches the dependency name. Version constraints are checked against the
installed version.

**LEVEL 2 — Installed packages (Provides)**
If no exact-name match is found, every installed package is checked for a
`# Provides:` field that matches the dependency name (with optional version).

**LEVEL 3 — Repository packages (exact name)**
Iterates over each active repository (from `$NHOPKG_ACTIVE_REPOS`). For each
repository, it first looks for a file named exactly after the dependency, then
for files whose internal `# Name:` matches. Version constraints are checked.

**LEVEL 4 — Repository packages (Provides)**
If no exact-name match is found in any repository, `resolve_virtual_package()`
is called to search every repository's packages for a `# Provides:` line that
matches the dependency name.

### Caching

Results are cached in the associative array `DEP_RESOLVED_CACHE` (keyed by the
dependency spec string). If the same spec is requested again within the same
session, the cached result is returned immediately and no repository scan is
performed. The repository name is stored separately in `DEP_REPO_CACHE`.

---

## Provides and Conflicts

### Provides

A package may declare that it **provides** a virtual package by adding a
`# Provides:` field in its nhoid:

```
# Provides:	sdl2
```

Multiple virtual packages are space-separated. Versioned provides are
expressed with `=`:

```
# Provides:	libfoo=2.0
```

When a dependency is not satisfied by any real package name, the resolver
checks whether any package (installed or in repositories) *provides* the
requested name (LEVEL 2 and LEVEL 4 above).

### Conflicts

A package may declare that it **conflicts** with another package:

```
# Conflicts:	sdl2
```

`dep_check_conflicts()` verifies that no installed package (or provider of the
conflicting name) matches the constraint. If a conflict is found, the
operation is aborted with an error.

### Replacement (self-conflict)

A special case exists when a package **conflicts with something it also
provides**. This signals a *replacement* — the new package is intended to take
the place of the old one:

```
# Provides:	sdl2
# Conflicts:	sdl2
```

In this case the resolver sets `DEP_REPLACE_PACKAGE` to the old package name,
and the install routine (`_dep_install_single()`) removes the old package
before installing the new one.

Version constraints work with both Provides and Conflicts:

```
# Provides:	libfoo>=2.0
# Conflicts:	libfoo<2.0
```

---

## Split-Specific Dependencies

When a package defines split sub-packages (`# Splitpackage: dev lib docs`),
each part may carry its own dependency fields using the `_<part>` suffix:

```
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
# BuildDep_lib32:	cmake
```

The suffix matches the split part name declared in `# Splitpackage:`. The
suffix is appended to any of the four dependency types:

| Field | Meaning |
|---|---|
| `# Dep_dev(post):` | Required runtime dep for the `dev` sub-package |
| `# OptionalDep_lib(post):` | Optional runtime dep for the `lib` sub-package |
| `# BuildDep_lib32:` | Required build dep for the `lib32` sub-package |
| `# OptionalBuildDep_docs:` | Optional build dep for the `docs` sub-package |

The same suffix mechanism applies to `# Provides:` and `# Conflicts:`:

```
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
```

---

## Resolution Flow

The resolution pipeline consists of three public functions called sequentially:

### 1. `dep_resolve_from_nhoid()`

Reads a nhoid file and resolves all dependencies of a given type (`required`,
`optional`, `build`, or `optional_build`). For each dependency spec found in
the matching field, `_dep_resolve_single()` is called.

- If a required/build dependency cannot be resolved, the function calls
  `exit 1` immediately.
- If an optional/optional_build dependency cannot be resolved, a warning is
  printed and resolution continues.
- If recursive resolution is enabled (default), `_dep_resolve_children()` is
  invoked on every newly found repository package, resolving its own
  dependencies of the same type.

Packages found in repositories are appended to either `RCASEPACKAGES`
(required/build) or `ORCASEPACKAGES` (optional/optional_build).

### 2. `dep_install_queue()`

Installs all packages accumulated in the resolution queues. It:

1. Displays the list of packages to the user and asks for confirmation
   (unless `ask_user=no`).
2. Calls `_dep_download_all()` which downloads each package from its
   repository via `nhoget_url` (the unified download backend: GNU wget,
   curl, or BusyBox wget).
3. Calls `_dep_install_all_from_queue()` (defined in `nhopkg.in`) which
   installs each downloaded package via `_dep_install_single()`.

`_dep_install_single()` handles conflict checking (via `dep_check_conflicts`),
upgrades, replacements, hash verification, architecture checks, signature
verification, and the actual file installation.

### 3. `dep_check_conflicts()`

Validates `# Conflicts:` declarations for a package against the set of
installed packages. For each conflict spec:

1. Checks if the conflicting package is installed by exact name.
2. Checks if any installed package *provides* the conflicting name.
3. If a conflict is found and the package also *provides* the conflicting name,
   it is treated as a *replacement* (see above) rather than an error.
4. Returns non-zero if an unresolvable conflict is detected, causing the
   caller to abort the operation.
