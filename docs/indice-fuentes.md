[← Index](README.md)

# 19\. Source index: generation and publication

Operational reference for `scripts/nhopkg-source-index.sh`, from the
authenticated smoke test to staging publication. **Production is never
touched in any step.**

## 1. The idea in one page

The generator reads `nhoid` files from the `neonatox-sources` GitLab group via
the REST API and publishes an index that clients download over HTTP **from
your own server**. Clients never need a GitLab token.

| Concept | Value | Configured with |
|---|---|---|
| GitLab group | `neonatox-sources` | `--group` (already the default) |
| GitLab API | `https://gitlab.com/api/v4` | `--api-url` |
| Group web URL | `https://gitlab.com/neonatox-sources` | — |
| Recipe clones | `https://gitlab.com/neonatox-sources/<project>.git` | `NHOPKG_GIT_SOURCES` |
| Published index URL | your choice | `NHOPKG_SOURCES_REPO` |

Do not confuse the two URLs: `NHOPKG_GIT_SOURCES` is the recipe **source**
(GitLab); `NHOPKG_SOURCES_REPO` is the index **destination** (your HTTP
server).

Published artefacts:

| File | Contents |
|---|---|
| `core.sources.tar.zst` | `<ref>/<project>` plus its `<project>.sourceinfo` sidecar |
| `content.source.db.zst` | `"<bytes> <ref>/<project>"` per file |
| `lastsync` | Unix epoch; the client skips download when it has not advanced |
| `report.txt` | Counters and rejected entries |
| `*.asc` | Detached signatures of the three files above (only when signing) |

Generator default refs: `main musl`. For this GitLab group **always pass
`--refs "main master musl"`** (see §4): the generator filters branch names
exactly and most repositories default to `master`. A recipe that only has
`master` is otherwise not indexed and does not even appear as an
`invalid-entry` in `report.txt`.

### Ref resolution on the client

| `NHOPKG_GIT_BRANCH` / `--ref` | Indexed project | Project absent from the index |
|---|---|---|
| empty | the sidecar `Source-Ref` of the default-branch entry wins (`main`, then `master`, then another non-`musl` ref); whole-index queries still use `main` | Git uses the repository's default branch (`main` or `master`) |
| `glibc` | `main` (explicit alias) | `main` |
| `musl`, `master`, other | that ref | that ref |

A `musl` entry is **never chosen implicitly**: use `--ref musl` or
`NHOPKG_GIT_BRANCH=musl` for that variant. This matters for projects such as
`enchant`, which are published under both `master` and `musl`.

This is the fix for `nhopkg -RCv enchant`: `enchant` defaults to `master`.
Before it is indexed, the clone no longer asks Git for `main`; after the
regenerated index is installed, `--show-source enchant` reads its `master`
sidecar directly.

For a group using only `master`, `--refs "master musl"` is enough. The ref name
is the key: `sources/<ref>/packages/` and the sidecar's `Source-Ref` must match.

## 2. Before you start

- Token with `read_api` and `read_repository` scopes.
- Tools: `curl`, `zstd`, `tar`, `sha256sum`, `date`, `mktemp`, `python3`.
  For signing also `gpg` and `NHOPKG_SIGN_KEY`.
- Up-to-date `builddir` (`ninja -C builddir`); the validator is
  `builddir/src/nhopkg-src`, invoked through `bash` by the generator.
- Ask for the token with `read -rsp` so it is neither echoed nor stored in
  shell history. Never paste it into a report.

## 3. Smoke test (always first)

```bash
cd ~/sources/NeonatoX_2026/neonatox-nhopkg

OUT=/tmp/opencode/source-index-smoke
rm -rf "$OUT" && mkdir -p "$OUT"

read -rsp 'GitLab token: ' GITLAB_TOKEN; echo
export GITLAB_TOKEN

scripts/nhopkg-source-index.sh \
  --output "$OUT" \
  --cache "$OUT/.cache" \
  --nhopkg-src builddir/src/nhopkg-src \
  --limit 2 --rate 1 --no-sign

cat "$OUT/report.txt"
```

`--limit 2` counts **projects**, not entries: 2 projects × 2 default refs = 4
entries. Expected: `indexed=4 reused=0 invalid=0 skipped=0 failed=0`. The smoke
uses the generator defaults only to exercise the plumbing; the real run below
overrides them with `--refs`.

## 4. Real generation

```bash
cd ~/sources/NeonatoX_2026/neonatox-nhopkg

DATE=$(date +%Y%m%d-%H%M)
OUT=/tmp/opencode/source-index-full-$DATE
CACHE=$HOME/.cache/nhopkg-source-index
mkdir -p "$OUT" "$CACHE"

read -rsp 'GitLab token: ' GITLAB_TOKEN; echo
export GITLAB_TOKEN

NHOPKG_SIGN_KEY=repo@neonatox.vegnux.com \
scripts/nhopkg-source-index.sh \
  --refs "main master musl" \
  --output "$OUT" \
  --cache "$CACHE" \
  --nhopkg-src builddir/src/nhopkg-src \
  --rate 2 --retries 3

cat "$OUT/report.txt"
```

- **No `--limit`** walks every active project; archived and empty ones are
  skipped automatically.
- **Keep `--cache` stable across runs.** It stores `nhoid` files by commit
  SHA. Inside `$OUT` it would be lost every time. On later runs `reused:`
  grows and API traffic drops.
- **`--rate 2`** means 2 requests/s. On `HTTP 429`, use `--rate 1`; the script
  already retries 3 times honouring `Retry-After`.
- Any request failure aborts **before publication**, so no partial index is
  left behind. Re-run with the same cache.
- `--refs "main master musl"` is the important part of this run. Reusing
  `$HOME/.cache/nhopkg-source-index` means only the ~100 projects that were
  previously skipped (no `main` and no `musl`) are fetched.
- The signing key above is the one already trusted by clients
  (`repo@neonatox.vegnux.com` / `38125726E317393F`). Do **not** pass
  `--no-sign` here: publication needs the three `.asc` files. `--no-sign`
  deletes existing signatures in `$OUT` and is only for smoke runs.

Expect `refs: main,master,musl` in `report.txt`, with about 100 more indexed
entries than the previous `main,musl` run. The exact count is whatever the
report says; read it before publishing.

### Signing an already generated index by hand

If the artefacts are already generated, you do not need to re-run the generator:
sign the three files the client consumes and upload the `.asc` files next to
them.

```bash
cd "$OUT"
KEY=repo@neonatox.vegnux.com

for f in core.sources.tar.zst content.source.db.zst lastsync; do
  gpg --batch --yes --default-key "$KEY" \
      --detach-sign --armor --output "${f}.asc" "$f"
done

gpg --verify core.sources.tar.zst.asc core.sources.tar.zst
```

If the key has a passphrase and `--batch` fails, unlock the agent first with
`echo test | gpg --clearsign >/dev/null`. `report.txt` is not signed. The `.asc`
files must sit next to the originals; if any of the three files is regenerated,
re-sign it.

The client verifies only the `.zst`/`.asc` and `lastsync`/`lastsync.asc` pairs
that are present. With `NHOPKG_VERIFY_REPO_METADATA=yes` it prints
`--- Repository metadata verified (3 files).`; note that
`NHOPKG_REQUIRE_SIGNED_METADATA=yes` rejects invalid signatures but does not
require a signature to exist.

Practical advice: run with `--limit 10` and the same cache first. If
`report.txt` is clean, drop the limit.

## 5. Reading `report.txt`

```
indexed: 42
reused: 38
skipped: 0
invalid: 1
failed: 0
refs: main,master,musl
invalid-entry: main/foo: <reason>
```

| Field | Meaning | Action |
|---|---|---|
| `indexed` | Published entries (project × ref) | Must be > 0 |
| `reused` | Served from cache | Informational |
| `skipped` | Refs not requested | Informational |
| `invalid` | `nhoid` that failed `nhopkg-src --validate` | **Not published**; fix in GitLab and re-run |
| `failed` | Projects with API or unsafe-path problems | Investigate |

A successful run with `invalid-entry:` lines is not a generator error: those
are malformed recipes. Fix them in GitLab and re-run; only changed entries are
downloaded again.

## 6. Publishing to staging

`rsync` is not installed on this machine, so copy the explicit file list.
Publish into a new directory and swap `current` atomically:

```bash
BASE=/path/to/staging/repo/n27/sources   # ← adjust (architecture-neutral)
NEW="$BASE/.new-$DATE"
mkdir -p "$NEW"

cp -p "$OUT"/core.sources.tar.zst "$OUT"/content.source.db.zst \
      "$OUT"/lastsync "$OUT"/report.txt "$NEW/"
# When signed, also copy:
# cp -p "$OUT"/*.asc "$NEW/"

if [[ -e "$BASE/current" ]]; then mv -T "$BASE/current" "$BASE/.old-$DATE"; fi
mv -T "$NEW" "$BASE/current"
rm -rf "$BASE/.old-$DATE"
```

The index is architecture-neutral: it lives in `repo/n27/sources`, not in
`repo/n27/x86_64/sources`. `main`, `master` and `musl` are selected inside the
index with `NHOPKG_GIT_BRANCH` (or the sidecar), not through the path, so one
copy serves all architectures.

Point `NHOPKG_SOURCES_REPO` at the directory that contains the artefacts. For
this deployment the authorised destination is the flat staging URL
`https://neonatox.vegnux.com/repo/n27/sources/`; the binary production
repositories (`repo.neonatox.vegnux.com/core|extra|multilib`) are never touched.
If you use the `current` scheme above, point at `…/sources/current`. Never
publish to a binary repository path.

## 7. Testing the client

On the client, put the URL in `/etc/nhopkg/nhopkg.conf`, then:

```bash
sudo nhopkg -U
nhopkg-src --list-sources
nhopkg-src --show-source <project>
nhopkg-src --show-source enchant   # regression: master-only default branch
```

- `nhopkg -U` needs root.
- A source-index failure is **only a warning**: binary repositories keep
  working.
- The system config overrides the environment variable: exporting
  `NHOPKG_SOURCES_REPO` is not enough if `/etc/nhopkg/nhopkg.conf` defines it
  as empty.
- `--show-source` checks `Source-Nhoid-SHA256`: a tampered cache is rejected.
- With `NHOPKG_GIT_BRANCH` empty, a project's sidecar decides its ref; only
  projects absent from the index fall back to Git's default branch.
- `NHOPKG_USE_SOURCE_INDEX` defaults to `no` in the generated config, so
  `nhopkg -C` clones from GitLab and follows the repository HEAD. Set it to
  `yes` to reuse a verified indexed recipe without cloning. Explicit
  `nhopkg-src --from-index` queries work either way.
- `--from-index` is not fully offline: with no extra files it does not clone,
  but `nbuild()` may still download upstream sources.

Read-only check without root or network, useful to validate published
artefacts:

```bash
STATE=/tmp/opencode/source-index-client-state
TMP=$(mktemp -d)
mkdir -p "$STATE/sources"
zstd -dc "$BASE/current/core.sources.tar.zst" | tar -xf - -C "$TMP"
for ref in main master musl; do
  [[ -d "$TMP/$ref" ]] || continue
  mkdir -p "$STATE/sources/$ref/packages"
  cp -a "$TMP/$ref/." "$STATE/sources/$ref/packages/"
done
cp -p "$BASE/current/content.source.db.zst" "$BASE/current/lastsync" "$STATE/sources/"
rm -rf "$TMP"
```

## 8. Common problems

| Symptom | Cause | Fix |
|---|---|---|
| Repeated `HTTP 429` | API limit, even with a token | `--rate 1`, wait for `Retry-After`, retry |
| `HTTP 401`/`403` | Token lacks scopes or expired | Recreate it with `read_api` + `read_repository` |
| `no valid nhoid entries` | Every `nhoid` failed validation | Fix recipes; check `report.txt` |
| `signing needs NHOPKG_SIGN_KEY` | Missing key | Set `NHOPKG_SIGN_KEY` or use `--no-sign` |
| Signing fails with `--batch` | Passphrase-protected key not unlocked | Unlock the GPG agent first |
| Client does not download | Local `lastsync` ≥ remote, or wrong URL | Check `NHOPKG_SOURCES_REPO` and `lastsync` |
| Client tries to fetch `main` on a `master`-only repository | Index was generated without `master`, so there is no sidecar to use | Regenerate with `--refs "main master musl"`; the clone path now leaves an unset ref to Git |
| Client cannot see a recipe | It is an `invalid-entry`, or its ref is absent | Check `report.txt` and ref mapping |
| `rsync: command not found` | Not installed | Use `cp -p` with the explicit file list |

## 9. Golden rules

1. Smoke first, then `--limit 10`, then the full run.
2. Keep the cache outside the output directory.
3. Pass `--refs "main master musl"` for this group and read `report.txt`
   **before** publishing.
4. Publish to `current` with an atomic swap, only at the designated flat
   staging URL.
5. Token only on the generating machine; never in the client or a log.
6. Staging always; binary production repositories are never touched.
7. If clients verify signatures, staging must include the `.asc` files.

## See also

- [`configuracion.md`](configuracion.md) — `NHOPKG_SOURCES_REPO`,
  `NHOPKG_GIT_BRANCH`, `NHOPKG_USE_SOURCE_INDEX`,
  `NHOPKG_AUTO_SOURCE_FALLBACK`
- [`nhopkg-src.md`](nhopkg-src.md) — `--list-sources`, `--search-sources`,
  `--show-source`, `--from-index`
- [`repositorios.md`](repositorios.md) — relationship with binary repositories
