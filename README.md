# 文明6 Mod 合集 / Civilization VI Mods

《文明6》(Civilization VI) 自制 Mod 的源代码仓库，作者 **Lingma**。

每个 Mod 一个子目录，子目录内是可直接放进游戏的 Mod 文件夹。

---

## Mod 列表

| Mod | 说明 | 目录 |
| --- | --- | --- |
| **自动修复受损建筑**<br>Auto Repair Damaged Buildings | 城市出现被灾害/掠夺损坏的城区或建筑时，自动把"修复"设为当前生产。纯 UI 脚本，只对人类玩家生效，不改数据库、不改成本。 | [`auto-repair-damaged-buildings-when-not-built/`](auto-repair-damaged-buildings-when-not-built/) |
| **城邦无初始城墙**<br>No City-State Initial Walls | 高难度下城邦不再自带初始城墙，攻城更符合预期。纯数据库改动（`UpdateDatabase`）。 | [`no-city-state-initial-walls/`](no-city-state-initial-walls/) |

---

## 目录结构

```
civ6mod/
├─ README.md                                        # 本文件
├─ auto-repair-damaged-buildings-when-not-built/
│  ├─ README.md                                     # 详细说明（功能、原理、排错、更新日志）
│  └─ AutoRepairDamagedBuildings/                   # ★ Mod 本体（安装 / 上传用这个文件夹）
│     ├─ AutoRepairDamagedBuildings.modinfo
│     └─ UI/
│        ├─ AutoRepairDamagedBuildings.xml
│        └─ AutoRepairDamagedBuildings.lua
└─ no-city-state-initial-walls/
   ├─ NoCityStateWalls.modinfo                       # ★ 仓库根即 Mod 本体（含 modinfo）
   ├─ Data/NoCityStateWalls_Gameplay.xml
   └─ Text/NoCityStateWalls_Text.xml
```

> 注意两个 Mod 的打包方式不同：
> 「自动修复受损建筑」的 Mod 本体在 `AutoRepairDamagedBuildings/` 子目录里（`README.md` 特意放在仓库根、不会被一起打包上传）；
> 「城邦无初始城墙」的 Mod 本体就是 `no-city-state-initial-walls/` 目录本身。

---

## 安装方法

1. 把上表中对应 Mod 的**本体文件夹**复制到：
   ```
   %USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\
   ```
2. 启动游戏 → 主菜单 → **额外内容 (Additional Content)** → 勾选启用；
3. **完全退出游戏到桌面再启动**（改过 Mod 文件后，回主菜单无效）；
4. 载入存档即可生效，无需新开局。

各 Mod 的详细说明、原理与故障排查见各自目录下的文档。

---

## 授权

各 Mod 可自由使用、转载与修改，请保留作者署名。
