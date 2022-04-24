-------------------------
---- 
---- LuaGhost: Spyro the Dragon
----
---- Copyright 2022 Piper
----
---- This software is licensed under GLPv3. See the
---- accompanying LICENSE file for details.
----
-------------------------

_LuaGhostVersion = "1.1.0"

-- Validate the version of BizHawk that is running
do
	local allowedVersions = {
		["2.6.0"] = true,
		["2.6.1"] = true,
		["2.6.2"] = true,
		["2.6.3"] = true,
		["2.7.0"] = true,
	}
	if not allowedVersions[client.getversion()] then
		print("ERROR\nIt looks like you're using an incompatible version of BizHawk: " .. client.getversion() .. "\nOnly versions 2.6.x and 2.7.0 are currently supported.")
		return
	end
end

-- Stop the program from advancing if it is started while no rom is loaded
if emu.getsystemid() ~= "PSX" then print("LuaGhost is running. Waiting for you to load Spyro the Dragon (USA or PAL).") while true do emu.frameadvance() end end

-- I've had trouble with io.popen not always working, so I'm re-implementing it using os.execute
function io.popen(s)
	local seperator = package.config:sub(1, 1)
	os.execute(s .. " > data" .. seperator .. "popen.txt")
	return io.input("data" .. seperator .. "popen.txt")
end

-- Ensure the data folder exists
os.execute("mkdir data")


-------------------------
-- Load external libraries/modules
-------------------------

assert(loadfile([[libs\bizHawkLuaUtility.lua]]))()
file = assert(loadfile([[libs\file.lua]]))()
inputs = assert(loadfile([[libs\inputs.lua]]))()
JSON = assert(loadfile [[libs\JSON.lua]])()

-------------------------
-- Variables and constants
--
-- Early in the project, I put all my global variables in
-- here, but it was becoming a nightmare to keep organized
-- so I started defining variables at the top of the
-- section they relate to. This section now contains things
-- I couldn't find a better home for, but mostly things
-- I haven't gotten around to moving yet. Some of them may
-- be for old functions that no longer exist.
-------------------------

do
	-------------------------
	-- Game Version Stuff
	-------------------------
	
	
	displayType = emu.getdisplaytype()
	
	memoryAddresses = {
		["NTSC"] = {
			[1] = 0,
			[2] = 0,
			[3] = 0,
			[4] = 0,
			[5] = 0,
			homeScreenCheck = 0x800DF20C,
			pixelRatio = 0.5625,
		},
		["PAL"] = {
			[1] = 0x68C8,
			[2] = 0x68CC,
			[3] = 0x68D4,
			[4] = 0x6990,
			[5] = 0x68D0,
			homeScreenCheck = 0x800DCB88,
			pixelRatio = 0.6469,
		},
	}
	
	if displayType == "NTSC" then
		framerate = 60
		m = memoryAddresses["NTSC"]
		
		FOVx = 1.22
		FOVy = 1.78
		screen_yOffset = 0

		screen_width = 560
		screen_height = 240

		border_left = 24
		border_right = screen_width - 25
		border_top = 8
		border_bottom = screen_height - 9

		nearClip = 500
	else
		framerate = 50
		m = memoryAddresses["PAL"]
		
		FOVx = 1.22
		FOVy = 1.48
		screen_yOffset = -1
		
		screen_width = 560
		screen_height = 288

		border_left = 24
		border_right = screen_width - 25
		border_top = 15
		border_bottom = screen_height - 18

		nearClip = 500
	end
	
	screen_halfWidth = screen_width / 2
	screen_halfHeight = screen_height / 2


	-------------------------
	-- Camera
	-------------------------
	cameraX = 0
	cameraX_buffer = {}
	cameraY = 0
	cameraY_buffer = {}
	cameraZ = 0
	cameraZ_buffer = {}
	cameraYaw = 0
	cameraYaw_buffer = {}

	cameraPitch = 0
	cameraPitch_buffer = {}

	-------------------------
	-- Buffer
	-------------------------
	-- The lua gui.* functions can draw to screen faster than the
	-- emulated game can draw its own graphics, so the
	-- overlayed graphics will appear to lead the game graphics
	-- unless delayed. The buffer is used to create this delay.

	bufferLength = 3
	bufferIndex = 0

	-------------------------
	-- Modes
	-------------------------
	
	recordingMode = "segment"
	recordingModePrettyNames = {
		["segment"] = "Segment",
		["run"] = "Full Run",
		["manual"] = "Manual",
	}
	recordingModeFolderNames = {
		["segment"] = "Segment Ghosts",
		["run"] = "Full Run Ghosts",
		["manual"] = "Manual Ghosts",
	}
	
	currentRoute = "120"
	currentSegment = {}
	routePrettyNames = {
		["120"] = "120%",
		["any"] = "Any%",
		["vortex"] = "Vortex",
		["80dragons"] = "80 Dragons",
	}
	routeFolderNames = {
		["120"] = "120%",
		["any"] = "Any%",
		["vortex"] = "Vortex",
		["80dragons"] = "80 Dragons",
	}
	
	variant_sparxless = false

	-------------------------
	-- GUI
	-------------------------

	drawColor = 0xffffffff

	-------------------------
	-- Menu Handling
	-------------------------
	
	-- Segment update
	menu_segmentUpdate_timer = 0
	menu_segmentUpdate_maxTimer = 30 * 8
	menu_segmentUpdate_delta = nil
	menu_segmentUpdate_gemCount = 0


	menu_showInputs = 0
	
	-------------------------
	-- Gameplay changes
	-------------------------

	flightMode = 0

	-------------------------
	-- Math Constants
	-------------------------

	_pi = math.pi--3.1415926535
	_tau = math.pi * 2--6.2831853072

	-------------------------
	-- Other Constants
	-------------------------

	spyroZOffset = 360--because Spyro's position is level with his shoulders, not his feet

	-------------------------
	-- Debug / Experimental
	-------------------------

	homescreencheck = 0x00

	--
end


-------------------------
-- Data
-------------------------

levelIds = { 10, 11, 12, 13, 14, 15, 20, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 40, 41, 42, 43, 44, 45, 50, 51, 52, 53, 54, 55, 61, 62, 63, 64, }

levelInfo = {
	[10] = {name = "Artisans",        gems = 100, dragons = 4, flightLevel = false},
	[11] = {name = "Stone Hill",      gems = 200, dragons = 4, flightLevel = false},
	[12] = {name = "Dark Hollow",     gems = 100, dragons = 3, flightLevel = false},
	[13] = {name = "Town Square",     gems = 200, dragons = 4, flightLevel = false},
	[14] = {name = "Toasty",          gems = 100, dragons = 1, flightLevel = false},
	[15] = {name = "Sunny Flight",    gems = 300, dragons = 0, flightLevel = true},
	[20] = {name = "Peace Keepers",   gems = 200, dragons = 3, flightLevel = false},
	[21] = {name = "Dry Canyon",      gems = 400, dragons = 4, flightLevel = false},
	[22] = {name = "Cliff Town",      gems = 400, dragons = 3, flightLevel = false},
	[23] = {name = "Ice Cavern",      gems = 400, dragons = 5, flightLevel = false},
	[24] = {name = "Doctor Shemp",    gems = 300, dragons = 1, flightLevel = false},
	[25] = {name = "Night Flight",    gems = 300, dragons = 0, flightLevel = true},
	[30] = {name = "Magic Crafters",  gems = 300, dragons = 3, flightLevel = false},
	[31] = {name = "Alpine Ridge",    gems = 500, dragons = 4, flightLevel = false},
	[32] = {name = "High Caves",      gems = 500, dragons = 3, flightLevel = false},
	[33] = {name = "Wizard Peak",     gems = 500, dragons = 3, flightLevel = false},
	[34] = {name = "Blowhard",        gems = 400, dragons = 1, flightLevel = false},
	[35] = {name = "Crystal Flight",  gems = 300, dragons = 0, flightLevel = true},
	[40] = {name = "Beast Makers",    gems = 300, dragons = 2, flightLevel = false},
	[41] = {name = "Terrace Village", gems = 400, dragons = 2, flightLevel = false},
	[42] = {name = "Misty Bog",       gems = 500, dragons = 4, flightLevel = false},
	[43] = {name = "Tree Tops",       gems = 500, dragons = 3, flightLevel = false},
	[44] = {name = "Metalhead",       gems = 500, dragons = 1, flightLevel = false},
	[45] = {name = "Wild Flight",     gems = 300, dragons = 0, flightLevel = true},
	[50] = {name = "Dream Weavers",   gems = 300, dragons = 3, flightLevel = false},
	[51] = {name = "Dark Passage",    gems = 500, dragons = 5, flightLevel = false},
	[52] = {name = "Lofty Castle",    gems = 400, dragons = 3, flightLevel = false},
	[53] = {name = "Haunted Towers",  gems = 500, dragons = 3, flightLevel = false},
	[54] = {name = "Jacques",         gems = 500, dragons = 2, flightLevel = false},
	[55] = {name = "Icy Flight",      gems = 300, dragons = 0, flightLevel = true},
	[60] = {name = "Gnasty's World",  gems = 200, dragons = 2, flightLevel = false},
	[61] = {name = "Gnorc Cove",      gems = 400, dragons = 2, flightLevel = false},
	[62] = {name = "Twilight Harbor", gems = 400, dragons = 2, flightLevel = false},
	[63] = {name = "Gnasty Gnorc",    gems = 500, dragons = 0, flightLevel = false},
	[64] = {name = "Gnasty's Loot",   gems = 2000,dragons = 0, flightLevel = false},
}

-------------------------
-- Update functions
-------------------------

do
	-------------------------
	-- Spyro Properties
	-------------------------
	
	spyroX = 0
	spyroY = 0
	spyroZ = 0
	spyroDirection = 0
	lastSpyroX = 0
	lastSpyroY = 0
	lastSpyroZ = 0
	lastSpyroDirection = 0
	
	xSpeed = 0
	ySpeed = 0
	zSpeed = 0
	
	spyroSpeed = 0
	spyroGroundSpeed = 0
	spyroLogicalSpeed = 0--read from 0x078B71 on NTSC
	
	thisFrameGrounded = false
	lastFrameGrounded = false
	
	spyroAnimation = 1
	lastSpyroAnimation = 1
	
	-------------------------
	-- World Stats
	-------------------------
	currentLevel = 0
	lastLevel = 0-- the currentLevel value last frame
	gameState = 0
	lastGameState = 0
	spyroControl = 0
	lastSpyroControl = 0
	loadingState = -1
	lastLoadingState = -1
	homeScreenState = 0
	gameOverIsOverworld = false
	enteredLoadThisFrame = false
	musicVolume = nil
	flightLevel = false
	showGhostAnimations = true
	lastInTitleScreen = false
	inTitleScreen = false
end

function getWorldValues()
	-- Detect that we're in the boot sequence, title screen, or demo.
	-- Address 0x075680 holds a value of 0x801BD020 once
	-- the player starts a new game. It changes to
	-- 0x8015E7C0 once Gnasty Gnorc is defeated. It changes
	-- again to 0x8018B000 once Gnasty's Loot is completed.
	-- Update: I've switched this to check for the values that
	-- exist on the boot and title screens. 0x00 while the game
	-- is loading and then 0x800DF20C in the title screen and
	-- demos. This should make PAL compatability easier.
	local v = memory.read_u32_le(0x075680 + m[1])
	oldInTitleScreen = inTitleScreen
	inTitleScreen = v == 0x00 or v == m.homeScreenCheck
	
	
	--[[ gameState changes based on loads, menus, and similar
	0 - Normal
	1 - Entering/Exiting level
	2 - Pause
	3 - Inventory
	4 - Dying
	5 - Game Over (can be poked)
	6 ? I've never seen this in context; makes a full screen overlay appear
	7 - Flight level complete menu (also when crashing/failing)
	8 - Dragon cutscene
	9 ? briefly while entering level (after loading)
	10 ? briefly while exiting level (before loading; doesn't always happen)
	11 - Fairy Menu
	12 - Balloonist (talking and riding)
	13 - Home Screen (will change to 0 during demos)
	14 - Intro Cutscene (can be poked, which clears save data)
	   - Also, Cutscene after beating gnasty Gnorc (level is still set to 63)
	15 - Credits (poking this will make the game freeze)
	--]]
	lastGameState = gameState
	gameState = memory.read_u32_le(0x0757D8 + m[2])
	
	-- loadingState counts up during loading screens
	lastLoadingState = loadingState
	loadingState = memory.read_s32_le(0x075864 + m[5])
	
	-- Spyro doesn't respond to inputs while spyroControl
	-- this is higher than 0 (although it doesn't stop you
	-- from controlling menus). Sometimes, this will be
	-- locked at 1 to disable controls and sometimes it
	-- will be set to a higher value and count down to 0.
	lastSpyroControl = spyroControl
	spyroControl = memory.read_u32_le(0x078C48 + m[4])

	-- level indecies should be read/interpreted in
	-- decimal. The 10s place is the homeworld, starting at
	-- 10 for the Artisans Homeworld. If the 1s place is 0,
	-- you're in the Homeworld; otherwise, you're in one of
	-- the levels. 
	if inTitleScreen then
		currentLevel = 10
		lastLevel = 0
	else
		lastLevel = currentLevel
		currentLevel = memory.read_u32_le(0x07596C + m[5])
		if currentLevel == 0 then
			currentLevel = 10
			lastLevel = 0
		end
		
		if lastLevel ~= currentLevel then
			flightLevel = levelInfo[currentLevel].flightLevel
			if currentLevel % 10 == 0 and lastLevel % 10 == 0 then
				currentSegment = {"World", currentLevel, "Entry"}
			else
				if currentLevel % 10 ~= 0 then
					if gameState == 12 then
						currentSegment = {"Level", currentLevel, "Balloon"}
					else
						currentSegment = {"Level", currentLevel, "Entry"}
					end
				else
					if gameState == 5 then
						currentSegment = {"Level", lastLevel, "GameOver"}
					elseif gameState == 15 then
						currentSegment = {"Level", lastLevel, "PostCredits"}
						memory.write_s32_le(0x078C48 + m[4], 0x01)--disable Spyro control
					else
						currentSegment = {"Level", lastLevel, "Exit"}
					end
				end
			end
			showDebug("Level change: {'" .. currentSegment[1] .. "', " .. tostring(currentSegment[2]) .. ", '" .. currentSegment[3] .. "'}")
		end
		--Detect cutscene at the start of the game
		if gameState == 14 and currentLevel ~= 63 and currentLevel ~= 64 then
			showDebug("Detected opening cutscene")
			currentLevel = 10
			lastLevel = 10
			currentSegment = {"World", 10, "Entry"}
		end
	end
	
	-- Music Volume
	-- We track this so we can update the volume of any
	-- savestate that is loaded to match it. If the
	-- savestate wasn't created during a loading screen,
	-- then the change won't take effect until the player
	-- pauses and unpauses the game.
	musicVolume = memory.read_u32_le(0x075748 + m[2])
	
	
	if inTitleScreen and not lastInTitleScreen then
		tryRunGlobalFunction("clearAllRecordingData")
	end
end

function getSpyroValues()
	--Get Spyro's location
	lastSpyroX = spyroX
	lastSpyroY = spyroY
	lastSpyroZ = spyroZ
	lastSpyroDirection = spyroDirection
	
	spyroX = memory.read_u32_le(0x078A58 + m[4])
	spyroY = memory.read_u32_le(0x078A5C + m[4])
	spyroZ = memory.read_u32_le(0x078A60 + m[4])
	spyroDirection = memory.read_s16_le(0x078A66 + m[4]) / 256 * _tau
	if spyroDirection < 0 then spyroDirection = spyroDirection + _tau end
	
	xSpeed = spyroX - lastSpyroX
	ySpeed = spyroY - lastSpyroY
	zSpeed = spyroZ - lastSpyroZ
	
	lastSpyroSpeed = spyroSpeed
	spyroSpeed = math.sqrt(xSpeed * xSpeed + ySpeed * ySpeed + zSpeed * zSpeed)
	lastSpyroGroundSpeed = spyroGroundSpeed
	spyroGroundSpeed = math.sqrt(xSpeed * xSpeed + ySpeed * ySpeed)
	lastSpyroLogicalSpeed = spyroLogicalSpeed
	spyroLogicalSpeed = memory.read_s8(0x078B71 + m[4])
	
	--Get grounded state
	lastFrameGrounded = thisFrameGrounded
	thisFrameGrounded = memory.read_s32_le(0x078BB4 + m[4])
	
	
	
	lastSpyroAnimation = spyroAnimation
	spyroAnimation = 1
	
	lastState076E90 = state076E90
	state076E90 = memory.read_u16_le(0x076E90 + m[4])
	
	if state076E90 == 3 then spyroAnimation = 2
	elseif state076E90 == 5 then spyroAnimation = 3 end
	
	if state076E90 == 0x0F and lastState076E90 ~= 0x0F then bonkCounter = bonkCounter + 1 end
end

function getCameraValues()
	--Handle rolling the buffer
	for i=bufferLength,2,-1 do
		cameraX_buffer[i] = cameraX_buffer[i - 1]
		cameraY_buffer[i] = cameraY_buffer[i - 1]
		cameraZ_buffer[i] = cameraZ_buffer[i - 1]
		cameraYaw_buffer[i] = cameraYaw_buffer[i - 1]
		cameraPitch_buffer[i] = cameraPitch_buffer[i - 1]
	end

	--Get camera position
	cameraX_buffer[1] = memory.read_u32_le(0x076DF8 + m[4])
	cameraY_buffer[1] = memory.read_u32_le(0x076DFC + m[4])
	cameraZ_buffer[1] = memory.read_u32_le(0x076E00 + m[4])
		
	--Get camera rotation
	
	cameraYaw_buffer[1] = memory.read_u16_le(0x076E20 + m[4]) / 0x800 * _pi
	
	cameraPitch_buffer[1] = bit.lshift(memory.read_u16_le(0x076E1E + m[4]), 4) / 0x8000 * _pi
	if cameraPitch_buffer[1] >= _pi then cameraPitch_buffer[1] = cameraPitch_buffer[1] - _tau end
	
	--Update camera variables
	bufferIndex = bufferIndex + 1
	if bufferIndex > bufferLength then
		bufferIndex = bufferLength
	end
	
	cameraX = cameraX_buffer[bufferIndex]
	cameraY = cameraY_buffer[bufferIndex]
	cameraZ = cameraZ_buffer[bufferIndex]
	cameraYaw = cameraYaw_buffer[bufferIndex]
	cameraPitch = cameraPitch_buffer[bufferIndex]
	
	cameraPitch_sin = math.sin(cameraPitch)
	cameraPitch_cos = math.cos(cameraPitch)
	cameraYaw_sin = math.sin(-cameraYaw)
	cameraYaw_cos = math.cos(-cameraYaw)
end

function detectSegmentEvents()

	if inTitleScreen then return end
	
	-- Detect retry in Flight Level
	if gameState == 0 and lastGameState == 7 and recordingMode == "segment" then
		showDebug("Detected retry in flight level")
		if not segment_shownFlightLevelRestartTip then
			segment_shownFlightLevelRestartTip = true
			local reloadInput = getInputForAction("reloadSegment")
			showMessage(conditional(reloadInput == "", "Tip: the ghost won't restart until you restart the segment.", "Tip: the ghost won't restart until you restart the segment with " .. reloadInput))
		end
	end
	
	-- Detect dragon cutscene
	segment_dragonSplitThisFrame = false
	if gameState == 0 and lastGameState == 8 then
		segment_dragonSplitArmed = true
	end
	if segment_dragonSplitArmed and (spyroControl == 0 or gameState ~= 0) then
		segment_dragonSplitArmed = false
		segment_dragonSplitThisFrame = true
	end
	
	-------
	-- Detect Segment Halt (end of level, entering portal, etc.)
	-------
	
	if segment_recording ~= nil and not segment_levelStartArmed then
	
		-- Detect level entry/exit. gameState 1 is used when entering and exiting levels
		if gameState == 1 and lastGameState ~= 1 then
			segment_halt()
		end
		
		-- Detect beating Gnasty Gnorc or completing Gnasty's Loot
		if gameState == 14 and (currentLevel == 63 or currentLevel == 64) then
			segment_halt()
		end
		
		--Detect game over. gameState 5 is used during game over screen
		if gameState == 5 and lastGameState ~= 5 then
			if currentLevel % 10 ~= 0 then
				segment_halt()
				gameOverIsOverworld = false
			else
				gameOverIsOverworld = true
			end
		end
		
		--Detect Flight Level ending
		if gameState == 7 and lastGameState ~= 7 then
			--gameState 7 is used on the ending screen
			--of flight levels, whether successful or not
			if segment_recording ~= nil then
				local flightLevelObjectives = memory.read_u32_le(0x078630 + m[4])
				flightLevelObjectives = flightLevelObjectives + memory.read_u32_le(0x078634 + m[4])
				flightLevelObjectives = flightLevelObjectives + memory.read_u32_le(0x078638 + m[4])
				flightLevelObjectives = flightLevelObjectives + memory.read_u32_le(0x07863C + m[4])			
				segment_recording.flightLevel = flightLevelObjectives == 32
			end
			segment_halt()
		end
		
		--Detect balloon travel. gameState 12 is used when talking to balloonist and riding the balloon
		if gameState == 12 and memory.read_s32_le(0x07576C + m[2]) == -1 then
			segment_halt()
		end
	
	end
	
	if run_recording ~= nil and not run_runStartArmed then
	
		if currentRoute == "120" then
			-- Condition: 120% Route, which ends on exiting Gnasty's Loot with all treasure
			if gameState == 14 and currentLevel == 64 then
				-- There's no need to check the gem count, because the
				-- cutscene (gameState 14) only triggers if 120% is completed.
				run_halt()
			end
		elseif currentRoute == "80dragons" then
			-- Condition: 80 Dragon route, ending on rescuing the final dragon
			if memory.read_u32_le(0x075750 + m[2]) == 80 then
				run_halt()
			end
		else
			-- Condition: All other routes, including any%, which should end on killing Gnasty Gnorc
			if memory.read_s8(memory.read_u32_le(0x075828 + m[3]) + 0x48) == 8 then
				run_halt()
			end
		end	
	end
	
	-------
	-- Load Ghost
	-------
	if lastLoadingState ~= 10 and loadingState == 10 and gameState ~= 14 and (gameState ~= 5 or not gameOverIsOverworld) and (recordingMode == "segment" or recordingMode == "run") and not segment_levelStartArmed then
		segment_levelStartArmed = true
		segment_loadGhosts()
		
		if recordingMode == "run" and currentSegment[2] == 10 and currentSegment[3] == "Entry" then
			run_runStartArmed = true
			run_loadGhosts()
		end
	end
	
	-------
	-- Create Save State
	-------
	if lastLoadingState ~= 12 and loadingState == 12 and gameState ~= 14 and (gameState ~= 5 or not gameOverIsOverworld) and (recordingMode == "segment" or recordingMode == "run") then
		
		local folder = "Savestates"
		if not file.exists(folder) then
			file.createFolder(folder) 
		end
		
		local f = file.combinePath(folder, displayType .. " - " .. "segment" .. " - " .. currentRoute .. " - " .. segmentToString(currentSegment) .. " - v1.state")
	
		if not file.exists(f) then
			savestate.save(f)
			setGlobalVariable({"savestateData", "segment", currentRoute, segmentToString(currentSegment)}, f)
			showDebug("Created save state: " .. f)
		end
	end
	
	-------
	-- Start segment
	-------
	
	-- Detect start of segment, when gaining control of Spyro after the segment_levelStartArmed flag has been set
	if spyroControl == 0 and lastSpyroControl > 0 and segment_levelStartArmed and (recordingMode == "segment" or recordingMode == "run") then
		segment_levelStartArmed = false
		segment_start()
	end
	
	-- Detect start of segment, when gaining control of Spyro after the segment_levelStartArmed flag has been set
	if spyroControl == 0 and lastSpyroControl > 0 and run_runStartArmed and recordingMode == "run" then
		run_runStartArmed = false
		run_start()
	end
end

-------------------------
-- Drawing functions
-------------------------

do
	showSpyroPosition = 0
	showArtisanProps = 0
	showSunnyFlightScanner = false
	
	showBonkCounter = false
	bonkCounter = 0
	showSpeed = 0
	showGroundSpeed = 0
	showLogicalSpeed = 0
	
	spyroX0 = 0
	spyroX1 = 0
	spyroX2 = 0
	spyroY0 = 0
	spyroY1 = 0
	spyroY2 = 0
	spyroZ0 = 0
	spyroZ1 = 0
	spyroZ2 = 0
	spyroDirection0 = 0
	spyroDirection1 = 0
	spyroDirection2 = 0
end

function drawProps()
	--Artisans Props
	if showArtisanProps == 2 or (showArtisanProps == 1 and currentLevel == 10) then
		drawArtisanProps()
	end
	
	--Sunny Flight Scanner
	if showSunnyFlightScanner and currentLevel == 15 and menu_showInputs < 1 then
		drawSunnyFlightScanner()
	end
	
	--Axis
	if showSpyroPosition > 0 then
		spyroX2 = spyroX1
		spyroX1 = spyroX0
		spyroY2 = spyroY1
		spyroY1 = spyroY0
		spyroZ2 = spyroZ1
		spyroZ1 = spyroZ0
		spyroDirection2 = spyroDirection1
		spyroDirection1 = spyroDirection0

		local axisLength = 1500
		spyroX0 = memory.read_u32_le(0x078A58 + m[4])
		spyroY0 = memory.read_u32_le(0x078A5C + m[4])
		spyroZ0 = memory.read_u32_le(0x078A60 + m[4])
		--drawLine_world(spyroX, spyroY, spyroZ - spyroZOffset, spyroX, spyroY, spyroZ)
		--drawLine_world(spyroX - axisLength, spyroY, spyroZ - spyroZOffset, spyroX + axisLength, spyroY, spyroZ - spyroZOffset)
		--drawLine_world(spyroX, spyroY - axisLength, spyroZ - spyroZOffset, spyroX, spyroY + axisLength, spyroZ - spyroZOffset)
		
		--spyroDirection0 = memory.read_u32_le(0x078B74 + m[4]) / 4096 * _tau
		spyroDirection0 = memory.read_s16_le(0x078A66 + m[4]) / 256 * _tau
		
		if showSpyroPosition == 1 then
			drawGhost({spyroX0, spyroY0, spyroZ0}, spyroDirection0, spyroAnimation)
		elseif showSpyroPosition == 2 then
			drawGhost({spyroX2, spyroY2, spyroZ2}, spyroDirection2, spyroAnimation)
		end
	end
end

function drawArtisanProps()
	--Towers
	if true then
		for iz = 9420, 20420, 1000 do
				drawCross_world(77831, 23375, iz)
				drawCross_world(92011, 23375, iz)				
		end
	end
	
	--Rook
	if true then
		local z2 = 9334 - spyroZOffset--floor height
		local z1 = z2 - 1000--base height
		local z3 = z2 + 700--crenel height
		local z4 = z3 + 700--merlon height
		
		local xc = 98511
		local yc = 39528
		
		local x = {
			98107 - xc,
			99151 - xc,
			99483 - xc,
			98979 - xc,
			98090 - xc,
			97671 - xc
		}
		x[7] = x[1]
		local y = {
			40354 - yc,
			40379 - yc,
			39492 - yc,
			38720 - yc,
			38749 - yc,
			39605 - yc
		}
		y[7] = y[1]
		
		local o1 = 1.6--outset1: factor from inner ring to inside of parapet
		local o2 = 2.2--outset2: factor from inner ring to outside of parapet
		
		local c2 = 0.3--crenel inset
		local c1 = 1 - c2
		
		for i = 1, 6 do
			drawLine_world(xc + x[i], yc + y[i], z2, xc + x[i] * o1, yc + y[i] * o1, z2)
			drawLine_world(xc + x[i] * o1, yc + y[i] * o1, z2, xc + x[i + 1] * o1, yc + y[i + 1] * o1, z2)
			drawLine_world(xc + x[i] * o1, yc + y[i] * o1, z2, xc + x[i] * o1, yc + y[i] * o1, z4)
			drawLine_world(xc + x[i] * o2, yc + y[i] * o2, z4, xc + x[i] * o2, yc + y[i] * o2, z2)
			drawLine_world(xc + x[i] * o2, yc + y[i] * o2, z2, xc + x[i + 1] * o2, yc + y[i + 1] * o2, z2)
			drawLine_world(xc + x[i] * o2, yc + y[i] * o2, z2, xc + x[i], yc + y[i], z1)
			drawLine_world(xc + x[i], yc + y[i], z1, xc + x[i + 1], yc + y[i + 1], z1)
			
			drawLine_world(
				xc + x[i] * o1,
				yc + y[i] * o1,
				z4,
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z4
			)
			drawLine_world(
				xc + x[i] * o2,
				yc + y[i] * o2,
				z4,
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z4
			)
			drawLine_world(
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z4,
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z4
			)
			drawLine_world(
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z4,
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z3
			)
			drawLine_world(
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z4,
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z3
			)
			drawLine_world(
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z3,
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z3
			)
			drawLine_world(
				((xc + x[i] * o1) * c1) + ((xc + x[i + 1] * o1) * c2),
				((yc + y[i] * o1) * c1) + ((yc + y[i + 1] * o1) * c2),
				z3,
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z3
			)
			drawLine_world(
				((xc + x[i] * o2) * c1) + ((xc + x[i + 1] * o2) * c2),
				((yc + y[i] * o2) * c1) + ((yc + y[i + 1] * o2) * c2),
				z3,
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z3
			)
			drawLine_world(
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z3,
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z3
			)
			drawLine_world(
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z3,
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z4
			)
			drawLine_world(
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z3,
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z4
			)
			drawLine_world(
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z4,
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z4
			)
			drawLine_world(
				((xc + x[i] * o1) * c2) + ((xc + x[i + 1] * o1) * c1),
				((yc + y[i] * o1) * c2) + ((yc + y[i + 1] * o1) * c1),
				z4,
				xc + x[i + 1] * o1,
				yc + y[i + 1] * o1,
				z4
			)
			drawLine_world(
				((xc + x[i] * o2) * c2) + ((xc + x[i + 1] * o2) * c1),
				((yc + y[i] * o2) * c2) + ((yc + y[i + 1] * o2) * c1),
				z4,
				xc + x[i + 1] * o2,
				yc + y[i + 1] * o2,
				z4
			)
		end
	end
	
	--Pyramid
	if true then
		--ring
		local v1 = {76864, 50240, 6912}
		local v2 = {77312, 49152, 6912}
		local v3 = {76864, 48064, 6912}
		local v4 = {75776, 47616, 6912}
		local v5 = {74688, 48064, 6912}
		local v6 = {74240, 49152, 6912}
		local v7 = {74688, 50240, 6912}
		local v8 = {75776, 50688, 6912}
		--top
		local v9 = {75694, 49152, 8992}

		drawLine_worldVector(v1, v2)
		drawLine_worldVector(v2, v3)
		drawLine_worldVector(v3, v4)
		drawLine_worldVector(v4, v5)
		drawLine_worldVector(v5, v6)
		drawLine_worldVector(v6, v7)
		drawLine_worldVector(v7, v8)
		drawLine_worldVector(v8, v1)
		
		drawLine_worldVector(v1, v9)
		drawLine_worldVector(v2, v9)
		drawLine_worldVector(v3, v9)
		drawLine_worldVector(v4, v9)
		drawLine_worldVector(v5, v9)
		drawLine_worldVector(v6, v9)
		drawLine_worldVector(v7, v9)
		drawLine_worldVector(v8, v9)
	end
	
	--Rotating Ghost
	if true then
		drawGhost({84837, 37883, 10687}, emu.framecount() / 60)
	end
end

function drawSunnyFlightScanner()
	-- This function draws a minimap of the area surrounding
	-- the planes in Sunny Flight. It also shows the
	-- locations of passing trains, planes, and Spyro. Spyro
	-- is drawn with a circle surrounding him. Planes will
	-- move if they are inside this circle or if the camera
	-- is pointed at them.
	
	-- Load map if needed (if it has not yet been loaded)
	if sunnyFlightScanner_verts == nil then
		f = assert(io.open(file.combinePath("assets", "Sunny Flight Map.obj"), "r"))
		sunnyFlightScanner_verts = {}
		sunnyFlightScanner_lines = {}
		local sunnyFlightScanner_verts = sunnyFlightScanner_verts
		local sunnyFlightScanner_lines = sunnyFlightScanner_lines
		
		local scale = 1000
			
		while true do
			local t = f:read()
			if t == nil then break end
			
			if bizstring.startswith(t, "v ") then
				local list = bizstring.split(t, " ")
				table.insert(sunnyFlightScanner_verts, {math.floor(tonumber(list[2]) * scale), math.floor(tonumber(list[3]) * scale)})
				
			elseif bizstring.startswith(t, "l ") then
				list = bizstring.split(t, " ")
				local line = {tonumber(list[2]), tonumber(list[3])}
				table.insert(sunnyFlightScanner_lines, line)
			end
		end
	end

	-- Functions to convert world coordinates into map coordinates
	local function convertX(x)
		-- return (x - map_xOrigin) / map_scale + (the location of the map origin on the screen)
		return (x - 32000) / 500 + border_left
	end
	local function convertY(y)
		-- y is subtracted from map_yOrigin to flip the map vertically.
		return (170000 - y) * m.pixelRatio / 500 + border_top + ((displayType == "NTSC") and 34 or 42)
	end
	
	-- Function to check if a position is within the map bounds
	local function isOnMap(x, y)
		return y > 70000 and y < 170000 and x > 32000 and x < ((y > 110000) and ((y < 155500) and 108000 or 98000) or 92000)
	end
	
	-- Draw a triangle at the x, y screen coordinates
	local function drawDart(x, y, direction, length, width, lineColor, backColor)
		-- direction is in radians
	
		local pointer = {{length, 0}, {-length * 2 / 3, width}, {-length * 2 / 3, -width}}
		local rotatedPointer = {}
		for i, v in ipairs(pointer) do
			table.insert(rotatedPointer, {
				math.cos(direction) * v[1] + math.sin(direction) * v[2],
				(math.cos(direction) * v[2] - math.sin(direction) * v[1]) * m.pixelRatio,
			})
		end
		gui.drawPolygon(rotatedPointer, x, y, 0, backColor)
		gui.drawPolygon(rotatedPointer, x, y, lineColor, 0)
	end
	
	-- Check we're in Sunny Flight
	if currentLevel == 15 and bit.band(2 ^ gameState, 0x9D) > 0 then
		-- Initialize variables globally if needed.
		if not sunnyFlightScanner_plane_lastCoords then sunnyFlightScanner_plane_lastCoords = {{},{},{},{},{},{},{},{},} end
		if not sunnyFlightScanner_plane_active then sunnyFlightScanner_plane_active = {} end
		
		-- Create local references to the global variables for faster access.
		local sunnyFlightScanner_plane_lastCoords = sunnyFlightScanner_plane_lastCoords
		local sunnyFlightScanner_plane_active = sunnyFlightScanner_plane_active
		local sunnyFlightScanner_verts = sunnyFlightScanner_verts
		
		-- Draw map
		for i, v in ipairs(sunnyFlightScanner_lines) do
			gui.drawLine(convertX(sunnyFlightScanner_verts[v[1]][1]), convertY(sunnyFlightScanner_verts[v[1]][2]), convertX(sunnyFlightScanner_verts[v[2]][1]), convertY(sunnyFlightScanner_verts[v[2]][2], 0xFF000000))
		end
		
		local regionOffset = (displayType == "NTSC") and 0x00 or 0x0994
		
		-- Spyro's coordinates
		local sx = memory.read_u32_le(0x078A58 + m[4])
		local sy = memory.read_u32_le(0x078A5C + m[4])
		
		-- Draw the Planes
		for i = 0, 7 do
			if memory.read_s8(0x1756D0 + regionOffset + i * 0x58 + 0x48) >= 0 and memory.read_u32_le(0x1756D0 + regionOffset + i * 0x58 + 0x18) == 0 then
				local px = memory.read_u32_le(0x1756D0 + regionOffset + i * 0x58 + 0x0C)
				local py = memory.read_u32_le(0x1756D0 + regionOffset + i * 0x58 + 0x10)
				
				local color = (memory.read_s8(0x1756D0 + regionOffset + i * 0x58 + 0x51) > 0 or (math.sqrt((px - sx) ^ 2 + (py - sy) ^ 2) < 0x4000)) and 0xFFFFFFFF or 0xFFFF0000
				drawDart(convertX(px), convertY(py), memory.read_u8(0x1756D0 + regionOffset + i * 0x58 + 0x46) * 2 * math.pi / 256, 8, 4, 0xFF000000, color)
			end
		end
		
		-- Draw the Trains
		for i = 11, 0, -1 do -- Counting backwards so the front of each train is drawn last.
			if memory.read_s8(0x175990 + regionOffset + i * 0x58 + 0x48) >= 0 and memory.read_u32_le(0x175990 + regionOffset + i * 0x58 + 0x18) == 0 then
				local tx = memory.read_u32_le(0x175990 + regionOffset + i * 0x58 + 0x0C)
				local ty = memory.read_u32_le(0x175990 + regionOffset + i * 0x58 + 0x10)
				if isOnMap(tx, ty) then
					gui.drawEllipse(convertX(tx)-3, convertY(ty)-2, 6, 4, 0xFF000000, (i % 3 == 0) and 0xFFA0A0A0 or 0xFFA04010)
				end
			end
		end
		
		-- Draw Spyro
		if true then
			if isOnMap(sx, sy) then
				drawDart(convertX(sx), convertY(sy), memory.read_u8(0x078A66 + m[4]) * 2 * math.pi / 256, 5, 8, 0xFF300050, 0xFFB080E0)
				local r = 0x4000
				local x = convertX(sx-r)
				local y = convertY(sy-r)
				local w = convertX(sx+r)-x
				local h = convertY(sy+r)-y
				gui.drawEllipse(x, y, w, h, 0x80300050, 0x00)
			end
		end
		
		--[[ This code draws guide lines that define the border of the map
		local function drawV(x, y1, y2)
			gui.drawLine(convertX(x), convertY(y1), convertX(x), convertY(y2))
		end
		local function drawH(y, x1, x2)
			gui.drawLine(convertX(x1), convertY(y), convertX(x2), convertY(y))
		end
		
		drawH(170000, 0, 108000)
		 drawH(155500, 0, 108000)
		drawH(110000, 0, 108000)
		drawH(70000, 0, 108000)
		drawV(108000, 70000, 170000)
		 drawV(98000, 70000, 170000)
		drawV(92000, 70000, 170000)
		drawV(32000, 70000, 170000)
		--]]
	end
end

function worldSpaceToScreenSpace(x, y, z)
	local relativeX = x - cameraX
	local relativeY = y - cameraY
	--local relativeZ = z - cameraZ
	
	local rotatedX = math.cos(-cameraYaw) * relativeX - math.sin(-cameraYaw) * relativeY
    --local rotatedY = math.sin(-cameraYaw) * relativeX + math.cos(-cameraYaw) * relativeY
    local rotatedZ = z - cameraZ--relativeZ

    local pitchedX = math.cos(cameraPitch) * rotatedX - math.sin(cameraPitch) * rotatedZ
    local pitchedY = math.sin(-cameraYaw) * relativeX + math.cos(-cameraYaw) * relativeY-- rotatedY
    local pitchedZ = math.sin(cameraPitch) * rotatedX + math.cos(cameraPitch) * rotatedZ
	
	if pitchedX < nearClip then
		return 0, 0
	end
	
	--viewport should range from -1 to 1
	local viewportX = (pitchedY / pitchedX) * FOVx
	local viewportY  = (pitchedZ / pitchedX) * FOVy
	
	--screen should vary from 0 to width/height (560/240)
	local screenX = (viewportX * -screen_halfWidth) + screen_halfWidth
	local screenY = (viewportY * -screen_halfHeight) + screen_halfHeight + screen_yOffset
	
	return screenX, screenY
end

function drawCross_world (x, y, z)
	local sx, sy = worldSpaceToScreenSpace(x, y, z)
	if sx == 0 then return end
	local width = 4
	local height = 3
	drawLine_screen (sx-width, sy, sx+width, sy)
	drawLine_screen (sx, sy-height, sx, sy+height)
end

function drawLine_worldVector (v1, v2)-- ({1, 2, 3}, {4, 5, 6})
	drawLine_world (v1[1], v1[2], v1[3], v2[1], v2[2], v2[3])
end

function drawLine_world (x1, y1, z1, x2, y2, z2)
	local scp = cameraPitch_sin
	local ccp = cameraPitch_cos
	local scy = cameraYaw_sin
	local ccy = cameraYaw_cos

	local relativeX1 = x1 - cameraX
	local relativeY1 = y1 - cameraY
	local relativeX2 = x2 - cameraX
	local relativeY2 = y2 - cameraY
	
	local rotatedX1 = ccy * relativeX1 - scy * relativeY1
	local rotatedZ1 = z1 - cameraZ
	local rotatedX2 = ccy * relativeX2 - scy * relativeY2
	local rotatedZ2 = z2 - cameraZ
	
	local pitchedX1 = ccp * rotatedX1 - scp * rotatedZ1
	local pitchedX2 = ccp * rotatedX2 - scp * rotatedZ2

	local pitchedY1 = scy * relativeX1 + ccy * relativeY1
	local pitchedZ1 = scp * rotatedX1 + ccp * rotatedZ1
	local pitchedY2 = scy * relativeX2 + ccy * relativeY2
	local pitchedZ2 = scp * rotatedX2 + ccp * rotatedZ2
	
	if pitchedX1 < nearClip then
		if pitchedX2 < nearClip then
			return
		end
		pitchedY1 = pitchedY1 + (pitchedY2-pitchedY1)/(pitchedX2-pitchedX1)*(nearClip-pitchedX1)
		pitchedZ1 = pitchedZ1 + (pitchedZ2-pitchedZ1)/(pitchedX2-pitchedX1)*(nearClip-pitchedX1)
		pitchedX1 = nearClip
	end
	
	if pitchedX2 < nearClip then
		pitchedY2 = pitchedY2 + (pitchedY1-pitchedY2)/(pitchedX1-pitchedX2)*(nearClip-pitchedX2)
		pitchedZ2 = pitchedZ2 + (pitchedZ1-pitchedZ2)/(pitchedX1-pitchedX2)*(nearClip-pitchedX2)
		pitchedX2 = nearClip
	end
	
	drawLine_screen(
		screen_halfWidth * (((pitchedY1 / pitchedX1) * -FOVx) + 1),
		screen_halfHeight * (((pitchedZ1 / pitchedX1) * -FOVy) + 1),
		screen_halfWidth * (((pitchedY2 / pitchedX2) * -FOVx) + 1),
		screen_halfHeight * (((pitchedZ2 / pitchedX2) * -FOVy) + 1)
	)	
	
end

function drawLine_screen (x1, y1, x2, y2)
	if x1 == 0 or x2 == 0 then return end
	
	local sameSide = false
	if math.abs(x1-x2) > 0.5 then
		local intercept_left = y1 - ((y2-y1)/((x2-border_left)-(x1-border_left)))*(x1-border_left)
		local intercept_right = y1 - ((y2-y1)/((x2-border_right)-(x1-border_right)))*(x1-border_right)
		if x1 < border_left then
			x1 = border_left
			y1 = intercept_left
			sameSide = true
		end
		if x2 < border_left then
			x2 = border_left
			y2 = intercept_left
			if sameSide then return end
		end
		sameSide = false
		if x1 > border_right then
			x1 = border_right
			y1 = intercept_right
			sameSide = true
		end
		if x2 > border_right then
			if sameSide then return end
			x2 = border_right
			y2 = intercept_right
		end
	else
		if x1 < border_left or x1 > border_right or x2 < border_left or x2 > border_right then return end
	end
	
	if math.abs(y1-y2) > 0.5 then
		local intercept_top = x1 - ((x2-x1)/((y2-border_top)-(y1-border_top)))*(y1-border_top)
		local intercept_bottom = x1 - ((x2-x1)/((y2-border_bottom)-(y1-border_bottom)))*(y1-border_bottom)
		sameSide = false
		if y1 < border_top then
			y1 = border_top
			x1 = intercept_top
			sameSide = true
		end
		if y2 < border_top then
			y2 = border_top
			x2 = intercept_top
			if sameSide then return end
		end
		sameSide = false
		if y1 > border_bottom then
			y1 = border_bottom
			x1 = intercept_bottom
			sameSide = true
		end
		if y2 > border_bottom then
			if sameSide then return end
			y2 = border_bottom
			x2 = intercept_bottom
		end
	else
		if y1 < border_top or y1 > border_bottom or y2 < border_top or y2 > border_bottom then return end
	end
	
	gui.drawLine(x1, y1, x2, y2, drawColor)
end

do
	ghostVerts = {}

	local foot_side = 140
	local back_side = foot_side
	local back_rear_side = back_side
	local foot_back_forward = -220
	local foot_front_forward = 120
	local foot_point_forward = foot_front_forward + foot_side
	
	local cheek_forward = foot_front_forward
	
	local back_height = -80
	local nose_height = 20
	local nose_forward = 320
	local head_front_height = 220
	local head_front_forward = 180
	local head_rear_height = 220
	local head_rear_forward = 0
	
	for i = 1, 3 do
	
		if i == 2 then --charge
			head_front_height = 0
			head_front_forward = 360
			head_rear_height = 50
			head_rear_forward = 100
			nose_forward = 420
			nose_height = -100
			cheek_forward = 200
		elseif i == 3 then --glide
			back_side = 280
			back_rear_side = 200
			head_front_height = 0
			head_front_forward = 360
			head_rear_height = 50
			head_rear_forward = 100
			nose_forward = 420
			nose_height = -100
			cheek_forward = 200
		end
	
		ghostVerts[i] = {
			{foot_point_forward, 0, -spyroZOffset},
			{foot_front_forward, -foot_side, -spyroZOffset},
			{foot_back_forward, -foot_side, -spyroZOffset},
			{foot_back_forward, foot_side, -spyroZOffset},
			{foot_front_forward, foot_side, -spyroZOffset},
			{nose_forward, 0, nose_height},
			{cheek_forward, -back_side, nose_height},
			{foot_back_forward, -back_rear_side, back_height},
			{foot_back_forward, back_rear_side, back_height},
			{cheek_forward, back_side, nose_height},
			{head_front_forward, 0, head_front_height},
			{head_rear_forward, 0, head_rear_height},
		}
	end
end

function drawGhost(position, rotation, animation, color)
	local oldDrawColor = drawColor
	if color ~= nil then drawColor = color end
	
	if animation == 0 or animation == nil then animation = 1 end
	
	local v1 = transform(ghostVerts[animation][1], position, rotation)--arrow point
	local v2 = transform(ghostVerts[animation][2], position, rotation)--front right foot
	local v3 = transform(ghostVerts[animation][3], position, rotation)--back right foot
	local v4 = transform(ghostVerts[animation][4], position, rotation)
	local v5 = transform(ghostVerts[animation][5], position, rotation)
	
	local v6 = transform(ghostVerts[animation][6], position, rotation)
	local v7 = transform(ghostVerts[animation][7], position, rotation)
	local v8 = transform(ghostVerts[animation][8], position, rotation)
	local v9 = transform(ghostVerts[animation][9], position, rotation)
	local v10 = transform(ghostVerts[animation][10], position, rotation)
	
	local v11 = transform(ghostVerts[animation][11], position, rotation)
	local v12 = transform(ghostVerts[animation][12], position, rotation)
	
	drawLine_worldVector(v1, v2)
	drawLine_worldVector(v2, v3)
	drawLine_worldVector(v3, v4)
	drawLine_worldVector(v4, v5)
	drawLine_worldVector(v5, v1)
	drawLine_worldVector(v1, v6)
	drawLine_worldVector(v2, v7)
	drawLine_worldVector(v3, v8)
	drawLine_worldVector(v4, v9)
	drawLine_worldVector(v5, v10)
	drawLine_worldVector(v6, v7)
	drawLine_worldVector(v7, v8)
	drawLine_worldVector(v8, v9)
	drawLine_worldVector(v9, v10)
	drawLine_worldVector(v10, v6)
	drawLine_worldVector(v6, v11)
	drawLine_worldVector(v7, v11)
	drawLine_worldVector(v8, v12)
	drawLine_worldVector(v9, v12)
	drawLine_worldVector(v10, v11)
	drawLine_worldVector(v11, v12)
	
	drawColor = oldDrawColor
end

function drawFlames()
	--This was used when I was studying how the flame
	--system works in the game, but nothing in the project
	--called it anymore when I wrote this comment. It just
	--needs to be called once during each draw cycle from
	--anywhere in the main loop.
	
	--This might not work on PAL
	for i=0,7 do
		drawSingleFlame(i)
	end
end

function drawSingleFlame(index)
	-- Addresses were found on NTCS. They have not been varified on PAL 
	local flameX = memory.read_u32_le(0x0787A0 + m[4] + index * 0x0c)
	local flameY = memory.read_u32_le(0x0787A4 + m[4] + index * 0x0c)
	local flameZ = memory.read_u32_le(0x0787A8 + m[4] + index * 0x0c)
	
	local flameTimer = memory.read_u8(0x0786E8 + m[4] + index * 0x01)
	local flameState = memory.read_u8(0x0786F8 + m[4] + index * 0x01)
	
	if flameTimer > 0 and flameState == 1 then
		drawCross_world (flameX, flameY, flameZ)
	end
end

function transform(vector, position, rotation) 
	return {
		vector[1] * math.cos(rotation) - vector[2] * math.sin(rotation) + position[1],
		vector[2] * math.cos(rotation) + vector[1] * math.sin(rotation) + position[2],
		vector[3] + position[3]
	}
end

-------------------------
-- Settings Saving and Loading
-------------------------

do
	settings_file = file.combinePath("data", "settings.txt")
	
	defaultPlayerName = "Unknown"
	playerName = defaultPlayerName
	
	quickUpdatingGems = false
	
	-- A list of the global variables that will be saved to settings.txt
	globalSettings = {
		"playerName",
		"showSpyroPosition",
		"showBonkCounter",
		"showSpeed",
		"showGroundSpeed",
		"showLogicalSpeed",
		"quickUpdatingGems",
		"showArtisanProps",
		"showSunnyFlightScanner",
		"showGhostAnimations",
		"currentPalette_name",
		"recordingMode",
		"currentRoute",
		"variant_sparxless",
		"showDebugMessages",
		"timeFormat_frames",
		"showDeltaPercent",
		"segment_comparison_collection",
		"segment_comparison_target",
		"segment_comparison_useColor",
		"segment_comparison_color",
		"segment_preloadAllGhosts",
		"segment_autoSaveGhosts",
		"segment_showSubSegmentGhosts",
		"run_collection",
		"run_comparison_target",
		"run_loadXFastest",
		"run_loadXRecent",
		"run_ghostColor",
		"run_showSegmentGhosts",
		"run_showRankList",
		"run_showRankNames",
		"run_showRankPlace",
		"controls",
		"segment_settings",
	}
end

function settings_save()
	
	local settingsPackage = {}
	
	for i, v in ipairs(globalSettings) do
		settingsPackage[v] = _G[v]
	end
	
	local f = assert(io.open(settings_file, "w"))
	f:write("settingsVersion: 2", "\n")
	f:write(JSON:encode_pretty(settingsPackage))
	f:close()
	
end

function settings_load()
	if not file.exists(settings_file) then return end
	
	segment_settings = {}
	
	local f = assert(io.open(settings_file, "r"))
	
	local fileVersion = f:read()
	
	if fileVersion == "settingsVersion: 2" then
		-- Condition: This is the first version of settings
		-- file to use JSON encoding. Adding new global
		-- settings is now as simple as adding the global
		-- variable names to the globalSettings array.
		
		local settingsPackage = JSON:decode(f:read("*a"))
		
		for i, v in ipairs(globalSettings) do
			if settingsPackage[v] ~= nil then
				_G[v] = settingsPackage[v]
			end
		end
	
	elseif fileVersion == "settingsVersion: 1" then
		-- Condition: This is an outdated settings file
		-- from before JSON was used.
		
		while true do
			local t = f:read()
			if t == nil then break end
			
			tryParseSetting(t, "playerName: ", "playerName", "string")
			tryParseSetting(t, "showBonkCounter: ", "showBonkCounter", "bool")
			tryParseSetting(t, "showSpeed: ", "showSpeed", "number")
			tryParseSetting(t, "showGroundSpeed: ", "showGroundSpeed", "number")
			tryParseSetting(t, "showLogicalSpeed: ", "showLogicalSpeed", "number")
			tryParseSetting(t, "showSpyroPosition: ", "showSpyroPosition", "number")
			tryParseSetting(t, "quickUpdatingGems: ", "quickUpdatingGems", "bool")
			tryParseSetting(t, "showArtisanProps: ", "showArtisanProps", "number")
			tryParseSetting(t, "showGhostAnimations: ", "showGhostAnimations", "bool")
			tryParseSetting(t, "currentPalette_name: ", "currentPalette_name", "string")
			tryParseSetting(t, "recordingMode: ", "recordingMode", "string")
			tryParseSetting(t, "variant_sparxless: ", "variant_sparxless", "bool")
			tryParseSetting(t, "currentRoute: ", "currentRoute", "string")
			tryParseSetting(t, "showDebugMessages: ", "showDebugMessages", "bool")
			tryParseSetting(t, "timeFormat_frames: ", "timeFormat_frames", "bool")
			tryParseSetting(t, "segment_comparison_collection: ", "segment_comparison_collection", "string")
			tryParseSetting(t, "segment_comparison_target: ", "segment_comparison_target", "string")
			tryParseSetting(t, "segment_comparison_useColor: ", "segment_comparison_useColor", "bool")
			tryParseSetting(t, "segment_comparison_color: ", "segment_comparison_color", "number")
			tryParseSetting(t, "segment_preloadAllGhosts: ", "segment_preloadAllGhosts", "bool")	
			tryParseSetting(t, "segment_autoSaveGhosts: ", "segment_autoSaveGhosts", "bool")
			tryParseSetting(t, "segment_showSubSegmentGhosts: ", "segment_showSubSegmentGhosts", "bool")
			
			if string.starts(t, "segment_ghostSettings:") then
				segment_ghostSettings = {}
				
				local items = string.split(t, " ")
				local i = 2
				
				local c = "Unknown"--collection
				
				while items[i] ~= nil and items[i + 1] ~= nil do
					if items[i] == "collection" then
						c = setting_decodeString(items[i + 1])
						segment_ghostSettings_createDefault(c)
					elseif items[i] == "showAll" then
						segment_ghostSettings[c].showAll = string.lower(items[i + 1]) == "true"
					elseif items[i] == "showRecent" then
						segment_ghostSettings[c].showRecent = tonumber(items[i + 1])
					elseif items[i] == "showFastest" then
						segment_ghostSettings[c].showFastest = tonumber(items[i + 1])
					elseif items[i] == "color" then
						segment_ghostSettings[c].color = tonumber(items[i + 1])
					end
					i = i + 2
				end
			end
			
			if string.starts(t, "controls:") then
				controls = {}
			
				local m = ""--recordingMode
				
				local items = string.split(t, " ")
				local i = 2
				
				while items[i] ~= nil and items[i + 1] ~= nil do
					if items[i] == "m" then
						m = items[i + 1]
						controls[m] = {}
					else
						controls[m][items[i]] = items[i + 1]
					end
					i = i + 2
				end
			end
			
			if string.starts(t, "segment_settings:") then
				local c = ""
				local s = ""
				local last = ""
				for i,v in ipairs(string.split(t, " ")) do
					if last == "c" then
						c = v
						segment_settings[c] = {}
					end
					if last == "s" then
						s = v
						segment_settings[c][s] = {}
					end
					if last == "h" then segment_settings[c][s].health = tonumber(v) end
					if last == "l" then segment_settings[c][s].lives = tonumber(v) end
					last = v
				end
			end
			
		end
	end
	f:close()
end

function tryParseSetting(str, prefix, targetVariable, Type)
	Type = string.lower(Type)
	
	local value = nil
	
	if string.sub(str, 0, string.len(prefix)) == prefix then
		if Type == "number" then
			value = tonumber(string.sub(str, string.len(prefix) + 1))
		elseif Type == "string" then
			value = string.sub(str, string.len(prefix) + 1)
		elseif Type == "bool" or Type == "boolean" then
			value = string.lower(string.sub(str, string.len(prefix) + 1)) == "true"
		end
	end
	
	if value ~= nil then
		setGlobalVariable(targetVariable, value)
	end
end

function getCategoryHandle(segment)
	-- Important: if no category variants are set, this
	-- function MUST return currentRoute unchanged, or
	-- there will be compatibility problems.
	local s = currentRoute
	
	if variant_sparxless and not (segment[3] == "Entry" and levelInfo[segment[2]].flightLevel) then s = s .. "-sparxless" end

	return s
end

function getCategoryFolderName(route)
	if route == nil then route = currentRoute end
	
	local catList = string.split(route, "-")
	route = catList[1]
	local variants = {}
	for i = 2, #catList do
		variants[catList[i]] = true
	end
	
	local s = routeFolderNames[currentRoute]
	
	if variants.sparxless then s = s .. " Sparxless" end
	
	return s
end

function getCategoryPrettyName()
	local s = routePrettyNames[currentRoute]
	
	if variant_sparxless then s = s .. " Sparxless" end
	
	return s
end

function getSegmentHandle(segment)
	if segment == nil then segment = currentSegment end
	
	return tostring(segment[1]) .. tostring(segment[2]) .. tostring(segment[3])
end

function setting_encodeString(s)
	s = bizstring.replace(s, [[\]], [[\\]])
	s = bizstring.replace(s, [[ ]], [[\s]])
	return s
end

function setting_decodeString(s)
	s = bizstring.replace(s, [[\\]], [[\]])
	s = bizstring.replace(s, [[\s]], [[ ]])
	return s
end

-------------------------
-- User input
-------------------------

do -- Settings and defaults for the player inputs
	
	controls_default = {
		manual = {
			RS_left = "openWarpMenu",
			RS_right = "loadSavepoint",
			RS_up = "updateGhost",
			RS_down = "clearSavepoint",
			R3 = "openMenu",
			L3 = "",
		},
		segment = {
			RS_left = "openWarpMenu",
			RS_right = "reloadSegment",
			RS_up = "updateSegment",
			RS_down = "",
			R3 = "openMenu",
			L3 = "",
		},
		run = {
			RS_left = "openActionMenu",
			RS_right = "saveRun",
			RS_up = "updateSegment_run",
			RS_down = "",
			R3 = "openMenu",
			L3 = "",
		},
	}
	
	controls = nil
	
	function menu_leftAction() return (controls[recordingMode] or {}).RS_left or "" end
	function menu_rightAction() return (controls[recordingMode] or {}).RS_right or "" end
	function menu_upAction() return (controls[recordingMode] or {}).RS_up or "" end
	function menu_downAction() return (controls[recordingMode] or {}).RS_down or "" end
	function menu_R3Action() return (controls[recordingMode] or {}).R3 or "" end
	function menu_L3Action() return (controls[recordingMode] or {}).L3 or "" end
end

function controls_verify()
	if controls == nil or controls == {} then
		controls_restoreDefault()
	end
	if controls.manual == nil then controls_restoreDefault("manual") end
	if controls.segment == nil then controls_restoreDefault("segment") end
	if controls.run == nil then controls_restoreDefault("run") end
end

function controls_restoreDefault(mode)
	--if mode is nil or "", all controls will be restored
	if mode == "" then mode = nil end
	
	if mode == nil then controls = {} end
	
	for mk, mv in pairs(controls_default) do
		if mk == mode or mode == nil then
			controls[mk] = {}
			
			for ck, cv in pairs(mv) do
				controls[mk][ck] = cv
			end
		end
	end
end

function requireMainMenuAction()
	--This function ensures there is an option to open the
	--main menu, creating one if it does not exist.
	--The priority array lists all the actions that will be
	--checked. If no main menu option is found, then it
	--will bind the main menu to the first input to not
	--have an action bound to it. If all the inputs have
	--actions bound, then the first will be overwritten.
	local priority = {"R3", "RS_down", "RS_up", "RS_left", "RS_right", "L3"}
	
	--Check if there are any "open menu" actions available in the current recordingMode's controls.
	local menuOptionNeeded = true
	for i, v in ipairs(priority) do
		if (controls[recordingMode] or {})[v] == "openMenu" then
			menuOptionNeeded = false
		end
	end
	
	--No "open menu" was found, so search for an empty control to put it in.
	if menuOptionNeeded then
		for i, v in ipairs(priority) do
			if ((controls[recordingMode] or {})[v] or "") == "" then
				controls[recordingMode][v] = "openMenu"
				menuOptionNeeded = false
				break
			end
		end
	end
	
	--No empty control was found, so overwrite the first option.
	if menuOptionNeeded then
		controls[recordingMode][priority[1]] = "openMenu"
	end
end

function handleUserInput()
	
	-----
	-- Handle user inputs
	-----
	
	-- No menu is open
	if menu_state == nil then
		
		if inputs.rightStick_left.press then
			handleAction(menu_leftAction())
		end
		
		if inputs.rightStick_right.press then
			handleAction(menu_rightAction())
		end
		
		if inputs.rightStick_up.press then
			handleAction(menu_upAction())
		end
		
		if inputs.rightStick_down.press then
			handleAction(menu_downAction())
		end
		
		if inputs.R3.press then
			handleAction(menu_R3Action())
		end
		
		if inputs.L3.press then
			handleAction(menu_L3Action())
		end
	
	else
		-- Menu is open
		menuChangedThisFrame = false
		
		if inputs.any_down.menuPress then
			
			-- Call the menu's custom function, if any.
			-- Otherwise, use the default behavior.
			if type(menu_currentData.downFunction) == "function" then
				menu_currentData:downFunction()
			else
				if type(menu_items) == "table" then
					menu_cursor = menu_cursor + 1
					if menu_cursor > #menu_items then menu_cursor = 1 end
					menu_cursorFlash_timer = menu_cursorFlash_period
					menu_cursorFlash = true
				end
				
				if type((menu_currentData or {}).updateFunction) == "function" then
					menu_currentData:updateFunction()
				end
			end
		end
		
		if inputs.any_up.menuPress then
			
			-- Call the menu's custom function, if any.
			-- Otherwise, use the default behavior.
			if type(menu_currentData.upFunction) == "function" then
				menu_currentData:upFunction()
			else
				if type(menu_items) == "table" then
					menu_cursor = menu_cursor - 1
					if menu_cursor < 1 then menu_cursor = #menu_items end
					menu_cursorFlash_timer = menu_cursorFlash_period
					menu_cursorFlash = true
				end
				
				if type((menu_currentData or {}).updateFunction) == "function" then
					menu_currentData:updateFunction()
				end
			end
		end
		
		if inputs.X.press then
			menu_select()
		elseif inputs.square.press then
			menu_select(true)
		end
		
		if inputs.any_right.menuPress then
		
			-- Call the menu's custom function, if any.
			-- Otherwise, use the default behavior.
			if type(menu_currentData.rightFunction) == "function" then
				menu_currentData:rightFunction()
			else
				menu_right()
			end
		end
		
		if inputs.any_left.menuPress then
		
			-- Call the menu's custom function, if any.
			-- Otherwise, use the default behavior.
			if type(menu_currentData.leftFunction) == "function" then
				menu_currentData:leftFunction()
			else
				menu_left()
			end
		end
		
		if inputs.triangle.press then
			if type(menu_currentData.backFunction) == "function" then
				menu_currentData:backFunction()
			else
				menu_back()
			end
		end
		
		if inputs.R3.press then
			menu_back()
			menu_close()
		end		
	end
end

function getInputForAction(action)
	if type(action) ~= "string" then return "" end

	local input = ""
	if menu_leftAction() == action then input = "Right Stick: Left" end
	if menu_rightAction() == action then input = "Right Stick: Right" end
	if menu_upAction() == action then input = "Right Stick: Up" end
	if menu_downAction() == action then input = "Right Stick: Down" end
	if menu_R3Action() == action then input = "R3" end
	if menu_L3Action() == action then input = "L3" end
	
	return input
end

--These are the actions the player can use while outside
--the menu system.
action_data = {
	{
		name = "openMenu",
		
		prettyName = "Open Menu",
		recordingMode = "global",
		description = "Open the menu. (R3 can always be used to close the menu once open)",
		actionFunction = function()
			menu_open("main menu")
		end,
	},
	{
		name = "openWarpMenu",
		
		prettyName = "Open Warp Menu",
		recordingMode = "global",
		description = "Open the warp menu.",
		actionFunction = function()
			menu_open("warp menu", 0)
			if currentLevel > 0 then
				menu_open("warp menu", currentLevel - (currentLevel % 10))
				if currentLevel % 10 > 0 then
					menu_open("warp menu", currentLevel)
				end
			end
		end,
	},
	{
		name = "openActionMenu",
		
		prettyName = "Open Action Menu",
		recordingMode = "global",
		description = "Open the action menu.",
		actionFunction = function()
			menu_open("action menu")
		end,
	},
	{
		name = "setSavepoint",
		
		prettyName = "Set Savepoint",
		recordingMode = "manual",
		description = "Create a savepoint and begin recording a ghost from it. These savepoints do not currently presist when you reload the lua script.",
		actionFunction = function()
			showMessage("Set new savepoint and started recording")
			createQuickSavestate()
			manual_ghost = nil
			rebuildAllGhosts = true
			manual_recording = Ghost.startNewRecording("manual")
			manual_stateExists = true
		end,
	},
	{
		name = "loadSavepoint",
		
		prettyName = "Load Savepoint",
		recordingMode = "manual",
		description = "Load the current savepoint and play back the currently saved ghost (if any). Creates a savepoint if none currently exists.",
		actionFunction = function()
			if manual_stateExists then
				--Condition: There is a already a savestate, so load it
				showMessage("Loaded savepoint and started new recording")
				loadQuickSavestate()
				if Ghost.isGhost(manual_ghost) then
					manual_ghost:startPlayback()
				end
			else
				--Condition: There is currently no savestate, so create a new one
				showMessage("Set new savepoint and started recording")
				createQuickSavestate()
				manual_stateExists = true
			end
			
			manual_recording = Ghost.startNewRecording("manual")
		end,
	},
	{
		name = "clearSavepoint",
		
		prettyName = "Clear Savepoint",
		recordingMode = "manual",
		description = "Removes the current savepoint. Useful if you are using \"Load Savepoint\" to both create and load savepoints.",
		actionFunction = function()
			showMessage("Cleared savepoint and recordings")
			manual_recording = nil
			manual_ghost = nil
			rebuildAllGhosts = true
			manual_stateExists = false
		end,
	},
	{
		name = "updateGhost",
		
		prettyName = "Update Ghost",
		recordingMode = "manual",
		description = "Overwrite the current ghost. Manual ghosts cannot currently be saved to file.",
		actionFunction = function()
			if Ghost.isGhost(manual_recording) then
				showMessage("Saved recording")
				manual_recording:endRecording()
				manual_ghost = manual_recording
				rebuildAllGhosts = true
				manual_recording = nil
			else
				showMessage("No recording to update")
			end
		end,
	},
	{
		name = "playGhost",
		
		prettyName = "Play Ghost",
		recordingMode = "manual",
		description = "Start the currently saved ghost without loading the savepoint.",
		actionFunction = function()
			if Ghost.isGhost(manual_ghost) then
				showMessage("Playing currently saved recording")
				manual_ghost:startPlayback()
			else
				if Ghost.isGhost(manual_recording) then
					showMessage("Saving current recording and playing it")
					manual_ghost = manual_recording
					rebuildAllGhosts = true
					manual_recording = nil
					manual_ghost:startPlayback()
				else
					showMessage("No recording to play")
				end
			end
		end,
	},
	{
		name = "updateSegment",
		
		prettyName = "Save Segment Ghost",
		recordingMode = "segment",
		description = "Save the most recently completed segment ghost. (Only available after completing a segment)",
		actionFunction = function()
			if segment_readyToUpdate and segment_lastRecording ~= nil then
				local g = segment_lastRecording
				local folder = file.combinePath("Ghosts", playerName, recordingModeFolderNames[g.mode], getCategoryFolderName(g.category))
				if not file.exists(folder) then
					file.createFolder(folder)
				end
				
				local f = tostring(g.segment[2]) .. " " .. levelInfo[g.segment[2]].name .. " " .. g.segment[3] .. " " .. getFormattedTime(g.length, false, true, true) .. " " .. g.playerName .. " - " .. bizstring.replace(g.uid, g.playerName, "") .. ".txt"
				saveRecordingToFile(file.combinePath(folder, f), segment_lastRecording)
				
				addNewGhostMeta({
					segment = segmentToString(segment_lastRecording.segment),
					filePath = file.combinePath(folder, f),
					playerName = segment_lastRecording.playerName,
					uid = segment_lastRecording.uid,
					category = segment_lastRecording.category,
					collection = playerName,
					length = segment_lastRecording.length,
					timestamp = segment_lastRecording.timestamp,
					mode = segment_lastRecording.mode,
				})
				
				segment_readyToUpdate = false
				showMessage("Saved recording!")
			end
		end,
	},
	{
		name = "updateSegment_run",
		
		prettyName = "Save Segment Ghost",
		recordingMode = "run",
		description = "Save the most recently completed segment ghost. (Only available after completing a segment)",
		actionFunction = function()
			-- Proxy to the regular updateSegment action.
			-- This must be done this way because actions cannot currently
			-- belong to multiple recordingModes unless they are global.
			handleAction("updateSegment")
		end,
	},
	{
		name = "saveRun",
		
		prettyName = "Save Run Ghost",
		recordingMode = "run",
		description = "Save the most recently completed full run ghost.",
		actionFunction = function()
			if run_readyToUpdate and run_lastRecording ~= nil then
				local g = run_lastRecording
				local folder = file.combinePath("Ghosts", playerName, recordingModeFolderNames[g.mode], getCategoryFolderName(g.category))
				if not file.exists(folder) then
					file.createFolder(folder)
				end
				
				local f = "Full Run " .. getFormattedTime(g.length, false, true, true) .. " " .. g.playerName .. " - " .. bizstring.replace(g.uid, g.playerName, "") .. ".txt"
				saveRecordingToFile(file.combinePath(folder, f), run_lastRecording)
				
				addNewGhostMeta({
					segment = segmentToString(run_lastRecording.segment),
					filePath = file.combinePath(folder, f),
					playerName = run_lastRecording.playerName,
					uid = run_lastRecording.uid,
					category = run_lastRecording.category,
					collection = playerName,
					length = run_lastRecording.length,
					timestamp = run_lastRecording.timestamp,
					mode = run_lastRecording.mode,
				})
				
				run_readyToUpdate = false
				menu_showEndOfRun = false
				showMessage("Saved recording!")
			end
		end,
	},
	{
		name = "startRun",
		
		prettyName = "Start Run",
		recordingMode = "run",
		description = "Begin a new run from the beginning.",
		actionFunction = function()
			bonkCounter = 0
			segment_restart({"World", 10, "Entry"})
		end,
	},
	{
		name = "reloadSegment",
		
		prettyName = "Restart Segment",
		recordingMode = "segment",
		description = "Load the savepoint for the current segment.",
		actionFunction = function()
			bonkCounter = 0
			if segment_recording ~= nil then
				segment_restart(segment_recording.segment)
			elseif segment_lastRecording ~= nil then
				segment_restart(segment_lastRecording.segment)
			else
				segment_restart(currentSegment)
			end
		end,
	},
	{
		name = "toggleSubSegmentGhosts",
		
		prettyName = "Toggle Sub-Segment Ghosts",
		recordingMode = "segment",
		description = "When on, ghosts will jump forward or backward when you rescue a dragon so they begin the next sub-segment at the same time.",
		actionFunction = function()
			segment_showSubSegmentGhosts = not segment_showSubSegmentGhosts
			if segment_showSubSegmentGhosts then
				showMessage("Sub-Segments On")
			else
				showMessage("Sub-Segments Off")
			end
		end,
	},
}

function processActionData()
	--action_data is created as an ordered array so we can
	--present the actions in a logical order (instead of
	--alphabetically) in menus, but we'll also need to
	--access the actions by their name. This function
	--should be called once and will create a duplicate
	--entry for each action using its name as its key.
	
	for i, v in ipairs(action_data) do
		action_data[v.name] = v
	end
end

function getActionName(action)
	if (action or "") == "" then return "None" end
	
	if action_data[action] ~= nil then
		if (action_data[action].prettyName or "") ~= nil then
			return action_data[action].prettyName
		else
			return tostring(action)
		end
	end
	
	return "Unknown Action: " .. tostring(action)
end

function handleAction(action)
	if type((action_data[action] or {}).actionFunction) == "function" then
		action_data[action].actionFunction()
	end
end

-------------------------
-- Menus
-------------------------

do
	-- Menu 
	
	menu_state = nil --the name that will determine which data gets loaded for the menu
	menu_lastState = nil --the previous menu state
	menu_options = nil --a string, number, or table that may be used to pass additional info to the menu
	menu_currentData = nil --a reference to the menu_data entry for the current menu
	
	menu_title = ""
	menu_cursor = 1
	menu_items = {}
	
	menu_stack = {}

	menu_cursorFlash = true
	menu_cursorFlash_timer = 0
	menu_cursorFlash_period = 30
	
	showDeltaPercent = false
	
	-- Menu options for the player name entry. This is
	-- separate from the rest of the menu data because it
	-- needs to be accessed in multiple places.
	playerNameMenuOptions = {description = "Please enter a name. This will be saved in any ghost recordings you create. This can be changed later.", openFunction = function(self) self.keyboard_output = playerName if playerName == defaultPlayerName then self.keyboard_output = "" end end,
	doneFunction = function(self) 
		self.keyboard_output = string.trim(self.keyboard_output)
		if (self.keyboard_output or "") ~= "" then
			playerName = self.keyboard_output
			segment_comparison_collection = playerName
			run_collection = playerName
			collections[playerName] = true
		end
		menu_back()
	end,}
	
	menu_rankingInfo = {action = "changeMenu", target = "notice", options = {message = "LuaGhost will attempt to determine the current ranking of the player and the ghost(s) at the end of each segment, but it's not perfect and is easily confused unless everyone follows identical routes. It cannot tell when an overtake happens in the middle of a segment, only at the end."},}
end

-- This function is used to open the menu when it is closed
-- and also to change menu screens while the menu is open
function menu_open(newMenuState, options)
	-- Open a menu or change to a new menu screen
	
	if menu_state == nil or menu_state == "" then
		-- Condition: There is currently no open menu and we're openning a new menu
		
		-- Create a new stack to track navigation through the menu
		menu_stack = {}
	else
		-- Condition: The menu is already open and we're changing to a new menu screen
		
		-- Get info about the button that was pressed
		local _lastMenuItem = (menu_items or {})[menu_cursor or 1] or {}
		
		-- Add the current menu state to the stack so we can backtrack later if needed
		table.insert(menu_stack, {state = menu_state, cursor = menu_cursor, options = menu_options, lastMenuItem = _lastMenuItem})
		-- I'm storing menu_cursor in case I need it later, but it's not currently used anywhere
	end
	
	menu_lastState = menu_state
	menu_options = options
	
	menu_state = newMenuState
	
	menu_populate()
end

function menu_back()
	--Pull the most recent menu off of the stack, closing the menu if the stack is empty
	
	local stackItem = table.remove(menu_stack)
	
	if stackItem == nil then
		--Condition: there is nothing in the stack, so close the menu instead
		menu_close()
	else
		--Condition: there is a menu in the stack, so return to it
		
		--Call the closing function for the old menu, if
		--one exists. This is only called in this branch
		--because menu_close() will also do this.
		if (menu_currentData or {}).closeFunction ~= nil then
			menu_currentData:closeFunction()
		end
		
		--Keeping track of which menu we're leaving.
		local lastMenuState = menu_state
		local lastMenuOptions = menu_options
		
		menu_state = stackItem.state
		menu_options = stackItem.options
		local lastMenuItem = stackItem.lastMenuItem or {}
		
		menu_populate()
		
		menu_cursor = 1
		
		--Put the cursor on the menu item that leads to the
		--menu we just left. I do it this way instead of
		--using stackItem.cursor in case the layout of the
		--menu has changed since we were last here.
		if type(menu_items) == "table" then
			for i = 1, #menu_items do
				if (menu_items[i] or {}).action == "changeMenu" and menu_items[i].target == lastMenuState and menu_items[i].options == lastMenuOptions then
					menu_cursor = i
				end
				if table.isSimilar(menu_items[i], lastMenuItem, {menuIndex = true, display = true}) then
					menu_cursor = i
				end
			end
		end
	end
end

function menu_close()
	--Close the menu
	
	--Call the closing function for this menu, if one exists
	if (menu_currentData or {}).closeFunction ~= nil then
		menu_currentData:closeFunction()
	end
	
	menu_state = nil
	menu_showInputs = framerate / 2 * 20
	
	requireMainMenuAction()
	
	settings_save()
end

function menu_select(squareSelect)
	-- squareSelect is true if the user pressed the square button, nil or false otherwise
	
	-- The player has pressed X
	local selectedItem = menu_items[menu_cursor]
	
	-- Handle case of user pressing square
	if squareSelect then
		if (selectedItem or {}).squareSelect then
			-- Condition: This menu item has a square
			-- action, so select it instead of the
			-- normal action.
			selectedItem = selectedItem.squareSelect
		else
			-- Condition: This menu item has no square
			-- action, so return without doing anything.
			return
		end
	end
	
	-- Handle selected action
	local selectedAction = (selectedItem or {}).action
	
	if selectedAction == "changeMenu" then
		if selectedItem.target ~= nil then
			--Condition: This menu button has a target
			menu_open(selectedItem.target, selectedItem.options)
		else
			--Condition: This menu button has no target selected, so do nothing
		end
	elseif selectedAction == "selectSetting" then
		setGlobalVariable(menu_currentData.targetVariable, selectedItem.setting)
		menu_updateAllItems()
	elseif selectedAction == "onOffSetting" then
		setGlobalVariable(selectedItem.targetVariable, not getGlobalVariable(selectedItem.targetVariable))
		menu_updateItem(selectedItem)
	elseif selectedAction == "offRawSmoothSetting" or selectedAction == "offTrueDelayedSetting" or selectedAction == "offOnAlwaysSetting" then
		local value = getGlobalVariable(selectedItem.targetVariable) + 1
		if value > 2 then value = 0 end
		setGlobalVariable(selectedItem.targetVariable, value)
		menu_updateItem(selectedItem)
	elseif selectedAction == "numberSetting" then
		if not string.ends(selectedItem.display, "Press left or right") then
			selectedItem.display = selectedItem.display .. " - Press left or right"
		end		
	elseif selectedAction == "stringSetting" then
		local index = selectedItem.selectedIndex + 1
		if index > #selectedItem.options then index = 1 end
		setGlobalVariable(selectedItem.targetVariable, selectedItem.options[index])
		menu_updateItem(selectedItem)
	elseif selectedAction == "loadSegment" then
		local levelType = (menu_options % 10 == 0) and "World" or "Level"
		if segment_restart({levelType, menu_options, selectedItem.target}) then
			showDebug("Loading Segment: {'" .. levelType .. "', " .. tostring(menu_options) .. ", '" .. selectedItem.target .. "'}")
			bonkCounter = 0
			menu_close()
		else
			showError("Oops, something went wrong. Trying to load nonexistant file." )
		end
	elseif selectedAction == "performAction" then
		menu_close()
		handleAction(selectedItem.targetAction)
	end
	
	-- If this menu item has a custom function to call, do
	-- it now, after most other effects of the item have
	-- been run, but before changing the menu if this is a
	-- back button.
	tryRunGlobalFunction((selectedItem or {}).selectFunction, selectedItem)
	
	if selectedAction == "back" then
		--Condition: This menu item is a back button
		menu_back()
		return
	end
end

function menu_right()
	--The player has pressed right
	local selectedItem = menu_items[menu_cursor]
	local selectedAction = (selectedItem or {}).action
	
	if selectedAction == "onOffSetting" then
		setGlobalVariable(selectedItem.targetVariable, not getGlobalVariable(selectedItem.targetVariable))
		menu_updateItem(selectedItem)
	elseif selectedAction == "offRawSmoothSetting" or selectedAction == "offTrueDelayedSetting" or selectedAction == "offOnAlwaysSetting" then
		local value = getGlobalVariable(selectedItem.targetVariable) + 1
		if value > 2 then value = 0 end
		setGlobalVariable(selectedItem.targetVariable, value)
		menu_updateItem(selectedItem)
	elseif selectedAction == "numberSetting" then
		local value = getGlobalVariable(selectedItem.targetVariable) + 1
		if selectedItem.maxValue and value > selectedItem.maxValue then value = selectedItem.maxValue end
		setGlobalVariable(selectedItem.targetVariable, value)
		menu_updateItem(selectedItem)
	elseif selectedAction == "stringSetting" then
		local index = selectedItem.selectedIndex + 1
		if index > #selectedItem.options then index = 1 end
		setGlobalVariable(selectedItem.targetVariable, selectedItem.options[index])
		menu_updateItem(selectedItem)
	end
	
	tryRunGlobalFunction((selectedItem or {}).rightFunction, selectedItem)
	
end

function menu_left()
	--They player has pressed left
	local selectedItem = menu_items[menu_cursor]
	local selectedAction = (selectedItem or {}).action
	
	if selectedAction == "onOffSetting" then
		setGlobalVariable(selectedItem.targetVariable, not getGlobalVariable(selectedItem.targetVariable))
		menu_updateItem(selectedItem)
	elseif selectedAction == "offRawSmoothSetting" or selectedAction == "offTrueDelayedSetting" or selectedAction == "offOnAlwaysSetting" then
		local value = getGlobalVariable(selectedItem.targetVariable) - 1
		if value < 0 then value = 2 end
		setGlobalVariable(selectedItem.targetVariable, value)
		menu_updateItem(selectedItem)
	elseif selectedAction == "numberSetting" then
		local value = getGlobalVariable(selectedItem.targetVariable) - 1
		if selectedItem.minValue and value < selectedItem.minValue then value = selectedItem.minValue end
		setGlobalVariable(selectedItem.targetVariable, value)
		menu_updateItem(selectedItem)
	elseif selectedAction == "stringSetting" then
		local index = selectedItem.selectedIndex - 1
		if index < 1 then index = #selectedItem.options end
		setGlobalVariable(selectedItem.targetVariable, selectedItem.options[index])
		menu_updateItem(selectedItem)
	end
	
	tryRunGlobalFunction((selectedItem or {}).leftFunction, selectedItem)
end

--This table contains the information needed to generate
--all the menus. It includes menu-specific functions.
menu_data = {
	["main menu"] = {
		menuType = "normal",
		title = "Main Menu",
		description = nil,
		reservedDescriptionLines = 3,
		items = {
			{action = "changeMenu", target = "recording mode", description = "Set whether ghosts are handled automatically or manually.",
				updateDisplay = function(self)
					self.display = menu_data["recording mode"].title .. ": " .. tostring(recordingModePrettyNames[recordingMode])
				end,
			},
			{action = "changeMenu", target = "route select", description = "Select the route to work on. Each route has its own savestates and ghosts.",
				updateDisplay = function(self)
					self.display = menu_data["route select"].title .. ": " .. getCategoryPrettyName()
				end,
			},
			{action = "changeMenu", target = "action menu", description = "A set of actions relating to the current recording mode."},
			{action = "changeMenu", target = "warp menu", display = "Warp to Segment", options = 0, description = "Load segment savepoints created in segment recording mode for the current route. Also access warp settings here."},
			{action = "changeMenu", target = "display", description = "Change settings for Spyro's palette, bonk counter, and similar."},
			{action = "changeMenu", target = "ghost settings", description = "When in segment mode, choose which ghost to compare to, additional ghosts to show, ghost colors, and similar."},
			{action = "changeMenu", target = "keyboard input", description = "Change the name that is saved in your ghost recordings.", updateDisplay = function(self) self.display = "Player's Name: " .. playerName end, options = playerNameMenuOptions,},
		},
	},
	["recording mode"] = {
		menuType = "selectSetting",
		targetVariable = "recordingMode",
		title = "Recording Mode",
		description = "Decide whether ghosts are created automatically or manually.",
		items = {
			{action = "selectSetting", setting = "manual", display = "Manual", description = "Manual mode allows you to create a savepoint any time you want, record a ghost starting from that point, and practice against that ghost. Useful for practicing or experimenting with individual tricks. Manual ghosts cannot currently be saved to file."},
			{action = "selectSetting", setting = "segment", display = "Segment", description = "Segment mode allows you to practice individual levels or homeworld movement between levels. When entering or exiting a level, a comparison ghost will automatically start. New savestates are created automatically as you complete your route."},
			{action = "selectSetting", setting = "run", display = "Full Run", description = "Full Run will create a ghost for an entire speedrun. Segment ghosts may optionally be shown."},
		},
		openFunction = function(self)
			self.originalValue = getGlobalVariable(self.targetVariable)
		end,
		closeFunction = function(self)
			if self.originalValue ~= getGlobalVariable(self.targetVariable) then
				tryRunGlobalFunction("clearAllRecordingData")
			end
		end,
	},
	["route select"] = {
		menuType = "selectSetting",
		targetVariable = "currentRoute",
		title = "Current Route",
		description = "Select the route to practice. Each route creates a separate set of savestates and ghost recordings. If you do a complete run from the start of the game in segment recording mode, it will create all the savestates for that route automatically.",
		items = {
			{action = "selectSetting", setting = "any", display = routePrettyNames["any"], description = ""},
			{action = "selectSetting", setting = "120", display = routePrettyNames["120"], description = ""},
			{action = "selectSetting", setting = "80dragons", display = routePrettyNames["80dragons"], description = ""},
			{action = "selectSetting", setting = "vortex", display = routePrettyNames["vortex"], description = ""},
			{action = "onOffSetting", targetVariable = "variant_sparxless", prettyName = "Sparxless", description = "No one to pick up gems for you. No one to protect you from harm. It's dangerous to go alone!"},
		},
		closeFunction = function(self)
			tryRunGlobalFunction("segment_clearData")
		end,
	},
	["action menu"] = {
		menuType = "normal",
		title = "Action Menu",
		description = nil,
		limitDisplayedItems = 6,
		items = {},
		openFunction = function(self)
			menu_items = {}
			for i, v in ipairs(action_data) do
				if v.recordingMode == recordingMode then
					table.insert(menu_items, {action = "performAction", targetAction = v.name, display = (v.prettyName or v.name), description = v.description})
				end
			end
			table.insert(menu_items, {action = "changeMenu", target = "rebind actions", description = "Rebind the controls you can use in-game.",})
		end,
	},
	["rebind actions"] = {
		menuType = "normal",
		title = "Rebind Action Controls",
		description = nil,
		items = {
			{action = "changeMenu", target = "rebind actions list", options = "RS_left", inputName = "Right Stick - Left: "},
			{action = "changeMenu", target = "rebind actions list", options = "RS_right", inputName = "Right Stick - Right: "},
			{action = "changeMenu", target = "rebind actions list", options = "RS_up", inputName = "Right Stick - Up: "},
			{action = "changeMenu", target = "rebind actions list", options = "RS_down", inputName = "Right Stick - Down: "},
			{action = "changeMenu", target = "rebind actions list", options = "R3", inputName = "R3: "},
			{action = "changeMenu", target = "rebind actions list", options = "L3", inputName = "L3: "},
			{action = "function", display = "Reset Controls", description = "Reset all the controls for this recording mode to the default settings.",
				selectFunction = function(self)
					controls_restoreDefault(recordingMode)
					menu_currentData:openFunction()
				end,
			},
		},
		openFunction = function(self)
			for i, v in ipairs(self.items) do
				if v.action == "changeMenu" then
					local actionName = getActionName(((_G["controls"] or {})[recordingMode] or {})[v.options])
					v.display = v.inputName .. tostring(actionName)
				end
			end
		end,
	},
	["rebind actions list"] = {
		menuType = "selectSetting",
		targetVariable = nil,
		title = "Options",
		limitDisplayedItems = 6,
		items = {},
		openFunction = function(self)
			self.targetVariable = {"controls", recordingMode, menu_options}
			
			if menu_options == "R3" then
				self.description = "Note that R3 can be used to close the menu and the controls while the menu is open cannot currently be changed."
			else
				self.description = nil
			end
			
			menu_items = {}			
			table.insert(menu_items, {action = "selectSetting", setting = nil, display = "None", description = "Unbind this control"})
			
			for i, v in ipairs(action_data) do
				if v.recordingMode == recordingMode or v.recordingMode == "global" then
					table.insert(menu_items, {action = "selectSetting", setting = v.name, display = (v.prettyName or v.name), description = v.description})
				end
			end
		end,
	},
	["warp settings"] = {
		menuType = "normal",
		title = "Warp Settings",
		description = "These settings are applied when you load a segment from the warp menu or reset a segment, but not when moving naturally between segments. If you've changed Spyro's palette, this will be reapplied when you load savestates. If you've changed the music volume in the game's settings, this change will also be applied as savestates are loaded.",
		items = {
			{action = "numberSetting", targetVariable = {"segment_settings", "category", "segment", "health"}, prettyName = "Health", minValue = -1, maxValue = 3, displayFunction = function(value) local lut ={[-1] = "No Change", [0] = "Sparxless", [1] = "Green Sparx", [2] = "Blue Sparx", [3] = "Gold Sparx"} return lut[value] end, description = nil},
			{action = "numberSetting", targetVariable = {"segment_settings", "category", "segment", "lives"}, prettyName = "Lives", minValue = -1, maxValue = 99, displayFunction = function(value) if value == -1 then return "No Change" end return value end, description = nil},
			{action = "function", display = "Delete segment savestate", description = "Delete the savestate for this segment in case you need to recreate it. This does not remove ghost data.",
				selectFunction = function(self)
					local fileName = getGlobalVariable({"savestateData", "segment", currentRoute, segmentToString(menu_options)})
					if (fileName or "") ~= "" and file.exists(fileName) then
						os.remove(fileName)
						setGlobalVariable({"savestateData", "segment", currentRoute, segmentToString(menu_options)}, nil)
						showMessage("Savestate file removed.")
					else
						showMessage("No savestate file found.")
					end
				end
			},
		},
		openFunction = function(self)
			
			-- If no segment is provided, assume the current one (shouldn't happen in practice)
			if menu_options == nil then
				menu_options = currentSegment
			end
			
			-- Detect unknown segment
			if type((menu_options or {})[2]) ~= "number" or levelInfo[menu_options[2]] == nil then
				menu_back()
				menu_open("notice", {message = "This segment is not recognized."})
				return
			end
			
			menu_title = "Warp Settings for " .. levelInfo[menu_options[2]].name .. " " .. menu_options[3]
			
			local category = currentRoute
			local segment = getSegmentHandle(menu_options)
			menu_segmentSettings = menu_segmentSettings or {}
			segment_settings[category] = segment_settings[category] or {}		
			segment_settings[category][segment] = segment_settings[category][segment] or {}
			segment_settings[category][segment].health = segment_settings[category][segment].health or -1
			segment_settings[category][segment].lives = segment_settings[category][segment].lives or -1
			
			for i, v in ipairs(self.items) do
				if v.action == "numberSetting" then
					v.targetVariable[2] = category
					v.targetVariable[3] = segment
				end
			end
		end,
	},
	["display"] = {
		menuType = "normal",
		title = "Display Settings",
		description = nil,
		reservedDescriptionLines = 4,
		items = {
			{action = "changeMenu", target = "spyroSkin", description = "Change Spyro's palette data.", updateDisplay = function(self) self.display = "Spyro's Skin: " .. (currentPalette_name or "Original") end},
			{action = "onOffSetting", targetVariable = "showBonkCounter", prettyName = "Show Bonk Counter", description = "Counts how many times Spyro bonks. The counter resets when you load a save state or reset a segment."},
			{action = "offRawSmoothSetting", targetVariable = "showSpeed", prettyName = "Show Speed", description = "The change in Spyro's position."},
			{action = "offRawSmoothSetting", targetVariable = "showGroundSpeed", prettyName = "Show Ground Speed", description = "The change in Spyro's position, ignoring the vertical component."},
			{action = "offRawSmoothSetting", targetVariable = "showLogicalSpeed", prettyName = "Show Logical Speed", description = "Spyro's speed in the game logic."},
			{action = "offTrueDelayedSetting", targetVariable = "showSpyroPosition", prettyName = "Show Spyro's Position", description = "Renders a ghost at Spyro's position."},
			{action = "offOnAlwaysSetting", targetVariable = "showArtisanProps", prettyName = "Show Artisan Props", description = "Some test objects in the Artisans Homeworld I used for calibrating the renderer."},
			{action = "onOffSetting", targetVariable = "showSunnyFlightScanner", prettyName = "Show Sunny Flight Scanner", description = "Show a minimap of the area surrounding the planes in Sunny Flight."},
			{action = "onOffSetting", targetVariable = "showGhostAnimations", prettyName = "Show Ghost Animations", description = "Changes a ghost's model to indicate charging and gliding states."},
			{action = "onOffSetting", targetVariable = "timeFormat_frames", displayLUT = {[true] = "Frames", [false] = "Decimal",}, prettyName = "Sub-second Displays As", description = displayType == "NTSC" and "The fractional part of times can be displayed with either a decimal (-2.50) or frame count (-2'30). The frame count will range from 0 to 59." or "The fractional part of times can be displayed with either a decimal (-2.50) or frame count (-2'25). The frame count will range from 0 to 49.",},
			{action = "onOffSetting", targetVariable = "showDeltaPercent", prettyName = "Show Delta Percent", description = "At the end of each segment, show the percent difference from the comparison time."},
			{action = "onOffSetting", targetVariable = "quickUpdatingGems", prettyName = "Fast Gem Counter", description = "Makes the game's gem counter update much faster."},
		},
	},
	["spyroSkin"] = {
		menuType = "selectSetting",
		targetVariable = "currentPalette_name",
		title = "Spyro's Skin",
		description = nil,
		suppressMenuBackground = true,
		items = {{action = "selectSetting", setting = "Original", selectFunction = function(self) currentPalette = self.palette end,},},
		openFunction = function(self)
			--clear all items from the items list except the first
			for i=2, #(self.items) do self.items[i] = nil end
			self.items[1].palette = spyroSkin.originalPalette
			
			if currentPalette_name == nil or currentPalette_name == "" then currentPalette_name = "Original" end
			
			--populate the items list with all the palettes that can be found in the folder
			for dir in io.popen([[dir "Spyro Palettes\" /b]]):lines() do
				if string.ends(dir, "ppm") then 
					local name = string.split(dir, ".")[1]
					table.insert(self.items, {action = "selectSetting", setting = name, palette = spyroSkin.loadPalette("Spyro Palettes\\" .. dir), selectFunction = function(self) currentPalette = self.palette end,})
				end
			end
			
		end,
		closeFunction = function(self)
			spyroSkin.applyPalette(currentPalette)
		end,
		updateFunction = function(self)
			spyroSkin.applyPalette((self.items[menu_cursor] or {}).palette)
		end,
	},
	["ghost settings"] = {
		menuType = "normal",
		title = "Ghost Settings",
		description = nil,
		reservedDescriptionLines = 4,
		items = {
			{action = "changeMenu", target = "segment ghost settings", description = "Change which segment ghosts are shown and which one to compare times against.",},
			{action = "changeMenu", target = "run ghost settings", description = "Change which full run ghosts are shown and which one to compare times against.",},
			{action = "function", display = "Export Fastest Times", description = "Create a new collection and copy your fastest ghost from each segment to it. Copies your fastest full game runs, too.",
				selectFunction = function(self)
					local collectionFolder = segment_exportGolds()
					populateFileList()
					menu_open("notice", {message = string.format([[Your fastest times for each segment have been copied to a new folder named "%s", which can be found in the script's "Ghosts" folder. It is safe to rename this folder, although you should always refresh this script after making any changes to the contents of the "Ghosts" folder.]], collectionFolder)})
				end,
			},
			{action = "onOffSetting", targetVariable = "segment_showSubSegmentGhosts", prettyName = "Show Sub-Segment Ghosts", description = "When you rescue a dragon, all visible ghosts will jump forward or backward to rescue it at the same time. This does not change the time deltas that are shown.",},
			{action = "onOffSetting", targetVariable = "segment_preloadAllGhosts", prettyName = "Preload All Ghosts", description = "Load the data for all segment ghosts when the script starts. May prevent a noticable stutter when entering a new segment at the cost of increased memory usage.",},
			{action = "onOffSetting", targetVariable = "segment_autoSaveGhosts", prettyName = "Auto-save Ghosts", description = "Automatically save ghosts when ending a segment. This is not recommended because the script cannot tell if a segment was completed successfully. This may be useful for creating segment recordings from a TAS.",},
		},
	},
	["segment ghost settings"] = {
		menuType = "normal",
		title = "Segment Ghost Settings",
		description = nil,
		reservedDescriptionLines = 4,
		items = {
			{action = "changeMenu", target = "choose from list", updateDisplay = function(self) self.display = "Comparison Collection: " .. segment_comparison_collection end, description = "Choose the collection you want to compare to. Each collection is a subfolder in the script's \"Ghosts\" folder. Ghosts you create will be saved to a collection using your name.", options = {title = "Choose a Collection", targetVariable = "segment_comparison_collection", choices = "collections",},},
			{action = "stringSetting", targetVariable = "segment_comparison_target", prettyName = "Compare To", description = "Select which ghost in the chosen collection will be compared to.", options = {"lengthSort", "timestampSort",}, displayLUT = {["lengthSort"] = "Fastest", ["timestampSort"] = "Most Recent",},},
			{action = "onOffSetting", targetVariable = "segment_comparison_useColor", prettyName = "Use Comparison Color", description = "Use a seperate color for the ghost that is being compared to, instead of the default color for its collection.",},
			{action = "changeMenu", target = "color select", options = {colorTarget = "segment_comparison_color",}, display = "Comparison Color", description = "Change the colors for the comparison ghost (if the setting above is on).",},
			{action = "changeMenu", target = "collection settings list", display = "Choose Additonal Ghosts to Show", description = "Choose which ghosts will be displayed from each collection. These ghosts are shown in addition to the ghost you are comparing to. Each collection is a subfolder in the script's \"Ghosts\" folder.",},
		},
	},
	["run ghost settings"] = {
		menuType = "normal",
		title = "Full Run Ghost Settings",
		description = nil,
		reservedDescriptionLines = 4,
		items = {
			{action = "changeMenu", target = "choose from list", updateDisplay = function(self) self.display = "Collection: " .. run_collection end, description = "Choose the collection for the full game ghosts. Currently, it's only possible to show one collection at a time.", options = {title = "Choose a Collection", targetVariable = "run_collection", choices = "collections",},},
			{action = "stringSetting", targetVariable = "run_comparison_target", prettyName = "Compare To", description = "Select which ghost will be compared to. This ghost will always be shown, even if the settings below are set to 0.", options = {"lengthSort", "timestampSort",}, displayLUT = {["lengthSort"] = "Fastest", ["timestampSort"] = "Most Recent",},},
			{action = "numberSetting", targetVariable = "run_loadXFastest", prettyName = "Show Fastest", description = "Show the x fastest ghosts.", minValue = 0,},
			{action = "numberSetting", targetVariable = "run_loadXRecent", prettyName = "Show Recent", description = "Show the x most recently created ghosts.", minValue = 0,},
			{action = "changeMenu", target = "color select", options = {colorTarget = "run_ghostColor",}, display = "Change Ghost Color", description = "Change the colors for these ghosts.",},
			{action = "onOffSetting", targetVariable = "run_comparison_useColor", prettyName = "Different Comparison Color", description = "Decide whether the ghost you're comparing to should be a different color.",},
			{action = "changeMenu", target = "color select", options = {colorTarget = "run_comparison_color",}, display = "Change Comparison Color", description = "Change the colors for the ghost you're comparing to, only if the setting above is on.",},
			{action = "onOffSetting", targetVariable = "run_showRankPlace", prettyName = "Show Current Rank", description = "Show your rank against the ghost(s) you're racing against. Press Square for more info.", squareSelect = menu_rankingInfo,},
			{action = "onOffSetting", targetVariable = "run_showRankList", prettyName = "Show Complete Ranking", description = "Show the rankings of all the ghosts in a list. Press Square for more info.", squareSelect = menu_rankingInfo,},
			{action = "onOffSetting", targetVariable = "run_showRankNames", prettyName = "Show Labels for Ghosts", description = "Show a letter above each ghost according to their final placement among the ghosts.",},
			{action = "onOffSetting", targetVariable = "run_showSegmentGhosts", prettyName = "Show Segment Ghosts", description = "Show segment ghosts during a full run.",},
		},
	},
	["comparison settings"] = {
		menuType = "normal",
		title = "Comparison Settings",
		description = nil,
		reservedDescriptionLines = 4,
		items = {
			{action = "changeMenu", target = "choose from list", updateDisplay = function(self) self.display = "Comparison Collection: " .. segment_comparison_collection end, description = "Choose the collection you want to compare to. Each collection is a subfolder in the script's \"Ghosts\" folder. Ghosts you create will be saved to a collection using your name.", options = {title = "Choose a Collection", targetVariable = "segment_comparison_collection", choices = "collections",},},
			{action = "stringSetting", targetVariable = "segment_comparison_target", prettyName = "Compare To", description = "Select which ghost in the chosen collection will be compared to.", options = {"lengthSort", "timestampSort",}, displayLUT = {["lengthSort"] = "Fastest", ["timestampSort"] = "Most Recent",},},
			{action = "onOffSetting", targetVariable = "segment_comparison_useColor", prettyName = "Use Comparison Color", description = "Use a seperate color for the ghost that is being compared to, instead of the default color for its collection.",},
			{action = "changeMenu", target = "color select", options = {colorTarget = "segment_comparison_color",}, display = "Comparison Color", description = "Change the colors for the comparison ghost (if the setting above is on).",},
		},
	},
	["collection settings list"] = {
		menuType = "noramal",
		title = "Collections",
		description = "Choose a collection to set which ghosts from that collection will be displayed. Each collection is a subfolder in the script's \"Ghosts\" folder. The ghosts you create are added to a collection using your name. The ghost you are comparing to will always be shown, regardless of these settings.",
		items = {},
		openFunction = function(self)
			menu_items = {}
			for k in pairs(collections) do
				table.insert(menu_items, {action = "changeMenu", target = "collection settings", display = k, options = {collection = k},})
			end
		end,
	},
	["collection settings"] = {
		menuType = "normal",
		title = "Collection Settings",
		description = "Choose the settings for this collection.",
		items = {
			{action = "onOffSetting", targetVariable = {"segment_ghostSettings", "_collection", "showAll"}, prettyName = "Show All", description = "Show all ghosts from this collection, overriding the other settings.",},
			{action = "numberSetting", targetVariable = {"segment_ghostSettings", "_collection", "showFastest"}, prettyName = "Show Fastest", description = "Show the x fastest ghosts for each segment.", minValue = 0,},
			{action = "numberSetting", targetVariable = {"segment_ghostSettings", "_collection", "showRecent"}, prettyName = "Show Recent", description = "Show the x most recently created ghosts for each segment.", minValue = 0,},
			{action = "changeMenu", target = "color select", options = {colorTarget = {"segment_ghostSettings", "_collection", "color",},}, display = "Change Color", description = "Change the colors for these ghosts.",},
		},
		openFunction = function(self)
			menu_title = self.title .. " - " .. menu_options.collection
			for i, v in ipairs(menu_items) do
				if type(v.targetVariable) == "table" and v.targetVariable[1] == "segment_ghostSettings" then
					v.targetVariable[2] = menu_options.collection
				end
				if v.target == "color select" then
					v.options.colorTarget[2] = menu_options.collection
				end
			end
			if segment_ghostSettings[menu_options.collection] == nil then
				segment_ghostSettings_createDefault(menu_options.collection)
			end
		end,
		closeFunction = function(self)
			segment_saveCollectionSettings(menu_options.collection)
		end,
	},
	["warp menu"] = {
		menuType = "normal",
		title = "Warp Menu",
		description = nil,
		items = {},
		openFunction = function(self)
			if menu_lastState ~= "warp menu" then
				menu_populateSegments()
			end
			
			local commonDescription = "Press X to load savestate. Press square to change savestate settings."
			
			menu_items = {}
			
			if not menu_options then menu_options = 0 end
			
			if menu_options == 0 then
				-- List of homeworlds
				for i = 10, 60, 10 do
					if warpMenu_availability[tostring(i)] then
						table.insert(menu_items, {action = "changeMenu", target = "warp menu", options = i, display = levelInfo[i].name .. " Homeworld",})
					end
				end
				table.insert(menu_items, {action = "back",})
				
				--menu_items = {"warpMenu world 10", "warpMenu world 20", "warpMenu world 30", "warpMenu world 40", "warpMenu world 50", "warpMenu world 60", }
			elseif menu_options % 10 == 0 then
				-- List of levels in current homeworld
				menu_title = menu_title .. " - " .. levelInfo[menu_options].name
				if warpMenu_segments[tostring(menu_options) .. "Entry"] then
					table.insert(menu_items, {action = "loadSegment", target = "Entry", display = "Homeworld Entry", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"World", menu_options, "Entry"},},})
				end
				local numberOfLevels = 5
				if menu_options == 60 then numberOfLevels = 4 end
				for i = menu_options + 1, menu_options + numberOfLevels do
					if warpMenu_availability[tostring(i)] then
						table.insert(menu_items, {action = "changeMenu", target = "warp menu", options = i, display = levelInfo[i].name,})
					end
				end
				table.insert(menu_items, {action = "back",})
			else
				-- Entry options and settings for currently selected level
				menu_title = menu_title .. " - " .. levelInfo[menu_options].name
				if warpMenu_segments[tostring(menu_options) .. "Entry"] then
					table.insert(menu_items, {action = "loadSegment", target = "Entry", display = "Level Entry", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"Level", menu_options, "Entry"},},})
				end
				if warpMenu_segments[tostring(menu_options) .. "Balloon"] then
					table.insert(menu_items, {action = "loadSegment", target = "Balloon", display = "Balloonist Entry", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"Level", menu_options, "Balloon"},},})
				end
				if warpMenu_segments[tostring(menu_options) .. "Exit"] then
					table.insert(menu_items, {action = "loadSegment", target = "Exit", display = "Level Exit", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"Level", menu_options, "Exit"},},})
				end
				if warpMenu_segments[tostring(menu_options) .. "GameOver"] then
					table.insert(menu_items, {action = "loadSegment", target = "GameOver", display = "Game Over", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"Level", menu_options, "GameOver"},},})
				end
				if warpMenu_segments[tostring(menu_options) .. "PostCredits"] then
					table.insert(menu_items, {action = "loadSegment", target = "PostCredits", display = "Post Credits", description = commonDescription, squareSelect = {action = "changeMenu", target = "warp settings", options = {"Level", menu_options, "PostCredits"},},})
				end
				table.insert(menu_items, {action = "back",})
			end
		end,
	},
	["keyboard input"] = {
		menuType = "keyboard",
		title = "Keyboard",
		keyboard_width = 11,
		keyboard_output = "Output",
		keyboard_caps = 0,
		keyboard_description = nil,
		drawFunction = "menu_draw_keyboard",
		description = nil,
		items = {
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"1", "!"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"2", "@"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"3", "#"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"4", "$"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"5", "%"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"6", "^"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"7", "&"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"8"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"9", "("},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"0", ")"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"delete"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"q", "Q"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"w", "W"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"e", "E"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"r", "R"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"t", "T"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"y", "Y"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"u", "U"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"i", "I"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"o", "O"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"p", "P"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"caps"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"a", "A"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"s", "S"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"d", "D"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"f", "F"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"g", "G"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"h", "H"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"j", "J"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"k", "K"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"l", "L"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"-", "_"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"space"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"z", "Z"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"x", "X"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"c", "C"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"v", "V"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"b", "B"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"n", "N"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"m", "M"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {",", "<"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {".", ">"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"done"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"*"},},
			{action = "function", selectFunction = {"menu_currentData", "_keySelectFunction"}, keys = {"cancel"},},
		},
		openFunction = function(self)
			self.keyboard_output = ""
			if type((menu_options or {}).openFunction) == "function" then
				menu_options.openFunction(self)
			end
			if self.keyboard_output == "" then
				self.keyboard_caps = 1
			else
				self.keyboard_caps = 0
			end
			if type((menu_options or {}).description) == "string" then
				self.keyboard_description = menu_options.description
			else
				self.keyboard_description = nil
			end
		end,
		upFunction = function(self)
			local i = 0
			while self._whileCheck(i) do
				i = i + 1
				menu_cursor = menu_cursor - self.keyboard_width
				if menu_cursor < 1 then menu_cursor = ((menu_cursor + self.keyboard_width - 1) % self.keyboard_width) + (#menu_items - ((#menu_items - 1) % self.keyboard_width)) end
				menu_cursorFlash_timer = menu_cursorFlash_period
				menu_cursorFlash = true
			end
		end,
		downFunction = function(self)
			local i = 0
			while self._whileCheck(i) do
				i = i + 1
				menu_cursor = menu_cursor + self.keyboard_width
				if menu_cursor > #menu_items then menu_cursor = ((menu_cursor - 1) % self.keyboard_width) + 1 end
				menu_cursorFlash_timer = menu_cursorFlash_period
				menu_cursorFlash = true
			end
		end,
		leftFunction = function(self)
			local i = 0
			while self._whileCheck(i) do
				i = i + 1
				if menu_cursor % self.keyboard_width == 1 then
					menu_cursor = menu_cursor + self.keyboard_width - 1
				else
					menu_cursor = menu_cursor - 1
				end
				menu_cursorFlash_timer = menu_cursorFlash_period
				menu_cursorFlash = true
			end
		end,
		rightFunction = function(self)
			local i = 0
			while self._whileCheck(i) do
				i = i + 1
				if menu_cursor % self.keyboard_width == 0 then
					menu_cursor = menu_cursor - self.keyboard_width + 1
				else
					menu_cursor = menu_cursor + 1
				end
				menu_cursorFlash_timer = menu_cursorFlash_period
				menu_cursorFlash = true
			end
		end,
		backFunction = function(self)
			menu_currentData.keyboard_output = string.sub(menu_currentData.keyboard_output, 1, -2)
			if menu_currentData.keyboard_output == "" and menu_currentData.keyboard_caps == 0 then
				menu_currentData.keyboard_caps = 1
			end
		end,
		_whileCheck = function(i)
			--used when navigating to skip over blank keys
			if i == 0 then return true end
			if i > 30 then return false end
			if menu_items[menu_cursor] == nil then return true end
			return ((menu_items[menu_cursor] or {}).keys or {})[1] == "*"
		end,
		_keySelectFunction = function(self)
			if self.keys[1] == "caps" then
				menu_currentData.keyboard_caps = menu_currentData.keyboard_caps + 1
				if menu_currentData.keyboard_caps > 2 then menu_currentData.keyboard_caps = 0 end
			elseif self.keys[1] == "delete" then
				menu_currentData.keyboard_output = string.sub(menu_currentData.keyboard_output, 1, -2)
				if menu_currentData.keyboard_output == "" and menu_currentData.keyboard_caps == 0 then
					menu_currentData.keyboard_caps = 1
				end
			elseif self.keys[1] == "done" then
				if type((menu_options or {}).doneFunction) == "function" then
					menu_options.doneFunction(menu_currentData)
				else
					menu_back()
				end
			elseif self.keys[1] == "cancel" then
				if type((menu_options or {}).cancelFunction) == "function" then
					menu_options.cancelFunction(menu_currentData)
				else
					menu_back()
				end
			else
				local key = self.keys[1]
				if menu_currentData.keyboard_caps > 0 and #(self.keys) > 1 then key = self.keys[2] end
				if key == "space" then
					key = " "
					if menu_currentData.keyboard_caps == 0 then
						menu_currentData.keyboard_caps = 1
					end
				end
				menu_currentData.keyboard_output = menu_currentData.keyboard_output .. key
				
				if menu_currentData.keyboard_caps == 1 and key ~= " " then menu_currentData.keyboard_caps = 0 end
			end
		end,
	},
	["color select"] = {
		menuType = "normal",
		title = "Select Color",
		items = {
			{action = "numberSetting", targetVariable = {"menu_colorSelect_data", "r"}, prettyName = "  Red", minValue = 0, maxValue = 15,},
			{action = "numberSetting", targetVariable = {"menu_colorSelect_data", "g"}, prettyName = "Green", minValue = 0, maxValue = 15,},
			{action = "numberSetting", targetVariable = {"menu_colorSelect_data", "b"}, prettyName = " Blue", minValue = 0, maxValue = 15,},
			{action = "numberSetting", targetVariable = {"menu_colorSelect_data", "a"}, prettyName = "Alpha", minValue = 0, maxValue = 15,},
		},
		openFunction = function(self)
			local function _convertA(value) return math.floor(value / 255 * 15 + 0.5) end
			local function _convertRGB(value) return math.floor(((value / 255) ^ 0.65) * 15 + 0.5) end
			
			menu_options = menu_options or {}
			local rgba = getGlobalVariable(menu_options.colorTarget) or 0xFFFFFFFF
			-- 0xAARRGGBB
			local _b = _convertRGB(rgba % 0x100)
			local _g = _convertRGB(math.floor(rgba / 0x100) % 0x100)
			local _r = _convertRGB(math.floor(rgba / 0x10000) % 0x100)
			local _a = _convertA(math.floor(rgba / 0x1000000) % 0x100)
			
			setGlobalVariable("menu_colorSelect_data", {r = _r, g = _g, b = _b, a = _a,})
		end,
		closeFunction = function(self)
			local function _convertA(value) return math.floor(value / 15 * 255 + 0.5) end
			local function _convertRGB(value) return math.floor(((value / 15) ^ (1 / 0.65)) * 255 + 0.5) end
			
			local t = getGlobalVariable("menu_colorSelect_data")
			setGlobalVariable(menu_options.colorTarget, _convertA(t.a) * 0x1000000 + _convertRGB(t.r) * 0x10000 + _convertRGB(t.g) * 0x100 + _convertRGB(t.b))
			setGlobalVariable("menu_colorSelect_data", nil)
		end,
		drawFunction = function(self)
			menu_draw()
			
			local function _convertA(value) return math.floor(value / 15 * 255 + 0.5) end
			local function _convertRGB(value) return math.floor((10 ^ ((value / 15) ^ (1 / 1.3)) - 1) / 9 * 255 + 0.5) end
			
			local t = getGlobalVariable("menu_colorSelect_data")
			color = _convertA(t.a) * 0x1000000 + _convertRGB(t.r) * 0x10000 + _convertRGB(t.g) * 0x100 + _convertRGB(t.b)
			
			local x1 = 200
			local x3 = 360
			local x2 = math.floor((x1 + x3) / 2)
			local y1 = 40
			local y3 = 120
			local y2 = math.floor((y1 + y3) / 2)
			local lightColor = 0xFFA0A0A0
			local darkColor = 0xFF606060
			
			gui.drawBox(x1, y1, x2 + 1, y2 + 1, 0x00000000, lightColor)
			gui.drawBox(x2, y1, x3, y2 + 1, 0x00000000, darkColor)
			gui.drawBox(x1, y2, x2 + 1, y3, 0x00000000, darkColor)
			gui.drawBox(x2, y2, x3, y3, 0x00000000, lightColor)
			gui.drawBox(x1, y1, x3, y3, 0x00000000, color)
		end,
	},
	["choose from list"] = {
		menuType = "selectSetting",
		title = "Choose From List",
		targetVariable = nil,
		description = nil,
		limitDisplayedItems = 6,
		items = {},
		openFunction = function(self)
			menu_items = {}
			local choices = getGlobalVariable((menu_options or {}).choices)
			if type(choices) == "table" then
				if choices[1] then
					for i, v in ipairs(choices) do
						table.insert(menu_items, {action = "selectSetting", setting = v, display = v,})
					end
				else
					for k, v in pairs(choices) do
						table.insert(menu_items, {action = "selectSetting", setting = k, display = k,})
					end
				end
			end
			if type((menu_options or {}).targetVariable) == "string" or type((menu_options or {}).targetVariable) == "table" then
				self.targetVariable = menu_options.targetVariable
			else
				self.targetVariable = nil
			end
			if type((menu_options or {}).title) == "string" then
				menu_title = menu_options.title
			else
				menu_title = "Choose An Option"
			end
			if type((menu_options or {}).description) == "string" then
				menu_description = menu_options.description
			else
				menu_description = nil
			end
		end,
	},
	["notice"] = {
		menuType = "normal",
		items = {{action = "back"},},
		openFunction = function(self)
			menu_title = menu_options.title or ""
			menu_description = menu_options.message
		end,
	},
}

function menu_populate()
	--called when opening a menu or changing menu screens,
	--loads the new menu's settings and creates the list
	--of menu items.
	
	menu_cursor = 1
	
	menuChangedThisFrame = true--used to be used to stop certain actions happening on the same frame. Is this still true?
	
	--Set up the menu
	menu_currentData = menu_data[menu_state] or {}
	menu_type = menu_currentData.menuType
	menu_title = menu_currentData.title or menu_state
	menu_description = menu_currentData.description
	menu_items = menu_currentData.items
	
	--Call the opening function for this menu, if one exists
	if menu_currentData.openFunction ~= nil then
		menu_currentData:openFunction()
	end
	
	--Do any processing needed on the menu items
	menu_updateAllItems()
	
	--Move the cursor to the currently selected setting in the selectSetting menu type
	if menu_type == "selectSetting" then
		for i,v in ipairs(menu_items) do
			if v.selected then menu_cursor = i end
		end
	end
	
	--Reset the cursor flashing variables so the cursor is
	--always visible immediately when opening a new menu.
	menu_cursorFlash_timer = menu_cursorFlash_period
	menu_cursorFlash = true
end

function menu_updateAllItems()
	if menu_items ~= nil then
		for i,v in ipairs(menu_items) do
			menu_updateItem(v)
			v.menuIndex = i
		end
	end
end

function menu_updateItem(menuItem)
	
	local function _getCustomDisplay(value)
		if type(menuItem.displayLUT) == "table" and menuItem.displayLUT[value] ~= nil then return menuItem.displayLUT[value] end
		if type(menuItem.displayFunction) == "function" then return menuItem.displayFunction(value) end
		return value
	end
	
	local function _getSettingLabel(prettyName, targetVariable)
		local label = prettyName
		if label == nil then
			if type(targetVariable) == "string" then
				label = targetVariable
			elseif type(targetVariable) == "table" then
				label = targetVariable[#targetVariable]
			else
				label = "?"
			end
		end
		return label
	end


	--Special handling to highlight the currently selected option
	if menu_currentData.menuType == "selectSetting" then
		menuItem.selected = getGlobalVariable(menu_currentData.targetVariable) == menuItem.setting--(_G[menu_currentData.targetVariable] == menuItem.setting)
	end

	if menuItem.updateDisplay ~= nil then
		--Condition: this menuItem has a function to determine its display.
		menuItem:updateDisplay()
		--The updateDisplay function does not return a
		--value. It should update its own display value
		--using the self reference that is passed to its
		--first parameter. Look up "Lua colon operator" for
		--more info if you're unfamiliar with how the colon
		--notation works in Lua.
	else
		--Condition: this menuItem does not have a function for special handling of the display.
		if menuItem.action == nil or menuItem.action == "" then
			--Condition: This menuItem doesn't have an action defined
			menuItem.display = "No Action Defined"
		elseif menuItem.action == "back" then
			--Condition: This menuItem is a back button. Leave
			--its display unchanged if already defined. This may
			--also used for buttons that should close the menu
			--once an option is selected.
			if menuItem.display == nil then menuItem.display = "Back" end
		elseif menuItem.action == "changeMenu" then
			--Condition: This menuItem is a changeMenu, a button to go to a different menu screen
			if menuItem.target == nil then
				--Condition: This changeMenu item doesn't have a defined target
				menuItem.display = "changeMenu: No Target"
			elseif (menu_data[menuItem.target] or {}).title ~= nil then
				--Condition: This changeMenu item points to a menu with a defined title
				menuItem.display = menuItem.display or menu_data[menuItem.target].title
			elseif menu_data[menuItem.target] ~= nil then
				--Condition: This changeMenu item points to a menu without a title
				menuItem.display = menuItem.target
			else
				--Condition: This changeMenu item points to a nil menu
				menuItem.display = "changeMenu: " .. tostring(menuItem.target) .. " is nil"
			end
		elseif menuItem.action == "onOffSetting" then
			--Condition: This menuItem is an onOffSetting, a toggle that can switch a setting to true or false
			local value = getGlobalVariable(menuItem.targetVariable)
			value = _getCustomDisplay(value)
			if type(value) == "boolean" then value = value and "On" or "Off" end
			menuItem.display = _getSettingLabel(menuItem.prettyName, menuItem.targetVariable) .. ": " .. value
		elseif menuItem.action == "offRawSmoothSetting" then
			--Condition: This menuItem is an offRawSmooth, used for speed displays
			local setting = "Off"
			if _G[menuItem.targetVariable] == 1 then setting = "Raw" end
			if _G[menuItem.targetVariable] == 2 then setting = "Smooth" end
			menuItem.display = _getSettingLabel(menuItem.prettyName, menuItem.targetVariable) .. ": " .. setting
			
			if menuItem.originalDescription == nil then menuItem.originalDescription = menuItem.description end
			if menuItem.originalDescription == nil then
				menuItem.description = ""
			else
				menuItem.description = menuItem.originalDescription .. " "
			end
			if setting == "Raw" then menuItem.description = menuItem.description .. "Showing raw values." end
			if setting == "Smooth" then menuItem.description = menuItem.description .. "\"Smooth\" setting will average the value over the previous two frames." end
		elseif menuItem.action == "offTrueDelayedSetting" then
			--Condition: This menuItem is an offTrueDelayed, used for rendering things with an option to delay
			local setting = "Off"
			if _G[menuItem.targetVariable] == 1 then setting = "True Position" end
			if _G[menuItem.targetVariable] == 2 then setting = "Delayed" end
			menuItem.display = _getSettingLabel(menuItem.prettyName, menuItem.targetVariable) .. ": " .. setting
			
			if menuItem.originalDescription == nil then menuItem.originalDescription = menuItem.description end
			if menuItem.originalDescription == nil then
				menuItem.description = ""
			else
				menuItem.description = menuItem.originalDescription .. " "
			end
			if setting == "True Position" then menuItem.description = menuItem.description .. "\"True Position\" shows the most up-to-date information for the current frame." end
			if setting == "Delayed" then menuItem.description = menuItem.description .. "\"Delayed\" delays the position by two rendered frames to match the game's frame buffer." end
		elseif menuItem.action == "offOnAlwaysSetting" then
			--Condition: This menuItem is an offTrueDelayed, used for rendering things with an option to show them even if they are not in the same level
			local setting = "Off"
			if _G[menuItem.targetVariable] == 1 then setting = "On" end
			if _G[menuItem.targetVariable] == 2 then setting = "Always" end
			menuItem.display = _getSettingLabel(menuItem.prettyName, menuItem.targetVariable) .. ": " .. setting
			
			if menuItem.originalDescription == nil then menuItem.originalDescription = menuItem.description end
			if menuItem.originalDescription == nil then
				menuItem.description = ""
			else
				menuItem.description = menuItem.originalDescription .. " "
			end
			if setting == "Always" then menuItem.description = menuItem.description .. "\"Always\" shows the object even if it is not in the same level as Spyro." end
		elseif menuItem.action == "numberSetting" then
			local value = getGlobalVariable(menuItem.targetVariable)
			value = _getCustomDisplay(value)
			menuItem.display = _getSettingLabel(menuItem.prettyName, menuItem.targetVariable) .. ": " .. tostring(value)
		elseif menuItem.action == "stringSetting" then
			local value = getGlobalVariable(menuItem.targetVariable)
			menuItem.selectedIndex = 1
			for i = 1, #menuItem.options do
				if menuItem.options[i] == value then menuItem.selectedIndex = i break end
			end
			value = _getCustomDisplay(value)
			menuItem.display = (menuItem.prettyName or menuItem.targetVariable) .. ": " .. tostring(value)
		elseif menuItem.action == "selectSetting" then
			--Condition: This menuItem is for selecting a setting
			if menuItem.display == nil then menuItem.display = menuItem.setting or "undefined setting" end
		else
			--Condition: menuItem action is not recognized
			if menuItem.display == nil then menuItem.display = menuItem.action end
		end
	end
end

function menu_draw()
	-- Dim the game when the menu is open.
	if menu_currentData.suppressMenuBackground == nil then
		menu_draw_background()
	end
	
	--the area used for drawing the menu, all measured from the top or left side of the screen
	local top = border_top
	local bottom = border_bottom - 2
	local left = border_left + 4
	local right = border_right - 5
	
	local lineHeight = 14 -- the vertical distance from one line to the next
	local sectionSpacer = 12 -- the extra space included between distinct sections of the menu
	local menuSpacer = 2 -- the extra space included between menu items
	local charWidth = 8 -- the width of one character. Used for calculating where to put line breaks and should not be changed unless you're changing the font family or size
	local indent = charWidth * 5 -- used to indent the menu items and title from the left side of the screen
	
	local regular_frontColor = "white"
	local regular_backColor = "black"
	local selected_frontColor = "pink"
	local selected_backColor = "purple"
	
	local y = top
	
	local _description = ""
	local _lines = 1
	
	--Draw the menu title
	gui.drawText(left + indent + indent, y, menu_title, "white", "black")
	y = y + lineHeight + sectionSpacer
	
	--Draw the menu description, if any
	if menu_description ~= nil and menu_description ~= "" then
		_description, _lines = menu_createListOfLines(menu_description, math.floor((right - left) / charWidth))
		menu_drawMultilineText(left, y, _description, lineHeight, "white", "black")
		y = y + (lineHeight * _lines) + sectionSpacer
	end
	
	if menu_items ~= nil then
		
		local menu_items_height = bottom - y
		
		--Calculate the space required for the description
		--of the currently highlighted menu item, if any.
		local descriptionLines = 0
		if ((menu_items[menu_cursor] or {}).description or "") ~= "" then
			_description, _lines = menu_createListOfLines(menu_items[menu_cursor].description, math.floor((right - left) / charWidth))
			descriptionLines = _lines
		else
			_description = nil
			_lines = nil
		end
		descriptionLines = math.max(descriptionLines, menu_currentData.reservedDescriptionLines or 0)
		menu_items_height = menu_items_height - (lineHeight * descriptionLines) - sectionSpacer
		
		--Calculate how many menu items can be drawn, based
		--on the available space
		local fewestPossibleItems = 3
		local maximumPossibleItems = menu_currentData.limitDisplayedItems or 9
		local totalMenuItems = #menu_items
		local maxItemsShown = math.min(math.max(math.min(math.floor((menu_items_height + menuSpacer) / (lineHeight + menuSpacer)), totalMenuItems), fewestPossibleItems), maximumPossibleItems)
		local firstItemShown = math.max(math.min(menu_cursor - math.floor((maxItemsShown - 1) / 2), totalMenuItems - maxItemsShown + 1), 1)
		local lastItemShown = math.min(firstItemShown + maxItemsShown - 1, totalMenuItems)
		
		--Draw an indicator if more menu items are available above the ones shown
		if firstItemShown > 1 then
			gui.drawText(left + indent, y - lineHeight, "...", regular_frontColor, regular_backColor)
		end
		
		--Draw the menu items
		for i = firstItemShown,lastItemShown do
			local isSelected = menu_items[i].selected
			gui.drawText(left + indent, y, menu_items[i].display, isSelected and selected_frontColor or regular_frontColor, isSelected and selected_backColor or regular_backColor)
			
			if menu_cursor == i and menu_cursorFlash then
				local leftRightCursor = (menu_items[menu_cursor] or {}).action or ""
				leftRightCursor = leftRightCursor == "onOffSetting" or leftRightCursor == "offRawSmoothSetting" or leftRightCursor == "offTrueDelayedSetting" or leftRightCursor == "offOnAlwaysSetting" or leftRightCursor == "numberSetting"
				if leftRightCursor then
					gui.drawPolygon({{-14, 3}, {-14 + 8, 3 + 4}, {-14, 3 + 8},}, left + indent + 2, y, 0x80000000, 0xffffffff)
					gui.drawPolygon({{-14, 3}, {-14 - 8, 3 + 4}, {-14, 3 + 8},}, left + indent - 8, y, 0x80000000, 0xffffffff)
				else
					gui.drawRectangle(left + indent - 18, y + 3, 8, 9, 0x80000000, 0xffffffff)
				end
			end
			y = y + lineHeight + menuSpacer
		end
		
		--Draw an indicator if more menu items are available below the ones shown
		if lastItemShown < totalMenuItems then
			gui.drawText(left + indent, y - menuSpacer - 4, "...", regular_frontColor, regular_backColor)
		end
		
		y = y - menuSpacer -- removing the extra space that was automatically added after the last menu item
		
		--Draw the description for the highlighted menu item, if any
		if _description ~= nil then
			y = y + sectionSpacer
			menu_drawMultilineText(left, y, _description, lineHeight, "white", "black")
		end
	end
end

function menu_draw_background()
	---[[ Dim the game when the menu is open. Color format is 0xAARRGGBB
	local color = 0xA0101010
	gui.drawBox(border_left, border_top, border_right, border_bottom, color, color)
	--]]
end

function menu_draw_keyboard()

	menu_draw_background()
	
	local top = 20
	local left = 80
	
	local y = top
	local x = left
	
	local dx = 34
	local dy = 16
	
	local regular_frontColor = "white"
	local regular_backColor = "black"
	local selected_frontColor = "pink"
	local selected_backColor = "purple"
	
	local outputString = "Name: " .. (menu_currentData.keyboard_output or "")
	if menu_cursorFlash then outputString = outputString .. [[_]] end
	
	gui.drawText(x, y, outputString, "white", "black", 22)
	
	x = left
	y = y + dy * 2
	
	for i = 1, #menu_items do
		local label = menu_items[i].keys[1]
		if menu_currentData.keyboard_caps > 0 and #(menu_items[i].keys) > 1 then
			label = menu_items[i].keys[2]
		end
		
		if label == "*" then label = "" end
		
		if label == "delete" then label = "Delete" end
		
		if label == "space" then label = "Space" end
		
		if label == "done" then label = "Done" end
		
		if label == "cancel" then label = "Cancel" end
		
		if label == "caps" then
			if menu_currentData.keyboard_caps == 0 then label = "shift"
			elseif menu_currentData.keyboard_caps == 1 then label = "Shift"
			else label = "SHIFT" end
		end
		
		gui.drawText(x, y, label, (menu_cursor == i and menu_cursorFlash) and selected_frontColor or regular_frontColor, (menu_cursor == i and menu_cursorFlash) and selected_backColor or regular_backColor)
		
		if menu_cursor == i then
			gui.drawRectangle(x, y + 13, 10, 2, 0x80000000, 0xffffffff)
		end
		
		x = x + dx
		if i % menu_currentData.keyboard_width == 0 then
			x = left
			y = y + dy
		end
	end
	
	
	if menu_currentData.keyboard_description ~= nil then
		local _description, _lines
		_description, _lines = menu_createListOfLines(menu_currentData.keyboard_description, math.floor((530 - left) / 8))
		y = y + dy
		menu_drawMultilineText(left, y, _description, 14, "white", "black")
	end
end

function menu_wrapText(text, charWidth)
	if (text or "") == "" then return "", 1 end

	local _lines = 1
	
	local words = string.split(text, " ")
	local _text = words[1]
	local x = charWidth - string.len(words[1])--tracks the remaining space on the current line
	
	for i,v in ipairs(words) do
		if i > 1 then
			if string.len(v) > x then
				x = charWidth - string.len(v)
				_text = _text .. "\n" .. v
				_lines = _lines + 1
			else
				x = x - string.len(v) - 1
				_text = _text .. " " .. v
			end			
		end
	end
	
	return _text, _lines
end

function menu_createListOfLines(text, charWidth)
	-- Converts a long string to a table of strings with a
	-- max length of charWidth. Will break lines at spaces
	-- when possible.
	
	text = string.trim(text)
	
	if (text or "") == "" then return {""}, 1 end

	local _lines = 1
	
	local _table = {}
	
	local paragraphs = string.split(text, "\n")
	
	if #paragraphs > 1 then
		-- Condition: The provided text already contains line breaks, so we need to work around them.
		
		for i, p in ipairs(paragraphs) do
			local pTable = menu_createListOfLines(p, charWidth)
			for j, q in ipairs(pTable) do
				table.insert(_table, q)
				_lines = _lines + 1
			end
		end
	else
		-- Condition: The provided text has no line breaks, so we just need to add our own.
		local words = string.split(paragraphs[1], " ")
		local _text = words[1]
		local x = charWidth - string.len(words[1])--tracks the remaining space on the current line
		
		for i, v in ipairs(words) do
			if i > 1 then
				if string.len(v) > x then
					x = charWidth - string.len(v)
					table.insert(_table, _text)
					_text = v
					_lines = _lines + 1
				else
					x = x - string.len(v) - 1
					_text = _text .. " " .. v
				end			
			end
		end
		
		table.insert(_table, _text)
	end
	
	return _table, _lines
end

function menu_drawMultilineText (x, y, textTable, spacing, frontColor, backColor)
	if textTable == nil then return end
	
	if frontColor == nil then frontColor = "white" end
	if backColor == nil then backColor = "black" end
	
	if type(textTable) == "string" then
		gui.drawText(x, y, textTable, frontColor, backColor)
		return
	end

	for i,v in ipairs(textTable) do
		gui.drawText(x, y, v, frontColor, backColor)
		y = y + spacing
	end

end

function draw_inputs()
	--Cancel the menu once the player starts moving Spyro
	local sensitivity = 50
	if inputs.leftStick_x.value > 128 + sensitivity or inputs.leftStick_x.value < 128 - sensitivity or inputs.leftStick_y.value > 128 + sensitivity or inputs.leftStick_y.value < 128 - sensitivity or inputs.dPad_left.value or inputs.dPad_right.value or inputs.dPad_up.value or inputs.dPad_down.value then
		menu_showInputs = 0
		return
	end

	local top = 50
	local spacing = 13
	local left = 60
	
	gui.drawText(left, top + spacing * 0, " Mode: " .. tostring(recordingModePrettyNames[recordingMode]), "white", "black")
	gui.drawText(left, top + spacing * 1, "Route: " .. tostring(getCategoryPrettyName()), "white", "black")
	
	gui.drawText(left, top + spacing * 4, "  Right Stick", "white", "black")
	gui.drawText(left, top + spacing * 5, " Left: " .. getActionName(menu_leftAction()), "white", "black")
	gui.drawText(left, top + spacing * 6, "Right: " .. getActionName(menu_rightAction()), "white", "black")
	gui.drawText(left, top + spacing * 7, "   Up: " .. getActionName(menu_upAction()), "white", "black")
	gui.drawText(left, top + spacing * 8, " Down: " .. getActionName(menu_downAction()), "white", "black")
	
	gui.drawText(left, top + spacing * 10, "   L3: " .. getActionName(menu_L3Action()), "white", "black")
	gui.drawText(left, top + spacing * 11, "   R3: " .. getActionName(menu_R3Action()), "white", "black")
end

function draw_updateSegment()
	
	if segment_lastRecording == nil then
		menu_segmentUpdate_timer = 0
		return
	end
	
	--Position of the GUI
	local x = 40
	local y = 120
	local dy = 20--vertical spacing between lines

	--Gem Count
	local color = "white"--color to display text elements	
	if segment_lastRecording.flightLevel == nil then
		if segment_lastRecording_gemCount ~= segment_lastRecording_gemTotal and segment_lastRecording.enforceGemRequirement then color = "red" end
		gui.drawText(x, y, "Gems: " .. tostring(segment_lastRecording_gemCount) .. "/" .. tostring(segment_lastRecording_gemTotal), color, "black")
	else
		if segment_lastRecording.flightLevel then
			gui.drawText(x, y, "Level Complete!", "white", "black")
		else
			gui.drawText(x, y, "Level Failed", "red", "black")
		end
	end
	
	if segment_lastRecording.flightLevel == nil or segment_lastRecording.flightLevel then
	
		-- Calculate and print segment time
		local endTime = getFormattedTime(segment_lastRecording.length)
		
		gui.drawText(x, y+dy, "Final Time: " .. endTime, "white", "black")

		-- Calculate and print segment delta
		if menu_segmentUpdate_delta ~= nil then

			local percent = ""
			if showDeltaPercent then
				percent = menu_segmentUpdate_delta / (segment_lastRecording.length - menu_segmentUpdate_delta)
				local sign = percent >= 0 and "+" or ""
				percent = "   " .. string.format("%s%d%%", sign, percent * 100)
			end

			local s, c = getFormattedTime(menu_segmentUpdate_delta, true, menu_segmentUpdate_forceFrames)--This should not be calculated here. 
			s = "Delta: " .. s .. percent
			
			gui.drawText(x, y+2*dy, s, c, "black")
		end
		
		-- Print input to overwrite segment data, if new time is faster. If current route is 120%, also check that we got all the gems.
		if segment_readyToUpdate and ((segment_lastRecording_gemCount == segment_lastRecording_gemTotal or not segment_lastRecording.enforceGemRequirement) or segment_lastRecording.flightLevel) and not run_readyToUpdate then
			local updateButton = getInputForAction("updateSegment")
			if updateButton == "" then updateButton = getInputForAction("updateSegment_run") end
			if updateButton ~= "" then
				gui.drawText(x, y+3*dy, "Save new ghost with " .. updateButton, "white", "black")
			end
		end
	end
	
end

function draw_endOfRun()
	if run_lastRecording == nil then
		menu_showEndOfRun = false
		return
	end
	
	--Position of the GUI
	local x = border_right - 45
	local y = 100
	local dy = 20--vertical spacing between lines
	
	-- Calculate and print run time
	local endTime = getFormattedTime(run_lastRecording.length)
	
	if run_finalRank and run_finalRank > 0 then
		gui.drawText(x, y+1*dy, "Final Rank: " .. ordinal(run_finalRank), "white", "black", 12, nil, nil, "right")
	end
	
	gui.drawText(x, y+2*dy, "Final Time: " .. endTime, "white", "black", 12, nil, nil, "right")

	-- Calculate and print run delta
	if menu_runUpdate_delta ~= nil then

		local percent = ""
		if showDeltaPercent then
			percent = menu_runUpdate_delta / (run_lastRecording.length - menu_runUpdate_delta)
			local sign = percent >= 0 and "+" or ""
			percent = "   " .. string.format("%s%.0d%%", sign, percent * 100)
		end

		local s, c = getFormattedTime(menu_runUpdate_delta, true, menu_runUpdate_forceFrames)--This should not be calculated here. 
		s = "Delta: " .. s .. percent
		
		gui.drawText(x, y+3*dy, s, c, "black", 12, nil, nil, "right")
	end
	
	-- Print input to overwrite run data.
	if run_readyToUpdate then
		local updateButton = getInputForAction("saveRun")
		if updateButton ~= "" then
			gui.drawText(x, y+4*dy, "Save new ghost with " .. updateButton, "white", "black", 12, nil, nil, "right")
		end
	end
end

function drawStats()
	local top = 38
	local spacing = 13
	local left = 480
	
	local i = 0
	
	if showBonkCounter then
		gui.drawText(left, top + spacing * i, "Bonks:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%3d", bonkCounter), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	
	if showSpeed == 1 then
		gui.drawText(left, top + spacing * i, "Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%5.1f", spyroSpeed / 8), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	if showSpeed == 2 then
		gui.drawText(left, top + spacing * i, "Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%5.1f", ((spyroSpeed + lastSpyroSpeed) / 2 ) / 8), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	
	if showGroundSpeed == 1 then
		gui.drawText(left, top + spacing * i, "Ground Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%5.1f", spyroGroundSpeed / 8), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	if showGroundSpeed == 2 then
		gui.drawText(left, top + spacing * i, "Ground Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%5.1f", ((spyroGroundSpeed + lastSpyroGroundSpeed) / 2) / 8), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	
	if showLogicalSpeed == 1 then
		gui.drawText(left, top + spacing * i, "Logical Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%3d", spyroLogicalSpeed), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	if showLogicalSpeed == 2 then
		gui.drawText(left, top + spacing * i, "Logical Speed:  ", "white", "black", 12, nil, nil, "right")
		gui.drawText(left, top + spacing * i, string.format("%3d", (spyroLogicalSpeed + lastSpyroLogicalSpeed) / 2), "white", "black", 12, nil, nil, "left")
		i = i + 1
	end
	
end

-------------------------
-- On-screen Messages, Debug Messages, and Errors
-------------------------

do
	onscreenMessages = {}
	onscreenMessages_maximum = 5
	onscreenMessages_left = border_left + 4
	onscreenMessages_bottom = border_bottom - 30
	onscreenMessages_lineHeight = 14

	showDebugMessages = false
end

function showMessage(message)

	if (message or "") == "" then return end
	

	table.insert(onscreenMessages, 1, {["message"] = message, ["time"] = 30 * 4})
	if(#onscreenMessages > onscreenMessages_maximum) then
		table.remove(onscreenMessages, onscreenMessages_maximum + 1)
	end
	
end

function showDebug(message)

	if (message or "") == "" then return end
	
	if showDebugMessages then
		showMessage(message, false)
		print(message)
	end
end

function showError(message)

	if (message or "") == "" then return end

	showMessage(message, false)
	print(message)
end

function onscreenMessages_update()
	local lineOffset = 0
	for index,data in ipairs(onscreenMessages) do
		data["time"] = data["time"] - 1
		if data["time"] < 1 then
			table.remove(onscreenMessages, index)
		else
			local color = "white"
			if data["time"] < 30 then color = "gray" end
			gui.drawText(onscreenMessages_left, onscreenMessages_bottom - lineOffset, data["message"], color, "black")
			lineOffset = lineOffset + onscreenMessages_lineHeight
		end
	end
end

do
	timeFormat_frames = false
	
	quickDelta_timer = 0
	quickDelta_color = "white"
	quickDelta_text = ""
end

function getFormattedTime(frames, forceSign, forceFrames, useLetters)
	if useLetters then
		local hourMarker = "h"
		local minuteMarker = "m"
		local secondMarker = "s"
		local frameMarker = "f"
	else
		local hourMarker = ":"
		local minuteMarker = ":"
		local secondMarker = ""
		local frameMarker = ""
	end

	local fps = framerate
	
	local plus = forceSign and "+" or ""

	local sign = 1
	local color = "red"
	if frames < 0 then
		sign = -1
		color = "green"
	end
	
	local hours = math.floor((frames * sign) / (fps * 3600))
	local minutes = math.floor((frames * sign) / (fps * 60)) - hours * 60
	local seconds = math.floor((frames * sign) / fps) % 60
	
	local subSecond = (frames * sign) % fps
	
	local subSecondType =  timeFormat_frames
	if forceFrames ~= nil then subSecondType = forceFrames end
	if subSecondType then
		if not useLetters then secondMarker = "'" end
		subSecond = secondMarker .. string.format("%02d", subSecond) .. frameMarker
	else
		subSecond = "." .. string.format("%02d", subSecond / fps * 100) .. secondMarker
	end
	
	local output = (sign == 1) and plus or "-"
	if hours > 0 then
		output = output .. tostring(hours) .. hourMarker .. string.format("%02d", minutes) .. minuteMarker .. string.format("%02d", seconds) .. subSecond
	else
		if minutes > 0 then
			output = output .. tostring(minutes) .. minuteMarker .. string.format("%02d", seconds) .. subSecond
		else
			output = output .. tostring(seconds) .. subSecond
		end
	end
	
	return output, color
end

function quickDelta_show(framesDelta, forceFrames)
	quickDelta_text, quickDelta_color = getFormattedTime(framesDelta, true, forceFrames)
	quickDelta_text = "Delta: " .. quickDelta_text
	quickDelta_timer = 30 * 4
end

function quickDelta_draw()
	gui.drawText(30, 100, quickDelta_text, quickDelta_color, "black")
end

-------------------------
-- All Recording Modes
-------------------------

do -- Variables used by all recording modes
	saveStateRequested = false -- This allows the onLoadSavestate() event needs to know whether a savestate was loaded by the player or by this script.
	
	allGhosts = {}
	rebuildAllGhosts = false
end

function clearAllRecordingData()
	tryRunGlobalFunction("manual_clearData")
	tryRunGlobalFunction("segment_clearData")
	tryRunGlobalFunction("run_clearData")
	allGhosts = {}
end

-------------------------
-- Manual Mode
-------------------------

do -- Manual Mode Variables
	manual_recording = nil
	manual_ghost = nil
	manual_stateExists = false
end

function manual_clearData()
	showDebug("manual_clearData()")
	
	manual_recording = nil
	manual_ghost = nil
	rebuildAllGhosts = true
	manual_stateExists = false
end

function createQuickSavestate()
	savestate.save(file.combinePath("data", "quicksave"))
end

function loadQuickSavestate()
	saveStateRequested = true
	savestate.load(file.combinePath("data", "quicksave"))
end

-------------------------
-- Segment Mode
-------------------------

do -- Segment Mode Settings and Variables
	segment_settings = {}
	
	segment_recording = nil
	segment_ghosts = {} -- A list of all ghosts that are currently being shown, including the one we're comparing against.
	segment_ghostsSet = {} -- Same as above, but as an unordered set storing only the uids
	segment_ghostSettings = {}
	segment_comparison_ghost = nil -- The ghost we're currently comparing against.
	segment_comparison_collection = "Unknown"
	segment_comparison_target = "lengthSort"
	segment_comparison_useColor = true
	segment_comparison_color = 0xFFFFFFFF
	
	segment_lastRecording = nil -- Keeps a copy of the most recently completed recording (from segment_recording) while we wait to see if the player will save it.
	segment_lastRecording_gemCount = 0
	segment_lastRecording_gemTotal = 1	
	segment_readyToUpdate = false
	
	segment_autoSaveGhosts = false -- A setting to automatically save all ghosts without waiting for the player to confirm they should be saved. Only intended for use cases such as creating a ghost from a tas.
		
	segment_preloadAllGhosts = false -- Load all available ghosts into segment_loadedGhostCach when the script first starts.
	
	segment_levelStartArmed = false
	segment_dragonSplitThisFrame = false
	segment_dragonSplitArmed = false
	
	segment_showSubSegmentGhosts = false
	
	segment_shownFlightLevelRestartTip = false
end

function segment_clearData()
	showDebug("segment_clearData()")
	
	segment_recording = nil
	segment_ghosts = {}
	rebuildAllGhosts = true
	segment_comparison_ghost = nil
	segment_lastRecording = nil
	segment_readyToUpdate = false
	
	segment_levelStartArmed = false
	segment_dragonSplitThisFrame = false
	segment_dragonSplitArmed = false
end

function segment_loadGhosts()
	segment_ghosts = {}
	rebuildAllGhosts = true
	segment_ghostsSet = {}
	segment_comparison_ghost = nil
	
	if recordingMode == "segment" or run_showSegmentGhosts then
		-- For each collection, load some ghosts from it (maybe).
		for collectionName in pairs(collections) do
					
			local collection = getGlobalVariable({"ghostData", "segment", getCategoryHandle(currentSegment), segmentToString(currentSegment), collectionName})
			
			if type(collection) == "table" then
			
				if (segment_ghostSettings[collectionName] or {}).showAll then
					-- Condition: The option to show all ghosts has
					-- been set for this collection.
					
					for i = 1, #(collection.lengthSort or {}) do
						local ghost, alreadyLoaded = loadRecordingUsingCache(collection.lengthSort[i], collectionName)
						if Ghost.isGhost(ghost) and not alreadyLoaded then
							table.insert(segment_ghosts, ghost)
							segment_ghostsSet[ghost.uid] = true
						end
					end
					
				else
					-- Condition: We're not showing all ghosts, so
					-- check which ones should be shown.
					
					-- Load the fastest ghosts from this collection
					local loadXFastest = (segment_ghostSettings[collectionName] or {}).showFastest or 0
					for i = 1, math.min(#(collection.lengthSort or {}), loadXFastest) do
						local ghost, alreadyLoaded = loadRecordingUsingCache(collection.lengthSort[i], collectionName)
						if Ghost.isGhost(ghost) and not alreadyLoaded then
							table.insert(segment_ghosts, ghost)
							segment_ghostsSet[ghost.uid] = true
						end
					end
					
					-- Load the most recent ghosts from this collection
					local loadXRecent = (segment_ghostSettings[collectionName] or {}).showRecent or 0
					for i = 1, math.min(#(collection.timestampSort or {}), loadXRecent) do
						local ghost, alreadyLoaded = loadRecordingUsingCache(collection.timestampSort[i], collectionName)
						if Ghost.isGhost(ghost) and not alreadyLoaded then
							table.insert(segment_ghosts, ghost)
							segment_ghostsSet[ghost.uid] = true
						end
					end
				end
			end
		end
		
		-- Determine which ghost to compare to, loading it if it is not already loaded.	
		local comparison_target = getGlobalVariable({"ghostData", "segment", getCategoryHandle(currentSegment), segmentToString(currentSegment), segment_comparison_collection, segment_comparison_target, 1})

		local ghost, alreadyLoaded = loadRecordingUsingCache(comparison_target, segment_comparison_collection)
		if Ghost.isGhost(ghost) then
			segment_comparison_ghost = ghost
			if not alreadyLoaded then
				table.insert(segment_ghosts, ghost)
				segment_ghostsSet[ghost.uid] = true
			end
			if segment_comparison_useColor then
				ghost.color = segment_comparison_color or 0xFFFFFFFF
			end
		end
	end
	
	-- Force unused ghosts to be removed from the cache
	cleanCachedGhosts = true
end

function segment_start()
	if recordingMode ~= "segment" and recordingMode ~= "run" then return end
	
	bonkCounter = 0
	
	showDebug("Segment Start")
	
	segment_dragonSplitArmed = false
	
	segment_recording = Ghost.startNewRecording("segment")

	for i, ghost in ipairs(segment_ghosts) do
		if Ghost.isGhost(ghost) then
			ghost:startPlayback()
		end
	end
end

function segment_halt()
	if recordingMode ~= "segment" and recordingMode ~= "run" then return end
	
	
	-- Handle full runs
	if recordingMode == "run" and run_recording ~= nil then
		run_recording.segmentSplits[getSegmentHandle()] = emu.framecount() - run_recording.zeroFrame
	end
	if recordingMode == "run" and not run_showSegmentGhosts then return end
	
	segment_dragonSplitArmed = false
	
	showDebug("Segment End")
	
	if Ghost.isGhost(segment_recording) then
		segment_recording:endRecording()
		
		segment_readyToUpdate = true
		segment_lastRecording = segment_recording
		segment_recording = nil
		
		segment_lastRecording.enforceGemRequirement = currentRoute == "120" and segment_lastRecording.segment[1] == "Level" and (segment_lastRecording.segment[3] == "Entry" or segment_lastRecording.segment[3] == "Balloon")
		
		local level = segment_lastRecording.segment[2]
		if segment_lastRecording.segment[3] ~= "Entry" then level = level - level % 10 end
		
		segment_lastRecording_gemCount = memory.read_u32_le((math.floor((level-10)/10)*6+(level%10))*4+0x77420+m[4])
		segment_lastRecording_gemTotal = levelInfo[level].gems
		
		menu_segmentUpdate_timer = menu_segmentUpdate_maxTimer
		quickDelta_timer = 0

		if Ghost.isGhost(segment_comparison_ghost) then
			if segment_comparison_ghost.framerate == framerate then
					menu_segmentUpdate_delta = segment_lastRecording.length - segment_comparison_ghost.length
					menu_segmentUpdate_forceFrames = nil
				else
					menu_segmentUpdate_delta = segment_lastRecording.length - (segment_comparison_ghost.length * framerate / segment_comparison_ghost.framerate)
					menu_segmentUpdate_forceFrames = false
			end
		else
			menu_segmentUpdate_delta = nil
		end
		
		if segment_autoSaveGhosts then
			handleAction("updateSegment")
		end
	end
end

function segment_restart(targetSegment)
	local targetFile = getGlobalVariable({"savestateData", "segment", currentRoute, segmentToString(targetSegment)})
	if targetFile ~= nil then
		currentSegment = targetSegment
		currentLevel = currentSegment[2]
		if currentSegment[1] ~= "Entry" then
			currentLevel = currentLevel - currentLevel % 10
		end
		flightLevel = levelInfo[currentLevel].flightLevel
		
		segment_recording = nil
		segment_lastRecording = nil
		segment_readyToUpdate = false
		if recordingMode == "segment" or recordingMode == "run" then segment_levelStartArmed = true end
		run_recording = nil
		run_lastRecording = nil
		run_readyToUpdate = false
		if recordingMode == "run" and currentSegment[2] == 10 and currentSegment[3] == "Entry" then run_runStartArmed = true end
		spyroControl = 0
		
		--try to load ghost
		if recordingMode == "segment" or recordingMode == "run" then segment_loadGhosts() end
		
		--try to load full run ghost
		if recordingMode == "run" and currentSegment[2] == 10 and currentSegment[3] == "Entry" then run_loadGhosts() end
		
		--load savestate
		saveStateRequested = true
		requestedState = targetFile
		
		local f = assert(io.open(file.combinePath("data", "requestedState.txt"), "w+"))
		f:write(targetFile)
		f:close()
		
		savestate.load(targetFile)
		return true
	else
		showMessage("No savestate found for current segment in the current route.")
		return false
	end
end

function segment_ghostSettings_createDefault(c)
	segment_ghostSettings[c] = {showAll = false, showRecent = 0, showFastest = 0, color = 0xFFFFFFFF}
end

function segment_collectionSettings_getFileName(c)
	return(file.combinePath("Ghosts", c, "collectionSettings.txt"))
end

function segment_saveCollectionSettings(c)
	local settings = (segment_ghostSettings or {})[c]
	if c == nil then return end

	if not file.exists(file.combinePath("Ghosts", c)) then
		file.createFolder(file.combinePath("Ghosts", c))
	end
	
	local f = assert(io.open(segment_collectionSettings_getFileName(c), "w"))
	f:write("Collection Settings", "\n", "version: 1", "\n")
	
	f:write("showAll: ", (settings.showAll or false) and "True" or "False", "\n")
	f:write("showRecent: ", tostring(settings.showRecent or 0), "\n")
	f:write("showFastest: ", tostring(settings.showFastest or 0), "\n")
	f:write("color: ", string.format("0x%X", settings.color or 0), "\n")
	
	f:close()
end

function segment_loadCollectionSettings(c)
	local settingsPath = segment_collectionSettings_getFileName(c)
	if not file.exists(settingsPath) then return end
	
	local f = assert(io.open(settingsPath, "r"))
	while true do
		local t = f:read()
		if t == nil then break end
		
		tryParseSetting(t, "showAll: ", {"segment_ghostSettings", c, "showAll"}, "bool")
		tryParseSetting(t, "showRecent: ", {"segment_ghostSettings", c, "showRecent"}, "number")
		tryParseSetting(t, "showFastest: ", {"segment_ghostSettings", c, "showFastest"}, "number")
		tryParseSetting(t, "color: ", {"segment_ghostSettings", c, "color"}, "number")
	end
	f:close()
end

function segment_loadAllCollectionSettings()
	for c in pairs(collections) do
		segment_loadCollectionSettings(c)
	end
end

function segment_exportGolds()
	local collectionFolder = playerName .. " Golds " .. os.date("%Y-%m-%d")
	for category, segment_table in pairs(ghostData["segment"]) do
		for segment, collection_table in pairs(segment_table) do
			local goldGhost = ((collection_table[playerName] or {}).lengthSort or {})[1]
			if goldGhost then
				local targetPath = file.combinePath({"Ghosts", collectionFolder, getCategoryFolderName(category)})
				if not file.exists(targetPath) then
					file.createFolder(targetPath)
				end
				file.copy(goldGhost.filePath, file.combinePath({targetPath, file.nameFromPath(goldGhost.filePath)}))
			end
		end
	end
	segment_ghostSettings_createDefault(collectionFolder)
	segment_ghostSettings[collectionFolder].showFastest = 1
	segment_ghostSettings[collectionFolder].color = 0xFFFFFF00
	segment_saveCollectionSettings(collectionFolder)
	return collectionFolder
end

-------------------------
-- Full Run Mode
-------------------------

if true then -- Full Run Mode Settings and Variables
	
	run_recording = nil
	run_ghosts = {} -- A list of all ghosts that are currently being shown, including the one we're comparing against.
	run_ghostsSet = {} -- Same as above, but as an unordered set storing only the uids
	
	run_collection = "Unknown"
	run_loadXFastest = 0
	run_loadXRecent = 0
	run_ghostColor = 0xFFFFFFFF
	
	run_comparison_ghost = nil -- The ghost we're currently comparing against.
	run_comparison_target = "lengthSort"
	run_comparison_useColor = false -- No setting for this currently exists
	run_comparison_color = 0xFFFFFFFF
	
	run_ranking = {}
	run_rankingNames = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",}
	run_showRanking = false
	run_rankingPlace = 0
	
	run_showRankList = false
	run_showRankNames = false
	run_showRankPlace = true
	
	run_lastRecording = nil -- Keeps a copy of the most recently completed recording (from run_recording) while we wait to see if the player will save it.
	run_readyToUpdate = false
	
	run_runStartArmed = false
	
	run_showSegmentGhosts = true
end

function run_clearData()
	run_showRanking = false
	
	run_recording = nil
	run_ghosts = {}
	rebuildAllGhosts = true
	run_ghostsSet = {}
	
	run_clearRanking()
	
	run_lastRecording = nil
	run_readyToUpdate = false
	run_runStartArmed = false
	
	run_rankingPlace = 0
end

function run_clearRanking()

	run_ranking = {}
	run_showRanking = false
end

function run_loadGhosts()
	run_ghosts = {}
	rebuildAllGhosts = true
	run_ghostsSet = {}
	run_comparison_ghost = nil
	
	run_clearRanking()
	
	local collectionName = run_collection
	local loadXFastest = run_loadXFastest
	local loadXRecent = run_loadXRecent
	local ghostColor = run_ghostColor
	
	local run_comparison_target = run_comparison_target
	
	-- Load extra ghosts (additional to the comparison) from the target collection 
	local collection = getGlobalVariable({"ghostData", "run", getCategoryHandle(currentSegment), segmentToString(currentSegment), collectionName})
	
	if type(collection) == "table" then
		-- Load the fastest ghosts from this collection
		for i = 1, math.min(#(collection.lengthSort or {}), loadXFastest) do
			local ghost, alreadyLoaded = loadRecordingUsingCache(collection.lengthSort[i], collectionName, ghostColor)
			if Ghost.isGhost(ghost) and not alreadyLoaded then
				table.insert(run_ghosts, ghost)
				run_ghostsSet[ghost.uid] = true
			end
		end
		
		-- Load the most recent ghosts from this collection
		for i = 1, math.min(#(collection.timestampSort or {}), loadXRecent) do
			local ghost, alreadyLoaded = loadRecordingUsingCache(collection.timestampSort[i], collectionName, ghostColor)
			if Ghost.isGhost(ghost) and not alreadyLoaded then
				table.insert(run_ghosts, ghost)
				run_ghostsSet[ghost.uid] = true
			end
		end
	end
	
	-- Determine which ghost to compare to, loading it if it is not already loaded.	
	local comparison_target = getGlobalVariable({"ghostData", "run", getCategoryHandle(currentSegment), segmentToString(currentSegment), segment_comparison_collection, run_comparison_target, 1})

	local ghost, alreadyLoaded = loadRecordingUsingCache(comparison_target, collectionName, ghostColor)
	if Ghost.isGhost(ghost) then
		run_comparison_ghost = ghost
		if not alreadyLoaded then
			table.insert(run_ghosts, ghost)
			run_ghostsSet[ghost.uid] = true
		end
		if run_comparison_useColor then
			ghost.color = run_comparison_color or 0xFFFFFFFF
		end
	end
	
	-- Establish ranking names and starting positions
	run_ranking = {}
	for i, v in ipairs(run_ghosts) do
		table.insert(run_ranking, v)
	end
	table.sort(run_ranking, function(a, b)
		return a.length < b.length
	end)
	for i, v in ipairs(run_ranking) do
		v.rankingName = run_getRankingName(i)
		v.rankingLastFrame = 0
	end
	
	-- Force unused ghosts to be removed from the cache
	cleanCachedGhosts = true
end

function run_getRankingName(i)
	if run_rankingNames[i] then return run_rankingNames[i] end
	return tostring(i - #run_rankingNames)
end

function run_updateRankings()
	if run_ranking == nil or #run_ranking == 0 then return end
	
	local overtakes = {}
	
	for i, v in ipairs(run_ranking) do
		local oldTime = v.rankingLastFrame
		local newTime = emu.framecount() - v.zeroFrame
		for k, t in pairs(v.segmentSplits) do
			if t > oldTime and t <= newTime then
				--print("split: " .. tostring(v.rankingName))
				for ii, vv in ipairs(run_ranking) do
					if ii >= i then break end
					if vv.segmentSplits[k] and vv.segmentSplits[k] > t then
						table.insert(overtakes, {v, vv})
					end
				end
				-- Check for overtaking the player
				if gameState ~= 12 and v ~= run_recording and k == getSegmentHandle() then
					table.insert(overtakes, {v, run_recording})
				end
				if v == run_recording then
					for ii, vv in ipairs(run_ranking) do
						if vv.segmentSplits[k] and vv.segmentSplits[k] < t then
							table.insert(overtakes, {vv, v})
						end
					end
				end
				break
			end
		end
		v.rankingLastFrame = newTime
	end
	
	--[[ DEBUG: show overtakes in console as they happen
	if #overtakes > 0 then
		print("Overtake")
		for i, v in ipairs(overtakes) do
			print(v[1].rankingName .. " -> " .. v[2].rankingName)
		
		end
	end
	--]]
	for i, v in ipairs(overtakes) do
		local tempGhost = nil
		for ii, vv in ipairs(run_ranking) do
			if tempGhost ~= nil then
				run_ranking[ii] = tempGhost
				tempGhost = vv
				if tempGhost == v[1] then break end
			end
			if vv == v[1] and tempGhost == nil then break end
			if vv == v[2] then
				tempGhost = vv
				run_ranking[ii] = v[1]
			end
		end
	end
end

function run_start()
	if recordingMode ~= "run" then return end
	
	showDebug("Run Start")
	
	run_recording = Ghost.startNewRecording("run")
	
	run_rankingPlace = 0
	
	table.insert(run_ranking, 1, run_recording)
	run_recording.rankingName = "Player"
	if #run_ranking > 1 then
		run_showRanking = true
	end

	for i, ghost in ipairs(run_ghosts) do
		if Ghost.isGhost(ghost) then
			ghost:startPlayback()
		end
	end
end

function run_halt()
	if recordingMode ~= "run" then return end
	
	showDebug("Run End")
	
	run_showRanking = false
	
	run_finalRank = 0
	
	if Ghost.isGhost(run_recording) then
	
		if run_rankingPlace > 0 then
			run_finalRank = run_rankingPlace
		end
	
		run_recording:endRecording()
		
		menu_showEndOfRun = true
		run_readyToUpdate = true
		run_lastRecording = run_recording
		run_recording = nil

		if Ghost.isGhost(run_comparison_ghost) then
			if run_comparison_ghost.framerate == framerate then
					menu_runUpdate_delta = run_lastRecording.length - run_comparison_ghost.length
					menu_runUpdate_forceFrames = nil
				else
					menu_runUpdate_delta = run_lastRecording.length - (run_comparison_ghost.length * framerate / run_comparison_ghost.framerate)
					menu_runUpdate_forceFrames = false
			end
		else
			menu_runUpdate_delta = nil
		end
	end
end

-------------------------
-- File Tracking and Handling
-------------------------

do
	ghostData = {}
	collections = {}
	savestateData = {}
end

-- This function scans through the directories to find
-- ghost and savestate files. Metadata for these files are
-- saved in tables so we can quickly figure out what is
-- available without having to search through folders
-- every time.
function populateFileList()

	-- The global table that will hold the information about ghosts
	ghostData = {}
	
	-- Ghost metadata will be saved to a file so we can load it faster next time.
	cachedGhostData = {VERSION = 2}
	
	local cacheFilePath = file.combinePath("data","cachedGhostData.txt")
	if file.exists(cacheFilePath) then
		local f  = assert(io.open(file.combinePath("data","cachedGhostData.txt"), "r"))
		loadedGhostDataCache = JSON:decode(f:read("*a"))
		f:close()
	else
		loadedGhostDataCache = {}
	end
	
	if loadedGhostDataCache.VERSION ~= cachedGhostData.VERSION then
		-- Version mismatch, so discard the old cache
		loadedGhostDataCache = {}
	end
	
	-- The global table that will hold a list of available ghost collections.
	-- These are the folders in the 
	collections = {}
	if playerName or "" ~= "" then
		collections[playerName] = true
	else
		collections["Unknown"] = true
	end
	
	-- The full paths we'll get later are absolute paths,
	-- so it will be useful to know how deep into the
	-- folder hierarchy we are.
	local seperator = package.config:sub(1, 1)
	local collectionDirectoryLevel = #(string.split(io.popen("echo %cd%"):read(), seperator)) + 2
	
	-- Recursivly search through the Ghosts directory
	-- hierarchy, running the following code for each file
	-- that is found.
	file.forAllFilesRecursively("Ghosts", function(fullPath, fileName)
		
		-- Ensure this is the correct type of file.
		if not string.ends(string.lower(fileName), ".txt") then return end
		
		-- Skip this file if it is a collection settings file
		if string.ends(fileName, "collectionSettings.txt") then return end
		
		-- Keep track of whether we have successfully loaded this ghost's metadata
		local ghostIsValid = false
		
		-- Check if the file's metadata has been cached
		if loadedGhostDataCache[fullPath] then
			-- Condition: this file has been loaded before, so load the cached metadata
			
			addNewGhostMeta(loadedGhostDataCache[fullPath])
			cachedGhostData[fullPath] = loadedGhostDataCache[fullPath]
			collections[loadedGhostDataCache[fullPath].collection] = true
			ghostIsValid = true
		else
			-- Condition: we have no record of seeing this file before, so open the file to investigate
			
			-- The metadata for this ghost (assuming it is a valid ghost file)
			local ghostMeta = {filePath = fullPath}
			
			-- Determine the collection.
			local directoryTreeList = string.split(fullPath, seperator)
			if #directoryTreeList < collectionDirectoryLevel + 1 then
				-- Condition: The user has put a ghost file
				-- directly in the Ghosts folder, not a
				-- collection folder. Treat this as the
				-- Unknown collection.
				ghostMeta.collection = "Unknown"
			else
				ghostMeta.collection = directoryTreeList[collectionDirectoryLevel]
			end
			
			-- Track what collections exist.
			collections[ghostMeta.collection] = true
			
			-- The entries to search for. The ghost is only considered valid if all of these are present.
			local requiredItems = {"uid", "playerName", "gameName", "mode", "framerate", "category", "segment", "length", "timestamp"}
			
			-- Open the file and begin looping through its lines.
			local f = assert(io.open(fullPath, "r"))
			local keepLooping = true
			
			local line = f:read()
			
			if line == "version: 2" or line == "version: 3" then 
				while keepLooping do
					line = f:read()
					if line == nil then
						-- Condition: We've reached the end of the
						-- file, so exit the loop. If we reach this
						-- point, then the required info was not
						-- found in the file and the metadata
						-- is discarded.
						
						keepLooping = false
						
					else
						-- Condition: We haven't reached the end of
						-- the file. Check this line to see if it
						-- has information we need.
						
						for i, v in ipairs(requiredItems) do
							-- Loop through the list of
							-- requirements, checking each to see
							-- if we've found it.
							if string.starts(line, v) then
								-- Condition: We've found a piece of data we're
								-- looking for. Add it to the metadata for this ghost.
								ghostMeta[v] = string.trim(string.sub(line, string.len(v) + 2))
								
								-- Remove this requirement from the list. This is done
								-- both so we don't keep searching for it and because
								-- we check if we've found all the required data by
								-- testing if requiredItems is empty.
								table.remove(requiredItems, i)
								break
							end
						end
						
						-- Check if we've found all the requirements.
						if #requiredItems == 0 then
							-- If we have, then stop reading data
							-- from this file and add the metadata
							-- to the global table.
							
							-- First, convert some values to numbers
							ghostMeta.framerate = tonumber(ghostMeta.framerate)
							ghostMeta.timestamp = tonumber(ghostMeta.timestamp)
							ghostMeta.length = tonumber(ghostMeta.length)
							if ghostMeta.framerate ~= framerate then
								ghostMeta.length = ghostMeta.length * framerate / ghostMeta.framerate
							end
							
							-- Add the metadata to the global table, initializing the tables if they do not exist
							keepLooping = false
							if ghostMeta.gameName == "Spyro the Dragon" then
								addNewGhostMeta(ghostMeta)
								cachedGhostData[fullPath] = ghostMeta
								ghostIsValid = true
							end
						end
					end
				end
			end
			
			f:close()
		
		end
		
		-- Load the ghost into the cache if the segment_preloadAllGhosts setting is set.
		if ghostIsValid and segment_preloadAllGhosts and loadedGhostCache[ghostMeta.uid] == nil then
			local newCachedData = {age = 0, data = loadGhostFromMeta(ghostMeta),}
			if newCachedData.data then
				loadedGhostCache[ghostMeta.uid] = newCachedData
			end
		end
		
	end)
	
	-- Save the metadata cache so it can be loaded
	-- faster next time.
	local f  = assert(io.open(file.combinePath("data","cachedGhostData.txt"), "w"))
	f:write(JSON:encode(cachedGhostData))
	f:close()
	cachedGhostData = nil
	loadedGhostDataCache = nil
	
	-- The table that will hold information about the available savestates
	savestateData = {}
	
	file.forAllFilesRecursively("Savestates", function(fullPath, fileName)
	
		-- Make sure this is the correct type of file.
		if not string.ends(string.lower(fileName), ".state") then return end
		
		-- We can't put metadata inside the .state file, so
		-- all the needed info is built into the file name.
		-- Remove the ".state" from the end and break the
		-- name into separate components.
		local fileParts = string.split(bizstring.replace(fileName, ".state", ""), "-")
		
		-- Skip this file if it is not a known format.
		if bizstring.trim(fileParts[5]) ~= "v1" then return end
		
		-- Skip this file if it is for the wrong region.
		if bizstring.trim(fileParts[1]) ~= displayType then return end
		
		setGlobalVariable({"savestateData", bizstring.trim(fileParts[2]), bizstring.trim(fileParts[3]), bizstring.trim(fileParts[4])}, fullPath)
	end)
	
end

function addNewGhostMeta(ghostMeta)
	-- Create the arrays if they do not already exist.
	if type(getGlobalVariable({"ghostData", ghostMeta.mode, ghostMeta.category, ghostMeta.segment, ghostMeta.collection, "lengthSort"})) ~= "table" then
		setGlobalVariable({"ghostData", ghostMeta.mode, ghostMeta.category, ghostMeta.segment, ghostMeta.collection, "lengthSort"}, {})
	end
	if type(getGlobalVariable({"ghostData", ghostMeta.mode, ghostMeta.category, ghostMeta.segment, ghostMeta.collection, "timestampSort"})) ~= "table" then
		setGlobalVariable({"ghostData", ghostMeta.mode, ghostMeta.category, ghostMeta.segment, ghostMeta.collection, "timestampSort"}, {})
	end
	
	-- Insert the ghost metadata into the arrays while keeping them sorted.
	table.insertSorted(ghostData[ghostMeta.mode][ghostMeta.category][ghostMeta.segment][ghostMeta.collection].lengthSort, ghostMeta, function(a, b) return a.length < b.length end)
	table.insertSorted(ghostData[ghostMeta.mode][ghostMeta.category][ghostMeta.segment][ghostMeta.collection].timestampSort, ghostMeta, function(a, b) return a.timestamp > b.timestamp end)
end

function loadGhostFromMeta(ghostMeta)
	local f = (ghostMeta or {}).filePath
	if f ~= nil then
		return loadRecordingFromFile(f)
	end
	return nil
end

-------------------------
-- Ghost Class
-------------------------

do
	loadedGhostCache = {} -- A list of ghosts and their data. When reloading a segment, the script will check here first before loading a ghost from file. Ghosts that are no longer being used will be dropped from this cache unless segment_preloadAllGhosts is set.
	ghostQualityOptions = {
		high = {
			maxTotalError = 100,
			maxDirError = 0.15,
			compression = "none",
		},
		low = {
			maxTotalError = 300,
			maxDirError = 0.35,
			compression = "diff",
			angleFactor = 50,
		},
	}
end

Ghost = {
	isPlaying = false,
	isRecording = false,
	keyframes = {},
	dragonSplits = {},
	length = 0,
	zeroFrame = 0,
	subSegmentOffset = 0,
	currentKeyframe = 0,
	ghostLevel = 0,
	animation = 1,
	playerName = "Unknown",
	gameName = "Spyro the Dragon",
	framerate = 60,
	mode = "segment",
	category = "120",
	segment = {},
	collection = "Unknown",
	dateTime = "unknown",
	timestamp = 0,
	uid = "unknown",
	quality = ghostQualityOptions.high,
	counter = 1,
	--keyframeHit = 0 --DEBUG to determine how many frames are being thrown away (keyframe / total frames)
	--keyframeTotal = 0
}

function Ghost:new(o)
	o = o or {} -- create object if user does not provide one
	setmetatable(o, self)
	self.__index = self
	return o
end

function Ghost.isGhost(o)
	if type(o) == "table" and getmetatable(o) == Ghost then return true end
	
	return false
end

function Ghost.startNewRecording(mode)
	local newRecording = Ghost:new()
	
	newRecording.keyframes = {}
	newRecording.dragonSplits = {}
	newRecording.segmentSplits = {} -- used during full game runs to show when different segments exit
	newRecording.isRecording = true
	newRecording.zeroFrame = emu.framecount() - 1
	newRecording.animation = 1
	newRecording.playerName = playerName
	newRecording.framerate = framerate
	newRecording.mode = mode
	newRecording.category = getCategoryHandle(getCurrentSegment())
	newRecording.segment = getCurrentSegment()
	newRecording.datetime = os.date("%Y-%m-%d %H.%M.%S")
	newRecording.timestamp = os.time()
	
	if mode == "run" then
		newRecording.quality = ghostQualityOptions.low
	else
		newRecording.quality = ghostQualityOptions.high
	end
	
	newRecording.state1 = {}
	newRecording.state2 = {}
	newRecording.state3 = {}
	
	newRecording.uid = bizstring.replace(string.format("%04X%03X%X", math.random(2 ^ 16) - 1, Ghost.counter, os.time()) .. tostring(playerName), " ", "")
	Ghost.counter = Ghost.counter + 1
	
	return newRecording
end

function Ghost:endRecording()
	if self.isRecording == false then return end
	
	self.isRecording = false
end

function Ghost:startPlayback()
	self:endRecording()
	self.isPlaying = true
	self.zeroFrame = emu.framecount() - 1
	self.subSegmentOffset = 0
	self.currentKeyframe = 1
	self.ghostLevel = (self.keyframes[self.currentKeyframe] or {})["segment"] or self.ghostLevel
	self.animation = (self.keyframes[self.currentKeyframe] or {})["animation"] or 1
	if not showGhostAnimations then self.animation = 1 end
end

function Ghost:resumePlayback()
	self.isPlaying = true
end

function Ghost:endPlayback()
	self.isPlaying = false
end

function Ghost.update(ghost)
	if Ghost.isGhost(ghost) then
		ghost:_update()
	end
end

function Ghost:_update()
	if self.isRecording then
		self:updateRecording()
	end
	
	if self.isPlaying then
		self:updatePlayback()
	end
end

function Ghost:updateRecording()

	local currentFrame = emu.framecount() - self.zeroFrame
	
	local newSegment = false
	local newKeyframe = false
	
	local animationChange = false
	
	local targetKeyframe = #self.keyframes
	if targetKeyframe == 0 then
		--We have not created our first segment and keyframe yet
		newSegment = true
	elseif self.keyframes[targetKeyframe]["segment"] ~= nil then
		--The last keyframe created was the start of a segment, so create a new keyframe immediately
		newKeyframe = true
	else
		--Create keyframe if too much time has passed
		if self.keyframes[targetKeyframe][1] - self.keyframes[targetKeyframe - 1][1] > framerate then
			newKeyframe = true
		end
		
		--Create keyframe if our speed has changed too much
		local xSpeed = 0
		local ySpeed = 0
		local zSpeed = 0
		local dirSpeed = 0
		if self.keyframes[targetKeyframe - 1]["segment"] == nil then
			local deltaTime = self.keyframes[targetKeyframe - 1][1] - self.keyframes[targetKeyframe - 2][1]
			xSpeed = (self.keyframes[targetKeyframe - 1][2][1] - self.keyframes[targetKeyframe - 2][2][1]) / deltaTime
			ySpeed = (self.keyframes[targetKeyframe - 1][2][2] - self.keyframes[targetKeyframe - 2][2][2]) / deltaTime
			zSpeed = (self.keyframes[targetKeyframe - 1][2][3] - self.keyframes[targetKeyframe - 2][2][3]) / deltaTime
			
			dirSpeed = (self.keyframes[targetKeyframe - 1][3] - self.keyframes[targetKeyframe - 2][3])
			if dirSpeed > _pi then dirSpeed = dirSpeed - _tau end
			if dirSpeed < -_pi then dirSpeed = dirSpeed + _tau end
			dirSpeed = dirSpeed / deltaTime
		end
		
		local deltaTime = currentFrame - self.keyframes[targetKeyframe - 1][1]
		
		local xError = spyroX - (self.keyframes[targetKeyframe - 1][2][1] + xSpeed * deltaTime)
		local yError = spyroY - (self.keyframes[targetKeyframe - 1][2][2] + ySpeed * deltaTime)
		local zError = spyroZ - (self.keyframes[targetKeyframe - 1][2][3] + zSpeed * deltaTime)
		
		local totalError = math.sqrt(xError * xError + yError * yError + zError * zError)
		--gui.drawText(100, 100, tostring(totalError), "white", "black")
				
		if totalError > self.quality.maxTotalError then
			newKeyframe = true
		end
		
		local dirError = math.abs(spyroDirection - (self.keyframes[targetKeyframe - 1][3] + dirSpeed * deltaTime))
		if dirError > _pi then dirError = _tau - dirError end
		
		if dirError > self.quality.maxDirError then
			newKeyframe = true
		end
		
		--Create keyframe if our angle has changed too much
		local directionChange = math.abs(spyroDirection - self.keyframes[targetKeyframe - 1][3])
		if directionChange > _pi then directionChange = _tau - directionChange end
		if directionChange > 2 then
			newKeyframe = true
		end
		
	end
	
	--Create keyframes when Spyro starts and stops moving
	self.state3 = self.state2
	self.state2 = self.state1
	self.state1 = {spyroX, spyroY, spyroZ, spyroDirection}
	if table.isSimilar(self.state1, self.state2) ~= table.isSimilar(self.state2, self.state3) then
		newKeyframe = true
	end
	
	--Create keyframe on button events
	if (inputs.square.press or inputs.square.release or inputs.X.press) and (spyroControl == 0 and gameState == 0) then
		newKeyframe = true
	end
	
	--Create keyframe on grounding state change
	if thisFrameGrounded ~= lastFrameGrounded then
		newKeyframe = true
	end
	
	--Create keyframe on position discontinuities (death, level entry)
	--gameState is 5 during game over screen. This check prevents an extra discontinuity being detected.
	if spyroSpeed > 600 and gameState ~= 5 then
		newSegment = true
		showDebug("Detected discontinuity")
	end
	
	--Create keyframe on animation change
	if spyroAnimation ~= lastSpyroAnimation then
		newKeyframe = true
		animationChange = true
	end
	
	local newLevel = false
	--Detect level change
	if lastLevel ~= currentLevel then
		showDebug("Detected level change")
		newLevel = true
		newSegment = true
	end
	
	-- Handle creating new keyframe if needed
	if newSegment then
		newKeyframe = true
		animationChange = true
	end
	
	if Ghost.noCompression then
		newKeyframe = true
	end
	
	if newKeyframe then
		targetKeyframe = targetKeyframe + 1
		--gui.drawText(100, 120, "Keyframe!", "white", "black")
		--keyframeHit = keyframeHit + 1

	end
	
	if Ghost.showKeyframes then
		gui.drawPie(70, 30, 60, 34, 0, 360, 0, conditional(newKeyframe, 0xFFFF0000, 0xFFE0E0E0))
	end

	--keyframeTotal = keyframeTotal + 1
	--gui.drawText(100, 140, tostring(keyframeHit / keyframeTotal), "white", "black")

	if not newKeyframe and (self.keyframes[targetKeyframe] or {})["animation"] ~= nil then--prevent animation from being overwritten
		animationChange = true
	end
	

	-- Update or create data in keyframe
	self.keyframes[targetKeyframe] = {currentFrame, {spyroX, spyroY, spyroZ}, spyroDirection}
	
	if newSegment then
		--using idiom (a and b or c) = conditional operator (a ? b : 0)
		self.keyframes[targetKeyframe]["segment"] = newLevel and 0 or currentLevel
	end
	
	if animationChange then
		self.keyframes[targetKeyframe]["animation"] = spyroAnimation
	end
	
	--Create keyframe on dragon splits
	if segment_dragonSplitThisFrame then
		table.insert(self.dragonSplits, currentFrame)
		if Ghost.isGhost(segment_comparison_ghost) and segment_comparison_ghost.dragonSplits[#self.dragonSplits] ~= nil then
			if segment_comparison_ghost.framerate == framerate then
				quickDelta_show(self.dragonSplits[#self.dragonSplits] - segment_comparison_ghost.dragonSplits[#self.dragonSplits])
			else 
				quickDelta_show(self.dragonSplits[#self.dragonSplits] - (segment_comparison_ghost.dragonSplits[#self.dragonSplits] * framerate / segment_comparison_ghost.framerate), false)
			end
		else
			showDebug("Detected dragon")
		end
	end
	
	self.length = currentFrame
end

function Ghost:updatePlayback()
	-- This updates the ghosts position and other values
	
	self._doDraw = false
	
	local currentFrame = emu.framecount() - self.zeroFrame + conditional(segment_showSubSegmentGhosts, self.subSegmentOffset, 0)
	if self.framerate ~= framerate then
		currentFrame = currentFrame * self.framerate / framerate
	end
	
	-- Delay the ghost by two frames (at 30 fps) to compensate for the frame buffer.
	currentFrame = currentFrame - 4
	
	-- Cancel rendering if the current frame is outside the range
	if currentFrame < 1 or currentFrame > self.length then return end
	
	-- Advance current keyframe as needed.
	while self.keyframes[self.currentKeyframe + 1] ~= nil and self.keyframes[self.currentKeyframe + 1][1] <= currentFrame do
		self.currentKeyframe = self.currentKeyframe + 1
		
		self.ghostLevel = self.keyframes[self.currentKeyframe]["segment"] or self.keyframes[self.currentKeyframe]["l"] or self.ghostLevel
		self.keyframes[self.currentKeyframe]["l"] = self.ghostLevel
		
		self.animation = self.keyframes[self.currentKeyframe]["animation"] or self.keyframes[self.currentKeyframe]["a"] or self.animation
		self.keyframes[self.currentKeyframe]["a"] = self.animation
		
		if not showGhostAnimations then self.animation = 1 end
	end
	
	-- Roll back keyframe if needed. This can happen if a negative offset has been applied.
	while self.keyframes[self.currentKeyframe - 1] ~= nil and self.keyframes[self.currentKeyframe][1] > currentFrame do
		self.currentKeyframe = self.currentKeyframe - 1
		
		self.ghostLevel = self.keyframes[self.currentKeyframe]["segment"] or self.keyframes[self.currentKeyframe]["l"] or self.ghostLevel
		
		self.animation = self.keyframes[self.currentKeyframe]["animation"] or self.keyframes[self.currentKeyframe]["a"] or self.animation
		
		if not showGhostAnimations then self.animation = 1 end
	end
	
	-- This shouldn't be possible, but stop rendering if it does.
	if self.keyframes[self.currentKeyframe] == nil then return end
	
	-- Draw the ghost only if it is in the same level as the player.
	if self.ghostLevel == currentLevel then
		
		-- We'll use linear interpolation between keyframes,
		-- but not if we're already on the final keyframe or
		-- the next keyframe is a segment keyframe (which is
		-- used when the ghost's movement is discontinuous
		-- or it is moving between levels).
		if self.keyframes[self.currentKeyframe + 1] == nil or self.keyframes[self.currentKeyframe + 1]["segment"] ~= nil then
			-- Condition: we don't need to interpolate to the next keyframe
			
			self._position = self.keyframes[self.currentKeyframe][2]
			self._rotation = self.keyframes[self.currentKeyframe][3]
			self._doDraw = true
		else
			--Condition: we need to interpolate to the next keyframe
			
			local frame1 = self.keyframes[self.currentKeyframe][1]
			local spyroV1 = self.keyframes[self.currentKeyframe][2]
			local spyroDirection1 = self.keyframes[self.currentKeyframe][3]
			local frame2 = self.keyframes[self.currentKeyframe + 1][1]
			local spyroV2 = self.keyframes[self.currentKeyframe + 1][2]
			local spyroDirection2 = self.keyframes[self.currentKeyframe + 1][3]
			
			local interp = (currentFrame - frame1) / (frame2 - frame1)
			local spyroVI = {
				spyroV1[1] * (1 - interp) + spyroV2[1] * interp,
				spyroV1[2] * (1 - interp) + spyroV2[2] * interp,
				spyroV1[3] * (1 - interp) + spyroV2[3] * interp
			}
			
			if spyroDirection2 > spyroDirection1 + _pi then spyroDirection2 = spyroDirection2 - _tau end
			if spyroDirection2 < spyroDirection1 - _pi then spyroDirection2 = spyroDirection2 + _tau end
			local spyroDirectionI = (spyroDirection1 * (1 - interp)) + (spyroDirection2 * interp)
			
			self._position = spyroVI
			self._rotation = spyroDirectionI
			self._doDraw = true
		end
		
		-- Determine distance from camera (used for sorting)
		if self._doDraw then
			self._cameraRange = cameraPitch_cos * (cameraYaw_cos * (self._position[1] - cameraX) - cameraYaw_sin * (self._position[2] - cameraY)) - cameraPitch_sin * (self._position[3] - cameraZ)
		end
	end
end

function Ghost:draw()
	if self.isPlaying and self._doDraw then
		drawGhost(self._position, self._rotation, self.animation, self.color)
	end
end

function Ghost:changeSubSegmentOffset(frame)
	
	local oldFrameOffset = self.subSegmentOffset

	-- Convert framerates if needed
	if self.framerate ~= framerate then
		frame = frame * framerate / self.framerate
	end
	
	-- Calculate new offset so that ghost will render the desired frame on the next update
	self.subSegmentOffset = frame - (emu.framecount() - self.zeroFrame)
end

function saveRecordingToFile(path, ghost)

	local compression = ghost.quality.compression
	local fileVersion = (compression == "diff") and 3 or 2

	local f = assert(io.open(path, "w"))
	
	-----
	-- Header
	-----
	f:write("version: ", tostring(fileVersion), "\n")
	
	f:write("uid: ", ghost.uid, "\n")
	f:write("gameName: ", ghost.gameName, "\n")
	f:write("playerName: ", ghost.playerName, "\n")
	f:write("mode: ", ghost.mode, "\n")
	f:write("category: ", ghost.category, "\n")
	f:write("segment: ", segmentToString(ghost.segment), "\n")
	f:write("length: ", tostring(ghost.length), "\n")
	f:write("datetime: ", ghost.datetime, "\n")
	f:write("timestamp: ", tostring(ghost.timestamp), "\n")
	f:write("framerate: ", tostring(ghost.framerate), "\n")
	f:write("compression: ", compression, "\n")
	if compression == "diff" then f:write("angleFactor: ", ghost.quality.angleFactor, "\n") end
	f:write("segmentSplits: ", JSON:encode(ghost.segmentSplits), "\n")
	
	-----
	-- Dragon Splits
	-----
	f:write("dragonSplits: ")
	for index,data in ipairs(ghost.dragonSplits) do
		f:write((index == 1) and "" or ", ", tostring(data))
	end
	f:write("\n")
	
	-----
	-- Keyframes
	-----
	f:write("Keyframes\n")
	
	if compression == "diff" then
		--One line is written per keyframe using the following format:
		--frameNumber,spyroX,spyroY,spyroZ,spyroDirection[,s:12][,a:1]
		local lastData = {0, {0, 0, 0,},}
		local lastAngle = 0
		for index,data in ipairs(ghost.keyframes) do
			--f:write(tostring(index), "\n")
			f:write(tostring(data[1] - lastData[1]))
			f:write(",", tostring(data[2][1] - lastData[2][1]))
			f:write(",", tostring(data[2][2] - lastData[2][2]))
			f:write(",", tostring(data[2][3] - lastData[2][3]))
			local angle = math.floor(data[3] * ghost.quality.angleFactor + 0.5)
			f:write(",", tostring(angle - lastAngle))
			lastAngle = angle
			if data["segment"] ~= nil then
				f:write(",s:", tostring(data["segment"]))
			end
			if data["animation"] ~= nil then
				f:write(",a:", tostring(data["animation"]))
			end
			f:write("\n")
			lastData = data
		end
	else
		--One line is written per keyframe using the following format:
		--frameNumber, spyroX, spyroY, spyroZ, spyroDirection [,segment:12] [,dragon]
		for index,data in ipairs(ghost.keyframes) do
			--f:write(tostring(index), "\n")
			f:write(tostring(data[1]))
			f:write(", ", tostring(data[2][1]))
			f:write(", ", tostring(data[2][2]))
			f:write(", ", tostring(data[2][3]))
			f:write(", ", string.format("%.3f", data[3]))
			if data["segment"] ~= nil then
				f:write(", segment: ", tostring(data["segment"]))
			end
			if data["animation"] ~= nil then
				f:write(", animation: ", tostring(data["animation"]))
			end
			f:write("\n")
		end
	end
	
	f:write("End of Keyframes\n")
	
	f:close()
end

function loadRecordingFromFile(path)
	if not file.exists(path) then return nil end
	
	local newGhost = Ghost:new()
	local newKeyframes = {}
	local newDragonSplits = {}
	local newSegmentSplits = {}
	
	local line = nil
	local items = nil
	local f = assert(io.open(path, "r"))
	
	--line = f:read()--reading header
	
	while true do
		line = f:read()
		if line == nil then break end
		
		if string.starts(line, "playerName:") then
			local s = string.trim(string.sub(line, string.len("playerName:") + 1))
			if (s or "") ~= "" then newGhost.playerName = s end
		
		elseif string.starts(line, "gameName:") then
			local s = string.trim(string.sub(line, string.len("gameName:") + 1))
			if (s or "") ~= "" then newGhost.gameName = s end
		
		elseif string.starts(line, "framerate:") then
			local s = string.trim(string.sub(line, string.len("framerate:") + 1))
			if (s or "") ~= "" then newGhost.framerate = tonumber(s) end
			
		elseif string.starts(line, "length:") then
			local s = string.trim(string.sub(line, string.len("length:") + 1))
			if (s or "") ~= "" then newGhost.length = tonumber(s) end
			
		elseif string.starts(line, "mode:") then
			local s = string.trim(string.sub(line, string.len("mode:") + 1))
			if (s or "") ~= "" then newGhost.mode = s end
			
		elseif string.starts(line, "category:") then
			local s = string.trim(string.sub(line, string.len("category:") + 1))
			if (s or "") ~= "" then newGhost.category = s end
		
		elseif string.starts(line, "segment:") then
			local s = string.trim(string.sub(line, string.len("category:") + 1))
			if (s or "") ~= "" then newGhost.category = segmentFromString(s) end
		
		elseif string.starts(line, "datetime:") then
			local s = string.trim(string.sub(line, string.len("datetime:") + 1))
			if (s or "") ~= "" then newGhost.datetime = s end
			
		elseif string.starts(line, "timestamp:") then
			local s = string.trim(string.sub(line, string.len("timestamp:") + 1))
			if (s or "") ~= "" then newGhost.timestamp = tonumber(s) end
			
		elseif string.starts(line, "uid:") then
			local s = string.trim(string.sub(line, string.len("uid:") + 1))
			if (s or "") ~= "" then newGhost.uid = s end
		
		local angleFactor = 1
		elseif string.starts(line, "angleFactor:") then
			local s = string.trim(string.sub(line, string.len("angleFactor:") + 1))
			if (s or "") ~= "" then angleFactor = s end
		
		elseif string.starts(line, "compression:") then
			local s = string.trim(string.sub(line, string.len("compression:") + 1))
			if (s or "") ~= "" then newGhost.compression = s end
			
		elseif string.starts(line, "Keyframes") then
			if (newGhost.compression or "none") == "diff" then
				local lastKeyframe = {0, {0, 0, 0,},}
				local lastAngle = 0
				while true do
					line = f:read()
					if line == nil or string.starts(line, "End") then break end
					
					items = string.split(line, ",")
					
					local angle = tonumber(items[5])
					local newKeyframe = {
						tonumber(items[1]) + lastKeyframe[1],
						{
							tonumber(items[2]) + lastKeyframe[2][1],
							tonumber(items[3]) + lastKeyframe[2][2],
							tonumber(items[4]) + lastKeyframe[2][3],
						},
						(angle + lastAngle) / angleFactor,
					}
					lastAngle = lastAngle + angle
					
					local i = 6
					while items[i] ~= nil do
						if string.starts(items[i], "s") then
							newKeyframe["segment"] = tonumber(string.sub(items[i], 3))
						elseif string.starts(items[i], "a") then
							newKeyframe["animation"] = tonumber(string.sub(items[i], 3))
						end
						i = i + 1
					end
					
					table.insert(newKeyframes, newKeyframe)
					lastKeyframe = newKeyframe
				end

			else
				while true do
					line = f:read()
					if line == nil or string.starts(line, "End") then break end
					
					items = string.split(line, ",")
					
					local newKeyframe = {tonumber(items[1]), {tonumber(items[2]), tonumber(items[3]), tonumber(items[4])}, tonumber(items[5])}
					
					local i = 6
					while items[i] ~= nil do
						if string.starts(items[i], " segment") then
							newKeyframe["segment"] = tonumber(string.sub(items[i], 10))
						elseif string.starts(items[i], " animation") then
							newKeyframe["animation"] = tonumber(string.sub(items[i], 12))
						end
						i = i + 1
					end
					
					table.insert(newKeyframes, newKeyframe)
				end
			end
		elseif string.starts(line, "dragonSplits") then
			items = string.split(string.sub(line, 14), ",")
			local i = 1
			while items[i] ~= nil and tonumber(items[i]) ~= nil do
				table.insert(newDragonSplits, tonumber(items[i]))
				i = i + 1
			end
			
		elseif string.starts(line, "segmentSplits") then
			newSegmentSplits = JSON:decode(string.sub(line, 15))
		end
    end
	f:close()
	
	newGhost.keyframes = newKeyframes
	newGhost.dragonSplits = newDragonSplits
	newGhost.segmentSplits = newSegmentSplits
	return newGhost
end

function loadRecordingUsingCache(meta, collection, color)

	--Make sure this thing is real
	if type(meta) ~= "table" then return nil, false end
	
	if loadedGhostCache[meta.uid] then
		-- Condition: This ghost is already loaded and doesn't need to be read from file again.
		local alreadyLoaded = segment_ghostsSet[meta.uid] or run_ghostsSet[meta.uid]
		local ghost = loadedGhostCache[meta.uid].data
		
		-- It is possible for the same ghost to exist in multiple collections. If the
		-- ghost is loaded from multiple collections at the same time, it will prefer
		-- to represent a collection that is not the default collection (playerName).
		-- For example: if the player exports their golds to a new collection and
		-- then changes the color for the gold collection, that will always be the
		-- color that is used, even though those ghosts still exist in the default
		-- collection.
		if not alreadyLoaded or collection ~= playerName then
			ghost.collection = collection
		end
		ghost.color = color or (segment_ghostSettings[ghost.collection] or {}).color or 0xFFFFFFFF
		return ghost, alreadyLoaded
	else
		-- Condition: Only the metadata from this ghost is currently loaded, so the data needs to be read from file.
		local ghost = loadGhostFromMeta(meta)
		if Ghost.isGhost(ghost) then
			loadedGhostCache[meta.uid] = {data = ghost}
			ghost.collection = collection
			ghost.color = color or (segment_ghostSettings[collection] or {}).color or 0xFFFFFFFF
			return ghost, false
		else
			showError("Something went wrong when loading ghost.")
			return nil, false
		end
	end
end

-------------------------
-- Skins
-------------------------

do
	--[[
	This section contains code that can overwrite Spyro's
	palette data. The texture data cannot be overwritten by
	this code.
	
	spyroSkin.palettes contains a list of memory
	ranges in vram where Spyro's palettes are stored. The
	locations of palettes do not change between levels.
	Each palette technically contains 16 2-byte words, each
	word containing one color. I'm skipping the first word
	in each palette because it contains a transparent color
	for all of Spyro's palettes.
	
	spyroSkin.originalPalette contains the raw palette data
	copied from the game. Contains lots of purple.
	--]]
	
	spyroSkin = {}	
	
	currentPalette = nil
	currentPalette_name = "Original"
	
	menu_palettes = nil
end

--The locations of Spyro's palette data in gpu ram
spyroSkin.palettes_main = {
	{0x0D6FA2, 0x0D6FBE},
	{0x0D77A2, 0x0D77BE},--eyes
	{0x0D7FA2, 0x0D7FBE},
	{0x0F0FE2, 0x0F0FFE},
	{0x0F17E2, 0x0F17FE},
	{0x0F1FE2, 0x0F1FFE},
	{0x0F27E2, 0x0F27FE},
	{0x0F2FE2, 0x0F2FFE},
	{0x0F37E2, 0x0F37FE},
	{0x0F3FE2, 0x0F3FFE},
	{0x0F47E2, 0x0F47FE},
	{0x0F4FE2, 0x0F4FFE},
	{0x0F57E2, 0x0F57FE},
	{0x0F5FE2, 0x0F5FFE},
	{0x0F67E2, 0x0F67FE},
	{0x0F6FE2, 0x0F6FFE},--teeth
	{0x0F77E2, 0x0F77FE},
}

spyroSkin.palettes_main_PAL = {
	{0xD6FA2, 0xD6FBE}, -- Palette #1
	{0xD77A2, 0xD77BE}, -- Palette #2
	{0xD7FA2, 0xD7FBE}, -- Palette #3
	{0xD07A2, 0xD07BE}, -- Palette #4
	{0xC0FC2, 0xC0FDE}, -- Palette #5
	{0xC0FE2, 0xC0FFE}, -- Palette #6
	{0xC17A2, 0xC17BE}, -- Palette #7
	{0xC17C2, 0xC17DE}, -- Palette #8
	{0xC17E2, 0xC17FE}, -- Palette #9
	{0xC1FA2, 0xC1FBE}, -- Palette #10
	{0xC1FC2, 0xC1FDE}, -- Palette #11
	{0xC1FE2, 0xC1FFE}, -- Palette #12
	{0xD0FC2, 0xD0FDE}, -- Palette #13
	{0xD0FE2, 0xD0FFE}, -- Palette #14
	{0xD17C2, 0xD17DE}, -- Palette #15
	{0xD17E2, 0xD17FE}, -- Palette #16
	{0xD1FC2, 0xD1FDE}, -- Palette #17
}

--the locations of Spyro's palette data in gpu ram when on the title screen, because it's different. 
spyroSkin.palettes_title = {
	{0x286A2, 0x286BE},
	{0x246A2, 0x246BE},
	{0x2C6A2, 0x2C6BE},
	{0x206C2, 0x206DE},
	{0x206E2, 0x206FE},
	{0x246C2, 0x246DE},
	{0x246E2, 0x246FE},
	{0x286C2, 0x286DE},
	{0x286E2, 0x286FE},
	{0x206A2, 0x206BE},
	{0x2C6C2, 0x2C6DE},
	{0x2C6E2, 0x2C6FE},
	{0x20702, 0x2071E},
	{0x20722, 0x2073E},
	{0x20742, 0x2075E},
	{0x20762, 0x2077E},
	{0x20782, 0x2079E},
}

spyroSkin.palettes_title_PAL = {
	{0x24682, 0x2469E}, -- Palette #1
	{0x206A2, 0x206BE}, -- Palette #2
	{0x246A2, 0x246BE}, -- Palette #3
	{0x28682, 0x2869E}, -- Palette #4
	{0x286A2, 0x286BE}, -- Palette #5
	{0x2C682, 0x2C69E}, -- Palette #6
	{0x2C6A2, 0x2C6BE}, -- Palette #7
	{0x206C2, 0x206DE}, -- Palette #8
	{0x206E2, 0x206FE}, -- Palette #9
	{0x20682, 0x2069E}, -- Palette #10
	{0x246C2, 0x246DE}, -- Palette #11
	{0x246E2, 0x246FE}, -- Palette #12
	{0x286C2, 0x286DE}, -- Palette #13
	{0x286E2, 0x286FE}, -- Palette #14
	{0x2C6C2, 0x2C6DE}, -- Palette #15
	{0x2C6E2, 0x2C6FE}, -- Palette #16
	{0x20702, 0x2071E}, -- Palette #17
}

spyroSkin.palettes_iveGotSomeThingsToDo = {
	{0x38682, 0x3869E},
	{0x3C682, 0x3C69E},
	{0x346A2, 0x346BE},
	{0x386A2, 0x386BE},
	{0x3C6A2, 0x3C6BE},
	{0x346C2, 0x346DE},
	{0x386C2, 0x386DE},
	{0x3C6C2, 0x3C6DE},
	{0x346E2, 0x346FE},
	{0x386E2, 0x386FE},
	{0x08722, 0x0873E},
	{0x3C6E2, 0x3C6FE},
	{0x30682, 0x3069E},
	{0x306A2, 0x306BE},
	{0x306C2, 0x306DE},
	{0x306E2, 0x306FE},
	{0x40602, 0x4061E},
}

spyroSkin.palettes_iveGotSomeThingsToDo_PAL = {--Confirmed on English. Known to be wrong on Spanish. Yup.
	{0xC47E2, 0xC47FE}, -- Palette #1
	{0xC87C2, 0xC87DE}, -- Palette #2
	{0xC87E2, 0xC87FE}, -- Palette #3
	{0xCC7C2, 0xCC7DE}, -- Palette #4
	{0xCC7E2, 0xCC7FE}, -- Palette #5
	{0xD47C2, 0xD47DE}, -- Palette #6
	{0xD47E2, 0xD47FE}, -- Palette #7
	{0xC17C2, 0xC17DE}, -- Palette #8
	{0x24682, 0x2469E}, -- Palette #9
	{0x28682, 0x2869E}, -- Palette #10
	{0x08722, 0x0873E}, -- Palette #11
	{0x2C682, 0x2C69E}, -- Palette #12
	{0x246A2, 0x246BE}, -- Palette #13
	{0x286A2, 0x286BE}, -- Palette #14
	{0x2C6A2, 0x2C6BE}, -- Palette #15
	{0x246C2, 0x246DE}, -- Palette #16
	{0x286C2, 0x286DE}, -- Palette #17
}

-- The following palettes are missing the final
-- palette bank. I don't know why. But my code doesn't
-- break because of it, so it's not a high priority to
-- find out. But you better believe it's going to bug me
-- until I do.
spyroSkin.palettes_laughing = {
	{0x94582, 0x9459E},
	{0x98582, 0x9859E},
	{0x9C582, 0x9C59E},
	{0xA0582, 0xA059E},
	{0xA4582, 0xA459E},
	{0xA8582, 0xA859E},
	{0xAC582, 0xAC59E},
	{0x805A2, 0x805BE},
	{0x845A2, 0x845BE},
	{0x885A2, 0x885BE},
	{0x8C5A2, 0x8C5BE},
	{0x905A2, 0x905BE},
	{0x945A2, 0x945BE},
	{0x985A2, 0x985BE},
	{0x9C5A2, 0x9C5BE},
	{0xA05A2, 0xA05BE},
}

spyroSkin.palettes_laughing_PAL = {
	{0x94582, 0x9459E}, -- Palette #1
	{0x98582, 0x9859E}, -- Palette #2
	{0x9C582, 0x9C59E}, -- Palette #3
	{0xA0582, 0xA059E}, -- Palette #4
	{0xA4582, 0xA459E}, -- Palette #5
	{0xA8582, 0xA859E}, -- Palette #6
	{0xAC582, 0xAC59E}, -- Palette #7
	{0xB0582, 0xB059E}, -- Palette #8
	{0xB4582, 0xB459E}, -- Palette #9
	{0xB8582, 0xB859E}, -- Palette #10
	{0xBC582, 0xBC59E}, -- Palette #11
	{0x805A2, 0x805BE}, -- Palette #12
	{0x845A2, 0x845BE}, -- Palette #13
	{0x885A2, 0x885BE}, -- Palette #14
	{0x8C5A2, 0x8C5BE}, -- Palette #15
	{0x905A2, 0x905BE}, -- Palette #16
}

spyroSkin.palettes_toast = {
	{0x40642, 0x4065E},
	{0x40662, 0x4067E},
	{0x40682, 0x4069E},
	{0x406A2, 0x406BE},
	{0x406C2, 0x406DE},
	{0x406E2, 0x406FE},
	{0x40702, 0x4071E},
	{0x40722, 0x4073E},
	{0x40742, 0x4075E},
	{0x40762, 0x4077E},
	{0x945E2, 0x945FE},
	{0x40782, 0x4079E},
	{0x407A2, 0x407BE},
	{0x407C2, 0x407DE},
	{0x407E2, 0x407FE},
	{0x44602, 0x4461E},

}

spyroSkin.palettes_toast_PAL = {
	{0x40642, 0x4065E}, -- Palette #1
	{0x40662, 0x4067E}, -- Palette #2
	{0x40682, 0x4069E}, -- Palette #3
	{0x406A2, 0x406BE}, -- Palette #4
	{0x406C2, 0x406DE}, -- Palette #5
	{0x406E2, 0x406FE}, -- Palette #6
	{0x40702, 0x4071E}, -- Palette #7
	{0x40722, 0x4073E}, -- Palette #8
	{0x40742, 0x4075E}, -- Palette #9
	{0x40762, 0x4077E}, -- Palette #10
	{0x945E2, 0x945FE}, -- Palette #11
	{0x40782, 0x4079E}, -- Palette #12
	{0x407A2, 0x407BE}, -- Palette #13
	{0x407C2, 0x407DE}, -- Palette #14
	{0x407E2, 0x407FE}, -- Palette #15
	{0x44602, 0x4461E}, -- Palette #16
}

spyroSkin.palettes_whatsAMinion = {
	{0xE4782, 0xE479E},
	{0xE0722, 0xE073E},
	{0xE47A2, 0xE47BE},
	{0xE47C2, 0xE47DE},
	{0xE47E2, 0xE47FE},
	{0xE8602, 0xE861E},
	{0xE8622, 0xE863E},
	{0xE8642, 0xE865E},
	{0xE8662, 0xE867E},
	{0xE0702, 0xE071E},
	{0xE07C2, 0xE07DE},
	{0xE8682, 0xE869E},
	{0xE86A2, 0xE86BE},
	{0xE86C2, 0xE86DE},
	{0xE86E2, 0xE86FE},
	{0xE8702, 0xE871E},
}

spyroSkin.palettes_whatsAMinion_PAL = {
	{0xE4782, 0xE479E}, -- Palette #1
	{0xE0722, 0xE073E}, -- Palette #2
	{0xE47A2, 0xE47BE}, -- Palette #3
	{0xE47C2, 0xE47DE}, -- Palette #4
	{0xE47E2, 0xE47FE}, -- Palette #5
	{0xE8602, 0xE861E}, -- Palette #6
	{0xE8622, 0xE863E}, -- Palette #7
	{0xE8642, 0xE865E}, -- Palette #8
	{0xE8662, 0xE867E}, -- Palette #9
	{0xE0702, 0xE071E}, -- Palette #10
	{0xE07C2, 0xE07DE}, -- Palette #11
	{0xE8682, 0xE869E}, -- Palette #12
	{0xE86A2, 0xE86BE}, -- Palette #13
	{0xE86C2, 0xE86DE}, -- Palette #14
	{0xE86E2, 0xE86FE}, -- Palette #15
	{0xE8702, 0xE871E}, -- Palette #16
}

if displayType == "PAL" then
	spyroSkin.palettes_main = spyroSkin.palettes_main_PAL
	spyroSkin.palettes_title = spyroSkin.palettes_title_PAL
	spyroSkin.palettes_iveGotSomeThingsToDo = spyroSkin.palettes_iveGotSomeThingsToDo_PAL
	spyroSkin.palettes_laughing = spyroSkin.palettes_laughing_PAL
	spyroSkin.palettes_toast = spyroSkin.palettes_toast_PAL
	spyroSkin.palettes_whatsAMinion = spyroSkin.palettes_whatsAMinion_PAL
end

--The palette data for Spyro's original skin.
spyroSkin.originalPalette = {
	[1] = 13545,
	[2] = 13578,
	[3] = 13546,
	[4] = 12489,
	[5] = 13577,
	[6] = 12521,
	[7] = 14602,
	[8] = 12488,
	[9] = 14570,
	[10] = 14603,
	[11] = 13513,
	[12] = 0,
	[13] = 0,
	[14] = 0,
	[15] = 0,
	[16] = 21010,
	[17] = 32767,
	[18] = 12488,
	[19] = 1024,
	[20] = 14635,
	[21] = 26360,
	[22] = 17806,
	[23] = 13546,
	[24] = 29596,
	[25] = 22132,
	[26] = 13545,
	[27] = 1057,
	[28] = 7399,
	[29] = 11627,
	[30] = 13578,
	[31] = 14867,
	[32] = 14602,
	[33] = 14012,
	[34] = 22097,
	[35] = 12889,
	[36] = 18862,
	[37] = 15133,
	[38] = 23219,
	[39] = 13545,
	[40] = 13910,
	[41] = 16748,
	[42] = 21008,
	[43] = 14009,
	[44] = 12923,
	[45] = 11800,
	[46] = 5556,
	[47] = 5524,
	[48] = 5523,
	[49] = 4533,
	[50] = 5555,
	[51] = 6547,
	[52] = 4532,
	[53] = 4501,
	[54] = 6548,
	[55] = 4500,
	[56] = 6580,
	[57] = 6579,
	[58] = 7571,
	[59] = 4531,
	[60] = 5557,
	[61] = 5326,
	[62] = 8465,
	[63] = 4235,
	[64] = 4467,
	[65] = 7408,
	[66] = 4401,
	[67] = 5293,
	[68] = 6351,
	[69] = 4234,
	[70] = 8464,
	[71] = 4236,
	[72] = 4368,
	[73] = 4500,
	[74] = 5292,
	[75] = 4434,
	[76] = 13545,
	[77] = 16748,
	[78] = 11464,
	[79] = 13578,
	[80] = 18861,
	[81] = 9383,
	[82] = 13577,
	[83] = 15691,
	[84] = 12521,
	[85] = 11496,
	[86] = 13546,
	[87] = 14634,
	[88] = 19918,
	[89] = 10439,
	[90] = 14635,
	[91] = 15691,
	[92] = 13578,
	[93] = 17804,
	[94] = 13545,
	[95] = 17836,
	[96] = 16748,
	[97] = 15659,
	[98] = 16747,
	[99] = 13546,
	[100] = 14634,
	[101] = 17868,
	[102] = 14602,
	[103] = 14635,
	[104] = 16780,
	[105] = 18861,
	[106] = 5293,
	[107] = 7408,
	[108] = 4234,
	[109] = 4434,
	[110] = 6350,
	[111] = 3177,
	[112] = 4235,
	[113] = 4532,
	[114] = 8464,
	[115] = 6351,
	[116] = 4236,
	[117] = 4401,
	[118] = 3176,
	[119] = 7407,
	[120] = 5292,
	[121] = 16749,
	[122] = 20083,
	[123] = 13545,
	[124] = 12952,
	[125] = 19984,
	[126] = 13578,
	[127] = 13843,
	[128] = 23186,
	[129] = 18862,
	[130] = 14074,
	[131] = 25300,
	[132] = 22097,
	[133] = 14933,
	[134] = 15659,
	[135] = 13546,
	[136] = 12955,
	[137] = 10743,
	[138] = 14078,
	[139] = 11833,
	[140] = 9652,
	[141] = 14013,
	[142] = 15165,
	[143] = 12890,
	[144] = 10808,
	[145] = 12956,
	[146] = 8562,
	[147] = 10742,
	[148] = 13020,
	[149] = 11930,
	[150] = 15134,
	[151] = 7536,
	[152] = 8627,
	[153] = 7501,
	[154] = 7570,
	[155] = 6443,
	[156] = 7502,
	[157] = 7569,
	[158] = 7535,
	[159] = 7537,
	[160] = 8659,
	[161] = 7571,
	[162] = 7568,
	[163] = 7503,
	[164] = 8562,
	[165] = 6476,
	[166] = 16748,
	[167] = 25365,
	[168] = 12521,
	[169] = 21039,
	[170] = 25400,
	[171] = 14602,
	[172] = 11464,
	[173] = 24241,
	[174] = 19918,
	[175] = 10407,
	[176] = 15659,
	[177] = 25332,
	[178] = 17805,
	[179] = 13577,
	[180] = 23152,
	[181] = 14999,
	[182] = 20015,
	[183] = 13019,
	[184] = 10741,
	[185] = 21107,
	[186] = 11865,
	[187] = 14108,
	[188] = 17900,
	[189] = 10674,
	[190] = 11930,
	[191] = 10807,
	[192] = 21104,
	[193] = 19093,
	[194] = 13020,
	[195] = 18136,
	[196] = 5721,
	[197] = 2452,
	[198] = 7868,
	[199] = 2551,
	[200] = 3410,
	[201] = 4730,
	[202] = 8924,
	[203] = 7835,
	[204] = 3510,
	[205] = 2617,
	[206] = 3411,
	[207] = 3674,
	[208] = 8891,
	[209] = 5821,
	[210] = 2584,
	[211] = 7467,
	[212] = 6514,
	[213] = 12521,
	[214] = 8660,
	[215] = 5455,
	[216] = 9383,
	[217] = 13578,
	[218] = 11464,
	[219] = 6480,
	[220] = 5390,
	[221] = 9718,
	[222] = 7603,
	[223] = 8326,
	[224] = 6513,
	[225] = 15659,
	[226] = 30588,
	[227] = 19951,
	[228] = 32767,
	[229] = 24245,
	[230] = 18830,
	[231] = 22066,
	[232] = 26426,
	[233] = 31710,
	[234] = 24310,
	[235] = 30621,
	[236] = 25272,
	[237] = 16817,
	[238] = 25400,
	[239] = 21009,
	[240] = 22099,
	[241] = 15857,
	[242] = 13578,
	[243] = 12987,
	[244] = 22162,
	[245] = 15133,
	[246] = 12856,
	[247] = 18862,
	[248] = 21040,
	[249] = 13545,
	[250] = 14933,
	[251] = 16716,
	[252] = 25300,
	[253] = 12891,
	[254] = 14013,
	[255] = 16023,
}

function spyroSkin.applyPalette(palette, paletteLocations)
	if paletteLocations == nil then
		if gameState ~= 13 or loadingState ~= 10 then
			paletteLocations = spyroSkin.palettes_main
		else
			paletteLocations = spyroSkin.palettes_title
		end
	end

	if palette == nil then palette = spyroSkin.originalPalette end
	if #palette == 0 then return end
	
	local i = 1
	
	for trash,v in ipairs(paletteLocations) do
		for address=v[1],v[2],2 do
			memory.write_u16_le(address, palette[i], "GPURAM")
			i = i + 1
		end
	end
end

-- Call applyPalette, but only if Spyro's original palette
-- data is found at the target location.
function spyroSkin.tryReplacePalette(palette, paletteLocations)
	if paletteLocations == nil then
		if gameState ~= 13 or loadingState ~= 10 then
			paletteLocations = spyroSkin.palettes_main
		else
			paletteLocations = spyroSkin.palettes_title
		end
	end
	--print("ping " .. tostring(memory.read_u16_le(paletteLocations[1][1])) .. " " .. tostring(spyroSkin.originalPalette[1]))
	if memory.read_u16_le(paletteLocations[1][1], "GPURAM") == spyroSkin.originalPalette[1] and
		memory.read_u16_le(paletteLocations[1][1] + 2, "GPURAM") == spyroSkin.originalPalette[2] and
		memory.read_u16_le(paletteLocations[1][1] + 4, "GPURAM") == spyroSkin.originalPalette[3] then
		--print("pong")
		spyroSkin.applyPalette(palette, paletteLocations)
	end
end

function spyroSkin.loadPalette(file)
	
	if file == nil or file == "none" then return nil end
	
	local p = {}--newPalette
	
	local f = assert(io.open(file, "r"))
	
	--The first line should be "P3", indicating ppm format with ASCII data
	if not string.starts(f:read(), "P3") then
		showError("Error loading palette data from file: " .. file .. " - Unknown format")
		return nil
	end
	
	-- Next, we expect the size of the image, but there
	-- will often be commented lines beginning with a "#",
	-- which need to be skipped 15 17
	local size = f:read()
	while string.sub(size, 1, 1) == "#" do
		size = f:read()
	end
	if size ~= "15 17" then
		showError("Error loading palette data from file: " .. file .. " - Unexpected size")
		return nil
	end
	
	--Next, we expect the maximum value of a color, probably 255
	local whiteValue = f:read()
	
	while true do
		local line = f:read()
		if line == nil then break end
		table.insert(p,
			spyroSkin.makeColor({
				math.floor(tonumber(line)*31/whiteValue),
				math.floor(tonumber(f:read())*31/whiteValue),
				math.floor(tonumber(f:read())*31/whiteValue)
			})
		)
    end
	f:close()
	
	return p
end

function tryToLoadSkinFromFile()
	if currentPalette_name == nil or currentPalette_name == "" or currentPalette_name == "Original" then
		currentPalette = nil
		spyroSkin.applyPalette()
		return
	end
	
	local f = "Spyro Palettes\\" .. currentPalette_name .. ".ppm"
	if file.exists(f) then
		currentPalette = spyroSkin.loadPalette(f)
		spyroSkin.applyPalette(currentPalette)
	else
		currentPalette_name = nil
	end
end

function spyroSkin.makeColor(RGB)
	--turns a {31, 31, 31} value into a 2 byte word
	return RGB[1] + RGB[2] * 0x20 + RGB[3] * 0x400 + 0x8000
end

-------------------------
-- Misc
-------------------------

function getCurrentSegment()
	o = {}
	o[1] = currentSegment[1]
	o[2] = currentSegment[2]
	o[3] = currentSegment[3]
	return o
end

function segmentToString(segmentTable)
	if type(segmentTable) == "string" then return segmentTable end
	if (segmentTable or {}) == {} then return "" end
	return segmentTable[1] .. " " .. tostring(segmentTable[2]) .. " " .. segmentTable[3]
end

function segmentFromString(segmentString)
	if type(segmentString) == "table" then return segmentString end
	if (segmentString or "") == "" then return {} end
	local c = string.split(segmentString, " ")
	c[2] = tonumber(c[2])
	return c
end

function updateRecordingData(index, value)
	rec_data[index][1][2] = rec_data[index][1][1]
	rec_data[index][1][1] = value
	
	rec_data[index][2][2] = rec_data[index][2][1]
	rec_data[index][2][1] = rec_data[index][1][1] - rec_data[index][1][2]
	
	if index == 4 then
		--check for direction and stop it from hitting tau(6.2) when crossing the +x axis
		if rec_data[index][2][1] > _pi then rec_data[index][2][1] = rec_data[index][2][1] - _tau end
		if rec_data[index][2][1] < -_pi then rec_data[index][2][1] = rec_data[index][2][1] + _tau end
	end
	
	rec_data[index][3][2] = rec_data[index][3][1]
	rec_data[index][3][1] = rec_data[index][2][1] - rec_data[index][2][2]
	
	rec_data[index][4] = rec_data[index][3][1] - rec_data[index][3][2]
end

function rollValue(value, maxValue)
	value = value + 1
	if value > maxValue then value = 0 end
	return value
end

function onOff(value)
	if value then return "On" end
	return "Off"
end

function alwaysOnOff(value)
	if value == 2 then return "Always"
	elseif value == 1 then return "On"
	end
	return "Off"
end

function offRawSmooth(value)
	if value == 1 then return "Raw"
	elseif value == 2 then return "Smooth"
	end
	return "Off"
end

function menu_populateSegments()
	warpMenu_segments = {}
	warpMenu_availability = {}
	
	for s in pairs(getGlobalVariable({"savestateData", "segment", currentRoute}) or {}) do
		--s = "Level 11 Entry"
		local _s = segmentFromString(s)
		warpMenu_segments[_s[2] .. _s[3] ] = true
		warpMenu_availability[tostring(_s[2])] = true
		warpMenu_availability[tostring(tonumber(_s[2]) - (tonumber(_s[2]) % 10))] = true
	end
	
	--[[
	for r, r_table in pairs(getGlobalVariable({"savestateData", "segment"}) or {}) do
		--r = "120"
		for s in pairs(r_table) do
			--s = "Level 11 Entry"
			local _s = segmentFromString(s)
			warpMenu_segments[_s[2] .. _s[3] ] = true
			warpMenu_availability[tostring(_s[2])] = true
			warpMenu_availability[tostring(tonumber(_s[2]) - (tonumber(_s[2]) % 10))] = true
		end
	end
	--]]
end

function ordinal(n)
	if n % 10 == 1 then return tostring(n) .. "st" end
	if n % 10 == 2 then return tostring(n) .. "nd" end
	if n % 10 == 3 then return tostring(n) .. "rd" end
	return tostring(n) .. "th"
end

-------------------------
-- Events
-------------------------

function onLoadSavestate()
	rebuildAllGhosts = true
	
	requestedState = nil
	os.remove(file.combinePath("data", "requestedState.txt"))

	if not saveStateRequested then
		tryRunGlobalFunction("clearAllRecordingData")
	else
		-- Randomize the pRNG iterator
		memory.write_u16_le(0x075AC0 + m[5], math.random(0x10000))
		memory.write_u16_le(0x075AC2 + m[5], math.random(0x10000))
	
		if recordingMode == "segment" or recordingMode == "run" then
			for i, ghost in ipairs(segment_ghosts) do
				if Ghost.isGhost(ghost) then
					ghost:endPlayback()
				end
			end
			for i, ghost in ipairs(run_ghosts) do
				if Ghost.isGhost(ghost) then
					ghost:endPlayback()
				end
			end
			
			local category = currentRoute
			local segment = getSegmentHandle()
			if segment_settings[category] ~= nil and segment_settings[category][segment] ~= nil then
				local health = segment_settings[category][segment].health or -1
				if health > -1 then
					memory.write_u32_le(0x078BBC + m[4], health)
					memory.write_u32_le(0x07580C + m[3], health)
				end
				local lives = segment_settings[category][segment].lives or -1
				if lives > -1 then memory.write_u32_le(0x07582C + m[3], lives) end
			end
		end
	end
	saveStateRequested = false
	inHomeScreen = false
	if musicVolume ~= nil then memory.write_u32_le(0x075748 + m[2], musicVolume) end
	spyroSkin.applyPalette(currentPalette, spyroSkin.palettes_main)
end

-------------------------
-- Startup
-------------------------

do
	
	math.randomseed(os.time())
	
	event.unregisterbyname("onLoadSavestate")
	event.onloadstate(onLoadSavestate, "onLoadSavestate")

	currentLevel = memory.read_u32_le(0x07596C + m[5])
	lastLevel = currentLevel - (currentLevel % 10)
	currentSegment = {"Level", currentLevel, "Entry"}
	if currentLevel % 10 == 0 then
		lastLevel = lastLevel - 10
		currentSegment = {"World", currentLevel, "Entry"}
	end
	
	processActionData()
	
	settings_load()
	
	controls_verify()
	
	tryToLoadSkinFromFile()
	
	populateFileList()
	segment_loadAllCollectionSettings()
	
	menu_showInputs = framerate / 2 * 30
	requireMainMenuAction()
	
	print("\n\n\nWelcome to LuaGhost for Spyro the Dragon!\n")
	
	print("LuaGhost version: " .. _LuaGhostVersion)
	print("BizHawk version: " .. client.getversion() .. " (" .. _VERSION .. ")")
	print("Game version: " .. gameinfo.getromname() .. "\n")
	
	print("This window likes to pull focus away from the game window when reading and writing files. Minimizing this window should stop it doing that.\n\nIf LuaGhost ever crashes while loading a savestate, you'll need to close and reopen this window before LuaGhost will work again. Just refreshing or toggling the script might not work.\n")

	local menuInput = getInputForAction("openMenu")
	if menuInput ~= "" then
		print("Open LuaGhost's in-game menu with: " .. menuInput .. "\n")
	end

	--For first-time users. Prompt them to enter a name.
	if playerName == defaultPlayerName then
		menu_open("keyboard input", playerNameMenuOptions)
	end
	
	-- requestedState is set to the filename of a savestate
	-- before attempting to load that state. This name is
	-- also written to data\requestedState.txt. Both
	-- requestedState and the file are erased by
	-- onLoadSavestate(). If the file exists during this
	-- startup routine, then the script must have crashed
	-- during the load, meaning the savestate file might be
	-- corrupt. If requestedState is defined here, then the
	-- user has not restarted the lua console since the
	-- crash occurred. When crashes happen on savestate
	-- loads, it leaves the lua console in a corrupted
	-- state that may crash on loading ANY savestate (even
	-- ones that should work fine) or may be entirely
	-- unresponsive. It will only be fixed when the user closes
	-- and restarts the console. Here, we should prompt the
	-- user to delete the corrupted file and restart the
	-- console if needed.
	local restartRequired = false
	if requestedState then
		restartRequired = true
	end
	if file.exists(file.combinePath("data", "requestedState.txt")) then
		local f = assert(io.open(file.combinePath("data", "requestedState.txt"), "r"))
		requestedState = f:read()
		f:close()
		os.remove(file.combinePath("data", "requestedState.txt"))
	end
	if requestedState then
		gui.drawText(28, 15, "Error: See the lua console for details.", "white", "black")
		print("\n\n\nNOTICE\nIt looks like LuaGhost crashed while loading the following savestate:\n\n" .. requestedState .. "\n\nThis can happen if specific emulator settings have changed since the savestate was created. You'll either need to delete the savestate file to let LuaGhosts recreate it with your new settings or revert any recent changes you've made to emulator settings. The settings that can cause this problem are the ones in \"PSX\" -> \"Controller / Memcard Configuration\".\n\n")
		if restartRequired then
			print("\nYou'll also need to close and reopen this window before LuaGhost will run.")
		else
			requestedState = nil
		end
		
		-- Close the script
		return
	end
end

-------------------------
-- Main Loop
-------------------------

while true do

	-- Determine whether to update the script on this frame.
	-- Memory value 0x075760 counts how many frames (at 60
	-- fps) the current image has been displayed for. The
	-- value is 0 on the frame a new image is ready to be
	-- displayed and the value typically alternates between
	-- 0 and 1 as long as there is no lag. Odd numbers of
	-- lag frames are possible because the game makes no
	-- effort to ensure images are rendered on a consistent
	-- parity (odd or even frames). This means that although
	-- the game typically updates physics and renders new
	-- frames every 30th of a second, it is possible to lose
	-- time to lag in 60th of a second intervals.
	if memory.read_u32_le(0x075760 + m[2]) % 2 == 0 then
		
		-- Bizhawk automatically clears old gui graphics on
		-- any frame when new graphics are being drawn (the
		-- gui system is used for rendering the ghosts as
		-- well as menus and any custom hud elements).
		-- However, if none of the objects we're drawing
		-- are currently visible on the screen, outdated
		-- graphics may remain visible until we have
		-- something else to draw.
		-- Calling gui.clearGraphics() forces old graphics
		-- to be removed.
		gui.clearGraphics()
		
		-- Update and handle user inputs
		inputs:update()
		handleUserInput()
		
		-- Get fresh data from the game for this frame
		getWorldValues()
		getSpyroValues()
		getCameraValues()
		
		-- Detect events as Spyro moves around the world
		detectSegmentEvents()
		
		-- Handle props (extra content drawn into the game world)
		drawProps()
		
		-- Update gems faster
		if quickUpdatingGems then
			local gemCountAddress = ((((((currentLevel - (currentLevel % 10)) / 10) - 1) * 6) + (currentLevel % 10)) * 4) + 0x077420 + m[4]
			memory.write_u32_le(0x077FC8 + m[4], math.max(memory.read_u32_le(0x077FC8 + m[4]), memory.read_u32_le(gemCountAddress) - 1))
		end
		
		--Handle Spyro Palettes
		if loadingState == 6 and lastLoadingState ~= 6 then
			-- Spyro's palette data gets overwritten during
			-- every level load. It happens exactly as the
			-- loading state switches to 6, so it's easy to
			-- test for.
			spyroSkin.applyPalette(currentPalette)
			
			-- For the remaining checks, Spyro's palettes
			-- could be located in multiple locations and I
			-- don't have a good way of knowing which to
			-- expect. So I'm using tryReplacePalette every
			-- frame, which will check if Spyro's default
			-- palette has been loaded into one of the
			-- possible locations and overwrite it
			-- when needed.
		elseif gameState == 13 then
			-- gameState 13 is the title menu.
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_title)
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_main)
		elseif gameState == 14 then
			-- gameState 14 is all of the cutscenes
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_main)
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_iveGotSomeThingsToDo) -- intro cutscene
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_toast) -- post gnasty gnorc
			spyroSkin.tryReplacePalette(currentPalette, spyroSkin.palettes_whatsAMinion) -- post gnasty's loot
		elseif currentLevel == 63 and spyroControl > 0 and lastSpyroControl == 0 then
			-- Level 63 is Gnasty Gnorc. When Spyro kills
			-- the boss, he is turned invisible and
			-- replaced with a separate object that turns
			-- and laughs at Gnasty Gnorc. We only need to
			-- perform this check while player control is
			-- disabled (spyroControl > 0).
			spyroSkin.applyPalette(currentPalette, spyroSkin.palettes_laughing)
		end
		
		-- Handle recording		
		Ghost.update(manual_recording)
		
		Ghost.update(segment_recording)
		Ghost.update(run_recording)
		
		if segment_dragonSplitThisFrame then
			local splitNumber = #((segment_recording or {}).dragonSplits or {})
			for i, ghost in ipairs(segment_ghosts) do
				local seekFrame = ghost.dragonSplits[splitNumber]
				if seekFrame then
					ghost:changeSubSegmentOffset(seekFrame)
				end
			end
		end
		
		if rebuildAllGhosts then
			rebuildAllGhosts = false
			allGhosts = {}
			if manual_ghost ~= nil then table.insert(allGhosts, manual_ghost) end
			for i, ghost in ipairs(segment_ghosts) do
				table.insert(allGhosts, ghost)
			end
			for i, ghost in ipairs(run_ghosts) do
				table.insert(allGhosts, ghost)
			end
		end
		
		-- Update the locations of ghosts for this frame
		for i, ghost in ipairs(allGhosts) do
			Ghost.update(ghost)
		end
		-- Sort ghosts by distance in front of the camera
		table.sort(allGhosts, function(a, b)
			if not a.isPlaying or not a._doDraw or not b.isPlaying or not b._doDraw then return nil end
			return a._cameraRange > b._cameraRange
		end)
		-- Draw the ghosts
		for i, ghost in ipairs(allGhosts) do
			ghost:draw()
		end
		
		-- Update rankings in full run mode
		if recordingMode == "run" then
			if run_recording ~= nil then
				run_updateRankings()
			end
			-- show current rankings in full run mode
			if run_showRanking then
				local x = border_right - 20
				local y = 60
				local dy = 14--vertical spacing between lines
				run_rankingPlace = 0
				for i, v in ipairs(run_ranking) do
					if v == run_recording then run_rankingPlace = i end
					if run_showRankList and i <= 8 then
						gui.drawText(x, y, v.rankingName, "white", "black", 12, nil, nil, "right")
						y = y + dy
					end
					if run_showRankNames and v.ghostLevel == currentLevel and v._position then
						local gx, gy = worldSpaceToScreenSpace(v._position[1], v._position[2], v._position[3] + 280)
						if gx > 0 then
							gui.drawText(gx, gy, v.rankingName, v.color, nil, 12, nil, nil, "center", "bottom")
						end
					end
				end
				if run_showRankPlace and run_rankingPlace > 0 then
					gui.drawText(x, 30, ordinal(run_rankingPlace), "white", "black", 18, nil, nil, "right")
				end
			end
		end
	
		
		-- Update health as needed when loading savestates
		if (setHealth_armed or -1) > -1 and loadingState == -1 then
			memory.write_u32_le(0x078BBC + m[4], setHealth_armed)
			setHealth_armed = -1
		end
		
		-- Handle menus
		if menu_state ~= nil then
		
			menu_cursorFlash_timer = menu_cursorFlash_timer - 1
			if menu_cursorFlash_timer < 0 then menu_cursorFlash_timer = menu_cursorFlash_period end
			menu_cursorFlash = menu_cursorFlash_timer > (menu_cursorFlash_period / 2)
			
			--If the menu has a custom draw function, call it.
			--Otherwise, call the default one
			local customDrawFunction = tryGetGlobalFunction(menu_currentData.drawFunction)
			if type(customDrawFunction) == "function" then
				customDrawFunction(menu_currentData)
			else
				menu_draw()
			end
			
		else
			drawStats()
			
			if menu_showInputs > 0 then
			
				draw_inputs()
				menu_showInputs = menu_showInputs - 1
				
			else
				if menu_segmentUpdate_timer > 0 then
				
					draw_updateSegment()
					menu_segmentUpdate_timer = menu_segmentUpdate_timer - 1
				
				elseif quickDelta_timer > 0 then
				
					quickDelta_draw()
					quickDelta_timer = quickDelta_timer - 1
				end
				
				if menu_showEndOfRun then
					draw_endOfRun()
				end
			end
		end
		
		onscreenMessages_update()
	else
		
	end
	
	-- Stop changes to variants from taking effect until you leave the menu.
	if menu_state == nil then
		variant_sparxless_effective = variant_sparxless
	end
	
	-- Apply Sparxless variant
	if variant_sparxless_effective then
		memory.write_u16_le(0x078BBC + m[4], 0x00)
	end
	
	-- Stop controller inputs from reaching the game while the menu is open.
	if menu_state ~= nil then
		if not inTitleScreen or memory.read_u32_le(0x076C60 + m[4]) == 0 then
			memory.write_u32_le(0x078C48 + m[4], 1)--This disables control of Spyro. This stops Spyro from reacting to inputs if the player opens the script's menu while the game is unpaused.
			memory.write_u16_le(0x077380 + m[4], 0xF9F0)--as far as I can tell, this is telling the game that all the buttons were held down in the previous frame, preventing any button press events triggering. This prevents the player's inputs from reaching the game's menu if the game is paused while the script's menu is open.
		end
	end
	
	-- Unload any ghosts (from loadedGhostCache) that are no longer being used
	if cleanCachedGhosts and not segment_preloadAllGhosts then
		cleanCachedGhosts = false
		for k, v in pairs(loadedGhostCache) do
			if not segment_ghostsSet[k] and not run_ghostsSet[k] then
				loadedGhostCache[k] = nil
			end
		end
	end
	
	-- Return control to the emulator to render the next frame.
	emu.frameadvance();
end