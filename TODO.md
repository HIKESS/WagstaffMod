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

---

## Fix v2.0.2 — Persistência do reset de XP/skills (4 bugs)

**Contexto:**
O usuário reportou que o XP/insights do Wagstaff voltavam após relogar, e que ao
deletar um save e criar um novo, o XP antigo persistia (comportamento padrão do
Klei — o profile é global, não por mundo). O mecanismo de reset existente
(`wagstaff_profile_reset` flag + net_bool signal + client-side DeactivateSkill/AddSkillXP)
estava estruturalmente correto, mas falhava em 4 pontos críticos de persistência.

**Bug #1 (CRÍTICO) — Reset client-side não persistia no profile:**
O bloco client (modmain.lua:2033) fazia `DeactivateSkill` + `AddSkillXP(-xp)` para
zerar em memória, mas NÃO chamava `Profile:Save()`. Como o profile é a source-of-truth
global do DST (independente de saves de mundo), o reset era perdido no próximo reload.
**Fix:** Adicionar `Profile:Save()` no final do bloco client, dentro de pcall.

**Bug #2 (MÉDIO) — `needs_xp_reset_net` não era resetado no OnLoad:**
No `OnLoad` do world (modmain.lua:1928), os boss nets eram sincronizados, mas o
`wagstaff_needs_xp_reset_net` era esquecido. Em certos cenários de timing (client
reconecta antes do server reconstruir o world), o client recebia um `true` "órfão"
do reset anterior, causando reset duplicado em reload.
**Fix:** Setar explicitamente `wagstaff_needs_xp_reset_net:set(false)` no OnLoad.

**Bug #3 (CRÍTICO) — Flag `wagstaff_profile_reset` em `TheWorld.state` (não persiste):**
O flag era guardado em `TheWorld.state.wagstaff_profile_reset`. Campos custom em
`TheWorld.state` NÃO são persistidos automaticamente pelo engine — dependiam do
wrap `OnSave`/`OnLoad` (pattern `local old_OnSave = self.OnSave; self.OnSave = ...`),
que é frágil: se outro mod ou o engine sobrescrever `world.OnSave` depois, o wrap é
perdido e o flag volta como `nil`→`false` no reload, fazendo o reset rodar de novo.
**Fix:** Mover o flag para campo direto na entidade world (`self.wagstaff_profile_reset`
em vez de `self.state.wagstaff_profile_reset`). Campos diretos em entidades DST são
persistidos naturalmente quando retornados no `data` do OnSave. Ajustadas 8 referências.

**Bug #4 (MÉDIO) — Race condition: flag setado no FIM do DoTaskInTime:**
O flag `wagstaff_profile_reset = true` era setado na última linha do bloco
`DoTaskInTime(0)` (após todo o trabalho de reset). Se o jogador saísse do mundo
antes desse tick completar, o flag nunca era persistido e o reset rodava de novo
no próximo reload, zerando XP/skills legitimamente ganhos.
**Fix:** Setar o flag IMEDIATAMENTE no início do bloco (antes de qualquer trabalho),
garantindo que o flag persista mesmo se o trabalho abaixo falhar/interromper.

**Escopo da mudança (modmain.lua):**
- Bloco `AddPrefabPostInit("world")`: init do flag movido de `self.state` → `self`
  + OnLoad agora reseta `needs_xp_reset_net` explicitamente.
- Bloco `AddPrefabPostInit("wagstaff")` (server): flag lido/escrito no campo direto
  + setado no início do DoTaskInTime em vez do fim.
- Bloco `AddPrefabPostInit("wagstaff")` (client): adicionado `Profile:Save()` final.
- Total: ~40 linhas adicionadas/comentadas, 0 linhas funcionais removidas.

**Validação:**
- Sintaxe validada com `luac -p` (Lua 5.4.7) — OK.
- Verificado que nenhuma referência ao campo antigo (`TheWorld.state.wagstaff_profile_reset`)
  sobreviveu fora de comentários explicativos.

**Notas:**
- Branch de trabalho contínuo: `fix/xp-reset-persistence` (sem PR/merge ainda —
  acumulando correções conforme o usuário reporta).
- Esta é uma correção de persistência, não muda a lógica do mecanismo existente.
- Teste recomendado: criar mundo novo, verificar XP=0, jogar alguns dias, relogar,
  verificar que XP/skills do reload estão intactos (não zeraram de novo).