--[[
    Commands to implement:

    -ls     lists all files
        flags:  -h: show hidden files -d: show extra details (like file size)
   
    -mount  mounts a disk to a location
        usage:  [disk] [location]
    
    -specs  shows all connected internal hardware and specs.

    potential, but not sure:
    -at     exectures programs (in the background) in the future. print id for canceling if need be.
        usage: [file] [time] <date>
    -sch    shows a schedule of all programs will be executed, are being executed, and have executed for the current day, as well as any values they returned.
    -can    cancels a program scheduled to execute, or halts a currently executing program.
        usage: [id1], <id2>, ...
    -bg   executes a program in the background.
        usage:  [file1], <file2>, ...
    -proc   shows a list of all currently executing programs. can potentially make a program out of this later for constantly updating results.
        flags: -c shows CPU usage -r shows RAM usage
--]]

local sAlias = ...
if not sAlias then
    printError("alias expected")
    return
end

if not shell.getAlias(sAlias) then
    printError("no such alias")
    return
end

-- Prepare for the cringe list of if/then statements.
-- Mostly because I got a bit lazy. =P

-- Note to self: When not lazy, allow users to add their own help stuffs.
-- Also, make all text except usage some nice color. :)
-- term.setTextColor(0, 127, 255)

-- Shell Programs
term.setTextColor(colors.white)
if sAlias == "alias" then
    print("Sets an alias for a program, or gets an alias.")
    print("Usage: alias [alias] -> Returns the path for a given alias.")
    print("Usage: alias [alias] [program] -> Sets the alias for a program.")

elseif sAlias == "calias" then
    print("Removes an alias for a program.")
    print("Usage: calias [alias]")

elseif sAlias == "cat" then
    print("Prints the entire contents of a file.")
    print("Usage: cat [file]")

elseif sAlias == "cd" then
    print("Changes the working directory of the shell.")
    print("Usage: cd [path] (The path may be relative or absolute.)")

elseif sAlias == "clr" then
    print("Clears the screen of clutter.")
    print("Usage: clr")

elseif sAlias == "clock" then
    print("Displays the amount of time that passed since the computer was turned on.")
    print("Usage: clock")

elseif sAlias == "comps" then
    print("Displays the addresses of all components currently in the computer.")
    print("Usage: comps")

elseif sAlias == "cp" then
    print("Copies a file or directory from one location to another.")
    print("Usage: cp [sourcePath] [destinationPath] (The paths may be relative or absolute.)")

elseif sAlias == "date" then
    print("Displays the current real-world date.")
    print("Usage: date")

elseif sAlias == "drives" then
    print("Displays all the current storage devices and their labels.")
    print("Usage: drives")

elseif sAlias == "find" then
    print("Searches for a specific file or directory on all storage devices.")
    print("Usage: find [path] (The path may have wildcards* in it.)")

elseif sAlias == "help" then
    print("Explains the function of a given program, as well as the usage of it.")
    print("Usage: help [alias]")

elseif sAlias == "ls" then
    print("Lists the files and directories in a given path.")
    print("Usage: ls [path] (The path may be relative or absolute.)")

elseif sAlias == "mkdir" then
    print("Creates a directory.")
    print("Usage: mkdir [path] (The path may be relative or absolute.)")

--elseif sAlias == "mount" then
--    print("Mounts a directory")

elseif sAlias == "mv" then
    print("Moves a file or directory from one location to another.")
    print("Usage: mv [sourcePath] [destinationPath] (The path may be relative or absolute.)")

elseif sAlias == "nodes" then
    print("Displays a list of what's currently connected to the computer.")
    print("Usage: nodes")

elseif sAlias == "progs" then
    print("Displays a list of program aliases available for quick use.")
    print("Usage: progs")

elseif sAlias == "restart" then
    print("Restarts the computer one second after being ran.")
    print("Usage: restart")

elseif sAlias == "rm" then
    print("Removes a file or directory.")
    print("Usage: rm [path] (The path may be relative or absolute.)")

elseif sAlias == "shutdown" then
    print("Shuts the computer down one second after being ran.")
    print("Usage: shutdown")

elseif sAlias == "specs" then
    print("Displays the specifications of the computer.")
    print("Usage: specs")

elseif sAlias == "time" then
    print("Displays the current real-world time.")
    print("Usage: time -> Shows the time in twelve hour format.")
    print("Usage: time -m -> Shows the time in twenty-four hour format.")

-- Regular Programs
elseif sAlias == "adv" then
    print("A text adventure game.")
    print("Usage: adv")

elseif sAlias == "cdisp" then
    print("Displays all the colors the current GPU can display.")
    print("Usage: cdisp")

elseif sAlias == "cmd" then
    print("Runs an interactive shell program, much like the one you're in.")
    print("Usage: cmd")

elseif sAlias == "edit" then
    print("Edits a lua file to allow for programming of the computer.")
    print("Usage: edit [file] (The file may be relative or absolute.)")

elseif sAlias == "lua" then
    print("Runs an interactive lua console to experiment in.")
    print("Usage: lua")

elseif sAlias == "paint" then
    print("Edits a picture so you may express yourself.")
    print("Usage: paint [file] (The file may be relative or absolute.)")

--elseif sAlias == "unmount" then
--    print("Unmounts a directory")

-- Unknown Program
else
    print("no available help")
end