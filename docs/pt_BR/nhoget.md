# nhoget — Ferramenta de Download Unificada

`nhoget` é o sistema de download unificado para o gerenciador de pacotes nhopkg. Ele fornece capacidades de download HTTP/HTTPS e VCS transparentes para todos os componentes do nhopkg — construções, instalações, atualizações de repositórios e criação de pacotes fonte — além de servir como uma ferramenta CLI independente utilizável em scripts pós-instalação, receitas de construção ou no terminal.

## Justificativa

Antes do `nhoget`, o nhopkg usava chamadas ad-hoc a `wget` e `git clone` espalhadas por todo o código base. Isso dificultava:

- Alternar entre backends de download (GNU wget, curl, BusyBox wget)
- Adicionar tipos de VCS além do git (svn, hg)
- Aplicar políticas consistentes de repetição, tempo limite e retomada
- Auditar ou estender o comportamento de download

`nhoget` centraliza toda a lógica de download em uma única biblioteca (`libnhopkg_download`) exposta através de uma ferramenta CLI e carregada de forma transparente pelo `nhopkg`.

## Garantia de transparência

`nhoget` é uma **substituição transparente**: nenhum fluxo de trabalho existente do nhopkg, formato nhoid ou interface de usuário foi alterado. As mesmas opções (`nhopkg -b`, `-C`, `-S`, `-U`) se comportam de forma idêntica. Internamente, cada `wget` e `git clone` foi substituído por `nhoget_url` / `nhoget_vcs`.

## Comandos

### `download`

Baixa um arquivo via HTTP/HTTPS.

```
nhoget download [opções] <url> [<dest>]
```

Se `<dest>` for omitido, o nome do arquivo é derivado da URL. Use `-o` para especificar um caminho de saída exato, ou `-O` para especificar um diretório de saída. Suporta verificação de hash com `--hash`.

### `clone`

Clona um repositório VCS.

```
nhoget clone [opções] <url> [<dest>]
```

Padrão é git. Use `--type svn` ou `--type hg` para outros tipos de VCS. O destino padrão é o nome base da URL (com `.git` removido para URLs git).

### `fetch`

Detecta automaticamente o tipo de fonte pela URL e baixa ou clona.

```
nhoget fetch [opções] <url> [<dest>]
```

Regras de detecção:

| Padrão de URL | Comportamento |
|-------------|-----------|
| `git+<url>` ou `*.git` | Git clone |
| `svn+<url>` | Subversion checkout |
| `hg+<url>` | Mercurial clone |
| URL simples | Download de tarball + extração automática |

Os tarballs são extraídos com `--strip-components=1` no diretório de destino. Formatos suportados: `.tar.zst`, `.tar.xz`, `.tar.bz2`, `.tar.gz`, `.zip`, `.AppImage`.

Para tipos VCS, `nhoget fetch` tenta uma atualização incremental (fetch + checkout) se o destino já existir, recorrendo a um clone novo em caso de falha.

### `patch`

Baixar um arquivo de patch ou diff, salvando-o com o nome de arquivo original da URL.

```
nhoget patch <url>
```

O arquivo é salvo como `../<nome-do-arquivo>` (diretório pai do diretório de trabalho).

## Opções

| Curta | Longa | Descrição |
|-------|-------|-------------|
| `-o` | `--output FILE` | Salvar em um arquivo específico (apenas download) |
| `-O` | `--output-dir DIR` | Salvar em um diretório |
| `-r` | `--resume` | Retomar um download parcial |
| `-t` | `--timeout SECS` | Tempo limite de conexão (padrão: 20) |
| | `--retries N` | Número de repetições (padrão: 3) |
| `-q` | `--quiet` | Suprimir saída não essencial |
| `-v` | `--verbose` | Saída detalhada |
| | `--hash TIPO:VALOR` | Verificar hash após o download (ex.: `sha256:abc...`) |
| | `--type TIPO` | Forçar tipo de fonte: `tarball`, `git`, `svn`, `hg` |
| | `--ref REF` | Referência VCS (tag, branch, commit para git; revisão para svn) |
| | `--depth N` | Profundidade de clone superficial (apenas git) |
| | `--backend BACKEND` | Forçar backend: `wget`, `curl`, `wget-bb`, `auto` |
| `-h` | `--help` | Mostrar ajuda |
| | `--version` | Mostrar versão |

## Backends

O backend `auto` faz a varredura nesta ordem:

1. **GNU wget** — preferido para compatibilidade com versões anteriores (não curl, apesar de curl ser mais portável)
2. **curl** — usado se o GNU wget não estiver disponível
3. **BusyBox wget** — suporta HTTPS; as repetições são implementadas através de um loop manual (BusyBox não possui a opção `-t`)

## A biblioteca `libnhopkg_download`

Toda a lógica de download reside na biblioteca **`libnhopkg_download`** (instalada como `/usr/lib/nhopkg/libnhopkg_download`). O CLI `nhoget` é um wrapper leve sobre ela, e a biblioteca também é carregada diretamente pelo `nhopkg`, pelo `nhopkg-src` e pelo resolvedor de dependências. Funções principais:

Função | Finalidade
---|---
`nhoget_detect_backend()` | Seleciona o backend de download (`wget`, `curl`, `wget-bb`) respeitando `NHOGET_BACKEND`.
`nhoget_url()` | Baixa uma única URL com repetições, tempo limite e retomada opcional.
`nhoget_url_wget_bb()` | Variante para BusyBox wget (loop manual de repetições; BusyBox não tem `-t`).
`nhoget_verify_hash()` | Verifica um arquivo baixado contra uma especificação de hash `TIPO:VALOR`.
`nhoget_vcs()` / `nhoget_vcs_git()` / `nhoget_vcs_svn()` / `nhoget_vcs_hg()` | Operações de clonagem/checkout VCS.
`nhoget_fetch()` | Detecta automaticamente o tipo de fonte e despacha para os caminhos URL ou VCS.
`nhoget_fetch_tarball()` | Baixa e extrai automaticamente um tarball (com `--strip-components=1`).

O comportamento de retomada e verificação de hash é, portanto, idêntico seja o download disparado pelo CLI `nhoget`, por uma receita de compilação, ou pelas chamadas `nhoget_url` do resolvedor de dependências.

## Configuração

O comportamento é controlado por variáveis de ambiente ou `/etc/nhopkg/nhopkg.conf`:

| Variável | Padrão | Descrição |
|----------|---------|-------------|
| `NHOGET_BACKEND` | `auto` | Seleção de backend (`wget`, `curl`, `wget-bb`, `auto`) |
| `NHOGET_TIMEOUT` | `20` | Tempo limite de conexão em segundos |
| `NHOGET_RETRIES` | `3` | Número de repetições de download |
| `NHOGET_RESUME` | `yes` | Habilitar retomada de downloads parciais |

## Prefixos de URL

Repositórios VCS podem ser especificados com prefixos de URL:

- `git+https://exemplo.com/repo` — Repositório Git
- `svn+https://exemplo.com/svn/repo` — Repositório Subversion
- `hg+https://exemplo.com/repo` — Repositório Mercurial
- `https://exemplo.com/pacote.tar.zst` — Tarball simples (extração automática)

Para compatibilidade com versões anteriores, URLs que terminam em `.git` também são tratadas como repositórios Git (sem necessidade do prefixo `git+`).

## Veja Também

- [Referência de comandos](comandos.md) — Comandos principais do nhopkg
- [Visão geral da arquitetura](arquitetura.md)
