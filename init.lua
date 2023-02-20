local sock = require "libs.sock"
local bitser = require "libs.bitser"

local steamy = {
    isBooting = false,
    hasBooted = false,
    callbacks = {},
}

function steamy:setCallback(name, callback)
    self.callbacks[name] = callback
end

function steamy:restartAndBoot(name)
    print("Checking '" .. name .. "' successfully mounts ...")
    local success = love.filesystem.mount("steamy_games/" .. name, "/")
    if success then
        print("Game successfully mounted... restarting and booting!")
        love.filesystem.write(".booting.lock", name)
        love.event.quit("restart")
    end
end

function steamy:bootGame(name)
    print("Attempting to boot game ...")
    local success = love.filesystem.mount("steamy_games/" .. name, "/")
    if success then
        print("Game successfully mounted... booting!")

        -- Make sure we clear already loaded modules
        package.loaded["."] = nil
        package.loaded["conf"] = nil
        package.loaded["main"] = nil
        package.loaded["libs.sock"] = nil
        package.loaded["libs.bitser"] = nil
        package.loaded["libs.pprint"] = nil
        package.loaded["libs.love-zip"] = nil
        package.loaded["libs.love-zip.nativefs"] = nil
        package.loaded["libs.love-zip.nativefs.nativefs"] = nil

        love.init()
        self.hasBooted = true
    end
end

function steamy:startServer(host)
    self.server = sock.newServer(host, 3621)
    self.server:setSerialization(bitser.dumps, bitser.loads)

    self.server:on("connect", function(data, client)
        print("Client connected!")
    end)

    self.server:on("download", function(data, client)
        print("Game received, saving to disk ...")
        local success = love.filesystem.write("steamy_games/game.zip", data)
        if success then
            print("Game saved!")
            self.callbacks["download"]()
            client:send("downloaded", true)
        else
            print("Failed to save game!")
            client:send("downloaded", false)
        end
    end)

    self.server:on("boot", function(name, client)
        self:restartAndBoot(name)
    end)
end

function steamy:load()
    self.isBooting = love.filesystem.getInfo(".booting.lock")
    if self.isBooting then
        local name = love.filesystem.read(".booting.lock")
        local success = love.filesystem.remove(".booting.lock")
        if success then
            print("Removed booting lock file")
            self:bootGame(name)
        end
    end
end

function steamy:update()
    if self.server then self.server:update() end
end

return steamy