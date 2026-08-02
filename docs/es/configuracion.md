# Configuración de Nhopkg

## Precedencia de configuración

Los ajustes se resuelven en el siguiente orden (las fuentes posteriores anulan a las anteriores):

1. **Opciones de línea de comandos** — máxima prioridad, siempre ganan
2. **Configuración del sistema** — `/etc/nhopkg/nhopkg.conf`
3. **Configuración por defecto** — `/usr/share/nhopkg/nhopkg.conf` — incluida con el paquete, prioridad mínima

El archivo usa sintaxis estándar de **bash**:

- `#` para comentarios
- `VAR="value"` para asignaciones
- Se admite sustitución de variables (p. ej. `${SYSCONFDIR}/nhopkg`)

---

## 1. Principal — Rutas

Directorios básicos y rutas base utilizados internamente por nhopkg.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `prefix` | `@prefix@` | Prefijo de instalación (definido por Meson) |
| `datarootdir` | `@datarootdir@` | Directorio base de datos (Meson) |
| `SYSCONFDIR` | `@sysconfdir@` | Directorio de configuración del sistema (normalmente `/etc`) |
| `NHOPKG_SYSCONFDIR` | `${SYSCONFDIR}/nhopkg` | Directorio de configuración específico de nhopkg |
| `NHOPKG_DATADIR` | `${datarootdir}/@PACKAGE@` | Directorio de datos de nhopkg |
| `LOCALSTATEDIR` | `@localstatedir@` | Directorio de estado local (normalmente `/var`) |
| `NHOPKG_LOCALSTATEDIR` | `${LOCALSTATEDIR}/nhopkg` | Directorio de estado de nhopkg (p. ej. `/var/nhopkg`) |
| `TMPDIR` | `/tmp` | Directorio temporal para extracción |
| `TEMPLATE_TMPDIR` | `.nhopkg.XXXXXXXXXX` | Plantilla para subdirectorios temporales |
| `BUILDIR` | `/usr/src` | Directorio base de compilación de fuentes |
| `NHOPKG_BUILDIR` | `${BUILDIR}/nhopkg` | Directorio de compilación de nhopkg |
| `NHOPKG_LIB` | `@prefix@/lib/nhopkg/libnhopkg` | Ruta a la biblioteca `libnhopkg` |
| `NHOPKG_LOCKFILE` | `/var/lock/nhopkg` | Archivo de bloqueo para evitar instancias concurrentes de nhopkg |

**Valores aceptados:** cualquier ruta absoluta válida.

---

## 2. Opciones — Comportamiento

Opciones generales de comportamiento para el manejo de dependencias, verificación, verbosidad y características experimentales.

| Variable | Valor por defecto | Valores aceptados | Descripción |
|---|---|---|---|
| `NHOPKG_CHECKDEPS` | `yes` | `yes`, `no` | Habilitar verificación de dependencias (requeridas y opcionales) |
| `NHOPKG_PURGE` | `no` | `yes`, `no` | Habilitar la eliminación de dependencias inversas al desinstalar paquetes |
| `NHOPKG_CHECKSHA256` | `yes` | `yes`, `no` | Verificar las sumas SHA256 de los paquetes |
| `NHOPKG_CHECKARCH` | `yes` | `yes`, `no` | Verificar la compatibilidad de arquitectura de los paquetes |
| `VERBOSE_MODE` | `no` | `yes`, `no` | Habilitar salida verbosa |
| `STRIP_BINARIES` | `no` | `yes`, `no` | Eliminar símbolos de binarios y bibliotecas después de la instalación (experimental) |
| `NHOHOLD` | `"nhopkg glibc gcc"` | Nombres de paquete separados por espacios | Paquetes a retener: nunca eliminar sus archivos al desinstalar |
| `NHOPKG_USE_BUSYBOX` | `no` | `yes`, `no` | Usar el PATH privado de BusyBox estático (ver [PATH privado de BusyBox](#path-privado-de-busybox)) |

### PATH privado de BusyBox

Cuando `NHOPKG_USE_BUSYBOX=yes`, nhopkg antepone `/usr/lib/nhopkg/bin` a `PATH`
(vía `setup_busybox_path()` en `libnhopkg`). Ese directorio contiene un BusyBox
**enlazado estáticamente** más los enlaces simbólicos a sus applets, generados
en la instalación por el helper **`nhopkg-bb-setup`** (instalado como
`/usr/lib/nhopkg/nhopkg-bb-setup` e invocado automáticamente como paso de
post-instalación).

Esto es crítico para las distribuciones rolling: al estar BusyBox y zstd
enlazados estáticamente, nhopkg sigue funcionando incluso tras una actualización
de la biblioteca C (musl/glibc) que de otro modo rompería todos los binarios
dinámicos. Los applets provisionados son: `awk`, `sed`, `grep`, `sort`, `cut`,
`tr`, `head`, `tail`, `wc`, `xargs`, `mkdir`, `cp`, `mv`, `rm`, `ln`, `ls`,
`du`, `stat`, `basename`, `dirname`, `mktemp`, `chmod`, `chown`, `tar`, `gzip`,
`gunzip`, `md5sum`, `sha1sum`, `sha256sum`, `sha512sum`, `wget`, `id`, `date`,
`sleep`, `cat`, `nproc`, `unshare`, `od`, `realpath`, `chroot`, `adduser`,
`addgroup` y `passwd`.

El helper omite cualquier applet no compilado en el BusyBox instalado, limpia
los enlaces simbólicos obsoletos de versiones anteriores y notifica cuántos
enlaces creó.

---

## 3. Sistema de init

Selecciona el sistema de init utilizado por el sistema objetivo. Afecta a los archivos de servicio o scripts que se instalan.

| Variable | Valor por defecto | Valores aceptados | Descripción |
|---|---|---|---|
| `INITSYSTEM` | `systemd` | `systemd`, `sysvinit` | Sistema de init a utilizar |

---

## 4. Unidades Systemd de BLFS

Configuración para los archivos de unidades systemd proporcionados por BLFS. Se usa solo cuando `INITSYSTEM=systemd`.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `BLFS_DIR` | `${NHOPKG_LOCALSTATEDIR}/cache/blfs` | Directorio base de caché para los paquetes BLFS extraídos (fuera de `FIND_DIRS`) |
| `SYSTEMD_BLFS_VER` | `20251204` | Versión del paquete de unidades systemd de BLFS |
| `SYSTEMD_BLFS_DIR` | `${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}` | Directorio local de las unidades extraídas |
| `SYSTEMD_BLFS_URL` | `https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz` | URL de descarga |

---

## 5. Scripts SysVinit de BLFS

Configuración para los scripts de arranque SysVinit de BLFS. Se usa solo cuando `INITSYSTEM=sysvinit`.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `SYSV_BLFS_VER` | `20251220` | Versión del paquete de bootscripts de BLFS |
| `SYSV_BLFS_DIR` | `${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}` | Directorio local de los scripts extraídos |
| `SYSV_BLFS_URL` | `https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz` | URL de descarga |

---

## 6. Firma y verificación de paquetes

Configuración GPG para firmar y verificar paquetes binarios.

| Variable | Valor por defecto | Valores aceptados | Descripción |
|---|---|---|---|
| `NHOPKG_TRUSTED_KEYS_DIR` | `"${NHOPKG_SYSCONFDIR}/trusted-keys/"` | Ruta de directorio válida | Directorio que contiene las claves públicas de confianza |
| `NHOPKG_SIGN_PACKAGES` | `yes` | `yes`, `no` | Firmar paquetes durante la compilación (normalmente para mantenedores) |
| `NHOPKG_SIGN_KEY` | `"repo@neonatox.vegnux.com"` | ID de clave GPG o email | Clave utilizada para firmar |
| `NHOPKG_VERIFY_SIGNATURE` | `yes` | `yes`, `no` | Verificar las firmas de los paquetes durante la instalación |
| `NHOPKG_REQUIRE_SIGNATURE` | `no` | `yes`, `no` | Abortar la instalación si la firma falta o no es válida |

---

## 7. Repositorios

Configuración de repositorios: qué repositorios están activos y dónde están ubicados.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `NHOPKG_ACTIVE_REPOS` | `"core extra multilib"` | Lista de nombres de repositorios activos separados por espacios |
| `NHOPKG_REPO_CORE` | `@NHOPKG_REPO_CORE@` | URL del repositorio **core** (definida en el momento de la configuración) |
| `NHOPKG_REPO_EXTRA` | `@NHOPKG_REPO_EXTRA@` | URL del repositorio **extra** |
| `NHOPKG_REPO_MULTILIB` | `@NHOPKG_REPO_MULTILIB@` | URL del repositorio **multilib** |

**Valores aceptados para `NHOPKG_ACTIVE_REPOS`:** cualquier lista de nombres de repositorio en minúsculas separados por espacios (debe coincidir con una variable `NHOPKG_REPO_*` correspondiente).

Las URLs de los repositorios pueden incluir varios mirrors por repositorio (consulta el código fuente de nhopkg para conocer la sintaxis de mirrors).

---

## 8. Fuentes Git

Repositorio Git por defecto utilizado para obtener las fuentes de los paquetes `.srcnho`.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `NHOPKG_GIT_SOURCES` | `https://gitlab.com/neonatox-sources` | URL del repositorio Git para paquetes fuente |

---

## 9. Soporte de idiomas

Soporte de internacionalización basado en gettext.

| Variable | Valor por defecto | Valores aceptados | Descripción |
|---|---|---|---|
| `NHOPKG_GETTEXT` | `yes` | `yes`, `no` | Habilitar traducciones gettext |
| `TEXTDOMAIN` | `@PACKAGE_NAME@` | Nombre de dominio de texto | Dominio de texto de gettext (no editar) |
| `TEXTDOMAINDIR` | `@localedir@` | Ruta de directorio | Directorio de locales de gettext (no editar) |

---

## 10. Configuración de compilación — Optimizaciones

Variables leídas por nhopkg y exportadas antes de la ejecución de `nbuild()`. Se usan al compilar paquetes desde el código fuente.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `NHOPKG_MACHINE` | `generic` | Objetivo de optimización de CPU (p. ej. `sandybridge`, `native`, `generic`, `x86-64`). Si está vacía o comentada, nhopkg usa `generic` |
| `NHOPKG_CFLAGS` | `"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"` | Flags base del compilador C (se añade el objetivo de máquina) |
| `NHOPKG_CXXFLAGS` | `$NHOPKG_CFLAGS` | Flags del compilador C++. Si está vacío, usa `NHOPKG_CFLAGS` |
| `NHOPKG_CPPFLAGS` | `""` (vacío) | Flags del preprocesador C |
| `NHOPKG_LDFLAGS` | `"-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"` | Flags del enlazador |
| `NHOPKG_BUILD_JOBS` | `""` (vacío) | Trabajos de compilación en paralelo. Si está vacío, se auto-detecta como `nproc - 2` (mínimo 1) |
| `NHOPKG_MAKEFLAGS` | `""` (vacío) | Flags de make. Si está vacío, se auto-generan desde `NHOPKG_BUILD_JOBS` |
| `NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL` | `""` (vacío) | Nivel de paralelismo CMake. Si está vacío, se define desde `NHOPKG_BUILD_JOBS` |

---

## 11. Creación de paquetes fuente

Ajustes utilizados al generar paquetes binarios desde el código fuente.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `FIND_DIRS` | `/bin /boot /etc /lib /opt /sbin /srv /usr` | Lista de directorios separados por espacios/saltos de línea que se escanean para detectar archivos instalados |
| `NOUPGRADE_FILES` | `mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache ${NHOPKG_BUILDIR} /etc/mtab /etc/fstab` | Lista de archivos/directorios separados por espacios/saltos de línea que nunca se sobrescriben en una actualización |

---

## 12. Base de datos

Configuración de la base de datos interna de archivos de nhopkg.

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `NHOPKG_DB` | `${NHOPKG_LOCALSTATEDIR}/nhopkg.db` | Ruta del archivo de base de datos de paquetes |
| `NO_DIRS_IN_DB` | `/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var` | Lista de directorios separados por espacios/saltos de línea excluidos del indexado de la base de datos |

Los directorios de `NO_DIRS_IN_DB` nunca se rastrean en la base de datos de paquetes, incluso si un paquete instala archivos allí.

---

## Ejemplo de configuración

```bash
#====================================================================
# /etc/nhopkg/nhopkg.conf
#====================================================================

# --- Principal ---
NHOPKG_SYSCONFDIR=/etc/nhopkg
NHOPKG_LOCALSTATEDIR=/var/nhopkg
TMPDIR=/tmp
NHOPKG_BUILDIR=/usr/src/nhopkg

# --- Opciones ---
NHOPKG_CHECKDEPS=yes
NHOPKG_PURGE=no
NHOPKG_CHECKSHA256=yes
NHOPKG_CHECKARCH=yes
VERBOSE_MODE=no
STRIP_BINARIES=no
NHOHOLD="nhopkg glibc gcc"
NHOPKG_USE_BUSYBOX=no

# --- Sistema de init ---
INITSYSTEM=systemd

# --- Unidades Systemd de BLFS ---
BLFS_DIR=${NHOPKG_LOCALSTATEDIR}/cache/blfs
SYSTEMD_BLFS_VER=20251204
SYSTEMD_BLFS_DIR=${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}
SYSTEMD_BLFS_URL=https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz

# --- Scripts SysVinit de BLFS ---
SYSV_BLFS_VER=20251220
SYSV_BLFS_DIR=${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}
SYSV_BLFS_URL=https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz

# --- Firma de paquetes ---
NHOPKG_TRUSTED_KEYS_DIR="${NHOPKG_SYSCONFDIR}/trusted-keys/"
NHOPKG_SIGN_PACKAGES=yes
NHOPKG_SIGN_KEY="repo@neonatox.vegnux.com"
NHOPKG_VERIFY_SIGNATURE=yes
NHOPKG_REQUIRE_SIGNATURE=no

# --- Repositorios ---
NHOPKG_ACTIVE_REPOS="core extra multilib"
NHOPKG_REPO_CORE="https://repo.neonatox.vegnux.com/core"
NHOPKG_REPO_EXTRA="https://repo.neonatox.vegnux.com/extra"
NHOPKG_REPO_MULTILIB="https://repo.neonatox.vegnux.com/multilib"

# --- Fuentes Git ---
NHOPKG_GIT_SOURCES=https://gitlab.com/neonatox-sources

# --- Idioma ---
NHOPKG_GETTEXT=yes

# --- Configuración de compilación ---
NHOPKG_MACHINE="generic"
NHOPKG_CFLAGS="-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"
NHOPKG_CXXFLAGS="$NHOPKG_CFLAGS"
NHOPKG_CPPFLAGS=""
NHOPKG_LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"
NHOPKG_BUILD_JOBS=""
NHOPKG_MAKEFLAGS=""
NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL=""

# --- Creación de paquetes fuente ---
FIND_DIRS="/bin /boot /etc /lib /opt /sbin /srv /usr"
NOUPGRADE_FILES="mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache /usr/src/nhopkg /etc/mtab /etc/fstab"

# --- Base de datos ---
NHOPKG_DB=/var/nhopkg/nhopkg.db
NO_DIRS_IN_DB="/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var"
```
