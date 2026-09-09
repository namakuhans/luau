-- ==============================================================================
-- BOTHAI / BOTHAX WORLD HUNTER SCRIPT
-- Documentation: https://github.com/dravenox/bothax/blob/main/README.md
-- ==============================================================================

-- CONFIGURATION / KONFIGURASI
local CONFIG = {
    custom_letter = 5,          -- Panjang huruf nama world (misal: 5 = 5 huruf)
    with_number = true,         -- Sisipkan angka secara acak (maksimal 3 angka)
    readable = true,            -- true = nama bisa dibaca (konsonan-vokal), false = acak murni
    target_world_count = 5,     -- Jumlah world tanpa lock yang ditargetkan untuk dikunci (maksimal 20)
    delay_join_world = 4000,    -- Delay saat berpindah antar world dalam milidetik (ms)
    delay_action = 300,         -- Delay antar aksi (punch/place) dalam milidetik (ms)
    discord_webhook_url = "YOUR_DISCORD_WEBHOOK_URL_HERE" -- Link Webhook Discord
}

-- Memastikan batas maksimal target world adalah 20
if CONFIG.target_world_count > 20 then
    CONFIG.target_world_count = 20
end

math.randomseed(os.time())

-- ==============================================================================
-- CONSTANTS & TABLES
-- ==============================================================================
local WORLD_LOCK_ID = 242
local WHITE_DOOR_ID = 6
local FIST_ID = 18

local VOWELS = {"A", "E", "I", "O", "U"}
local CONSONANTS = {"B", "C", "D", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "V", "W", "X", "Y", "Z"}
local ALL_LETTERS = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local LOCK_IDS = {
    [202] = true,   -- Small Lock
    [204] = true,   -- Big Lock
    [206] = true,   -- Huge Lock
    [242] = true,   -- World Lock
    [1796] = true,  -- Diamond Lock
    [7188] = true,  -- Emerald Lock
    [11550] = true, -- Ruby Lock
    [4994] = true,  -- Builder's Lock
    [9640] = true,  -- Master Lock
    [2408] = true,  -- Robotic Lock
    [5814] = true   -- Guild Lock
}

-- ==============================================================================
-- HELPER FUNCTIONS
-- ==============================================================================

-- Fungsi log ke konsol Bothax
local function logMessage(msg)
    if type(LogToConsole) == "function" then
        LogToConsole("`9[World Hunter]`` " .. tostring(msg))
    else
        print("[World Hunter] " .. tostring(msg))
    end
end

-- Escape string untuk JSON formatting
local function escapeJson(str)
    str = tostring(str or "")
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

-- Generator JSON sederhana untuk payload Webhook
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

-- Mengirim notifikasi embed ke Webhook Discord
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
                color = color or 65280, -- Default Green (0x00FF00)
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
        if type(MakeRequest) == "function" then
            MakeRequest(CONFIG.discord_webhook_url, "POST", headers, encodeJson(payload), 5000)
        end
    end)
end

-- Generator Nama World secara acak
local function generateWorldName(letterCount, isReadable, withNumber)
    local letters = {}
    local len = tonumber(letterCount) or 5
    if len < 1 then len = 5 end

    if isReadable then
        -- Pola konsonan dan vokal bergantian
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
        -- Acak murni tanpa pola
        for i = 1, len do
            table.insert(letters, ALL_LETTERS[math.random(1, #ALL_LETTERS)])
        end
    end

    -- Menyisipkan angka acak (maksimal 3 angka) jika with_number = true
    if withNumber then
        local numDigits = math.random(1, math.min(3, len))
        for _ = 1, numDigits do
            local randNum = tostring(math.random(0, 9))
            local insertPos = math.random(1, #letters + 1)
            table.insert(letters, insertPos, randNum)
        end
    end

    return table.concat(letters)
end

-- Menghitung jumlah World Lock di inventory
local function getWorldLockCount()
    if type(GetInventory) ~= "function" then return 0 end
    local inv = GetInventory()
    if not inv then return 0 end
    for _, item in ipairs(inv) do
        if item.id == WORLD_LOCK_ID then
            return item.amount or 0
        end
    end
    return 0
end

-- Memeriksa apakah world memiliki lock di tile manapun
local function isWorldLocked()
    if type(GetTiles) ~= "function" then return false end
    local tiles = GetTiles()
    if not tiles then return false end

    for _, tile in ipairs(tiles) do
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

-- Mencari lokasi White Door (pintu masuk world)
local function findWhiteDoorTile()
    if type(GetTiles) ~= "function" then return nil end
    local tiles = GetTiles()
    if not tiles then return nil end

    for _, tile in ipairs(tiles) do
        if tile.fg == WHITE_DOOR_ID then
            return tile
        end
    end
    return nil
end

-- Mengirim paket place / punch
local function placeTile(tileX, tileY, itemId)
    if type(SendPacketRaw) == "function" then
        local localPlayer = (type(GetLocal) == "function") and GetLocal() or nil
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
end

local function punchTile(tileX, tileY)
    placeTile(tileX, tileY, FIST_ID)
end

-- ==============================================================================
-- MAIN HUNTING LOOP
-- ==============================================================================

local function main()
    logMessage("==============================================")
    logMessage(" Starting World Hunting Script...")
    logMessage(string.format(" Target World Count: %d", CONFIG.target_world_count))
    logMessage(string.format(" Letter Length: %d | Readable: %s | With Number: %s",
        CONFIG.custom_letter, tostring(CONFIG.readable), tostring(CONFIG.with_number)))
    logMessage("==============================================")

    local lockedWorldCount = 0

    while lockedWorldCount < CONFIG.target_world_count do
        -- 1. Cek Ketersediaan World Lock di Inventory
        local currentWl = getWorldLockCount()
        if currentWl <= 0 then
            local alertTitle = "⚠️ Out of World Locks!"
            local alertMsg = string.format("Script dihentikan karena World Lock di inventory habis! Berhasil mengunci %d dari target %d world.",
                lockedWorldCount, CONFIG.target_world_count)

            logMessage("ERROR: World Lock di inventory habis! Menghentikan script...")
            sendWebhookNotification(alertTitle, alertMsg, 16711680, { -- Red Color
                { name = "🔒 Locked Worlds", value = string.format("%d / %d", lockedWorldCount, CONFIG.target_world_count), inline = true }
            })
            break
        end

        -- 2. Generate Nama World Baru
        local targetWorldName = generateWorldName(CONFIG.custom_letter, CONFIG.readable, CONFIG.with_number)
        logMessage(string.format("Mencoba bergabung ke world: %s ...", targetWorldName))

        -- 3. Masuk ke World
        if type(RequestJoinWorld) == "function" then
            RequestJoinWorld(targetWorldName)
        end

        Sleep(CONFIG.delay_join_world)

        -- Verifikasi apakah berhasil masuk world
        local currentWorld = (type(GetWorld) == "function") and GetWorld() or nil
        if not currentWorld or not currentWorld.name or currentWorld.name == "" then
            logMessage("Gagal atau sedang memuat world, mencoba world selanjutnya...")
        else
            logMessage(string.format("Berhasil masuk ke world: %s", currentWorld.name))

            -- 4. Cek Apakah World Memiliki Lock
            if isWorldLocked() then
                logMessage(string.format("World %s sudah terkunci (memiliki Lock). Melewati world ini...", currentWorld.name))
            else
                logMessage(string.format("🎉 World %s TIDAK MEMILIKI LOCK!", currentWorld.name))

                -- 5. Cari White Door
                local doorTile = findWhiteDoorTile()
                if not doorTile then
                    logMessage("White Door tidak ditemukan di world ini! Melewati...")
                else
                    local lockX = doorTile.x
                    local lockY = doorTile.y - 1

                    logMessage(string.format("White door ditemukan di (%d, %d). Posisi target Lock: (%d, %d)",
                        doorTile.x, doorTile.y, lockX, lockY))

                    -- Pindah mendekati White Door
                    local hasPath = true
                    if type(CheckPath) == "function" then
                        hasPath = CheckPath(doorTile.x, doorTile.y)
                    end

                    if hasPath then
                        if type(FindPath) == "function" then
                            FindPath(doorTile.x, doorTile.y)
                        end
                        Sleep(500)
                    else
                        logMessage("Tidak ada jalur langsung ke White Door. Mencoba mencari jalur terdekat atau break...")
                    end

                    -- 6. Cek & Bersihkan Blok di Atas White Door (jika ada)
                    local targetTile = (type(GetTile) == "function") and GetTile(lockX, lockY) or nil
                    if targetTile and targetTile.fg and targetTile.fg ~= 0 then
                        logMessage(string.format("Terdapat blok (ID: %d) di atas White Door. Melakukan break...", targetTile.fg))

                        -- Pukuli blok sampai hancur (fg == 0) atau maksimal 25 pukulan
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

                    -- Re-check apakah posisi lock sudah kosong
                    local checkLockPos = (type(GetTile) == "function") and GetTile(lockX, lockY) or nil
                    if checkLockPos and checkLockPos.fg ~= 0 then
                        logMessage("Gagal menghancurkan blok di atas White Door. Melewati world ini...")
                    else
                        -- 7. Pasang World Lock
                        logMessage("Memasang World Lock di atas White Door...")

                        if type(SetItemSelected) == "function" then
                            SetItemSelected(WORLD_LOCK_ID)
                        end
                        Sleep(200)

                        placeTile(lockX, lockY, WORLD_LOCK_ID)
                        Sleep(1000)

                        -- 8. Konfirmasi Pemasangan Lock
                        local verifyTile = (type(GetTile) == "function") and GetTile(lockX, lockY) or nil
                        if isWorldLocked() or (verifyTile and verifyTile.fg == WORLD_LOCK_ID) then
                            lockedWorldCount = lockedWorldCount + 1
                            logMessage(string.format("✅ SUKSES! World %s berhasil dikunci! Progress: [%d/%d]",
                                currentWorld.name, lockedWorldCount, CONFIG.target_world_count))

                            -- Kirim Webhook Discord
                            sendWebhookNotification(
                                "🎉 World Berhasil Dikunci!",
                                string.format("World **%s** berhasil dikunci dengan World Lock!", currentWorld.name),
                                65280, -- Green
                                {
                                    { name = "🌍 World Name", value = currentWorld.name, inline = true },
                                    { name = "📊 Progress Target", value = string.format("%d / %d World", lockedWorldCount, CONFIG.target_world_count), inline = true },
                                    { name = "💎 Sisa WL di Inventory", value = tostring(getWorldLockCount()), inline = true }
                                }
                            )
                        else
                            logMessage("Pemasangan World Lock gagal atau terhalang. Melewati world ini...")
                        end
                    end
                end
            end
        end

        Sleep(CONFIG.delay_action)
    end

    logMessage("==============================================")
    logMessage(string.format(" World Hunter Selesai! Total World Dikunci: %d", lockedWorldCount))
    logMessage("==============================================")
end

-- Menjalankan script menggunakan RunThread jika tersedia, atau eksekusi langsung
if type(RunThread) == "function" then
    RunThread(main)
else
    main()
end
