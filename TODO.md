# TODO.md (blackboxai)

## Objetivo
Corrigir bug: upgrade de bots para MK2 falha em Cave Ativa devido a checagem de skills em `G.WagstaffHasSkill` retornar false quando `activatedskills`/world skills estão vazios.

## Ações planejadas
1. Confirmar branch atual e garantir que alterações só ocorram no arquivo correto (`modmain.lua`) do repo correto.
2. Aplicar patch mínimo em `G.WagstaffHasSkill` para: se `activatedskills` estiver vazio, consultar `TheWorld:GetWagstaffSkillsFromWorld()` e restaurar `activatedskills` + tag.
3. Remover quaisquer alterações não relacionadas (ex.: workspaces/untracked pastas) antes de commitar.
4. `git add modmain.lua` e commitar no branch `blackboxai/upgrade-mk2-fix`.
5. Validar rapidamente via inspeção que o patch remove abort por skill não encontrada.

## Progresso
- [x] Identificada função `G.WagstaffHasSkill` em `modmain.lua`.
- [ ] Aplicar/ajustar patch mínimo cirúrgico em `G.WagstaffHasSkill` (se necessário).
- [ ] Limpar/evitar commits de arquivos untracked (.blackbox, workspaces, pastas extra).
- [ ] Comitar no branch correto.

