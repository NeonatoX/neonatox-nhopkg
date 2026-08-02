# Formato do Arquivo nhoid — nhopkg v0.5.1

O arquivo nhoid é o descritor de metadados usado em pacotes binários (`.nho`) e fonte (`.srcnho`). Ele define identidade do pacote, dependências, etapas de compilação, lógica de instalação e tarefas pós-instalação.

## Regras do Formato

- Campos usam sintaxe `# NomeDoCampo:\tvalor` (separado por tabulação)
- Comentários usam `##` (hash duplo) — ignorados pelo interpretador
- O arquivo deve começar com o cabeçalho `#%NHO-0.5`
- Funções (`nbuild()`, `ninstall()`, etc.) definem código executável

## Cabeçalho

```nhoid
#%NHO-0.5
# Package Maintainer:	Nome <email>
```

Se a versão do cabeçalho não corresponder a `NHOID_VERSION`, o pacote é rejeitado.

## Campos de Metadados

| Campo | Obrigatório | Descrição |
|---|---|---|
| `# Name:` | Sim | Nome do pacote |
| `# Version:` | Sim | Versão do pacote (ex. `1.0`, `2.15.6`) |
| `# Release:` | Sim | Lançamento do pacote (ex. `n2026`) |
| `# License:` | Não | Licença de software (ex. `GPL-3.0-only`, `MIT`) |
| `# Group:` | Não | Classificação de grupo do pacote |
| `# Repository:` | Não | Repositório alvo (`core`, `extra`, `multilib`) |
| `# Arch:` | Não | Arquitetura(s) alvo, separadas por espaço (ex. `i686 x86_64`) |
| `# OS:` | Não | Sistema operacional alvo |
| `# Url:` | Não | Site do projeto upstream |
| `# Description:` | Não | Descrição do pacote |
| `# Installed-Size:` | Não | Tamanho instalado em bytes (calculado automaticamente durante a compilação) |
| `# Build-Duration:` | Não | Tempo de compilação (registrado automaticamente) |
| `# Build-Date:` | Não | Carimbo de data/hora da compilação (registrado automaticamente) |
| `# Build-Host:` | Não | Nome do host de compilação (registrado automaticamente) |

### Metadados de Fonte

| Campo | Obrigatório | Descrição |
|---|---|---|
| `# Packageurl:` | Sim | URL da fonte. Para tarballs: `https://...tar.gz`. Para git: `git+https://...` |
| `# Packageref:` | Apenas se git | Referência de tag, commit ou branch do Git |
| `# SHA256:` | Recomendado para tarballs | Soma de verificação SHA256 + nome do arquivo. Alternativa: `# MD5:`, `# SHA512:`, `# BSUM:` |

Exemplo:

```nhoid
# Packageurl:	https://example.com/pkg-1.0.tar.gz
# SHA256:	a1b2c3d4...  pkg-1.0.tar.gz
```

Para fontes git:

```nhoid
# Packageurl:	git+https://github.com/user/repo
# Packageref:	v1.0
```

### Pacotes Divididos (Split)

Pacotes divididos permitem que uma única fonte produza múltiplos sub-pacotes.

```nhoid
# Splitpackage:	dev lib docs
```

Cada parte dividida tem seu próprio conjunto de campos de metadados usando o sufixo `_<parte>`:

```nhoid
# Description_dev:	Cabeçalhos de desenvolvimento
# Description_lib:	Bibliotecas compartilhadas
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
# Group_docs:	doc
# Repository_dev:	extra
# Dep_dev(post):	somepackage
```

### Provides e Conflicts

```nhoid
# Provides:	sdl2
# Provides_lib32:	lib32-sdl2
# Conflicts:	sdl2
# Conflicts_lib32:	lib32-sdl2
```

### Backup

Arquivos listados em `# Backup:` são preservados antes da extração e restaurados depois. Útil para arquivos de configuração.

```nhoid
# Backup:	/etc/foo.conf /etc/foo.d/*
```

### Dependências

Todos os campos de dependência são opcionais. Múltiplos pacotes são separados por espaço. Operadores de versão: `>=`, `<=`, `!=`, `>`, `<`, `=`.

```nhoid
# BuildDep:	cmake ninja
# OptionalBuildDep:	gtk4>=4.10
# Dep(post):	libfoo
# OptionalDep(post):	bar<2.0
```

Dependências específicas de partes divididas usam o sufixo `_<parte>`:

```nhoid
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
```

### Tipos de Dependência

| Campo | Quando avaliado | Descrição |
|---|---|---|
| `# BuildDep:` | Antes de `nbuild()` | Dependências de compilação obrigatórias |
| `# OptionalBuildDep:` | Antes de `nbuild()` | Dependências de compilação opcionais |
| `# Dep(post):` | Antes de `ninstall()` | Dependências de execução obrigatórias |
| `# OptionalDep(post):` | Antes de `ninstall()` | Dependências de execução opcionais |

---

## Funções

Funções definem código executável. Devem ser bash válido.

### nbuild()

Comandos de compilação. Deve ter conteúdo real (não apenas `noemptyfuncs`).

```bash
nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}
```

### ninstall()

Comandos de instalação. Deve ter conteúdo real.

Os arquivos são instalados diretamente na raiz do sistema ativo. Os novos arquivos instalados são então detectados pela varredura de `FIND_DIRS`.

```bash
ninstall() {
    ninja -C build install
}
```

### ninstall_\<parte\>()

Comandos de instalação para um sub-pacote dividido.

```bash
ninstall_dev() {
    cp -r include/* /usr/include/
}
```

### npostinstall()

Comandos pós-instalação (ldconfig, hardlinks, etc.). Pode ser `noemptyfuncs`.

```bash
npostinstall() {
    ldconfig
}
```

### npostinstall_\<parte\>()

Pós-instalação para um sub-pacote dividido.

### npostremove()

Comandos pós-remoção. Pode ser `noemptyfuncs`.

```bash
npostremove() {
    rm -f /etc/ld.so.cache
}
```

### npostremove_\<parte\>()

Pós-remoção para um sub-pacote dividido.

### noemptyfuncs

Placeholder para funções opcionais. Previne erros do bash quando um corpo de função está intencionalmente vazio.

```bash
npostinstall() {
    noemptyfuncs
}
```

---

## Exemplos

### Pacote tarball simples

```nhoid
#%NHO-0.5
# Package Maintainer:	usuario <usuario@host>

# Name:	mktorrent
# Version:	1.1
# Release:	n2026
# License:	GPL-2.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://github.com/pobrn/mktorrent
# Description:	Utilitário simples de linha de comando para criar arquivos de metadados BitTorrent.
# Packageurl:	https://github.com/pobrn/mktorrent/archive/v1.1/mktorrent-1.1.tar.gz
# SHA256:	d0f47500192605d01b5a2569c605e51ed319f557d24cfcbcb23a26d51d6138c9  mktorrent-1.1.tar.gz

nbuild() {
    make
}

ninstall() {
    make install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}
```

### Fonte Git com pacotes divididos

```nhoid
#%NHO-0.5
# Package Maintainer:	cargabsj175 <cargabsj175@gmail.com>

# Name:	qt6
# Version:	6.10.2
# Release:	n2026
# License:	GPL-3.0-only LGPL-3.0-only
# Repository:	extra
# Arch:	i686 x86_64
# Url:	https://www.qt.io/
# Description:	Um framework multiplataforma para aplicativos e interfaces de usuário.
# Description_xcb_private_headers:	Cabeçalhos privados para Qt6 Xcb.
# Packageurl:	git+https://github.com/qt/qtbase
# Packageref:	v6.10.2
# Splitpackage:	xcb_private_headers

nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}

ninstall() {
    ninja -C build install
}

npostinstall() {
    noemptyfuncs
}

npostremove() {
    noemptyfuncs
}

ninstall_xcb_private_headers() {
    cp -r include/* /usr/include/
}

npostinstall_xcb_private_headers() {
    noemptyfuncs
}

npostremove_xcb_private_headers() {
    noemptyfuncs
}
```
