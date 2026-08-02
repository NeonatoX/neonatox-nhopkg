[← Документация](README.md)

# 6\. Управление пользователями и службами

**nhopkg** предоставляет две ключевые функции для производственных систем:

  * `nhouser()`: создаёт или проверяет системных пользователей и группы идемпотентным способом.
  * `install_init_unit()`: устанавливает модули служб для `systemd` или `sysvinit` из внешних источников, таких как BLFS.



Обе функции предназначены для использования внутри сценариев пост-установки пакетов (`npostinstall()`), в соответствии с соглашениями **Beyond Linux From Scratch (BLFS)**.

## 6.1. Управление пользователями и группами

Управление пользователями и группами реализовано в библиотеке **`libnhopkg_nhouser`**
(устанавливается как `/usr/lib/nhopkg/libnhopkg_nhouser`), которая предоставляет
функцию `nhouser()` и поддерживает **два бэкенда**, определяемых во время выполнения:

  * **GNU shadow-utils** (`useradd`/`groupadd`) — предпочтительно в полноценных системах.
  * **BusyBox** (`adduser`/`addgroup`) — запасной вариант для статических/встраиваемых сред.

Определение бэкенда не ограничивается проверкой существования бинарных файлов: оно
проверяет, что они действительно *выполняются* (защищая от повреждённых динамических
бинарных файлов после обновления libc). Библиотека также ищет свободные значения
UID/GID ниже 999, когда запрошенное занято или выходит за пределы диапазона, и
предупреждает о несоответствиях UID/GID.

### Инструмент командной строки `nhouser`

`nhouser` также устанавливается как отдельная команда (`/usr/bin/nhouser`). Это
тонкая обёртка, которая загружает `nhopkg.conf`, базовую библиотеку и
`libnhopkg_nhouser`, а затем вызывает `nhouser()` с разобранными аргументами. Это
делает её пригодной для использования как из сценариев `npostinstall()`, так и в
интерактивном режиме:

    nhouser --check|--create --user ИМЯ [опции]
    nhouser --check|--create --group ИМЯ [--gid GID]

### Синтаксис `nhouser()`

    nhouser --check|--create [опции]

Функция идемпотентна: если пользователь или группа уже существует, ничего не
изменяется (регистрируется только несоответствие UID/GID).

### Доступные опции

Опция | Описание  
---|---  
`--check`| Проверяет, существует ли пользователь/группа (без изменений).  
`--create`| Создаёт пользователя/группу, если он(а) не существует.  
`--user <имя>`| Имя пользователя.  
`--group <имя>`| Основная группа.  
`--uid <ид>`| Числовой идентификатор пользователя (рекомендуется BLFS).  
`--gid <ид>`| Числовой идентификатор группы.  
`--uname <комментарий>`| Поле комментария GECOS для пользователя.  
`--udir <путь>`| Домашний каталог пользователя.  
`--shell <путь>`| Назначенная оболочка (например, `/sbin/nologin`).  
`--groups <список>`| Дополнительные группы (через запятую).  
`--locked`| Немедленно заблокировать учётную запись (`passwd -l`).  
`-v, --verbose`| Подробные операции.  
  
### Примеры из реальной жизни (BLFS)

#### Пример 1: пользователь `cups`
    
    
    nhouser --create \
      --user lp \
      --group lp \
      --uid 9 \
      --gid 9 \
      --shell /sbin/nologin

#### Пример 2: пользователь `greetd`
    
    
    nhouser --create \
      --user greetd \
      --group greetd \
      --uid 51 \
      --gid 51 \
      --shell /sbin/nologin

#### Пример 3: пользователь `dhcpcd`
    
    
    nhouser --create \
      --user dhcp \
      --group dhcp \
      --uid 82 \
      --gid 82 \
      --shell /sbin/nologin

**Примечание:** Значения UID/GID, приведённые здесь, соответствуют стандартам
BLFS/LFS, что обеспечивает совместимость с существующими политиками и сценариями. 

## 6.2. Управление службами: `install_init_unit()`

Эта функция устанавливает модули служб из репозиториев BLFS, автоматически
определяя, использует ли система `systemd` или `sysvinit`.

### Синтаксис
    
    
    install_init_unit install|remove <служба>

### Требуемые переменные

  * `INITSYSTEM`: `systemd` или `sysvinit`
  * `SYSTEMD_BLFS_URL` / `SYSTEMD_BLFS_DIR`
  * `SYSV_BLFS_URL` / `SYSV_BLFS_DIR`



### Примеры

#### Установить службу `slapd` (OpenLDAP)
    
    
    install_init_unit install slapd

#### Удалить службу `cups`
    
    
    install_init_unit remove cups

#### Интеграция в `npostinstall()`
    
    
    npostinstall() {
      nhouser --create --user lp --group lp --uid 9 --gid 9 --shell /sbin/nologin
      install_init_unit install cups
      [ -x /usr/bin/systemctl ] && systemctl daemon-reload
    }

## 6.3. Конфигурация системы

Эти переменные определяются в `nhopkg.conf` и могут быть переопределены для каждого пакета:

    export INITSYSTEM="systemd"                    # systemd или sysvinit
    export BLFS_DIR="${NHOPKG_LOCALSTATEDIR}/cache/blfs"
    export SYSTEMD_BLFS_VER="20251204"
    export SYSTEMD_BLFS_DIR="${BLFS_DIR}/blfs-systemd-units-${SYSTEMD_BLFS_VER}"
    export SYSTEMD_BLFS_URL="https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz"
    export SYSV_BLFS_VER="20251220"
    export SYSV_BLFS_DIR="${BLFS_DIR}/blfs-bootscripts-${SYSV_BLFS_VER}"
    export SYSV_BLFS_URL="https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz"

## Заключение

С помощью `nhouser()` и `install_init_unit()` **nhopkg** предоставляет зрелое,
согласованное с BLFS решение для управления пользователями и службами в
производственных средах.
