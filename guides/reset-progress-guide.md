# Wagstaff Mod — Guia de Reset de Progresso do Personagem

## Estrutura Padrao da Pasta Klei

```
C:\Users\<SEU_USUARIO>\Documents\Klei\DoNotStarveTogether\
│
├── save/                          ← DADOS DE MUNDOS (aqui esta o progresso)
│   ├── session/                   ← CADA SUBPASTA = UM MUNDO
│   │   ├── 1A2B3C4D/              ← Mundo 1 (nome aleatorio)
│   │   │   ├── main/              ← Dados principais do mundo
│   │   │   │   ├── <world_save>   ← Save do mundo (biomas, structs, bosses mortos)
│   │   │   │   └── <player_save>  ← Save do jogador (inventario, vida, stats)
│   │   │   ├── mods/              ← Modoverrides do mundo (quais mods ativos)
│   │   │   └── mod_config/        ← Config dos mods PARA ESTE MUNDO
│   │   │
│   │   ├── 5E6F7G8H/              ← Mundo 2
│   │   │   └── ...
│   │   └── ...
│   │
│   └── backup/                    ← Backups automaticos de mundos
│
├── client_save/                   ← CONFIGS DE CLIENTE (mantenha!)
│   ├── mod_config_save/           ← Configs de mods (client-side)
│   └── ...
│
├── mods/                          ← MODS BAIXADOS DO WORKSHOP (mantenha!)
│   ├── workshop/
│   │   ├── 1234567890/            ← Cada pasta = um mod do Workshop
│   │   └── ...
│   └── ...
│
├── mod_config/                    ← CONFIGS GLOBAIS DE MODS (mantenha!)
│
├── profile/                       ← PROFILE STATS (bosses mortos, tempo jogado)
│
└── cluster/                       ← Dados de servidor dedicado (se usar)
```

---

## O Que Resetar vs O Que Manter

| Pasta | Acao | Motivo |
|-------|------|--------|
| `save/session/<mundo>/main/*` | **DELETAR** | Reseta mundo + progresso do personagem |
| `save/session/<mundo>/mods/` | **DELETAR** junto | Modoverrides do mundo (recria ao entrar) |
| `save/session/<mundo>/mod_config/` | **DELETAR** junto | Config de mods do mundo (recria ao entrar) |
| `mods/` | **NAO TOQUE** | Mods baixados do Workshop |
| `mod_config/` | **NAO TOQUE** | Configs globais de mods |
| `client_save/` | **NAO TOQUE** | Preferencias de cliente |
| `profile/` | **NAO TOQUE** | Estatisticas de conta |

---

## Metodos de Reset

### Metodo 1: Reset de UM mundo especifico
Delete a pasta inteira do mundo em `save/session/<NOME_DA_PASTA>/`.
Ao reentrar no mundo, ele sera recriado do zero.

### Metodo 2: Reset de TODOS os mundos
Delete tudo dentro de `save/session/`.

### Metodo 3: Reset so do progresso do personagem (mantem o mundo)
Mais complexo — requer editar os saves manualmente.
Para o Wagstaff mod, basta deletar `save/session/<mundo>/main/` e recriar o mundo.

---

## Script PowerShell (Recomendado)

Use o arquivo `reset-wagstaff-progress.ps1` que acompanha este guia.

### Como usar:
1. Abra o PowerShell como **Administrador**
2. Navegue ate a pasta do guia:
   ```powershell
   cd "C:\caminho\ate\WagstaffMod\guides"
   ```
3. Execute:
   ```powershell
   .\reset-wagstaff-progress.ps1
   ```

O script mostra seus mundos e pergunta qual resetar.

---

## Estrutura de Save do Wagstaff Mod

| Dado | Onde fica | Reseta ao deletar? |
|------|-----------|-------------------|
| XP do personagem | `save/session/<mundo>/main/<player_save>` | Sim |
| Skills desbloqueadas | `save/session/<mundo>/main/<player_save>` | Sim |
| Bosses mortos (affinity) | `save/session/<mundo>/main/<world_save>` | Sim |
| Nivel dos Bots | Na entidade do bot (no mundo) | Sim |
| Config de mods | `mod_config/` e `client_save/` | Nao |

---

## Aviso

- **Sempre faca backup** antes de deletar qualquer pasta
- O script `reset-wagstaff-progress.ps1` cria backup automaticamente
- Se jogar em servidor dedicado, os saves ficam em `cluster/` ao inves de `session/`