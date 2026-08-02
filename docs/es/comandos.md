# Comandos principales — nhopkg v0.5.1

nhopkg es un gestor universal de paquetes binarios y fuente. Esta página documenta todos los comandos y opciones aceptados por el binario `nhopkg`. Las tareas administrativas (compilación de paquetes, gestión de repositorios, creación de usuarios) las realizan las herramientas complementarias referenciadas al final.

## Referencia de comandos

| Corto | Largo | Descripción |
|-------|-------|-------------|
| `-i` | `--install` | Instala un paquete binario `.nho` local |
| `-S` | `--super-install` | Instala un paquete desde un repositorio remoto |
| `-d` | `--dios` | Igual que `-S` / `--super-install` |
| `-b` | `--build` | Compila e instala un paquete fuente `.srcnho` |
| `-C` | `--super-build` | Clona un repositorio Git y compila/instala desde su receta `nhoid` |
| `-r` | `--remove` | Elimina un paquete instalado |
| | `--purge` | Elimina un paquete más todas sus dependencias inversas |
| `-B` | `--backup` | Recrea un paquete binario `.nho` a partir de un paquete ya instalado |
| `-l` | `--list` | Lista todos los paquetes instalados por nhopkg |
| `-n` | `--info` | Muestra información detallada de un paquete (instalado, en el repositorio o `.nho` local) |
| `-w` | `--show` | Lista todos los archivos pertenecientes a un paquete instalado |
| `-s` | `--search` | Busca paquetes en los metadatos del repositorio local |
| `-t` | `--list-repo` | Lista todos los paquetes disponibles en los repositorios configurados |
| `-k` | `--check` | Verifica la integridad de un paquete instalado (comprueba que cada archivo listado exista) |
| `-y` | `--upgrade` | Actualiza todos los paquetes instalados a la versión más reciente disponible en los repositorios |
| `-U` | `--update` | Sincroniza todas las bases de datos de repositorios configuradas (`core.packages.tar.zst`, `core.files.tar.zst`, `lastsync`) |
| `-u` | `--update-db` | Reconstruye la base de datos local de ubicación de archivos (`updatedb` / `plocate`) |
| `-x` | `--update-shooters` | Actualiza las cachés del sistema: esquemas GLib, caché de iconos, base de datos de escritorio, base de datos MIME, páginas man, caché de fuentes, caché de bibliotecas compartidas y cargadores GDK pixbuf |
| `-e` | `--clean` | Elimina los paquetes `.nho` en caché del directorio de descarga; con `-R` también limpia el directorio de compilación |
| `-G` | `--install-group` | Instala todos los paquetes pertenecientes a un grupo con nombre (p. ej. `base`, `libs`, `xorg`) en todos los repositorios activos |
| `-X` | `--strip-binaries` | Elimina los símbolos de depuración de binarios ELF y objetos compartidos durante `--build` (experimental) |

## Opciones (flags)

| Largo | Descripción |
|-------|-------------|
| `-v`, `--verbose` | Habilita la salida detallada |
| `-p`, `--preserve-files` | Fuerza la retención de los archivos del paquete al eliminarlo |
| `-R`, `--recursive` | Responde "sí" a todos los avisos (modo no interactivo) |
| `-o`, `--output DIR` | Escribe la salida del comando (list, info, show) en un archivo de registro en DIR |
| `--root DIR` | Opera en un directorio raíz alternativo (para bootstrap, chroot o contenedores); el estado, los repositorios y las dependencias se resuelven dentro del destino, y los ganchos posteriores a la instalación / actualizaciones de caché se ejecutan allí mediante chroot |
| `--no-check-deps` | Omite la resolución de dependencias |
| `--force-check-deps` | Fuerza la resolución de dependencias aunque esté deshabilitada en la configuración |
| `--no-check-arch` | Omite la validación de arquitectura |
| `--force-check-arch` | Fuerza la validación de arquitectura aunque esté deshabilitada en la configuración |
| `--no-check-sha256` | Omite la verificación de la suma de verificación SHA-256 |
| `--force-check-sha256` | Fuerza la verificación de la suma de verificación aunque esté deshabilitada en la configuración |
| `--sign-package` | Firma el paquete binario con GPG durante `--build` |
| `--no-sign-package` | Omite la firma GPG |
| `--verify-package-signature` | Verifica la firma GPG de un paquete antes de instalarlo |
| `--no-verify-package-signature` | Omite la verificación de firma |
| `--license` | Muestra un aviso breve de licencia |
| `--license-all` | Muestra el texto completo de la licencia GPL |
| `--version` | Muestra la versión de nhopkg y los derechos de autor |
| `--help` | Muestra la página de ayuda integrada |
| `--` | Detiene el análisis de argumentos (todo lo que sigue se trata como nombre de paquete) |

> **Nota:** Las opciones `--no-check-sums` y `--force-check-sums` son alias de `--no-check-sha256` y `--force-check-sha256` respectivamente.

## Ejemplos

```bash
# Instalar un paquete .nho local
sudo nhopkg -i gimp-3.0.4-n20260523.linux-x86_64.nho

# Instalar desde el repositorio (con resolución de dependencias)
sudo nhopkg -S gimp

# Igual que lo anterior
sudo nhopkg --super-install gimp
sudo nhopkg -d gimp

# Compilar a partir de una receta fuente
sudo nhopkg -b foo.srcnho

# Compilar directamente desde un repositorio Git
sudo nhopkg -C foo

# Eliminar un paquete
sudo nhopkg -r gimp

# Eliminar un paquete y todo lo que depende de él
sudo nhopkg --purge gimp

# Actualizar los metadatos del repositorio
sudo nhopkg -U

# Actualizar todos los paquetes instalados
sudo nhopkg -y

# Listar paquetes instalados
nhopkg -l

# Mostrar información detallada (busca repositorios, instalados o .nho local)
nhopkg -n gimp

# Mostrar archivos pertenecientes a un paquete
nhopkg -w gimp

# Buscar paquetes que coincidan con un patrón
nhopkg -s gimp

# Verificar la integridad de un paquete instalado
sudo nhopkg -k gimp

# Limpiar la caché de descarga
sudo nhopkg -e

# Limpiar caché y directorio de compilación
sudo nhopkg -e -R

# Instalar con raíz alternativa (p. ej. para un chroot)
sudo nhopkg -i foo.nho --root /mnt/chroot

# Activar la salida detallada
nhopkg -v -n gimp

# Escribir la salida de la lista en un archivo
nhopkg -l -o /tmp

# Instalar todos los paquetes del grupo "base"
sudo nhopkg -G base

# Eliminar símbolos de depuración durante la compilación
sudo nhopkg -X -b foo.srcnho

# Eliminar un paquete conservando sus archivos
sudo nhopkg -r gimp -p
```

## Modo raíz (`--root`)

`--root DIR` instala, actualiza o elimina paquetes en un **directorio raíz alternativo** en lugar del sistema en vivo. Útil para el bootstrap de un sistema nuevo, chroots o contenedores. El directorio de destino ya debe existir.

- El estado del paquete (`/var/nhopkg/packages`, `files`, `repo`, `cache`) vive **dentro del destino** (`DIR/var/nhopkg`).
- La sincronización de repositorios (`--update`), la resolución de dependencias y las comprobaciones de conflictos operan contra la raíz de destino, no contra el host.
- Los archivos se extraen dentro de `DIR`.
- Los ganchos `npostinstall()` y las actualizaciones de caché (`shooter_updates`: esquemas GLib, cachés de iconos/MIME/escritorio, fuentes, `ldconfig`) **no** se ejecutan en el host: se ejecutan **dentro del destino** mediante un chroot en un namespace de montaje privado que monta `/dev`, `/proc`, `/sys` y `/run` del host. Esto requiere `/bin/sh` dentro del destino.
- Si nhopkg aún no está instalado dentro del destino, las actualizaciones de caché se omiten con una advertencia; ejecuta `nhopkg -x` una vez dentro del destino.
- Los archivos `# Backup:` se leen y se restauran dentro de la raíz de destino.
- No interactivo: los avisos se omiten durante las instalaciones desde repositorio.

```bash
# Instalar en un destino chroot
sudo nhopkg -i foo.nho --root /mnt/chroot

# Instalar desde un repositorio dentro del destino (con resolución de dependencias)
sudo nhopkg -S foo --root /mnt/chroot

# Actualizar todo dentro del destino
sudo nhopkg -y --root /mnt/chroot
```

> **Nota:** `--root` no es un envoltorio completo de `chroot`. Debe ejecutarse como root, y el destino ya debe contener los paquetes esenciales (p. ej. glibc, bash, nhopkg) antes de poder ejecutar ganchos dentro de él.

## Herramientas complementarias

| Herramienta | Propósito | Referencia |
|-------------|-----------|------------|
| `nhoget` | Herramienta de descarga unificada (HTTP/HTTPS + VCS) para compilaciones y CLI | [`docs/es/nhoget.md`](nhoget.md) |
| `nhopkg-src` | Asistente de creación de paquetes fuente | [`docs/es/nhopkg-src.md`](nhopkg-src.md) |
| `nhopkg-repos` | Creación y mantenimiento de repositorios (`--create-repo`, `--add-to-repo`) | [`docs/es/repositorios.md`](repositorios.md) |
| `nhouser` | Creación idempotente de usuarios/grupos del sistema (usado en `npostinstall()`) | [`docs/es/usuarios-servicios.md`](usuarios-servicios.md) |
| `nhopkg-overlay` | Entorno de compilación aislado mediante overlay | [`docs/es/nhopkg-overlay.md`](nhopkg-overlay.md) |

## Véase también

- [Referencia de configuración](configuracion.md)
- [Formato de paquete (nhoid)](formato-nhoid.md)
- [Grupos de paquetes](grupos.md)
- [Visión general de la arquitectura](arquitectura.md)
