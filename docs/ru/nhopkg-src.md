# nhopkg-src — инструмент для проектов исходных пакетов

## Обзор

`nhopkg-src` создаёт, проверяет и собирает проекты исходных пакетов для nhopkg. Он работает с файлами `.srcnho` — плоскими tarball-архивами, содержащими файл метаданных `nhoid`, а также патчи и дополнительные файлы, которые `nhopkg -bv` использует для загрузки, компиляции и установки бинарных пакетов.

## Команды

### `--init [<name>]`

Создаёт новый каталог проекта исходного пакета. Интерактивные запросы проводят вас по обязательным и необязательным полям. Если `<name>` передан аргументом, он используется как имя пакета и имя каталога без запросов.

**Промпты:**

| Поле | Обязательное | По умолчанию | Примечания |
|---|---|---|---|
| Имя | Да | — | Из аргумента или интерактивного запроса |
| Версия | Нет | `1.0` | |
| Выпуск | Нет | `n2026` | |
| Сопровождающий | Нет | `$USER <$USER@$HOSTNAME>` | |
| Лицензия | Нет | `GPL-3.0-only` | |
| Архитектура | Нет | `x86_64` | |
| URL | Нет | (пусто) | Веб-сайт вышестоящего проекта |
| Описание | Нет | (пусто) | |
| Packageurl | **Да** | — | URL tarball-архива или `git+<url>` для git-исходников |
| Packageref | **Да**, если git | — | Ссылка на тег, коммит или ветку |
| Загрузка SHA256 | Только для tarball-архивов | Д/н | Загружает tarball-архив и автоматически вычисляет SHA256. При пропуске записывает `## SHA256:` как напоминание |
| Splitpackage | Нет | (через пробел) | например `dev lib docs` |
| Provides | Нет | (через пробел) | |
| Conflicts | Нет | (через пробел) | |

**Создаваемая структура проекта:**

```
<name>/
├── nhoid              # Метаданные пакета и функции сборки
├── sources/           # Загруженные tarball-архивы (не включаются в .srcnho)
├── patches/           # Файлы *.patch и *.diff (включаются в .srcnho)
├── others/            # Дополнительные файлы (включаются в .srcnho)
└── build/             # Каталог сборки (не включается в .srcnho)
```

**Создаваемый шаблон nhoid:**

Файл `nhoid` включает:
- Заголовок `#%NHO-0.5` со всеми полями метаданных
- Функции-заглушки: `nbuild()`, `ninstall()`, `npostinstall()`, `npostremove()` (все установлены в `noemptyfuncs`)
- Для разделённых пакетов: сгенерированные `ninstall_<part>()`, `npostinstall_<part>()`, `npostremove_<part>()` для каждой части
- Закомментированные поля зависимостей (`## BuildDep:`, `## Dep(post):` и т. д.) для ручного редактирования

Подробные описания полей см. в [формате nhoid](format-nhoid.md).

**Примеры:**

```bash
# Создать проект интерактивно
nhopkg-src --init

# Создать проект с заданным именем (пропускает запрос имени)
nhopkg-src --init myapp
```

nhoid для tarball-архива (после загрузки для SHA256):

```nhoid
#%NHO-0.5
# Package Maintainer:	user <user@host>

# Name:	myapp
# Version:	1.0
# Release:	n2026
# License:	GPL-3.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://example.com/myapp
# Description:	My application
# Packageurl:	https://example.com/myapp-1.0.tar.gz
# SHA256:	abc123def456...  myapp-1.0.tar.gz
## BuildDep:	(добавьте сюда зависимости сборки)
## OptionalBuildDep:	(добавьте сюда необязательные зависимости сборки)
## Dep(post):	(добавьте сюда зависимости времени выполнения)
## OptionalDep(post):	(добавьте сюда необязательные зависимости времени выполнения)

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

nhoid для tarball-архива без SHA256 (оставлено напоминание):

```nhoid
# Packageurl:	https://example.com/myapp-1.0.tar.gz
## SHA256:	<pendiente>  myapp-1.0.tar.gz
```

nhoid для git-исходника:

```nhoid
# Packageurl:	git+https://github.com/user/myapp
# Packageref:	v1.0
```

С разделёнными пакетами:

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

### `--createpackage [--force]`

Упаковывает текущий каталог проекта в плоский tarball-архив `.srcnho`.

**Что включается:**
- `nhoid` (обязательный, сначала проверяется через `--validate`)
- файлы `patches/*.patch` и `patches/*.diff`
- файлы `others/*` (любого типа)

**Что НЕ включается:**
- каталог `sources/`
- каталог `build/`

**Поведение:**
- Отказывается перезаписывать существующий файл `.srcnho`, если не передан `--force`
- Выходной файл называется `<name>-<version>-<release>.srcnho`

**Пример:**

```bash
cd myapp/
nhopkg-src --createpackage
# Создаёт: myapp-1.0-n2026.srcnho

# Перезаписать существующий:
nhopkg-src --createpackage --force
```

---

### `--buildpackage`

Собирает пакет `.srcnho` с помощью `nhopkg -bv` и `sudo -k` (всегда запрашивает пароль).

**Порядок действий:**
1. Читает `nhoid` в текущем каталоге, чтобы получить `<name>-<version>-<release>`
2. Ищет `<name>-<version>-<release>.srcnho`
3. Прерывает выполнение, если файл `.srcnho` не найден
4. Выполняет `sudo -k nhopkg -bv <file>.srcnho`

**Пример:**

```bash
cd myapp/
nhopkg-src --createpackage
nhopkg-src --buildpackage
# Выполняет: sudo -k nhopkg -bv myapp-1.0-n2026.srcnho
```

---

### `--validate [<nhoid_file>]`

Проверяет файл nhoid (по умолчанию `./nhoid`). Возвращает код выхода 0, если файл корректен, и 1 при ошибках.

**Выполняемые проверки:**

| Проверка | Тип | Описание |
|---|---|---|
| Заголовок `#%NHO-0.5` | Ошибка | Должен присутствовать |
| `# Name:` | Ошибка | Должно присутствовать и быть непустым |
| `# Version:` | Ошибка | Должно присутствовать и быть непустым |
| `# Release:` | Ошибка | Должно присутствовать и быть непустым |
| `# Packageurl:` | Ошибка | Должен присутствовать и быть непустым |
| `# Packageref:` | Ошибка | Обязательно, если Packageurl начинается с `git+` |
| `# SHA256:` | Предупреждение | Рекомендуется для tarball-исходников, не обязательно |
| Содержимое `nbuild()` | Ошибка | Должны быть реальные команды сборки (не только `noemptyfuncs`) |
| Содержимое `ninstall()` | Ошибка | Должны быть реальные команды установки (не только `noemptyfuncs`) |
| Наличие `npostinstall()` | Ошибка | Функция должна быть определена |
| Наличие `npostremove()` | Ошибка | Функция должна быть определена |
| Наличие функций для разделённых частей | Ошибка | `ninstall_<part>()` должен существовать для каждой разделённой части |
| Перекрытие Provides/Conflicts | Ошибка | Одно и то же имя не должно встречаться в обоих полях |

**Примеры:**

```bash
nhopkg-src --validate
nhopkg-src --validate ./nhoid
nhopkg-src --validate /path/to/nhoid
```

## Формат файла .srcnho

Файл `.srcnho` — это плоский tar-архив (без сжатия и подкаталогов). Его содержимое извлекается `nhopkg -bv` во временный каталог, где `nhopkg` читает `nhoid`, загружает исходники через `Packageurl`, проверяет `SHA256`, выполняет `nbuild()` и `ninstall()` и создаёт конечный бинарный пакет `.nho`.

**Содержимое:**

```
nhoid
some.patch
another.diff
extra_file
```

### `--get-source <project> [--ref <ref>]`

Клонирует проект исходников из репозитория `NHOPKG_GIT_SOURCES`.

Проект клонируется в подкаталог, названный по имени проекта. Если передан `--ref`, он передаётся git как ссылка на тег, ветку или коммит. После клонирования создаются стандартные каталоги `patches/` и `others/`, чтобы проект был готов к редактированию и упаковке.

URL репозитория формируется как `${NHOPKG_GIT_SOURCES}/${project}.git`.

**Примеры:**

```bash
# Клонировать проект gcc
nhopkg-src --get-source gcc

# Клонировать с конкретной веткой/тегом
nhopkg-src --get-source gcc --ref n2027
```

## См. также

- [формат nhoid](format-nhoid.md) — полный справочник по полям nhoid
- `nhopkg -bv` — собирает бинарный пакет из исходного пакета `.srcnho`
