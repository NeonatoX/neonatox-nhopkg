[← Índice](README.md)

# 10\. Mantenimiento del sistema

**nhopkg** incluye una serie de comandos y funciones diseñadas para mantener el sistema limpio, coherente y actualizado. Estas herramientas son esenciales para la administración diaria de una distribución basada en nhopkg.

## 10.1. Actualización de cachés del sistema (`--update-shooters`)

El comando `--update-shooters` (o `-x`) ejecuta una serie de tareas post-instalación globales que aseguran que el sistema esté en un estado coherente tras instalar o actualizar paquetes.

Estas tareas son implementadas en la función `shooter_updates()` y se ejecutan automáticamente al final de una operación de instalación o actualización, pero también pueden invocarse manualmente.

### Tareas ejecutadas

  * **Esquemas GSettings** : `glib-compile-schemas /usr/share/glib-2.0/schemas`
  * **Caché de iconos** : `gtk-update-icon-cache` para todos los temas de iconos.
  * **Base de datos de aplicaciones** : `update-desktop-database`.
  * **Tipos MIME** : `update-mime-database /usr/share/mime`.
  * **Páginas de manual** : `mandb` o `makewhatis`.
  * **Caché de fuentes** : `fc-cache -f`.
  * **Caché de bibliotecas compartidas** : `ldconfig`.


    
    
    # Ejecutar manualmente las actualizaciones de caché
    sudo nhopkg --update-shooters

## 10.2. Gestión de la base de datos local (`--update-db`)

La base de datos local, usada por `locate` (o `mlocate`), permite a nhopkg resolver dependencias basadas en archivos (por ejemplo, si un paquete requiere `/usr/bin/python3`).

El comando `--update-db` (o `-u`) actualiza esta base de datos, excluyendo directorios definidos en la variable `NO_DIRS_IN_DB` del archivo de configuración.
    
    
    # Actualizar la base de datos local
    sudo nhopkg --update-db

## 10.3. Limpieza de caché (`--clean`)

Con el tiempo, nhopkg acumula archivos en su caché:

  * Paquetes descargados (`/var/nhopkg/cache/`).
  * Directorios de compilación (`/usr/src/nhopkg/`).



El comando `--clean` (o `-e`) elimina estos archivos temporales.

Comando | Efecto  
---|---  
`nhopkg --clean` | Elimina solo los paquetes descargados de la caché.  
`nhopkg --clean -R` | Elimina la caché de paquetes **y** el directorio de compilación (`/usr/src/nhopkg/`).  
      
    
    # Limpiar caché de paquetes
    sudo nhopkg --clean
    
    # Limpiar caché y directorio de compilación
    sudo nhopkg --clean -R

## 10.4. Verificación de integridad (`--check`)

El comando `--check` (o `-k`) verifica la integridad de un paquete instalado. Compara la lista de archivos registrada en `/var/nhopkg/files/<paquete>-<versión>-<release>.zst` con el sistema de archivos real.

Si un archivo está faltante, el comando lo reportará con el porcentaje de archivos presentes.
    
    
    # Verificar la integridad del paquete 'gimp'
    nhopkg --check gimp

## 10.5. Listado e inspección de paquetes

nhopkg ofrece varias formas de inspeccionar el estado del sistema:

Comando | Descripción  
---|---  
`--list` o `-l` | Lista todos los paquetes instalados.  
`--info` o `-n` | Muestra metadatos detallados de un paquete (instalado, en repositorio o en archivo local).  
`--show` o `-w` | Muestra la lista de archivos contenidos en un paquete.  
`--list-repo` o `-t` | Lista todos los paquetes disponibles en los repositorios locales sincronizados.  
`--search` o `-s` | Busca paquetes en los repositorios por nombre o descripción.  
  
## 10.6. Reconstrucción de paquetes (`--backup`)

El comando `--backup` (o `-B`) es una herramienta poderosa para la recuperación y migración. Reconstruye un paquete binario (`.nho`) a partir de un paquete ya instalado en el sistema.

Esto es útil para: 

  * Crear copias de seguridad de paquetes personalizados.
  * Migrar paquetes entre sistemas.
  * Recrear un paquete si se pierde el original.


    
    
    # Reconstruir el paquete 'gimp' instalado
    sudo nhopkg --backup gimp

**Nota:** El paquete reconstruido contendrá todos los archivos tal como están en el sistema, incluyendo cualquier modificación manual. No se incluyen las funciones de post-instalación originales. 

## Conclusión

Con este conjunto de herramientas, **nhopkg** no solo gestiona paquetes, sino que también proporciona un entorno completo para el mantenimiento proactivo y reactivo de un sistema Linux, asegurando su estabilidad y rendimiento a largo plazo.
