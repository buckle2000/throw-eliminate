function love.conf(t)
    t.identity = nil                    -- The name of the save directory (string)
    t.version = "0.10.1"                -- The LÖVE version this game was made for (string)
    t.console = true                    -- Attach a console (boolean, Windows only)

    t.window.title = "throw-eliminate"  -- The window title (string)
    t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
    t.window.width = 801                -- The window width (number)
    t.window.height = 601               -- The window height (number)

    t.modules.touch = false  -- no touch support
end