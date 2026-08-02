[← Índice](README.md)

# nhoget — Herramienta de descarga unificada

`nhoget` es el sistema de descarga unificada para el gestor de paquetes nhopkg. Proporciona capacidades de descarga HTTP/HTTPS y VCS transparentes a todos los componentes de nhopkg (construcciones, instalaciones, actualizaciones de repositorios y creación de paquetes fuente), además de funcionar como una herramienta CLI independiente utilizable desde scripts post-instalación, recetas de construcción o un terminal.

## Justificación

Antes de `nhoget`, nhopkg usaba llamadas ad-hoc a `wget` y `git clone` dispersas por todo el código base. Esto dificultaba:

- Cambiar entre backends de descarga (GNU wget, curl, BusyBox wget)
- Añadir tipos de VCS más allá de git (svn, hg)
- Aplicar políticas coherentes de reintentos, tiempo de espera y reanudación
- Auditar o extender el comportamiento de descarga

`nhoget` centraliza toda la lógica de descarga en una única biblioteca (`libnhopkg_download`) expuesta a través de una herramienta CLI y cargada de forma transparente por `nhopkg`.

## Garantía de transparencia

`nhoget` es un **reemplazo transparente**: ningún flujo de trabajo existente de nhopkg, formato nhoid o interfaz de usuario ha cambiado. Las mismas opciones (`nhopkg -b`, `-C`, `-S`, `-U`) se comportan de forma idéntica. Internamente, cada `wget` y `git clone` ha sido reemplazado por `nhoget_url` / `nhoget_vcs`.

## Comandos

### `download`

Descarga un archivo vía HTTP/HTTPS.

```
nhoget download [opciones] <url> [<dest>]
```

Si se omite `<dest>`, el nombre del archivo se deriva de la URL. Use `-o` para especificar una ruta de salida exacta, o `-O` para especificar un directorio de salida. Soporta verificación de hash con `--hash`.

### `clone`

Clona un repositorio VCS.

```
nhoget clone [opciones] <url> [<dest>]
```

Por defecto usa git. Use `--type svn` o `--type hg` para otros tipos de VCS. El destino por defecto es el nombre base de la URL (con `.git` eliminado para URLs de git).

### `fetch`

Detecta automáticamente el tipo de fuente desde la URL y descarga o clona.

```
nhoget fetch [opciones] <url> [<dest>]
```

Reglas de detección:

| Patrón de URL | Comportamiento |
|-------------|-----------|
| `git+<url>` o `*.git` | Git clone |
| `svn+<url>` | Subversion checkout |
| `hg+<url>` | Mercurial clone |
| URL simple | Descarga de tarball + extracción automática |

Los tarballs se extraen con `--strip-components=1` en el directorio de destino. Formatos soportados: `.tar.zst`, `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.zip`, `.AppImage`.

Para tipos VCS, `nhoget fetch` intenta una actualización incremental (fetch + checkout) si el destino ya existe, recurriendo a un clon nuevo si falla.

### `patch`

Descarga un archivo de parche o diff, guardándolo con el nombre de archivo original de la URL.

```
nhoget patch <url>
```

El archivo se guarda como `../<nombre-de-archivo>` (directorio padre del directorio de trabajo).

## Opciones

| Corta | Larga | Descripción |
|-------|-------|-------------|
| `-o` | `--output FILE` | Guardar en un archivo específico (solo download) |
| `-O` | `--output-dir DIR` | Guardar en un directorio |
| `-r` | `--resume` | Reanudar una descarga parcial |
| `-t` | `--timeout SECS` | Tiempo de espera de conexión (por defecto: 20) |
| | `--retries N` | Número de reintentos (por defecto: 3) |
| `-q` | `--quiet` | Suprimir salida no esencial |
| `-v` | `--verbose` | Salida verbosa |
| | `--hash TIPO:VALOR` | Verificar hash después de la descarga (ej. `sha256:abc...`) |
| | `--type TIPO` | Forzar tipo de fuente: `tarball`, `git`, `svn`, `hg` |
| | `--ref REF` | Referencia VCS (tag, rama, commit para git; revisión para svn) |
| | `--depth N` | Profundidad de clon superficial (solo git) |
| | `--backend BACKEND` | Forzar backend: `wget`, `curl`, `wget-bb`, `auto` |
| `-h` | `--help` | Mostrar ayuda |
| | `--version` | Mostrar versión |

## Backends

El backend `auto` sondea en este orden:

1. **GNU wget** — preferido por compatibilidad hacia atrás (no curl, a pesar de que curl es más portable)
2. **curl** — usado si GNU wget no está disponible
3. **BusyBox wget** — soporta HTTPS; los reintentos se implementan mediante un bucle manual (BusyBox no dispone de la opción `-t`)

## La librería `libnhopkg_download`

Toda la lógica de descarga reside en la librería **`libnhopkg_download`** (instalada como `/usr/lib/nhopkg/libnhopkg_download`). El CLI `nhoget` es un envoltorio ligero sobre ella, y la librería también es cargada directamente por `nhopkg`, `nhopkg-src` y el resolutor de dependencias. Funciones principales:

Función | Propósito
---|---
`nhoget_detect_backend()` | Selecciona el backend de descarga (`wget`, `curl`, `wget-bb`) respetando `NHOGET_BACKEND`.
`nhoget_url()` | Descarga una única URL con reintentos, tiempo de espera y reanudación opcional.
`nhoget_url_wget_bb()` | Variante para BusyBox wget (bucle de reintentos manual; BusyBox no tiene `-t`).
`nhoget_verify_hash()` | Verifica un archivo descargado contra una especificación de hash `TIPO:VALOR`.
`nhoget_vcs()` / `nhoget_vcs_git()` / `nhoget_vcs_svn()` / `nhoget_vcs_hg()` | Operaciones de clonado/checkout VCS.
`nhoget_fetch()` | Detecta automáticamente el tipo de fuente y lo redirige a las rutas URL o VCS.
`nhoget_fetch_tarball()` | Descarga y extrae automáticamente un tarball (con `--strip-components=1`).

El comportamiento de reanudación y verificación de hash es, por tanto, idéntico tanto si la descarga se dispara desde el CLI `nhoget`, desde una receta de compilación, o desde las llamadas `nhoget_url` del resolutor de dependencias.

## Configuración

El comportamiento se controla mediante variables de entorno o `/etc/nhopkg/nhopkg.conf`:

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `NHOGET_BACKEND` | `auto` | Selección de backend (`wget`, `curl`, `wget-bb`, `auto`) |
| `NHOGET_TIMEOUT` | `20` | Tiempo de espera de conexión en segundos |
| `NHOGET_RETRIES` | `3` | Número de reintentos de descarga |
| `NHOGET_RESUME` | `yes` | Habilitar reanudación de descargas parciales |

## Prefijos de URL

Los repositorios VCS se pueden especificar con prefijos de URL:

- `git+https://ejemplo.com/repo` — Repositorio Git
- `svn+https://ejemplo.com/svn/repo` — Repositorio Subversion
- `hg+https://ejemplo.com/repo` — Repositorio Mercurial
- `https://ejemplo.com/paquete.tar.zst` — Tarball simple (extracción automática)

Para compatibilidad hacia atrás, las URLs que terminan en `.git` también se tratan como repositorios Git (sin necesidad del prefijo `git+`).

## Véase también

- [Referencia de comandos](comandos.md) — Comandos principales de nhopkg
- [Visión general de la arquitectura](arquitectura.md)
