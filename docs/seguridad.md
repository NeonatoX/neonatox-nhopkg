[← Index](README.md)

# 5\. Security and GPG signatures

**nhopkg** includes built-in support for GPG signature verification, ensuring package authenticity and integrity before installation.

## The `libnhopkg_crypto` library

All cryptographic operations are implemented in the library
**`libnhopkg_crypto`** (installed as `/usr/lib/nhopkg/libnhopkg_crypto`) and
sourced by both `nhopkg` and `nhopkg-repos`. The module is active only when the
`gpg` binary is available (`CRYPTO_GPG_AVAILABLE`).

### Package signing and verification

Function | Purpose
---|---
`crypto_sign_package()` | Signs `data.tar.zst` inside the build temp dir with `NHOPKG_SIGN_KEY` using `--detach-sign --armor`, producing `signature.gpg`. Skipped when `NHOPKG_SIGN_PACKAGES` is not `yes`.
`crypto_sign_package_ext()` | Same, but for an external `data.tar.zst` (used by `nhopkg-repos`).
`crypto_verify_signature()` | Verifies package signatures against the trusted keyring. Supports **multi-signature** packages: it finds every `signature*.gpg` in the temp dir and succeeds if at least one verifies. Honors `NHOPKG_REQUIRE_SIGNATURE` (abort when a signed package is required).
`crypto_sign_file()` | Low-level detached signature (`--detach-sign --armor`) of any file.
`crypto_verify_file()` | Low-level verification of a detached signature against the trusted keyring.

### Repository metadata signing

`nhopkg-repos` also signs the repository metadata, and `nhopkg -U` verifies it
before accepting an update:

Function | Purpose
---|---
`crypto_sign_repo_metadata()` | Creates `<file>.asc` for every `*.zst` metadata file plus `lastsync.asc` in a repository directory.
`crypto_verify_repo_metadata()` | Verifies each `*.zst`/`.asc` pair and `lastsync.asc`; honors `NHOPKG_REQUIRE_SIGNED_METADATA`.

### Key management

Function | Purpose
---|---
`crypto_init_keyring()` | Auto-initializes the trusted keyring: if `pubring.kbx` is absent but `nhopkg-repo.pub` exists, imports it automatically.
`crypto_generate_key()` | Generates a new GPG key pair for a packager (supports batch/passphrase-file for CI/CD).
`crypto_import_key()` / `crypto_export_key()` / `crypto_list_keys()` / `crypto_remove_key()` | Manage keys in the trusted keyring.
`crypto_verify_incoming()` | Verifies signatures of incoming packages when adding them to a repository (collaborators workflow).

## Overview

Binary packages (`.nho`) may include an optional `signature.gpg` file, which is a detached GPG signature of `data.tar.zst`.

Trusted keys are stored in:
    
    
    /etc/nhopkg/trusted-keys/

## Security configuration

Variable| Default| Description  
---|---|---  
`NHOPKG_VERIFY_SIGNATURE`| yes| Enable GPG verification  
`NHOPKG_REQUIRE_SIGNATURE`| no| Require signed packages  
`NHOPKG_TRUSTED_KEYS_DIR`| /etc/nhopkg/trusted-keys/| Trusted keyring directory  
`NHOPKG_SIGN_PACKAGES`| yes| Sign packages when building  
`NHOPKG_SIGN_KEY`| repo@neonatox.vegnux.com| Default signing key  
`NHOPKG_VERIFY_INCOMING`| no| Verify signatures of incoming packages (collaborators)  
`NHOPKG_SIGN_REPO_METADATA`| yes| Sign repository metadata files  
`NHOPKG_VERIFY_REPO_METADATA`| yes| Verify repository metadata during `nhopkg -U`  
`NHOPKG_REQUIRE_SIGNED_METADATA`| no| Require valid metadata signatures  
  
**Automatic keyring initialization:** if `pubring.kbx` does not exist but `nhopkg-repo.pub` is present, nhopkg imports it automatically. 

## Verification flow

  1. User installs a package.
  2. If verification is enabled, nhopkg checks `signature.gpg`.
  3. If missing and required → abort.
  4. If invalid → abort.
  5. If valid → continue.

Multi-signature packages are accepted when **at least one** `signature*.gpg`
verifies against the trusted keyring.

## Recommendations

  * Keep signature verification enabled in production.
  * Enable mandatory signatures for critical systems.
  * Protect your private signing key.


