[← Índice](README.md)

# 8\. Actualizaciones seguras

El comando `--upgrade` (o `-y`) de **nhopkg** permite actualizar todos los paquetes instalados a sus versiones más recientes disponibles en los repositorios configurados.

A diferencia de otros gestores, **nhopkg** implementa un flujo de actualización robusto, seguro y atómico en la medida de lo posible, minimizando el riesgo de corrupción parcial del sistema.

## Flujo de actualización

El proceso de actualización sigue estos pasos críticos:

  1. **Sincroniza los repositorios** locales con los servidores remotos (`--update` implícito).
  2. **Lista todos los paquetes instalados** en el sistema.
  3. **Compara las versiones instaladas** con las disponibles en los repositorios.
  4. **Identifica los paquetes que tienen actualizaciones** (versión nueva > versión instalada).
  5. **Muestra un plan de actualización** y solicita confirmación al usuario.
  6. **Resuelve y descarga todas las dependencias** necesarias (incluyendo las de los paquetes a actualizar).
  7. **Instala primero las dependencias** descargadas.
  8. **Para cada paquete a actualizar** : 
     * Elimina la versión antigua del sistema.
     * Instala la nueva versión.
  9. **Ejecuta tareas post-instalación** globales (`shooter_updates`).
  10. **Actualiza la base de datos local** (`updatedb`).



**Característica clave:** La versión antigua se elimina _antes_ de instalar la nueva. Esto evita conflictos de archivos y garantiza que el sistema siempre esté en un estado coherente, incluso si la instalación falla. 

## Resolución de dependencias

Durante la actualización, **nhopkg** realiza una resolución completa de dependencias en modo de solo lectura:

  * Analiza las dependencias de los paquetes a actualizar usando los metadatos del repositorio.
  * Descarga _todas_ las dependencias necesarias (tanto obligatorias como opcionales, si se aceptan) antes de comenzar cualquier instalación.
  * Instala las dependencias _antes_ que los paquetes principales.



Esto garantiza que no se produzcan errores por dependencias faltantes en mitad del proceso.

## Gestión de conflictos y reemplazos

Antes de instalar cualquier paquete actualizado, **nhopkg** verifica posibles conflictos usando los campos `# Conflicts:` y `# Provides:` del `nhoid`.

  * Si un paquete actualizado declara un conflicto con uno instalado, el proceso se aborta con un mensaje claro.
  * Si un paquete actualizado _reemplaza_ a otro (porque provee la misma interfaz), el paquete antiguo se desinstala automáticamente tras confirmación del usuario.



## Verificación de seguridad

Todas las verificaciones de seguridad configuradas se aplican durante la actualización:

  * **Checksum SHA256** : se valida la integridad de cada paquete descargado.
  * **Arquitectura** : se asegura que el paquete sea compatible con el sistema.
  * **Firma GPG** : si está habilitada, se verifica la autenticidad de cada paquete.



Si alguna verificación falla, la actualización se detiene inmediatamente.

## Comando y opciones
    
    
    # Actualizar todo el sistema
    sudo nhopkg --upgrade
    
    # O su alias corto
    sudo nhopkg -y

Este comando no acepta argumentos adicionales (como nombres de paquetes). Para actualizar paquetes específicos, se debe usar `--super-install` en su lugar.

## Ejemplo de salida
    
    
    $ sudo nhopkg --upgrade
     - Updating repository databases...
     :: Updating repository: extra (https://neonatox.vegnux.com/repo/n27/x86_64/extra)
       - Downloading database...
     - All repositories updated successfully.
     - Checking for available updates...
     - Updates are available for the following packages:
       gimp: 3.0.2-n2024 -> 3.0.4-n2025
       firefox: 120.0-n2024 -> 121.0-n2025
    
    Do you want to continue?[yes/NO]: yes
     - Downloading upgrade packages...
     --- Downloading gimp-3.0.4-n2025.linux-x86_64.nho
     --- Downloading firefox-121.0-n2025.linux-x86_64.nho
     - Installing dependencies...
     - Installing upgraded packages...
     --- Removing gimp-3.0.2-n2024
     --- Installing gimp-3.0.4-n2025
     --- Removing firefox-120.0-n2024
     --- Installing firefox-121.0-n2025
     - System updates completed
     - System updated successfully!

## Consideraciones importantes

  * El comando `--upgrade` solo considera paquetes que están en los repositorios activos (`NHOPKG_ACTIVE_REPOS`).
  * No actualiza paquetes instalados desde fuentes locales (`.nho` o `.srcnho`) a menos que también existan en un repositorio.
  * El proceso es interactivo por defecto. Para uso automatizado, se puede combinar con `--recursive` para asumir "sí" a todas las preguntas.


