"use client";
/* eslint-disable react-hooks/immutability -- game loop requires mutating refs */

import { useCallback, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Progress } from "@/components/ui/progress";
import {
  SENTRY,
  DISPENSER_TIERS,
  type DispenserTier,
  type TowerDefinition,
  effectiveDps,
  nextTier,
  upgradeCost,
} from "@/lib/game/towers";

// ---------- Tipos ----------
interface Enemy {
  id: number;
  pathIndex: number;
  pos: { x: number; y: number };
  hp: number;
  maxHp: number;
  speed: number; // px/s
  slowUntil: number; // timestamp ms
  slowFactor: number;
  reward: number;
  radius: number;
  color: string;
}

interface Tower {
  id: number;
  kind: "sentry" | "dispenser";
  tier?: DispenserTier;
  pos: { x: number; y: number };
  lastShot: number;
  ammo: number; // sentry
  reloadingUntil: number; // sentry
  cooldown: number; // ms entre ataques
  stats: TowerDefinition["stats"];
}

interface Projectile {
  id: number;
  from: { x: number; y: number };
  targetId: number;
  pos: { x: number; y: number };
  speed: number;
  damage: number;
  color: string;
}

interface Pulse {
  id: number;
  pos: { x: number; y: number };
  radius: number;
  maxRadius: number;
  color: string;
  alpha: number;
  bornAt: number;
}

interface FloatingText {
  id: number;
  pos: { x: number; y: number };
  text: string;
  color: string;
  bornAt: number;
  vy: number;
}

// ---------- Constantes do jogo ----------
const WIDTH = 800;
const HEIGHT = 480;
const TILE = 40;
const START_GOLD = 250;
const START_LIVES = 20;

// Caminho (grid cells) - serpenteando o tabuleiro
const PATH_CELLS: Array<[number, number]> = [
  [0, 2],
  [4, 2],
  [4, 5],
  [9, 5],
  [9, 1],
  [13, 1],
  [13, 8],
  [18, 8],
  [18, 4],
  [20, 4],
];

function cellToPx(c: [number, number]) {
  return { x: c[0] * TILE + TILE / 2, y: c[1] * TILE + TILE / 2 };
}

const PATH_POINTS = PATH_CELLS.map(cellToPx);

// Verifica se uma posição (x,y) está longe do caminho (para permitir construir)
function isBuildable(x: number, y: number): boolean {
  for (let i = 0; i < PATH_POINTS.length - 1; i++) {
    const a = PATH_POINTS[i];
    const b = PATH_POINTS[i + 1];
    const dist = distToSegment({ x, y }, a, b);
    if (dist < TILE * 0.75) return false;
  }
  return true;
}

function distToSegment(
  p: { x: number; y: number },
  a: { x: number; y: number },
  b: { x: number; y: number }
) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const l2 = dx * dx + dy * dy;
  if (l2 === 0) return Math.hypot(p.x - a.x, p.y - a.y);
  let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

function dist(a: { x: number; y: number }, b: { x: number; y: number }) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

// ---------- Hook de animação ----------
function useRaf(callback: (dt: number, now: number) => void, active: boolean) {
  const cbRef = useRef(callback);
  useEffect(() => {
    cbRef.current = callback;
  }, [callback]);
  useEffect(() => {
    if (!active) return;
    let raf = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      cbRef.current(dt, now);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [active]);
}

type PlacementChoice = "sentry" | "dispenser-mk1" | null;

export function TowerDefenseGame() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [gold, setGold] = useState(START_GOLD);
  const [lives, setLives] = useState(START_LIVES);
  const [wave, setWave] = useState(0);
  const [score, setScore] = useState(0);
  const [running, setRunning] = useState(false);
  const [gameOver, setGameOver] = useState(false);
  const [victory, setVictory] = useState(false);
  const [choice, setChoice] = useState<PlacementChoice>(null);
  const [selectedTowerId, setSelectedTowerId] = useState<number | null>(null);
  const [waveInProgress, setWaveInProgress] = useState(false);
  const [enemiesLeft, setEnemiesLeft] = useState(0);

  // refs mutáveis (estado de jogo) — não causam re-render
  const towersRef = useRef<Tower[]>([]);
  const enemiesRef = useRef<Enemy[]>([]);
  const projectilesRef = useRef<Projectile[]>([]);
  const pulsesRef = useRef<Pulse[]>([]);
  const floatsRef = useRef<FloatingText[]>([]);
  const mouseRef = useRef<{ x: number; y: number } | null>(null);
  const idCounter = useRef(1);
  const spawnQueueRef = useRef<Array<{ at: number; enemy: Omit<Enemy, "id" | "pos" | "pathIndex"> }>>([]);
  const waveStartRef = useRef(0);
  const livesRef = useRef(START_LIVES);
  const goldRef = useRef(START_GOLD);
  const scoreRef = useRef(0);
  const runningRef = useRef(false);

  // Snapshot da torre selecionada (atualizado via state, nunca lendo ref em render)
  const [selectedSnapshot, setSelectedSnapshot] = useState<Tower | null>(null);

  useEffect(() => {
    runningRef.current = running;
  }, [running]);

  // Mantém o snapshot sincronizado periodicamente quando há torre selecionada
  useEffect(() => {
    if (selectedTowerId == null) {
      setSelectedSnapshot(null);
      return;
    }
    const refresh = () => {
      const t = towersRef.current.find((x) => x.id === selectedTowerId);
      setSelectedSnapshot(t ? { ...t, stats: { ...t.stats } } : null);
    };
    refresh();
    const id = setInterval(refresh, 200);
    return () => clearInterval(id);
  }, [selectedTowerId]);

  const selectedTower = selectedSnapshot;

  // ---------- Spawning de inimigos ----------
  const startWave = useCallback(() => {
    if (waveInProgress || gameOver) return;
    const nextWave = wave + 1;
    setWave(nextWave);
    setWaveInProgress(true);
    waveStartRef.current = performance.now();
    const count = 6 + nextWave * 2;
    const queue: typeof spawnQueueRef.current = [];
    for (let i = 0; i < count; i++) {
      const hp = 24 + nextWave * 8 + i * 2;
      const speed = 50 + nextWave * 4;
      const reward = 3 + Math.floor(nextWave / 2);
      const isElite = i === count - 1 && nextWave % 3 === 0;
      queue.push({
        at: i * 900,
        enemy: {
          hp: isElite ? hp * 3 : hp,
          maxHp: isElite ? hp * 3 : hp,
          speed: isElite ? speed * 0.7 : speed,
          slowUntil: 0,
          slowFactor: 0,
          reward: isElite ? reward * 4 : reward,
          radius: isElite ? 16 : 11,
          color: isElite ? "#ef4444" : "#eab308",
        },
      });
    }
    spawnQueueRef.current = queue;
    setEnemiesLeft(count);
    setRunning(true);
  }, [wave, waveInProgress, gameOver]);

  // ---------- Lógica de atualização ----------
  useRaf(
    (dt, now) => {
      if (!runningRef.current) return;

      // Spawn enemies
      while (
        spawnQueueRef.current.length > 0 &&
        now - waveStartRef.current >= spawnQueueRef.current[0].at
      ) {
        const item = spawnQueueRef.current.shift()!;
        enemiesRef.current.push({
          id: idCounter.current++,
          pathIndex: 0,
          pos: { ...PATH_POINTS[0] },
          ...item.enemy,
        });
      }

      // Move enemies
      for (const e of enemiesRef.current) {
        const slowed = e.slowUntil > now ? e.slowFactor : 0;
        const speed = e.speed * (1 - slowed);
        const target = PATH_POINTS[e.pathIndex + 1];
        if (!target) {
          // chegou no fim
          livesRef.current -= 1;
          setLives(livesRef.current);
          e.hp = -1; // marca para remover
          continue;
        }
        const dirx = target.x - e.pos.x;
        const diry = target.y - e.pos.y;
        const d = Math.hypot(dirx, diry);
        const step = speed * dt;
        if (d <= step) {
          e.pos = { ...target };
          e.pathIndex += 1;
        } else {
          e.pos.x += (dirx / d) * step;
          e.pos.y += (diry / d) * step;
        }
      }

      // Towers atacam
      for (const t of towersRef.current) {
        if (t.kind === "sentry") {
          // recarregando?
          if (t.reloadingUntil > now) continue;
          if (t.ammo <= 0) {
            t.reloadingUntil = now + (t.stats.reloadTime ?? 0) * 1000;
            t.ammo = t.stats.ammo ?? 0;
            continue;
          }
          if (now - t.lastShot < 1000 / t.stats.fireRate) continue;
          // acha inimigo mais próximo dentro do alcance
          let target: Enemy | null = null;
          let bestDist = Infinity;
          for (const e of enemiesRef.current) {
            if (e.hp <= 0) continue;
            const d = dist(e.pos, t.pos);
            if (d <= t.stats.range && d < bestDist) {
              bestDist = d;
              target = e;
            }
          }
          if (target) {
            t.lastShot = now;
            t.ammo -= 1;
            projectilesRef.current.push({
              id: idCounter.current++,
              from: { ...t.pos },
              targetId: target.id,
              pos: { ...t.pos },
              speed: 480,
              damage: t.stats.damage,
              color: t.stats.color,
            });
          }
        } else {
          // dispenser: pulso de área
          if (now - t.lastShot < 1000 / t.stats.fireRate) continue;
          // só dispara se houver inimigo dentro do alcance
          const hasEnemyInRange = enemiesRef.current.some(
            (e) => e.hp > 0 && dist(e.pos, t.pos) <= t.stats.range
          );
          if (!hasEnemyInRange) continue;
          t.lastShot = now;
          pulsesRef.current.push({
            id: idCounter.current++,
            pos: { ...t.pos },
            radius: 0,
            maxRadius: t.stats.splashRadius ?? t.stats.range,
            color: t.stats.color,
            alpha: 0.55,
            bornAt: now,
          });
          // aplica dano e slow
          for (const e of enemiesRef.current) {
            if (e.hp <= 0) continue;
            const d = dist(e.pos, t.pos);
            if (d <= (t.stats.splashRadius ?? t.stats.range)) {
              e.hp -= t.stats.damage;
              if (t.stats.slowFactor && t.stats.slowDuration) {
                e.slowFactor = Math.max(e.slowFactor, t.stats.slowFactor);
                e.slowUntil = Math.max(
                  e.slowUntil,
                  now + t.stats.slowDuration * 1000
                );
              }
              floatsRef.current.push({
                id: idCounter.current++,
                pos: { x: e.pos.x, y: e.pos.y - 14 },
                text: `-${t.stats.damage}`,
                color: t.stats.color,
                bornAt: now,
                vy: -30,
              });
            }
          }
        }
      }

      // Move projectiles
      for (const p of projectilesRef.current) {
        const target = enemiesRef.current.find((e) => e.id === p.targetId);
        if (!target || target.hp <= 0) {
          // remove
          p.damage = -1;
          continue;
        }
        const dx = target.pos.x - p.pos.x;
        const dy = target.pos.y - p.pos.y;
        const d = Math.hypot(dx, dy);
        const step = p.speed * dt;
        if (d <= step) {
          target.hp -= p.damage;
          floatsRef.current.push({
            id: idCounter.current++,
            pos: { x: target.pos.x, y: target.pos.y - 14 },
            text: `-${p.damage}`,
            color: p.color,
            bornAt: now,
            vy: -30,
          });
          p.damage = -1; // marca para remover
        } else {
          p.pos.x += (dx / d) * step;
          p.pos.y += (dy / d) * step;
        }
      }

      // Animate pulses
      for (const pu of pulsesRef.current) {
        const age = (now - pu.bornAt) / 1000;
        pu.radius = pu.maxRadius * Math.min(1, age * 4);
        pu.alpha = Math.max(0, 0.55 - age * 0.8);
        if (pu.alpha <= 0) pu.radius = -1;
      }

      // Animate floats
      for (const f of floatsRef.current) {
        f.pos.y += f.vy * dt;
      }

      // Remove mortos e coleta recompensa
      const survivors: Enemy[] = [];
      for (const e of enemiesRef.current) {
        if (e.hp <= 0) {
          if (e.hp > -99999) {
            // não foi o "chegou no fim"
            goldRef.current += e.reward;
            scoreRef.current += e.reward;
          }
        } else {
          survivors.push(e);
        }
      }
      enemiesRef.current = survivors;
      projectilesRef.current = projectilesRef.current.filter((p) => p.damage > 0);
      pulsesRef.current = pulsesRef.current.filter((p) => p.radius >= 0);
      floatsRef.current = floatsRef.current.filter((f) => now - f.bornAt < 800);

      // Atualiza estados UI
      if (goldRef.current !== gold) setGold(goldRef.current);
      if (scoreRef.current !== score) setScore(scoreRef.current);
      setEnemiesLeft(
        enemiesRef.current.length + spawnQueueRef.current.length
      );

      // Fim de onda
      if (
        waveInProgress &&
        enemiesRef.current.length === 0 &&
        spawnQueueRef.current.length === 0
      ) {
        setWaveInProgress(false);
        // bonus
        const bonus = 20 + wave * 5;
        goldRef.current += bonus;
        setGold(goldRef.current);
        if (wave >= 10) {
          setVictory(true);
          setRunning(false);
        }
      }

      // Game over
      if (livesRef.current <= 0 && !gameOver) {
        setGameOver(true);
        setRunning(false);
      }
    },
    true // sempre ativo para poder desenhar
  );

  // ---------- Render ----------
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    let raf = 0;
    const render = () => {
      const now = performance.now();
      // fundo
      ctx.fillStyle = "#0f1419";
      ctx.fillRect(0, 0, WIDTH, HEIGHT);

      // grid sutil
      ctx.strokeStyle = "rgba(255,255,255,0.04)";
      ctx.lineWidth = 1;
      for (let x = 0; x <= WIDTH; x += TILE) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, HEIGHT);
        ctx.stroke();
      }
      for (let y = 0; y <= HEIGHT; y += TILE) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(WIDTH, y);
        ctx.stroke();
      }

      // caminho
      ctx.strokeStyle = "rgba(250, 204, 21, 0.18)";
      ctx.lineWidth = TILE * 0.9;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.beginPath();
      PATH_POINTS.forEach((p, i) => {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.stroke();

      // linha central do caminho
      ctx.strokeStyle = "rgba(250, 204, 21, 0.45)";
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 6]);
      ctx.beginPath();
      PATH_POINTS.forEach((p, i) => {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
      });
      ctx.stroke();
      ctx.setLineDash([]);

      // towers
      for (const t of towersRef.current) {
        // base
        ctx.fillStyle = "rgba(0,0,0,0.4)";
        ctx.beginPath();
        ctx.arc(t.pos.x, t.pos.y + 3, 16, 0, Math.PI * 2);
        ctx.fill();
        // corpo
        ctx.fillStyle = t.stats.color;
        ctx.strokeStyle = t.stats.glow;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(t.pos.x, t.pos.y, 15, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        // ícone (emoji)
        ctx.font = "16px serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        const icon =
          t.kind === "sentry"
            ? SENTRY.icon
            : t.tier === "MK1"
            ? DISPENSER_TIERS.MK1.icon
            : t.tier === "MK2"
            ? DISPENSER_TIERS.MK2.icon
            : DISPENSER_TIERS.MK3.icon;
        ctx.fillText(icon, t.pos.x, t.pos.y + 1);

        // alcance se selecionada
        if (t.id === selectedTowerId) {
          ctx.strokeStyle = t.stats.glow + "aa";
          ctx.fillStyle = t.stats.color + "12";
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.arc(t.pos.x, t.pos.y, t.stats.range, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();
        }

        // indicador de munição (sentry)
        if (t.kind === "sentry") {
          const reloading = t.reloadingUntil > now;
          if (reloading) {
            const pct = 1 - (t.reloadingUntil - now) / ((t.stats.reloadTime ?? 1) * 1000);
            ctx.fillStyle = "rgba(0,0,0,0.7)";
            ctx.fillRect(t.pos.x - 16, t.pos.y - 26, 32, 5);
            ctx.fillStyle = "#f97316";
            ctx.fillRect(t.pos.x - 16, t.pos.y - 26, 32 * pct, 5);
          } else {
            ctx.fillStyle = "rgba(0,0,0,0.7)";
            ctx.fillRect(t.pos.x - 16, t.pos.y - 26, 32, 5);
            ctx.fillStyle = "#fb923c";
            const ammoPct = t.ammo / (t.stats.ammo ?? 1);
            ctx.fillRect(t.pos.x - 16, t.pos.y - 26, 32 * ammoPct, 5);
          }
        }
      }

      // pulses
      for (const pu of pulsesRef.current) {
        ctx.strokeStyle = pu.color + Math.floor(pu.alpha * 255).toString(16).padStart(2, "0");
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(pu.pos.x, pu.pos.y, pu.radius, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = pu.color + Math.floor(pu.alpha * 80).toString(16).padStart(2, "0");
        ctx.beginPath();
        ctx.arc(pu.pos.x, pu.pos.y, pu.radius, 0, Math.PI * 2);
        ctx.fill();
      }

      // inimigos
      for (const e of enemiesRef.current) {
        const slowed = e.slowUntil > now;
        // sombra
        ctx.fillStyle = "rgba(0,0,0,0.4)";
        ctx.beginPath();
        ctx.arc(e.pos.x, e.pos.y + 3, e.radius, 0, Math.PI * 2);
        ctx.fill();
        // corpo
        ctx.fillStyle = slowed ? "#67e8f9" : e.color;
        ctx.strokeStyle = "rgba(255,255,255,0.5)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(e.pos.x, e.pos.y, e.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        // hp bar
        const w = e.radius * 2.4;
        ctx.fillStyle = "rgba(0,0,0,0.7)";
        ctx.fillRect(e.pos.x - w / 2, e.pos.y - e.radius - 8, w, 4);
        ctx.fillStyle = "#22c55e";
        ctx.fillRect(e.pos.x - w / 2, e.pos.y - e.radius - 8, w * (e.hp / e.maxHp), 4);
      }

      // projéteis
      for (const p of projectilesRef.current) {
        ctx.fillStyle = p.color;
        ctx.shadowColor = p.color;
        ctx.shadowBlur = 6;
        ctx.beginPath();
        ctx.arc(p.pos.x, p.pos.y, 3.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0;
      }

      // floats
      for (const f of floatsRef.current) {
        const age = (now - f.bornAt) / 800;
        ctx.globalAlpha = 1 - age;
        ctx.fillStyle = f.color;
        ctx.font = "bold 12px monospace";
        ctx.textAlign = "center";
        ctx.fillText(f.text, f.pos.x, f.pos.y);
        ctx.globalAlpha = 1;
      }

      // preview de placement
      if (choice && mouseRef.current) {
        const def =
          choice === "sentry" ? SENTRY : DISPENSER_TIERS.MK1;
        const buildable =
          isBuildable(mouseRef.current.x, mouseRef.current.y) &&
          goldRef.current >= def.stats.cost;
        ctx.strokeStyle = buildable ? def.stats.glow : "#ef4444";
        ctx.fillStyle = (buildable ? def.stats.color : "#ef4444") + "20";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(
          mouseRef.current.x,
          mouseRef.current.y,
          def.stats.range,
          0,
          Math.PI * 2
        );
        ctx.fill();
        ctx.stroke();
        ctx.fillStyle = (buildable ? def.stats.color : "#ef4444") + "aa";
        ctx.beginPath();
        ctx.arc(mouseRef.current.x, mouseRef.current.y, 15, 0, Math.PI * 2);
        ctx.fill();
      }

      raf = requestAnimationFrame(render);
    };
    raf = requestAnimationFrame(render);
    return () => cancelAnimationFrame(raf);
  }, [choice, selectedTowerId]);

  // ---------- Handlers ----------
  const handleCanvasMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const sx = WIDTH / rect.width;
    const sy = HEIGHT / rect.height;
    mouseRef.current = {
      x: (e.clientX - rect.left) * sx,
      y: (e.clientY - rect.top) * sy,
    };
  };

  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const sx = WIDTH / rect.width;
    const sy = HEIGHT / rect.height;
    const x = (e.clientX - rect.left) * sx;
    const y = (e.clientY - rect.top) * sy;

    // se tem choice, tenta colocar
    if (choice) {
      const def = choice === "sentry" ? SENTRY : DISPENSER_TIERS.MK1;
      if (!isBuildable(x, y)) return;
      if (goldRef.current < def.stats.cost) return;
      // não pode encostar em outra torre
      for (const t of towersRef.current) {
        if (dist(t.pos, { x, y }) < 30) return;
      }
      goldRef.current -= def.stats.cost;
      setGold(goldRef.current);
      const newTower: Tower = {
        id: idCounter.current++,
        kind: def.kind,
        tier: def.kind === "dispenser" ? "MK1" : undefined,
        pos: { x, y },
        lastShot: 0,
        ammo: def.stats.ammo ?? 0,
        reloadingUntil: 0,
        cooldown: 1000 / def.stats.fireRate,
        stats: { ...def.stats },
      };
      towersRef.current.push(newTower);
      setChoice(null);
      return;
    }

    // senão, seleciona torre existente
    let found: Tower | null = null;
    for (const t of towersRef.current) {
      if (dist(t.pos, { x, y }) <= 18) {
        found = t;
        break;
      }
    }
    setSelectedTowerId(found ? found.id : null);
  };

  const handleUpgrade = () => {
    if (!selectedTower || selectedTower.kind !== "dispenser" || !selectedTower.tier) return;
    const nt = nextTier(selectedTower.tier);
    if (!nt) return;
    const cost = upgradeCost(selectedTower.tier);
    if (goldRef.current < cost) return;
    goldRef.current -= cost;
    setGold(goldRef.current);
    const actual = towersRef.current.find((t) => t.id === selectedTower.id);
    if (actual) {
      actual.tier = nt;
      actual.stats = { ...DISPENSER_TIERS[nt].stats };
      actual.cooldown = 1000 / actual.stats.fireRate;
      setSelectedSnapshot({ ...actual, stats: { ...actual.stats } });
    }
  };

  const handleSell = () => {
    if (!selectedTower) return;
    const refund = Math.floor(selectedTower.stats.cost * 0.6);
    goldRef.current += refund;
    setGold(goldRef.current);
    towersRef.current = towersRef.current.filter(
      (t) => t.id !== selectedTower.id
    );
    setSelectedTowerId(null);
    setSelectedSnapshot(null);
  };

  const resetGame = () => {
    towersRef.current = [];
    enemiesRef.current = [];
    projectilesRef.current = [];
    pulsesRef.current = [];
    floatsRef.current = [];
    spawnQueueRef.current = [];
    livesRef.current = START_LIVES;
    goldRef.current = START_GOLD;
    scoreRef.current = 0;
    setLives(START_LIVES);
    setGold(START_GOLD);
    setScore(0);
    setWave(0);
    setWaveInProgress(false);
    setGameOver(false);
    setVictory(false);
    setSelectedTowerId(null);
    setSelectedSnapshot(null);
    setChoice(null);
    setRunning(false);
  };

  const sentryDps = effectiveDps(SENTRY.stats);
  const mk1Dps = effectiveDps(DISPENSER_TIERS.MK1.stats);
  const mk2Dps = effectiveDps(DISPENSER_TIERS.MK2.stats);
  const mk3Dps = effectiveDps(DISPENSER_TIERS.MK3.stats);

  const upgradeTarget = selectedTower?.tier ? nextTier(selectedTower.tier) : null;
  const upgradeCostValue = selectedTower?.tier ? upgradeCost(selectedTower.tier) : 0;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-4">
      {/* Coluna do jogo */}
      <div className="space-y-3">
        {/* HUD */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          <HudStat label="Ouro" value={`🪙 ${gold}`} accent="#facc15" />
          <HudStat label="Vidas" value={`❤️ ${lives}`} accent="#ef4444" />
          <HudStat label="Onda" value={`🌊 ${wave}/10`} accent="#38bdf8" />
          <HudStat label="Pontos" value={`⭐ ${score}`} accent="#a855f7" />
        </div>

        {/* Canvas */}
        <div className="relative rounded-xl overflow-hidden border border-border bg-[#0f1419]">
          <canvas
            ref={canvasRef}
            width={WIDTH}
            height={HEIGHT}
            className="w-full h-auto block cursor-crosshair"
            style={{ aspectRatio: `${WIDTH}/${HEIGHT}` }}
            onMouseMove={handleCanvasMove}
            onMouseLeave={() => (mouseRef.current = null)}
            onClick={handleCanvasClick}
          />
          {(gameOver || victory) && (
            <div className="absolute inset-0 grid place-items-center bg-black/70 backdrop-blur-sm">
              <div className="text-center space-y-3">
                <div className="text-3xl font-bold">
                  {victory ? "🏆 Vitória!" : "💀 Game Over"}
                </div>
                <p className="text-muted-foreground text-sm">
                  {victory
                    ? "Você defendeu até a onda 10!"
                    : `Você chegou até a onda ${wave}`}
                </p>
                <Button onClick={resetGame} variant="secondary">
                  Jogar novamente
                </Button>
              </div>
            </div>
          )}
        </div>

        {/* Controles de onda */}
        <div className="flex flex-wrap items-center gap-2">
          <Button
            onClick={startWave}
            disabled={waveInProgress || gameOver || victory || wave >= 10}
            size="sm"
          >
            {wave === 0 ? "▶ Iniciar onda 1" : `▶ Iniciar onda ${wave + 1}`}
          </Button>
          {waveInProgress ? (
            <Badge variant="outline" className="text-amber-400 border-amber-500/30">
              Onda em andamento — {enemiesLeft} restantes
            </Badge>
          ) : wave >= 10 ? (
            <Badge variant="outline" className="text-emerald-400 border-emerald-500/30">
              Todas as ondas concluídas
            </Badge>
          ) : (
            <Badge variant="outline" className="text-cyan-400 border-cyan-500/30">
              Próxima onda pronta
            </Badge>
          )}
          <div className="ml-auto flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={resetGame}
            >
              ↻ Reiniciar
            </Button>
          </div>
        </div>

        {/* Barra de progresso da onda */}
        <div className="space-y-1">
          <div className="flex justify-between text-xs text-muted-foreground">
            <span>Progresso das ondas</span>
            <span>{wave}/10</span>
          </div>
          <Progress value={(wave / 10) * 100} className="h-2" />
        </div>
      </div>

      {/* Coluna lateral: shop + selected tower */}
      <div className="space-y-3">
        <Card>
          <CardContent className="pt-5 space-y-3">
            <div>
              <h3 className="text-sm font-semibold">Construir torre</h3>
              <p className="text-[11px] text-muted-foreground">
                Selecione e clique no mapa. Construa fora do caminho.
              </p>
            </div>
            <ShopButton
              active={choice === "sentry"}
              onClick={() =>
                setChoice((c) => (c === "sentry" ? null : "sentry"))
              }
              icon={SENTRY.icon}
              name={SENTRY.name}
              cost={SENTRY.stats.cost}
              dps={sentryDps}
              color={SENTRY.stats.color}
              disabled={gold < SENTRY.stats.cost}
              tag="Recarga"
            />
            <ShopButton
              active={choice === "dispenser-mk1"}
              onClick={() =>
                setChoice((c) =>
                  c === "dispenser-mk1" ? null : "dispenser-mk1"
                )
              }
              icon={DISPENSER_TIERS.MK1.icon}
              name="Dispenser MK1"
              cost={DISPENSER_TIERS.MK1.stats.cost}
              dps={mk1Dps}
              color={DISPENSER_TIERS.MK1.stats.color}
              disabled={gold < DISPENSER_TIERS.MK1.stats.cost}
              tag="Upgradável"
            />

            <Separator />

            {/* Torre selecionada */}
            {selectedTower ? (
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <span
                    className="grid place-items-center w-8 h-8 rounded-md text-base"
                    style={{
                      background: `${selectedTower.stats.color}1f`,
                      border: `1px solid ${selectedTower.stats.color}55`,
                    }}
                  >
                    {selectedTower.kind === "sentry"
                      ? SENTRY.icon
                      : selectedTower.tier === "MK1"
                      ? DISPENSER_TIERS.MK1.icon
                      : selectedTower.tier === "MK2"
                      ? DISPENSER_TIERS.MK2.icon
                      : DISPENSER_TIERS.MK3.icon}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-semibold truncate">
                      {selectedTower.kind === "sentry"
                        ? SENTRY.name
                        : DISPENSER_TIERS[selectedTower.tier!].name}
                    </div>
                    <div className="text-[10px] text-muted-foreground font-mono">
                      DPS {effectiveDps(selectedTower.stats).toFixed(1)}
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-1 text-[11px]">
                  <MiniStat label="Dano" value={selectedTower.stats.damage.toString()} />
                  <MiniStat label="Cadência" value={`${selectedTower.stats.fireRate.toFixed(2)}/s`} />
                  <MiniStat label="Alcance" value={`${selectedTower.stats.range}px`} />
                  <MiniStat label="Splash" value={`${selectedTower.stats.splashRadius ?? 0}px`} />
                </div>

                {selectedTower.kind === "sentry" && (
                  <div className="text-[10px] text-orange-400/80 bg-orange-500/10 rounded px-2 py-1">
                    Pente: {selectedTower.ammo}/{selectedTower.stats.ammo} • Recarga: {selectedTower.stats.reloadTime}s
                  </div>
                )}
                {selectedTower.kind === "dispenser" && selectedTower.stats.slowFactor ? (
                  <div className="text-[10px] text-cyan-400/80 bg-cyan-500/10 rounded px-2 py-1">
                    ❄ Slow {Math.round(selectedTower.stats.slowFactor * 100)}% por {selectedTower.stats.slowDuration}s
                  </div>
                ) : null}

                {selectedTower.kind === "dispenser" && upgradeTarget ? (
                  <div className="space-y-2 pt-1">
                    <div className="text-[11px] text-muted-foreground">
                      Próximo:{" "}
                      <span
                        className="font-semibold"
                        style={{ color: DISPENSER_TIERS[upgradeTarget].stats.color }}
                      >
                        {DISPENSER_TIERS[upgradeTarget].name}
                      </span>
                    </div>
                    <Button
                      size="sm"
                      className="w-full"
                      onClick={handleUpgrade}
                      disabled={gold < upgradeCostValue}
                      style={{
                        background: DISPENSER_TIERS[upgradeTarget].stats.color,
                      }}
                    >
                      ⬆ Upgrade por 🪙 {upgradeCostValue}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="w-full"
                      onClick={handleSell}
                    >
                      💰 Vender (+🪙 {Math.floor(selectedTower.stats.cost * 0.6)})
                    </Button>
                  </div>
                ) : (
                  <Button
                    size="sm"
                    variant="outline"
                    className="w-full"
                    onClick={handleSell}
                  >
                    💰 Vender (+🪙 {Math.floor(selectedTower.stats.cost * 0.6)})
                  </Button>
                )}
              </div>
            ) : (
              <div className="text-[11px] text-muted-foreground italic px-1">
                💡 Clique numa torre construída para ver stats, fazer upgrade
                (Dispenser MK1→MK2→MK3) ou vender.
              </div>
            )}
          </CardContent>
        </Card>

        {/* Mini comparativo DPS rápido */}
        <Card>
          <CardContent className="pt-5 space-y-2">
            <h3 className="text-sm font-semibold">DPS por torre</h3>
            <DpsBar label="Sentry" value={sentryDps} color={SENTRY.stats.color} max={Math.max(sentryDps, mk3Dps)} />
            <DpsBar label="MK1" value={mk1Dps} color={DISPENSER_TIERS.MK1.stats.color} max={Math.max(sentryDps, mk3Dps)} />
            <DpsBar label="MK2" value={mk2Dps} color={DISPENSER_TIERS.MK2.stats.color} max={Math.max(sentryDps, mk3Dps)} />
            <DpsBar label="MK3" value={mk3Dps} color={DISPENSER_TIERS.MK3.stats.color} max={Math.max(sentryDps, mk3Dps)} />
            <p className="text-[10px] text-muted-foreground pt-1">
              Sentry inclui tempo de recarga. Dispenser é dano×cadência simples.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function HudStat({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent: string;
}) {
  return (
    <div className="rounded-lg border border-border bg-card px-3 py-2">
      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
        {label}
      </div>
      <div className="text-base font-bold font-mono" style={{ color: accent }}>
        {value}
      </div>
    </div>
  );
}

function ShopButton({
  active,
  onClick,
  icon,
  name,
  cost,
  dps,
  color,
  disabled,
  tag,
}: {
  active: boolean;
  onClick: () => void;
  icon: string;
  name: string;
  cost: number;
  dps: number;
  color: string;
  disabled?: boolean;
  tag?: string;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`w-full flex items-center gap-3 rounded-lg border px-3 py-2 text-left transition-all disabled:opacity-40 disabled:cursor-not-allowed ${
        active
          ? "bg-accent border-foreground/20"
          : "hover:bg-accent/50 border-border"
      }`}
      style={active ? { borderColor: color } : undefined}
    >
      <span
        className="grid place-items-center w-9 h-9 rounded-md text-lg shrink-0"
        style={{ background: `${color}1f`, border: `1px solid ${color}55` }}
      >
        {icon}
      </span>
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium flex items-center gap-1.5">
          {name}
          {tag ? (
            <Badge variant="outline" className="text-[9px] px-1 py-0 h-3.5">
              {tag}
            </Badge>
          ) : null}
        </div>
        <div className="text-[10px] text-muted-foreground font-mono">
          DPS {dps.toFixed(1)}
        </div>
      </div>
      <div className="text-right shrink-0">
        <div className="text-xs font-mono font-semibold">🪙 {cost}</div>
      </div>
    </button>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md bg-muted/40 px-2 py-1">
      <div className="text-[9px] uppercase text-muted-foreground">{label}</div>
      <div className="text-xs font-mono font-semibold">{value}</div>
    </div>
  );
}

function DpsBar({
  label,
  value,
  color,
  max,
}: {
  label: string;
  value: number;
  color: string;
  max: number;
}) {
  const pct = max > 0 ? (value / max) * 100 : 0;
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-[11px]">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-mono font-semibold">{value.toFixed(1)}</span>
      </div>
      <div className="h-1.5 bg-muted/40 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all"
          style={{ width: `${pct}%`, background: color }}
        />
      </div>
    </div>
  );
}
