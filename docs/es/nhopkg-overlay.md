# nhopkg-overlay — Entorno de compilación aislado

`nhopkg-overlay` proporciona un **entorno de compilación aislado** montando el sistema raíz del host como un overlay con semántica copy-on-write. Las compilaciones realizadas dentro solo escriben en una capa superior temporal, de modo que el sistema host nunca se modifica.

No acepta argumentos de línea de comandos: ejecútalo y obtendrás un shell dentro del entorno aislado, con el directorio de trabajo actual disponible en `/work`.

## Justificación

Compilar paquetes desde el código fuente puede modificar el sistema directamente (véase `ninstall()` en el formato nhoid). `nhopkg-overlay` permite a los mantenedores probar recetas `.srcnho` o ejecutar pasos de compilación no confiables sin arriesgar el sistema host:

- Raíz con copy-on-write: nada de lo escrito dentro del overlay llega al `/` real
- Los sistemas de archivos virtuales enlazados (`/dev`, `/proc`, `/sys`, `/run`) mantienen funcional el entorno
- El directorio de trabajo actual se expone en `/work`, de modo que las fuentes de compilación son accesibles desde el interior
- Al salir, todo se desmonta recursivamente y se elimina `/var/lib/nhopkg-overlay/`

## Estructura

El overlay se crea bajo `/var/lib/nhopkg-overlay/`:

| Ruta | Rol |
|------|-----|
| `/var/lib/nhopkg-overlay/upper` | Capa superior copy-on-write (todos los cambios van aquí) |
| `/var/lib/nhopkg-overlay/work` | Directorio de trabajo del overlay |
| `/var/lib/nhopkg-overlay/root` | Punto de montaje del overlay (la raíz aislada) |

Se monta así:

```
mount -t overlay overlay \
  -o lowerdir=/,upperdir=upper,workdir=work \
  root
```

Se enlazan por bind dentro de la raíz aislada:

- `/dev`, `/proc`, `/sys`, `/run`
- `devpts` en `/dev/pts` (para una terminal interactiva)
- El directorio de trabajo actual en `/work`

## Uso

Debe ejecutarse como **root**:

```
sudo nhopkg-overlay
```

Se entra en un shell `chroot` en la raíz del overlay, dentro de `/work`:

```
======================================
 Overlay active
 System: ISOLATED (overlay)
 Work: /work -> /home/usuario/pkg
======================================
```

Desde aquí puedes compilar paquetes como de costumbre (p. ej. `nhopkg -b foo.srcnho`). Todas las escrituras de archivos van a la capa superior y desaparecen al salir.

## Requisitos

- Privilegios de root
- `nhopkg` instalado y disponible en `PATH`
- `mount` disponible
- Kernel con soporte para overlayfs
- Un shell en `/bin/sh` en la raíz del overlay

## Limpieza

Al salir (EXIT, INT, TERM), `nhopkg-overlay`:

1. Mata los procesos que aún usan el overlay (`fuser -km` si está disponible)
2. Desmonta recursivamente la raíz del overlay y los puntos de montaje conocidos
3. Elimina `/var/lib/nhopkg-overlay/`

Si el directorio no puede eliminarse porque sigue ocupado, se muestra una advertencia.

## Véase también

- [Construcción de paquetes](construccion.md) — compilar paquetes `.srcnho`
- [Formato de paquete fuente](formato-nhoid.md) — campos y funciones del nhoid
- [`nhopkg-src`](nhopkg-src.md) — crear paquetes fuente
