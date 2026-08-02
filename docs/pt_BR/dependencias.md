[← Índice](README.md)

# Resolução de Dependências — nhopkg v0.5.1

O Sistema Unificado de Resolução de Dependências (UDEPSYS) é o módulo responsável
por resolver, baixar e instalar dependências de pacotes. Ele é implementado
na biblioteca **`libnhopkg_udepsys`** (instalada como
`/usr/lib/nhopkg/libnhopkg_udepsys`) e carregada pelo binário principal `nhopkg`.
Ela expõe os pontos de entrada públicos `dep_resolve_from_nhoid()`,
`dep_install_queue()` e `dep_check_conflicts()`, além das funções auxiliares
`version_compare()` (comparação de versões via `sort -V`) e `get_repo_url()`
(construção da URL do repositório). Os downloads de pacotes são delegados ao
backend de download unificado `nhoget_url` de [`libnhopkg_download`](nhoget.md).

Para a sintaxe completa do campo nhoid (incluindo campos de dependência específicos
de split), consulte [formato-nhoid.md](formato-nhoid.md).

---

## Tipos de Dependência

Quatro tipos de dependência são suportados, cada um avaliado em um estágio diferente:

| Tipo | Chave interna | Quando é avaliado | Comportamento em falha |
|---|---|---|---|
| `# BuildDep:` | `build` | Antes de `nbuild()` | Falha grave se ausente |
| `# OptionalBuildDep:` | `optional_build` | Antes de `nbuild()` | Apenas aviso |
| `# Dep(post):` | `required` | Antes de `ninstall()` | Falha grave se ausente |
| `# OptionalDep(post):` | `optional` | Antes de `ninstall()` | Apenas aviso |

Falhas graves (`required` e `build`) fazem com que a instalação ou construção
seja abortada com erro. Tipos opcionais (`optional` e `optional_build`) emitem
um aviso e continuam.

---

## Operadores de Versão

Toda especificação de dependência pode incluir uma restrição de versão usando um
dos seguintes operadores:

| Operador | Significado |
|---|---|
| `=` | Igual |
| `!=` | Diferente |
| `<` | Menor que |
| `<=` | Menor ou igual |
| `>` | Maior que |
| `>=` | Maior ou igual |

A comparação é realizada por `version_compare()`, que delega para `sort -V`
(ordenação natural de versões). A função compara a versão do pacote instalado
ou do repositório contra a restrição e retorna sucesso se a restrição for
atendida.

Exemplos:

```
foo>=2.0
bar<1.5
baz!=3.0
qux=1.0
quux>4.0
```

Uma especificação sem operador corresponde a qualquer versão.

---

## Ordem de Resolução

Ao resolver uma dependência individual, o UDEPSYS pesquisa na seguinte ordem.
A primeira correspondência vence.

**NÍVEL 1 — Pacotes instalados (nome exato)**
Varre `${ROOT_PKG_STATE_DIR}/packages/` em busca de um arquivo cujo `# Name:`
interno corresponda ao nome da dependência. Restrições de versão são verificadas
contra a versão instalada.

**NÍVEL 2 — Pacotes instalados (Provides)**
Se nenhuma correspondência de nome exato for encontrada, cada pacote instalado
é verificado quanto a um campo `# Provides:` que corresponda ao nome da
dependência (com versão opcional).

**NÍVEL 3 — Pacotes do repositório (nome exato)**
Itera sobre cada repositório ativo (de `$NHOPKG_ACTIVE_REPOS`). Para cada
repositório, primeiro procura um arquivo com o nome exato da dependência,
depois por arquivos cujo `# Name:` interno corresponda. Restrições de versão
são verificadas.

**NÍVEL 4 — Pacotes do repositório (Provides)**
Se nenhuma correspondência de nome exato for encontrada em nenhum repositório,
`resolve_virtual_package()` é chamada para pesquisar em todos os repositórios
por uma linha `# Provides:` que corresponda ao nome da dependência.

### Cache

Os resultados são armazenados em cache no array associativo `DEP_RESOLVED_CACHE`
(chaveado pela string de especificação da dependência). Se a mesma especificação
for solicitada novamente dentro da mesma sessão, o resultado em cache é
retornado imediatamente e nenhuma varredura de repositório é realizada. O nome
do repositório é armazenado separadamente em `DEP_REPO_CACHE`.

---

## Provides e Conflicts

### Provides

Um pacote pode declarar que **fornece** um pacote virtual adicionando um campo
`# Provides:` em seu nhoid:

```
# Provides:	sdl2
```

Múltiplos pacotes virtuais são separados por espaços. Provides versionados são
expressos com `=`:

```
# Provides:	libfoo=2.0
```

Quando uma dependência não é satisfeita por nenhum nome de pacote real, o
resolvedor verifica se algum pacote (instalado ou em repositórios) *fornece*
o nome solicitado (NÍVEL 2 e NÍVEL 4 acima).

### Conflicts

Um pacote pode declarar que **conflita** com outro pacote:

```
# Conflicts:	sdl2
```

`dep_check_conflicts()` verifica se nenhum pacote instalado (ou fornecedor do
nome conflitante) corresponde à restrição. Se um conflito for encontrado, a
operação é abortada com erro.

### Substituição (autoconflito)

Existe um caso especial quando um pacote **conflita com algo que também
fornece**. Isso sinaliza uma *substituição* — o novo pacote deve ocupar o
lugar do antigo:

```
# Provides:	sdl2
# Conflicts:	sdl2
```

Neste caso, o resolvedor define `DEP_REPLACE_PACKAGE` como o nome do pacote
antigo, e a rotina de instalação (`_dep_install_single()`) remove o pacote
antigo antes de instalar o novo.

Restrições de versão funcionam tanto com Provides quanto com Conflicts:

```
# Provides:	libfoo>=2.0
# Conflicts:	libfoo<2.0
```

---

## Dependências Específicas de Split

Quando um pacote define subpacotes divididos (`# Splitpackage: dev lib docs`),
cada parte pode ter seus próprios campos de dependência usando o sufixo `_<parte>`:

```
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
# BuildDep_lib32:	cmake
```

O sufixo corresponde ao nome da parte dividida declarada em `# Splitpackage:`.
O sufixo é anexado a qualquer um dos quatro tipos de dependência:

| Campo | Significado |
|---|---|
| `# Dep_dev(post):` | Dep. de execução obrigatória para o subpacote `dev` |
| `# OptionalDep_lib(post):` | Dep. de execução opcional para o subpacote `lib` |
| `# BuildDep_lib32:` | Dep. de construção obrigatória para o subpacote `lib32` |
| `# OptionalBuildDep_docs:` | Dep. de construção opcional para o subpacote `docs` |

O mesmo mecanismo de sufixo se aplica a `# Provides:` e `# Conflicts:`:

```
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
```

---

## Fluxo de Resolução

O pipeline de resolução consiste em três funções públicas chamadas sequencialmente:

### 1. `dep_resolve_from_nhoid()`

Lê um arquivo nhoid e resolve todas as dependências de um determinado tipo
(`required`, `optional`, `build` ou `optional_build`). Para cada especificação
de dependência encontrada no campo correspondente, `_dep_resolve_single()` é
chamada.

- Se uma dependência obrigatória/de construção não puder ser resolvida, a função
  chama `exit 1` imediatamente.
- Se uma dependência opcional/optional_build não puder ser resolvida, um aviso é
  exibido e a resolução continua.
- Se a resolução recursiva estiver habilitada (padrão), `_dep_resolve_children()`
  é invocada em cada pacote de repositório recém-encontrado, resolvendo suas
  próprias dependências do mesmo tipo.

Pacotes encontrados em repositórios são anexados a `RCASEPACKAGES`
(obrigatórias/construção) ou `ORCASEPACKAGES` (opcionais/optional_build).

### 2. `dep_install_queue()`

Instala todos os pacotes acumulados nas filas de resolução. Ela:

1. Exibe a lista de pacotes ao usuário e solicita confirmação
   (a menos que `ask_user=no`).
2. Chama `_dep_download_all()` que baixa cada pacote do seu
   repositório via `nhoget_url` (o backend de download unificado: GNU wget,
   curl ou BusyBox wget).
3. Chama `_dep_install_all_from_queue()` (definida em `nhopkg.in`) que
   instala cada pacote baixado via `_dep_install_single()`.

`_dep_install_single()` lida com verificação de conflitos (via `dep_check_conflicts`),
atualizações, substituições, verificação de hash, verificação de arquitetura,
verificação de assinatura e a instalação real dos arquivos.

### 3. `dep_check_conflicts()`

Valida as declarações `# Conflicts:` de um pacote contra o conjunto de pacotes
instalados. Para cada especificação de conflito:

1. Verifica se o pacote conflitante está instalado pelo nome exato.
2. Verifica se algum pacote instalado *fornece* o nome conflitante.
3. Se um conflito for encontrado e o pacote também *fornecer* o nome conflitante,
   isso é tratado como uma *substituição* (veja acima) em vez de um erro.
4. Retorna diferente de zero se um conflito insolúvel for detectado, fazendo com
   que o chamador aborte a operação.
