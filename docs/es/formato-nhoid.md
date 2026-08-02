# Formato de archivo nhoid — nhopkg v0.5.1

El archivo nhoid es el descriptor de metadatos utilizado tanto en los paquetes binarios (`.nho`) como en los de fuente (`.srcnho`). Define la identidad del paquete, las dependencias, los pasos de compilación, la lógica de instalación y las tareas posteriores a la instalación.

## Reglas del formato

- Los campos usan la sintaxis `# FieldName:\tvalue` (separados por tabulador)
- Los comentarios usan `##` (doble almohadilla) — los ignora el analizador
- El archivo debe comenzar con la cabecera `#%NHO-0.5`
- Las funciones (`nbuild()`, `ninstall()`, etc.) definen código ejecutable

## Cabecera

```nhoid
#%NHO-0.5
# Package Maintainer:	Nombre <email>
```

Si la versión de la cabecera no coincide con `NHOID_VERSION`, el paquete se rechaza.

## Campos de metadatos

| Campo | Obligatorio | Descripción |
|---|---|---|
| `# Name:` | Sí | Nombre del paquete |
| `# Version:` | Sí | Versión del paquete (p. ej. `1.0`, `2.15.6`) |
| `# Release:` | Sí | Release del paquete (p. ej. `n2026`) |
| `# License:` | No | Licencia del software (p. ej. `GPL-3.0-only`, `MIT`) |
| `# Group:` | No | Clasificación de grupo del paquete (puede aparecer más de una vez; un paquete puede pertenecer a varios grupos) |
| `# Repository:` | No | Repositorio de destino (`core`, `extra`, `multilib`) |
| `# Arch:` | No | Arquitectura(s) de destino, separadas por espacios (p. ej. `i686 x86_64`) |
| `# OS:` | No | Sistema operativo de destino |
| `# Url:` | No | Sitio web del proyecto upstream |
| `# Description:` | No | Descripción del paquete |
| `# Installed-Size:` | No | Tamaño instalado en bytes (calculado automáticamente durante la compilación) |
| `# Build-Duration:` | No | Tiempo de compilación (registrado automáticamente) |
| `# Build-Date:` | No | Marca de tiempo de compilación (registrada automáticamente) |
| `# Build-Host:` | No | Nombre de host de compilación (registrado automáticamente) |

### Metadatos de fuente

| Campo | Obligatorio | Descripción |
|---|---|---|
| `# Packageurl:` | Sí | URL de la fuente. Para tarballs: `https://...tar.gz`. Para fuentes de control de versiones, usa un prefijo de esquema: `git+`, `svn+` o `hg+` (una URL que termine en `.git` también se trata como Git) |
| `# Packageref:` | Solo si es VCS | Referencia de control de versiones: tag, commit o rama (git); revisión (svn, hg) |
| `# SHA256:` | Recomendado para tarballs | Suma SHA256 + nombre de archivo. Alternativa: `# MD5:`, `# SHA512:`, `# BSUM:` |

Ejemplo:

```nhoid
# Packageurl:	https://example.com/pkg-1.0.tar.gz
# SHA256:	a1b2c3d4...  pkg-1.0.tar.gz
```

Para fuentes de control de versiones, el prefijo de esquema selecciona el sistema:

```nhoid
# Packageurl:	git+https://github.com/user/repo
# Packageref:	v1.0

# Packageurl:	svn+https://svn.example.com/project
# Packageref:	r42

# Packageurl:	hg+https://hg.example.com/project
# Packageref:	1.0
```

### Paquetes divididos (split)

Los paquetes divididos permiten que una única fuente produzca varios subpaquetes.

```nhoid
# Splitpackage:	dev lib docs
```

Cada parte dividida tiene su propio conjunto de campos de metadatos usando el sufijo `_<parte>`:

```nhoid
# Description_dev:	Cabeceras de desarrollo
# Description_lib:	Bibliotecas compartidas
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
# Group_docs:	doc
# Repository_dev:	extra
# Dep_dev(post):	algúnpaquete
# Backup_dev:	/etc/foo-dev.conf
```

Los campos `# Backup_<parte>:` específicos de subpaquetes funcionan igual que el campo principal `# Backup:`: los archivos del subpaquete se preservan antes de la extracción y se restauran después. `# Group_<parte>:`, `# Repository_<parte>:` y `# Provides_<parte>:` / `# Conflicts_<parte>:` sobrescriben los campos principales correspondientes para el subpaquete.

### Provides y Conflicts

```nhoid
# Provides:	sdl2
# Provides_lib32:	lib32-sdl2
# Conflicts:	sdl2
# Conflicts_lib32:	lib32-sdl2
```

### Backup

Los archivos listados en `# Backup:` se preservan antes de la extracción y se restauran después. Útil para archivos de configuración.

```nhoid
# Backup:	/etc/foo.conf /etc/foo.d/*
```

Los subpaquetes divididos usan su propio campo `# Backup_<parte>:` (ver la sección Paquetes divididos más arriba).

### Dependencias

Todos los campos de dependencias son opcionales. Los paquetes múltiples se separan con espacios. Operadores de versión: `>=`, `<=`, `!=`, `>`, `<`, `=`.

```nhoid
# BuildDep:	cmake ninja
# OptionalBuildDep:	gtk4>=4.10
# Dep(post):	libfoo
# OptionalDep(post):	bar<2.0
```

Las dependencias específicas de subpaquetes usan el sufijo `_<parte>`:

```nhoid
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
```

### Tipos de dependencia

| Campo | Cuándo se evalúa | Descripción |
|---|---|---|
| `# BuildDep:` | Antes de `nbuild()` | Dependencias de compilación requeridas |
| `# OptionalBuildDep:` | Antes de `nbuild()` | Dependencias de compilación opcionales |
| `# Dep(post):` | Antes de `ninstall()` | Dependencias de ejecución requeridas |
| `# OptionalDep(post):` | Antes de `ninstall()` | Dependencias de ejecución opcionales |

---

## Funciones

Las funciones definen código ejecutable. Deben ser bash válido.

### nbuild()

Comandos de compilación. Debe tener contenido real (no solo `noemptyfuncs`).

```bash
nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}
```

### ninstall()

Comandos de instalación. Debe tener contenido real.

Los archivos se instalan directamente en la raíz del sistema en vivo. Después, los archivos recién instalados se detectan escaneando `FIND_DIRS`.

```bash
ninstall() {
    ninja -C build install
}
```

### ninstall_\<parte\>()

Comandos de instalación para un subpaquete dividido.

```bash
ninstall_dev() {
    cp -r include/* /usr/include/
}
```

### npostinstall()

Comandos posteriores a la instalación (ldconfig, hardlinks, etc.). Puede ser `noemptyfuncs`.

```bash
npostinstall() {
    ldconfig
}
```

### npostinstall_\<parte\>()

Post-instalación para un subpaquete dividido.

### npostremove()

Comandos posteriores a la eliminación. Puede ser `noemptyfuncs`.

```bash
npostremove() {
    rm -f /etc/ld.so.cache
}
```

### npostremove_\<parte\>()

Post-eliminación para un subpaquete dividido.

### noemptyfuncs

Marcador de posición para funciones opcionales. Evita errores de bash cuando el cuerpo de una función está intencionadamente vacío.

```bash
npostinstall() {
    noemptyfuncs
}
```

---

## Ejemplos

### Paquete tarball simple

```nhoid
#%NHO-0.5
# Package Maintainer:	usuario <usuario@host>

# Name:	mktorrent
# Version:	1.1
# Release:	n2026
# License:	GPL-2.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://github.com/pobrn/mktorrent
# Description:	Utilidad de línea de comandos para crear archivos de metadatos BitTorrent.
# Packageurl:	https://github.com/pobrn/mktorrent/archive/v1.1/mktorrent-1.1.tar.gz
# SHA256:	d0f47500192605d01b5a2569c605e51ed319f557d24cfcbcb23a26d51d6138c9  mktorrent-1.1.tar.gz

nbuild() {
    make
}

ninstall() {
    make install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
```

### Fuente Git con paquetes divididos

```nhoid
#%NHO-0.5
# Package Maintainer:	cargabsj175 <cargabsj175@gmail.com>

# Name:	qt6
# Version:	6.10.2
# Release:	n2026
# License:	GPL-3.0-only LGPL-3.0-only
# Repository:	extra
# Arch:	i686 x86_64
# Url:	https://www.qt.io/
# Description:	Un framework multiplataforma de aplicaciones e interfaz de usuario.
# Description_xcb_private_headers:	Cabeceras privadas para Qt6 Xcb.
# Packageurl:	git+https://github.com/qt/qtbase
# Packageref:	v6.10.2
# Splitpackage:	xcb_private_headers

nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}

ninstall() {
    ninja -C build install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_xcb_private_headers() {
    cp -r include/* /usr/include/
}

npostinstall_xcb_private_headers() {
    noemptyfuncs
}

npostremove_xcb_private_headers() {
    noemptyfuncs
}
```
