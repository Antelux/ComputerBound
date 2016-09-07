function driver()
    {
    	bind = function(port)
            if not type(port) == "number" then return end
        end,
        
        getPosition = function()
            local position = console.canvasMousePosition()
            return floor(position[1] / Scale), floor(position[2] / Scale)
        end
    }
end