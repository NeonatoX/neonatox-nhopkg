[← Índice](README.md)

# 6\. Gerenciamento de usuários e serviços

**nhopkg** fornece duas funções essenciais para sistemas em produção:

  * `nhouser()`: cria ou verifica usuários e grupos do sistema de forma idempotente.
  * `install_init_unit()`: instala unidades de serviço para `systemd` ou `sysvinit` a partir de fontes externas como BLFS.

Ambas as funções são projetadas para serem usadas em scripts pós-instalação de pacotes (`npostinstall()`), seguindo as convenções do **Beyond Linux From Scratch (BLFS)**.

## 6.1. Gerenciamento de usuários e grupos

O gerenciamento de usuários e grupos é implementado na biblioteca **`libnhopkg_nhouser`** (instalada em `/usr/lib/nhopkg/libnhopkg_nhouser`), que fornece a função `nhouser()` e suporta **dois backends**, detectados em tempo de execução:

  * **GNU shadow-utils** (`useradd`/`groupadd`) — preferido em sistemas completos.
  * **BusyBox** (`adduser`/`addgroup`) — alternativa para ambientes estáticos/embarcados.

A detecção de backend não se limita a verificar se os binários existem: ela confirma que eles realmente *executam* (protegendo contra binários dinâmicos quebrados após uma atualização de libc). A biblioteca também busca UID/GID livres abaixo de 999 quando o solicitado está em uso ou fora da faixa, e avisa sobre divergências de UID/GID.

### A ferramenta de linha de comando `nhouser`

`nhouser` também é instalado como um comando autônomo (`/usr/bin/nhouser`). É um wrapper que carrega `nhopkg.conf`, a biblioteca base e `libnhopkg_nhouser`, e então chama `nhouser()` com os argumentos já analisados. Isso permite usá-lo tanto em scripts `npostinstall()` quanto interativamente:

    nhouser --check|--create --user NOME [opções]
    nhouser --check|--create --group NOME [--gid GID]

### Sintaxe de `nhouser()`

    nhouser --check|--create [opções]

A função é idempotente: se o usuário ou grupo já existir, nada é alterado (apenas registra um aviso se houver divergência de UID/GID).

### Opções disponíveis

Opção | Descrição  
---|---  
`--check`| Verificar se o usuário/grupo existe (sem alterações).  
`--create`| Criar o usuário/grupo se não existir.  
`--user <nome>`| Nome do usuário.  
`--group <nome>`| Grupo primário.  
`--uid <id>`| ID numérico do usuário (recomendado pelo BLFS).  
`--gid <id>`| ID numérico do grupo.  
`--uname <comentário>`| Campo de comentário GECOS do usuário.  
`--udir <caminho>`| Diretório home do usuário.  
`--shell <caminho>`| Shell atribuído (ex.: `/sbin/nologin`).  
`--groups <lista>`| Grupos secundários (separados por vírgula).  
`--locked`| Bloquear a conta imediatamente (`passwd -l`).  
`-v, --verbose`| Operações detalhadas.  

### Exemplos reais (BLFS)

#### Exemplo 1: usuário `cups`
    
    
    nhouser --create \
      --user lp \
      --group lp \
      --uid 9 \
      --gid 9 \
      --shell /sbin/nologin

#### Exemplo 2: usuário `greetd`
    
    
    nhouser --create \
      --user greetd \
      --group greetd \
      --uid 51 \
      --gid 51 \
      --shell /sbin/nologin

#### Exemplo 3: usuário `dhcpcd`
    
    
    nhouser --create \
      --user dhcp \
      --group dhcp \
      --uid 82 \
      --gid 82 \
      --shell /sbin/nologin

**Nota:** Os valores de UID/GID mostrados aqui seguem os padrões BLFS/LFS, garantindo compatibilidade com políticas e scripts existentes.

## 6.2. Gerenciamento de serviços: `install_init_unit()`

Esta função instala unidades de serviço dos repositórios BLFS, detectando automaticamente se o sistema usa `systemd` ou `sysvinit`.

### Sintaxe
    
    
    install_init_unit install|remove <serviço>

### Variáveis necessárias

  * `INITSYSTEM`: `systemd` ou `sysvinit`
  * `SYSTEMD_BLFS_URL` / `SYSTEMD_BLFS_DIR`
  * `SYSV_BLFS_URL` / `SYSV_BLFS_DIR`

### Exemplos

#### Instalar serviço `slapd` (OpenLDAP)
    
    
    install_init_unit install slapd

#### Remover serviço `cups`
    
    
    install_init_unit remove cups

#### Integração em `npostinstall()`
    
    
    npostinstall() {
      nhouser --create --user lp --group lp --uid 9 --gid 9 --shell /sbin/nologin
      install_init_unit install cups
      [ -x /usr/bin/systemctl ] && systemctl daemon-reload
    }

## 6.3. Configuração do sistema

Essas variáveis são definidas no `nhopkg.conf` e podem ser sobrescritas por pacote:

    export INITSYSTEM="systemd"                    # systemd ou sysvinit
    export SYSTEMD_BLFS_VER="20251204"
    export SYSTEMD_BLFS_DIR="/usr/src/blfs-systemd-units-${SYSTEMD_BLFS_VER}"
    export SYSTEMD_BLFS_URL="https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-${SYSTEMD_BLFS_VER}.tar.xz"
    export SYSV_BLFS_VER="20251220"
    export SYSV_BLFS_DIR="/usr/src/blfs-bootscripts-${SYSV_BLFS_VER}"
    export SYSV_BLFS_URL="https://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-${SYSV_BLFS_VER}.tar.xz"

## Conclusão

Com `nhouser()` e `install_init_unit()`, o **nhopkg** fornece uma solução madura e alinhada ao BLFS para gerenciar usuários e serviços em ambientes de produção.

