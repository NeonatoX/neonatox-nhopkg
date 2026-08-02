[← Документация](README.md)

# 11\. Несколько репозиториев

**nhopkg** поддерживает несколько репозиториев, позволяя организовывать пакеты по назначению и жизненному циклу.

## Активные репозитории
    
    
    NHOPKG_ACTIVE_REPOS="extra multilib"

## URL репозиториев
    
    
    NHOPKG_REPO_EXTRA=https://example.com/extra
    NHOPKG_REPO_MULTILIB=https://example.com/multilib

## Назначение пакетов
    
    
    # Репозиторий: extra

Поиск выполняется только в репозиториях, перечисленных в `NHOPKG_ACTIVE_REPOS`.

## Создание репозиториев

Репозитории создаются и обслуживаются с помощью сопутствующего инструмента `nhopkg-repos`:

    
    
    sudo nhopkg-repos -g /path/to/packages
