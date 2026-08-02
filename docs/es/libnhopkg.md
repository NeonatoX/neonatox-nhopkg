[← Índice](README.md)

# La librería base `libnhopkg`

**`libnhopkg`** es la librería compartida principal de nhopkg. Se instala como
`/usr/lib/nhopkg/libnhopkg` y es cargada (mediante `source`) por el script
principal (`nhopkg`), por las herramientas independientes (`nhoget`, `nhouser`,
`nhopkg-src`, `nhopkg-repos`, `nhopkg-overlay`) y por las librerías
especializadas (`libnhopkg_udepsys`, `libnhopkg_download`, `libnhopkg_crypto`,
`libnhopkg_nhouser`).

Proporciona las funciones base: mensajes con color, directorios temporales,
extracción de datos de paquetes, verificación de hashes, generación de bases de
datos de repositorio/instalados y comprobaciones de versión. También define las
constantes de versión públicas.

## Constantes de versión

Variable | Valor | Descripción
---|---|---
`NHOPKG_VERSION` | `@PACKAGE_VERSION@` | Versión de nhopkg (desde la compilación).
`NHOID_VERSION` | `0.5` | Versión del formato nhoid soportada por esta versión.
`BINLOCATE` | fijado en la compilación | Binario `locate`/`plocate` usado para la base de datos de archivos.

## Orden de carga

Las herramientas que necesitan `libnhopkg` lo localizan a través de `NHOPKG_LIB`
(definida en `nhopkg.conf`) y lo cargan con `source` antes que cualquier otra
librería:

    source "${NHOPKG_LIB}"
    source "${NHOPKG_LIB%/libnhopkg}/libnhopkg_udepsys"

## Funciones de mensajes

Función | Descripción
---|---
`echog()` | Imprime un mensaje en el idioma del sistema con salto de línea (usa gettext cuando `NHOPKG_GETTEXT=yes`).
`echogn()` | Imprime un mensaje en el idioma del sistema sin salto de línea.

## Configuración y entorno

Función | Descripción
---|---
`setup_busybox_path()` | Si `NHOPKG_USE_BUSYBOX=yes`, antepone `/usr/lib/nhopkg/bin` (applets de BusyBox) a `PATH`. Se invoca automáticamente al cargar la librería. Ver [PATH privado de BusyBox](configuracion.md#path-privado-de-busybox).

## Directorios y permisos

Función | Descripción
---|---
`get_pwd_dir()` | Establece `CWD` (directorio de trabajo actual, con respaldo en `/tmp`) y `DIROWNER` (`usuario:grupo`).
`check_if_root_uid()` | Termina con error si no se ejecuta como root.
`make_tmp_dir()` | Crea un directorio temporal seguro y establece `NHOPKG_TMPDIR`.
`check_if_ok()` | Comprueba el resultado del comando anterior; si falla, imprime un mensaje, limpia y sale con 1.
`cleanup_tmp_dir()` | Elimina `NHOPKG_TMPDIR` recursivamente.
`cleanup_all()` | Elimina el archivo de bloqueo de nhopkg y el directorio temporal.
`cleanup_build_dir()` | Ofrece eliminar el directorio de compilación actual bajo `NHOPKG_BUILDIR`.

## Funciones de datos de paquetes

Función | Descripción
---|---
`get_basic_data()` | Extrae `pkgname`, `pkgversion`, `pkgrevision` y `pkgdescription` de un archivo de información de paquete. Falla si falta algún campo.
`get_nhoid_data()` | Extrae todos los campos de un archivo `.nhoid` (`pkgname`, `pkgversion`, `pkgrevision`, `pkglicense`, `pkggroup`, `pkgrepo`, `pkgurl`, `pkgdescription`, `pkgsha256`, `pkgmd5`, `pkgsha512`, `pkgbsum`, `pkgarch`, `pkgos`, `pkginstalledsize`, `pkgsrcurl`, `pkggitref`). Gestiona paquetes divididos (`# Splitpackage:`) creando variables `pkgdescription_<parte>`. Valida el marcador de formato `#%NHO-` contra `NHOID_VERSION`.
`get_good_file_name()` | Deriva un nombre corto a partir de una ruta completa, usado para buscar dependencias.
`nhopicker()` | Mueve archivos de un árbol fuente (staging) a un árbol destino usando patrones de `find -path`. Se usa para dividir paquetes en subpaquetes (p. ej. `nhopicker destdir pkg-dev "*.a" "*.h" "*.pc"`).
`noemptyfuncs()` | Función vacía de no-operación, usada donde se requiere un cuerpo no vacío.

## Verificación de hashes y descargas

Función | Descripción
---|---
`verify_file_hash()` | Calcula el hash (`md5`, `sha256`, `sha512` o `bsum`) de un archivo y lo compara con el valor esperado. Devuelve 0 si coincide, 1 si no, 2 si no hay herramienta de hash disponible.
`get_hash_from_nhoid()` | Lee el tipo de hash solicitado de un archivo `.nhoid`.
`check_package_hash()` | Verifica el hash de un paquete descargado contra los metadatos del nhoid.
`download_with_hash_check()` | Descarga una URL y verifica el archivo resultante contra el hash esperado.
`verify_local_tarball_hash()` | Verifica un tarball local contra el hash registrado en el nhoid.

## Generación de bases de datos

Función | Descripción
---|---
`generate_repo_db()` | Construye `repo.db` para un repositorio (o todos los activos) en `${NHOPKG_LOCALSTATEDIR}/repo/<nombre>`, extrayendo los campos de cada `.nhoid` de paquete.
`generate_installed_db()` | Construye la base de datos de paquetes instalados.
`shooter_updates()` | Compara la base de datos local de instalados con los metadatos del repositorio e informa de actualizaciones disponibles.

## Librerías relacionadas

Librería | Propósito | Ver también
---|---|---
`libnhopkg_udepsys` | Resolución unificada de dependencias (`dep_resolve_from_nhoid`, `dep_install_queue`, `dep_check_conflicts`, `version_compare`, `get_repo_url`). | [`dependencias.md`](dependencias.md)
`libnhopkg_download` | Sistema de descarga unificado (GNU wget, curl, wget de BusyBox; clonado VCS; resume; verificación de hash). | [`nhoget.md`](nhoget.md)
`libnhopkg_crypto` | Ayudas de firma y verificación GPG. | [`seguridad.md`](seguridad.md)
`libnhopkg_nhouser` | Gestión idempotente de usuarios/grupos (doble backend shadow-utils + BusyBox). | [`usuarios-servicios.md`](usuarios-servicios.md)
