// Definição das torres do Tower Defense
// - Sentry: torre de tiro que GASTA munição e precisa recarregar (por isso custa mais)
// - Dispenser: torre de área que NÃO gasta munição, mas tem cooldown entre ataques.
//   Pode fazer upgrade em 3 níveis: MK1 -> MK2 -> MK3.

export type TowerKind = "sentry" | "dispenser";
export type DispenserTier = "MK1" | "MK2" | "MK3";

export interface TowerStats {
  damage: number;       // dano por ataque
  range: number;        // alcance em pixels (no canvas)
  fireRate: number;     // ataques por segundo
  cost: number;         // custo em moedas
  ammo?: number;        // capacidade máxima de munição (sentry)
  reloadTime?: number;  // tempo (s) para recarregar (sentry)
  splashRadius?: number; // raio de splash (dispenser)
  slowFactor?: number;  // fator de lentidão aplicado ao inimigo (0-1)
  slowDuration?: number; // duração da lentidão (s)
  color: string;        // cor principal
  glow: string;         // cor de brilho
  description: string;
}

export interface TowerDefinition {
  kind: TowerKind;
  id: string;
  name: string;
  icon: string;
  stats: TowerStats;
}

// ---- SENTRY ----
// Torreta de tiro. Forte dano, mas gasta munição e precisa recarregar.
// Por causa disso, o custo operacional é maior.
export const SENTRY: TowerDefinition = {
  kind: "sentry",
  id: "sentry",
  name: "Sentry",
  icon: "🔫",
  stats: {
    damage: 18,
    range: 140,
    fireRate: 3, // 3 tiros/s
    cost: 120,
    ammo: 12,
    reloadTime: 2.2,
    color: "#f97316", // orange-500
    glow: "#fb923c",
    description:
      "Torreta de precisão. Dano alto por tiro, mas gasta munição e precisa recarregar — por isso custa mais para manter.",
  },
};

// ---- DISPENSER (Distribuidor de área) ----
// 3 níveis de upgrade: MK1 -> MK2 -> MK3.
// Sem munição, mas tem cooldown entre "pulso" de área.
export const DISPENSER_TIERS: Record<DispenserTier, TowerDefinition> = {
  MK1: {
    kind: "dispenser",
    id: "dispenser-mk1",
    name: "Dispenser MK1",
    icon: "🛢️",
    stats: {
      damage: 6,
      range: 90,
      fireRate: 1.4, // pulso a cada ~0.71s
      cost: 70,
      splashRadius: 55,
      slowFactor: 0,
      slowDuration: 0,
      color: "#22c55e", // green-500
      glow: "#4ade80",
      description:
        "Distribuidor básico de pulsos de área. Barato, dano fraco por pulso, sem efeito extra.",
    },
  },
  MK2: {
    kind: "dispenser",
    id: "dispenser-mk2",
    name: "Dispenser MK2",
    icon: "⚗️",
    stats: {
      damage: 14, // +133% vs MK1
      range: 115, // +28% vs MK1
      fireRate: 1.8, // +29% vs MK1
      cost: 150, // custo de upgrade a partir do MK1
      splashRadius: 78,
      slowFactor: 0.25, // 25% de lentidão
      slowDuration: 1.2,
      color: "#06b6d4", // cyan-500
      glow: "#22d3ee",
      description:
        "Pulsos mais fortes, mais rápidos e com maior alcance. Aplica 25% de lentidão por 1.2s.",
    },
  },
  MK3: {
    kind: "dispenser",
    id: "dispenser-mk3",
    name: "Dispenser MK3",
    icon: "🔮",
    stats: {
      damage: 30, // +114% vs MK2
      range: 150, // +30% vs MK2
      fireRate: 2.4, // +33% vs MK2
      cost: 280, // custo de upgrade a partir do MK2
      splashRadius: 105,
      slowFactor: 0.45, // 45% de lentidão
      slowDuration: 2.0,
      color: "#a855f7", // purple-500
      glow: "#c084fc",
      description:
        "Distribuidor máximo. Dano e alcance enormes, pulso rápido, 45% de lentidão por 2s.",
    },
  },
};

// DPS (dano por segundo) efetivo considerando munição/recarga para sentry,
// e cadência simples para dispenser.
export function effectiveDps(stats: TowerStats): number {
  if (stats.ammo && stats.reloadTime) {
    // tempo total para esvaziar + recarregar
    const burstTime = stats.ammo / stats.fireRate;
    const cycleTime = burstTime + stats.reloadTime;
    const damagePerCycle = stats.ammo * stats.damage;
    return damagePerCycle / cycleTime;
  }
  return stats.damage * stats.fireRate;
}

export function nextTier(tier: DispenserTier): DispenserTier | null {
  if (tier === "MK1") return "MK2";
  if (tier === "MK2") return "MK3";
  return null;
}

export function upgradeCost(from: DispenserTier): number {
  if (from === "MK1") return DISPENSER_TIERS.MK2.stats.cost;
  if (from === "MK2") return DISPENSER_TIERS.MK3.stats.cost;
  return 0;
}

export const ALL_TOWERS: TowerDefinition[] = [
  SENTRY,
  DISPENSER_TIERS.MK1,
  DISPENSER_TIERS.MK2,
  DISPENSER_TIERS.MK3,
];
