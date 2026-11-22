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

Default refs: `main musl`. Empty `NHOPKG_GIT_BRANCH` or `glibc` → `main`;
`musl` → `musl`. An explicit `--ref` always wins.

### Branches not named `main`

The generator **does not detect** GitLab's default branch: it filters branch
names exactly against `--refs`. A recipe that only has `master` is not indexed
and does not even appear as an `invalid-entry` in `report.txt`.

For a group using `master`:

```bash
scripts/nhopkg-source-index.sh \
  --refs "master musl" \
  --output "$OUT" --cache "$CACHE" \
  --nhopkg-src builddir/src/nhopkg-src --rate 2 --no-sign
```

On the client set `NHOPKG_GIT_BRANCH=master` (or pass `--ref master`). If it is
left empty it resolves to `main`, so the client looks in
`sources/main/packages` and finds nothing, while `--get-source` tries to clone
`main`. For a group mixing `main` and `master`, pass both
(`--refs "main master musl"`) and choose per client. The ref name is the key:
`sources/<ref>/packages/` and the sidecar's `Source-Ref` must match.

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

`--limit 2` counts **projects**, not entries: 2 projects × 2 refs = 4
entries. Expected: `indexed=4 reused=0 invalid=0 skipped=0 failed=0`.

## 4. Real generation

```bash
cd ~/sources/NeonatoX_2026/neonatox-nhopkg

DATE=$(date +%Y%m%d-%H%M)
OUT=/tmp/opencode/source-index-full-$DATE
CACHE=$HOME/.cache/nhopkg-source-index
mkdir -p "$OUT" "$CACHE"

read -rsp 'GitLab token: ' GITLAB_TOKEN; echo
export GITLAB_TOKEN

scripts/nhopkg-source-index.sh \
  --output "$OUT" \
  --cache "$CACHE" \
  --nhopkg-src builddir/src/nhopkg-src \
  --rate 2 --retries 3 \
  --no-sign

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

To generate **signed** output (required when clients use
`NHOPKG_VERIFY_SIGNATURE=yes`):

```bash
NHOPKG_SIGN_KEY='your-key-id' scripts/nhopkg-source-index.sh \
  --output "$OUT" --cache "$CACHE" \
  --nhopkg-src builddir/src/nhopkg-src \
  --rate 2 --retries 3
```

`--no-sign` deletes existing `.asc` files in the output directory; do not
reuse a directory that already contains signatures.

Practical advice: run with `--limit 10` and the same cache first. If
`report.txt` is clean, drop the limit.

## 5. Reading `report.txt`

```
indexed: 42
reused: 38
skipped: 0
invalid: 1
failed: 0
refs: main,musl
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
BASE=/path/to/staging/repo/n27/x86_64/sources   # ← adjust
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

Point `NHOPKG_SOURCES_REPO` at `…/sources/current`, not at the parent. Never
publish straight to the production URL.

## 7. Testing the client

On the client, put the URL in `/etc/nhopkg/nhopkg.conf`, then:

```bash
sudo nhopkg -U
nhopkg-src --list-sources
nhopkg-src --show-source <project>
```

- `nhopkg -U` needs root.
- A source-index failure is **only a warning**: binary repositories keep
  working.
- The system config overrides the environment variable: exporting
  `NHOPKG_SOURCES_REPO` is not enough if `/etc/nhopkg/nhopkg.conf` defines it
  as empty.
- `--show-source` checks `Source-Nhoid-SHA256`: a tampered cache is rejected.
- `--from-index` is not fully offline: with no extra files it does not clone,
  but `nbuild()` may still download upstream sources.

Read-only check without root or network, useful to validate published
artefacts:

```bash
STATE=/tmp/opencode/source-index-client-state
TMP=$(mktemp -d)
mkdir -p "$STATE/sources"
zstd -dc "$BASE/current/core.sources.tar.zst" | tar -xf - -C "$TMP"
for ref in main musl; do
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
| Client cannot see a recipe | It is an `invalid-entry`, or its ref is absent | Check `report.txt` and ref mapping |
| `rsync: command not found` | Not installed | Use `cp -p` with the explicit file list |

## 9. Golden rules

1. Smoke first, then `--limit 10`, then the full run.
2. Keep the cache outside the output directory.
3. Read `report.txt` **before** publishing.
4. Publish to `current` with an atomic swap.
5. Token only on the generating machine; never in the client or a log.
6. Staging always; production only on explicit decision.
7. If clients verify signatures, staging must include the `.asc` files.

## See also

- [`configuracion.md`](configuracion.md) — `NHOPKG_SOURCES_REPO`,
  `NHOPKG_GIT_BRANCH`, `NHOPKG_AUTO_SOURCE_FALLBACK`
- [`nhopkg-src.md`](nhopkg-src.md) — `--list-sources`, `--search-sources`,
  `--show-source`, `--from-index`
- [`repositorios.md`](repositorios.md) — relationship with binary repositories
