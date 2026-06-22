# WAGSTAFF MOD — GUIA COMPLETO DE BOTS, SENTRIES & DISPENSERS

> Dados extraidos diretamente do codigo-fonte do mod (v2.0.14, branch `GLM-5.1-Fixes`).
> Valores sujeitos a mudancas em futuras atualizacoes.

---

## MÁQUINAS / PROTOTYPERS (ESTAÇÕES DE FABRICAÇÃO)

Todas as receitas do mod sao fabricadas no menu proprio do Wagstaff (`builder_tag = "tinkerer"`) e exigem estar **proximo de uma estacao prototyper** correspondente ao nivel de Tech (ou nenhuma, no caso de `TECH.NONE`). Mapeamento dos niveis de Tech do DST para as maquinas reais:

| Tech (código) | Nível | Máquina / Prototyper |
|---------------|-------|----------------------|
| `TECH.NONE` | — | **Nenhuma** (fabricavel à mão, a qualquer momento) |
| `TECH.SCIENCE_ONE` | Science I | **Science Machine** (Máquina de Ciência) |
| `TECH.SCIENCE_TWO` | Science II | **Alchemy Engine** (Motor de Alquimia) |
| `TECH.MAGIC_ONE` | Magic I | Prestihatitator (Prestidigitador) |
| `TECH.MAGIC_TWO` | Magic II | **Shadow Manipulator** (Manipulador de Sombras) |
| `TECH.MAGIC_THREE` | Magic III | ⚠️ **Sem prototyper vanilla** — ver nota abaixo |

> ⚠️ **Nota sobre `TECH.MAGIC_THREE`:** No DST vanilla **nenhuma estação** fornece o nivel Magic III (Science Machine, Alchemy Engine, Prestihatitator e Shadow Manipulator param no nivel II). As receitas do **Ballistic Bot**, **E-Teleporter** e **E-Teleporter Exit** usam `TECH.MAGIC_THREE`, portanto **nao sao prototipaveis** em nenhuma estacao padrao. Nao foi encontrado no codigo do mod nenhum perk/skill que conceda esse tier ao Wagstaff — verifique in-game se ha desbloqueio alternativo ou se trata-se de requisito a ser ajustado pelo autor do mod.

---

## FABRICACAO BASE

### Scrap
| Custo | Quantidade | Tech | Máquina |
|-------|-----------|------|---------|
| 2 Flint + 2 Twigs | **x5** Scrap | Nenhuma | Nenhuma (à mão) |

### TF2 Wrench (chave de upgrade)
| Custo | Quantidade | Tech | Máquina |
|-------|-----------|------|---------|
| 5 Scrap + 3 Twigs | **x1** | Nenhuma | Nenhuma (à mão) |

### William Gadget (material base dos bots)
| Custo | Quantidade | Tech | Máquina |
|-------|-----------|------|---------|
| 2 Gears + 1 Gold Nugget | **x1** | Nenhuma | Nenhuma (à mão) |

---

## BOTS (William Toymaker)

---

### BUTLER BOT

**Fabricacao:** 1 William Gadget + 4 Boards + 2 Transistors *(Science One — Science Machine / Máquina de Ciência)*

| | **MK.I** | **MK.II** | **MK.III** |
|---|---|---|---|
| **HP** | 200 | 200 | 200 |
| **DMG** | 30 | 30 | 30 |
| **Fuel** | 1920s (32 min) | 1920s (32 min) | 1920s (32 min) |
| **Cook Slots** | 1 | 3 | 3 |
| **Custo Upgrade** | — | 85 Scrap (10,10,10,10,10,15) | 120 Scrap (5/hit) |
| **Skill Necessaria** | — | Butler MK.II | Butler MK.III |

**Habilidades por Tier:**

- **MK.I:** Cozinhar (1 slot), segue jogador, recarrega com relampago (+25% fuel), dano de chuva (-1/s)

- **MK.II:** 3 slots de cook + corta madeira e minera (com skill MK.II), herda tudo do MK.I

- **MK.III:** Herda MK.II + Celestial/Shadow affinity + Haunt Resurrection (revive com bonus)
  - **Celestial (dia):** Comidas curam 40% do HP baseado no valor de fome
  - **Shadow (dusk):** Comidas curam 40% da Sanidade baseado no valor de fome. MK.II pode reviver jogadores (so a noite)
  - **Haunt Resurrection (MK3):** Se assombrado, reviva com 20% HP bonus do assombrador

---

### BUSTER BOT

**Fabricacao:** 1 William Gadget + 3 Marble + 2 Transistors *(Magic Two — Shadow Manipulator / Manipulador de Sombras)*

| | **MK.I** | **MK.II** | **MK.III** |
|---|---|---|---|
| **HP** | 300 | 600 (+300) | 900 (+600) |
| **DMG** | 36 | 41 (+5) | 46 (+10) |
| **Absorcao** | 5%/nivel | 5%/nivel | 5%/nivel |
| **Fuel** | 1440s (24 min) | 1440s (24 min) | 1440s (24 min) |
| **Custo Upgrade** | — | 70 Scrap (5/hit) | 85 Scrap (5/hit) |
| **Skill Necessaria** | — | Buster MK.II | Buster MK.III |

**Habilidades por Tier:**

- **MK.I:** Segue jogador, combate corpo-a-corpo, absorcao 5% por nivel (max 3 niveis = 15%), +3 DMG/nivel (max +9), regen 5 HP/5s, recarrega com relampago

- **MK.II:** +300 HP, +5 DMG, dano em AoE, chance de stun

- **MK.III:** +600 HP total, +10 DMG total, **Explosive Punch** (30% chance: +50% dano bonus)
  - **Celestial (dia):** Explosive Punch ganha AoE com explosao de luz
  - **Shadow (dusk):** Invoca Shadow Clone (50% do dano original, invencivel, some no dia ou se Buster morre)

---

### BALLISTIC BOT

**Fabricacao:** 1 William Gadget + 4 Nitre + 2 Transistors *(Magic Three — ⚠️ sem prototyper vanilla, ver tabela de Máquinas acima)*

| | **MK.I** | **MK.II** | **MK.III** |
|---|---|---|---|
| **HP** | 150 | 400 (+250) | 400 (herda MK.II) |
| **DMG** | 16 (24/1.5) | 28 (+12) | 28 (herda MK.II) |
| **Fuel** | 3630s (60.5 min) | 3630s (60.5 min) | 3630s (60.5 min) |
| **Tipo** | Turret only | Turret only | Turret only |
| **Custo Upgrade** | — | 70 Scrap (5/hit) | 90 Scrap (5/hit) |
| **Skill Necessaria** | — | Ballistic MK.II | Ballistic MK.III |

**Habilidades por Tier:**

- **MK.I:** Deploy/undeploy (torre fixa, **nao-movel**), dano eletrico (1.5x vs mobs), para-raio, sistema de **Overcharge** (relampago = 3x DMG + 500 HP por 60s, 1x/dia, drena toda a bateria ao acabar)

- **MK.II:** +250 HP, +12 DMG, herda tudo do MK.I

- **MK.III:** Herda MK.II (mesmo HP/DMG), permanece **turret only** (o Ballistic Bot é exclusivamente uma torre fixa em **todos** os tiers — a melhoria de mobilidade está desativada no código), +:
  - **Lantern Light (so a noite):** Luz fixa ~0.6x lanterna + pulso ~3x lanterna a cada 0.5s
  - **Rain Splash:** Ataques causam splash eletrico (30% dano) + chain lightning em inimigos proximos
  - **Tempest Call:** Chuva + combate = atrai relampagos automaticamente (auto-overcharge)
  - **Auto-Recharge:** Absorve energia de para-raios e baterias Winona num raio de 6 tiles
  - **Celestial (dia):** Projeteil Brightshade (snare + dano em area) + luz protege sanidade
  - **Shadow (dusk):** Aura de medo (2-3s) em inimigos hitados + chain lightning causa panico

---

### BRUTE BOT

**Fabricacao:** 1 William Gadget + 4 Cut Stone + 2 Transistors *(Science Two — Alchemy Engine / Motor de Alquimia)*

| | **MK.I** | **MK.II** | **MK.III** |
|---|---|---|---|
| **HP** | 1500 | 2500 (+1000) | 2500 (herda MK.II*) |
| **DMG** | 17 | 27 (+10) | 27 (herda MK.II) |
| **Absorcao** | 8%/nivel | 8%/nivel | 8%/nivel |
| **Regen** | 5+5*nivel HP/5s | 5+5*nivel HP/5s | 5+5*nivel HP/5s |
| **Fuel** | 2400s (40 min) | 2400s (40 min) | 2400s (40 min) |
| **Custo Upgrade** | — | 65 Scrap (5/hit) | 40 Scrap (5/hit) |
| **Skill Necessaria** | — | Brute MK.II | Brute MK.III |

*\*MK.III spawna com HP = 2500-1000 = 1500/2500 (DoDelta negativo no spawn)*

**Habilidades por Tier:**

- **MK.I:** Segue jogador, taunt criaturas em raio de 7 tiles, absorcao 8%/nivel (max 3 = 24%), regen 5+5*nivel HP/5s, Ataques em "monster" tag

- **MK.II:** +1000 HP, +10 DMG, armazenamento (bau), segue jogador, tamanho maior, contra-ataque de fogo (30 fire dmg no atacante, sem cooldown)
  - **Celestial:** Aura de calor, quando hitado causa 25 dano de fogo em TODOS inimigos no raio de aggro
  - **Shadow:** Contra-ataque de sombra (15 shadow dmg), AOE "Void Weaken" reduz dano de inimigos em 50% por 3s no raio, atrai criaturas shadow como alvo prioritario absoluto + imune a dano planar

- **MK.III:** Herda MK.II stats + **Container (bau de armazenamento de 9 slots)**
  - **Celestial:** Mesmo do MK.II
  - **Shadow:** Mesmo do MK.II + imune a onda de pa do Bearger

---

## SENTRIES & DISPENSERS (TF2 Engineer)

---

### SENTRY GUN

**Fabricacao:** 20 Scrap + 3 Gears *(Magic Two — Shadow Manipulator / Manipulador de Sombras)*

| | **LVL 1** | **LVL 2** | **LVL 3** |
|---|---|---|---|
| **HP** | 300 | 600 (x2) | 900 (x3) |
| **DMG** | 25 | 25 | 25 |
| **Attack Range** | 12 tiles | 12 tiles | 12 tiles |
| **Fire Rate** | 1.5s | 1.5s | 1.5s |
| **Municao Max** | 100 | 200 | 300 |
| **Reload/wrench** | +5 municao | +10 municao | +15 municao |
| **Custo Upgrade** | — | 30 Scrap (1/hit) | 40 Scrap (1/hit) |
| **Skill Necessaria** | — | Sentry MK.II | Sentry MK.III |
| **Custo Total** | — | 30 Scrap (1->2) | 70 Scrap total (1->3) |

**Habilidades por Nivel:**

- **LVL 1:** Torre automatica, atira projeteis em inimigos, mira em alvos que atacam jogadores ou tem tag "hostile"/"monster"

- **LVL 2:** HP dobrado (600), municao dobrada (200), modelo atualizado

- **LVL 3:** HP triplicado (900), municao triplicada (300), **Rockets** (dispara foguetes com splash AOE: 25 dano direto + splash 3 tiles a 60% = 15 dano), **Affinity System**:
  - **Celestial (dia):** +10% dano bonus vs shadow_aligned + visao shadow (tag shadowaligned_sight)
  - **Shadow (dusk):** +10% dano bonus vs lunar_aligned
  - **x2 Damage (skill separada):** 15% chance de causar dano duplo (bonus igual ao dano base) — funciona em QUALQUER horario, MK3 only

---

### DISPENSER

**Fabricacao:** 15 Scrap + 3 Red Gems *(Science One — Science Machine / Máquina de Ciência)*

| | **LVL 1** | **LVL 2** | **LVL 3** |
|---|---|---|---|
| **Fuel max** | 4 ciclos | 6 ciclos (+50%) | 10 ciclos (+150%) |
| **Autonomia** | 4 dias (1 ciclo/dia) | 3 dias (2 ciclos/dia) | 3,3 dias (3 ciclos/dia) |
| **Custo Upgrade** | — | 30 Scrap (1/hit) | 40 Scrap (1/hit) |
| **Skill Necessaria** | — | Dispenser MK.II | Dispenser MK.III |
| **Custo Total** | — | 30 Scrap | 70 Scrap total |
| **Horarios ativos** | Dia | Dia + Dusk | Dia + Dusk + Noite |

**Output por ciclo (a cada ~5s) — v2.0.14 (Option B):**

| Recurso | LVL 1 (Dia) | LVL 2 (Dia/Dusk) | LVL 3 (Dia/Dusk/Noite) |
|---------|-------------|-------------------|------------------------|
| Scrap | 3 (flat) | 4 (flat) | 4 (flat) |
| Fuel items* | 2 | 3 | 3 |
| Mineral items* | 2 | 3 | 3 |
| Rare items* | — | — | 2 (flat, sempre) |
| Night items* | — | — | Noite: 2 (33% chance) |
| Affinity drop | — | — | Dia/Dusk: 1 (33%) — ver tabela abaixo |
| **Total/ciclo** | **7 itens** | **10 itens** | **12+ itens** |
| **Total/dia** | **7** | **20** | **36+** |

*\*Tabelas de drop ponderadas:*
- **Fuel:** Twigs (28.6%), Cut Grass (28.6%), Log (28.6%), Charcoal (14.3%)
- **Mineral:** Flint (41.7%), Rocks (41.7%), Nitre (12.5%), Marble (4.2%)
- **Night:** Light Bulb (50%), Wormlight (25%), Nightmare Fuel (25%)
- **Rare:** Gold Nugget (52.6%), Gunpowder (26.3%), Gears (15.8%), Living Log (5.3%)

**MK3 Affinity Auras (v2.0.14 — Level 2, sem bonus de afinidade dupla):**

Cada afinidade ativa apenas na sua fase (Celestial=dia, Shadow=dusk). Ter as duas afinidades simultaneamente **nao** da bonus extra — cada ciclo so dispara a afinidade da fase atual.

| Afinidade | Fase | Aura passiva | Luz | Drop ativo (33%/ciclo) |
|-----------|------|--------------|-----|------------------------|
| **Celestial** | Dia | **Sanity +100/min** (SANITYAURA_MED, era 50/min) | Forte, raio 2.5, azul-prata | **Moonglass (60%)** ou **Moon Moth (40%)** |
| **Shadow** | Dusk | **Heal 4 HP/s** (2 HP/0.5s) — **builder-only**, raio 4 | Media, raio 1.5, roxa | **Nightmare Fuel (50%)**, **Pure Horror (30%)** ou **Dark Tatters (20%)** |

*FX:* pulso de luz azul-prata durante o dia (celestial) e pulso roxo ao dusk (shadow). O ehealfx existente e reaproveitado com tint por afinidade.

---

## HABILIDADE ESPECIAL: x2 DAMAGE (Sentry)

| | |
|---|---|
| **Skill** | x2-Damage |
| **Custo de Insight** | 1 |
| **Requisito** | Sentry MK.III |
| **Efeito** | 15% de chance de causar dano duplo a cada hit da Sentry MK3 |
| **Funciona** | Qualquer horario (nao depende de Celestial/Shadow) |

---

## HABILIDADE ESPECIAL: LUCKY ENGINEER (Dispenser)

| | |
|---|---|
| **Skill** | Lucky Engineer |
| **Custo de Insight** | 1 |
| **Requisito** | Dispenser MK.III |
| **Efeito** | **20% de chance** (era 15%) de drop raro adicional por ciclo do Dispenser + **FX dourado visivel** quando ativa |
| **Funciona** | Todos os niveis e horarios (se o dispenser tem a tag) |

### TABELA DE DROP — LUCKY ENGINEER (20% chance por ciclo, v2.0.14)

| Item | Peso | **Chance %** |
|------|------|-------------|
| Gears | 25 | **25.00%** |
| Purple Gem | 18 | **18.00%** |
| Blue Gem | 15 | **15.00%** |
| Red Gem | 15 | **15.00%** |
| Thulecite | 10 | **10.00%** |
| Yellow Gem | 7 | **7.00%** |
| Orange Gem | 5 | **5.00%** |
| Green Gem | 2.5 | **2.50%** |
| Ancient Blueprint | 1.5 | **1.50%** |
| Opal Precious Gem | 1 | **1.00%** |
| **Total** | **100** | **100%** |

*Drop efetivo por ciclo = 20% (chance de trigger) x % do item acima*
*FX: pulso dourado (ehealfx com tint gold) + som `dontstarve/common/gemsparkle`*

---

## SKILL PASSIVA: MECHANICAL EFFICIENCY

| | |
|---|---|
| **Skill** | Mechanical Efficiency (root) |
| **Custo de Insight** | 1 |
| **Efeito** | 30% de chance que reparo, recarga e upgrade NAO custem scrap |
| **Aplica em** | TODOS bots, sentries e dispensers |

---

## RESUMO DE CUSTOS DE FABRICACAO

| Item | Custo | Tech | Máquina (Prototyper) |
|------|-------|------|----------------------|
| **Scrap** (x5) | 2 Flint + 2 Twigs | Nenhuma | Nenhuma (à mão) |
| **TF2 Wrench** | 5 Scrap + 3 Twigs | Nenhuma | Nenhuma (à mão) |
| **William Gadget** | 2 Gears + 1 Gold Nugget | Nenhuma | Nenhuma (à mão) |
| **Butler Bot** | 1 Gadget + 4 Boards + 2 Transistors | Science I | Science Machine |
| **Buster Bot** | 1 Gadget + 3 Marble + 2 Transistors | Magic II | Shadow Manipulator |
| **Brute Bot** | 1 Gadget + 4 Cut Stone + 2 Transistors | Science II | Alchemy Engine |
| **Ballistic Bot** | 1 Gadget + 4 Nitre + 2 Transistors | Magic III | ⚠️ Sem prototyper vanilla |
| **Sentry Gun** | 20 Scrap + 3 Gears | Magic II | Shadow Manipulator |
| **Dispenser** | 15 Scrap + 3 Red Gems | Science I | Science Machine |
| **E-Teleporter** | 30 Scrap + 5 Gears + 5 Transistors | Magic III | ⚠️ Sem prototyper vanilla |
| **E-Teleporter Exit** | 25 Scrap + 3 Gears + 3 Transistors | Magic III | ⚠️ Sem prototyper vanilla |

---

## RESUMO DE CUSTOS DE UPGRADE (SCRAP)

| Unidade | MK.I -> MK.II | MK.II -> MK.III | Custo por Hit | Metodo |
|---------|---------------|-----------------|---------------|--------|
| **Butler** | 85 | 120 | Variavel (10-15) / 5 | Wrench + Scrap |
| **Buster** | 70 | 85 | 5 | Wrench + Scrap |
| **Ballistic** | 70 | 90 | 5 | Wrench + Scrap |
| **Brute** | 65 | 40 | 5 | Wrench + Scrap |
| **Sentry** | 30 | 40 (total 70) | 1 | Wrench + Scrap |
| **Dispenser** | 30 | 40 (total 70) | 1 | Wrench + Scrap |

---

## ARVORE DE SKILLS

```
MECHANICAL (Root)
  ├── Sentry MK.II (1 insight)
  │   └── Sentry MK.III (1 insight)
  │       └── x2-Damage (1 insight)  [Sentry MK3 only, 15% double damage]
  │
  └── Dispenser MK.II (1 insight)
      └── Dispenser MK.III (1 insight)
          └── Lucky Engineer (1 insight)  [Dispenser 20% rare drop + golden FX]

ROBOTIC (Root, linear chain)
  Brute MK.II (1 insight)
  └── Brute MK.III (1 insight)
      └── Buster MK.II (1 insight)
          └── Buster MK.III (1 insight)
              └── Ballistic MK.II (1 insight)
                  └── Ballistic MK.III (1 insight)
                      └── Butler MK.II (1 insight)
                          └── Butler MK.III (1 insight)

ALLEGIANCE (Boss-locked, mutual exclusion)
  ├── [Celestial Champion kill] -> Celestial Possession (1 insight)
  └── [Ancient Fuelweaver kill] -> Shadow Possession (1 insight)
```

**Total de insights para tudo:** 6 Mechanical + 9 Robotic + 1 Allegiance = **16 insights**

---

## CHANGELOG

### v2.0.14 — Balanceamento do Dispenser (Option B) + Afinidade Level 2

**Balanceamento (Option B — rescale da curva de progressao):**
- **MK1:** fuel 4 (igual), drops flat 3 scrap / 2 fuel / 2 mineral por ciclo (era 2+33%/1/1)
- **MK2:** fuel **6** (era 4), drops flat 4 scrap / 3 fuel / 3 mineral por ciclo (era 3+33%/3/2)
- **MK3:** fuel **10** (era 8), drops 4 scrap / 3 fuel / 3 mineral / **2 rare flat** (era 2/2/2/33%-chance-1)
- Progressao corrigida: MK1→MK2 agora +186% items/dia (era +302%), MK2→MK3 +80% (era +16%)
- Autonomia alinhada: 4 → 3 → 3,3 dias (MK1→MK2→MK3)

**Afinidade Level 2 (sem bonus de afinidade dupla):**
- **Celestial (dia):** Sanity aura **+100/min** (era 50/min), luz forte azul-prata raio 2.5
- **Celestial drop ativo:** 33%/ciclo — Moonglass (60%) ou Moon Moth (40%)
- **Shadow (dusk):** Heal **4 HP/s** (era 2 HP/s), builder-only, luz media roxa raio 1.5
- **Shadow drop ativo:** 33%/ciclo — Nightmare Fuel (50%), Pure Horror (30%) ou Dark Tatters (20%)
- Ter ambas afinidades **nao** da bonus extra — cada fase so dispara sua propria afinidade

**Lucky Engineer:**
- Chance: 15% → **20%** por ciclo
- Adicionado **FX dourado visivel** (ehealfx com tint gold + som `gemsparkle`) — antes era invisivel

**Custos de upgrade e fabricacao:** mantidos (30/40 scrap, 15 scrap + 3 red gems)