[← Índice](README.md)

# 9\. Construcción de paquetes

**nhopkg** permite construir paquetes binarios (`.nho`) a partir de recetas de compilación definidas en paquetes fuente (`.srcnho`) o directamente desde repositorios de control de versiones.

Este proceso es fundamental para distribuciones personalizadas, ya que garantiza reproducibilidad, control total sobre las dependencias y la posibilidad de generar paquetes optimizados para el sistema objetivo.

## Flujo general de construcción

  1. **Preparación del entorno** : descarga o descompresión del código fuente.
  2. **Resolución de dependencias** : verificación e instalación de dependencias de compilación y ejecución.
  3. **Compilación** : ejecución de la función `nbuild()` (solo en el paquete principal).
  4. **Instalación en staging** : ejecución de `ninstall()` (principal) o `ninstall_<part>()` (subpaquetes).
  5. **Detección de archivos instalados** : escaneo de los directorios del sistema.
  6. **Generación del paquete binario** : compresión de los archivos y metadatos en un archivo `.nho`.
  7. **Opcional: firma GPG** del paquete (si está habilitado).



## Comandos de construcción

Comando | Descripción  
---|---  
`--build` o `-b` | Construye e instala un paquete a partir de un archivo `.srcnho` local.  
`--super-build` o `-C` | Clona un repositorio de control de versiones (Git, Subversion o Mercurial), construye e instala un paquete directamente desde fuentes remotas.  
  
## Fuentes de código

El código fuente puede provenir de dos fuentes distintas, según lo definido en el `nhoid`:

### 1\. Repositorios de control de versiones (VCS)

El campo `# Packageurl:` selecciona el sistema de control de versiones mediante un prefijo de esquema: `git+` (Git), `svn+` (Subversion) o `hg+` (Mercurial). Una URL que termine en `.git` también se trata como Git. nhopkg clonará el repositorio y, opcionalmente, cambiará a una referencia específica usando `# Packageref:` (tag, rama o commit para git; revisión para svn y hg).
    
    
    # Packageurl:	git+https://gitlab.gnome.org/GNOME/gimp.git
    # Packageref:	GIMP_3_0_4
    
    # Packageurl:	svn+https://svn.example.com/project
    # Packageref:	r42

### 2\. Tarball (local o remoto)

Si `# Packageurl:` apunta a un archivo comprimido (ej. `.tar.xz`), nhopkg lo descargará y descomprimirá. Si el tarball está incluido dentro del `.srcnho`, se usará directamente.
    
    
    # Packageurl:	https://download.gimp.org/gimp-3.0.4.tar.xz

**Importante:** Para tarballs (locales o remotos), el campo `# SHA256:` es obligatorio y debe corresponder al hash del archivo fuente. 

## Funciones de compilación e instalación

El archivo `nhoid` debe contener al menos dos funciones Bash:

  * `nbuild()`: compila el software (ej. con `meson`, `cmake`, `make`). Solo se ejecuta una vez, para el paquete principal.
  * `ninstall()`: instala los archivos directamente en el sistema real; los archivos nuevos se detectan después escaneando `FIND_DIRS`.



Ejemplo:
    
    
    nbuild() {
      meson setup build --prefix=/usr
      ninja -C build
    }
    
    ninstall() {
      ninja -C build install
    }

## Subpaquetes (_Split Packages_)

nhopkg soporta la generación automática de múltiples paquetes a partir de una sola receta usando el campo `# Splitpackage:`.
    
    
    # Splitpackage:	dev docs

Esto generará tres paquetes:

  * `gimp-3.0.4-n2025.linux-x86_64.nho` (principal)
  * `gimp-dev-3.0.4-n2025.linux-x86_64.nho`
  * `gimp-docs-3.0.4-n2025.linux-x86_64.nho`



**Comportamiento clave de los subpaquetes:**

  * Los subpaquetes **no tienen su propia función`nbuild()`**.
  * Toda la lógica de compilación e instalación para un subpaquete debe ir dentro de su función `ninstall_<part>()`.
  * Esto significa que, si un subpaquete requiere comandos de compilación adicionales, deben ejecutarse dentro de `ninstall_dev()`, `ninstall_docs()`, etc.



Ejemplo para un subpaquete `dev`:
    
    
    ninstall_dev() {
      # No hay nbuild_dev(), todo va aquí
      mkdir -p /usr/include
      cp -r include/* /usr/include/
      # Incluso podrías compilar algo específico aquí si fuera necesario
    }

## Post-instalación y post-eliminación

Además de `nbuild()` y `ninstall()`, se pueden definir funciones opcionales:

  * `npostinstall()`: se ejecuta tras instalar el paquete (ej. actualizar cachés).
  * `npostremove()`: se ejecuta tras desinstalarlo (ej. limpiar cachés).



Estas funciones también admiten variantes por subpaquete: `npostinstall_dev()`, `npostremove_docs()`, etc.

## Directorios clave

  * `/usr/src/nhopkg/`: directorio de compilación (`NHOPKG_BUILDIR`).
  * `/var/nhopkg/logs/`: almacena logs de compilación e instalación.
  * `/tmp/.nhopkg.XXXXXXXXXX/`: directorio temporal seguro para cada operación.



## Ejemplos de uso
    
    
    # Construir desde un .srcnho local
    sudo nhopkg --build gimp-3.0.4.srcnho
    
    # Construir directamente desde un repositorio de control de versiones
    sudo nhopkg --super-build gimp
    
    # Construir en modo verboso
    sudo nhopkg --verbose --build gimp-3.0.4.srcnho

## Verificación y seguridad

  * Se verifica la arquitectura del sistema antes de compilar.
  * Se resuelven y descargan todas las dependencias antes de comenzar.
  * Si está habilitado, el paquete resultante se firma con GPG.
  * Los logs de compilación e instalación se guardan para auditoría.



## Consideraciones importantes

  * La construcción requiere privilegios de root.
  * El directorio de compilación no se elimina automáticamente; se pregunta al usuario.
  * Los archivos generados en tiempo de ejecución (como `/etc/ld.so.cache`) se excluyen del paquete final.
  * El tamaño del paquete se calcula automáticamente en KB.


