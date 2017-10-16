--[[
    
    This API implements the backbone of the virtual file system
    used by in-game storage devices. It should be noted that this
    isn't exactly built for error detection; that is, it assumes
    you're using it correctly. If other mods which add components
    end up using this API, do so carefully. 

    Of course, if I find out mod authors actually do want to use
    this, I can make it safer or stand alone.

--]]

local OS = -- (very) Basic OS detection.
    (package.cpath:find(".dll")   and "Windows") or
    (package.cpath:find(".so")    and "Linux") or
    (package.cpath:find(".dylib") and "Mac") or "Unknown"

local iopen = io.open
local ipopen = io.popen
local ilines = io.lines
local itype = io.type

local oexecute = os.execute
local orename = os.rename

local type = type
local tonumber = tonumber
local error = error

-- Get the current game directory and set the computer storage path relative to it.

local ComputerDirectory, p
if OS == "Windows" then
    p = ipopen("cd"); ComputerDirectory = p:read():sub(1, -7) .. "\\storage\\computers\\"

elseif OS == "Linux" or OS == "Mac" then
    p = iopen("pwd"); ComputerDirectory = p:read():sub(1, -9) .. "/storage/computers/"

else
    error("This OS isn't compatible with ComputerBound.")

end

p:close(); p = nil

function newFilesystem(BasePath, Size)
    if type(BasePath) ~= "string" then
        error("base must be a string, got a " .. type(basePath) .. " value", 2)
    end

    -- These two are measured in bytes.
    local TotalSpace = Size or math.huge
    local UsedSpace = 0

    local Storage = {}
    local BaseDirectory

    if OS == "Windows" then
        BaseDirectory = (ComputerDirectory .. BasePath .. "\\")

        -- Get a list of all files and folders at this specific path.
        local ItemList = ipopen("cd " .. BaseDirectory .. " & dir /s /o")

        -- Skip the first few lines; they're unnecessary.
        ItemList:read("*l"); ItemList:read("*l"); ItemList:read("*l")

        -- And then iterate through the list.
        local base = #(" Directory of " .. BaseDirectory)
        local line = ItemList:read("*l")

        if line then
            while line:find(" Directory of ") do
                local basePath = (line .. "\\"):sub(base)
                local LocalStorage
                local Offset, i = 0, 1

                for path in basePath:gmatch("(.-\\)") do
                    if path ~= "\\" then
                        path = path:sub(1, -2)
                        LocalStorage[path] = LocalStorage[path] or {}
                        LocalStorage = LocalStorage[path]
                    else
                        LocalStorage = Storage
                    end
                end

                -- The first line is empty.
                ItemList:read("*l")

                -- This is the line we're after.
                line = ItemList:read("*l")

                -- Directories will be printed first, so go through those.
                local name = line:match("^%d%d/%d%d/%d%d%d%d  %d%d:%d%d [AP]M    <DIR>          ([%w.*]+)$")
                while name do
                    if name ~= "." and name ~= ".." then
                        Offset = Offset + #name
                    end

                    line = ItemList:read("*l")
                    name = line:match("^%d%d/%d%d/%d%d%d%d  %d%d:%d%d [AP]M    <DIR>          ([%w.*]+)$")
                end

                -- Files are what follow next.
                local size, name = line:match("^%d%d/%d%d/%d%d%d%d  %d%d:%d%d [AP]M%s+([%d,]+) ([%w.*]+)$")
                while size do
                    -- Add the file to our table of items.
                    local Data = {name, tonumber(size:gsub(",", ""), 10) + #name}
                    LocalStorage[i] = Data
                    LocalStorage[name] = i
                    Offset = Offset + #name; i = i + 1

                    line = ItemList:read("*l")
                    size, name = line:match("^%d%d/%d%d/%d%d%d%d  %d%d:%d%d [AP]M%s+([%d,]+) ([%w.*]+)$")
                end

                -- Keep track of how many files are in the folder.
                LocalStorage[-1] = i - 1

                -- And lastly is the file count and size of only all the files combined.
                local FolderSize = tonumber(line:match("([%d,]+) bytes$"):gsub(",", ""), 10) + Offset
                LocalStorage[0] = FolderSize; UsedSpace = UsedSpace + FolderSize

                -- What follows is just another empty line.
                ItemList:read("*l")

                -- The next directory line is here.
                line = ItemList:read("*l")
            end
        end

        ItemList:close()

    elseif OS == "Linux" then
        BaseDirectory = (ComputerDirectory .. BasePath .. "/")

        -- Get a list of all files and folders at this specific path.
        local ItemList = ipopen("ls " .. BaseDirectory .. " -la -R")
        local line = ItemList:read("*l")

        if line then
            while line do
                local basePath = (line .. "\\"):sub(base)
                local LocalStorage
                local Offset = 0
                local i = 1

                for path in basePath:gmatch("(.-\\)") do
                    if path ~= "\\" then
                        path = path:sub(1, -2)
                        LocalStorage[path] = LocalStorage[path] or {}
                        LocalStorage = LocalStorage[path]
                    else
                        LocalStorage = Storage
                    end
                end



                -- What follows is just another empty line.
                ItemList:read("*l")

                -- The next directory line is here.
                line = ItemList:read("*l")
            end
        end
    end

    -- Returns the folder/file at the given path.
    local function GetItem(basePath)
        local LocalStorage
        if basePath:sub(-1) ~= "/" then
            basePath = basePath .. "/"
        end

        for path in basePath:gmatch("(.-/)") do
            if path ~= "/" then
                path = path:sub(1, -2)
                local ls = LocalStorage[path]
                if ls then
                    LocalStorage = ls
                else
                    return
                end
            else
                LocalStorage = Storage
            end
        end

        return LocalStorage
    end

    -- Similar to the above, except that it creates
    -- new folders if need be, taking into account
    -- the space needed for them as well.
    local function mkdir(basePath)
        local LocalStorage
        if basePath:sub(-1) ~= "/" then
            basePath = basePath .. "/"
        end

        local requiredSpace = 0
        local empty = {}

        for path in basePath:gmatch("(.-/)") do
            if path ~= "/" then
                path = path:sub(1, -2)
                if not LocalStorage[path] then
                    requiredSpace = requiredSpace + #path
                    LocalStorage = empty
                else
                    LocalStorage = LocalStorage[path]
                end
            else
                LocalStorage = Storage
            end
        end

        if requiredSpace == 0 then
            return GetItem(basePath)

        elseif UsedSpace + requiredSpace <= TotalSpace then
            local path, dirname = basePath:match("^/(.+)/(.+)$")
            if dirname then
                local success = oexecute("cd " .. BaseDirectory .. path .. " & mkdir " .. dirname)
                if success then
                    UsedSpace = UsedSpace + requiredSpace

                    for path in basePath:gmatch("(.-/)") do
                        if path ~= "/" then
                            path = path:sub(1, -2)
                            LocalStorage[path] = LocalStorage[path] or {[-1] = 0, [0] = #path}
                            LocalStorage = LocalStorage[path]
                        else
                            LocalStorage = Storage
                        end
                    end

                    return LocalStorage
                else
                    return false, "unable to create folder(s)"
                end
            else
                return false, "bad path"
            end
        else
            return false, "insufficient space"
        end
    end

    -- Deletes an item, taking into account space.
    local function del(Item, size)
        for i = 1, Item[-1] or 0 do
            local item = Item[i]

            local name = item[1]
            item[1], item[2] = nil, nil

            Item[name] = nil
            Item[i] = nil
        end
        Item[-1] = nil

        for name, item in pairs(Item) do
            size = del(item, size)
            Item[name] = nil
        end

        local foldersize = Item[0]
        UsedSpace = UsedSpace - foldersize
        size = size + foldersize

        return size
    end

    return {
        open = function(filename, mode)
            local file, err = iopen(BaseDirectory .. filename:sub(2), mode)
            local mode = mode or "r"

            if file then
                if mode == "w" then 
                    local fwrite = file.write

                    file.write = function(file, ...)
                        local requiredSpace = 0
                        local data = {...}
                        local type = type

                        for i = 1, #data do
                            local value = data[i]
                            local typeof = type(value)

                            if typeof == "string" then
                                requiredSpace = requiredSpace + #value

                            elseif typeof == "number" then
                                requiredSpace = requiredSpace + 1

                            else
                                return false, "invalid value"
                            end
                        end

                        if UsedSpace + requiredSpace <= TotalSpace then
                            UsedSpace = UsedSpace + requiredSpace
                            fwrite(file, ...)
                        else
                            return false, "insufficient space"
                        end

                        return file
                    end
                end

                return file
            else
                return false, err
            end
        end,

        move = function(path1, path2)
            local basepath1, name1 = path1:match("^(.+)/(.+)$")
            if not (basepath1 and name1) then return false, "bad path1" end

            local basepath2, name2 = path2:match("^(.+)/(.+)$")
            if not (basepath2 and name2) then return false, "bad path2" end

            local Item = GetItem(path1); if not Item then return false, "no such item at path1" end
            if GetItem(path2) then return false, "item already exists at path2" end

            local Folder, err = mkdir(basepath2); if not Folder then return false, err end
            local Parent = GetItem(basepath1); if not Parent then return false, "unable to get parent for path1" end

            local ok, err = orename(BaseDirectory .. path1:sub(2), BaseDirectory .. path2:sub(2))
            if ok then
                local ID = Folder[-1] + 1
                Folder[-1] = ID

                Folder[ID] = Item
                Item[1] = name2
                local Size = Item[2]
                Folder[0] = Folder[0] + Size

                local ID = Parent[name1]
                Parent[name1] = nil

                Parent[ID] = nil
                Parent[0] = Parent[0] - Size

                if Parent[-1] == ID then
                    Parent[-1] = Parent[-1] - 1
                end

                return true, Size
            else
                return false, "unable to move item"
            end
        end,

        delete = function(path)
            local Item = GetItem(path)

            if not Item then return true, 0 end
            
            if not Item[0] then -- It's a file.
                local ok, err = os.remove(BaseDirectory .. path:sub(2))
                if ok then
                    Item[1] = nil
                    local size = Item[2]
                    UsedSpace = UsedSpace - size
                    Item[2] = nil

                    local path, filename = basePath:match("^(.+/)(.+)$")
                    local parent = GetItem(path)

                    local id = parent[filename]
                    parent[filename] = nil
                    parent[id] = nil

                    if parent[-1] == id then
                        parent[-1] = parent[-1] - 1
                    end

                    parent[0] = parent[0] - size

                    return true, size
                else
                    return false, "unable to delete file"
                end

            else -- It's a folder
                local path, dirname = basePath:match("^(.+)/(.+)$")
                local ok, err = oexecute("cd " .. BaseDirectory .. path:sub(2) .. " & rmdir " .. dirname .. " /s /q")

                if ok then
                    local size = del(Item, 0)
                    local parent = GetItem(path)
                    parent[dirname] = nil
                    parent[0] = parent[0] - #dirname

                    return true, size
                else
                    return false, "unable to delete folder"
                end
            end
        end,

        mkdir = mkdir,

        list = function(path)
            local Folder = GetItem(path)
            local List, Size = {}, 0

            if Folder then
                for k, v in pairs(Folder) do
                    if type(k) ~= "number" then
                        Size = Size + 1
                        List[Size] = k
                    end
                end
            end

            List[0] = Size

            return List
        end,

        exists = function(path)
            local Item = GetItem(path)
            return type(Item) == "number" and "file" or "dir"
        end,

        size = function(path)
            local Item = GetItem(path)
            return type(Item) == "number" and Item or Item[0]
        end
    }
end