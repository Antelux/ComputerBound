require "/lua/uuid.lua"

local computerID
function peripheralType()
	return "handscanner"
end

function peripheralBind(id)
	computerID = id
end

function peripheralAddress()
	return storage.address
end

function peripheralDriver()
	return {
		turnOn = function()
			object.setInteractive(true)
			output(true)
		end,

		turnOff = function()
			object.setInteractive(false)
			output(false)
		end
	}
end

-------------------------------------------------------------------------------

function init()
	storage.address = storage.address or newUUID()
	object.setInteractive(true)
	output(true)
end

function onInteraction(entity)
	if computerID then
		if world.entityType(entity.sourceId) == "player" then
			world.callScriptedEntity(computerID, "pushEvent", "handscan_success", world.entityUniqueId(entity.sourceId))
		else
			world.callScriptedEntity(computerID, "pushEvent", "handscan_failure")
		end
	end
end

function output(state)
  if state then
    animator.setAnimationState("switchState", "on")
    if not (config.getParameter("alwaysLit")) then object.setLightColor(config.getParameter("lightColor", {0, 0, 0, 0})) end
    object.setSoundEffectEnabled(true)
    animator.playSound("on")

  else
    animator.setAnimationState("switchState", "off")
    if not (config.getParameter("alwaysLit")) then object.setLightColor({0, 0, 0, 0}) end
    object.setSoundEffectEnabled(false)
    animator.playSound("off")
  end
end