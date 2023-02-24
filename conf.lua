local argparse = require "libs.argparse"

local parser = argparse("steamy", "Steamy Remote Launcher")
parser:argument("dir", "Directory that contains main.lua"):default("current working directory")
parser:argument("host", "IP or hostname of a server.\nIn client mode, this is the server to connect to.\nIn server mode, this is the address that will be bound to.\n"):default("127.0.0.1")

parser:option("--port", "Port", "3621")
parser:option("--name", "Name of game zip file sent to server.", "game")
parser:flag("--console", "Reconnect after game boot to listen for print statements.")
parser:flag("--upload-only", "Don't automatically boot game after uploading.", false)
parser:flag("--boot-menu", "Display a boot menu and run a server, allow remote clients to load/boot games.", false)
parser:flag("--inject", "Inject steamy into games to keep server alive.")

arguments = parser:parse()
if arguments.host == "127.0.0.1" and not arguments.server_mode then
    print("WARNING: You are running in client mode, but are trying to connect to 127.0.0.1 (the default setting).")
    print("This might not be what you want. Pass a different host to connect to a remote server.")
    print("Run with the --help flag to see usage information.\n")
end

if arguments.dir == "current working directory" then
    arguments.dir = "."
end

function love.conf(t)
    t.window.title = "Videah's Steamy LÖVE Launcher"
    t.identity = "steamy"
    t.window.width = 1280
    t.window.height = 800
    t.gammacorrect = true
    t.vsync = true
    t.fullscreen = true

    -- if we're running in cli mode we disable all graphics modules
    if not arguments.boot_menu then
        t.modules.audio = false
        t.modules.graphics = false
        t.modules.image = false
        t.modules.joystick = false
        t.modules.keyboard = false
        t.modules.math = false
        t.modules.mouse = false
        t.modules.physics = false
        t.modules.sound = false
        t.modules.system = false
        t.modules.timer = false
        t.modules.touch = false
        t.modules.video = false
        t.modules.window = false
    end
end