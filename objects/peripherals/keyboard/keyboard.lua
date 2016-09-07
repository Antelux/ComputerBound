function driver()
    return {
        bind = function(port)
            if not type(port) == "number" then return end
        end,

        isPressed = function(key)
            -- Returns true once, the moment the key was pressed, and
            -- will return true if the key was held down for a second
            -- until the key is released. Good for things that need
            -- text-based user input for something.
        end,

        isDown = function(key)
            -- Returns true until the key is no longer pressed, good for
            -- Games which need movement to be triggered.
        end
    }
end