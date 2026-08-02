[← Índice](README.md)

# 9\. Construção de pacotes

**nhopkg** pode construir pacotes binários (`.nho`) a partir de receitas fonte (`.srcnho`) ou diretamente de repositórios de controle de versão.

## Fluxo de construção

  1. Preparação do fonte
  2. Resolução de dependências
  3. Compilação (`nbuild()`)
  4. Instalação no diretório de staging (`ninstall()`)
  5. Detecção de arquivos
  6. Geração do pacote binário
  7. Assinatura GPG opcional

## Comandos de construção

    # Construir a partir de pacote fonte local
    sudo nhopkg --build foo.srcnho
    
    # Construir diretamente de um repositório de controle de versão
    sudo nhopkg --super-build foo

## Tipos de fonte

O campo `# Packageurl:` no `nhoid` seleciona como a fonte é obtida:

| Prefixo | Fonte |
|---|---|
| `https://...tar.gz` (ou outro tarball) | Baixar e extrair um tarball |
| `git+https://...` (ou URL terminada em `.git`) | Clone Git |
| `svn+https://...` | Checkout Subversion |
| `hg+https://...` | Clone Mercurial |

Para fontes de controle de versão, `# Packageref:` fixa a referência (tag, branch ou commit para git; revisão para svn e hg). Sem prefixo de esquema, a URL é tratada como tarball.

## Pacotes divididos (split)

Múltiplos pacotes binários podem ser gerados a partir de uma única receita:
    
    # Splitpackage: dev docs

Cada subpacote usa sua própria função `ninstall_<name>()`.
