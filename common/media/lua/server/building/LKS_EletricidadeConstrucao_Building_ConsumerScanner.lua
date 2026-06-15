-- ============================================================================
-- HOMENAGEM E AGRADECIMENTO AO CRIADOR ORIGINAL
-- Este arquivo foi adaptado e integrado nativamente ao LKS SuperMod Patch.
-- Agradecemos a Beathoven pelo mod original "Generator Powered Buildings"
-- (ID Workshop: 3597471949) e pela contribuição à comunidade.
-- ============================================================================

-- LKS_EletricidadeConstrucao_Building_ConsumerScanner.lua
-- LKS_EletricidadeConstrucao V2 - Consumer Scanner
-- Scans building areas for power consumers (lights, lamps, appliances)
-- Version: 2.0.0-alpha
-- Date: February 22, 2026


-- Ensure namespace exists
if not LKS_EletricidadeConstrucao then
    print("[LKS_EletricidadeConstrucao_Building_ConsumerScanner] LKS_EletricidadeConstrucao namespace not found - skipping module load")
    return
end

-- Initialize sub-namespace
LKS_EletricidadeConstrucao.Building = LKS_EletricidadeConstrucao.Building or {}
LKS_EletricidadeConstrucao.Building.ConsumerScanner = LKS_EletricidadeConstrucao.Building.ConsumerScanner or {}

-- ============================================================================
-- CONSUMER DETECTION
-- ============================================================================

--- Scan building for power consumers
--- @param buildingData BuildingData Building to scan
--- @param borderTiles table Array of border tiles {x, y, z}
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(buildingData, borderTiles)
    if not buildingData then
        LKS_EletricidadeConstrucao.Core.Logger.Error("BuildingData is nil", "Building")
        return
    end
    
    if not borderTiles or #borderTiles == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("No border tiles for building %s", buildingData.id),
            "Building"
        )
        return
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.StartTimer("ConsumerScan")
    
    -- Use borderTiles directly - they already contain all tiles (interior + perimeter)
    -- across multiple Z levels (z-3 to z+15) from DetectBorders()
    local allTiles = borderTiles
    
    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("Scanning %d tiles for consumers (across multiple Z levels)", #allTiles),
        "Building"
    )
    
    local lightCount = 0
    local lampCount = 0
    local applianceCount = 0
    local applianceCandidates = {}
    local anchorSquare = getSquare(buildingData.x, buildingData.y, buildingData.z or 0)
    local anchorBuilding = anchorSquare and anchorSquare:getBuilding() or nil

    local function IsForeignBuildingSquare(square)
        if not square or not anchorBuilding then
            return false
        end

        local sqBuilding = square:getBuilding()
        return sqBuilding ~= nil and sqBuilding ~= anchorBuilding
    end
    
    -- Track scanned squares to prevent duplicates
    local scannedSquares = {}
    
        -- Perimeter tiles (one-tile ring) to catch exterior wall lights/lamps
        local function CollectPerimeterTiles(interior)
            local out = {}
            local seen = {}
            local dirs = {
                {x = 1,  y = 0}, {x = -1, y = 0},
                {x = 0,  y = 1}, {x = 0,  y = -1}
            }
            for _, tile in ipairs(interior) do
                for _, d in ipairs(dirs) do
                    local px = tile.x + d.x
                    local py = tile.y + d.y
                    local key = px .. "_" .. py .. "_" .. tile.z
                    if not seen[key] then
                        seen[key] = true
                        table.insert(out, {x = px, y = py, z = tile.z})
                    end
                end
            end
            return out
        end

    -- Scan each tile for objects
    for _, tile in ipairs(allTiles) do
        local square = getSquare(tile.x, tile.y, tile.z)
        
        if square and not IsForeignBuildingSquare(square) then
            -- Mark this square as scanned to prevent duplicates
            local squareKey = tile.x .. "_" .. tile.y .. "_" .. tile.z
            scannedSquares[squareKey] = true
            
            local objects = square:getObjects()
            
            if objects then
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    
                    if obj then
                        local consumerType = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(obj)
                        
                        if consumerType then
                            -- Create consumer data
                            local consumerData = LKS_EletricidadeConstrucao.Data.Consumer.New(square, consumerType)
                            
                            -- Set fuel consumption based on type
                            local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
                            local baseFuelRate = Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH
                            
                            if consumerType == "light" or consumerType == "lamp" then
                                baseFuelRate = Constants.CONSUMPTION_LIGHT_LPH
                                consumerData.applianceType = nil
                            elseif consumerType == "appliance" then
                                -- Detect specific appliance type and get vanilla fuel rate
                                local applianceType, fuelRate = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceDetails(obj)
                                consumerData.applianceType = applianceType
                                baseFuelRate = fuelRate
                                
                                -- Recalculate powerDraw with appliance type
                                consumerData.powerDraw = LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw(consumerData, square)
                                
                                -- Debug logging
                                LKS_EletricidadeConstrucao.Core.Logger.Debug(
                                    string.format("Appliance detected: type=%s, powerDraw=%.1f, sprite=%s",
                                        tostring(applianceType or "NONE"),
                                        consumerData.powerDraw,
                                        obj:getSprite() and obj:getSprite():getName() or "unknown"),
                                    "Building")
                            end
                            
                            -- Apply sandbox fuel multiplier (normalize vanilla 0.1 -> 1.0)
                            local sandboxMult = 1.0
                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier then
                                sandboxMult = LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
                            end
                            consumerData.fuelConsumptionLph = baseFuelRate * sandboxMult
                            
                            -- Add to building
                            LKS_EletricidadeConstrucao.Data.Building.AddConsumer(buildingData, consumerData)
                            
                            -- Count by type
                            if consumerType == "light" then
                                lightCount = lightCount + 1
                            elseif consumerType == "lamp" then
                                lampCount = lampCount + 1
                            elseif consumerType == "appliance" then
                                applianceCount = applianceCount + 1
                            end
                        else
                            -- Record candidates for debugging when appliances are missing
                            local cand = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(obj)
                            if cand then table.insert(applianceCandidates, cand) end
                        end
                    end
                end
            end
        end
    end

    -- BorderTiles already include perimeter, but we can still check one more ring for safety
    local perimeterTiles = CollectPerimeterTiles(allTiles)
    for _, tile in ipairs(perimeterTiles) do
        -- Skip if already scanned (prevents duplicates)
        local squareKey = tile.x .. "_" .. tile.y .. "_" .. tile.z
        if not scannedSquares[squareKey] then
            scannedSquares[squareKey] = true
            
            local square = getSquare(tile.x, tile.y, tile.z)
        if square and not IsForeignBuildingSquare(square) then
            local objects = square:getObjects()
            if objects then
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if obj then
                        local consumerType = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(obj)
                        if consumerType == "light" or consumerType == "lamp" then
                            local consumerData = LKS_EletricidadeConstrucao.Data.Consumer.New(square, consumerType)
                            
                            -- Apply sandbox fuel multiplier
                            local baseFuelRate = LKS_EletricidadeConstrucao.Constants.FUEL.CONSUMPTION_LIGHT_LPH
                            local sandboxMult = 1.0
                            if LKS_EletricidadeConstrucao.Fuel and LKS_EletricidadeConstrucao.Fuel.Manager and LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier then
                                sandboxMult = LKS_EletricidadeConstrucao.Fuel.Manager.GetSandboxFuelMultiplier()
                            end
                            
                            consumerData.fuelConsumptionLph = baseFuelRate * sandboxMult
                            consumerData.applianceType = nil
                            LKS_EletricidadeConstrucao.Data.Building.AddConsumer(buildingData, consumerData)
                            if consumerType == "light" then
                                lightCount = lightCount + 1
                            elseif consumerType == "lamp" then
                                lampCount = lampCount + 1
                            end
                        else
                            local cand = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(obj)
                            if cand then table.insert(applianceCandidates, cand) end
                        end
                    end
                end
            end
        end
        end  -- close: if not scannedSquares[squareKey]
    end
    
    LKS_EletricidadeConstrucao.Core.Logger.EndTimer("ConsumerScan", 100)  -- Warn if > 100ms
    
    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("Found consumers in building %s: %d lights, %d lamps, %d appliances",
            buildingData.id, lightCount, lampCount, applianceCount),
        "Building"
    )

    if applianceCount == 0 and #applianceCandidates > 0 then
        local seen = {}
        local uniq = {}
        for _, tag in ipairs(applianceCandidates) do
            if not seen[tag] then
                seen[tag] = true
                table.insert(uniq, tag)
            end
        end
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("Appliance candidates seen (not counted): %s", table.concat(uniq, ", ")),
            "Building"
        )
    end
end

--- Rescan consumers for an existing building (e.g. after object placed/removed).
--- Uses the same logic as the initial scan to ensure consistency.
--- @param buildingData BuildingData Building to rescan
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.RescanConsumers(buildingData)
    if not buildingData then
        LKS_EletricidadeConstrucao.Core.Logger.Error("RescanConsumers: buildingData is nil", "Building")
        return
    end

    LKS_EletricidadeConstrucao.Core.Logger.Debug(
        string.format("RescanConsumers for building %s", buildingData.id),
        "Building"
    )

    -- Compute effective scan radius (player-built: derive from bounding box so the full
    -- footprint is covered even when borderRadius is only 2 from Config)
    local scanRadius = buildingData.borderRadius
    local bldId = buildingData.id or ""
    if string.match(bldId, "^bld_%-?%d+_%-?%d+_%-?%d+$") then
        if buildingData.boundingBox then
            local bb = buildingData.boundingBox
            local halfW = math.ceil((bb.maxX - bb.minX) / 2) + 3
            local halfH = math.ceil((bb.maxY - bb.minY) / 2) + 3
            scanRadius = math.max(halfW, halfH, scanRadius or 2)
        else
            scanRadius = math.max(scanRadius or 2, 30)
        end
    end

    -- Detect borders again (same as initial scan; pass id so player-built skips nearby-building search)
    local borderTiles = LKS_EletricidadeConstrucao.Building.BorderDetector.DetectBorders(
        buildingData.x,
        buildingData.y,
        buildingData.z,
        scanRadius,
        buildingData.id
    )

    if not borderTiles or #borderTiles == 0 then
        LKS_EletricidadeConstrucao.Core.Logger.Warn(
            string.format("RescanConsumers: no border tiles for building %s", buildingData.id),
            "Building"
        )
        return
    end

    -- B-83: Guard against partial chunk loads.
    -- A large building can span multiple 10×10 chunks. The 30-tick timer in the
    -- ChunkTracker fires after ONE generator's chunk loads; adjacent chunks may
    -- still be unloaded. getSquare() returns nil for unloaded tiles, so those
    -- consumers would simply not be found after the clear. The GlobalModData
    -- consumer list is correct (it was saved on the previous successful scan),
    -- so we preserve it by skipping the clear+rescan.
    local Scanner = LKS_EletricidadeConstrucao.Building.Scanner
    local hasExisting = false
    if buildingData.powerConsumers then
        for _ in pairs(buildingData.powerConsumers) do hasExisting = true; break end
    end
    if hasExisting and Scanner and Scanner.IsBuildingAreaLoaded
       and not Scanner.IsBuildingAreaLoaded(buildingData) then
        LKS_EletricidadeConstrucao.Core.Logger.Info(
            string.format("RescanConsumers: partial chunk load for %s – keeping existing consumers",
                buildingData.id),
            "Building")
        return
    end

    -- Clear existing consumers first to prevent duplicates
    LKS_EletricidadeConstrucao.Data.Building.ClearConsumers(buildingData)

    -- Use the same scan logic as initial scan (includes interior + perimeter)
    LKS_EletricidadeConstrucao.Building.ConsumerScanner.ScanConsumers(buildingData, borderTiles)

    -- Recalculate total power draw
    LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(buildingData)

    -- Persist updated building
    LKS_EletricidadeConstrucao.Core.StateManager.AddBuilding(buildingData)

    LKS_EletricidadeConstrucao.Core.Logger.Info(
        string.format("RescanConsumers completed for building %s: %d consumers, %.1f power draw",
            buildingData.id, #buildingData.powerConsumers, buildingData.totalPowerDraw or 0),
        "Building"
    )
end

--- Get consumer type from object
--- @param object IsoObject Object to check
--- @return string|nil Consumer type ("light", "lamp", "appliance") or nil
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(object)
    if not object then
        return nil
    end
    
    -- Check for ceiling lights (dynamic IsoLight objects)
    if instanceof(object, "IsoLight") then
        return "light"
    end
    
    -- Light switches represent the fixture they control: count as "light" (same as V1)
    if instanceof(object, "IsoLightSwitch") then
        return "light"
    end
    
    -- Check sprite name for light fixtures and lamps
    local sprite = object:getSprite()
    
    if sprite then
        local spriteName = sprite:getName()
        
        if spriteName then
            local lowerName = string.lower(spriteName)
            
            -- Check for ceiling / wall light fixtures.
            -- Vanilla PZ light sprites use a "lights_" prefix (e.g. lights_fluorescent_01,
            -- lights_ceiling_01, lights_wall_01).  Exclude switches / lighters / flashlights.
            if (string.find(lowerName, "lights_") or
                string.find(lowerName, "fluorescent") or
                string.find(lowerName, "ceiling_light") or
                string.find(lowerName, "wall_light") or
                string.find(lowerName, "streetlight")) and
               not string.find(lowerName, "switch") and
               not string.find(lowerName, "lighter") and
               not string.find(lowerName, "flashlight") then
                return "light"
            end
            
            -- Check for moveable lamps
            if string.find(lowerName, "lamp") or
               string.find(lowerName, "lighting") or
               string.find(lowerName, "floorlamp") or
               string.find(lowerName, "desklamp") or
               string.find(lowerName, "tablelamp") then
                return "lamp"
            end
        end
    end
    
    -- Check for appliances
    if LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(object) then
        return "appliance"
    end
    
    return nil
end

--- Check if object is an appliance
--- @param object IsoObject Object to check
--- @return boolean True if appliance
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(object)
    if not object then
        return false
    end

    -- Light fixtures and switches are handled by the light scanner. Many of
    -- them also expose generic powered APIs, which would inflate appliance counts.
    if instanceof(object, "IsoLight") or instanceof(object, "IsoLightSwitch") then
        return false
    end
    
    -- Check vanilla appliance types (mirrors V1 detection exactly)
    if instanceof(object, "IsoStove") or
       instanceof(object, "IsoRadio") or
       instanceof(object, "IsoTelevision") or
       instanceof(object, "IsoClothingDryer") or
       instanceof(object, "IsoClothingWasher") or
       instanceof(object, "IsoCombinationWasherDryer") or
       instanceof(object, "IsoStackedWasherDryer") then
        return true
    end

    -- Fridge / freezer detection: V1 uses getContainerByType (reliable across all
    -- fridge mods), which is more robust than IsoThumpable:isRefrigerator().
    -- Washer / dryer: world-gen objects are IsoThumpable with a container type,
    -- not IsoClothingDryer/Washer (that class is only used for moveables).
    if object.getContainerByType then
        if object:getContainerByType("fridge")        ~= nil
        or object:getContainerByType("freezer")       ~= nil
        or object:getContainerByType("clothingdryer") ~= nil
        or object:getContainerByType("clothingwasher") ~= nil then
            return true
        end
    end
    
    -- Check sprite name
    local sprite = object:getSprite()
    
    if sprite then
        local spriteName = sprite:getName()
        
        if spriteName then
            local lowerName = string.lower(spriteName)
            
            -- Common appliance keywords
            if string.find(lowerName, "fridge") or
               string.find(lowerName, "freezer") or
               string.find(lowerName, "microwave") or
               string.find(lowerName, "oven") or
               string.find(lowerName, "stove") or
               string.find(lowerName, "television") or
               string.find(lowerName, "radio") or
               string.find(lowerName, "washer") or
               string.find(lowerName, "dryer") then
                return true
            end
        end
    end

    -- Fallback: treat devices with device data (custom electronics) as appliances
    if object.getDeviceData then
        local ok, deviceData = pcall(function() return object:getDeviceData() end)
        if ok and deviceData then
            return true
        end
    end
    
    return false
end

-- Debug helper: tag likely-appliance objects that were not counted
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceCandidateTag(object)
    if not object then return nil end
    local sprite = object.getSprite and object:getSprite()
    local name = sprite and sprite:getName() or "<no-sprite>"
    if object.getDeviceData and object:getDeviceData() then
        return name .. "[device]"
    end
    if object.setIsPowered then
        return name .. "[powerable]"
    end
    if object.getContainerCount and object:getContainerCount() > 0 then
        return name .. "[container]"
    end
    return nil
end

-- ============================================================================
-- CONSUMER POWER DRAW CALCULATION
-- ============================================================================

--- Get power draw for consumer
--- @param consumerData ConsumerData Consumer to check
--- @return number Power draw value
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerPowerDraw(consumerData)
    if not consumerData then
        return 0
    end
    
    local Constants = LKS_EletricidadeConstrucao.Constants
    
    -- NOTE: ConsumerData uses objectType (not type). For appliance sub-type granularity
    -- prefer LKS_EletricidadeConstrucao.Data.Consumer.CalculatePowerDraw() directly.
    if consumerData.objectType == "light" then
        return Constants.FUEL.POWER_DRAW_LIGHT or 1.0
    elseif consumerData.objectType == "lamp" then
        return Constants.FUEL.POWER_DRAW_LIGHT or 1.0
    elseif consumerData.objectType == "appliance" then
        return Constants.FUEL.POWER_DRAW_APPLIANCE or 2.0
    end

    return 0
end

--- Detect specific appliance type and get vanilla fuel consumption rate
--- @param object IsoObject The object to check
--- @return string|nil applianceType Specific type ("fridge", "freezer", "tv", "radio", "stove", "washer", "dryer", "microwave")
--- @return number fuelConsumptionLph Fuel consumption in L/h (vanilla rate)
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetApplianceDetails(object)
    local Constants = LKS_EletricidadeConstrucao.Constants.FUEL
    
    -- Check by instanceof first (most reliable)
    if instanceof(object, "IsoTelevision") then
        return "tv", Constants.CONSUMPTION_TV_LPH
    end
    
    if instanceof(object, "IsoRadio") then
        return "radio", Constants.CONSUMPTION_RADIO_LPH
    end
    
    if instanceof(object, "IsoStove") then
        return "stove", Constants.CONSUMPTION_STOVE_LPH
    end
    
    if instanceof(object, "IsoClothingWasher") or instanceof(object, "IsoStackedWasherDryer") then
        return "washer", Constants.CONSUMPTION_WASHER_LPH
    end
    
    if instanceof(object, "IsoClothingDryer") or instanceof(object, "IsoCombinationWasherDryer") then
        return "dryer", Constants.CONSUMPTION_DRYER_LPH
    end
    
    -- Check container types (for world-placed appliances)
    if object.getContainerByType then
        -- Check for combo fridge/freezer first (has both containers)
        local hasFridge = object:getContainerByType("fridge") ~= nil
        local hasFreezer = object:getContainerByType("freezer") ~= nil
        
        if hasFridge and hasFreezer then
            return "fridgeFreezer", Constants.CONSUMPTION_FRIDGE_FREEZER_LPH
        end
        
        if hasFridge then
            return "fridge", Constants.CONSUMPTION_FRIDGE_LPH
        end
        
        if hasFreezer then
            return "freezer", Constants.CONSUMPTION_FREEZER_LPH
        end
        
        if object:getContainerByType("clothingwasher") ~= nil then
            return "washer", Constants.CONSUMPTION_WASHER_LPH
        end
        
        if object:getContainerByType("clothingdryer") ~= nil then
            return "dryer", Constants.CONSUMPTION_DRYER_LPH
        end
    end
    
    -- Check sprite name for detection (important for multi-tile appliances)
    local sprite = object:getSprite()
    if sprite then
        local spriteName = sprite:getName()
        if spriteName then
            local lowerName = string.lower(spriteName)
            
            if string.find(lowerName, "microwave") then
                return "microwave", Constants.CONSUMPTION_MICROWAVE_LPH
            end
            
            -- Fridge detection (including combo units) - check before freezer to prioritize combo detection
            if string.find(lowerName, "fridge") and string.find(lowerName, "freezer") then
                return "fridgeFreezer", Constants.CONSUMPTION_FRIDGE_FREEZER_LPH
            end
            
            if string.find(lowerName, "fridge") then
                return "fridge", Constants.CONSUMPTION_FRIDGE_LPH
            end
            
            -- Freezer detection (various sprite patterns)
            if string.find(lowerName, "freezer") or 
               string.find(lowerName, "appliances_refrigeration") or
               string.find(lowerName, "commercial_freezer") then
                return "freezer", Constants.CONSUMPTION_FREEZER_LPH
            end
            
            if string.find(lowerName, "stove") or string.find(lowerName, "oven") then
                return "stove", Constants.CONSUMPTION_STOVE_LPH
            end
            
            -- Washer/dryer patterns
            if string.find(lowerName, "washer") or string.find(lowerName, "washing") then
                return "washer", Constants.CONSUMPTION_WASHER_LPH
            end
            
            if string.find(lowerName, "dryer") or string.find(lowerName, "drying") then
                return "dryer", Constants.CONSUMPTION_DRYER_LPH
            end
            
            -- Debug: Log unrecognized appliance sprites
            LKS_EletricidadeConstrucao.Core.Logger.Debug(
                string.format("Unrecognized appliance sprite: %s (using default %.3f L/h)",
                    spriteName, Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH),
                "Building")
        end
    end
    
    -- Default for unclassified appliances
    return nil, Constants.CONSUMPTION_APPLIANCE_DEFAULT_LPH
end

--- Update consumer power state
--- @param consumerData ConsumerData Consumer to update
--- @param isPowered boolean True if powered
--- NOTE: isActive update on consumerData is handled by the caller (Distributor)
---       since it needs to check light-switch-on state per consumer.
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.UpdateConsumerPowerState(consumerData, isPowered)
    if not consumerData then
        return
    end
    
    -- Get object from world
    local square = getSquare(consumerData.squareX, consumerData.squareY, consumerData.squareZ)
    
    if not square then
        LKS_EletricidadeConstrucao.Core.Logger.Trace(
            string.format("Square not found for consumer at (%d,%d,%d)", 
                consumerData.squareX, consumerData.squareY, consumerData.squareZ),
            "Building"
        )
        return
    end
    
    -- Find object
    local objects = square:getObjects()
    
    if not objects then
        return
    end
    
    local objType = consumerData.objectType
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            -- Only act on the specific object matching this consumer's type.
            -- Using all-objects iteration + broad instanceof caused errors on
            -- non-powerable objects (walls, floors) that share the same square.
            local matched = false
            if objType == "light" then
                matched = instanceof(obj, "IsoLight") or instanceof(obj, "IsoLightSwitch")
            elseif objType == "lamp" then
                -- IsoLight covers dynamic lights; fall back to setIsPowered
                -- existence check for moveable lamp IsoThumpable subclasses.
                if instanceof(obj, "IsoLight") then
                    matched = true
                elseif obj.setIsPowered ~= nil and not instanceof(obj, "IsoLightSwitch") and not instanceof(obj, "IsoLight") then
                    matched = true
                end
            elseif objType == "appliance" then
                matched = LKS_EletricidadeConstrucao.Building.ConsumerScanner.IsAppliance(obj)
            end

            if matched then
                LKS_EletricidadeConstrucao.Building.ConsumerScanner.SetObjectPowerState(obj, objType, isPowered)
                break  -- one consumer = one target object
            end
        end
    end
end

--- Set object power state
--- @param object IsoObject Object to update
--- @param consumerType string Consumer type
--- @param isPowered boolean True if powered
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.SetObjectPowerState(object, consumerType, isPowered)
    if not object then
        return
    end
    
    if consumerType == "light" then
        -- Dynamic ceiling light (IsoLight)
        if instanceof(object, "IsoLight") then
            if object.setActive then
                object:setActive(isPowered)
            end
            return
        end
        -- IsoLightSwitch: setIsPowered is not exposed in PZ 42 Lua, and
        -- toggle() would override the player's own on/off preference.
        -- The IsoLight path (above) handles the actual ambient lighting.
        -- Nothing to do here; just consume the match so we don't fall through.
        if instanceof(object, "IsoLightSwitch") then
            return
        end
    elseif consumerType == "lamp" then
        -- Dynamic lamp light
        if instanceof(object, "IsoLight") then
            if object.setActive then
                object:setActive(isPowered)
            end
            return
        end
        -- Moveable lamp: only call if the method is actually exposed.
        if instanceof(object, "IsoThumpable") and object.setIsPowered then
            object:setIsPowered(isPowered)
            return
        end
    elseif consumerType == "appliance" then
        -- Guard: not all IsoThumpable subclasses expose setIsPowered to Lua.
        if instanceof(object, "IsoThumpable") and object.setIsPowered then
            object:setIsPowered(isPowered)
            return
        end
    end
end

--- Check if consumer still exists in world
--- @param consumerData ConsumerData Consumer to check
--- @return boolean True if exists
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.ConsumerExists(consumerData)
    if not consumerData then
        return false
    end
    
    local square = getSquare(consumerData.squareX, consumerData.squareY, consumerData.squareZ)
    
    if not square then
        return false
    end
    
    local objects = square:getObjects()
    
    if not objects then
        return false
    end
    
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        
        if obj then
            local objX = obj:getX()
            local objY = obj:getY()
            local objZ = obj:getZ()
            
            if objX == consumerData.squareX and objY == consumerData.squareY and objZ == consumerData.squareZ then
                local objType = LKS_EletricidadeConstrucao.Building.ConsumerScanner.GetConsumerType(obj)
                
                if objType == consumerData.objectType then
                    return true
                end
            end
        end
    end
    
    return false
end

--- Remove invalid consumers from building
--- @param buildingData BuildingData Building to clean
--- @return number Number of consumers removed
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.CleanInvalidConsumers(buildingData)
    if not buildingData then
        return 0
    end
    
    local removed = 0
    local validConsumers = {}

    -- Use pairs (not ipairs): powerConsumers deserialized from GlobalModData uses
    -- Kahlua string numeric keys ("1","2",...) that ipairs cannot iterate.
    for _, consumer in pairs(buildingData.powerConsumers) do
        if LKS_EletricidadeConstrucao.Building.ConsumerScanner.ConsumerExists(consumer) then
            table.insert(validConsumers, consumer)
        else
            LKS_EletricidadeConstrucao.Core.Logger.Debug(
                string.format("Removing invalid consumer at (%d,%d,%d) from building %s",
                    consumer.squareX, consumer.squareY, consumer.squareZ, buildingData.id),
                "Building"
            )
            removed = removed + 1
        end
    end
    
    buildingData.powerConsumers = validConsumers
    
    if removed > 0 then
        LKS_EletricidadeConstrucao.Data.Building.RecalculatePower(buildingData)
    end
    
    return removed
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- Print consumer scan results
--- @param buildingData BuildingData Building to print
function LKS_EletricidadeConstrucao.Building.ConsumerScanner.PrintConsumers(buildingData)
    if not buildingData then
        LKS_EletricidadeConstrucao.Print("No building data")
        return
    end
    
    -- Collect via pairs: powerConsumers deserialized from GlobalModData uses Kahlua
    -- string numeric keys ("1","2",...) that # and ipairs cannot reliably iterate.
    local all = {}
    local totalCount = 0
    local lights = 0
    local lamps = 0
    local appliances = 0
    for _, consumer in pairs(buildingData.powerConsumers) do
        totalCount = totalCount + 1
        table.insert(all, consumer)
        if consumer.objectType == "light" then
            lights = lights + 1
        elseif consumer.objectType == "lamp" then
            lamps = lamps + 1
        elseif consumer.objectType == "appliance" then
            appliances = appliances + 1
        end
    end

    LKS_EletricidadeConstrucao.Print("=== Consumers for Building " .. buildingData.id .. " ===")
    LKS_EletricidadeConstrucao.Print("Total Consumers: " .. totalCount)
    LKS_EletricidadeConstrucao.Print("Total Power Draw: " .. (buildingData.totalPowerDraw or 0))
    LKS_EletricidadeConstrucao.Print("Lights: " .. lights)
    LKS_EletricidadeConstrucao.Print("Lamps: " .. lamps)
    LKS_EletricidadeConstrucao.Print("Appliances: " .. appliances)

    LKS_EletricidadeConstrucao.Print("\nFirst 10 consumers:")
    local limit = math.min(10, #all)
    for i = 1, limit do
        local consumer = all[i]
        LKS_EletricidadeConstrucao.Print(string.format("  [%d] %s at (%d,%d,%d) draw=%.1f",
            i, consumer.objectType, consumer.squareX, consumer.squareY, consumer.squareZ, consumer.powerDraw))
    end
    if totalCount > 10 then
        LKS_EletricidadeConstrucao.Print("  ... " .. (totalCount - 10) .. " more")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

LKS_EletricidadeConstrucao.RegisterModule("Building.ConsumerScanner", "2.0.0")

return LKS_EletricidadeConstrucao.Building.ConsumerScanner
