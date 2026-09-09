[← Índice](README.md)

# 7\. Grupos de pacotes e meta-pacotes

**nhopkg** permite organizar pacotes em grupos lógicos usando o campo `# Group:` no arquivo `nhoid`. Grupos são metadados usados para busca e relatórios; para instalar um conjunto inteiro de pacotes de uma vez, você cria um **meta-pacote** que depende do grupo.

## Definindo um grupo

O campo `# Group:` pode aparecer mais de uma vez em um `nhoid`; um pacote pertence a todos os grupos listados.

    # Group:	graphics
    # Group:	development

## O que é um meta-pacote

Um meta-pacote é um pacote `.nho` que **não contém arquivos de aplicação**: ele apenas depende de um conjunto de pacotes que são instalados juntos. Uma vez instalado o meta-pacote, instalar e remover todo o conjunto é gerenciado normalmente pelo nhopkg; as dependências são resolvidas na instalação.

## Criando um meta-pacote

Use `nhopkg-src --init <nome> --meta`. A ferramenta pergunta pelo **grupo alvo** e escreve os nomes dos pacotes do grupo como entradas `# BuildDep:` e `# Dep(post):`:

```bash
# Criar um projeto que depende de tudo do grupo "base"
nhopkg-src --init base-meta --meta

# Empacotar
nhopkg-src --createpackage

# Compilar e instalar (resolve e instala todas as dependências)
sudo nhopkg-src --buildpackage
```

Meta-pacotes usam metadados fixos: `# License: CUSTOM`, `# Arch: any`, uma URL de projeto e a descrição `Metapackage for <nome> group.`. Nenhum tarball fonte ou URL de download é necessário.

## Instalação e remoção

Um meta-pacote é instalado e removido como qualquer outro pacote:

```bash
# Instalar um meta-pacote compilado localmente
sudo nhopkg -i base-meta-1.0-n2026.linux-any.nho

# Desinstalar sem afetar seus pacotes
sudo nhopkg -r base-meta

# Remoção completa (não existe configuração, então basta -r; --purge é opcional para uma remoção definitiva)
sudo nhopkg --purge base-meta
```

Ao remover o meta-pacote, seus pacotes **não** são removidos automaticamente.

## Documentação

Ao compilar ou instalar um meta-pacote, um `README.meta` é gerado em `/usr/share/doc/<pacote>/` (no idioma preferido do sistema quando há tradução disponível). Ele explica o propósito do meta-pacote, a lista de pacotes e como removê-lo com segurança.

## Casos de uso

Grupos e meta-pacotes são ideais para definir perfis de sistema como `base`, `desktop` ou `server`:

```bash
# Sincronizar repositórios
sudo nhopkg --update

# Listar pacotes de um grupo (buscar nos metadados)
nhopkg --search base | grep base

# Compilar e instalar o meta-pacote "base"
nhopkg-src --init base-meta --meta
nhopkg-src --createpackage
sudo nhopkg -b base-meta-1.0-n2026.srcnho
```