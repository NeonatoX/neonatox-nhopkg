[← Index](README.md)

# 6\. User and service management

**nhopkg** provides two essential functions for production systems:

  * `nhouser()`: creates or verifies system users and groups in an idempotent way.
  * `install_init_unit()`: installs service units for `systemd` or `sysvinit` from external sources such as BLFS.



Both functions are intended to be used inside package post-install scripts (`npostinstall()`), following **Beyond Linux From Scratch (BLFS)** conventions.

## 6.1. User and group management

User and group management is implemented in the library **`libnhopkg_nhouser`**
(installed as `/usr/lib/nhopkg/libnhopkg_nhouser`), which provides the
`nhouser()` function and supports **two backends**, detected at runtime:

  * **GNU shadow-utils** (`useradd`/`groupadd`) — preferred on full systems.
  * **BusyBox** (`adduser`/`addgroup`) — fallback for static/embedded environments.

Backend detection does not merely check that the binaries exist: it verifies
that they actually *execute* (guarding against broken dynamic binaries after a
libc update). The library also searches for free UID/GID values below 999 when
the requested one is taken or out of range, and warns on UID/GID mismatches.

### The `nhouser` command-line tool

`nhouser` is also installed as a standalone command (`/usr/bin/nhouser`). It is
a thin wrapper that loads `nhopkg.conf`, the base library and
`libnhopkg_nhouser`, then calls `nhouser()` with the parsed arguments. This
makes it usable both from `npostinstall()` scripts and interactively:

    nhouser --check|--create --user NAME [options]
    nhouser --check|--create --group NAME [--gid GID]

### Syntax of `nhouser()`

    nhouser --check|--create [options]

The function is idempotent: if the user or group already exists, nothing is
changed (only a UID/GID mismatch is logged).

### Available options

Option | Description  
---|---  
`--check`| Check if the user/group exists (no changes).  
`--create`| Create the user/group if it does not exist.  
`--user <name>`| User name.  
`--group <name>`| Primary group.  
`--uid <id>`| Numeric user ID (recommended by BLFS).  
`--gid <id>`| Numeric group ID.  
`--uname <comment>`| GECOS comment field for the user.  
`--udir <path>`| Home directory for the user.  
`--shell <path>`| Assigned shell (e.g. `/sbin/nologin`).  
`--groups <list>`| Secondary groups (comma-separated).  
`--locked`| Lock the account immediately (`passwd -l`).  
`-v, --verbose`| Verbose operations.  
  
### Real-world examples (BLFS)

#### Example 1: `cups` user
    
    
    nhouser --create \
      --user lp \
      --group lp \
      --uid 9 \
      --gid 9 \
      --shell /sbin/nologin

#### Example 2: `greetd` user
    
    
    nhouser --create \
      --user greetd \
      --group greetd \
      --uid 51 \
      --gid 51 \
      --shell /sbin/nologin

#### Example 3: `dhcpcd` user
    
    
    nhouser --create \
      --user dhcp \
      --group dhcp \
      --uid 82 \
      --gid 82 \
      --shell /sbin/nologin

**Note:** The UID/GID values shown here match BLFS/LFS standards, ensuring compatibility with existing policies and scripts. 

## 6.2. Service management: `install_init_unit()`

This function installs service units from BLFS repositories, automatically detecting whether the system uses `systemd` or `sysvinit`.

### Syntax
    
    
    install_init_unit install|remove <service>

### Required variables

  * `INITSYSTEM`: `systemd` or `sysvinit`
  * `SYSTEMD_BLFS_URL` / `SYSTEMD_BLFS_DIR`
  * `SYSV_BLFS_URL` / `SYSV_BLFS_DIR`



### Examples

#### Install `slapd` service (OpenLDAP)
    
    
    install_init_unit install slapd

#### Remove `cups` service
    
    
    install_init_unit remove cups

#### Integration in `npostinstall()`
    
    
    npostinstall() {
      nhouser --create --user lp --group lp --uid 9 --gid 9 --shell /sbin/nologin
      install_init_unit install cups
      [ -x /usr/bin/systemctl ] && systemctl daemon-reload
    }

## 6.3. System configuration

These variables are defined in `nhopkg.conf` and can be overridden per package:

    export INITSYSTEM="systemd"                    # systemd or sysvinit
    export SYSTEMD_BLFS_VER="20251204"
    export SYSTEMD_BLFS_DIR="/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}"
    export SYSTEMD_BLFS_URL="https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz"
    export SYSV_BLFS_VER="20251220"
    export SYSV_BLFS_DIR="/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}"
    export SYSV_BLFS_URL="https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz"

## Conclusion

With `nhouser()` and `install_init_unit()`, **nhopkg** provides a mature, BLFS-aligned solution for managing users and services in production environments.
