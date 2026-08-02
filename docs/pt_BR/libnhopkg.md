[← Índice](README.md)

# A biblioteca base `libnhopkg`

**`libnhopkg`** é a biblioteca compartilhada principal do nhopkg. É instalada
como `/usr/lib/nhopkg/libnhopkg` e é carregada (via `source`) pelo script
principal (`nhopkg`), pelas ferramentas autônomas (`nhoget`, `nhouser`,
`nhopkg-src`, `nhopkg-repos`, `nhopkg-overlay`) e pelas bibliotecas
especializadas (`libnhopkg_udepsys`, `libnhopkg_download`, `libnhopkg_crypto`,
`libnhopkg_nhouser`).

Ela fornece as funções base: mensagens coloridas, diretórios temporários,
extração de dados de pacotes, verificação de hashes, geração de bancos de dados
de repositório/instalados e verificações de versão. Também define as constantes
de versão públicas.

## Constantes de versão

Variável | Valor | Descrição
---|---|---
`NHOPKG_VERSION` | `@PACKAGE_VERSION@` | Versão do nhopkg (definida no build).
`NHOID_VERSION` | `0.5` | Versão do formato nhoid suportada por esta versão.
`BINLOCATE` | definido no build | Binário `locate`/`plocate` usado para o banco de dados de arquivos.

## Ordem de carregamento

As ferramentas que precisam de `libnhopkg` o localizam via `NHOPKG_LIB`
(definida em `nhopkg.conf`) e o carregam com `source` antes de qualquer outra
biblioteca:

    source "${NHOPKG_LIB}"
    source "${NHOPKG_LIB%/libnhopkg}/libnhopkg_udepsys"

## Funções de mensagens

Função | Descrição
---|---
`echog()` | Imprime uma mensagem no idioma do sistema com quebra de linha (usa gettext quando `NHOPKG_GETTEXT=yes`).
`echogn()` | Imprime uma mensagem no idioma do sistema sem quebra de linha.

## Configuração e ambiente

Função | Descrição
---|---
`setup_busybox_path()` | Se `NHOPKG_USE_BUSYBOX=yes`, antepõe `/usr/lib/nhopkg/bin` (applets do BusyBox) ao `PATH`. É chamada automaticamente ao carregar a biblioteca. Veja [PATH privado do BusyBox](configuracao.md#path-privado-do-busybox).

## Diretórios e permissões

Função | Descrição
---|---
`get_pwd_dir()` | Define `CWD` (diretório de trabalho atual, com fallback em `/tmp`) e `DIROWNER` (`usuário:grupo`).
`check_if_root_uid()` | Termina com erro se não estiver sendo executado como root.
`make_tmp_dir()` | Cria um diretório temporário seguro e define `NHOPKG_TMPDIR`.
`check_if_ok()` | Verifica o resultado do comando anterior; se falhar, imprime uma mensagem, limpa e sai com 1.
`cleanup_tmp_dir()` | Remove `NHOPKG_TMPDIR` recursivamente.
`cleanup_all()` | Remove o arquivo de bloqueio do nhopkg e o diretório temporário.
`cleanup_build_dir()` | Oferece excluir o diretório de compilação atual sob `NHOPKG_BUILDIR`.

## Funções de dados de pacotes

Função | Descrição
---|---
`get_basic_data()` | Extrai `pkgname`, `pkgversion`, `pkgrevision` e `pkgdescription` de um arquivo de informações do pacote. Falha se faltar algum campo.
`get_nhoid_data()` | Extrai todos os campos de um arquivo `.nhoid` (`pkgname`, `pkgversion`, `pkgrevision`, `pkglicense`, `pkggroup`, `pkgrepo`, `pkgurl`, `pkgdescription`, `pkgsha256`, `pkgmd5`, `pkgsha512`, `pkgbsum`, `pkgarch`, `pkgos`, `pkginstalledsize`, `pkgsrcurl`, `pkggitref`). Gerencia pacotes divididos (`# Splitpackage:`) criando variáveis `pkgdescription_<parte>`. Valida o marcador de formato `#%NHO-` contra `NHOID_VERSION`.
`get_good_file_name()` | Deriva um nome curto de um caminho completo, usado para buscar dependências.
`nhopicker()` | Move arquivos de uma árvore de origem (staging) para uma árvore de destino usando padrões de `find -path`. Usado para dividir pacotes em subpacotes (ex.: `nhopicker destdir pkg-dev "*.a" "*.h" "*.pc"`).
`noemptyfuncs()` | Função vazia de não-operação, usada onde um corpo não vazio é exigido.

## Verificação de hashes e downloads

Função | Descrição
---|---
`verify_file_hash()` | Calcula o hash (`md5`, `sha256`, `sha512` ou `bsum`) de um arquivo e o compara com o valor esperado. Retorna 0 se coincidir, 1 se não, 2 se não houver ferramenta de hash disponível.
`get_hash_from_nhoid()` | Lê o tipo de hash solicitado de um arquivo `.nhoid`.
`check_package_hash()` | Verifica o hash de um pacote baixado contra os metadados do nhoid.
`download_with_hash_check()` | Baixa uma URL e verifica o arquivo resultante contra o hash esperado.
`verify_local_tarball_hash()` | Verifica um tarball local contra o hash registrado no nhoid.

## Geração de bancos de dados

Função | Descrição
---|---
`generate_repo_db()` | Constrói `repo.db` para um repositório (ou todos os ativos) em `${NHOPKG_LOCALSTATEDIR}/repo/<nome>`, extraindo os campos de cada `.nhoid` de pacote.
`generate_installed_db()` | Constrói o banco de dados de pacotes instalados.
`shooter_updates()` | Compara o banco de dados local de instalados com os metadados do repositório e informa sobre atualizações disponíveis.

## Bibliotecas relacionadas

Biblioteca | Finalidade | Veja também
---|---|---
`libnhopkg_udepsys` | Resolução unificada de dependências (`dep_resolve_from_nhoid`, `dep_install_queue`, `dep_check_conflicts`, `version_compare`, `get_repo_url`). | [`dependencias.md`](dependencias.md)
`libnhopkg_download` | Sistema de download unificado (GNU wget, curl, wget do BusyBox; clonagem VCS; resume; verificação de hash). | [`nhoget.md`](nhoget.md)
`libnhopkg_crypto` | Auxiliares de assinatura e verificação GPG. | [`seguranca.md`](seguranca.md)
`libnhopkg_nhouser` | Gerenciamento idempotente de usuários/grupos (backend duplo shadow-utils + BusyBox). | [`usuarios-servicos.md`](usuarios-servicos.md)
