# TODO_RESEARCH_UPGRADE_MK2

## Done
- Clonar/atualizar repo `WagstaffMod`
- Clonar/atualizar repo `DontStarve-logs`
- Criar branch `blackboxai/upgrade-mk2-fix`

## Próximos passos
- [x] Checar estado do repo `DontStarve-logs` (working tree limpo, branch main).
- [ ] Identificar no código do mod onde ocorre a lógica de “upgrade”/evolução para MK II (ex.: componente/entidade/ações/stage tags).
- [ ] Ler logs do repo `DontStarve-logs` e localizar stacktrace/erros ligados ao upgrade de bots para MK2.
- [ ] Achar quais “prefabs/inst tags” distinguem MK1 vs MK2.
- [ ] Implementar correção mínima no branch.
- [ ] Commit incremental (um por mudança lógica).
- [ ] Validar carregamento/upgrade no jogo (ou pelo menos checar se o script que falha não lança erro).
