-- ===========================================================================
-- Auto Repair Damaged Buildings (UI context)
-- 空闲城市自动修复受损建筑/城区（仅人类玩家，事件驱动，不改变原有逻辑）
--
-- 触发（UI 事件）：
--   Events.CityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
--       城市完成任意一项生产时触发；orderType：0=训练单位 1=建造建筑 2=建造城区。
--       不再限定订单类型 —— 单位/建筑/城区/项目/奇观完成均触发扫描。
--   Events.CityAddedToMap(playerID, cityID, cityX, cityY)
--       城市加入地图（初次坐城）时触发。
--   Events.CityOccupationChanged(playerID, cityID)
--       城市归属/占领状态变化时触发（攻陷、获得城市等）。
--   Events.LocalPlayerTurnBegin()
--       本地玩家回合开始时触发（每回合巡检一次，不依赖灾害/事件）。
-- 行为：任一触发发生时，扫描本国所有城市，找出"已建造且被掠夺(损坏)"的城区/建筑，
--       直接把"修复"设为该城市的当前生产（替换位置0，立即开工）。
--       城区优先：城区被掠夺时其附属建筑会一并显示为损坏，且必须先修城区
--       （原版 ProductionPanel 亦注明 "Must do districts before buildings"）。
--       —— 完全等同于玩家手动点击"修复"（一次触发即可覆盖灾害波及的多座城市）。
--
-- 说明：本脚本不修改任何数据库，只做运行时排队，不改变成本/不强制完成。
--       使用与生产面板(ProductionPanel.lua)完全相同的 API 路径。
-- ===========================================================================

local LOG_TAG = "[AutoRepair] ";

-- ===========================================================================
-- 日志总开关：发布前改成 false 即可关闭本 Mod 的全部日志输出。
-- ===========================================================================
local LOG_ENABLED = true;  -- ← 调试时可改为 true

local function Log(msg)
	if not LOG_ENABLED then
		return;
	end
	print(LOG_TAG .. tostring(msg));
end

-- ===========================================================================
-- 是否空闲：没有正在进行的当前生产
-- ===========================================================================
local function IsCityIdle(pCity)
	local pBuildQueue = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		return false;
	end
	return pBuildQueue:GetCurrentProductionTypeHash() == 0;
end

-- ===========================================================================
-- 查找该城市中"已建造且已被掠夺(损坏)"的建筑
-- ===========================================================================
local function FindDamagedBuilding(pCity)
	local pCityBuildings = pCity:GetBuildings();
	if pCityBuildings == nil then
		return nil;
	end
	for building in GameInfo.Buildings() do
		if pCityBuildings:HasBuilding(building.Index) and pCityBuildings:IsPillaged(building.Hash) then
			return building;
		end
	end
	return nil;
end

-- ===========================================================================
-- 查找该城市中"已建造且已被掠夺(损坏)"的城区
-- ===========================================================================
local function FindDamagedDistrict(pCity)
	local pCityDistricts = pCity:GetDistricts();
	if pCityDistricts == nil then
		return nil;
	end
	for district in GameInfo.Districts() do
		if pCityDistricts:HasDistrict(district.Index) and pCityDistricts:IsPillaged(district.Index) then
			return district;
		end
	end
	return nil;
end

-- ===========================================================================
-- 该修复项当前是否可生产
--   城区被掠夺时，其附属建筑会被标记为损坏(IsPillaged=true)，但游戏不允许单独
--   生产该建筑 —— 必须先把城区修好。这里用 CanProduce 校验，避免把无效的"建筑修复"
--   排进队列/覆盖玩家当前生产。
-- ===========================================================================
local function CanRepairNow(pCity, hash)
	local pBuildQueue = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		return true;   -- 取不到队列时不拦截，交给游戏处理
	end
	local ok, canProduce = pcall(function()
		return pBuildQueue:CanProduce(hash, false, true);
	end);
	if not ok then
		return true;   -- 接口异常时不拦截
	end
	return canProduce == true;
end

-- ===========================================================================
-- 该修复项是否已在"当前生产"或"生产队列"中（避免重复入队）
-- ===========================================================================
local function IsRepairAlreadyQueued(pCity, buildingRow, districtRow)
	local pBuildQueue = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		return false;
	end

	local targetHash = nil;
	if buildingRow ~= nil then
		targetHash = buildingRow.Hash;
	elseif districtRow ~= nil then
		targetHash = districtRow.Hash;
	end
	if targetHash == nil then
		return false;
	end

	-- 正在生产的就是该项
	if pBuildQueue:GetCurrentProductionTypeHash() == targetHash then
		return true;
	end

	-- 队列里已有该项
	local n = pBuildQueue:GetSize();
	for i = 1, n do
		local entry = pBuildQueue:GetAt(i);
		if entry ~= nil then
			if buildingRow ~= nil and entry.BuildingType == buildingRow.BuildingType then
				return true;
			end
			if districtRow ~= nil and entry.DistrictType == districtRow.DistrictType then
				return true;
			end
		end
	end
	return false;
end

-- ===========================================================================
-- 把"修复"直接设为当前生产（替换位置0，立即开工；与生产面板点"修复"默认行为一致）
-- ===========================================================================
local function SetRepairAsProduction(pCity, buildingRow, districtRow)
	local tParameters = {};
	tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_REPLACE_AT;
	tParameters[CityOperationTypes.PARAM_QUEUE_DESTINATION_LOCATION] = 0;

	if buildingRow ~= nil then
		tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingRow.Hash;
	elseif districtRow ~= nil then
		tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtRow.Hash;
	else
		return false;
	end

	CityManager.RequestOperation(pCity, CityOperationTypes.BUILD, tParameters);
	return true;
end

-- ===========================================================================
-- 主逻辑：仅人类玩家；扫描本国所有城市
--   城区优先，其次建筑；每城每次最多接手一项（已在队列的会跳过，完成后继续下一项）
-- ===========================================================================
local function TryAutoRepairAll(playerID)
	-- 只处理人类（本地）玩家，绝不触碰 AI
	if playerID == nil or playerID ~= Game.GetLocalPlayer() then
		return;
	end

	local pPlayer = Players[playerID];
	if pPlayer == nil then
		return;
	end

	local idleCount, busyCount, actionCount = 0, 0, 0;

	for _, pCity in pPlayer:GetCities():Members() do
		local cityID = pCity:GetID();
		if IsCityIdle(pCity) then
			idleCount = idleCount + 1;
		else
			busyCount = busyCount + 1;
		end

		-- 城区优先：城区被掠夺时其附属建筑会一并显示为损坏，且必须先修城区
		-- （原版 ProductionPanel 亦注明 "Must do districts before buildings"）；
		-- 否则会卡在"修建筑"，城区一直不修，看起来就像没生效。
		local districtRow = FindDamagedDistrict(pCity);
		local buildingRow = nil;
		if districtRow == nil then
			buildingRow = FindDamagedBuilding(pCity);
		end

		if districtRow == nil and buildingRow == nil then
			-- 本城无损坏，跳过（不打印，避免刷屏）
		elseif IsRepairAlreadyQueued(pCity, buildingRow, districtRow) then
			Log("跳过(修复已在队列) city=" .. tostring(cityID));
		else
			-- 城区修复直接排（城区被掠夺只能靠城市生产修复）；
			-- 建筑修复需先确认当前可生产（城区被掠夺时其建筑不可单独修，需等城区修好）。
			local canQueue = (districtRow ~= nil) or (buildingRow ~= nil and CanRepairNow(pCity, buildingRow.Hash));
			if not canQueue then
				Log("跳过(当前不可生产) city=" .. tostring(cityID) .. " 建筑=" .. tostring(buildingRow.BuildingType));
			elseif SetRepairAsProduction(pCity, buildingRow, districtRow) then
				actionCount = actionCount + 1;
				if districtRow ~= nil then
					Log("城市 " .. tostring(cityID) .. " 自动修复城区: " .. tostring(districtRow.DistrictType));
				else
					Log("城市 " .. tostring(cityID) .. " 自动修复建筑: " .. tostring(buildingRow.BuildingType));
				end
			end
		end
	end

	Log("巡检汇总: 空闲=" .. tostring(idleCount) .. " 忙碌=" .. tostring(busyCount) .. " 本次修复=" .. tostring(actionCount));
end

-- ===========================================================================
-- 事件回调（用 pcall 包裹，避免脚本异常影响游戏）
-- ===========================================================================
function OnAutoRepairCityProductionCompleted(playerID, cityID, orderType)
	if playerID ~= Game.GetLocalPlayer() then
		return;
	end
	local ok, err = pcall(TryAutoRepairAll, playerID);
	if not ok then
		Log("CityProductionCompleted 处理异常: " .. tostring(err));
	end
end

function OnAutoRepairCityAddedToMap(playerID, cityID)
	if playerID ~= Game.GetLocalPlayer() then
		return;
	end
	local ok, err = pcall(TryAutoRepairAll, playerID);
	if not ok then
		Log("CityAddedToMap 处理异常: " .. tostring(err));
	end
end

-- ===========================================================================
-- 获得/攻陷城市：城市归属（占领状态）变化时触发，立即检查该城（及全国）是否需修复
-- ===========================================================================
function OnAutoRepairCityOccupationChanged(playerID, cityID)
	if playerID ~= Game.GetLocalPlayer() then
		return;
	end
	local ok, err = pcall(TryAutoRepairAll, playerID);
	if not ok then
		Log("CityOccupationChanged 处理异常: " .. tostring(err));
	end
end

-- ===========================================================================
-- 每回合巡检：本地玩家回合开始时，无论是否有灾害/事件，都对全国城市检查一遍
-- ===========================================================================
function OnAutoRepairLocalPlayerTurnBegin()
	local playerID = Game.GetLocalPlayer();
	if playerID == nil or playerID < 0 then
		return;
	end
	local ok, err = pcall(TryAutoRepairAll, playerID);
	if not ok then
		Log("LocalPlayerTurnBegin 处理异常: " .. tostring(err));
	end
end

Events.CityProductionCompleted.Add(OnAutoRepairCityProductionCompleted);
Events.CityAddedToMap.Add(OnAutoRepairCityAddedToMap);
Events.CityOccupationChanged.Add(OnAutoRepairCityOccupationChanged);
Events.LocalPlayerTurnBegin.Add(OnAutoRepairLocalPlayerTurnBegin);

Log("已加载(UI)：监听'生产完成'/'城市加入地图'/'城市易主'/'回合开始'事件。");
