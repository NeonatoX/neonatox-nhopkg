[← Índice](README.md)

# 11\. Repositorios múltiples

**nhopkg** soporta un sistema de **repositorios múltiples** , lo que permite organizar paquetes en categorías lógicas (por ejemplo, `extra`, `multilib`, `core`) y gestionarlos de forma independiente.

## Configuración de repositorios activos

La variable `NHOPKG_ACTIVE_REPOS` en `/etc/nhopkg/nhopkg.conf` define qué repositorios están habilitados:
    
    
    NHOPKG_ACTIVE_REPOS="extra multilib"

Esta lista determina qué repositorios se sincronizan con `--update` y desde dónde se instalan paquetes con `--super-install`.

## Definición de URLs por repositorio

Cada repositorio activo debe tener una variable correspondiente que defina su URL (o URLs de mirrors):

Repositorio | Variable de configuración | Ejemplo  
---|---|---  
`extra` | `NHOPKG_REPO_EXTRA` | `https://neonatox.vegnux.com/repo/n2026/x86_64/extra`  
`multilib` | `NHOPKG_REPO_MULTILIB` | `https://neonatox.vegnux.com/repo/n2026/x86_64/multilib`  
`core` | `NHOPKG_REPO_CORE` | `https://mirror1.example.com/core https://mirror2.example.com/core`  
  
Cada variable puede contener **múltiples URLs separadas por espacios** , lo que permite definir mirrors redundantes.

## Asignación de paquetes a repositorios

Los paquetes se asignan a un repositorio mediante el campo `# Repository:` en su archivo `nhoid`:
    
    
    # Repository:	extra

Si este campo no está presente, **nhopkg** asume por defecto `extra` (compatibilidad hacia atrás).

**Importante:** Durante la instalación o actualización, nhopkg solo buscará un paquete en los repositorios listados en `NHOPKG_ACTIVE_REPOS`. Si un paquete pertenece a un repositorio no activo, será ignorado. 

## Sincronización de repositorios (`--update`)

El comando `--update` sincroniza **todos los repositorios activos** en paralelo:

  1. Para cada repositorio en `NHOPKG_ACTIVE_REPOS`, nhopkg descarga: 
     * `core.packages.tar.zst`: metadatos de los paquetes.
     * `core.files.tar.zst`: listas de archivos por paquete.
     * `lastsync`: marca de tiempo de la última sincronización.
  2. Los archivos se almacenan en subdirectorios separados: 
     * `/var/nhopkg/repo/extra/`
     * `/var/nhopkg/repo/multilib/`



Esto evita conflictos entre repositorios y permite una resolución de dependencias precisa.

## Creación de repositorios (`nhopkg-repos -A`)

Los repositorios se crean y mantienen con la herramienta complementaria `nhopkg-repos`. El comando `-A, --add-to-repo` es especialmente potente en entornos multi-repositorio:

  1. Analiza todos los archivos `.nho` en un directorio de entrada.
  2. Extrae el campo `# Repository:` de cada `nhoid`.
  3. Clasifica los paquetes en subdirectorios según su repositorio destino.
  4. Genera metadatos (`core.packages.tar.zst`, `core.files.tar.zst`, `lastsync`) **por repositorio**.
  5. Copia los archivos `.nho` a sus respectivos subdirectorios.



Por ejemplo, si ejecutas:
    
    
    sudo nhopkg-repos -A /path/to/packages/*.nho --repo-dir /path/to/packages

y tus paquetes tienen `# Repository: extra` y `# Repository: multilib`, obtendrás:
    
    
    /path/to/packages/
    ├── extra/
    │   ├── core.packages.tar.zst
    │   ├── core.files.tar.zst
    │   ├── lastsync
    │   └── *.nho
    └── multilib/
        ├── core.packages.tar.zst
        ├── core.files.tar.zst
        ├── lastsync
        └── *.nho

## Resolución de paquetes

Al instalar un paquete con `--super-install`, nhopkg:

  1. Busca el paquete en **todos los repositorios activos**.
  2. Si lo encuentra en varios, usa el primero (el orden depende del sistema de archivos).
  3. Descarga e instala el paquete desde el repositorio correcto.



Esto garantiza que siempre se use la versión más adecuada para el repositorio configurado.

## Ventajas del sistema multi-repositorio

  * **Organización clara** : separación lógica de paquetes (base, gráficos, multilib, etc.).
  * **Control de versiones** : cada repositorio puede tener su propio ciclo de vida.
  * **Seguridad** : repositorios críticos (como `core`) pueden mantenerse separados y firmados de forma independiente.
  * **Escalabilidad** : fácil de extender a nuevos repositorios sin modificar el núcleo de nhopkg.



## Ejemplo de flujo de trabajo
    
    
    # 1. Configurar repositorios
    echo 'NHOPKG_ACTIVE_REPOS="extra multilib"' >> /etc/nhopkg/nhopkg.conf
    echo 'NHOPKG_REPO_EXTRA=https://mi-repo.com/extra' >> /etc/nhopkg/nhopkg.conf
    echo 'NHOPKG_REPO_MULTILIB=https://mi-repo.com/multilib' >> /etc/nhopkg/nhopkg.conf
    
    # 2. Sincronizar
    sudo nhopkg --update
    
    # 3. Instalar un paquete del repositorio 'extra'
    sudo nhopkg --super-install gimp
    
    # 4. Instalar un paquete del repositorio 'multilib'
    sudo nhopkg --super-install lib32-glibc
