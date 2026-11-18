# 自动修复受损建筑（Auto Repair Damaged Buildings）

一个《文明6》轻量 UI 脚本 Mod：当你的城市里出现**被灾害/掠夺损坏的城区或建筑**时，自动把"修复"设为该城市的当前生产，效果**完全等同于你手动在生产面板点击"修复"**。

- **作者**：Lingma
- **版本**：v14
- **适用游戏**：文明6 2.0（实测于《风云变幻》；原版 / 迭起兴衰 亦应可用）
- **类型**：纯 UI 脚本，不改数据库、不改成本、不强制完成
- **存档兼容**：可在已有存档中直接生效，无需新开局

---

## 功能特性

- ✅ 自动识别本国所有城市中"**已建造且被掠夺**"的**城区**与**建筑**
- ✅ 自动把"修复"排入城市生产，立即开工（无需手动逐个点选）
- ✅ **城区优先**：城区被掠夺时其附属建筑会一并损坏，先修城区（符合游戏机制）
- ✅ **智能去重**：修复项已在当前生产或生产队列中时，不会重复入队
- ✅ **只作用于人类玩家（本地玩家）**，绝不干预 AI 与其他文明
- ✅ 事件驱动、每回合巡检，覆盖“回合开始 / 城市完成生产 / 坐城 / 攻陷·获得城市”等多种时机

---

## 工作原理

脚本监听三个游戏事件，任一触发时即扫描本国所有城市：

| 事件 | 触发时机 |
| --- | --- |
| `Events.LocalPlayerTurnBegin` | 本地玩家每回合开始时（常规巡检） |
| `Events.CityProductionCompleted` | 任意城市完成一次生产时 |
| `Events.CityAddedToMap` | 城市初次坐城时 |
| `Events.CityOccupationChanged` | 城市归属/占领状态变化时（攻陷、获得城市） |

扫描逻辑：

1. 遍历本国每座城市，先找**被掠夺的城区**，没有则找**被掠夺的建筑**；
2. 若该项**已在当前生产或队列**中，跳过（避免重复）；
3. 否则把"修复"直接设为该城市的**当前生产（替换位置 0，立即开工）**；
4. 每座城市每次最多接手一项，完成后下次触发继续下一项。

> 使用与游戏原版 `ProductionPanel.lua` **完全相同的 API 路径**（`CityManager.RequestOperation` + `CityOperationTypes.BUILD`），因此行为与手动点击"修复"一致。

---

## 安装方法

1. 将 **`AutoRepairDamagedBuildings`** 文件夹（Mod 本体）放入：
   ```
   文档\My Games\Sid Meier's Civilization VI\Mods\
   ```
   （即 `%USERPROFILE%\Documents\My Games\Sid Meier's Civilization VI\Mods\`）
2. 启动游戏 → 主菜单 → **额外内容（Additional Content）** → 勾选本 Mod；
3. **完全退出游戏到桌面，再重新启动**（改了模组文件后尤其重要，回主菜单无效）；
4. 载入任意存档即可生效，无需新开局。

---

## 使用说明

无需任何操作。启用后，凡是你自己的城市出现被损坏的城区/建筑，脚本会在下一次触发时机自动安排修复。

---

## 注意事项与已知限制

- ⚠️ **会替换城市当前生产**：本 Mod 采用与"生产面板点修复"相同的默认行为——把修复放到当前生产位（替换位置 0）。因此若该城市正在生产其他内容（单位/建筑/奇观），会被替换为修复项。这是为了"立即开工"，请知悉。
- ⚠️ **仅处理城区 / 建筑**：农田、矿场、伐木场等地块**改良设施**被掠夺时需要**建造者**修复，不在本 Mod 处理范围内。
- ⚠️ **修复仍需正常生产回合**：脚本只负责"排队"，不改变修复成本、也不强制立即完成。
- ⚠️ **仅对人类（本地）玩家生效**：AI 文明不受影响。
- ⚠️ **城区优先**的原因：游戏规定先修城区（原版注释 "Must do districts before buildings"）；城区被掠夺时其附属建筑也会被标记为损坏，但**不能单独修复**，必须先修好城区。脚本对此做了可生产校验，避免无效入队。

---

## 故障排查

本 Mod 发布版**默认关闭日志**（`LOG_ENABLED = false`）。如需排查问题，请先把 `UI/AutoRepairDamagedBuildings.lua` 顶部的 `LOG_ENABLED` 改为 `true`，再完全重启游戏。

1. 日志文件位置：
   ```
   %LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\Lua.log
   ```
2. 打开并搜索 `[AutoRepair]`，常见日志：

   | 日志 | 含义 |
   | --- | --- |
   | `已加载(UI)：监听...` | 脚本加载成功 |
   | `城市 X 自动修复城区: DISTRICT_...` | 已为城市 X 排入城区修复 |
   | `城市 X 自动修复建筑: BUILDING_...` | 已为城市 X 排入建筑修复 |
   | `跳过(修复已在队列) city=X` | 该城修复已在队列，跳过 |
   | `跳过(当前不可生产) city=X` | 该项当前不可生产（如城区未修好），等待下次 |
   | `巡检汇总: 空闲=.. 忙碌=.. 本次修复=..` | 每次扫描的结果汇总 |

3. 若日志里完全没有 `[AutoRepair]`：说明 Mod 未加载，请确认
   **已勾选启用**且**完全重启过游戏**。

---

## 日志开关（开发者）

日志总开关在 `UI/AutoRepairDamagedBuildings.lua` 顶部：

```lua
local LOG_ENABLED = false;  -- ← 发布版关闭日志；调试时改为 true
```

---

## 目录结构

```
auto-repair-damaged-buildings-when-not-built/   # 仓库根目录（仅放说明文档）
├─ README.md
└─ AutoRepairDamagedBuildings/                   # ★ 实际的 Mod 文件夹（安装 / 上传用这个）
   ├─ AutoRepairDamagedBuildings.modinfo         # Mod 定义
   └─ UI/
      ├─ AutoRepairDamagedBuildings.xml           # 隐藏 UI 上下文（用于挂载 Lua）
      └─ AutoRepairDamagedBuildings.lua           # 核心逻辑
```

> 说明：`README.md` 特意放在仓库**根目录**、不放在 Mod 文件夹内。
> 因为文明6上传工具是打包**整个 Mod 文件夹**，上传时把工具指向
> `AutoRepairDamagedBuildings\AutoRepairDamagedBuildings.modinfo` 即可，README 不会被一起上传。

---

## 更新日志

- **v15**：新增**攻陷 / 获得城市时**的触发判定（监听 `Events.CityOccupationChanged`），拿下城市后立即检查并安排修复。
- **v14**：修复"城区（如圣地）被灾害/掠夺损坏后不被修复"的问题——改为**城区优先**，并增加**建筑修复前的可生产校验**，避免无效入队并卡住城区修复。
- **v13 及更早**：引入事件驱动 + 每回合巡检的自动修复机制。

---

## 授权

本 Mod 可自由使用、转载与修改，请保留作者署名。如需采用其他授权方式，请自行调整本节。
