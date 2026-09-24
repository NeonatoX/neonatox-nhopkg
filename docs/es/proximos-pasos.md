[← Índice](README.md)

# 13\. Próximos pasos

Aunque **nhopkg v1.0** es estable, hay margen de crecimiento.

## Completado

Los siguientes elementos de la hoja de ruta ya están implementados:

| Elemento | Dónde |
|---|---|
| Crear más paquetes `.srcnho` | Herramienta `nhopkg-src` (`--init`, `--createpackage`, `--buildpackage`) |
| Mejorar las definiciones de paquetes divididos | Campos por parte `# Description_<parte>:`, `# Group_<parte>:`, `# Repository_<parte>:`, `# Backup_<parte>:` (además de `Provides_/Conflicts_/Dep_/OptionalDep_`) |
| Flags de compilación reproducibles | Sección "Configuración de compilación — Optimizaciones" de `nhopkg.conf` (`NHOPKG_MACHINE`, `NHOPKG_CFLAGS`, ...) |
| Compilación en sandbox | `nhopkg-overlay` (superposición del directorio de compilación) |
| Descargas unificadas | `libnhopkg_download` / `nhoget` (GNU wget, curl, BusyBox wget, VCS) |
| Firma y verificación GPG | `libnhopkg_crypto`, firma de `nhopkg-repos`, `NHOPKG_REQUIRE_SIGNATURE` |
| Automatizar la creación de repositorios | `nhopkg-repos` (`--add-to-repo`) |
| PATH privado resiliente con BusyBox | BusyBox estático en `lib/nhopkg/bin` con enlaces simbólicos vía `nhopkg-bb-setup` |
| Páginas man | `nhopkg.8`, `nhoget.8`, `nhopkg-repos.8`, `nhopkg-src.8`, `nhopkg-overlay.8`, `nhouser.8`, `nhopkg.conf.5` |
| Grupos de paquetes claros | Meta-paquetes con `nhopkg-src --init --meta` / `get_packages_by_group_names()` |

## Aún en la hoja de ruta

  * Suite de pruebas automatizadas
  * Descargas delta

**nhopkg** es una base — hasta dónde llegue depende de sus usuarios.
