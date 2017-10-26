# ComputerBound
This is a mod I've been working on for about a year now, which adds in programmable computers to the game Starbound.
As of now, it's functional and well, with a lot of final designs for stuff taking place and being implemented.
You can think of previous versions as having prototypes and tests of the systems used in place now.
Of course it's still buggy here and there, but that's to be expected I suppose. Nothing that can't be fixed.

I won't be releasing this on the mod forums of Starbound until I deem it 100% playable in survival and completely
server friendly (or, at least to the extent possible within the game's limitations).

In the mean time, I'll be releasing periodic updates (weekly or so), plus or minus a couple of days if I need more time
to make sure the updated version doesn't just go ahead and break everything.

Hopefully this continues to go well!

# Prerequisites

This mod requires the option "safeScripts" to be false.

Your starbound.config can be found in your storage folder, where the option can be changed.

### Wait . . "safeScripts" needs to be off? Isn't that really really bad??

Unfortunately, it's required because there's no other way of writing files to the computer. Disabling the option gives
me access to the io library and some other neat stuff. As far as how bad it is? For this mod, it should be impossible
for any user to access these bindings, even at the administrator level (at least from the vanilla version of the mod).

I think I can safely say that even as the mod is, the most harmful thing any user can do to the server is make the computer
object crash or temporarily stall other objects running Lua scripts. While both these things are annoying, they are far from
fatal, and a server should chug along normally despite either or both of the two happening. From the get-go, I constructed
the mod to be as server-safe as possible, since that is a primary goal for me in developing it.

So where does the real danger in disabling this option come from, if not from the mod itself? From other mods, of course.
If you're going to disable this option, please be wary of other mods you have installed. Generally (from my experience),
mods from the official Starbound mod forum should be OK and not be checking for the functions that come along with disabling
safeScripts. Just be careful and ensure that the mod is trustworthy (perhaps have a look through its code, even).

Other than that, it shouldn't be inherently harmful to use this mod. Though, if some kind of security exploit is found, be
sure to contact me in some way with the details, since such an exploit is a serious problem.

. . . But, just to be sure, please only use this mod in single player or on a server with people you can trust for now.
This precaution can likely be ignored once I do release the mod fully.

# Credits

* A large amount of the mod's art assets were made by donpapillon. Massive thanks for such awesome stuff!
- Link to his Starbound profile page: https://community.playstarbound.com/members/donpapillon.215443/

* I used two websites for creation of the mod logo, both of which are listed below:
- https://logomakr.com
- http://www5.flamingtext.com