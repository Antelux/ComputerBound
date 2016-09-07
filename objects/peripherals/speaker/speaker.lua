require "/lua/uuid.lua"
function init()
	storage.address = storage.address or newUUID()
end

local has = false
function bindToSoundchip(hasSound)
	has = hasSound
end

function peripheralType()
	return "speaker"
end

function peripheralAddress()
	return storage.address
end

function peripheralDriver()
	local volume, pitch, fade, sound = 1, 1, 1
	local ty = type

	return {
		play = function(sSound, nPitch, nFade, nVolume)
			if not has then return end

			local sound = (ty(sSound) == "number" and sound and sound..sSound) or (ty(sSound) == "string" and sSound) or sound
			if not sound or not has(sound:gsub("[0-9]", "")) then return end

			local volume = ty(nVolume) == "number" and (nVolume >= 1 and nVolume <= 3 and nVolume) or volume
			local pitch = ty(nPitch) == "number" and (nPitch >= 1 and nPitch <= 6 and nPitch) or pitch
			local fade = ty(nFade) == "number" and (nFade >= 0.1 and nFade <= 1 and nFade) or fade
			
			animator.setSoundVolume(sound, volume, 0)
			animator.setSoundPitch(sound, pitch, 0)
			animator.playSound(sound, 0)
			animator.setSoundVolume(sound, 0, fade)

			return true
		end,

		setSound = function(sSound)
			sound = ty(sSound) == "string" and (has(sSound) and sSound) or sound
			return sound == sSound
		end,

		getSound = function()
			return sound
		end,

		setVolume = function(nVolume)
			volume = ty(nVolume) == "number" and (nVolume >= 1 and nVolume <= 3 and nVolume) or volume
			return volume == nVolume
		end,

		getVolume = function()
			return volume
		end,

		setPitch = function(nPitch)
			pitch = ty(nPitch) == "number" and (nPitch >= 1 and nPitch <= 6 and nPitch) or pitch
			return pitch == nPitch
		end,

		getPitch = function()
			return pitch
		end,

		setFade = function(nFade)
			fade = ty(nFade) == "number" and (nFade > 0 and nFade <= 1 and nFade) or fade
			return fade == nFade
		end,

		getFade = function()
			return fade
		end
	}
end