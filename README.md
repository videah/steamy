# Videah's Steamy Remote LÖVE Launcher

`steamy` is a library/tool for [LÖVE](https://love2d.org) that facilitates remote development and testing.

You can use `steamy` to remotely receive and launch game files within LÖVE itself. There is no need to package a .love, all
the bundling is done for you. This allows you to easily develop and test on devices other than your development machine!

Primarily created and designed to be used for developing games on [Steam Deck](https://store.steampowered.com/steamdeck)
but can be easily used on other devices.

**Note:** `steamy` depends on [LuaJIT's FFI capabilities](http://luajit.org/ext_ffi.html) to function and won't be
useful on platforms where JIT and FFI are not available.

# Usage

### Running a server manually
Getting a `steamy` server running in your game is easy!
```lua
-- Place the steamy repo somewhere in your game's directory (like a libs folder) and require it
local steamy = require 'libs.steamy'

-- Start a steamy server in your game, listening on a host (example: 0.0.0.0)
steamy:startServer("0.0.0.0")

-- Process the steamy server in your love.update
function love.update(dt)
    steamy:update()
end
```
That's all you need! When the server receives a game from a client it'll automatically restart LÖVE and boot the game
it received.

The easiest way to send a game to a server is using the [CLI.](#cli)

### CLI
```
Usage: steamy [--port <port>] [--name <name>] [--console]
       [--upload-only] [--boot-menu] [--inject] [-h] [<dir>] [<host>]

Steamy Remote Launcher

Arguments:
   dir                   Directory that contains main.lua (default: current working directory)
   host                  IP or hostname of a server.
                         In client mode, this is the server to connect to.
                         In server mode, this is the address that will be bound to.
                          (default: 127.0.0.1)

Options:
   --port <port>         Port (default: 3621)
   --name <name>         Name of game zip file sent to server. (default: game)
   --console             Reconnect after game boot to listen for print statements.
   --upload-only         Don't automatically boot game after uploading.
   --boot-menu           Display a boot menu and run a server, allow remote clients to load/boot games.
   --inject              Inject steamy into games to keep server alive.
   -h, --help            Show this help message and exit.
```

### Boot Menu

![](assets/screenshot.png)

There is a provided GUI boot menu designed to be a 1st class citizen on [Steam Deck](https://store.steampowered.com/steamdeck).

This can be used by running the `steamy` [CLI](#cli) with the `--boot-menu` flag. The boot menu will start a server to
listen for incoming games and load/boot them from remote clients.

#### Injection
The boot menu can attempt to inject a `steamy` server into any game it boots when the `--inject` flag is passed.
Since this makes a few assumptions about your games code and is generally quite hack-y this can be a bit temperamental.

It's highly recommended you [manually start a server in your games code](#running-a-server-manually) instead if possible.

## Libraries Used
- [LoveZip](https://github.com/Rami-Sabbagh/LoveZip)
- [nativefs](https://codeberg.org/pgimeno/nativefs)
- [bitser](https://github.com/gvx/bitser)
- [sock.lua](https://github.com/camchenry/sock.lua)
- [pprint.lua](https://github.com/jagt/pprint.lua)
- [argparse](https://github.com/mpeterv/argparse)