--[[ ================================================ ]]--
--[[  /~~\'      |~~\                  ~~|~    |      ]]--
--[[  '--.||/~\  |   |/~\/~~|/~~|\  /    | \  /|/~~|  ]]--
--[[  \__/||     |__/ \_/\__|\__| \/   \_|  \/ |\__|  ]]--
--[[                     \__|\__|_/                   ]]--
--[[ ================================================ ]]--
--[[

This file defines the tools to change visuals of zombies for the mod Zomboid Forge

]]--
--[[ ================================================ ]]--

--- Import functions localy for performances reasons
local table = table -- Lua's table module
local ipairs = ipairs -- ipairs function
local pairs = pairs -- pairs function
local ZombRand = ZombRand -- java function
local Long = Long --Long for pID

--- import module from ZomboidForge
local ZomboidForge = require "ZomboidForge_module"
local ZFModOptions = require "ZomboidForge_ClientOption"
ZFModOptions = ZFModOptions.options_data

-- localy initialize player
local player = getPlayer()
local function initTLOU_OnGameStart(playerIndex, player_init)
	player = getPlayer()
end
Events.OnCreatePlayer.Remove(initTLOU_OnGameStart)
Events.OnCreatePlayer.Add(initTLOU_OnGameStart)


--#region Update Zombie visuals

ZomboidForge.UpdateVisuals = function(zombie,ZombieTable,ZType)
    -- get zombie data
    local gender = zombie:isFemale() and "female" or "male"
    local ZData

    -- set ZombieData
    for key,data in pairs(ZomboidForge.ZombieData) do
        ZData = ZomboidForge.RetrieveDataFromTable(ZombieTable,key,gender)

        -- if data for this ZTypes found then
        if ZData then
            -- get current and do a choice
            local current = data.current(zombie)
            local choice = ZomboidForge.ChoseInTable(ZData,current)

            -- verify data was found in the list to chose or current is not choice
            if choice ~= nil then
                data.apply(zombie,choice)
            end
        end
    end

    -- set ZombieData_boolean
    for key,data in pairs(ZomboidForge.ZombieData_boolean) do
        ZData = ZomboidForge.RetrieveDataFromTable(ZombieTable,key,gender)

        -- if data for this ZTypes found then
        if ZData then
            -- do a choice
            local choice = ZomboidForge.ChoseInTable(ZData,nil)

            -- verify data was found in the list to chose or current is not choice
            if choice ~= nil then
                data.update(zombie,choice)
            end
        end
    end

    -- set custom emitters if any
    local customEmitter = ZombieTable.customEmitter
    if customEmitter then
        -- retreive emitter
        local emitter = customEmitter.general
            or zombie:isFemale() and customEmitter.female
            or customEmitter.male

        if emitter then
            local zombieEmitter = zombie:getEmitter()
            if not zombieEmitter:isPlaying(emitter) then
                zombieEmitter:stopAll()
                zombieEmitter:playVocals(emitter)
            end
        end
    end

    -- remove bandages
    if ZomboidForge.GetBooleanResult(zombie,ZType,ZombieTable.removeBandages,"removeBandages") then
        -- Remove bandages
        local bodyVisuals = zombie:getHumanVisual():getBodyVisuals()
        if bodyVisuals and bodyVisuals:size() > 0 then
            zombie:getHumanVisual():getBodyVisuals():clear()
        end
    end

    -- zombie clothing visuals
    local clothingVisuals = ZombieTable.clothingVisuals
    if clothingVisuals then
        -- get visuals and skip of none
        local visuals = zombie:getItemVisuals()
        if visuals then
            -- remove new visuals
            local locations = clothingVisuals.remove
            if locations then
                ZomboidForge.RemoveClothingVisuals(zombie,ZType,visuals,locations)
            end

            -- set new visuals
            locations = clothingVisuals.set
            if locations then
                ZomboidForge.AddClothingVisuals(visuals,locations)
            end
        end
    end
end

-- This function will remove clothing visuals from the `zombie` for each clothing `locations`.
---@param visuals ItemVisuals
---@param locations table
ZomboidForge.RemoveClothingVisuals = function(zombie,ZType,visuals,locations)
    -- cycle backward to not have any fuck up in index whenever one is removed
    for i = visuals:size() - 1, 0, -1 do
        local item = visuals:get(i)
        local location = item:getScriptItem():getBodyLocation()
        local location_remove = locations[item:getScriptItem():getBodyLocation()]
        if location_remove then
            local getRemove = ZomboidForge.GetBooleanResult(zombie,ZType,location_remove,"remove "..tostring(location))
            if getRemove then
                visuals:remove(item)
            end
        end
    end
end

-- This function will replace or add clothing visuals from the `zombie` for each 
-- clothing `locations` specified. 
--
--      `1: checks for bodyLocations that fit locations`
--      `2: replaces bodyLocation item if not already the proper item`
--      `3: add visuals that need to get added`
---@param visuals       ItemVisuals
---@param locations     table      --Zombie Type ID
ZomboidForge.AddClothingVisuals = function(visuals,locations)
    -- replace visuals that are at the same body locations and check for already set visuals
    local replace = {}
    for i = visuals:size() - 1, 0, -1 do
        local item = visuals:get(i)
        local location = item:getScriptItem():getBodyLocation()
        local getReplacement = locations[location]
        if getReplacement then
            if getReplacement ~= item then
                item:setItemType(getReplacement)
			    item:setClothingItemName(getReplacement)
            end
            replace[location] = item
        end
    end

    -- check for visuals that need to be added and add them
    for location,item in pairs(locations) do
        if not replace[location] then
            local itemVisual = ItemVisual.new()
            itemVisual:setItemType(item)
            itemVisual:setClothingItemName(item)
            visuals:add(itemVisual)
        end
    end
end

--#endregion

--#region Nametag handling

-- Permits access to the value associated to the option `ZFModOptions.Ticks`.
-- Used in `ZomboidForge.GetNametagTickValue`.
local TicksOption = {
    10,
    50,
    100,
    200,
    500,
    1000,
    10000,
}

-- Returns the `ticks` value. This value can be forced via a zombie type, else it's based
-- on client options.
---@param ZombieTable table
---@return int
ZomboidForge.GetNametagTickValue = function(ZombieTable)
    return ZombieTable.ticks or TicksOption[ZFModOptions.Ticks.value]
end

-- Shows the nametag of the `zombie`. Can be triggered anytime and will automatically
-- the `ticks` value and apply it to the `zombie`.
---@param zombie IsoZombie
---@param trueID int [opt]
---@param ZombieTable table [opt]
ZomboidForge.ShowZombieNametag = function(zombie,trueID,ZombieTable)
    -- get zombie informations
    trueID = trueID or ZomboidForge.pID(zombie)
    if not ZombieTable then
        local ZType = ZomboidForge.GetZType(trueID)
        ZombieTable = ZomboidForge.ZTypes[ZType]
    end
    local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID,"nametag")

    nonPersistentZData.ticks = ZomboidForge.GetNametagTickValue(ZombieTable)
end

-- Updates the nametag of the `zombie` if valid.
---@param zombie IsoZombie
---@param ZombieTable table
ZomboidForge.UpdateNametag = function(zombie,ZombieTable)
    -- get name and if none then no nametag should be set
    local name = getText(ZombieTable.name)
    if not name then return end

    -- retrieve nametag info
    local trueID = ZomboidForge.pID(zombie)
    local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID,"nametag")

    -- retrieve tick info
    local ticks = nonPersistentZData.ticks

    -- if not ticks then checks that nametag should be shown
    local valid = ZomboidForge.IsZombieValidForNametag(zombie)
    if not ticks then
        if not valid then
            return
        end

        ticks = ZomboidForge.GetNametagTickValue(ZombieTable)
    elseif valid then
        ticks = ZomboidForge.GetNametagTickValue(ZombieTable)
    end

    -- instantly fade zombie nametag
    -- if ZomboidForge.IsZombieBehind(zombie,player) then
    --     ticks = math.min(ticks,100)
    -- end

    -- draw nametag
    ZomboidForge.DrawNameTag(zombie,ZombieTable,ticks)

    -- reduce value of nametag or delete it
    if ticks <= 0 then
        nonPersistentZData.ticks = nil

        ZomboidForge.DeleteNametag(zombie)
    elseif ZomboidForge.IsZombieBehind(zombie,player) then
        ticks = math.min(ticks,100)
        nonPersistentZData.ticks = ticks - 100
    else
        nonPersistentZData.ticks = ticks - 1
    end
end

ZomboidForge.DeleteNametag = function(zombie)
    local zombieModData = zombie:getModData()
    zombieModData.nametag = nil
    zombieModData.color = nil
    zombieModData.outline = nil
    zombieModData.VerticalPlacement = nil
end

-- Draws the nametag of the `zombie` based on the `ticks` value.
---@param zombie IsoZombie
---@param ZombieTable table
---@param ticks int
ZomboidForge.DrawNameTag = function(zombie,ZombieTable,ticks)
    local zombieModData = zombie:getModData()

    -- get zombie nametag
    local nametag = zombieModData.nametag
    -- initialize nametag
    if not nametag then
        -- create the nametag
        zombieModData.nametag = TextDrawObject.new()
        nametag = zombieModData.nametag

        zombieModData.color = ZombieTable.color or {255,255,255}
        zombieModData.outline = ZombieTable.outline or {255,255,255}
        zombieModData.VerticalPlacement = ZFModOptions.VerticalPlacement.value

        -- apply string with font
        local fonts = ZFModOptions.Fonts
        nametag:ReadString(UIFont[fonts[fonts.value]], getText(ZombieTable.name), -1)

        if ZFModOptions.Background.value then
            nametag:setDrawBackground(true)
        end
    end

    -- get initial position of zombie
    local x = zombie:getX()
    local y = zombie:getY()
    local z = zombie:getZ()

    local sx = IsoUtils.XToScreen(x, y, z, 0)
    local sy = IsoUtils.YToScreen(x, y, z, 0)

    -- apply offset
    sx = sx - IsoCamera.getOffX() - zombie:getOffsetX()
    sy = sy - IsoCamera.getOffY() - zombie:getOffsetY()

    -- apply client vertical placement
    sy = sy - 190 + 20*zombieModData.VerticalPlacement

    -- apply zoom level
    local zoom = getCore():getZoom(0)
    sx = sx / zoom
    sy = sy / zoom
    sy = sy - nametag:getHeight()

    -- apply visuals
    local color = zombieModData.color
    local outline = zombieModData.outline
    nametag:setDefaultColors(color[1]/255,color[2]/255,color[3]/255,ticks/100)
    nametag:setOutlineColors(outline[1]/255,outline[2]/255,outline[3]/255,ticks/100)

    -- Draw nametag
    nametag:AddBatchedDraw(sx, sy, true)
end

-- Checks if the `zombie` is valid to have its nametag displayed for local player.
---@param zombie IsoZombie
---@return boolean
ZomboidForge.IsZombieValidForNametag = function(zombie)
    local isBehind = ZomboidForge.IsZombieBehind(zombie,player)

    -- test for each options
    -- 1. draw nametag if should always be on
    if ZFModOptions.AlwaysOn.value
    and (isClient() and SandboxVars.ZomboidForge.NametagsAlwaysOn or true)
    and not isBehind and player:CanSee(zombie)
    then
        return true

    -- 2. don't draw if player can't see zombie
    elseif not player:CanSee(zombie)
    or isBehind
    then
        return false

    -- 3. draw if zombie is attacking and option for it is on
    elseif ZFModOptions.WhenZombieIsTargeting.value and zombie:getTarget() then

        -- verify the zombie has a target and the player is the target
        local target = zombie:getTarget()
        if target and target == player then
            return true
        end

    -- 4. draw if zombie is in radius of cursor detection
    elseif ZomboidForge.IsZombieOnCursor(zombie) then
        return true
    end

    -- else return false, zombie is not valid
    return false
end

--#endregion