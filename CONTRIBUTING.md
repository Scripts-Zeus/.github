# Padrões de desenvolvimento — Scripts Zeus

## Novo script
Crie sempre a partir do template usando o script abaixo (PowerShell, com `gh` logado numa conta owner da org):

```powershell
.\scripts\new-script.ps1 -Name az-nome-do-script -Description "Descrição curta"
```

O script cria o repositório privado a partir do `fivem-script-template`, aplica as labels, renomeia o resource e clona localmente.

## Convenções
- **Nome do repositório = nome do resource**, com prefixo `az-` e em minúsculas (ex.: `az-zombies`, `az-safezones`).
- **Standalone:** nada de `exports` ou eventos de framework fora de `bridge/`.
- **Eventos** sempre prefixados com o nome do resource: `GetCurrentResourceName() .. ':acao'`.
- **Nunca confie no client:** validar no server toda ação que dá item, dinheiro ou permissão.
- **Performance:** loops com `Wait` adequado. Nada de `Wait(0)` sem necessidade.
- **Textos** sempre via `L('chave')` e `locales/`.

## Interface (NUI)
- **Padrão visual obrigatório:** [MRI UI Kit](https://ui.mriqbox.com.br) (`@mriqbox/ui-kit`). Use os componentes, a tipografia (Saira) e os espaçamentos do kit, sem criar estilos próprios de botão, card, input etc.
- **A única coisa que muda é a cor de destaque**, vinda da convar replicada `az:color` (padrão `#E11D2A`). No código da UI use só `bg-primary`, `text-primary`, `border-primary` e `hsl(var(--primary) / N)`. **Nunca use hex fixo.**
- A versão do `@mriqbox/ui-kit` fica fixada no `package.json`. Atualize de forma deliberada, testando antes.

## Versionamento
SemVer (`MAJOR.MINOR.PATCH`). A tag `vX.Y.Z` precisa bater com o `version` do `fxmanifest.lua`, senão a release falha.
