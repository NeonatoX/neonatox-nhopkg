[← Índice](README.md)

# 5\. Segurança e assinaturas GPG

**nhopkg** inclui suporte nativo para verificação de assinaturas GPG, garantindo autenticidade e integridade dos pacotes antes da instalação.

## A biblioteca `libnhopkg_crypto`

Todas as operações criptográficas são implementadas na biblioteca **`libnhopkg_crypto`** (instalada como `/usr/lib/nhopkg/libnhopkg_crypto`) e carregadas tanto pelo `nhopkg` quanto pelo `nhopkg-repos`. O módulo fica ativo apenas quando o binário `gpg` está disponível (`CRYPTO_GPG_AVAILABLE`).

### Assinatura e verificação de pacotes

Função | Finalidade
---|---
`crypto_sign_package()` | Assina `data.tar.zst` no diretório temporário de build com `NHOPKG_SIGN_KEY` usando `--detach-sign --armor`, gerando `signature.gpg`. É ignorado quando `NHOPKG_SIGN_PACKAGES` não é `yes`.
`crypto_sign_package_ext()` | Igual, mas para um `data.tar.zst` externo (usado pelo `nhopkg-repos`).
`crypto_verify_signature()` | Verifica as assinaturas do pacote contra o chaveiro confiável. Suporta **multi-assinatura**: encontra todos os `signature*.gpg` no diretório temporário e tem sucesso se pelo menos um verificar. Respeita `NHOPKG_REQUIRE_SIGNATURE` (aborta quando um pacote assinado é exigido).
`crypto_sign_file()` | Assinatura destacada de baixo nível (`--detach-sign --armor`) de qualquer arquivo.
`crypto_verify_file()` | Verificação de baixo nível de uma assinatura destacada contra o chaveiro confiável.

### Assinatura de metadados do repositório

O `nhopkg-repos` também assina os metadados do repositório, e o `nhopkg -U` os verifica antes de aceitar uma atualização:

Função | Finalidade
---|---
`crypto_sign_repo_metadata()` | Cria `<arquivo>.asc` para cada arquivo de metadados `*.zst` mais `lastsync.asc` no diretório do repositório.
`crypto_verify_repo_metadata()` | Verifica cada par `*.zst`/`.asc` e `lastsync.asc`; respeita `NHOPKG_REQUIRE_SIGNED_METADATA`.

### Gerenciamento de chaves

Função | Finalidade
---|---
`crypto_init_keyring()` | Inicializa automaticamente o chaveiro confiável: se `pubring.kbx` estiver ausente, mas `nhopkg-repo.pub` existir, importa-o automaticamente.
`crypto_generate_key()` | Gera um novo par de chaves GPG para um mantenedor (suporta batch/arquivo de passphrase para CI/CD).
`crypto_import_key()` / `crypto_export_key()` / `crypto_list_keys()` / `crypto_remove_key()` | Gerenciam chaves no chaveiro confiável.
`crypto_verify_incoming()` | Verifica assinaturas de pacotes recebidos ao adicioná-los a um repositório (fluxo de colaboradores).

## Visão geral

Pacotes binários (`.nho`) podem incluir um arquivo opcional `signature.gpg`, que é uma assinatura GPG destacada de `data.tar.zst`.

As chaves confiáveis são armazenadas em:
    
    
    /etc/nhopkg/trusted-keys/

## Configuração de segurança

Variável| Padrão| Descrição  
---|---|---  
`NHOPKG_VERIFY_SIGNATURE`| yes| Ativar verificação GPG  
`NHOPKG_REQUIRE_SIGNATURE`| no| Exigir pacotes assinados  
`NHOPKG_TRUSTED_KEYS_DIR`| /etc/nhopkg/trusted-keys/| Diretório do chaveiro confiável  
`NHOPKG_SIGN_PACKAGES`| yes| Assinar pacotes ao compilar  
`NHOPKG_SIGN_KEY`| repo@neonatox.vegnux.com| Chave de assinatura padrão  
`NHOPKG_VERIFY_INCOMING`| no| Verificar assinaturas de pacotes recebidos (colaboradores)  
`NHOPKG_SIGN_REPO_METADATA`| yes| Assinar arquivos de metadados do repositório  
`NHOPKG_VERIFY_REPO_METADATA`| yes| Verificar metadados do repositório durante `nhopkg -U`  
`NHOPKG_REQUIRE_SIGNED_METADATA`| no| Exigir metadados assinados válidos  

**Inicialização automática do chaveiro:** se `pubring.kbx` não existir, mas `nhopkg-repo.pub` estiver presente, o nhopkg o importa automaticamente.

## Fluxo de verificação

  1. O usuário instala um pacote.
  2. Se a verificação estiver ativada, o nhopkg verifica `signature.gpg`.
  3. Se ausente e obrigatório → abortar.
  4. Se inválido → abortar.
  5. Se válido → continuar.

Pacotes multi-assinatura são aceitos quando **pelo menos uma** `signature*.gpg`
verifica contra o chaveiro confiável.

## Recomendações

  * Mantenha a verificação de assinaturas ativada em produção.
  * Ative assinaturas obrigatórias para sistemas críticos.
  * Proteja sua chave privada de assinatura.

