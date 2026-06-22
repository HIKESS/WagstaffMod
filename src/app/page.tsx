"use client";

import { TowerComparisonPanel } from "@/components/game/TowerComparisonPanel";
import { TowerDefenseGame } from "@/components/game/TowerDefenseGame";
import { Badge } from "@/components/ui/badge";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/30 backdrop-blur sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <span className="grid place-items-center w-10 h-10 rounded-lg bg-gradient-to-br from-orange-500 to-purple-500 text-xl shadow-lg">
              🛡️
            </span>
            <div>
              <h1 className="text-lg font-bold tracking-tight">
                Tower Defense — Sentry vs Dispenser
              </h1>
              <p className="text-[11px] text-muted-foreground">
                Compare o poder de MK1, MK2 e MK3 e jogue em tempo real.
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="text-[10px]">
              4 torres
            </Badge>
            <Badge variant="outline" className="text-[10px]">
              10 ondas
            </Badge>
            <Badge variant="outline" className="text-[10px]">
              Upgrades MK1→MK3
            </Badge>
          </div>
        </div>
      </header>

      {/* Conteúdo principal */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 py-6 space-y-8">
        {/* Resposta direta à pergunta: poder do MK2 e diferenças */}
        <section className="space-y-3">
          <div className="flex items-center gap-2">
            <Badge className="bg-cyan-500/15 text-cyan-500 border-cyan-500/30">
              Pergunta respondida
            </Badge>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-sm">
            <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/5 p-3">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-lg">🛢️</span>
                <span className="font-semibold">MK1 — base</span>
              </div>
              <p className="text-[12px] text-muted-foreground">
                Dano <span className="font-mono font-semibold text-foreground">6/pulso</span>,
                alcance <span className="font-mono font-semibold text-foreground">90px</span>,
                DPS <span className="font-mono font-semibold text-foreground">8.4</span>.
                Sem slow. Barato (🪙 70).
              </p>
            </div>
            <div className="rounded-lg border border-cyan-500/40 bg-cyan-500/10 p-3 ring-1 ring-cyan-500/30">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-lg">⚗️</span>
                <span className="font-semibold text-cyan-500">MK2 — destaque</span>
              </div>
              <p className="text-[12px] text-muted-foreground">
                Dano <span className="font-mono font-semibold text-foreground">14/pulso</span>{" "}
                (<span className="text-emerald-500">+133%</span>),
                alcance <span className="font-mono font-semibold text-foreground">115px</span>,
                DPS <span className="font-mono font-semibold text-foreground">25.2</span>{" "}
                (<span className="text-emerald-500">3× o MK1</span>).
                Ganha <span className="text-cyan-500 font-semibold">slow 25%</span> por 1.2s.
              </p>
            </div>
            <div className="rounded-lg border border-purple-500/30 bg-purple-500/5 p-3">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-lg">🔮</span>
                <span className="font-semibold">MK3 — topo</span>
              </div>
              <p className="text-[12px] text-muted-foreground">
                Dano <span className="font-mono font-semibold text-foreground">30/pulso</span>,
                alcance <span className="font-mono font-semibold text-foreground">150px</span>,
                DPS <span className="font-mono font-semibold text-foreground">72</span>{" "}
                (<span className="text-emerald-500">8.6× o MK1</span>).
                Slow <span className="text-purple-500 font-semibold">45%</span> por 2s.
              </p>
            </div>
          </div>
          <p className="text-xs text-muted-foreground">
            💡 A <span className="text-orange-500 font-semibold">Sentry</span> custa
            mais porque precisa <span className="font-semibold">recarregar</span> o
            pente (12 tiros a cada 2.2s) — enquanto o Dispenser dispara pulsos de
            área sem nunca precisar recarregar.
          </p>
        </section>

        {/* Painel comparativo detalhado */}
        <section>
          <TowerComparisonPanel highlight="MK2" />
        </section>

        {/* Jogo */}
        <section className="space-y-3">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div>
              <h2 className="text-lg font-semibold tracking-tight">
                Jogue e teste em tempo real
              </h2>
              <p className="text-sm text-muted-foreground">
                Construa torres, faça upgrade do Dispenser e veja o poder de
                cada nível em ação.
              </p>
            </div>
          </div>
          <TowerDefenseGame />
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-border bg-card/30 mt-auto">
        <div className="max-w-7xl mx-auto px-4 py-4 text-center text-[11px] text-muted-foreground">
          Tower Defense • Sentry (recarga) vs Dispenser (MK1→MK2→MK3) • Feito
          com Next.js + Canvas
        </div>
      </footer>
    </div>
  );
}
