# LuaGhost: Spyro the Dragon

This script can be run through the Lua console in the [BizHawk emulator](http://tasvideos.org/BizHawk.html) to add ghost recording and playback functionality to the PlayStation 1 game Spyro the Dragon. It is intended for use as a practice or learning tool for speedrunning. Note that this is not intended to be used for leaderboard runs and I do not know of any real-time leaderboard that would consider the use of such a tool during runs to be legal. For a brief look at some of the features in action, see [this video](https://youtu.be/Q8kLlcEh1C0).


# Download

You can download the latest version of LuaGhost [here](https://github.com/Piper1618/LuaGhost-for-Spyro-the-Dragon/releases/latest). Look for the LuaGhost_Spyro1.zip file and download it. I recommend extracting the .zip file into BizHawk's Lua folder, but you can put it wherever you want.

# Setup

The script is designed to work with BizHawk version 2.6.1 through 2.7. It is NOT currently compatible with BizHawk 2.8.x. The emulator must be running the NTSC (U) or PAL version of Spyro the Dragon. It is not compatible with the later Spyro games, only the first in the original trilogy.

BizHawk has some graphics settings which may cause issues if configured incorrectly, so you'll want to check the settings in "PSX" -> "Options".

- Resolution Management: Should be set to either "Mednafen Mode" or "Tweaked Mednafen Mode".
- Drawing Area: Should be set to Full (0 to 239 on NTSC or 0 to 287 on PAL).
- Horizontal Overscan Clipping: Should be set to either "None" or "Clip to Framebuffer".

If you've never needed to use your right stick in BizHawk before, you may want to check that it is bound correctly, because you'll be using it a lot to interact with LuaGhost.

# Starting the Script

To start the script, open the game in BizHawk and then navigate to "Tools" -> "Lua Console" on the toolbar.
Inside the Lua Console window, navigate to "Script" -> "Open Script..." or select the open file icon on the toolbar. Open the file "LuaGhost Spyro the Dragon.lua". The script should now be running!

The console window will sometimes pull focus away from the game window when reading and writing files, so you may want to minimize it while playing to stop it doing that.

The first time you launch the script, it will open a prompt in the game window asking you to enter your name. The name you enter will be saved in any ghost files you create. It can be changed later from the script's menu. You can open the script menu at any time by pressing R3 on your controller (by default).

# Using LuaGhost

## Interacting with LuaGhost

Most interaction with LuaGhost is done using the right stick since the game doesn't use it. Pressing R3 (by default) will open or close the LuaGhost menu, allowing you to configure how the script works. Tilting the right stick up, down, left, or right will access other actions depending on the recording mode (these controls can all be rebound in the menu).

## Recording Modes

From LuaGhost's menu, you can switch between two recording modes. The main one you'll probably be using (which should be active by default) is Segment Mode. This mode automates most of the process of creating and saving ghost files. It will create segment savestates automatically when starting a new save file, entering levels, exiting levels, or traveling between homeworlds. Whenever you end a segment, you will be prompted to save the ghost (by pressing the right stick up by default). This is needed because LuaGhost can't tell whether you've successfully completed a segment or are just navigating around the world.

If you want to experiment with specific movement or tricks, you can switch to Manual Mode. This allows you to create a savestate anywhere you want and record a ghost starting from it. Currently, these ghosts are not saved to file and the savestates you create in this mode will not be remembered next time you load the script.

## Ghost Collections

Inside the script's folder, you'll find a folder called "Ghosts". This is where all your segment recordings live. There are several settings that change how ghosts are displayed in the game and most of these allow you to set different settings for ghosts based on what collection they are in. Each collection is a sub-folder in the Ghosts folder. In segment mode, LuaGhost saves all new ghosts to a collection using your name. There is an option in the segment mode settings menu to export all of your fastest times to a new collection to make it easier to share them without sharing your entire history (LuaGhost currently does not delete old ghost files).

If you make any manual changes to the contents of the Ghosts directory while LuaGhost is running, you MUST restart LuaGhost after making the changes. It is safe to rename the ghost files any way you want. Renaming a collection folder will rename that collection inside LuaGhost (and settings for that collection will not be lost). The only folders that matter to LuaGhost are the collection folders; all sub-folders below those are only there to help keep things organized. If you are building your own collection, you can arrange the files inside it however you want. Nothing breaks if the same ghost exists in multiple collections. All the settings that control how the ghosts are displayed are stored in collectionSettings.txt in each collection's root folder, so you can distribute a collection with sensible defaults.

# A Warning about Savestates

I have not shared default savestates for the different routes. Savestates will be created automatically as you play through your route in segment recording mode. Because of limitations in BizHawk's PS1 emulator, savestates cannot be loaded unless specific settings have not been changed since the savestate was created. The settings that can cause this problem are the ones in "PSX" -> "Controller / Memcard Configuration". BizHawk will throw an error if you try to load an incompatible savestate.

If LuaGhost tries to load an incompatible savestate, it will also corrupt the current Lua Console, causing unexpected behaviour until the console is closed and reopened. There is no indication in the console window when it has been corrupted in this way. If the script ever crashes while loading a savestate, you'll need to close and reopen the console window.

# Spyro Palettes

There is a setting in the script to change Spyro's appearance. Only Spyro's palette data can be overwritten at this time. So, swapping out the purple for a different color is possible, but giving Spyro stripes or spots is not possible. The script will look for .ppm files in the "Spyro Palettes" directory. To work, the files must be formatted in ASCII format, not binary (raw).

If you want to create your own palettes, you'll need to make sure you export them in the correct format. GIMP will ask which mode you want if you export an image in .ppm format and you can select the ASCII format. From my testing, MS Paint will use binary format (the wrong one) without asking. I haven't tested any other programs for compatibility.

If you want to create palettes, look for "Default Spyro Palette.ppm" in the main directory for Spyro's default palette. There is also a "Default Spyro Palette.xcf" file, which is a GIMP file with the palette data split onto different layers and labeled for easier editing. The colors are arranged in the order they exists in the game's ram and it is not intuitive, so I highly recommend referring to the .xcf file.

The PS1 uses 5 bit color (values ranging from 0-31). Modern image editors will typically produce images with 8 or more bits per channel. When loaded, these colors will be rounded to the nearest 5 bit equivalent, losing some detail. Hue can be distorted quite a lot for very dark colors.

# Donate

This software is free for you to use. However, if you have enjoyed using it and want to make a donation, you may do so [here](https://www.paypal.com/donate/?hosted_button_id=UG7BDNLT8F8D6). Thank you!
