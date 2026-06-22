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

---

## Fix v2.0.1 — Crash "attempt to call global 'pcall' (a nil value)"

**Sintoma (log de crash do cliente):**
```
../mods/WagstaffMod/modmain.lua:2014: attempt to call global 'pcall' (a nil value)
LUA ERROR stack traceback:
    modmain.lua:2014 in (field) fn  <-- callback de DoTaskInTime(3, ...)
    scripts/scheduler.lua:186 OnTick
```

**Causa raiz:**
Em mods de DST, `modmain.lua` roda dentro de um sandbox environment (cópia de `_G`).
Closures passadas para `DoTaskInTime` / `ListenForEvent` / callbacks do scheduler
podem, em certos contextos de runtime, executar com um `_ENV` que NÃO expõe as
builtins padrão do Lua. Quando isso acontece, `pcall` (global direta) resolve para
`nil`, e a chamada falha.

O autor já conhecia esse problema — daí os aliases defensivos no topo do arquivo:
```lua
local pairs = G.pairs or pairs
local ipairs = G.ipairs or ipairs
local next = G.next or next
```
**Mas `pcall` (e outras builtins) foram esquecidos.** Das 9 ocorrências de `pcall`
no modmain, 5 usavam `G.pcall` (seguras) e 4 usavam `pcall` cru (vulneráveis):
linhas 1984, 2014, 2028, 2040. A linha 2014 foi a primeira atingida em runtime
(tick 1111, ~37s após o cliente conectar).

**Correção aplicada:**
Expandir o bloco de aliases defensivos para cobrir todas as builtins usadas "cruas"
no modmain: `pcall`, `xpcall`, `tostring`, `tonumber`, `type`, `select`, `print`,
`error`, `assert`, `setmetatable`, `getmetatable`, `unpack`. Cada `local X = G.X or X`
cria uma upvalue capturada no momento do load (quando o _ENV está intacto), tornando
todas as closures do arquivo imunes ao problema.

**Escopo da mudança:**
- `modmain.lua`: +19 linhas (bloco de aliases), 0 linhas removidas. As 4 ocorrências
  de `pcall` cru passam automaticamente a usar a upvalue local (shadowing de global).
- `modinfo.lua`: bump de versão `2.0.0` -> `2.0.1`.
- `scripts/prefabs/william_brute.lua`: NÃO tocado (seus `pcall` crus rodam no env do
  jogo, não no sandbox do mod, portanto não sofrem do mesmo bug).

**Notas:**
- Bug reportado pelo usuário @HIKESS em 2026-06-22 (timestamp do crash: 13:19 UTC-3).
- Game Version: 736959 (x64). World Day 1 (autumn). Client-only (ismastersim = false).
- Mod "Crash Never Mind" também habilitado — não é a causa, apenas capturou o trace.