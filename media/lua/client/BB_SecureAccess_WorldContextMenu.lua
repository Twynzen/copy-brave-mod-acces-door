-- ************************************************************************
-- **        ██████  ██████  █████  ██   ██ ███████ ███   ██          **
-- **        ██   ██ ██   ██ ██   ██ ██   ██ ██      ████  ██          **
-- **        ██████  ██████  ███████ ██   ██ █████   ██ ██ ██          **
-- **        ██   ██ ██   ██ ██   ██ ██   ██ ██      ██  ██ ██          **
-- **        ██████  ██   ██ ██   ██  █████  ███████ ██   ████          **
-- ************************************************************************
-- ** All rights reserved. This content is protected by © Copyright law. **
-- ************************************************************************

-- Table to store cooldown times for each door
local doorCooldowns = {}

local colorMapping = {
    B = "Blue",
    C = "Cyan",
    G = "Green",
    O = "Orange",
    P = "Purple",
    R = "Red",
    W = "White",
    Y = "Yellow"
}

-- Function to check if the door is in cooldown
local function isDoorInCooldown(doorName)
    local currentTime = os.time()
    if doorCooldowns[doorName] and (currentTime - doorCooldowns[doorName]) < 5 then
        -- If the current time is less than the cooldown time (5 seconds), the door is in cooldown
        return true
    else
        -- If the door is not in cooldown, remove the previous record
        doorCooldowns[doorName] = nil
        return false
    end
end

local function tryOpenDoor(squares, properties, playerObj, keycardItem)
    local doorName = properties[1].fullName  -- The full name of the door

    -- Check if the door is in cooldown
    if isDoorInCooldown(doorName) then
        return  -- No notification to the player, just exit the function if in cooldown
    end

    -- If the door is not in cooldown, proceed with the interaction
    if BB_SecureAccess_Utils.DistanceBetween(playerObj, squares[1]) > 1 then
        if luautils.walkAdj(playerObj, squares[1]) then
            ISTimedActionQueue.add(BB_SecureAccess_TimedAction:InsertKeycard(squares, properties, playerObj, keycardItem))
        end
    else
        ISTimedActionQueue.add(BB_SecureAccess_TimedAction:InsertKeycard(squares, properties, playerObj, keycardItem))
    end

    -- Start the cooldown once the door is successfully opened
    doorCooldowns[doorName] = os.time()
end

local function handleSquareLogic(selectedSq)
    local objs = selectedSq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)

        if instanceof(obj, "IsoObject") then
            local sprite = obj:getSprite()
            if not sprite then return end

            local properties = sprite:getProperties()
            if properties:Is("CustomName") then
                local name = properties:Val("CustomName")
                if not name then return end

                local lockState = string.sub(name, 3, 3)
                if lockState == "O" then return end

                local colorType = string.sub(name, 4, 4)

                -- Garage Doors
                if string.len(name) == 5 then
                    colorType = string.sub(name, 5, 5)
                end

                local args = { fullName = name, colorType = colorType }
                return selectedSq, args
            end
        end
    end
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    if playerObj:getVehicle() then return end

    local objs = clickedSquare:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)

        if instanceof(obj, "IsoObject") then
            local sprite = obj:getSprite()
            if sprite then
                local spriteProps = sprite:getProperties()
                if spriteProps:Is("CustomName") then
                    local name = spriteProps:Val("CustomName")
                    if name then
                        local lockState = string.sub(name, 3, 3)
                        if lockState == "C" then
                            local colorType = string.sub(name, 4, 4)
                            local isGarage = false

                            -- Garage Doors
                            if string.len(name) == 5 then
                                colorType = string.sub(name, 5, 5)
                                isGarage = true
                            end

                            local playerInv = playerObj:getInventory()
                            local cardColor = colorMapping[colorType]
                            if not cardColor then return end

                            local keycardItem = playerInv:getItemFromType("Base." .. cardColor .. "KeyCard")
                            if not keycardItem then return end

                            local args = { fullName = name, colorType = colorType }
                            local sqX, sqY, sqZ = clickedSquare:getX(), clickedSquare:getY(), clickedSquare:getZ()

                            local squares = { clickedSquare }
                            local properties = { args }

                            -- Handle adjacent squares if isGarage is true
                            if isGarage then
                                for dx = -2, 2 do
                                    for dy = -2, 2 do
                                        local x, y = sqX + dx, sqY + dy
                                        local adjacentSquare = getCell():getGridSquare(x, y, sqZ)
                                        if adjacentSquare then
                                            local selectedSq, props, item = handleSquareLogic(adjacentSquare)
                                            if selectedSq then
                                                table.insert(squares, selectedSq)
                                                table.insert(properties, props)
                                            end
                                        end
                                    end
                                end
                            end

                            context:addOptionOnTop(getText("ContextMenu_Insert") .. " " .. keycardItem:getName(), squares, tryOpenDoor, properties, playerObj, keycardItem)
                        end
                    end
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
