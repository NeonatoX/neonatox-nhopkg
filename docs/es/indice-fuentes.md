[← Índice](README.md)

# 19\. Índice de fuentes: generación y publicación

Guía operativa de `scripts/nhopkg-source-index.sh`. Es una referencia para
consultar; no hace falta memorizarla. Cubre desde el humo autenticado hasta la
publicación en staging. **Producción no se toca en ningún paso.**

## 1. Idea en una página

El generador lee los `nhoid` del grupo GitLab `neonatox-sources` mediante la
API REST y publica un índice que los clientes descargan por HTTP **desde tu
propio servidor**. El cliente nunca necesita un token de GitLab.

| Concepto | Valor | Dónde se configura |
|---|---|---|
| Grupo GitLab | `neonatox-sources` | `--group` (por defecto ya está) |
| API GitLab | `https://gitlab.com/api/v4` | `--api-url` |
| Web del grupo | `https://gitlab.com/neonatox-sources` | — |
| Clonación de recetas | `https://gitlab.com/neonatox-sources/<proyecto>.git` | `NHOPKG_GIT_SOURCES` |
| URL del índice publicado | la que elijas en tu servidor | `NHOPKG_SOURCES_REPO` |

No confundas las dos URLs: `NHOPKG_GIT_SOURCES` es el **origen** de las
recetas (GitLab); `NHOPKG_SOURCES_REPO` es el **destino** del índice (tu HTTP).

Artefactos que se publican:

| Archivo | Contenido |
|---|---|
| `core.sources.tar.zst` | Árbol con `<ref>/<proyecto>` y su `<proyecto>.sourceinfo` |
| `content.source.db.zst` | `"<bytes> <ref>/<proyecto>"` por archivo |
| `lastsync` | Época Unix; el cliente compara y se salta la descarga si no hay cambio |
| `report.txt` | Contadores y entradas rechazadas |
| `*.asc` | Firmas separadas de los tres archivos anteriores (solo si se firma) |

Refs por defecto del generador: `main musl`. Para este grupo GitLab **pasa
siempre `--refs "main master musl"`** (ver §4): el generador filtra por nombre
exacto y la mayoría de los repositorios tienen `master` por defecto. Una receta
que solo tiene `master` no se indexa y ni siquiera aparece como
`invalid-entry` en el `report.txt`.

### Resolución de refs en el cliente

| `NHOPKG_GIT_BRANCH` / `--ref` | Proyecto indexado | Proyecto ausente del índice |
|---|---|---|
| vacío | gana el `Source-Ref` del sidecar (prefiere `main`, luego `musl`, luego el primer ref encontrado); las consultas globales siguen usando `main` | Git usa la rama por defecto del repo (`main` o `master`) |
| `glibc` | `main` (alias explícito) | `main` |
| `musl`, `master`, otro | ese ref | ese ref |

Esto arregla `nhopkg -RCv enchant`: `enchant` tiene `master` por defecto.
Antes de indexarlo, el clone ya no pide `main` a Git; tras instalar el índice
regenerado, `--show-source enchant` lee directamente su sidecar `master`.

Para un grupo que solo usa `master`, basta `--refs "master musl"`. El nombre del
ref es la clave: `sources/<ref>/packages/` y el campo `Source-Ref` del sidecar
deben coincidir.

## 2. Antes de empezar

- Token con scopes `read_api` y `read_repository`.
- Herramientas: `curl`, `zstd`, `tar`, `sha256sum`, `date`, `mktemp`,
  `python3`. Para firmar, además `gpg` y `NHOPKG_SIGN_KEY`.
- `builddir` al día: `ninja -C builddir` (el validador es
  `builddir/src/nhopkg-src`, que no tiene permiso de ejecución y se invoca con
  `bash`; el generador ya lo gestiona).
- El token se pide con `read -rsp` para que no quede en el historial ni se
  imprima. Nunca lo pegues en un informe.

## 3. Humo (siempre primero)

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

`--limit 2` cuenta **proyectos**, no entradas: 2 proyectos × 2 refs por defecto
= 4 entradas. Esperado: `indexed=4 reused=0 invalid=0 skipped=0 failed=0`. El
humo usa solo los defaults para comprobar la maquinaria; la corrida real de abajo
los sustituye con `--refs`.

## 4. Generación real

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

Puntos clave:

- **Sin `--limit`** recorre todos los proyectos activos. Los archivados y
  vacíos se omiten solos.
- **`--cache` estable entre corridas**: guarda los `nhoid` por commit SHA. Si
  la pones dentro de `$OUT`, se pierde cada vez. En la segunda corrida sube
  `reused:` y bajan las peticiones.
- **`--rate 2`** son 2 peticiones/s (valor por defecto). Si sale `HTTP 429`,
  baja a `--rate 1`: reintenta 3 veces respetando `Retry-After`.
- Si falla cualquier petición, el script termina **antes de publicar**: no
  queda un índice a medias. Vuelve a correr con la misma caché.
- `--refs "main master musl"` es la parte importante. Al reutilizar
  `$HOME/.cache/nhopkg-source-index`, solo se bajan los ~100 proyectos que antes
  se omitían (sin `main` ni `musl`).
- La clave de arriba es la que ya confían los clientes
  (`repo@neonatox.vegnux.com` / `38125726E317393F`). **No** pases
  `--no-sign`: la publicación necesita los tres `.asc`. `--no-sign` borra las
  firmas existentes en `$OUT` y solo sirve para el humo.

Espera `refs: main,master,musl` en el `report.txt`, con unos 100 entradas más
que la corrida anterior `main,musl`. El número exacto es el que diga el informe;
léelo antes de publicar.

### Firmar a mano una generación ya publicada

Si los artefactos ya están generados, no hace falta repetir la corrida: firma los
tres archivos que consume el cliente y sube los `.asc` al mismo directorio.

```bash
cd "$OUT"
KEY=repo@neonatox.vegnux.com

for f in core.sources.tar.zst content.source.db.zst lastsync; do
  gpg --batch --yes --default-key "$KEY" \
      --detach-sign --armor --output "${f}.asc" "$f"
done

gpg --verify core.sources.tar.zst.asc core.sources.tar.zst
```

Si la clave tiene passphrase y `--batch` falla, desbloquea antes el agente con
`echo prueba | gpg --clearsign >/dev/null`. `report.txt` no se firma. Los `.asc`
deben estar junto a los originales; si se regenera cualquiera de los tres
archivos, hay que volver a firmarlo.

El cliente verifica solo los pares `.zst`/`.asc` y `lastsync`/`lastsync.asc`
presentes. Con `NHOPKG_VERIFY_REPO_METADATA=yes` verá `--- Repository metadata
verified (3 files).`; ten en cuenta que `NHOPKG_REQUIRE_SIGNED_METADATA=yes`
rechaza firmas inválidas, pero no exige que la firma exista.

Recomendación: antes del run total haz uno con `--limit 10` y la misma caché.
Si el `report.txt` sale limpio, quita el `--limit`.

## 5. Leer el `report.txt`

```
indexed: 42
reused: 38
skipped: 0
invalid: 1
failed: 0
refs: main,master,musl
invalid-entry: main/foo: <motivo>
```

| Campo | Significado | Acción |
|---|---|---|
| `indexed` | Entradas publicadas (proyecto × ref) | Debe ser > 0 |
| `reused` | Sirvieron de la caché | Informativo |
| `skipped` | Refs no solicitadas | Informativo |
| `invalid` | `nhoid` que falló `nhopkg-src --validate` | **No entran** al índice; se corrigen en GitLab y se reintenta |
| `failed` | Proyectos con problema de API o ruta insegura | Investigar |

Si la corrida termina con éxito pero hay `invalid-entry:`, no es un error del
generador: son recetas mal formadas. Corrígelas en GitLab y vuelve a correr;
solo se volverán a bajar las que cambiaron.

## 6. Publicar en staging

En esta máquina no hay `rsync`, así que se copia la lista explícita. Publica
en un directorio nuevo y cambia `current` de golpe para que el cliente no lea
un índice a medias:

```bash
BASE=/ruta/real/de/staging/repo/n27/sources   # ← ajústalo (sin arquitectura)
NEW="$BASE/.new-$DATE"
mkdir -p "$NEW"

cp -p "$OUT"/core.sources.tar.zst "$OUT"/content.source.db.zst \
      "$OUT"/lastsync "$OUT"/report.txt "$NEW/"
# Si generaste firmado, añade también:
# cp -p "$OUT"/*.asc "$NEW/"

if [[ -e "$BASE/current" ]]; then mv -T "$BASE/current" "$BASE/.old-$DATE"; fi
mv -T "$NEW" "$BASE/current"
rm -rf "$BASE/.old-$DATE"
```

El índice es independiente de la arquitectura: va en `repo/n27/sources`, no en
`repo/n27/x86_64/sources`. `main`, `master` y `musl` se seleccionan dentro del
índice con `NHOPKG_GIT_BRANCH` (o con el sidecar), no con la ruta. Así una sola
copia sirve a todas las arquitecturas.

`NHOPKG_SOURCES_REPO` debe apuntar al directorio que contiene los artefactos.
El destino autorizado en este despliegue es la URL plana de staging
`https://neonatox.vegnux.com/repo/n27/sources/`; los repositorios binarios de
producción (`repo.neonatox.vegnux.com/core|extra|multilib`) no se tocan.
Si usas el esquema `current` de arriba, apunta a `…/sources/current`.
Nunca publiques en una ruta de repositorio binario.

## 7. Probar el cliente

En la máquina cliente, pon la URL en `/etc/nhopkg/nhopkg.conf` y ejecuta:

```bash
sudo nhopkg -U
nhopkg-src --list-sources
nhopkg-src --show-source <proyecto>
nhopkg-src --show-source enchant   # regresión: rama por defecto master
```

- `nhopkg -U` necesita root.
- Si el índice falla, es **solo un aviso**: los repositorios binarios siguen
  funcionando.
- El config del sistema sobrescribe la variable de entorno: exportar
  `NHOPKG_SOURCES_REPO` no basta si `/etc/nhopkg/nhopkg.conf` la define vacía.
- `--show-source` comprueba `Source-Nhoid-SHA256`: una caché manipulada se
  rechaza.
- Con `NHOPKG_GIT_BRANCH` vacío, el sidecar del proyecto decide su ref; solo los
  proyectos ausentes del índice caen en la rama por defecto de Git.
- `--from-index` no es totalmente *offline*: sin extras no clona, pero el
  `nbuild()` puede seguir descargando fuentes upstream.

Prueba de lectura sin root ni red (útil para validar los artefactos ya
publicados):

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

## 8. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `HTTP 429` reiterado | Límite de API, aunque con token | `--rate 1`, esperar `Retry-After`, reintentar |
| `HTTP 401`/`403` | Token sin scopes o caducado | Regenerarlo con `read_api` + `read_repository` |
| `no valid nhoid entries` | Todos los `nhoid` fallaron la validación | Corregir recetas; revisar `report.txt` |
| `signing needs NHOPKG_SIGN_KEY` | Falta la clave | Definir `NHOPKG_SIGN_KEY` o usar `--no-sign` |
| Firma falla con `--batch` | Clave con passphrase sin desbloquear | Desbloquear el agente GPG antes de generar |
| El cliente no descarga | `lastsync` local ≥ remoto, o URL mal puesta | Comprobar `NHOPKG_SOURCES_REPO` y el número de `lastsync` |
| El cliente intenta buscar `main` en un repo solo-`master` | El índice se generó sin `master` y no hay sidecar que usar | Regenerar con `--refs "main master musl"`; la ruta de clone ya deja el ref vacío a Git |
| El cliente no ve una receta | Es `invalid-entry` o su ref no está en el índice | Revisar `report.txt` y el mapeo de refs |
| `rsync: orden no encontrada` | No está instalado | Usar `cp -p` con la lista de archivos |

## 9. Reglas de oro

1. Humo primero, `--limit 10` después, completo al final.
2. Caché fuera del directorio de salida.
3. Pasar `--refs "main master musl"` para este grupo y leer `report.txt`
   **antes** de publicar.
4. Publicar en `current` mediante sustitución atómica, solo en la URL plana de
   staging autorizada.
5. Token solo en la máquina que genera; nunca en el cliente ni en un log.
6. Staging siempre; los repositorios binarios de producción nunca se tocan.
7. Si hay firmas en el cliente, el staging debe incluir los `.asc`.

## Véase también

- [`configuracion.md`](configuracion.md) — variables `NHOPKG_SOURCES_REPO`,
  `NHOPKG_GIT_BRANCH`, `NHOPKG_AUTO_SOURCE_FALLBACK`
- [`nhopkg-src.md`](nhopkg-src.md) — comandos `--list-sources`,
  `--search-sources`, `--show-source`, `--from-index`
- [`repositorios.md`](repositorios.md) — relación con los repositorios binarios
