[← Índice](README.md)

# 6\. Gestión de usuarios y servicios

**nhopkg** incluye dos funciones esenciales para la gestión de sistemas de producción:

  * `nhouser()`: crea o verifica usuarios y grupos del sistema de forma idempotente.
  * `install_init_unit()`: instala unidades de servicio para `systemd` o scripts de `sysvinit` desde fuentes externas (como BLFS).



Ambas funciones están diseñadas para integrarse en los scripts de post-instalación (`npostinstall()`) de los paquetes, siguiendo las convenciones de **Beyond Linux From Scratch (BLFS)**.

## 6.1. Gestión de usuarios y grupos

La gestión de usuarios y grupos está implementada en la librería **`libnhopkg_nhouser`** (instalada en `/usr/lib/nhopkg/libnhopkg_nhouser`), que proporciona la función `nhouser()` y soporta **dos backends**, detectados en tiempo de ejecución:

  * **GNU shadow-utils** (`useradd`/`groupadd`) — preferido en sistemas completos.
  * **BusyBox** (`adduser`/`addgroup`) — alternativa para entornos estáticos/embebidos.

La detección de backend no se limita a comprobar que los binarios existen: verifica que realmente *ejecutan* (protegiendo contra binarios dinámicos rotos tras una actualización de libc). La librería también busca UID/GID libres por debajo de 999 cuando el solicitado está ocupado o fuera de rango, y avisa ante desajustes de UID/GID.

### La herramienta de línea de comandos `nhouser`

`nhouser` también se instala como comando independiente (`/usr/bin/nhouser`). Es un envoltorio que carga `nhopkg.conf`, la librería base y `libnhopkg_nhouser`, y luego llama a `nhouser()` con los argumentos ya analizados. Así se puede usar tanto desde `npostinstall()` como de forma interactiva:

    nhouser --check|--create --user NOMBRE [opciones]
    nhouser --check|--create --group NOMBRE [--gid GID]

### Sintaxis de `nhouser()`

    nhouser --check|--create [opciones]

La función es idempotente: si el usuario o grupo ya existe, no se modifica nada (solo registra un aviso si hay desajuste de UID/GID).

### Opciones disponibles

Opción | Descripción  
---|---  
`--check`| Verifica si el usuario/grupo existe (no crea nada).  
`--create`| Crea el usuario/grupo si no existe.  
`--user <nombre>`| Nombre del usuario a crear.  
`--group <nombre>`| Nombre del grupo primario.  
`--uid <id>`| ID numérico del usuario (recomendado en BLFS).  
`--gid <id>`| ID numérico del grupo.  
`--uname <comentario>`| Campo de comentario GECOS del usuario.  
`--udir <ruta>`| Directorio home del usuario.  
`--shell <ruta>`| Shell asignado (ej. `/bin/false`, `/sbin/nologin`).  
`--groups <lista>`| Grupos secundarios (separados por comas).  
`--locked`| Bloquea la cuenta inmediatamente (`passwd -l`).  
`-v, --verbose`| Operaciones detalladas.  
  
### Ejemplos reales (BLFS)

Estos ejemplos replican exactamente lo que se hace en BLFS para paquetes comunes.

#### Ejemplo 1: Usuario para `cups`
    
    
    nhouser --create \
      --user lp \
      --group lp \
      --uid 9 \
      --gid 9 \
      --shell /sbin/nologin

#### Ejemplo 2: Usuario para `greetd`
    
    
    nhouser --create \
      --user greetd \
      --group greetd \
      --uid 51 \
      --gid 51 \
      --shell /sbin/nologin

#### Ejemplo 3: Usuario para `dhcpcd`
    
    
    nhouser --create \
      --user dhcp \
      --group dhcp \
      --uid 82 \
      --gid 82 \
      --shell /sbin/nologin

**Nota:** Los UID/GID utilizados aquí coinciden con los estándares de BLFS y LFS, garantizando compatibilidad con scripts y políticas de seguridad existentes. 

## 6.2. Gestión de servicios: `install_init_unit()`

Esta función instala unidades de servicio desde repositorios externos de BLFS, detectando automáticamente si el sistema usa `systemd` o `sysvinit`.

### Sintaxis
    
    
    install_init_unit install|remove <servicio>

### Variables requeridas

El sistema debe definir en su configuración global:

  * `INITSYSTEM`: `systemd` o `sysvinit`
  * `SYSTEMD_BLFS_URL` y `SYSTEMD_BLFS_DIR`
  * `SYSV_BLFS_URL` y `SYSV_BLFS_DIR`



### Ejemplos reales (BLFS)

#### Ejemplo 1: Instalar unidad de `slapd` (OpenLDAP)
    
    
    install_init_unit install slapd

Esto descargará e instalará la unidad desde el repositorio de BLFS para systemd o el script de sysvinit, según corresponda.

#### Ejemplo 2: Eliminar unidad de `cups`
    
    
    install_init_unit remove cups

#### Ejemplo 3: Integración en `npostinstall()`
    
    
    npostinstall() {
      # Crear usuario
      nhouser --create --user lp --group lp --uid 9 --gid 9 --shell /sbin/nologin
    
      # Instalar servicio
      install_init_unit install cups
    
      # Recargar systemd (si aplica)
      [ -x /usr/bin/systemctl ] && systemctl daemon-reload
    }

## 6.3. Configuración del sistema

Para que `install_init_unit()` funcione, el sistema define estas variables en `/etc/nhopkg/nhopkg.conf` (valores por defecto):
    
    
    INITSYSTEM="systemd"
    BLFS_DIR="${NHOPKG_LOCALSTATEDIR}/cache/blfs"
    SYSTEMD_BLFS_VER=20251204
    SYSTEMD_BLFS_DIR="${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}"
    SYSTEMD_BLFS_URL="https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz"
    SYSV_BLFS_VER=20251220
    SYSV_BLFS_DIR="${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}"
    SYSV_BLFS_URL="https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz"

Los archivos se descomprimen en `${BLFS_DIR}` (fuera de `FIND_DIRS`), por lo que nunca se capturan en el `data.tar.*` del paquete binario en construcción. Además, la copia extraída permanece intacta para posteriores compilaciones que usen `install_init_unit()`.

## Conclusión

Con `nhouser()` e `install_init_unit()`, **nhopkg** ofrece una solución madura y alineada con BLFS para gestionar aspectos críticos de los paquetes en entornos de producción, sin depender de herramientas externas complejas.
