[← Índice](README.md)

# Resolución de dependencias — nhopkg v1.0

El Sistema Unificado de Resolución de Dependencias (UDEPSYS) es el módulo responsable de resolver, descargar e instalar las dependencias de los paquetes. Está implementado en la librería **`libnhopkg_udepsys`** (instalada como `/usr/lib/nhopkg/libnhopkg_udepsys`) y es cargada por el binario principal `nhopkg`. Expone los puntos de entrada públicos `dep_resolve_from_nhoid()`, `dep_install_queue()` y `dep_check_conflicts()`, además de las funciones auxiliares `version_compare()` (comparación de versiones mediante `sort -V`) y `get_repo_url()` (construcción de URL de repositorio). Las descargas de paquetes se delegan en el backend de descarga unificado `nhoget_url` de [`libnhopkg_download`](nhoget.md).

Para conocer la sintaxis completa de los campos nhoid (incluyendo los campos de dependencias específicas para subpaquetes), consulte [formato-nhoid.md](formato-nhoid.md).

---

## Tipos de dependencias

Se soportan cuatro tipos de dependencias, cada una evaluada en una etapa diferente:

| Tipo | Clave interna | Cuándo se evalúa | Comportamiento ante fallo |
|---|---|---|---|
| `# BuildDep:` | `build` | Antes de `nbuild()` | Error fatal si falta |
| `# OptionalBuildDep:` | `optional_build` | Antes de `nbuild()` | Solo advertencia |
| `# Dep(post):` | `required` | Antes de `ninstall()` | Error fatal si falta |
| `# OptionalDep(post):` | `optional` | Antes de `ninstall()` | Solo advertencia |

Los fallos fatales (`required` y `build`) hacen que la instalación o compilación se interrumpa con un error. Los tipos opcionales (`optional` y `optional_build`) emiten una advertencia y continúan.

---

## Operadores de versión

Cada especificación de dependencia puede incluir una restricción de versión usando uno de los siguientes operadores:

| Operador | Significado |
|---|---|
| `=` | Igual |
| `!=` | No igual |
| `<` | Menor que |
| `<=` | Menor o igual |
| `>` | Mayor que |
| `>=` | Mayor o igual |

La comparación la realiza `version_compare()` que delega en `sort -V` (ordenación natural de versiones). La función compara la versión del paquete instalado o del repositorio contra la restricción y devuelve éxito si la restricción se cumple.

Ejemplos:

```
foo>=2.0
bar<1.5
baz!=3.0
qux=1.0
quux>4.0
```

Una especificación sin operador coincide con cualquier versión.

---

## Orden de resolución

Al resolver una dependencia individual, UDEPSYS busca en el siguiente orden. La primera coincidencia gana.

**NIVEL 1 — Paquetes instalados (nombre exacto)**
Escanea `${ROOT_PKG_STATE_DIR}/packages/` en busca de un archivo cuyo `# Name:` interno coincida con el nombre de la dependencia. Las restricciones de versión se verifican contra la versión instalada.

**NIVEL 2 — Paquetes instalados (Provides)**
Si no se encuentra una coincidencia exacta, se verifica cada paquete instalado en busca de un campo `# Provides:` que coincida con el nombre de la dependencia (con versión opcional).

**NIVEL 3 — Paquetes del repositorio (nombre exacto)**
Itera sobre cada repositorio activo (de `$NHOPKG_ACTIVE_REPOS`). Para cada repositorio, primero busca un archivo con el nombre exacto de la dependencia, luego archivos cuyo `# Name:` interno coincida. Las restricciones de versión se verifican.

**NIVEL 4 — Paquetes del repositorio (Provides)**
Si no se encuentra una coincidencia exacta en ningún repositorio, se llama a `resolve_virtual_package()` para buscar en todos los repositorios una línea `# Provides:` que coincida con el nombre de la dependencia.

### Caché

Los resultados se almacenan en caché en el array asociativo `DEP_RESOLVED_CACHE` (indexado por la cadena de especificación de dependencia). Si la misma especificación se solicita nuevamente dentro de la misma sesión, el resultado en caché se devuelve inmediatamente sin escanear el repositorio. El nombre del repositorio se almacena por separado en `DEP_REPO_CACHE`.

---

## Provides y Conflicts

### Provides

Un paquete puede declarar que **proporciona** un paquete virtual añadiendo un campo `# Provides:` en su nhoid:

```
# Provides:	sdl2
```

Múltiples paquetes virtuales están separados por espacios. Los provides con versión se expresan con `=`:

```
# Provides:	libfoo=2.0
```

Cuando una dependencia no es satisfecha por ningún nombre de paquete real, el resolvedor verifica si algún paquete (instalado o en repositorios) *proporciona* el nombre solicitado (NIVEL 2 y NIVEL 4 anteriores).

### Conflicts

Un paquete puede declarar que **entra en conflicto** con otro paquete:

```
# Conflicts:	sdl2
```

`dep_check_conflicts()` verifica que ningún paquete instalado (o proveedor del nombre conflictivo) coincida con la restricción. Si se encuentra un conflicto, la operación se aborta con un error.

### Reemplazo (autoconflicto)

Existe un caso especial cuando un paquete **entra en conflicto con algo que también proporciona**. Esto señala un *reemplazo* — el nuevo paquete está destinado a tomar el lugar del anterior:

```
# Provides:	sdl2
# Conflicts:	sdl2
```

En este caso, el resolvedor establece `DEP_REPLACE_PACKAGE` al nombre del paquete anterior, y la rutina de instalación (`_dep_install_single()`) elimina el paquete anterior antes de instalar el nuevo.

Las restricciones de versión funcionan tanto con Provides como con Conflicts:

```
# Provides:	libfoo>=2.0
# Conflicts:	libfoo<2.0
```

---

## Dependencias específicas de subpaquetes

Cuando un paquete define subpaquetes separados (`# Splitpackage: dev lib docs`), cada parte puede tener sus propios campos de dependencia usando el sufijo `_<parte>`:

```
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
# BuildDep_lib32:	cmake
```

El sufijo coincide con el nombre de la parte declarada en `# Splitpackage:`. El sufijo se añade a cualquiera de los cuatro tipos de dependencia:

| Campo | Significado |
|---|---|
| `# Dep_dev(post):` | Dependencia de ejecución requerida para el subpaquete `dev` |
| `# OptionalDep_lib(post):` | Dependencia de ejecución opcional para el subpaquete `lib` |
| `# BuildDep_lib32:` | Dependencia de compilación requerida para el subpaquete `lib32` |
| `# OptionalBuildDep_docs:` | Dependencia de compilación opcional para el subpaquete `docs` |

El mismo mecanismo de sufijo se aplica a `# Provides:` y `# Conflicts:`:

```
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
```

---

## Flujo de resolución

El pipeline de resolución consta de tres funciones públicas llamadas secuencialmente:

### 1. `dep_resolve_from_nhoid()`

Lee un archivo nhoid y resuelve todas las dependencias de un tipo dado (`required`, `optional`, `build` u `optional_build`). Para cada especificación de dependencia encontrada en el campo correspondiente, se llama a `_dep_resolve_single()`.

- Si una dependencia requerida/de compilación no se puede resolver, la función llama a `exit 1` inmediatamente.
- Si una dependencia opcional/de compilación opcional no se puede resolver, se imprime una advertencia y la resolución continúa.
- Si la resolución recursiva está habilitada (por defecto), se invoca `_dep_resolve_children()` en cada paquete de repositorio recién encontrado, resolviendo sus propias dependencias del mismo tipo.

Los paquetes encontrados en repositorios se añaden a `RCASEPACKAGES` (requeridos/de compilación) u `ORCASEPACKAGES` (opcionales/de compilación opcional).

### 2. `dep_install_queue()`

Instala todos los paquetes acumulados en las colas de resolución.:

1. Muestra la lista de paquetes al usuario y solicita confirmación (a menos que `ask_user=no`).
2. Llama a `_dep_download_all()` que descarga cada paquete desde su repositorio mediante `nhoget_url` (el backend de descarga unificado: GNU wget, curl o BusyBox wget).
3. Llama a `_dep_install_all_from_queue()` (definida en `nhopkg.in`) que instala cada paquete descargado mediante `_dep_install_single()`.

`_dep_install_single()` maneja la verificación de conflictos (mediante `dep_check_conflicts`), actualizaciones, reemplazos, verificación de hash, checksum de arquitectura, verificación de firmas y la instalación real de archivos.

### 3. `dep_check_conflicts()`

Valida las declaraciones `# Conflicts:` de un paquete contra el conjunto de paquetes instalados. Para cada especificación de conflicto:

1. Verifica si el paquete conflictivo está instalado por nombre exacto.
2. Verifica si algún paquete instalado *proporciona* el nombre conflictivo.
3. Si se encuentra un conflicto y el paquete también *proporciona* el nombre conflictivo, se trata como un *reemplazo* (ver arriba) en lugar de un error.
4. Devuelve un valor distinto de cero si se detecta un conflicto irresoluble, lo que hace que el llamador aborte la operación.
