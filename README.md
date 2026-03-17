Build on the work of n4gi0s (https://gitlab.com/n4gi0s/vu-mapvote) which was greatly appreciated. Rebuilkd it to work with 

Still working out some kinks, but it seems to be working at this time.

Installation:


Extract contect of zip to your mods folder. This should look something like Admin/Mods/vu-mapvote
Add vu-mapvote to your Admin/ModList.txt
Setup the maps you want in MapList.txt (without this it will not work! See example below)
Voting starts at the endscreen, after 10 seconds. To make sure it does not interfere with the game. 

Optional configuration:

Add these to your Admin/Startup.txt

mapvote.randomize <true/false> (default true)
mapvote.limit <number of selectable random maps> (default 15)
mapvote.excludecurrentmap <true/false> (default true)


Not recommended, because it can have some unintended results.

Manually starting a vote, via server console or RCON:
mapvote.start
