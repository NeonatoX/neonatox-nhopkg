[← Índice](README.md)

# 11\. Múltiplos repositórios

**nhopkg** suporta múltiplos repositórios para organizar pacotes por propósito e ciclo de vida.

## Repositórios ativos
    
    NHOPKG_ACTIVE_REPOS="extra multilib"

## URLs dos repositórios
    
    NHOPKG_REPO_EXTRA=https://example.com/extra
    NHOPKG_REPO_MULTILIB=https://example.com/multilib

## Atribuição de pacotes
    
    # Repositório: extra

Apenas repositórios listados em `NHOPKG_ACTIVE_REPOS` são pesquisados.

## Criação de repositórios

Os repositórios são criados e mantidos com a ferramenta complementar `nhopkg-repos`:

    
    sudo nhopkg-repos -g /path/to/packages
