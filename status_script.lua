-- ==============================================================================
-- LUCIFER BOT MONITORING & BANNED NOTIFIER SCRIPT
-- Documentation: https://github.com/Kwelpinator/Lucifer-docs
-- ==============================================================================

-- CONFIGURATION / KONFIGURASI
local STATUS_WEBHOOK_URL = "YOUR_STATUS_WEBHOOK_URL_HERE"
local BANNED_WEBHOOK_URL = "YOUR_BANNED_WEBHOOK_URL_HERE"
local DISCORD_USER_ID    = "YOUR_DISCORD_USER_ID_HERE" -- Contoh: "123456789012345678"
local UPDATE_INTERVAL    = 3 -- Interval update status realtime dalam detik

-- SCRIPT MODE:
-- Set USE_DYNAMIC_BOTS = true untuk mendeteksi SELURUH bot secara otomatis via getBots().
-- Jika getBots() tidak tersedia di versi Lucifer Anda, isi daftar nama bot di BOT_NAMES.
local USE_DYNAMIC_BOTS   = true

local BOT_NAMES = {
    -- "Bot1",
    -- "Bot2",
    -- "Bot3"
}

-- ==============================================================================
-- HELPER FUNCTIONS & DATA STRUCTURES
-- ==============================================================================

-- High Saturation / Vivid Color Generator for Discord Embeds
local VIVID_COLORS = {
    0xFF0000, -- Vivid Red
    0x00FF00, -- Neon Green
    0x00FFFF, -- Electric Cyan
    0xFF00FF, -- Bright Magenta
    0xFFFF00, -- Vivid Yellow
    0xFF5500, -- Bright Orange
    0x9900FF, -- Electric Purple
    0xFF007F, -- Hot Pink
    0x00FF99, -- Spring Green
    0x0099FF  -- Deep Sky Blue
}

local function getRandomVividColor()
    return VIVID_COLORS[math.random(1, #VIVID_COLORS)]
end

-- Converts BotStatus enum to human readable string with status indicators
local function getStatusString(status)
    if status == BotStatus.online then
        return "🟢 Online"
    elseif status == BotStatus.offline then
        return "🔴 Offline"
    elseif status == BotStatus.account_banned then
        return "⛔ Account Banned"
    elseif status == BotStatus.location_banned then
        return "⛔ Location Banned"
    elseif status == BotStatus.account_restricted then
        return "⛔ Account Restricted"
    elseif status == BotStatus.wrong_password then
        return "❌ Wrong Password"
    elseif status == BotStatus.captcha_requested then
        return "⚠️ Captcha Requested"
    elseif status == BotStatus.maintenance then
        return "🛠️ Maintenance"
    elseif status == BotStatus.server_overload or status == BotStatus.server_busy then
        return "⏳ Server Busy"
    elseif status == BotStatus.getting_server_data or status == BotStatus.bypassing_server_data or status == BotStatus.changing_subserver then
        return "🔄 Connecting"
    elseif status == BotStatus.stopped then
        return "⏹️ Stopped"
    else
        return "❓ " .. tostring(status)
    end
end

-- Checks if the given status indicates that the bot is banned
local function isBannedStatus(status)
    return status == BotStatus.account_banned
        or status == BotStatus.location_banned
        or status == BotStatus.account_restricted
end

-- Retrieves table of all bot instances dynamically or from BOT_NAMES
local function getAllBotsList()
    local botList = {}

    if USE_DYNAMIC_BOTS and type(getBots) == "function" then
        local rawBots = getBots()
        if type(rawBots) == "table" then
            for _, b in pairs(rawBots) do
                if type(b) == "userdata" or type(b) == "table" then
                    table.insert(botList, b)
                end
            end
        end
    end

    -- Fallback jika getBots() kosong atau USE_DYNAMIC_BOTS = false
    if #botList == 0 and #BOT_NAMES > 0 then
        for _, name in ipairs(BOT_NAMES) do
            local b = getBot(name)
            if b then
                table.insert(botList, b)
            end
        end
    end

    -- Jikalau hanya 1 bot utama (parent bot)
    if #botList == 0 and type(getBot) == "function" then
        local mainBot = getBot()
        if mainBot then
            table.insert(botList, mainBot)
        end
    end

    return botList
end

-- Table to track bots that have already triggered a banned notification (1 time notification)
local notifiedBans = {}

-- Function to send Banned Notification Webhook with Discord User Tag
-- NAMA BOT TIDAK DISENSOR PADA EMBED BANNED
local function sendBannedNotification(botName, bot, status)
    local webhook = Webhook.new(BANNED_WEBHOOK_URL)
    webhook.content = string.format("<@%s> 🚨 **BOT TERBANNED DETECTED!**", DISCORD_USER_ID)
    webhook.username = "Lucifer Ban Monitor"

    webhook.embed1.use = true
    webhook.embed1.title = "🚨 BOT BANNED ALERT"
    webhook.embed1.description = string.format("Bot **%s** telah terdeteksi terkena Banned!", botName)
    webhook.embed1.color = 0xFF0000 -- Red color for alert

    local worldName = "Unknown / Offline"
    local levelVal = "N/A"
    local gemVal = "N/A"

    if bot then
        if bot:isInWorld() then
            local w = bot:getWorld()
            if w and w.name ~= "" then
                worldName = w.name
            end
        end
        if bot.level then levelVal = tostring(bot.level) end
        if bot.gem_count then gemVal = tostring(bot.gem_count) end
    end

    webhook.embed1:addField("🤖 Bot Name", botName, true)
    webhook.embed1:addField("📌 Status Detail", getStatusString(status), true)
    webhook.embed1:addField("🌍 World", worldName, true)
    webhook.embed1:addField("⭐ Level", levelVal, true)
    webhook.embed1:addField("💎 Gems", gemVal, true)
    webhook.embed1:addField("⏰ Time", os.date("%Y-%m-%d %H:%M:%S"), false)

    webhook.embed1.footer.text = "Lucifer Bot Banned Detector"

    webhook:send()
    print(string.format("[BAN NOTIFIER] Sent ban alert for bot: %s", botName))
end

-- Function to initialize Status Webhook and extract Discord Message ID
local function createInitialStatusMessage()
    local webhook = Webhook.new(STATUS_WEBHOOK_URL)
    webhook.username = "Lucifer Status Monitor"
    webhook.embed1.use = true
    webhook.embed1.title = "📊 Lucifer Bots Live Status"
    webhook.embed1.description = "Initializing status monitor..."
    webhook.embed1.color = getRandomVividColor()
    webhook.embed1.footer.text = "Lucifer Bot Monitor • Realtime Status"

    local payload = ""
    if type(webhook.makeContent) == "function" then
        payload = webhook:makeContent()
    else
        -- Manual JSON construction fallback if makeContent is unavailable
        payload = string.format([[{"username":"Lucifer Status Monitor","embeds":[{"title":"📊 Lucifer Bots Live Status","description":"Initializing status monitor...","color":%d}]}]], getRandomVividColor())
    end

    local client = HttpClient.new()
    client.url = STATUS_WEBHOOK_URL .. "?wait=true"
    client.method = Method.post
    client.headers["Content-Type"] = "application/json"
    client.content = payload

    local response = client:request()
    if response and response.status >= 200 and response.status < 300 then
        local msgId = response.body:match('"id"%s*:%s*"(%d+)"')
        if msgId then
            print(string.format("[STATUS MONITOR] Initial message created successfully. Message ID: %s", msgId))
            return msgId
        end
    end

    print("[STATUS MONITOR] Failed to get Message ID from initial post. Will fallback to regular send.")
    return nil
end

-- Function to edit message via HttpClient PATCH as robust fallback
local function editWebhookMessage(msgId, webhook)
    if type(webhook.edit) == "function" then
        pcall(function() webhook:edit(msgId) end)
        return
    end

    -- Fallback to HttpClient PATCH request
    local client = HttpClient.new()
    client.url = STATUS_WEBHOOK_URL .. "/messages/" .. tostring(msgId)
    client.method = Method.patch
    client.headers["Content-Type"] = "application/json"
    if type(webhook.makeContent) == "function" then
        client.content = webhook:makeContent()
    end
    client:request()
end

-- ==============================================================================
-- MAIN MONITORING LOOP
-- ==============================================================================

print("==================================================")
print(" Starting Lucifer Bot Realtime Monitor & Ban Notifier")
print("==================================================")

math.randomseed(os.time())

-- Step 1: Post initial message and obtain message ID for subsequent editing
local messageId = createInitialStatusMessage()

while true do
    local webhook = Webhook.new(STATUS_WEBHOOK_URL)
    webhook.username = "Lucifer Status Monitor"

    local botsList = getAllBotsList()

    webhook.embed1.use = true
    webhook.embed1.title = "📊 Lucifer Bots Live Status"
    webhook.embed1.description = string.format("Total Bot Monitored: **%d**\nLast Updated: **%s**", #botsList, os.date("%H:%M:%S"))
    webhook.embed1.color = getRandomVividColor()
    webhook.embed1.footer.text = "Lucifer Bot Monitor • Updated Every 3s"

    local onlineCount = 0
    local bannedCount = 0
    local offlineCount = 0

    -- Iterate over all monitored bots
    for idx, bot in ipairs(botsList) do
        local botName = (bot and bot.name and bot.name ~= "") and bot.name or ("Bot_" .. idx)
        local statusStr = "🔴 Offline"
        local worldStr = "N/A"

        if bot then
            local status = bot.status
            statusStr = getStatusString(status)

            -- Count statistics
            if status == BotStatus.online then
                onlineCount = onlineCount + 1
            elseif isBannedStatus(status) then
                bannedCount = bannedCount + 1
            else
                offlineCount = offlineCount + 1
            end

            -- Retrieve world name
            if bot:isInWorld() then
                local world = bot:getWorld()
                if world and world.name ~= "" then
                    worldStr = world.name
                else
                    worldStr = "In World"
                end
            else
                worldStr = "Lobby / Exit"
            end

            -- Ban Check & Notification (Triggers once per bot)
            if isBannedStatus(status) then
                if not notifiedBans[botName] then
                    notifiedBans[botName] = true
                    sendBannedNotification(botName, bot, status)
                end
            end
        else
            offlineCount = offlineCount + 1
        end

        -- SENSOR NAMA BOT DAN NAMA WORLD UNTUK EMBED STATUS STATUS VIA ||
        local censoredBotName = "||" .. botName .. "||"
        local censoredWorldStr = (worldStr == "N/A" or worldStr == "Lobby / Exit" or worldStr == "In World")
            and worldStr
            or ("||" .. worldStr .. "||")

        -- Add field for each bot
        local fieldValue = string.format("• Status: **%s**\n• World: **%s**", statusStr, censoredWorldStr)
        webhook.embed1:addField("🤖 " .. censoredBotName, fieldValue, true)
    end

    -- Summary Field
    local summaryText = string.format("🟢 Online: **%d** | 🔴 Offline: **%d** | ⛔ Banned: **%d**", onlineCount, offlineCount, bannedCount)
    webhook.embed1:addField("📈 Summary", summaryText, false)

    -- Update Webhook via Edit or Send fallback
    if messageId then
        editWebhookMessage(messageId, webhook)
    else
        messageId = createInitialStatusMessage()
    end

    sleep(UPDATE_INTERVAL * 1000)
end
