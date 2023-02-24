local sock = require "libs.sock"
local bitser = require "libs.bitser"
local lovezip = require "libs.love-zip"
local steamy = require "."
local pprint = require "libs.pprint"

local isServer = arguments.server_mode
local isSend = not isServer

-- Set to true when we get our first print statement back from the server
-- when the --console flag is set.
local firstRemotePrint = false

local isAttemptingReconnect = false

local games = {}
local games_modified = {}
local function getGameList()
    -- Create a directory to hold games if it doesn't exist
    love.filesystem.createDirectory("steamy_games")
    games = love.filesystem.getDirectoryItems("steamy_games")
    -- Remove any non-zip or non-love files
    for i = #games, 1, -1 do
        local game = games[i]
        if not game:match("%.zip$") and not game:match("%.love$") then
            table.remove(games, i)
        end
    end

    -- Create table of modified times in the same order
    for i, game in ipairs(games) do
        games_modified[i] = love.filesystem.getInfo("steamy_games/" .. game)
    end
end

function love.load()
    getGameList()
    steamy:load()
    steamy:setCallback("download", getGameList)
    if isServer and not steamy.isBooting then
        steamy:startServer("*")
    end
end

if isSend then
    local gameSent = false
    print("Attempting to launch game remotely...")
    client = sock.newClient(arguments.host, 3621)
    client:setSerialization(bitser.dumps, bitser.loads)
    client:on("connect", function(data)
        if not gameSent then
            local name = arguments.name or "game"
            print("Connected to server!")
            print("Zipping game...")
            lovezip.writeZip(arguments.dir, "steamy_games/" .. name .. ".zip")
            print("Zipped!")

            local zip = love.filesystem.read("steamy_games/" .. name .. ".zip")
            print("Sending game...")
            client:send("download", zip)
            gameSent = true
            print("Sent, waiting for response...")
        end
    end)

    client:on("print", function(data)
        print(data)
    end)

    client:on("disconnect", function()
        if not isAttemptingReconnect then
            print("Disconnected, shutting down.")
            love.event.quit()
        else
            print("Attempting reconnect...")
            client:connect()
            print("Connected to server! Now receiving print statements remotely.")
            print("------------------------------------------------\n")
            isAttemptingReconnect = false
        end
    end)

    client:on("downloaded", function(success)
        if success then
            print("Game successfully sent, remotely restarting and booting!")
            if not arguments.upload_only then client:send("boot", "game.zip") end
            if not arguments.console then
                love.event.quit()
            else
                print("Reconnecting to server for console output...")

                isAttemptingReconnect = true
                if isAttemptingReconnect then client:disconnectLater() end
            end
        end
    end)

    client:connect()
end

local hearts = {}
function love.update(dt)
    steamy:update()
    if isSend then client:update() end

    if isServer then
        -- Update hearts to fade upwards and side to side using cos, iterate backwards to remove hearts
        for i = #hearts, 1, -1 do
            local heart = hearts[i]
            heart.y = heart.y - 100 * dt
            heart.x = heart.x + math.cos(love.timer.getTime() * heart.swaySpeed) * 100 * dt
            -- fade alpha as it gets near the top
            heart.alpha = heart.alpha - 0.5 * dt
            -- bounce the scale using cos
            heart.scale = heart.initalScale + math.cos(love.timer.getTime() * heart.bounceSpeed) * 0.1

            if heart.alpha <= 0 then
                table.remove(hearts, i)
            end
        end

    end
end

if isServer then
    local selected = 1
    local joystick = love.joystick.getJoysticks()[1]

    -- Pretty display stuff
    local bigFont = love.graphics.newFont("assets/AOTFShinGoProRegular.otf", 32)
    local smallFont = love.graphics.newFont("assets/AOTFShinGoProRegular.otf", 24)
    local hackFont = love.graphics.newFont("assets/Hack-Regular.ttf", 24)
    local smallHackFont = love.graphics.newFont("assets/Hack-Regular.ttf", 20)
    local chibi = love.graphics.newImage("assets/chibi-small.png")
    local chibiWidth = chibi:getWidth()
    local chibiHeight = chibi:getHeight()

    love.keyboard.setKeyRepeat(true)

    local heartImages = {
        love.graphics.newImage("assets/heart.png"),
        love.graphics.newImage("assets/heart2.png"),
        love.graphics.newImage("assets/heart4.png"),
    }
    local lastHeart = 1

    function love.draw()
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()

        local chibiX = screenW - chibiWidth / 2
        local chibiY = screenH - chibiHeight / 2
        if not steamy.hasBooted then
            love.graphics.setBackgroundColor(0.15, 0.15, 0.15)
            love.graphics.setFont(bigFont)
            love.graphics.print("Videah's Steamy LÖVE Launcher", 32, 32)
            if joystick then
                love.graphics.print("Press A button to boot selected game", 32, 74)
            else
                love.graphics.print("Press enter key to boot selected game", 32, 74)
            end

            if #games == 0 then
                love.graphics.setFont(smallFont)
                love.graphics.print("No games have been loaded/booted yet.", 32, 128)
            end
            for i, game in ipairs(games) do
                if i == selected then
                    -- flash the color between 0.5 and 1
                    local b = 0.55 + 0.25 * math.sin(love.timer.getTime() * 5)
                    love.graphics.setColor(b, 0.2, 0.2)
                    love.graphics.rectangle("fill", 32, 128 + (i - 1) * 32, screenW - 64, 32)
                    love.graphics.setColor(1, 1, 1)
                end
                love.graphics.setFont(smallFont)
                love.graphics.print(game, 36, 130 + (i - 1) * 32)
                -- Draw last modified time
                local info = games_modified[i]
                local date = os.date("%c", info.modtime)
                love.graphics.print(date, screenW - 32 - smallFont:getWidth(date) - 4, 130 + (i - 1) * 32)
            end

            love.graphics.setFont(hackFont)
            love.graphics.print("Server running on " .. arguments.host .. ":" .. arguments.port, 32, screenH - 96)

            local command = {
                {1, 1, 1},
                "Run command to upload: ",
                {0.2, 0.8, 0.2},
                "steamy ",
                {0.75, 0.4, 0.2},
                "<",
                {0.6, 0.6, 0.6},
                "dir with main.lua",
                {0.75, 0.4, 0.2},
                "> <",
                {0.6, 0.6, 0.6},
                "this devices ip",
                {0.75, 0.4, 0.2},
                ">"
            }
            love.graphics.setFont(smallHackFont)
            love.graphics.print(command, 32, screenH - 56)
            love.graphics.draw(chibi, chibiX - 16, chibiY - 16, math.sin(love.timer.getTime() * 4) * 0.15, 1, 1, chibiWidth/2, chibiHeight/2)

            -- Draw hearts
            for i = #hearts, 1, -1 do
                local heart = hearts[i]
                love.graphics.setColor(1, 1, 1, heart.alpha)
                love.graphics.draw(heartImages[heart.image], heart.x, heart.y, 0, 0.2 * heart.scale, 0.2 * heart.scale)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    function love.keypressed(key)
        if not steamy.hasBooted then
            if not steamy.hasBooted and key == "return" and #games > 0 then steamy:restartAndBoot(games[selected]) end
            if key == "up" then
                if selected == 1 then selected = #games else selected = math.max(1, selected - 1) end
            end
            if key == "down" then
                if selected == #games then selected = 1 else selected = math.min(#games, selected + 1) end
            end
        end
    end

    function love.gamepadpressed(_, button)
        if not steamy.hasBooted and button == "a" and #games > 0 then steamy:restartAndBoot(games[selected]) end
        if button == "up" then selected = math.max(1, selected - 1) end
        if button == "down" then selected = math.min(#games, selected + 1) end
    end

    function love.mousepressed(x, y, button)

        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        local headpatArea = {
            {x = screenW - 200, y = screenH - 280},
            {x = screenW - 40, y = screenH - 280},
            {x = screenW - 200, y = screenH - 130},
            {x = screenW - 40, y = screenH - 130},
        }

        -- check if click is in the headpat area (rectangle)
        if x > headpatArea[1].x and x < headpatArea[2].x and y > headpatArea[1].y and y < headpatArea[3].y then
            -- If so, add a heart to the hearts table
            local heart = {
                x = x - 12,
                y = y - 12,
                scale = 0.1,
                initalScale = math.random(0.8, 1),
                alpha = 1.5,
                swaySpeed = math.random(3, 5),
                bounceSpeed = math.random(5, 10),
                image = math.random(1, #heartImages)
            }
            -- Make sure the image wasn't the same as the last one
            if heart.image == lastHeart then
                heart.image = heart.image + 1
                if heart.image > #heartImages then heart.image = 1 end
            end
            lastHeart = heart.image
            table.insert(hearts, heart)
        end
    end
end