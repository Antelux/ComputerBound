function newSoundchipDriver(MaxInputNodes, MaxOutputNodes, animator)
	local soundTypes = {}
	local pitch, sound = 1
	local ty = type

	local function has(soundType)
		--for i = 1, #soundTypes do
		--	if soundType == soundTypes[i] then
		--		return true
		--	end
		--end
		return ty(soundType) == "string" and (animator.hasSound(soundType.."1") or animator.hasSound(soundType.."26"))
	end

	return {
		play = function(sSound, nPitch)
			local sound = (ty(sSound) == "number" and sound and sound..sSound) or (ty(sSound) == "string" and sSound) or sound
			if not sound or not has(sound:gsub("[0-9]", "")) then return end
			local pitch = ty(nPitch) == "number" and (nPitch >= 1 and nPitch <= 6 and nPitch) or pitch
			
			animator.setSoundPitch(sound, pitch, 0)
			animator.setSoundVolume(sound, 1, 0)
			animator.playSound(sound, 0)
			animator.setSoundVolume(sound, 0, 1)
			return true
		end,

		bind = function(nPort)
			if ty(nPort) ~= "number" then return end; nPort = nPort - MaxInputNodes
			if nPort < 0 or nPort > MaxOutputNodes then return end; local c, en = 0

			for e in pairs(object.getOutputNodeIds(nPort)) do c, en = c + 1, e end
			if c ~= 1 or not en then return end

			world.callScriptedEntity(en, "bindToSoundchip", has)
		end,

		setSound = function(sSound)
			sound = ty(sSound) == "string" and (has(sSound) and sSound) or sound
			return sound == sSound
		end,

		getSound = function()
			return sound
		end,

		setPitch = function(nPitch)
			pitch = ty(nPitch) == "number" and (nPitch >= 1 and nPitch <= 6 and nPitch) or pitch
			return pitch == nPitch
		end,

		getPitch = function()
			return pitch
		end,

		has = has,
	}
end