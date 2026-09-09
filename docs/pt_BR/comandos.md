# Comandos Principais — nhopkg v0.5.1

nhopkg é um gerenciador universal de pacotes binários e fonte. Esta página documenta todos os comandos e opções aceitos pelo binário `nhopkg`. Tarefas administrativas (compilação de pacotes, gerenciamento de repositórios, criação de usuários) são tratadas por ferramentas complementares referenciadas ao final.

## Referência de Comandos

| Curto | Longo | Descrição |
|-------|------|-------------|
| `-i` | `--install` | Instalar um pacote binário `.nho` local |
| `-S` | `--super-install` | Instalar um pacote de um repositório remoto |
| `-d` | `--dios` | O mesmo que `-S` / `--super-install` |
| `-b` | `--build` | Compilar e instalar um pacote fonte `.srcnho` |
| `-C` | `--super-build` | Clonar um repositório Git e compilar/instalar a partir de sua receita `nhoid` |
| `-r` | `--remove` | Remover um pacote instalado |
| | `--purge` | Remover um pacote mais todas as suas dependências inversas |
| `-B` | `--backup` | Recriar um pacote binário `.nho` a partir de um pacote já instalado |
| `-l` | `--list` | Listar todos os pacotes instalados pelo nhopkg |
| `-n` | `--info` | Mostrar informações detalhadas sobre um pacote (instalado, no repositório ou `.nho` local) |
| `-w` | `--show` | Listar todos os arquivos pertencentes a um pacote instalado |
| `-s` | `--search` | Procurar pacotes nos metadados do repositório local |
| `-t` | `--list-repo` | Listar todos os pacotes disponíveis nos repositórios configurados |
| `-k` | `--check` | Verificar a integridade de um pacote instalado (verificar se cada arquivo listado existe) |
| `-y` | `--upgrade` | Atualizar todos os pacotes instalados para a versão mais recente disponível nos repositórios |
| `-U` | `--update` | Sincronizar todos os bancos de dados de repositórios configurados (`core.packages.tar.zst`, `core.files.tar.zst`, `lastsync`) |
| `-u` | `--update-db` | Reconstruir o banco de dados local de localização de arquivos (`updatedb` / `plocate`) |
| `-x` | `--update-shooters` | Atualizar caches do sistema: esquemas GLib, cache de ícones, banco de dados de desktop, banco de dados MIME, páginas man, cache de fontes, cache de bibliotecas compartilhadas e carregadores GDK pixbuf |
| `-e` | `--clean` | Remover pacotes `.nho` em cache do diretório de download; com `-R` também limpa o diretório de compilação |
| `-X` | `--strip-binaries` | Remover símbolos de depuração de binários ELF e objetos compartilhados durante `--build` (experimental) |

## Opções (flags)

| Longo | Descrição |
|------|-------------|
| `-v`, `--verbose` | Ativar saída detalhada |
| `-p`, `--preserve-files` | Forçar a retenção dos arquivos do pacote ao removê-lo |
| `-R`, `--recursive` | Responder "sim" a todos os prompts (modo não interativo) |
| `-o`, `--output DIR` | Escrever a saída do comando (list, info, show) em um arquivo de log em DIR |
| `--root DIR` | Operar em um diretório raiz alternativo (para bootstrap, chroot ou contêineres); estado, repositórios e dependências são resolvidos dentro do destino, e ganchos pós-instalação / atualizações de cache são executados lá via chroot |
| `--no-check-deps` | Pular resolução de dependências |
| `--force-check-deps` | Forçar resolução de dependências mesmo se desabilitada na configuração |
| `--no-check-arch` | Pular validação de arquitetura |
| `--force-check-arch` | Forçar validação de arquitetura mesmo se desabilitada na configuração |
| `--no-check-sha256` | Pular verificação de soma de verificação SHA-256 |
| `--force-check-sha256` | Forçar verificação de soma de verificação mesmo se desabilitada na configuração |
| `--sign-package` | Assinar o pacote binário com GPG durante `--build` |
| `--no-sign-package` | Pular assinatura GPG |
| `--verify-package-signature` | Verificar a assinatura GPG de um pacote antes de instalá-lo |
| `--no-verify-package-signature` | Pular verificação de assinatura |
| `--license` | Exibir um aviso de licença resumido |
| `--license-all` | Exibir o texto completo da licença GPL |
| `--version` | Mostrar versão do nhopkg e direitos autorais |
| `--help` | Mostrar a página de ajuda embutida |
| `--` | Parar a interpretação de argumentos (tudo depois é tratado como nome de pacote) |

> **Nota:** As opções `--no-check-sums` e `--force-check-sums` são aliases para `--no-check-sha256` e `--force-check-sha256` respectivamente.

## Exemplos

```bash
# Instalar um pacote .nho local
sudo nhopkg -i gimp-3.0.4-n20260523.linux-x86_64.nho

# Instalar do repositório (com resolução de dependências)
sudo nhopkg -S gimp

# O mesmo que acima
sudo nhopkg --super-install gimp
sudo nhopkg -d gimp

# Compilar a partir de uma receita fonte
sudo nhopkg -b foo.srcnho

# Compilar diretamente de um repositório Git
sudo nhopkg -C foo

# Remover um pacote
sudo nhopkg -r gimp

# Remover um pacote e tudo que depende dele
sudo nhopkg --purge gimp

# Atualizar metadados do repositório
sudo nhopkg -U

# Atualizar todos os pacotes instalados
sudo nhopkg -y

# Listar pacotes instalados
nhopkg -l

# Mostrar informações detalhadas (busca repositórios, instalados ou .nho local)
nhopkg -n gimp

# Mostrar arquivos pertencentes a um pacote
nhopkg -w gimp

# Procurar por pacotes correspondentes a um padrão
nhopkg -s gimp

# Verificar integridade de um pacote instalado
sudo nhopkg -k gimp

# Limpar cache de download
sudo nhopkg -e

# Limpar cache e diretório de compilação
sudo nhopkg -e -R

# Instalar com raiz alternativa (ex. para um chroot)
sudo nhopkg -i foo.nho --root /mnt/chroot

# Ativar saída detalhada
nhopkg -v -n gimp

# Escrever saída da lista em um arquivo
nhopkg -l -o /tmp

# Remover símbolos de depuração durante a compilação
sudo nhopkg -X -b foo.srcnho

# Remover um pacote mantendo seus arquivos
sudo nhopkg -r gimp -p
```

## Modo raiz (`--root`)

`--root DIR` instala, atualiza ou remove pacotes em um **diretório raiz alternativo** em vez do sistema ativo. Útil para bootstrap de um novo sistema, chroots ou contêineres. O diretório de destino já deve existir.

- O estado do pacote (`/var/nhopkg/packages`, `files`, `repo`, `cache`) fica **dentro do destino** (`DIR/var/nhopkg`).
- Sincronização de repositórios (`--update`), resolução de dependências e verificações de conflito operam contra a raiz de destino, não contra o host.
- Os arquivos são extraídos para dentro de `DIR`.
- Ganchos `npostinstall()` e atualizações de cache (`shooter_updates`: esquemas GLib, caches de ícones/MIME/desktop, fontes, `ldconfig`) **não** são executados no host: são executados **dentro do destino** por meio de um chroot em um namespace de montagem privado que faz bind-mount de `/dev`, `/proc`, `/sys` e `/run` do host. Isso exige `/bin/sh` dentro do destino.
- Se o nhopkg ainda não estiver instalado dentro do destino, as atualizações de cache são ignoradas com um aviso; execute `nhopkg -x` uma vez dentro do destino depois.
- Arquivos `# Backup:` são lidos e restaurados dentro da raiz de destino.
- Não interativo: avisos são ignorados durante instalações de repositório.

```bash
# Instalar em um destino chroot
sudo nhopkg -i foo.nho --root /mnt/chroot

# Instalar de um repositório dentro do destino (com resolução de dependências)
sudo nhopkg -S foo --root /mnt/chroot

# Atualizar tudo dentro do destino
sudo nhopkg -y --root /mnt/chroot
```

> **Nota:** `--root` não é um wrapper completo de `chroot`. Deve ser executado como root, e o destino já deve conter os pacotes essenciais (ex.: glibc, bash, nhopkg) antes que ganchos possam ser executados dentro dele.

## Ferramentas Complementares

| Ferramenta | Propósito | Referência |
|------|---------|-----------|
| `nhopkg-src` | Assistente de criação de pacotes fonte | [`docs/pt_BR/nhopkg-src.md`](nhopkg-src.md) |
| `nhopkg-repos` | Criação e manutenção de repositórios (`--create-repo`, `--add-to-repo`) | [`docs/pt_BR/repositorios.md`](repositorios.md) |
| `nhouser` | Criação idempotente de usuários/grupos do sistema (usado em `npostinstall()`) | [`docs/pt_BR/usuarios-servicos.md`](usuarios-servicos.md) |
| `nhopkg-overlay` | Ambiente de construção isolado via overlay | [`docs/pt_BR/nhopkg-overlay.md`](nhopkg-overlay.md) |

## Veja também

- [Referência de configuração](configuracao.md)
- [Formato de pacote (nhoid)](formato-nhoid.md)
- [Grupos de pacotes](grupos.md)
- [Visão geral da arquitetura](arquitetura.md)
