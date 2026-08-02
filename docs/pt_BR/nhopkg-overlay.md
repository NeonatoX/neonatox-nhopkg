# nhopkg-overlay — Ambiente de construção isolado

`nhopkg-overlay` fornece um **ambiente de construção isolado** montando o sistema raiz do host como um overlay com semântica copy-on-write. As construções realizadas dentro dele gravam apenas em uma camada superior temporária, de modo que o sistema host nunca é modificado.

Ele não aceita argumentos de linha de comando: execute-o e você obterá um shell dentro do ambiente isolado, com o diretório de trabalho atual disponível em `/work`.

## Justificativa

Compilar pacotes a partir do código-fonte pode modificar o sistema diretamente (veja `ninstall()` no formato nhoid). O `nhopkg-overlay` permite que mantenedores testem receitas `.srcnho` ou executem passos de construção não confiáveis sem arriscar o sistema host:

- Raiz com copy-on-write: nada gravado dentro do overlay chega ao `/` real
- Sistemas de arquivos virtuais montados por bind (`/dev`, `/proc`, `/sys`, `/run`) mantêm o ambiente funcional
- O diretório de trabalho atual é exposto em `/work`, então as fontes de construção ficam acessíveis de dentro
- Ao sair, tudo é desmontado recursivamente e `/var/lib/nhopkg-overlay/` é removido

## Estrutura

O overlay é criado em `/var/lib/nhopkg-overlay/`:

| Caminho | Função |
|---------|--------|
| `/var/lib/nhopkg-overlay/upper` | Camada superior copy-on-write (todas as mudanças vão para cá) |
| `/var/lib/nhopkg-overlay/work` | Diretório de trabalho do overlay |
| `/var/lib/nhopkg-overlay/root` | Ponto de montagem do overlay (a raiz isolada) |

É montado assim:

```
mount -t overlay overlay \
  -o lowerdir=/,upperdir=upper,workdir=work \
  root
```

Os seguintes são montados por bind dentro da raiz isolada:

- `/dev`, `/proc`, `/sys`, `/run`
- `devpts` em `/dev/pts` (para um terminal interativo)
- O diretório de trabalho atual em `/work`

## Uso

Deve ser executado como **root**:

```
sudo nhopkg-overlay
```

Você entra em um shell `chroot` na raiz do overlay, dentro de `/work`:

```
======================================
 Overlay active
 System: ISOLATED (overlay)
 Work: /work -> /home/usuario/pkg
======================================
```

Daqui você pode construir pacotes normalmente (por exemplo, `nhopkg -b foo.srcnho`). Todas as gravações vão para a camada superior e desaparecem ao sair.

## Requisitos

- Privilégios de root
- `nhopkg` instalado e disponível no `PATH`
- `mount` disponível
- Kernel com suporte a overlayfs
- Um shell em `/bin/sh` na raiz do overlay

## Limpeza

Ao sair (EXIT, INT, TERM), o `nhopkg-overlay`:

1. Mata processos que ainda usam o overlay (`fuser -km` se disponível)
2. Desmonta recursivamente a raiz do overlay e os pontos de montagem conhecidos
3. Remove `/var/lib/nhopkg-overlay/`

Se o diretório não puder ser removido porque ainda está ocupado, um aviso é exibido.

## Veja também

- [Construção de pacotes](construcao.md) — compilar pacotes `.srcnho`
- [Formato do pacote fonte](formato-nhoid.md) — campos e funções do nhoid
- [`nhopkg-src`](nhopkg-src.md) — criar pacotes fonte
