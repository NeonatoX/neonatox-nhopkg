# nhopkg-src — Ferramenta de Projeto de Pacote Fonte

## Visão Geral

`nhopkg-src` cria, valida e constrói projetos de pacotes fonte para o nhopkg. Funciona com arquivos `.srcnho` — tarballs planos contendo o arquivo de metadados `nhoid` mais patches e arquivos extras, que o `nhopkg -bv` usa para baixar, compilar e instalar pacotes binários.

## Comandos

### `--init [<nome>]`

Cria um novo diretório de projeto de pacote fonte. Perguntas interativas guiam você pelos campos obrigatórios e opcionais. Se `<nome>` for fornecido como argumento, ele é usado como nome do pacote e nome do diretório sem solicitação.

**Perguntas:**

| Campo | Obrigatório | Padrão | Notas |
|---|---|---|---|
| Nome | Sim | — | Do argumento ou pergunta interativa |
| Versão | Não | `1.0` | |
| Release | Não | `n2026` | |
| Nome do mantenedor | Não | `$USER` | Predefina com `PKG_MAINTAINER_NAME` |
| E-mail do mantenedor | Não | `$USER@$HOSTNAME` | Predefina com `PKG_MAINTAINER_EMAIL` |
| Licença | Não | `GPL-3.0-only` | |
| Arch | Não | `x86_64` | |
| URL | Não | (vazio) | Site do projeto upstream |
| Descrição | Não | (vazio) | |
| Packageurl | **Sim** | — | URL do tarball ou `git+<url>` para fontes git |
| Packageref | **Sim** se git | — | Referência de tag, commit ou branch |
| SHA256 download | Apenas para tarballs | S/n | Baixa o tarball e calcula o SHA256 automaticamente. Se ignorado, escreve `## SHA256:` como lembrete |
| Splitpackage | Não | (separado por espaço) | ex.: `dev lib docs` |
| Provides | Não | (separado por espaço) | |
| Conflicts | Não | (separado por espaço) | |

**Estrutura do projeto criado:**

```
<nome>/
├── nhoid              # Metadados do pacote e funções de construção
├── sources/           # Tarballs baixados (não incluídos no .srcnho)
├── patches/           # Arquivos *.patch e *.diff (incluídos no .srcnho)
├── others/            # Arquivos extras (incluídos no .srcnho)
└── build/             # Diretório de construção (não incluído no .srcnho)
```

**Template nhoid gerado:**

O arquivo `nhoid` inclui:
- Cabeçalho `#%NHO-0.5` com todos os campos de metadados
- Funções placeholder: `nbuild()`, `ninstall()`, `npostinstall()`, `npostremove()` (todas definidas como `noemptyfuncs`)
- Para pacotes divididos: funções geradas `ninstall_<parte>()`, `npostinstall_<parte>()`, `npostremove_<parte>()` para cada parte
- Campos de dependência comentados (`## BuildDep:`, `## Dep(pos):`, etc.) para edição manual

Consulte [`formato-nhoid.md`](formato-nhoid.md) para descrições detalhadas dos campos.

**Exemplos:**

```bash
# Criar um projeto interativamente
nhopkg-src --init

# Criar um projeto com um nome específico (pula a pergunta do nome)
nhopkg-src --init meuapp

# Criar um projeto de meta-pacote (aponta para um grupo de pacotes, sem fonte)
nhopkg-src --init meuapp --meta
```

Com `--meta`, a ferramenta cria um **meta-pacote**: um pacote sem arquivos
fonte que apenas depende dos pacotes de um grupo alvo. Os metadados são
preenchidos automaticamente (`License: CUSTOM`, `Arch: any`, URL e descrição
derivadas do nome), o prompt `Target group name` é mostrado, os pacotes do
grupo são resolvidos dos metadados do repositório e escritos como entradas
`# BuildDep:`/`# Dep(post):`, e nenhum prompt de Packageurl/hash/VCS é feito.
O projeto resultante empacota e instala normalmente, mas `nbuild()` permanece
`noemptyfuncs` e um `README.meta` é gerado na instalação.

Tarball nhoid (após download para SHA256):

```nhoid
#%NHO-0.5
# Package Maintainer:	user <user@host>

# Name:	meuapp
# Version:	1.0
# Release:	n2026
# License:	GPL-3.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://example.com/meuapp
# Description:	Minha aplicação
# Packageurl:	https://example.com/meuapp-1.0.tar.gz
# SHA256:	abc123def456...  meuapp-1.0.tar.gz
## BuildDep:	(adicione suas dependências de construção aqui)
## OptionalBuildDep:	(adicione suas dependências opcionais de construção)
## Dep(post):	(adicione suas dependências de execução aqui)
## OptionalDep(post):	(adicione suas dependências opcionais de execução)

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
```

Tarball sem SHA256 (lembrete deixado):

```nhoid
# Packageurl:	https://example.com/meuapp-1.0.tar.gz
## SHA256:	<pendente>  meuapp-1.0.tar.gz
```

Fonte git nhoid:

```nhoid
# Packageurl:	git+https://github.com/user/meuapp
# Packageref:	v1.0
```

Com pacotes divididos:

```nhoid
# Splitpackage:	dev lib

nbuild() {
    noemptyfuncs
}

ninstall() {
    noemptyfuncs
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_dev() {
    noemptyfuncs
}

npostinstall_dev() {
    noemptyfuncs
}

npostremove_dev() {
    noemptyfuncs
}

ninstall_lib() {
    noemptyfuncs
}

npostinstall_lib() {
    noemptyfuncs
}

npostremove_lib() {
    noemptyfuncs
}
```

---

### Respostas predefinidas por variáveis de ambiente

Cada pergunta do `--init` pode ser respondida de antemão exportando a variável
de ambiente correspondente. Quando a variável já está definida, o `nhopkg-src`
imprime o valor e omite a pergunta. Consulte a documentação em inglês para a
lista completa de variáveis (`PKG_NAME`, `PKG_VERSION`, `PKG_RELEASE`,
`PKG_MAINTAINER_NAME`, `PKG_MAINTAINER_EMAIL`, `PKG_GROUP`,
`PKG_REPOSITORY`, `PKG_LICENSE`, `PKG_ARCH`, `PKG_URL`, `PKG_DESCRIPTION`,
`PKG_PACKAGEURL`, `PKG_PACKAGEREF`, `PKG_HASH_TYPE`, `PKG_DOWNLOAD`,
`PKG_META_GROUP`, `PKG_SPLIT`, `PKG_PROVIDES`, `PKG_CONFLICTS`).

O nome e o e-mail do mantenedor são definidos em separado
(`PKG_MAINTAINER_NAME` e `PKG_MAINTAINER_EMAIL`); o e-mail tem como padrão
`$USER@$HOSTNAME` (fallback `user@host`). No nhoid eles são escritos juntos em
um único campo `# Package Maintainer: Name <email>`.

Exemplo — criar um metapacote sem nenhuma pergunta:

```bash
export PKG_MAINTAINER_NAME="Jane Doe"
export PKG_MAINTAINER_EMAIL="jane@example.com"
export PKG_META_GROUP="ttf-fonts"
nhopkg-src --init fonts-meta --meta
```

---

### `--createpackage [--force]`

Empacota o diretório do projeto atual em um tarball `.srcnho` plano.

**O que é incluído:**
- `nhoid` (obrigatório, validado primeiro via `--validate`)
- Arquivos `patches/*.patch` e `patches/*.diff`
- Arquivos `others/*` (qualquer tipo)

**O que NÃO é incluído:**
- Diretório `sources/`
- Diretório `build/`

**Comportamento:**
- Recusa sobrescrever um arquivo `.srcnho` existente a menos que `--force` seja fornecido
- O arquivo de saída é nomeado `<nome>-<versão>-<release>.srcnho`

**Exemplo:**

```bash
cd meuapp/
nhopkg-src --createpackage
# Cria: meuapp-1.0-n2026.srcnho

# Sobrescrever existente:
nhopkg-src --createpackage --force
```

---

### `--buildpackage`

Constrói o pacote `.srcnho` usando `nhopkg -bv` com `sudo -k` (sempre solicita senha).

**Fluxo:**
1. Lê o `nhoid` no diretório atual para obter `<nome>-<versão>-<release>`
2. Procura por `<nome>-<versão>-<release>.srcnho`
3. Aborta se o arquivo `.srcnho` não for encontrado
4. Executa `sudo -k nhopkg -bv <arquivo>.srcnho`

**Exemplo:**

```bash
cd meuapp/
nhopkg-src --createpackage
nhopkg-src --buildpackage
# Executa: sudo -k nhopkg -bv meuapp-1.0-n2026.srcnho
```

---

### `--validate [<arquivo_nhoid>]`

Valida um arquivo nhoid (padrão é `./nhoid`). Retorna código de saída 0 se válido, 1 se houver erros.

**Verificações realizadas:**

| Verificação | Tipo | Descrição |
|---|---|---|
| Cabeçalho `#%NHO-0.5` | Erro | Deve estar presente |
| `# Name:` | Erro | Deve estar presente e não vazio |
| `# Version:` | Erro | Deve estar presente e não vazio |
| `# Release:` | Erro | Deve estar presente e não vazio |
| `# Packageurl:` | Erro | Deve estar presente e não vazio (não obrigatório em meta-pacotes) |
| `# Packageref:` | Erro | Obrigatório se Packageurl começar com `git+` (não obrigatório em meta-pacotes) |
| `# SHA256:` | Aviso | Recomendado para fontes tarball, não obrigatório |
| Conteúdo de `nbuild()` | Erro | Deve ter comandos de construção reais (não apenas `noemptyfuncs`), exceto meta-pacotes |
| Conteúdo de `ninstall()` | Erro | Deve ter comandos de instalação reais (não apenas `noemptyfuncs`), exceto meta-pacotes |
| Existência de `npostinstall()` | Erro | A função deve estar definida |
| Existência de `npostremove()` | Erro | A função deve estar definida |
| Existência de funções divididas | Erro | `ninstall_<parte>()` deve existir para cada parte dividida |
| Sobreposição Provides/Conflicts | Erro | O mesmo nome não deve aparecer em ambos |

**Exemplos:**

```bash
nhopkg-src --validate
nhopkg-src --validate ./nhoid
nhopkg-src --validate /caminho/para/nhoid
```

## Formato do Arquivo .srcnho

O arquivo `.srcnho` é um archive tar plano (sem compressão, sem subdiretórios). Seu conteúdo é extraído pelo `nhopkg -bv` em um diretório temporário, onde o `nhopkg` lê o `nhoid`, baixa a fonte via `Packageurl`, verifica o `SHA256`, executa `nbuild()` e `ninstall()`, e produz o pacote binário `.nho` final.

**Conteúdo:**

```
nhoid
algum.patch
outro.diff
arquivo_extra
```

### `--get-source <projeto> [--ref <ref>]`

Clona um projeto fonte do repositório `NHOPKG_GIT_SOURCES`.

O projeto é clonado em um subdiretório com o nome do projeto. Se `--ref` for fornecido, é passado ao git como referência de tag, branch ou commit. Após clonar, os diretórios padrão `patches/` e `others/` são criados para que o projeto esteja pronto para edição e empacotamento.

A URL do repositório é construída como `${NHOPKG_GIT_SOURCES}/${projeto}.git`.

**Exemplos:**

```bash
# Clonar o projeto gcc
nhopkg-src --get-source gcc

# Clonar com um branch/tag específico
nhopkg-src --get-source gcc --ref n2027
```

## Veja Também

- [`formato-nhoid.md`](formato-nhoid.md) — referência completa dos campos nhoid
- `nhopkg -bv` — constrói um pacote binário a partir de um pacote fonte `.srcnho`
