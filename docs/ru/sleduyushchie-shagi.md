[← Документация](README.md)

# 13\. Следующие шаги

Хотя **nhopkg v1.0** стабилен, есть пространство для роста.

## Завершено

Следующие пункты дорожной карты уже реализованы:

| Пункт | Где |
|---|---|
| Создание большего числа пакетов `.srcnho` | Инструмент `nhopkg-src` (`--init`, `--createpackage`, `--buildpackage`) |
| Улучшение определений разделённых пакетов | Поля по частям `# Description_part:`, `# Group_part:`, `# Repository_part:`, `# Backup_part:` (плюс `Provides_/Conflicts_/Dep_/OptionalDep_`) |
| Флаги воспроизводимой сборки | Раздел `nhopkg.conf` «Конфигурация сборки — Оптимизации компиляции» (`NHOPKG_MACHINE`, `NHOPKG_CFLAGS`, ...) |
| Изолированная сборка | `nhopkg-overlay` (оверлей каталога сборки) |
| Унифицированные загрузки | `libnhopkg_download` / `nhoget` (GNU wget, curl, BusyBox wget, VCS) |
| GPG-подпись и проверка | `libnhopkg_crypto`, подпись `nhopkg-repos`, `NHOPKG_REQUIRE_SIGNATURE` |
| Автоматизация создания репозиториев | `nhopkg-repos` (`--add-to-repo`) |
| Устойчивый приватный PATH | Статический BusyBox в `lib/nhopkg/bin` с символическими ссылками через `nhopkg-bb-setup` |
| Страницы man | `nhopkg.8`, `nhoget.8`, `nhopkg-repos.8`, `nhopkg-src.8`, `nhopkg-overlay.8`, `nhouser.8`, `nhopkg.conf.5` |
| Чёткие группы пакетов | Мета-пакеты через `nhopkg-src --init --meta` / `get_packages_by_group_names()` |

## В планах

  * Автоматический набор тестов
  * Дельта-загрузки

**nhopkg** — это фундамент; насколько далеко он продвинется, зависит от его пользователей.
