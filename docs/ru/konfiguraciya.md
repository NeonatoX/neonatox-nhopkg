# Конфигурация Nhopkg

## Приоритет конфигурации

Параметры разрешаются в следующем порядке (более поздние источники переопределяют более ранние):

1. **Параметры командной строки** — наивысший приоритет, всегда побеждают
2. **Системная конфигурация** — `/etc/nhopkg/nhopkg.conf`
3. **Конфигурация по умолчанию** — `/usr/share/nhopkg/nhopkg.conf` — поставляется с пакетом, наименьший приоритет

В файле используется стандартный **синтаксис bash**:

- `#` для комментариев
- `VAR="value"` для присваиваний
- Поддерживается подстановка переменных (например, `${SYSCONFDIR}/nhopkg`)

---

## 1. Основные параметры — Пути

Основные каталоги и базовые пути, используемые nhopkg внутри.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `prefix` | `@prefix@` | Префикс установки (задаётся Meson) |
| `datarootdir` | `@datarootdir@` | Базовый каталог данных (Meson) |
| `SYSCONFDIR` | `@sysconfdir@` | Каталог системной конфигурации (обычно `/etc`) |
| `NHOPKG_SYSCONFDIR` | `${SYSCONFDIR}/nhopkg` | Каталог конфигурации, специфичный для nhopkg |
| `NHOPKG_DATADIR` | `${datarootdir}/@PACKAGE@` | Каталог данных nhopkg |
| `LOCALSTATEDIR` | `@localstatedir@` | Каталог локальных данных состояния (обычно `/var`) |
| `NHOPKG_LOCALSTATEDIR` | `${LOCALSTATEDIR}/nhopkg` | Каталог состояния nhopkg (например, `/var/nhopkg`) |
| `TMPDIR` | `/tmp` | Временный каталог для распаковки |
| `TEMPLATE_TMPDIR` | `.nhopkg.XXXXXXXXXX` | Шаблон для временных подкаталогов |
| `BUILDIR` | `/usr/src` | Базовый каталог сборки исходников |
| `NHOPKG_BUILDIR` | `${BUILDIR}/nhopkg` | Каталог сборки nhopkg |
| `NHOPKG_LIB` | `@prefix@/lib/nhopkg/libnhopkg` | Путь к библиотеке `libnhopkg` |
| `NHOPKG_LOCKFILE` | `/var/lock/nhopkg` | Файл блокировки, предотвращающий одновременные экземпляры nhopkg |

**Допустимые значения:** любой корректный абсолютный путь.

---

## 2. Параметры — Поведение

Общие параметры поведения для обработки зависимостей, проверки, подробности вывода и экспериментальных функций.

| Переменная | По умолчанию | Допустимые значения | Описание |
|---|---|---|---|
| `NHOPKG_CHECKDEPS` | `yes` | `yes`, `no` | Включить проверку зависимостей (обязательных и необязательных) |
| `NHOPKG_PURGE` | `no` | `yes`, `no` | Включить удаление обратных зависимостей при удалении пакетов |
| `NHOPKG_CHECKSHA256` | `yes` | `yes`, `no` | Проверять контрольные суммы SHA256 пакетов |
| `NHOPKG_CHECKARCH` | `yes` | `yes`, `no` | Проверять совместимость архитектуры пакета |
| `VERBOSE_MODE` | `no` | `yes`, `no` | Включить подробный вывод |
| `STRIP_BINARIES` | `no` | `yes`, `no` | Вырезать символы из бинарных файлов и библиотек после установки (экспериментально) |
| `NHOHOLD` | `"nhopkg glibc gcc"` | Список имён пакетов через пробел | Удерживаемые пакеты — никогда не удалять их файлы при удалении |
| `NHOPKG_USE_BUSYBOX` | `no` | `yes`, `no` | Использовать приватный PATH статического BusyBox (см. Приватный PATH BusyBox) |

### Приватный PATH BusyBox

Когда `NHOPKG_USE_BUSYBOX=yes`, nhopkg добавляет `/usr/lib/nhopkg/bin` в
`PATH` (через `setup_busybox_path()` в `libnhopkg`). Этот каталог содержит
**статически слинкованный** BusyBox, а также символические ссылки на его апплеты,
создаваемые во время установки вспомогательным инструментом **`nhopkg-bb-setup`**
(устанавливается в `/usr/lib/nhopkg/nhopkg-bb-setup` и вызывается автоматически
как шаг после установки).

Это критически важно для катящихся релизов: поскольку BusyBox и zstd слинкованы
статически, nhopkg продолжает работать даже при обновлении библиотеки C
(musl/glibc), которое иначе сломало бы каждый динамический бинарный файл.
Подготавливаемые апплеты: `awk`, `sed`, `grep`, `sort`, `cut`, `tr`, `head`,
`tail`, `wc`, `xargs`, `mkdir`, `cp`, `mv`, `rm`, `ln`, `ls`, `du`, `stat`,
`basename`, `dirname`, `mktemp`, `chmod`, `chown`, `tar`, `gzip`, `gunzip`,
`md5sum`, `sha1sum`, `sha256sum`, `sha512sum`, `wget`, `id`, `date`, `sleep`,
`cat`, `nproc`, `unshare`, `od`, `realpath`, `chroot`, `adduser`, `addgroup`
и `passwd`.

Хелпер пропускает все апплеты, не скомпилированные в установленный BusyBox,
очищает устаревшие символические ссылки от предыдущих версий и сообщает, сколько
символических ссылок было создано.

---

## 3. Система инициализации

Выбор системы инициализации, используемой целевой системой. Влияет на то, какие файлы служб или сценарии устанавливаются.

| Переменная | По умолчанию | Допустимые значения | Описание |
|---|---|---|---|
| `INITSYSTEM` | `systemd` | `systemd`, `sysvinit` | Используемая система инициализации |

---

## 4. BLFS Systemd Units

Конфигурация предоставляемых BLFS файлов systemd units. Используется только когда `INITSYSTEM=systemd`.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `SYSTEMD_BLFS_VER` | `20251204` | Версия пакета systemd units BLFS |
| `SYSTEMD_BLFS_DIR` | `/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}` | Локальный каталог распакованных units |
| `SYSTEMD_BLFS_URL` | `https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz` | URL загрузки |

---

## 5. Сценарии BLFS SysVinit

Конфигурация загрузочных сценариев BLFS SysVinit. Используется только когда `INITSYSTEM=sysvinit`.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `SYSV_BLFS_VER` | `20251220` | Версия пакета загрузочных сценариев BLFS |
| `SYSV_BLFS_DIR` | `/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}` | Локальный каталог распакованных сценариев |
| `SYSV_BLFS_URL` | `https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz` | URL загрузки |

---

## 6. Подпись пакетов и проверка

Конфигурация GPG для подписания и проверки бинарных пакетов.

| Переменная | По умолчанию | Допустимые значения | Описание |
|---|---|---|---|
| `NHOPKG_TRUSTED_KEYS_DIR` | `"${NHOPKG_SYSCONFDIR}/trusted-keys/"` | Корректный путь к каталогу | Каталог, содержащий доверенные публичные ключи |
| `NHOPKG_SIGN_PACKAGES` | `yes` | `yes`, `no` | Подписывать пакеты во время сборки (обычно для сопровождающих) |
| `NHOPKG_SIGN_KEY` | `"repo@neonatox.vegnux.com"` | Идентификатор ключа GPG или адрес эл. почты | Ключ, используемый для подписания |
| `NHOPKG_VERIFY_SIGNATURE` | `yes` | `yes`, `no` | Проверять подписи пакетов во время установки |
| `NHOPKG_REQUIRE_SIGNATURE` | `no` | `yes`, `no` | Прервать установку, если подпись отсутствует или недействительна |

---

## 7. Репозитории

Конфигурация репозиториев: какие репозитории активны и где они расположены.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `NHOPKG_ACTIVE_REPOS` | `"core extra multilib"` | Список имён активных репозиториев через пробел |
| `NHOPKG_REPO_CORE` | `@NHOPKG_REPO_CORE@` | URL репозитория **core** (задаётся во время конфигурации) |
| `NHOPKG_REPO_EXTRA` | `@NHOPKG_REPO_EXTRA@` | URL репозитория **extra** |
| `NHOPKG_REPO_MULTILIB` | `@NHOPKG_REPO_MULTILIB@` | URL репозитория **multilib** |

**Допустимые значения для `NHOPKG_ACTIVE_REPOS`:** любой список имён репозиториев в нижнем регистре через пробел (должны соответствовать соответствующей переменной `NHOPKG_REPO_*`).

URL репозиториев могут содержать несколько зеркал на репозиторий (синтаксис зеркал смотрите в исходниках nhopkg).

---

## 8. Git-источники

Репозиторий Git по умолчанию, используемый для получения исходников пакетов `.srcnho`.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `NHOPKG_GIT_SOURCES` | `https://gitlab.com/neonatox-sources` | URL Git-репозитория для исходных пакетов |

---

## 9. Поддержка языков

Поддержка интернационализации на основе gettext.

| Переменная | По умолчанию | Допустимые значения | Описание |
|---|---|---|---|
| `NHOPKG_GETTEXT` | `yes` | `yes`, `no` | Включить переводы gettext |
| `TEXTDOMAIN` | `@PACKAGE_NAME@` | Имя домена перевода | Домен перевода gettext (не редактировать) |
| `TEXTDOMAINDIR` | `@localedir@` | Путь к каталогу | Каталог локалей gettext (не редактировать) |

---

## 10. Конфигурация сборки — Оптимизация компиляции

Переменные, считываемые nhopkg и экспортируемые перед выполнением `nbuild()`. Используются при сборке пакетов из исходников.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `NHOPKG_MACHINE` | `generic` | Целевой уровень оптимизации CPU (например, `generic`, `sandybridge`, `native`, `x86-64`). Если пусто, nhopkg использует `generic` |
| `NHOPKG_CFLAGS` | `"-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"` | Базовые флаги компилятора C |
| `NHOPKG_CXXFLAGS` | `$NHOPKG_CFLAGS` | Флаги компилятора C++. Если пусто, по умолчанию используются `NHOPKG_CFLAGS` |
| `NHOPKG_CPPFLAGS` | `""` (пусто) | Флаги препроцессора C |
| `NHOPKG_LDFLAGS` | `"-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"` | Флаги компоновщика |
| `NHOPKG_BUILD_JOBS` | `""` (пусто) | Количество параллельных заданий сборки. Если пусто, определяется автоматически как `nproc - 2` (минимум 1) |
| `NHOPKG_MAKEFLAGS` | `""` (пусто) | Флаги make. Если пусто, автоматически формируются из `NHOPKG_BUILD_JOBS` |
| `NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL` | `""` (пусто) | Уровень параллельности CMake. Если пусто, задаётся из `NHOPKG_BUILD_JOBS` |

---

## 11. Создание исходных пакетов

Параметры, используемые при создании бинарных пакетов из исходников.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `FIND_DIRS` | `/bin /boot /etc /lib /opt /sbin /srv /usr` | Список каталогов через пробел/новую строку, сканируемых для обнаружения установленных файлов |
| `NOUPGRADE_FILES` | `mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache ${NHOPKG_BUILDIR} /etc/mtab /etc/fstab` | Список файлов/каталогов через пробел/новую строку, которые никогда не перезаписываются при обновлении |

---

## 12. База данных

Конфигурация внутренней базы данных файлов nhopkg.

| Переменная | По умолчанию | Описание |
|---|---|---|
| `NHOPKG_DB` | `${NHOPKG_LOCALSTATEDIR}/nhopkg.db` | Путь к файлу базы данных пакетов |
| `NO_DIRS_IN_DB` | `/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var` | Список каталогов через пробел/новую строку, исключаемых из индексирования базы данных |

Каталоги из `NO_DIRS_IN_DB` никогда не отслеживаются в базе данных пакетов, даже если пакет устанавливает туда файлы.

---

## Пример конфигурации

```bash
#====================================================================
# /etc/nhopkg/nhopkg.conf
#====================================================================

# --- Main ---
NHOPKG_SYSCONFDIR=/etc/nhopkg
NHOPKG_LOCALSTATEDIR=/var/nhopkg
TMPDIR=/tmp
NHOPKG_BUILDIR=/usr/src/nhopkg

# --- Options ---
NHOPKG_CHECKDEPS=yes
NHOPKG_PURGE=no
NHOPKG_CHECKSHA256=yes
NHOPKG_CHECKARCH=yes
VERBOSE_MODE=no
STRIP_BINARIES=no
NHOHOLD="nhopkg glibc gcc"
NHOPKG_USE_BUSYBOX=no

# --- Init System ---
INITSYSTEM=systemd

# --- BLFS Systemd Units ---
SYSTEMD_BLFS_VER=20251204
SYSTEMD_BLFS_DIR=/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}
SYSTEMD_BLFS_URL=https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz

# --- BLFS SysVinit Scripts ---
SYSV_BLFS_VER=20251220
SYSV_BLFS_DIR=/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}
SYSV_BLFS_URL=https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz

# --- Package Signing ---
NHOPKG_TRUSTED_KEYS_DIR="${NHOPKG_SYSCONFDIR}/trusted-keys/"
NHOPKG_SIGN_PACKAGES=yes
NHOPKG_SIGN_KEY="repo@neonatox.vegnux.com"
NHOPKG_VERIFY_SIGNATURE=yes
NHOPKG_REQUIRE_SIGNATURE=no

# --- Repositories ---
NHOPKG_ACTIVE_REPOS="core extra multilib"
NHOPKG_REPO_CORE="https://repo.neonatox.vegnux.com/core"
NHOPKG_REPO_EXTRA="https://repo.neonatox.vegnux.com/extra"
NHOPKG_REPO_MULTILIB="https://repo.neonatox.vegnux.com/multilib"

# --- Git Sources ---
NHOPKG_GIT_SOURCES=https://gitlab.com/neonatox-sources

# --- Language ---
NHOPKG_GETTEXT=yes

# --- Build Configuration ---
NHOPKG_MACHINE="generic"
NHOPKG_CFLAGS="-O2 -pipe -fstack-protector-strong -D_FORTIFY_SOURCE=3"
NHOPKG_CXXFLAGS="$NHOPKG_CFLAGS"
NHOPKG_CPPFLAGS=""
NHOPKG_LDFLAGS="-Wl,-O1 -Wl,--as-needed -Wl,-z,relro"
NHOPKG_BUILD_JOBS=""
NHOPKG_MAKEFLAGS=""
NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL=""

# --- Source Package Creation ---
FIND_DIRS="/bin /boot /etc /lib /opt /sbin /srv /usr"
NOUPGRADE_FILES="mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache /usr/src/nhopkg /etc/mtab /etc/fstab"

# --- Database ---
NHOPKG_DB=/var/nhopkg/nhopkg.db
NO_DIRS_IN_DB="/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var"
```
