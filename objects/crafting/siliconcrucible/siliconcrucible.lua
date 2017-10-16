require "/lua/api/cconfig.lua"

function init()
    cconfig.root(root)
    local sc_config = cconfig.get("objects/siliconcrucible", {})

    storage.silicon = storage.silicon or 0
    storage.boules = storage.boules or 0
    storage.start = storage.start or false

    if storage.restart then
        storage.start = os.clock() - storage.restart
        storage.restart = nil
    end

    message.setHandler("storageSet", function(_, _, index, value)
        if type(storage[index]) ~= "nil" and type(value) == "number" or type(value) == "boolean" then
            storage[index] = value
        end
    end)

    message.setHandler("storageGet", function()
        return storage
    end)

    message.setHandler("configGet", function()
        return {
            siliconCapacity = sc_config.siliconCapacity or 100,
            siliconBouleCapacity = sc_config.siliconBouleCapacity or 10,
            bouleGrowTime = sc_config.bouleGrowTime or 600
        }
    end)
end

function uninit()
    if storage.start then
        storage.restart = os.clock() - storage.start
    end
end

function die()
    if storage.silicon > 0 then
        world.spawnItem("cb_silicon", entity.position(), storage.silicon)
    end

    if storage.boules > 0 then
        world.spawnItem("cb_siliconboule", entity.position(), storage.boules)
    end
end