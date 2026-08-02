[← Índice](README.md)

# 5\. Seguridad y firmas GPG

**nhopkg** incluye soporte integrado para verificación de firmas GPG, lo que permite garantizar la autenticidad e integridad de los paquetes binarios antes de su instalación.

## La librería `libnhopkg_crypto`

Todas las operaciones criptográficas están implementadas en la librería **`libnhopkg_crypto`** (instalada como `/usr/lib/nhopkg/libnhopkg_crypto`) y son cargadas tanto por `nhopkg` como por `nhopkg-repos`. El módulo solo está activo cuando el binario `gpg` está disponible (`CRYPTO_GPG_AVAILABLE`).

### Firma y verificación de paquetes

Función | Propósito
---|---
`crypto_sign_package()` | Firma `data.tar.zst` en el directorio temporal de compilación con `NHOPKG_SIGN_KEY` usando `--detach-sign --armor`, generando `signature.gpg`. Se omite si `NHOPKG_SIGN_PACKAGES` no es `yes`.
`crypto_sign_package_ext()` | Igual, pero para un `data.tar.zst` externo (usado por `nhopkg-repos`).
`crypto_verify_signature()` | Verifica las firmas del paquete contra el keyring de confianza. Soporta **multi-firma**: busca todos los `signature*.gpg` en el directorio temporal y tiene éxito si al menos una verifica. Respeta `NHOPKG_REQUIRE_SIGNATURE` (aborta cuando se exige un paquete firmado).
`crypto_sign_file()` | Firma detachada de bajo nivel (`--detach-sign --armor`) de cualquier archivo.
`crypto_verify_file()` | Verificación de bajo nivel de una firma detachada contra el keyring de confianza.

### Firmado de metadatos de repositorio

`nhopkg-repos` también firma los metadatos del repositorio, y `nhopkg -U` los verifica antes de aceptar una actualización:

Función | Propósito
---|---
`crypto_sign_repo_metadata()` | Crea `<archivo>.asc` para cada archivo de metadatos `*.zst` más `lastsync.asc` en el directorio del repositorio.
`crypto_verify_repo_metadata()` | Verifica cada par `*.zst`/`.asc` y `lastsync.asc`; respeta `NHOPKG_REQUIRE_SIGNED_METADATA`.

### Gestión de claves

Función | Propósito
---|---
`crypto_init_keyring()` | Inicializa automáticamente el keyring de confianza: si falta `pubring.kbx` pero existe `nhopkg-repo.pub`, lo importa automáticamente.
`crypto_generate_key()` | Genera un nuevo par de claves GPG para un mantenedor (soporta batch/passphrase-file para CI/CD).
`crypto_import_key()` / `crypto_export_key()` / `crypto_list_keys()` / `crypto_remove_key()` | Gestionan las claves del keyring de confianza.
`crypto_verify_incoming()` | Verifica firmas de paquetes entrantes al añadirlos a un repositorio (flujo de colaboradores).

## Funcionamiento general

Cada paquete binario (`.nho`) puede contener opcionalmente un archivo `signature.gpg`, que es una firma GPG detachada del archivo `data.tar.zst`.

Durante la instalación, **nhopkg** verifica esta firma contra un keyring de confianza ubicado en:
    
    
    /etc/nhopkg/trusted-keys/

## Configuración de seguridad

El comportamiento de seguridad se controla mediante variables en `/etc/nhopkg/nhopkg.conf`:

Variable | Valor por defecto | Descripción  
---|---|---  
`NHOPKG_VERIFY_SIGNATURE` | `yes` | Habilita la verificación de firmas GPG al instalar paquetes.  
`NHOPKG_REQUIRE_SIGNATURE` | `no` | Exige que todos los paquetes estén firmados. Solo tiene efecto si `NHOPKG_VERIFY_SIGNATURE=yes`.  
`NHOPKG_TRUSTED_KEYS_DIR` | `/etc/nhopkg/trusted-keys/` | Directorio del keyring de confianza (debe contener `pubring.kbx`).  
`NHOPKG_SIGN_PACKAGES` | `yes` | Firma automáticamente los paquetes binarios al construirlos (solo para mantenedores).  
`NHOPKG_SIGN_KEY` | `repo@neonatox.vegnux.com` | Clave GPG predeterminada usada para firmar paquetes.  
`NHOPKG_VERIFY_INCOMING` | `no` | Verifica firmas de paquetes entrantes (colaboradores).  
`NHOPKG_SIGN_REPO_METADATA` | `yes` | Firma los archivos de metadatos del repositorio.  
`NHOPKG_VERIFY_REPO_METADATA` | `yes` | Verifica los metadatos del repositorio durante `nhopkg -U`.  
`NHOPKG_REQUIRE_SIGNED_METADATA` | `no` | Exige metadatos firmados válidos.  
  
## Inicialización automática del keyring

**Característica clave:** Si no existe el keyring (`pubring.kbx`) pero sí hay una clave pública en: 
    
    
    /etc/nhopkg/trusted-keys/nhopkg-repo.pub

**nhopkg** la importará automáticamente la primera vez que se requiera verificación. 

Esto facilita la distribución de repositorios seguros sin requerir pasos manuales adicionales por parte del usuario final.

## Flujo de verificación

  1. El usuario ejecuta `sudo nhopkg -i paquete.nho`.
  2. Si `NHOPKG_VERIFY_SIGNATURE=yes`, nhopkg busca `signature.gpg` dentro del paquete.
  3. Si no hay firma: 
     * Y `NHOPKG_REQUIRE_SIGNATURE=yes` → **aborta con error**.
     * De lo contrario → muestra advertencia y continúa.
  4. Si hay firma, la verifica contra el keyring en `/etc/nhopkg/trusted-keys/`.
  5. Si la firma es válida → continúa con la instalación.
  6. Si la firma es inválida o no confiable → **aborta con error**.

Se aceptan paquetes multi-firma cuando **al menos una** `signature*.gpg`
verifica contra el keyring de confianza.



## Firmado de paquetes (para mantenedores)

Al construir un paquete con `--build` o `--super-build`, si `NHOPKG_SIGN_PACKAGES=yes`, nhopkg:

  1. Genera `data.tar.zst`.
  2. Ejecuta: `gpg --detach-sign --armor data.tar.zst`.
  3. Renombra `data.tar.zst.asc` a `signature.gpg`.
  4. Incluye `signature.gpg` en el paquete final `.nho`.



## Ejemplo de uso seguro
    
    
    # Instalar con verificación forzada
    sudo nhopkg --verify-package-signature -i gimp-3.0.4-n2025.linux-x86_64.nho
    
    # Desactivar verificación temporalmente (solo para desarrollo)
    sudo nhopkg --no-verify-package-signature -i paquete-local.nho

## Recomendaciones

  * Mantén `NHOPKG_VERIFY_SIGNATURE=yes` en entornos de producción.
  * Usa `NHOPKG_REQUIRE_SIGNATURE=yes` si deseas una política estricta de solo paquetes firmados.
  * Distribuye siempre `nhopkg-repo.pub` junto con tu repositorio para facilitar la inicialización segura.
  * Protege tu clave privada de firma (`NHOPKG_SIGN_KEY`) en un entorno aislado.


