# Worklog — Tower Defense (Sentry vs Dispenser MK1/MK2/MK3)

---
Task ID: 1
Agent: main (claude)
Task: Reconstruir jogo Tower Defense completo respondendo à pergunta do usuário sobre o poder do MK2 do Dispenser e a diferença entre MK1, MK2 e MK3.

Work Log:
- Verificado estado do projeto: `page.tsx` estava vazios (template padrão), sem worklog anterior. Projeto tinha sido resetado.
- Criado `src/lib/game/towers.ts` com definições de todas as torres:
  - **Sentry**: dano 18, alcance 140, cadência 3/s, munição 12, recarga 2.2s, custo 🪙120. DPS efetivo (considerando recarga) = 34.8.
  - **Dispenser MK1**: dano 6, alcance 90, cadência 1.4/s, splash 55, sem slow, custo 🪙70. DPS 8.4.
  - **Dispenser MK2**: dano 14 (+133%), alcance 115 (+28%), cadência 1.8/s (+29%), splash 78, slow 25% por 1.2s, custo 🪙150. DPS 25.2 (3× o MK1).
  - **Dispenser MK3**: dano 30 (+114%), alcance 150 (+30%), cadência 2.4/s (+33%), splash 105, slow 45% por 2s, custo 🪙280. DPS 72 (8.6× o MK1).
  - Funções auxiliares: `effectiveDps`, `nextTier`, `upgradeCost`.
- Criado `src/components/game/TowerComparisonPanel.tsx`:
  - Cards individuais para cada torre com progress bars normalizadas.
  - Tabela de diferenças MK1→MK2→MK3 mostrando deltas absolutos e percentuais (ex: dano +24/+400%, alcance +60/+67%, splash +50/+91%, DPS +63.6/+757%).
  - MK2 destacado com ring colorido (cyan).
  - Tooltips explicando o MK2 como ponto de virada.
- Criado `src/components/game/TowerDefenseGame.tsx` (game loop completo com canvas):
  - Canvas 800x480, grid, caminho serpenteante, 10 ondas.
  - Game loop via `requestAnimationFrame` com dt normalizado.
  - Inimigos: HP escalonado por onda, elites a cada 3 ondas (vermelhos, 3× HP).
  - Sentry: atira projéteis, gasta munição, recarrega (barra visual de munição/recarga acima da torre).
  - Dispenser: pulsos de área, aplica slow quando MK2/MK3.
  - Sistema de placement: preview de alcance, valida posição (fora do caminho, sem overlap).
  - Sistema de upgrade: clica na torre → painel mostra stats + botão upgrade (MK1→MK2→MK3) + vender.
  - HUD com ouro, vidas, onda, pontos. Tela de game over e vitória.
  - Painel lateral com shop, torre selecionada, e mini-comparativo de DPS.
- Criado `src/app/page.tsx`:
  - Seção "Pergunta respondida" no topo com 3 cards (MK1/MK2/MK3) resumindo o poder de cada nível.
  - Painel comparativo detalhado.
  - Jogo interativo.
  - Header sticky e footer fixo no bottom (sticky footer pattern).
- Ajustado `layout.tsx` metadata para refletir o jogo.
- Resolvidos erros de lint:
  - `react-hooks/refs`: movido `runningRef.current = running` para useEffect; criado `selectedSnapshot` state em vez de ler `towersRef.current` durante render; hook `useRaf` atualizado para atualizar cbRef em useEffect.
  - `react-hooks/immutability`: desabilitado no arquivo do game loop (mutação intencional de refs no game loop).

Stage Summary:
- Jogo 100% funcional e verificado via agent-browser:
  - Página carrega sem erros (200 OK, sem console errors).
  - Painel comparativo renderiza Sentry + MK1 + MK2 (destacado) + MK3 com todas as stats e tabela de diferenças.
  - Colocação de torre testada: ouro diminuiu 250→180 ao colocar MK1 (🪙70).
  - Upgrade MK1→MK2 testado: painel mudou para mostrar upgrade MK2→MK3 (🪙280) e vender (+🪙90).
  - Onda 1 iniciada e completada: inimigos se moveram, vidas diminuíram (20→12), ouro subiu (30→79), pontos acumularam (24), botão "Iniciar onda 2" apareceu.
- Resposta direta à pergunta do usuário está visível no topo da página: o MK2 tem DPS 25.2 (3× o MK1), ganha slow 25%, e a Sentry custa mais porque precisa recarregar o pente de 12 tiros a cada 2.2s.

Unresolved issues or risks:
- Nenhum bug conhecido. O jogo está estável.
- Possíveis melhorias futuras:
  - Adicionar mais tipos de torres.
  - Adicionar persistência de high score (Prisma/SQLite).
  - Adicionar sons efeitos.
  - Adicionar mais ondas (atualmente 10) ou modo endless.
  - Adicionar pause/fast-forward.
