"use client";

import {
  DISPENSER_TIERS,
  SENTRY,
  type DispenserTier,
  type TowerDefinition,
  effectiveDps,
} from "@/lib/game/towers";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Separator } from "@/components/ui/separator";

const TIER_ORDER: DispenserTier[] = ["MK1", "MK2", "MK3"];

// Normaliza para 0-100 para a barra de progresso
function pct(value: number, max: number): number {
  if (max <= 0) return 0;
  return Math.min(100, Math.round((value / max) * 100));
}

function StatRow({
  label,
  value,
  max,
  format,
  hint,
}: {
  label: string;
  value: number;
  max: number;
  format: (v: number) => string;
  hint?: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between items-baseline text-xs">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-mono font-semibold tabular-nums">
          {format(value)}
        </span>
      </div>
      <Progress value={pct(value, max)} className="h-1.5" />
      {hint ? (
        <p className="text-[10px] text-muted-foreground/70">{hint}</p>
      ) : null}
    </div>
  );
}

function TowerCard({
  def,
  highlight,
  dpsMax,
  dmgMax,
  rangeMax,
  fireMax,
  splashMax,
  prev,
}: {
  def: TowerDefinition;
  highlight?: boolean;
  dpsMax: number;
  dmgMax: number;
  rangeMax: number;
  fireMax: number;
  splashMax: number;
  prev?: TowerDefinition;
}) {
  const s = def.stats;
  const dps = effectiveDps(s);
  const dpsDelta = prev ? dps - effectiveDps(prev.stats) : 0;
  const dmgDelta = prev ? s.damage - prev.stats.damage : 0;
  const rangeDelta = prev ? s.range - prev.stats.range : 0;

  return (
    <Card
      className="relative overflow-hidden transition-all"
      style={{
        borderColor: highlight ? s.color : undefined,
        boxShadow: highlight ? `0 0 0 1px ${s.color}40` : undefined,
      }}
    >
      <div
        className="h-1.5 w-full"
        style={{
          background: `linear-gradient(90deg, ${s.color}, ${s.glow})`,
        }}
      />
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span
              className="grid place-items-center w-10 h-10 rounded-lg text-xl"
              style={{
                background: `${s.color}1f`,
                border: `1px solid ${s.color}55`,
              }}
            >
              {def.icon}
            </span>
            <div>
              <CardTitle className="text-base leading-tight">
                {def.name}
              </CardTitle>
              <CardDescription className="text-[11px]">
                {def.kind === "sentry" ? "Torreta de tiro" : "Distribuidor"}
              </CardDescription>
            </div>
          </div>
          {highlight ? (
            <Badge
              variant="secondary"
              style={{ background: `${s.color}1f`, color: s.color }}
            >
              Destaque
            </Badge>
          ) : null}
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-xs text-muted-foreground min-h-[36px] leading-snug">
          {s.description}
        </p>
        <Separator />
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="rounded-md bg-muted/40 px-2 py-1.5">
            <div className="text-[10px] uppercase text-muted-foreground">
              Custo
            </div>
            <div className="font-mono font-semibold">🪙 {s.cost}</div>
          </div>
          <div className="rounded-md bg-muted/40 px-2 py-1.5">
            <div className="text-[10px] uppercase text-muted-foreground">
              DPS
            </div>
            <div className="font-mono font-semibold flex items-center gap-1">
              {dps.toFixed(1)}
              {dpsDelta > 0 ? (
                <span className="text-emerald-500 text-[10px]">
                  +{dpsDelta.toFixed(1)}
                </span>
              ) : null}
            </div>
          </div>
        </div>

        <div className="space-y-2.5">
          <StatRow
            label="Dano / pulso"
            value={s.damage}
            max={dmgMax}
            format={(v) => v.toString()}
            hint={
              dmgDelta > 0
                ? `+${dmgDelta} vs nível anterior`
                : undefined
            }
          />
          <StatRow
            label="Alcance"
            value={s.range}
            max={rangeMax}
            format={(v) => `${v}px`}
            hint={
              rangeDelta > 0
                ? `+${rangeDelta}px vs nível anterior`
                : undefined
            }
          />
          <StatRow
            label="Cadência (ataques/s)"
            value={s.fireRate}
            max={fireMax}
            format={(v) => `${v.toFixed(2)}/s`}
            hint={`Intervalo: ${(1000 / s.fireRate).toFixed(0)}ms`}
          />
          {s.splashRadius ? (
            <StatRow
              label="Raio de splash"
              value={s.splashRadius}
              max={splashMax}
              format={(v) => `${v}px`}
            />
          ) : null}
        </div>

        {def.kind === "sentry" && s.ammo && s.reloadTime ? (
          <div className="rounded-md border border-orange-500/30 bg-orange-500/5 px-2 py-1.5 space-y-1">
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">Munição (pente)</span>
              <span className="font-mono font-semibold">{s.ammo} tiros</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">Recarga</span>
              <span className="font-mono font-semibold">
                {s.reloadTime}s
              </span>
            </div>
            <p className="text-[10px] text-orange-600/80 dark:text-orange-400/80">
              ⚠ Custo operacional maior: precisa recarregar após esvaziar o
              pente.
            </p>
          </div>
        ) : null}

        {def.kind === "dispenser" && s.slowFactor ? (
          <div className="rounded-md border border-cyan-500/30 bg-cyan-500/5 px-2 py-1.5 space-y-1">
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">Lentidão</span>
              <span className="font-mono font-semibold">
                {Math.round(s.slowFactor * 100)}%
              </span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-muted-foreground">Duração</span>
              <span className="font-mono font-semibold">
                {s.slowDuration}s
              </span>
            </div>
            <p className="text-[10px] text-cyan-600/80 dark:text-cyan-400/80">
              ❄ Aplica slow aos inimigos atingidos.
            </p>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

export function TowerComparisonPanel({
  highlight = "MK2",
}: {
  highlight?: DispenserTier | null;
}) {
  const all = [SENTRY, ...TIER_ORDER.map((t) => DISPENSER_TIERS[t])];
  const dpsMax = Math.max(...all.map((d) => effectiveDps(d.stats)));
  const dmgMax = Math.max(...all.map((d) => d.stats.damage));
  const rangeMax = Math.max(...all.map((d) => d.stats.range));
  const fireMax = Math.max(...all.map((d) => d.stats.fireRate));
  const splashMax = Math.max(
    ...all.map((d) => d.stats.splashRadius ?? 0)
  );

  return (
    <TooltipProvider delayDuration={150}>
      <div className="space-y-4">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <h2 className="text-lg font-semibold tracking-tight">
              Comparativo de Torres
            </h2>
            <Badge variant="outline" className="text-[10px]">
              4 torres
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground">
            Poder e diferença entre{" "}
            <span className="font-semibold text-foreground">MK1</span>,{" "}
            <Tooltip>
              <TooltipTrigger asChild>
                <span
                  className="font-semibold underline decoration-dashed underline-offset-2"
                  style={{ color: DISPENSER_TIERS.MK2.stats.color }}
                >
                  MK2
                </span>
              </TooltipTrigger>
              <TooltipContent>
                <p className="text-xs">
                  O MK2 é o ponto de virada: ganha lentidão e dobra o dano
                  do MK1.
                </p>
              </TooltipContent>
            </Tooltip>{" "}
            e{" "}
            <span className="font-semibold text-foreground">MK3</span> do
            Dispenser — e como a Sentry se compara.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
          <TowerCard
            def={SENTRY}
            dpsMax={dpsMax}
            dmgMax={dmgMax}
            rangeMax={rangeMax}
            fireMax={fireMax}
            splashMax={splashMax}
          />
          {TIER_ORDER.map((tier, i) => (
            <TowerCard
              key={tier}
              def={DISPENSER_TIERS[tier]}
              highlight={highlight === tier}
              dpsMax={dpsMax}
              dmgMax={dmgMax}
              rangeMax={rangeMax}
              fireMax={fireMax}
              splashMax={splashMax}
              prev={i === 0 ? SENTRY : DISPENSER_TIERS[TIER_ORDER[i - 1]]}
            />
          ))}
        </div>

        {/* Tabela de diferenças MK1 -> MK2 -> MK3 */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">
              Diferença entre MK1, MK2 e MK3
            </CardTitle>
            <CardDescription className="text-xs">
              Quanto cada upgrade aumenta em relação ao nível anterior.
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-0">
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr className="text-muted-foreground border-b">
                    <th className="text-left font-medium py-2 pr-4">
                      Atributo
                    </th>
                    <th className="text-right font-medium py-2 px-2">
                      MK1
                    </th>
                    <th className="text-right font-medium py-2 px-2">
                      MK2
                    </th>
                    <th className="text-right font-medium py-2 px-2">
                      MK3
                    </th>
                    <th className="text-right font-medium py-2 pl-2 text-emerald-500">
                      MK1→MK3
                    </th>
                  </tr>
                </thead>
                <tbody className="font-mono tabular-nums">
                  <DiffRow
                    label="Dano / pulso"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.damage
                    )}
                    format={(v) => v.toString()}
                  />
                  <DiffRow
                    label="Cadência (atk/s)"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.fireRate
                    )}
                    format={(v) => v.toFixed(2)}
                  />
                  <DiffRow
                    label="Alcance (px)"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.range
                    )}
                    format={(v) => v.toString()}
                  />
                  <DiffRow
                    label="Splash (px)"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.splashRadius ?? 0
                    )}
                    format={(v) => v.toString()}
                  />
                  <DiffRow
                    label="Lentidão (%)"
                    values={TIER_ORDER.map(
                      (t) => Math.round((DISPENSER_TIERS[t].stats.slowFactor ?? 0) * 100)
                    )}
                    format={(v) => `${v}%`}
                  />
                  <DiffRow
                    label="Duração slow (s)"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.slowDuration ?? 0
                    )}
                    format={(v) => v.toFixed(1)}
                  />
                  <DiffRow
                    label="DPS"
                    values={TIER_ORDER.map((t) =>
                      effectiveDps(DISPENSER_TIERS[t].stats)
                    )}
                    format={(v) => v.toFixed(1)}
                    bold
                  />
                  <DiffRow
                    label="Custo (🪙)"
                    values={TIER_ORDER.map(
                      (t) => DISPENSER_TIERS[t].stats.cost
                    )}
                    format={(v) => v.toString()}
                    cost
                  />
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </TooltipProvider>
  );
}

function DiffRow({
  label,
  values,
  format,
  bold,
  cost,
}: {
  label: string;
  values: [number, number, number];
  format: (v: number) => string;
  bold?: boolean;
  cost?: boolean;
}) {
  const [a, b, c] = values;
  const totalDelta = c - a;
  const totalPct = a > 0 ? Math.round((totalDelta / a) * 100) : 0;

  return (
    <tr className="border-b border-muted/40 last:border-0">
      <td
        className={`py-1.5 pr-4 text-muted-foreground ${
          bold ? "font-semibold text-foreground" : ""
        }`}
      >
        {label}
      </td>
      <td className="text-right py-1.5 px-2">{format(a)}</td>
      <td
        className="text-right py-1.5 px-2"
        style={{ color: bold ? DISPENSER_TIERS.MK2.stats.color : undefined }}
      >
        {format(b)}
      </td>
      <td
        className="text-right py-1.5 px-2"
        style={{ color: bold ? DISPENSER_TIERS.MK3.stats.color : undefined }}
      >
        {format(c)}
      </td>
      <td className="text-right py-1.5 pl-2 text-emerald-500">
        {cost ? (
          <span>+{format(totalDelta)}</span>
        ) : (
          <span>
            +{format(totalDelta)}{" "}
            <span className="text-[10px] opacity-70">
              (+{totalPct}%)
            </span>
          </span>
        )}
      </td>
    </tr>
  );
}
