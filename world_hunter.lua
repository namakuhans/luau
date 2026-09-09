local CONFIG = {
    custom_letter = 5,
    with_number = true,
    readable = true,
    target_world_count = 5,
    delay_join_world = 4000,
    delay_action = 300,
    discord_webhook_url = "YOUR_DISCORD_WEBHOOK_URL_HERE"
}

if CONFIG.target_world_count > 20 then
    CONFIG.target_world_count = 20
end

math.randomseed(os.time())

local WORLD_LOCK_ID = 242
local WHITE_DOOR_ID = 6
local FIST_ID = 18

local VOWELS = {"A", "E", "I", "O", "U"}
local CONSONANTS = {"B", "C", "D", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "V", "W", "X", "Y", "Z"}
local ALL_LETTERS = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local LOCK_IDS = {
    [202] = true,
    [204] = true,
    [206] = true,
    [242] = true,
    [1796] = true,
    [7188] = true,
    [11550] = true,
    [4994] = true,
    [9640] = true,
    [2408] = true,
    [5814] = true
}

local function escapeJson(str)
    str = tostring(str or "")
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

local function encodeJson(val)
    local t = type(val)
    if t == "table" then
        local isArray = (#val > 0)
        local items = {}
        if isArray then
            for _, v in ipairs(val) do
                table.insert(items, encodeJson(v))
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(items, string.format('"%s":%s', escapeJson(k), encodeJson(v)))
            end
            return "{" .. table.concat(items, ",") .. "}"
        end
    elseif t == "string" then
        return '"' .. escapeJson(val) .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

local function sendWebhookNotification(title, description, color, fields)
    if not CONFIG.discord_webhook_url or CONFIG.discord_webhook_url == "" or CONFIG.discord_webhook_url == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        return
    end

    local payload = {
        username = "Bothax World Hunter",
        embeds = {
            {
                title = title,
                description = description,
                color = color or 65280,
                fields = fields or {},
                footer = {
                    text = "Bothax World Hunter Script"
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    local headers = {
        ["Content-Type"] = "application/json"
    }

    pcall(function()
        MakeRequest(CONFIG.discord_webhook_url, "POST", headers, encodeJson(payload), 5000)
    end)
end

local function generateWorldName(letterCount, isReadable, withNumber)
    local letters = {}
    local len = tonumber(letterCount) or 5
    if len < 1 then len = 5 end

    if isReadable then
        local startWithConsonant = (math.random(1, 2) == 1)
        for i = 1, len do
            local useConsonant = (i % 2 == 1)
            if not startWithConsonant then
                useConsonant = (i % 2 == 0)
            end
            if useConsonant then
                table.insert(letters, CONSONANTS[math.random(1, #CONSONANTS)])
            else
                table.insert(letters, VOWELS[math.random(1, #VOWELS)])
            end
        end
    else
        for i = 1, len do
            table.insert(letters, ALL_LETTERS[math.random(1, #ALL_LETTERS)])
        end
    end

    if withNumber then
        local numDigits = math.random(1, math.min(3, len))
        local replaced = {}
        local count = 0
        while count < numDigits do
            local pos = math.random(1, len)
            if not replaced[pos] then
                replaced[pos] = true
                letters[pos] = tostring(math.random(0, 9))
                count = count + 1
            end
        end
    end

    return table.concat(letters)
end

local function getWorldLockCount()
    local inv = GetInventory()
    if not inv then return 0 end
    for _, item in pairs(inv) do
        if item.id == WORLD_LOCK_ID then
            return item.amount or 0
        end
    end
    return 0
end

local function getTileCoords(tile)
    local x = tile.x or (tile.pos and tile.pos.x) or 0
    local y = tile.y or (tile.pos and tile.pos.y) or 0
    return x, y
end

local function isWorldLocked()
    local tiles = GetTiles()
    if not tiles then return false end

    for _, tile in pairs(tiles) do
        if tile.locktile and tile.locktile ~= 0 then
            return true
        end
        if tile.flags and tile.flags.locked then
            return true
        end
        if tile.fg and LOCK_IDS[tile.fg] then
            return true
        end
    end

    return false
end

local function findWhiteDoorTile()
    local tiles = GetTiles()
    if not tiles then return nil end

    for _, tile in pairs(tiles) do
        if tile.fg == WHITE_DOOR_ID then
            return tile
        end
    end
    return nil
end

local function placeTile(tileX, tileY, itemId)
    local localPlayer = GetLocal()
    local posX = localPlayer and localPlayer.pos and localPlayer.pos.x or (tileX * 32)
    local posY = localPlayer and localPlayer.pos and localPlayer.pos.y or (tileY * 32)

    local packet = {
        type = 3,
        value = itemId,
        px = tileX,
        py = tileY,
        x = posX,
        y = posY
    }

    SendPacketRaw(false, packet)
end

local function punchTile(tileX, tileY)
    placeTile(tileX, tileY, FIST_ID)
end

local function main()
    local lockedWorldCount = 0

    while lockedWorldCount < CONFIG.target_world_count do
        local targetWorldName = generateWorldName(CONFIG.custom_letter, CONFIG.readable, CONFIG.with_number)
        RequestJoinWorld(targetWorldName)
        Sleep(CONFIG.delay_join_world)

        local currentWorld = GetWorld()
        if currentWorld and currentWorld.name and currentWorld.name ~= "" then
            if not isWorldLocked() then
                local currentWl = getWorldLockCount()
                if currentWl <= 0 then
                    sendWebhookNotification(
                        "⚠️ Out of World Locks!",
                        string.format("Script dihentikan karena World Lock di inventory habis! Berhasil mengunci %d dari target %d world.", lockedWorldCount, CONFIG.target_world_count),
                        16711680,
                        {
                            { name = "🔒 Locked Worlds", value = string.format("%d / %d", lockedWorldCount, CONFIG.target_world_count), inline = true }
                        }
                    )
                    break
                end

                local doorTile = findWhiteDoorTile()
                if doorTile then
                    local doorX, doorY = getTileCoords(doorTile)
                    local lockX = doorX
                    local lockY = doorY - 1

                    if CheckPath(doorX, doorY) then
                        FindPath(doorX, doorY)
                        Sleep(500)
                    end

                    local targetTile = GetTile(lockX, lockY)
                    if targetTile and targetTile.fg and targetTile.fg ~= 0 then
                        local emptyNeighbors = {
                            { x = lockX - 1, y = lockY },
                            { x = lockX + 1, y = lockY },
                            { x = lockX, y = lockY - 1 }
                        }

                        for _, neighbor in ipairs(emptyNeighbors) do
                            local nTile = GetTile(neighbor.x, neighbor.y)
                            if nTile and (not nTile.fg or nTile.fg == 0) and CheckPath(neighbor.x, neighbor.y) then
                                FindPath(neighbor.x, neighbor.y)
                                Sleep(300)
                                break
                            end
                        end

                        local punchHits = 0
                        while punchHits < 25 do
                            local checkT = GetTile(lockX, lockY)
                            if not checkT or checkT.fg == 0 then
                                break
                            end
                            punchTile(lockX, lockY)
                            punchHits = punchHits + 1
                            Sleep(CONFIG.delay_action)
                        end
                    end

                    local checkLockPos = GetTile(lockX, lockY)
                    if not checkLockPos or checkLockPos.fg == 0 then
                        SetItemSelected(WORLD_LOCK_ID)
                        Sleep(200)

                        placeTile(lockX, lockY, WORLD_LOCK_ID)
                        Sleep(1000)

                        local verifyTile = GetTile(lockX, lockY)
                        if isWorldLocked() or (verifyTile and verifyTile.fg == WORLD_LOCK_ID) then
                            lockedWorldCount = lockedWorldCount + 1

                            sendWebhookNotification(
                                "🎉 World Berhasil Dikunci!",
                                string.format("World **%s** berhasil dikunci dengan World Lock!", currentWorld.name),
                                65280,
                                {
                                    { name = "🌍 World Name", value = currentWorld.name, inline = true },
                                    { name = "📊 Progress Target", value = string.format("%d / %d World", lockedWorldCount, CONFIG.target_world_count), inline = true },
                                    { name = "💎 Sisa WL di Inventory", value = tostring(getWorldLockCount()), inline = true }
                                }
                            )
                        end
                    end
                end
            end
        end

        Sleep(CONFIG.delay_action)
    end
end

RunThread(main)
