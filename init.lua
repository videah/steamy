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

        -- We need to start our new server before we boot the game so it's ready ASAP
        if arguments.inject then
            _G.__steamy = self
            _G.__steamy:startServer(self.host)

            -- Patch print to send print statements remotely to clients.
            local oldPrint = print
            _G.print = function(...)
                oldPrint(...)
                _G.__steamy:print(...)
            end
            print("Patched print statements, ready to send remotely to clients.")
        end

        love.init()

        -- Attempt to inject steamy into the running game to keep the server alive
        -- This makes some assumptions about the users love.update, since if the user
        -- were to replace the function at any point after boot it would stop working.
        --
        -- But who does that?
        if arguments.inject then
            if love.update then
                local userUpdate = love.update
                love.update = function(dt)
                    userUpdate(dt)
                    _G.__steamy:update()
                end
                print("Steamy has been injected.")
            end
        end
        self.hasBooted = true
        if _G.__steamy then _G.__steamy.hasBooted = true end
    end
end

function steamy:startServer(host)
    self.host = host
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
            if self.callbacks["download"] then self.callbacks["download"]() end
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

-- Send a print statement to clients
function steamy:print(...)
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        str = str .. tostring(v)
        if i ~= #args then
            str = str .. "\t"
        end
    end
    self.server:sendToAll("print", str)
end

function steamy:update()
    if self.server then self.server:update() end
end

return steamy