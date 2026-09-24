[← Índice](README.md)

# 13\. Próximos passos

Embora **nhopkg v1.0** seja estável, há espaço para crescimento.

## Concluído

Os seguintes itens do roteiro já estão implementados:

| Item | Onde |
|---|---|
| Criar mais pacotes `.srcnho` | Ferramenta `nhopkg-src` (`--init`, `--createpackage`, `--buildpackage`) |
| Melhorar definições de pacotes divididos | Campos por parte `# Description_<parte>:`, `# Group_<parte>:`, `# Repository_<parte>:`, `# Backup_<parte>:` (além de `Provides_/Conflicts_/Dep_/OptionalDep_`) |
| Flags de construção reproduzível | Seção "Build Configuration — Compilation Optimizations" do `nhopkg.conf` (`NHOPKG_MACHINE`, `NHOPKG_CFLAGS`, ...) |
| Construções em ambiente isolado (sandbox) | `nhopkg-overlay` (sobreposição do diretório de construção) |
| Downloads unificados | `libnhopkg_download` / `nhoget` (GNU wget, curl, BusyBox wget, VCS) |
| Assinatura e verificação GPG | `libnhopkg_crypto`, assinatura do `nhopkg-repos`, `NHOPKG_REQUIRE_SIGNATURE` |
| Automatizar criação de repositórios | `nhopkg-repos` (`--add-to-repo`) |
| PATH privado resiliente com BusyBox | BusyBox estático em `lib/nhopkg/bin` com symlinks via `nhopkg-bb-setup` |
| Páginas man | `nhopkg.8`, `nhoget.8`, `nhopkg-repos.8`, `nhopkg-src.8`, `nhopkg-overlay.8`, `nhouser.8`, `nhopkg.conf.5` |
| Grupos de pacotes claros | Meta-pacotes via `nhopkg-src --init --meta` / `get_packages_by_group_names()` |

## Ainda no roteiro

  * Suíte de testes automatizada
  * Downloads delta

**nhopkg** é uma fundação — até onde irá depende de seus usuários.
