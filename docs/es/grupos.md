[← Índice](README.md)

# 7\. Grupos de paquetes

**nhopkg** permite organizar paquetes en **grupos lógicos** mediante el campo `# Group:` en el archivo `nhoid`. Esto facilita la instalación masiva de conjuntos de software relacionados (por ejemplo, un entorno de escritorio, un servidor o un conjunto de herramientas de desarrollo).

## Definición de grupos

Para asignar un paquete a un grupo, se debe incluir una línea en su `nhoid` con el siguiente formato:
    
    
    # Group:	<nombre-del-grupo>

Donde `<nombre-del-grupo>` es un identificador alfanumérico (puede contener guiones bajos o guiones).

### Ejemplos
    
    
    # Group:	graphics
    
    
    # Group:	base
    
    
    # Group:	development

## Instalación por grupo

Una vez que los paquetes están clasificados en grupos, se pueden instalar todos los miembros de un grupo con un solo comando:
    
    
    sudo nhopkg --install-group <nombre-del-grupo>

Por ejemplo:
    
    
    # Instalar todos los paquetes del grupo "graphics"
    sudo nhopkg --install-group graphics
    
    # Instalar el sistema base mínimo
    sudo nhopkg --install-group base

## Funcionamiento interno

El comando `--install-group` realiza los siguientes pasos:

  1. **Escanea los repositorios locales sincronizados** (`/var/nhopkg/repo/*/packages/`).
  2. **Busca todos los archivos`nhoid`** que contengan la línea `# Group: <grupo>`.
  3. **Compila una lista única de paquetes** pertenecientes al grupo.
  4. **Resuelve las dependencias** de todos los paquetes del grupo.
  5. **Muestra un plan de instalación** y pide confirmación al usuario.
  6. **Descarga e instala** primero las dependencias y luego los paquetes del grupo.



**Nota:** La función que implementa esta lógica es `get_packages_by_group()`, definida en el script principal. Esta función es eficiente y está diseñada para trabajar con múltiples repositorios activos. 

## Uso práctico en distribuciones personalizadas

Los grupos son especialmente útiles para definir perfiles de instalación en una distribución personalizada. Algunos ejemplos comunes:

Grupo | Propósito | Paquetes de ejemplo  
---|---|---  
`base` | Sistema mínimo funcional | `glibc`, `bash`, `coreutils`, `systemd`  
`xorg` | Servidor gráfico X11 | `xorg-server`, `mesa`, `xf86-video-intel`  
`desktop` | Entorno de escritorio completo | `gnome`, `firefox`, `gimp`  
`server` | Paquetes para servidores | `openssh`, `nginx`, `postgresql`  
`development` | Herramientas de compilación | `gcc`, `make`, `git`, `valgrind`  
  
## Consideraciones importantes

  * Un paquete puede pertenecer a **varios grupos**: el campo `# Group:` puede aparecer más de una vez en el `nhoid`, y el paquete se incluye si cualquiera de sus líneas de grupo coincide.
  * La instalación por grupo **respeta todas las políticas de seguridad** (verificación de firmas, arquitectura, etc.).
  * Si un paquete del grupo ya está instalado, **se omitirá** a menos que haya una actualización disponible.
  * El comando fallará si **no se encuentra ningún paquete** para el grupo especificado.
    
    
    # Group:	base
    # Group:	development



## Ejemplo completo de flujo de trabajo
    
    
    # 1. Sincronizar repositorios
    sudo nhopkg --update
    
    # 2. Ver qué paquetes hay en el grupo "base"
    nhopkg --list-repo | grep "Group: base"
    
    # 3. Instalar el grupo "base"
    sudo nhopkg --install-group base
    
    # Salida esperada:
    #  - Packages to be installed:
    #    glibc-2.40-n2025
    #    bash-5.2.32-n2025
    #    coreutils-9.5-n2025
    #    ...
    # Do you want to continue?[yes/NO]: yes
    # ...
    #  - Group installation finished successfully!
