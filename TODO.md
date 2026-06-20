# TODO.md (blackboxai) - Upgrade MK2/MK3 Fix

## Análise do Problema (Causa Raiz Final)

O bug de upgrade MK2/MK3 tem **duas causas raiz**:

### 1. SkillTreeDefs.SKILLS não populado (CORRIGIDO no commit 64b4d4c)
**Sintoma nos logs:** `Invalid SetSkillActivatedState no skill with id RPC`
**Causa:** O engine DST valida ativação de skills via `SkillTreeDefs.SKILLS[charname]`, mas o código original dizia "NOTE: Do NOT set SkillTreeDefs.SKILLS". Isso fazia o engine rejeitar TODOS os RPCs de ativação de skill do cliente.
**Correção:** Adicionar `SkillTreeDefs.SKILLS["wagstaff"] = data.SKILLS` após `CreateSkillTreeFor`.

### 2. activatedskills = nil no jogador (AINDA PERSISTE)
**Sintoma nos logs:** `activatedskills: nil` e `ALL activatedskills keys: (empty)`
**Causa:** Mesmo com RPCs funcionando, quando o jogador carrega o save:
- O `World OnLoad` restaura `self._wagstaff_activated_skills`
- Chama `apply_world_skills_to_wagstaff()` que percorre `GLOBAL.AllPlayers`
- **Mas:** o jogador (`GLOBAL.AllPlayers[1]`) pode ainda não ter `skilltreeupdater` populado neste momento
- O `DoTaskInTime(0.5)` tenta de novo mas nem sempre funciona dependendo do timing de carregamento

## Status Atual
- [x] Corrigir RPC_LOOKUP inversion bug (commit 866e307)
- [x] Corrigir SkillTreeDefs.SKILLS não populado (commit 64b4d4c)
- [x] Adicionar fallback no WagstaffHasSkill para activatedskills vazio
- [ ] **Testar em servidor dedicado** - a correção 1 sozinha pode resolver todo o problema