[← Índice](README.md)

# 7\. Grupos de paquetes y meta-paquetes

**nhopkg** permite organizar paquetes en **grupos lógicos** mediante el campo `# Group:` en el archivo `nhoid`. Los grupos son metadatos que se usan para buscar e informar; para instalar todo un conjunto de paquetes a la vez se crea un **meta-paquete** que depende del grupo.

## Definición de grupos

El campo `# Group:` puede aparecer más de una vez en un `nhoid`; un paquete pertenece a todos los grupos listados.

    # Group:	graphics
    # Group:	development

## Qué es un meta-paquete

Un meta-paquete es un paquete `.nho` que **no contiene archivos de aplicación**: solo depende de un conjunto de paquetes que se instalan juntos. Una vez instalado el meta-paquete, instalar y eliminar todo el conjunto se gestiona normalmente con nhopkg; sus dependencias se resuelven al instalarlo.

## Crear un meta-paquete

Se usa `nhopkg-src --init <nombre> --meta`. La herramienta pregunta por un **grupo objetivo** y escribe los nombres de los paquetes del grupo como entradas `# BuildDep:` y `# Dep(post):`:

```bash
# Crear un proyecto que depende de todo lo del grupo "base"
nhopkg-src --init base-meta --meta

# Empaquetarlo
nhopkg-src --createpackage

# Compilarlo e instalarlo (resuelve e instala todas sus dependencias)
sudo nhopkg-src --buildpackage
```

Los meta-paquetes usan metadatos fijos: `# License: CUSTOM`, `# Arch: any`, una URL de proyecto y la descripción `Metapackage for <nombre> group.`. No se requiere tarball fuente ni URL de descarga.

## Instalación y eliminación

Un meta-paquete se instala y elimina igual que cualquier otro paquete:

```bash
# Instalar un meta-paquete construido localmente
sudo nhopkg -i base-meta-1.0-n2026.linux-any.nho

# Desinstalarlo sin afectar a sus paquetes
sudo nhopkg -r base-meta

# Eliminarlo por completo (no existe configuración, así que basta -r; --purge es opcional para una eliminación definitiva)
sudo nhopkg --purge base-meta
```

Al eliminar el meta-paquete, sus paquetes **no** se eliminan automáticamente.

## Documentación

Al construir o instalar un meta-paquete, se genera un `README.meta` en `/usr/share/doc/<paquete>/` (en el idioma preferido del sistema cuando hay traducción disponible). Explica el propósito del meta-paquete, la lista de paquetes y cómo eliminarlo de forma segura.

## Casos de uso

Los grupos y los meta-paquetes son ideales para definir perfiles de sistema como `base`, `desktop` o `server`:

```bash
# Sincronizar repositorios
sudo nhopkg --update

# Listar paquetes de un grupo (buscar en los metadatos)
nhopkg --search base | grep base

# Compilar e instalar el meta-paquete "base"
nhopkg-src --init base-meta --meta
nhopkg-src --createpackage
sudo nhopkg -b base-meta-1.0-n2026.srcnho
```