# Формат файла nhoid — nhopkg v0.5.1

Файл nhoid — это дескриптор метаданных, используемый как в бинарных (`.nho`), так и в исходных (`.srcnho`) пакетах. Он определяет идентичность пакета, зависимости, шаги сборки, логику установки и задачи пост-установки.

## Правила формата

- Поля используют синтаксис `# ИмяПоля:\tзначение` (разделитель — табуляция)
- Комментарии используют `##` (двойной хэш) — игнорируются парсером
- Файл должен начинаться с заголовка `#%NHO-0.5`
- Функции (`nbuild()`, `ninstall()` и т. д.) определяют исполняемый код

## Заголовок

```nhoid
#%NHO-0.5
# Package Maintainer:	Имя <email>
```

Если версия заголовка не совпадает с `NHOID_VERSION`, пакет отклоняется.

## Поля метаданных

| Поле | Обязательно | Описание |
|---|---|---|
| `# Name:` | Да | Имя пакета |
| `# Version:` | Да | Версия пакета (например, `1.0`, `2.15.6`) |
| `# Release:` | Да | Релиз пакета (например, `n2026`) |
| `# License:` | Нет | Лицензия ПО (например, `GPL-3.0-only`, `MIT`) |
| `# Group:` | Нет | Классификация группы пакета (может встречаться более одного раза; пакет может принадлежать нескольким группам) |
| `# Repository:` | Нет | Целевой репозиторий (`core`, `extra`, `multilib`) |
| `# Arch:` | Нет | Целевая архитектура (архитектуры), через пробел (например, `i686 x86_64`) |
| `# OS:` | Нет | Целевая операционная система |
| `# Url:` | Нет | Веб-сайт вышестоящего проекта |
| `# Description:` | Нет | Описание пакета |
| `# Installed-Size:` | Нет | Установленный размер в байтах (рассчитывается автоматически при сборке) |
| `# Build-Duration:` | Нет | Время сборки (фиксируется автоматически) |
| `# Build-Date:` | Нет | Метка времени сборки (фиксируется автоматически) |
| `# Build-Host:` | Нет | Имя хоста сборки (фиксируется автоматически) |

### Метаданные исходного кода

| Поле | Обязательно | Описание |
|---|---|---|
| `# Packageurl:` | Да | URL исходного кода. Для tarball-архивов: `https://...tar.gz`. Для систем контроля версий используйте префикс схемы: `git+`, `svn+` или `hg+` (URL, заканчивающийся на `.git`, также считается Git) |
| `# Packageref:` | Только для VCS | Ссылка контроля версий: тег, коммит или ветка (git); ревизия (svn, hg) |
| `# SHA256:` | Рекомендуется для tarball | Контрольная сумма SHA256 + имя файла. Альтернатива: `# MD5:`, `# SHA512:`, `# BSUM:` |

Пример:

```nhoid
# Packageurl:	https://example.com/pkg-1.0.tar.gz
# SHA256:	a1b2c3d4...  pkg-1.0.tar.gz
```

Для источников контроля версий префикс схемы выбирает систему:

```nhoid
# Packageurl:	git+https://github.com/user/repo
# Packageref:	v1.0

# Packageurl:	svn+https://svn.example.com/project
# Packageref:	r42

# Packageurl:	hg+https://hg.example.com/project
# Packageref:	1.0
```

### Разделённые пакеты

Разделённые пакеты позволяют одному исходному коду порождать несколько подпакетов.

```nhoid
# Splitpackage:	dev lib docs
```

Каждая разделённая часть имеет собственный набор полей метаданных с суффиксом `_<часть>`:

```nhoid
# Description_dev:	Заголовочные файлы разработчика
# Description_lib:	Разделяемые библиотеки
# Provides_dev:	libfoo-dev
# Conflicts_lib32:	lib32-libfoo
# Group_docs:	doc
# Repository_dev:	extra
# Dep_dev(post):	somepackage
# Backup_dev:	/etc/foo-dev.conf
```

Поля `# Backup_<часть>:` для разделённых частей работают как основное поле `# Backup:`: файлы подпакета сохраняются перед извлечением и восстанавливаются после. `# Group_<часть>:`, `# Repository_<часть>:` и `# Provides_<часть>:` / `# Conflicts_<часть>:` переопределяют соответствующие основные поля для подпакета.

### Provides и Conflicts

```nhoid
# Provides:	sdl2
# Provides_lib32:	lib32-sdl2
# Conflicts:	sdl2
# Conflicts_lib32:	lib32-sdl2
```

### Backup

Файлы, перечисленные в `# Backup:`, сохраняются перед извлечением и восстанавливаются после него. Полезно для файлов конфигурации.

```nhoid
# Backup:	/etc/foo.conf /etc/foo.d/*
```

Разделённые подпакеты используют собственное поле `# Backup_<часть>:` (см. раздел Разделённые пакеты выше).

### Зависимости

Все поля зависимостей необязательны. Несколько пакетов разделяются пробелами. Операторы версий: `>=`, `<=`, `!=`, `>`, `<`, `=`.

```nhoid
# BuildDep:	cmake ninja
# OptionalBuildDep:	gtk4>=4.10
# Dep(post):	libfoo
# OptionalDep(post):	bar<2.0
```

Зависимости, специфичные для разделённых частей, используют суффикс `_<часть>`:

```nhoid
# Dep_dev(post):	libfoo-dev
# OptionalDep_lib(post):	lib32-gcc
```

### Типы зависимостей

| Поле | Когда вычисляется | Описание |
|---|---|---|
| `# BuildDep:` | Перед `nbuild()` | Обязательные зависимости сборки |
| `# OptionalBuildDep:` | Перед `nbuild()` | Необязательные зависимости сборки |
| `# Dep(post):` | Перед `ninstall()` | Обязательные зависимости времени выполнения |
| `# OptionalDep(post):` | Перед `ninstall()` | Необязательные зависимости времени выполнения |

---

## Функции

Функции определяют исполняемый код. Они должны быть корректным bash.

### nbuild()

Команды сборки. Должны содержать реальный код (не только `noemptyfuncs`).

```bash
nbuild() {
    cmake -B build -G Ninja
    ninja -C build
}
```

### ninstall()

Команды установки. Должны содержать реальный код.

Файлы устанавливаются непосредственно в корень живой системы. Затем вновь установленные файлы обнаруживаются сканированием `FIND_DIRS`.

```bash
ninstall() {
    ninja -C build install
}
```

### ninstall_\<часть\>()

Команды установки для разделённого подпакета.

```bash
ninstall_dev() {
    cp -r include/* /usr/include/
}
```

### npostinstall()

Команды пост-установки (ldconfig, жёсткие ссылки и т. д.). Могут быть `noemptyfuncs`.

```bash
npostinstall() {
    ldconfig
}
```

### npostinstall_\<часть\>()

Пост-установка для разделённого подпакета.

### npostremove()

Команды пост-удаления. Могут быть `noemptyfuncs`.

```bash
npostremove() {
    rm -f /etc/ld.so.cache
}
```

### npostremove_\<часть\>()

Пост-удаление для разделённого подпакета.

### noemptyfuncs

Заглушка для необязательных функций. Предотвращает ошибки bash, когда тело функции намеренно пустое.

```bash
npostinstall() {
    noemptyfuncs
}
```

---

## Примеры

### Простой tarball-пакет

```nhoid
#%NHO-0.5
# Package Maintainer:	пользователь <пользователь@host>

# Name:	mktorrent
# Version:	1.1
# Release:	n2026
# License:	GPL-2.0-only
# Repository:	extra
# Arch:	x86_64
# Url:	https://github.com/pobrn/mktorrent
# Description:	Простая утилита командной строки для создания файлов метаданных BitTorrent.
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

### Исходный код git с разделёнными пакетами

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
# Description:	Кроссплатформенный фреймворк для приложений и пользовательских интерфейсов.
# Description_xcb_private_headers:	Приватные заголовочные файлы для Qt6 Xcb.
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
