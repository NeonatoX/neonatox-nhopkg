# Configuração do Nhopkg

## Precedência de Configuração

As configurações são resolvidas na seguinte ordem (fontes posteriores sobrescrevem as anteriores):

1. **Opções de linha de comando** — maior prioridade, sempre vencem
2. **Configuração do sistema** — `/etc/nhopkg/nhopkg.conf`
3. **Configuração padrão** — `/usr/share/nhopkg/nhopkg.conf` — distribuída com o pacote, menor prioridade

O arquivo usa sintaxe **bash** padrão:

- `#` para comentários
- `VAR="valor"` para atribuições
- Substituição de variáveis (ex. `${SYSCONFDIR}/nhopkg`) é suportada

---

## 1. Principal — Caminhos

Diretórios principais e caminhos base usados internamente pelo nhopkg.

| Variável | Padrão | Descrição |
|---|---|---|
| `prefix` | `@prefix@` | Prefixo de instalação (definido pelo Meson) |
| `datarootdir` | `@datarootdir@` | Diretório base de dados (Meson) |
| `SYSCONFDIR` | `@sysconfdir@` | Diretório de configuração do sistema (geralmente `/etc`) |
| `NHOPKG_SYSCONFDIR` | `${SYSCONFDIR}/nhopkg` | Diretório de configuração específico do nhopkg |
| `NHOPKG_DATADIR` | `${datarootdir}/@PACKAGE@` | Diretório de dados do nhopkg |
| `LOCALSTATEDIR` | `@localstatedir@` | Diretório de estado local (geralmente `/var`) |
| `NHOPKG_LOCALSTATEDIR` | `${LOCALSTATEDIR}/nhopkg` | Diretório de estado do nhopkg (ex. `/var/nhopkg`) |
| `TMPDIR` | `/tmp` | Diretório temporário para extração |
| `TEMPLATE_TMPDIR` | `.nhopkg.XXXXXXXXXX` | Padrão de modelo para subdiretórios temporários |
| `BUILDIR` | `/usr/src` | Diretório base de compilação de fontes |
| `NHOPKG_BUILDIR` | `${BUILDIR}/nhopkg` | Diretório de compilação do nhopkg |
| `NHOPKG_LIB` | `@prefix@/lib/nhopkg/libnhopkg` | Caminho para a biblioteca `libnhopkg` |
| `NHOPKG_LOCKFILE` | `/var/lock/nhopkg` | Arquivo de bloqueio impedindo instâncias simultâneas do nhopkg |

**Valores aceitos:** Qualquer caminho absoluto válido.

---

## 2. Opções — Comportamento

Opções gerais de comportamento para manipulação de dependências, verificação, verbosidade e funcionalidades experimentais.

| Variável | Padrão | Valores Aceitos | Descrição |
|---|---|---|---|
| `NHOPKG_CHECKDEPS` | `yes` | `yes`, `no` | Ativar verificação de dependências (obrigatórias e opcionais) |
| `NHOPKG_PURGE` | `no` | `yes`, `no` | Ativar remoção de dependências inversas ao desinstalar pacotes |
| `NHOPKG_CHECKSHA256` | `yes` | `yes`, `no` | Verificar somas de verificação SHA256 dos pacotes |
| `NHOPKG_CHECKARCH` | `yes` | `yes`, `no` | Verificar compatibilidade de arquitetura do pacote |
| `VERBOSE_MODE` | `no` | `yes`, `no` | Ativar saída detalhada |
| `STRIP_BINARIES` | `no` | `yes`, `no` | Remover símbolos de binários e bibliotecas após instalação (experimental) |
| `NHOHOLD` | `"nhopkg glibc gcc"` | Nomes de pacotes separados por espaço | Pacotes a reter — nunca excluir seus arquivos ao desinstalar |
| `NHOPKG_USE_BUSYBOX` | `no` | `yes`, `no` | Usar o PATH privado do BusyBox estático (ver [PATH privado do BusyBox](#path-privado-do-busybox)) |

### PATH privado do BusyBox

Quando `NHOPKG_USE_BUSYBOX=yes`, o nhopkg antepõe `/usr/lib/nhopkg/bin` ao
`PATH` (via `setup_busybox_path()` na `libnhopkg`). Esse diretório contém um
BusyBox **linkado estaticamente** mais os symlinks para seus applets, gerados
na instalação pelo helper **`nhopkg-bb-setup`** (instalado como
`/usr/lib/nhopkg/nhopkg-bb-setup` e invocado automaticamente como passo de
pós-instalação).

Isso é crítico para distribuições rolling: como BusyBox e zstd são linkados
estaticamente, o nhopkg continua funcionando mesmo após uma atualização da
biblioteca C (musl/glibc) que de outra forma quebraria todos os binários
dinâmicos. Os applets provisionados são: `awk`, `sed`, `grep`, `sort`, `cut`,
`tr`, `head`, `tail`, `wc`, `xargs`, `mkdir`, `cp`, `mv`, `rm`, `ln`, `ls`,
`du`, `stat`, `basename`, `dirname`, `mktemp`, `chmod`, `chown`, `tar`, `gzip`,
`gunzip`, `md5sum`, `sha1sum`, `sha256sum`, `sha512sum`, `wget`, `id`, `date`,
`sleep`, `cat`, `nproc`, `unshare`, `od`, `realpath`, `chroot`, `adduser`,
`addgroup` e `passwd`.

O helper omite qualquer applet não compilado no BusyBox instalado, limpa os
symlinks obsoletos de versões anteriores e informa quantos symlinks criou.

---

## 3. Sistema de Inicialização

Seleciona o sistema de inicialização usado pelo sistema alvo. Afeta quais arquivos ou scripts de serviço são instalados.

| Variável | Padrão | Valores Aceitos | Descrição |
|---|---|---|---|
| `INITSYSTEM` | `systemd` | `systemd`, `sysvinit` | Sistema de inicialização a usar |

---

## 4. Unidades Systemd BLFS

Configuração para arquivos de unidades systemd fornecidos pelo BLFS. Usado apenas quando `INITSYSTEM=systemd`.

| Variável | Padrão | Descrição |
|---|---|---|
| `SYSTEMD_BLFS_VER` | `20251204` | Versão do pacote de unidades systemd BLFS |
| `SYSTEMD_BLFS_DIR` | `/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}` | Diretório local para as unidades extraídas |
| `SYSTEMD_BLFS_URL` | `https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz` | URL de download |

---

## 5. Scripts SysVinit BLFS

Configuração para scripts de inicialização SysVinit BLFS. Usado apenas quando `INITSYSTEM=sysvinit`.

| Variável | Padrão | Descrição |
|---|---|---|
| `SYSV_BLFS_VER` | `20251220` | Versão do pacote de scripts de inicialização BLFS |
| `SYSV_BLFS_DIR` | `/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}` | Diretório local para os scripts extraídos |
| `SYSV_BLFS_URL` | `https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz` | URL de download |

---

## 6. Assinatura e Verificação de Pacotes

Configuração GPG para assinar e verificar pacotes binários.

| Variável | Padrão | Valores Aceitos | Descrição |
|---|---|---|---|
| `NHOPKG_TRUSTED_KEYS_DIR` | `"${NHOPKG_SYSCONFDIR}/trusted-keys/"` | Caminho de diretório válido | Diretório contendo chaves públicas confiáveis |
| `NHOPKG_SIGN_PACKAGES` | `yes` | `yes`, `no` | Assinar pacotes durante a compilação (tipicamente para mantenedores) |
| `NHOPKG_SIGN_KEY` | `"repo@neonatox.vegnux.com"` | ID de chave GPG ou email | Chave usada para assinatura |
| `NHOPKG_VERIFY_SIGNATURE` | `yes` | `yes`, `no` | Verificar assinaturas de pacotes durante a instalação |
| `NHOPKG_REQUIRE_SIGNATURE` | `no` | `yes`, `no` | Abortar instalação se a assinatura estiver ausente ou inválida |

---

## 7. Repositórios

Configuração de repositórios: quais repositórios estão ativos e onde estão localizados.

| Variável | Padrão | Descrição |
|---|---|---|
| `NHOPKG_ACTIVE_REPOS` | `"core extra multilib"` | Lista separada por espaços de nomes de repositórios ativos |
| `NHOPKG_REPO_CORE` | `@NHOPKG_REPO_CORE@` | URL para o repositório **core** (definido na configuração) |
| `NHOPKG_REPO_EXTRA` | `@NHOPKG_REPO_EXTRA@` | URL para o repositório **extra** |
| `NHOPKG_REPO_MULTILIB` | `@NHOPKG_REPO_MULTILIB@` | URL para o repositório **multilib** |

**Valores aceitos para `NHOPKG_ACTIVE_REPOS`:** Qualquer lista de nomes de repositórios em minúsculas separados por espaço (deve corresponder a uma variável `NHOPKG_REPO_*` correspondente).

URLs de repositório podem incluir múltiplos espelhos por repositório (verifique o código fonte do nhopkg para sintaxe de espelhos).

---

## 8. Fontes Git

Repositório Git padrão usado para buscar fontes para pacotes `.srcnho`.

| Variável | Padrão | Descrição |
|---|---|---|
| `NHOPKG_GIT_SOURCES` | `https://gitlab.com/neonatox-sources` | URL do repositório Git para pacotes fonte |

---

## 9. Suporte a Idiomas

Suporte a internacionalização baseado em gettext.

| Variável | Padrão | Valores Aceitos | Descrição |
|---|---|---|---|
| `NHOPKG_GETTEXT` | `yes` | `yes`, `no` | Ativar traduções gettext |
| `TEXTDOMAIN` | `@PACKAGE_NAME@` | Nome do domínio de texto | Domínio de texto gettext (não editar) |
| `TEXTDOMAINDIR` | `@localedir@` | Caminho do diretório | Diretório de locale gettext (não editar) |

---

## 10. Configuração de Compilação — Otimizações

Variáveis lidas pelo nhopkg e exportadas antes da execução de `nbuild()`. Usadas ao compilar pacotes a partir do fonte.

| Variável | Padrão | Descrição |
|---|---|---|
| `NHOPKG_MACHINE` | `sandybridge` | Alvo de otimização de CPU (ex. `sandybridge`, `native`, `generic`, `x86-64`). Se vazio ou comentado, o nhopkg usa `generic` como padrão |
| `NHOPKG_CFLAGS` | `"-O2 -pipe -march=x86-64"` | Flags base do compilador C (o alvo de máquina é anexado) |
| `NHOPKG_CXXFLAGS` | `""` (vazio) | Flags do compilador C++. Se vazio, usa `NHOPKG_CFLAGS` como padrão |
| `NHOPKG_CPPFLAGS` | `""` (vazio) | Flags do pré-processador C |
| `NHOPKG_LDFLAGS` | `"-Wl,-O1"` | Flags do linker |
| `NHOPKG_BUILD_JOBS` | `""` (vazio) | Trabalhos de compilação paralelos. Se vazio, detectado automaticamente como `nproc - 2` (mínimo 1) |
| `NHOPKG_MAKEFLAGS` | `""` (vazio) | Flags do Make. Se vazio, gerado automaticamente a partir de `NHOPKG_BUILD_JOBS` |
| `NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL` | `""` (vazio) | Nível de paralelismo do CMake. Se vazio, definido a partir de `NHOPKG_BUILD_JOBS` |

---

## 11. Criação de Pacotes Fonte

Configurações usadas ao gerar pacotes binários a partir do fonte.

| Variável | Padrão | Descrição |
|---|---|---|
| `FIND_DIRS` | `/bin /boot /etc /lib /opt /sbin /srv /usr` | Lista separada por espaço/nova linha de diretórios varridos para detectar arquivos instalados |
| `NOUPGRADE_FILES` | `mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache ${NHOPKG_BUILDIR} /etc/mtab /etc/fstab` | Lista separada por espaço/nova linha de arquivos/diretórios nunca sobrescritos em atualização |

---

## 12. Banco de Dados

Configuração do banco de dados interno de arquivos do nhopkg.

| Variável | Padrão | Descrição |
|---|---|---|
| `NHOPKG_DB` | `${NHOPKG_LOCALSTATEDIR}/nhopkg.db` | Caminho para o arquivo do banco de dados de pacotes |
| `NO_DIRS_IN_DB` | `/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var` | Lista separada por espaço/nova linha de diretórios excluídos da indexação do banco de dados |

Diretórios `NO_DIRS_IN_DB` nunca são rastreados no banco de dados de pacotes, mesmo que um pacote instale arquivos lá.

---

## Exemplo de Configuração

```bash
#====================================================================
# /etc/nhopkg/nhopkg.conf
#====================================================================

# --- Principal ---
NHOPKG_SYSCONFDIR=/etc/nhopkg
NHOPKG_LOCALSTATEDIR=/var/nhopkg
TMPDIR=/tmp
NHOPKG_BUILDIR=/usr/src/nhopkg

# --- Opções ---
NHOPKG_CHECKDEPS=yes
NHOPKG_PURGE=no
NHOPKG_CHECKSHA256=yes
NHOPKG_CHECKARCH=yes
VERBOSE_MODE=no
STRIP_BINARIES=no
NHOHOLD="nhopkg glibc gcc"
NHOPKG_USE_BUSYBOX=no

# --- Sistema de Inicialização ---
INITSYSTEM=systemd

# --- Unidades Systemd BLFS ---
SYSTEMD_BLFS_VER=20251204
SYSTEMD_BLFS_DIR=/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}
SYSTEMD_BLFS_URL=https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz

# --- Scripts SysVinit BLFS ---
SYSV_BLFS_VER=20251220
SYSV_BLFS_DIR=/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}
SYSV_BLFS_URL=https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz

# --- Assinatura de Pacotes ---
NHOPKG_TRUSTED_KEYS_DIR="${NHOPKG_SYSCONFDIR}/trusted-keys/"
NHOPKG_SIGN_PACKAGES=yes
NHOPKG_SIGN_KEY="repo@neonatox.vegnux.com"
NHOPKG_VERIFY_SIGNATURE=yes
NHOPKG_REQUIRE_SIGNATURE=no

# --- Repositórios ---
NHOPKG_ACTIVE_REPOS="core extra multilib"
NHOPKG_REPO_CORE="https://repo.neonatox.vegnux.com/core"
NHOPKG_REPO_EXTRA="https://repo.neonatox.vegnux.com/extra"
NHOPKG_REPO_MULTILIB="https://repo.neonatox.vegnux.com/multilib"

# --- Fontes Git ---
NHOPKG_GIT_SOURCES=https://gitlab.com/neonatox-sources

# --- Idioma ---
NHOPKG_GETTEXT=yes

# --- Configuração de Compilação ---
NHOPKG_MACHINE="sandybridge"
NHOPKG_CFLAGS="-O2 -pipe -march=x86-64"
NHOPKG_CXXFLAGS=""
NHOPKG_CPPFLAGS=""
NHOPKG_LDFLAGS="-Wl,-O1"
NHOPKG_BUILD_JOBS=""
NHOPKG_MAKEFLAGS=""
NHOPKG_CMAKE_BUILD_PARALLEL_LEVEL=""

# --- Criação de Pacotes Fonte ---
FIND_DIRS="/bin /boot /etc /lib /opt /sbin /srv /usr"
NOUPGRADE_FILES="mimeinfo.cache info/dir info/dir.old /etc/ld.so.cache /usr/src/nhopkg /etc/mtab /etc/fstab"

# --- Banco de Dados ---
NHOPKG_DB=/var/nhopkg/nhopkg.db
NO_DIRS_IN_DB="/dev /home /media /mnt /opt /proc /run /sys /tmp /usr/src /usr/share/zoneinfo /var"
```
