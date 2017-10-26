require "/lua/api/cconfig.lua"
require "/lua/api/filesystem.lua"

function newComponent(Computer, ItemName, DeviceAddress)
    local Interrupt = Computer.Interrupt
    ItemName = ItemName:match("^cb_(.+)%(")

    local IO_Speed = cconfig.get("components/storage." .. ItemName .. "_io", 1)
    local Seek_Speed = cconfig.get("components/storage." .. ItemName .. "_seek", 1)
    local Disk_Size = cconfig.get("components/storage." .. ItemName .. "_size", 1)
    local IO_Sustain = cconfig.get("components/storage." .. ItemName .. "_sustain", 1)

    local FileSystem = newFilesystem(DeviceAddress, Disk_Size)

    local ceil = math.ceil
    local abs = math.abs

    local Countdown = math.huge
    local CurrentFunction
    local CurrentFile
    local CurrentFileName
    local CurrentVar

    local Switch = false

    local function isPathOkay(path)
        if type(path) ~= "string" then return false, "path must be a string" end
        path = path:gsub("\\", "/"):gsub("/+", "/")
        if path:sub(1, 1) ~= "/" then return false, "path must be absolute" end
        return path
    end

    return {
        type = "storage",

        methods = function()
            return {"set", "read", "write", "seek", "makedir", "exists", "list", "delete", "move", "size"}
        end,

        call = function(FunctionName, Param1, Param2)
            if FunctionName == "set" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                if Path ~= CurrentFileName then
                    local sound = Switch and "floppy_forward" or "floppy_back"
                    animator.playSound(sound, 0)
                    Switch = not Switch

                    Countdown = Seek_Speed
                    CurrentFunction = function()
                        if CurrentFile then CurrentFile:close() end
                        local file, err = FileSystem.open(Path, "r+")

                        --animator.stopAllSounds(sound)

                        if file then
                            CurrentFile = file; CurrentFileName = Path
                            Interrupt:Push({"storage_set", DeviceAddress, true})
                        else
                            Interrupt:Push({"storage_set", DeviceAddress, false, err})
                        end
                    end
                else
                    Interrupt:Push({"storage_set", DeviceAddress, true})
                end

                return true

            elseif FunctionName == "read" then
                if type(Param1) ~= "number" then return false, "amount must be a number" end
                if not CurrentFile then return false, "no selected file" end

                if Param1 < 0 then
                    local current = CurrentFile:seek()
                    Param1 = CurrentFile:seek("end") + Param1 + 1
                    CurrentFile:seek("set", current)
                    Param1 = Param1 >= 0 and Param1 or 0
                end
                
                animator.playSound("floppy_rw", -1)

                Countdown = ceil(Param1 / IO_Speed)
                CurrentFunction = function()
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_read", DeviceAddress, CurrentFile:read(Param1)})
                end

                return true

            elseif FunctionName == "write" then
                if type(Param1) ~= "string" then return false, "data must be a string" end
                if not CurrentFile then return false, "no selected file" end

                animator.playSound("floppy_rw", -1)

                Countdown = ceil(#Param1 / IO_Speed)
                CurrentFunction = function()
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_write", DeviceAddress, CurrentFile:write(Param1)}) 
                end

                return true

            elseif FunctionName == "seek" then
                if type(Param1) ~= "string" then return false, "mode must be a string" end
                if type(Param2) ~= "number" then return false, "offset must be a string" end

                if Param1 == "absolute" then
                    local current = CurrentFile:seek()
                    local size = CurrentFile:seek("end")

                    if Param2 < 0 then
                        Param2 = CurrentFile:seek("end") + Param2 + 1
                        Param2 = Param2 >= 0 and Param2 or 0
                    end
                    if Param2 > size then Param2 = size end

                    animator.playSound("floppy_rw", -1)

                    Countdown = ceil(abs(Param2 - current) / IO_Speed)
                    CurrentFunction = function()
                        animator.stopAllSounds("floppy_rw")
                        Interrupt:Push({"storage_seek", DeviceAddress, CurrentFile:seek("set", Param2)}) 
                    end

                elseif Param1 == "relative" then
                    local current = CurrentFile:seek()
                    local size = CurrentFile:seek("end")
                    local seek_location = current + Param2

                    if seek_location > size then
                        Param2 = size - current
                    elseif seek_location < 0 then
                        Param2 = -current
                    end

                    animator.playSound("floppy_rw", -1)

                    Countdown = ceil(abs(Param2) / IO_Speed)
                    CurrentFunction = function()
                        animator.stopAllSounds("floppy_rw")
                        Interrupt:Push({"storage_seek", DeviceAddress, CurrentFile:seek("cur", Param2)}) 
                    end

                else
                    return false, "invalid seek mode"
                end

                return true

            elseif FunctionName == "makedir" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                animator.playSound("floppy_rw", -1)

                Countdown = ceil(#Path / IO_Speed)
                CurrentFunction = function()
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_makedir", DeviceAddress, FileSystem.mkdir(Path)}) 
                end

                return true

            elseif FunctionName == "exists" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                animator.playSound("floppy_rw", -1)

                Countdown = Seek_Speed
                CurrentFunction = function()
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_exists", DeviceAddress, FileSystem.exists(Path)})
                end

                return true

            elseif FunctionName == "list" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                animator.playSound("floppy_rw", -1)

                local List = FileSystem.list(Path)
                local Length = 0

                if List then
                    for i = 1, List[0] do
                        Length = Length + #List[i]
                    end
                end

                Countdown = ceil(Length / IO_Speed)
                CurrentFunction = function()
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_list", DeviceAddress, List})
                end

                return true

            elseif FunctionName == "delete" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                animator.playSound("floppy_rw", -1)

                local size = FileSystem.size(Path)
                if size then
                    Countdown = ceil(size / IO_Speed)
                    CurrentFunction = function()
                        animator.stopAllSounds("floppy_rw")
                        if Path == CurrentFileName then
                            CurrentFile:close(); CurrentFile = nil
                        end

                        Interrupt:Push({"storage_delete", DeviceAddress, FileSystem.delete(Path)})
                    end
                else
                    return false, "bad path"
                end

                return true

            elseif FunctionName == "move" then
                --local Path, err = isPathOkay(Param1)
                --if not Path then return false, err end

                --local Path, err = isPathOkay(Param2)
                --if not Path then return false, err end

                return true

            elseif FunctionName == "size" then
                local Path, err = isPathOkay(Param1)
                if not Path then return false, err end

                animator.playSound("floppy_rw", -1)

                Countdown = Seek_Speed
                CurrentFunction = function() 
                    animator.stopAllSounds("floppy_rw")
                    Interrupt:Push({"storage_size", DeviceAddress, FileSystem.size(Param1)}) 
                end

                return true
            else
                return false, "invalid operation"
            end
        end,

        update = function()
            Countdown = (Countdown or math.huge) - 1

            if Countdown <= 0 then
                Countdown = math.huge
                CurrentFunction()
            end
        end,

        init = function()

        end,

        uninit = function()
            if CurrentFile then 
                CurrentFile:close()

                animator.stopAllSounds("floppy_rw")
            end
        end
    }
end