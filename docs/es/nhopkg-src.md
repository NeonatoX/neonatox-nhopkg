[← Índice](README.md)

# nhopkg-src — Herramienta de proyectos de paquetes fuente

## Descripción general

`nhopkg-src` crea, valida y compila proyectos de paquetes fuente para nhopkg. Trabaja con archivos `.srcnho` — tarballs planos que contienen el archivo de metadatos `nhoid` junto con parches y archivos adicionales, que `nhopkg -bv` utiliza para descargar, compilar e instalar paquetes binarios.

## Comandos

### `--init [<nombre>]`

Crea un nuevo directorio de proyecto de paquete fuente. Guías interactivas le guían a través de los campos requeridos y opcionales. Si se proporciona `<nombre>` como argumento, se utiliza como nombre del paquete y del directorio sin preguntar.

**Campos solicitados:**

| Campo | Requerido | Valor por defecto | Notas |
|---|---|---|---|
| Nombre | Sí | — | Desde argumento o entrada interactiva |
| Versión | No | `1.0` | |
| Release | No | `n2026` | |
| Nombre del mantenedor | No | `$USER` | Predefinir con `PKG_MAINTAINER_NAME` |
| Correo del mantenedor | No | `$USER@$HOSTNAME` | Predefinir con `PKG_MAINTAINER_EMAIL` |
| Licencia | No | `GPL-3.0-only` | |
| Arquitectura | No | `x86_64` | |
| URL | No | (vacío) | Sitio web del proyecto upstream |
| Descripción | No | (vacío) | |
| Packageurl | **Sí** | — | URL del tarball o `git+<url>` para fuentes git |
| Packageref | **Sí** si es git | — | Referencia a tag, commit o rama |
| SHA256 | Solo tarballs | S/n | Descarga el tarball y calcula SHA256 automáticamente. Si se omite, escribe `## SHA256:` como recordatorio |
| Splitpackage | No | (separado por espacios) | ej. `dev lib docs` |
| Provides | No | (separado por espacios) | |
| Conflicts | No | (separado por espacios) | |

**Estructura del proyecto creado:**

```
<nombre>/
├── nhoid              # Metadatos del paquete y funciones de compilación
├── sources/           # Tarballs descargados (no incluidos en .srcnho)
├── patches/           # Archivos *.patch y *.diff (incluidos en .srcnho)
├── others/            # Archivos adicionales (incluidos en .srcnho)
└── build/             # Directorio de compilación (no incluido en .srcnho)
```

**Plantilla nhoid generada:**

El archivo `nhoid` incluye:
- Cabecera `#%NHO-0.5` con todos los campos de metadatos
- Funciones placeholder: `nbuild()`, `ninstall()`, `npostinstall()`, `npostremove()` (todas establecidas a `noemptyfuncs`)
- Para paquetes divididos: funciones generadas `ninstall_<parte>()`, `npostinstall_<parte>()`, `npostremove_<parte>()` para cada parte
- Campos de dependencia comentados (`## BuildDep:`, `## Dep(post):`, etc.) para edición manual

Vea [`formato-nhoid.md`](formato-nhoid.md) para descripciones detalladas de los campos.

**Ejemplos:**

```bash
# Crear un proyecto interactivamente
nhopkg-src --init

# Crear un proyecto con nombre dado (omite el prompt del nombre)
nhopkg-src --init miapp

# Crear un proyecto de meta-paquete (apunta a un grupo de paquetes, sin fuente)
nhopkg-src --init miapp --meta
```

Con `--meta`, la herramienta crea un **meta-paquete**: un paquete sin archivos
fuente que solo depende de los paquetes de un grupo objetivo. Los metadatos se
rellenan automáticamente (`License: CUSTOM`, `Arch: any`, URL y descripción
derivadas del nombre), se muestra el prompt de `Target group name`, los
paquetes del grupo se resuelven desde los metadatos del repositorio y se
escriben como entradas `# BuildDep:`/`# Dep(post):`, y no se preguntan
Packageurl/hash/VCS. El proyecto resultante se empaqueta e instala con
normalidad, pero `nbuild()` permanece como `noemptyfuncs` y se genera un
`README.meta` al instalar.

Ejemplo de nhoid para tarball (después de descargar para SHA256):

```nhoid
#%NHO-0.5
# Package Maintainer:	usuario <usuario@host>

# Name:	miapp
# Version:	1.0
# Release:	n2026
# License:	GPL-3.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://example.com/miapp
# Description:	Mi aplicación
# Packageurl:	https://example.com/miapp-1.0.tar.gz
# SHA256:	abc123def456...  miapp-1.0.tar.gz
## BuildDep:	(añada aquí sus dependencias de compilación)
## OptionalBuildDep:	(añada aquí sus dependencias opcionales de compilación)
## Dep(post):	(añada aquí sus dependencias de ejecución)
## OptionalDep(post):	(añada aquí sus dependencias opcionales de ejecución)

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
```

Tarball sin SHA256 (recordatorio dejado):

```nhoid
# Packageurl:	https://example.com/miapp-1.0.tar.gz
## SHA256:	<pendiente>  miapp-1.0.tar.gz
```

Ejemplo de nhoid para fuente git:

```nhoid
# Packageurl:	git+https://github.com/usuario/miapp
# Packageref:	v1.0
```

Con paquetes divididos:

```nhoid
# Splitpackage:	dev lib

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_dev() {
    noemptyfuncs
}

npostinstall_dev() {
    noemptyfuncs
}

npostremove_dev() {
    noemptyfuncs
}

ninstall_lib() {
    noemptyfuncs
}

npostinstall_lib() {
    noemptyfuncs
}

npostremove_lib() {
    noemptyfuncs
}
```

---

### Respuestas predefinidas mediante variables de entorno

Cada usuario puede predefinir las respuestas exportando variables en el entorno.
Si las variables están exportadas, `nhopkg-src` las usa y omite la pregunta.
Vea la documentación en inglés para el comportamiento completo y la lista de
campos predefinidos (`PKG_NAME`, `PKG_VERSION`, `PKG_RELEASE`,
`PKG_MAINTAINER_NAME`, `PKG_MAINTAINER_EMAIL`, `PKG_GROUP`,
`PKG_REPOSITORY`, `PKG_LICENSE`, `PKG_ARCH`, `PKG_URL`, `PKG_DESCRIPTION`,
`PKG_PACKAGEURL`, `PKG_PACKAGEREF`, `PKG_HASH_TYPE`, `PKG_DOWNLOAD`,
`PKG_META_GROUP`, `PKG_SPLIT`, `PKG_PROVIDES`, `PKG_CONFLICTS`).

El nombre y el correo del mantenedor se definen por separado
(`PKG_MAINTAINER_NAME` y `PKG_MAINTAINER_EMAIL`); el correo toma como valor
por defecto `$USER@$HOSTNAME` (retrocede a `user@host`). En el nhoid se
escriben juntos en un único campo `# Package Maintainer: Name <email>`.

Ejemplo — crear un metapaquete sin ninguna pregunta:

```bash
export PKG_MAINTAINER_NAME="Jane Doe"
export PKG_MAINTAINER_EMAIL="jane@example.com"
export PKG_META_GROUP="ttf-fonts"
nhopkg-src --init fonts-meta --meta
```

---

### `--createpackage [--force]`

Empaqueta el directorio del proyecto actual en un tarball `.srcnho` plano.

**Lo que se incluye:**
- `nhoid` (requerido, primero se valida mediante `--validate`)
- Archivos `patches/*.patch` y `patches/*.diff`
- Archivos `others/*` (cualquier tipo)

**Lo que NO se incluye:**
- Directorio `sources/`
- Directorio `build/`

**Comportamiento:**
- Rechaza sobrescribir un archivo `.srcnho` existente a menos que se use `--force`
- El archivo de salida se nombra `<nombre>-<versión>-<release>.srcnho`

**Ejemplo:**

```bash
cd miapp/
nhopkg-src --createpackage
# Crea: miapp-1.0-n2026.srcnho

# Sobrescribir existente:
nhopkg-src --createpackage --force
```

---

### `--buildpackage`

Compila el paquete `.srcnho` usando `nhopkg -bv` con `sudo -k` (siempre solicita contraseña).

**Flujo:**
1. Lee `nhoid` en el directorio actual para obtener `<nombre>-<versión>-<release>`
2. Busca `<nombre>-<versión>-<release>.srcnho`
3. Aborta si el archivo `.srcnho` no se encuentra
4. Ejecuta `sudo -k nhopkg -bv <archivo>.srcnho`

**Ejemplo:**

```bash
cd miapp/
nhopkg-src --createpackage
nhopkg-src --buildpackage
# Ejecuta: sudo -k nhopkg -bv miapp-1.0-n2026.srcnho
```

---

### `--validate [<archivo_nhoid>]`

Valida un archivo nhoid (por defecto `./nhoid`). Devuelve código de salida 0 si es válido, 1 si hay errores.

**Verificaciones realizadas:**

| Verificación | Tipo | Descripción |
|---|---|---|
| Cabecera `#%NHO-0.5` | Error | Debe estar presente |
| `# Name:` | Error | Debe estar presente y no vacío |
| `# Version:` | Error | Debe estar presente y no vacío |
| `# Release:` | Error | Debe estar presente y no vacío |
| `# Packageurl:` | Error | Debe estar presente y no vacío (no requerido en meta-paquetes) |
| `# Packageref:` | Error | Requerido si Packageurl comienza con `git+` (no requerido en meta-paquetes) |
| `# SHA256:` | Advertencia | Recomendado para fuentes tarball, no requerido |
| Contenido de `nbuild()` | Error | Debe tener comandos reales (no solo `noemptyfuncs`), salvo meta-paquetes |
| Contenido de `ninstall()` | Error | Debe tener comandos reales de instalación (no solo `noemptyfuncs`), salvo meta-paquetes |
| Existencia de `npostinstall()` | Error | La función debe estar definida |
| Existencia de `npostremove()` | Error | La función debe estar definida |
| Existencia de funciones divididas | Error | `ninstall_<parte>()` debe existir para cada parte dividida |
| Superposición Provides/Conflicts | Error | El mismo nombre no debe aparecer en ambos |

**Ejemplos:**

```bash
nhopkg-src --validate
nhopkg-src --validate ./nhoid
nhopkg-src --validate /ruta/al/nhoid
```

## Formato de archivo .srcnho

El archivo `.srcnho` es un archivo tar plano (sin compresión, sin subdirectorios). Su contenido es extraído por `nhopkg -bv` en un directorio temporal, donde `nhopkg` lee el `nhoid`, descarga la fuente mediante `Packageurl`, verifica `SHA256`, ejecuta `nbuild()` y `ninstall()`, y produce el paquete binario `.nho` final.

**Contenido:**

```
nhoid
some.patch
another.diff
archivo_extra
```

### `--get-source <proyecto> [--ref <ref>]`

Clona un proyecto fuente desde el repositorio `NHOPKG_GIT_SOURCES`.

El proyecto se clona en un subdirectorio con el nombre del proyecto. Si se proporciona `--ref`, se pasa a git como referencia de tag, rama o commit. Después de clonar, se crean los directorios estándar `patches/` y `others/` para que el proyecto esté listo para editar y empaquetar.

La URL del repositorio se construye como `${NHOPKG_GIT_SOURCES}/${proyecto}.git`.

**Ejemplos:**

```bash
# Clonar el proyecto gcc
nhopkg-src --get-source gcc

# Clonar con una rama/tag específica
nhopkg-src --get-source gcc --ref n2027
```

## Véase también

- [`formato-nhoid.md`](formato-nhoid.md) — referencia completa de campos nhoid
- `nhopkg -bv` — compila un paquete binario desde un paquete fuente `.srcnho`
