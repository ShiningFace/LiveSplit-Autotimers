//This is version 3
//By ShiningFace, Jelly, IDGeek

state("sonic2app")
{
	bool timerEnd         : 0x0134AFDA;
	bool runStart         : 0x0134AFFA;
	bool controlActive    : 0x0134AFFE;
	bool levelEnd         : 0x0134B002;
	bool inCutscene       : 0x015420F8;
	bool nowLoading       : 0x016557E4;
	bool inAMV            : 0x016EDE28;
	bool inEmblem         : 0x01919BE0;
	
	byte bossRush         : 0x00877DC4;
	byte timestop         : 0x0134AFF7;
	byte stageID          : 0x01534B70;
	byte menuMode         : 0x01534BE0;
	byte timesRestarted   : 0x01534BE8;
	byte saveChao         : 0x015F645C;
	byte chaoID           : 0x0165A2CC;
	byte textCutscene     : 0x016EFD44;
	byte raceChao         : 0x019D2784;
	byte twoplayerMenu    : 0x0191B88C;
	byte mainMenu1        : 0x0191BD2C;
	byte mainMenu2        : 0x0197BAE0;
	byte stageSelect      : 0x0191BEAC;
	byte storyRecap       : 0x0191C1AC;
	byte pauseCutscene    : 0x019CFF00;
	byte gameplayPause    : 0x021F0014;

	short currEmblems     : 0x01536296;
	short currEvent       : 0x01628AF4;
	//Get minutes, seconds, and centiseconds all in one read
	int levelTimer        : 0x015457F8;
	int levelTimerClone   : 0x0134AFDB;
	
	int frameCount        : 0x0134B038;

	float bossHealth      : 0x019E9604, 0x48;
	
	int currMenu          : 0x0197BB10;
	int currMenuState     : 0x0197BB14;
}

init
{
	if ((settings["timerPopup"]) && timer.CurrentTimingMethod == TimingMethod.RealTime)
	{        
    	var timingMessage = MessageBox.Show
		(
       		"This game uses Game Time (IGT) as the main timing method.\n"+
    		"LiveSplit is currently set to display Real Time (RTA).\n"+
    		"Would you like to set the timing method to Game Time?",
       	 	"Sonic Adventure 2: Battle | LiveSplit",
       		MessageBoxButtons.YesNo,MessageBoxIcon.Question
       	);
		
        if (timingMessage == DialogResult.Yes) 
		{
			timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
	}
}

startup
{
	refreshRate = 120;
	//Variables
	vars.totalTime = 0;      //Time accumulated from level timer, in centiseconds
	vars.timestopFrames = 0; //How many additional frames we added due to timestop
	vars.lastGoodTimerVal = Int32.MaxValue;
	vars.splitDelay = 0;
	//Settings
	settings.Add("timerPopup", false, "Ask to switch to IGT on startup.");
	settings.Add("storyStart", false, "Only start timer when starting a story.");
	settings.Add("stageExit", false, "Restart timer upon manually exiting a stage in stage select.");
	settings.Add("resetIL", false, "Restart timer upon restart/death for ILs.");
	settings.Add("cannonsCore", false, "Only split in Cannon's Core when a mission is completed.");
	settings.Add("bossRush", false, "Only split in Boss Rush when defeating the last boss of a story.");
	settings.Add("chaoRace", false, "Split when exiting a Chao Race.");
	settings.Add("emblemTiming", false, "Include timing for emblem cutscenes outside of 180/171 emblems.");
}

update
{
	//Counts emblem cutscene if a specified category
	if ((settings["emblemTiming"]) && current.inEmblem)
	{
		if (!current.nowLoading)
		{
			vars.countFrames = true;
		}
		else vars.countFrames = false;
	}
	//Cannons Core
	else if (current.stageID == 34 || current.stageID == 35 || current.stageID == 36 || current.stageID == 37 || current.stageID == 38)
	{
		if (current.timestop == 2) //Count time by frames on timestop
		{
			vars.countFrames = true;
		}
		else
		{
			vars.countFrames = false; //Not timestop? - don't count frames
		}

		if (current.menuMode == 17) //Don't count frames when pause menu open
		{
			vars.countFrames = false;
		}

		if (current.timerEnd) //Pause timer when dying/restarting/finishing level while timestop is active
		{
			vars.countFrames = false;
		}
	}
	//Don't count time by frames anywhere else but cannons core
	else
	{
		vars.countFrames = false;
	}
	
	if (vars.countFrames)
	{
		int diff = current.frameCount - old.frameCount;
		vars.timestopFrames = vars.timestopFrames+diff;
	}
	//Ensure we have accurate readings of the IGT
	if ((current.levelTimer & 0xFFFFFF) == (current.levelTimerClone & 0xFFFFFF))
	{
		int currMinutes =    (current.levelTimer >> 0)  & 0xFF;
		int currSeconds =    (current.levelTimer >> 8)  & 0xFF;
		int currCentis  =    (current.levelTimer >> 16) & 0xFF;

		int oldMinutes  = (vars.lastGoodTimerVal >> 0)  & 0xFF;
		int oldSeconds  = (vars.lastGoodTimerVal >> 8)  & 0xFF;
		int oldCentis   = (vars.lastGoodTimerVal >> 16) & 0xFF;

		currCentis = (int)Math.Ceiling(currCentis*(5.0/3.0));
		oldCentis  =  (int)Math.Ceiling(oldCentis*(5.0/3.0));
		//In game timer converted to centiseconds
		int inGameTime  = (currMinutes*6000) + (currSeconds*100) + (currCentis);
		int oldGameTime =  (oldMinutes*6000) +  (oldSeconds*100) +  (oldCentis);
		//Only add positive time
		int timeToAdd = Math.Max(0, inGameTime-oldGameTime);
		//Don't add time when the timer goes beserk in loading screens
		if (current.controlActive)
		{
			vars.totalTime += timeToAdd;
		}

		vars.lastGoodTimerVal = current.levelTimer;
	}
	//Splitting
	vars.splitDelay = Math.Max(0, vars.splitDelay-1);
	//Boss rush
	if ((settings["bossRush"]) && current.bossRush == 1 && current.stageID != 66 && current.stageID != 42)
	{
		vars.splitDelay = 0;
	}
	//Final boss
	else if ((timer.Run.CategoryName == "Hero Story" || timer.Run.CategoryName == "Dark Story") && current.stageID == 42)
	{
		if (current.bossHealth == 0 && current.timerEnd && !old.timerEnd)
		{
			vars.splitDelay = 1;
		}
	}
	else if ((timer.Run.CategoryName == "Last Story" || timer.Run.CategoryName == "All Stories") && current.stageID == 66)
	{
		if (current.levelEnd && !old.levelEnd)
		{
			vars.splitDelay = 1;
		}
	}
	//Boss stages
	else if ((current.stageID == 42 || current.stageID == 33 || current.stageID == 29 || current.stageID == 20 || current.stageID == 19) && current.bossHealth == 0)
	{
		if (current.timerEnd && !old.timerEnd)
		{
			vars.splitDelay = 3;
		}
	}
	//Cannon's Core
	else if ((settings["cannonsCore"]) && (current.stageID == 38 || current.stageID == 37 || current.stageID == 36 || current.stageID == 35))
	{
		if (current.controlActive && current.levelEnd && !old.levelEnd)
		{
			vars.splitDelay = 3;
		}
	}
	//Kart stages
	else if (current.stageID == 71 || current.stageID == 70)
	{
		if (current.timerEnd && !old.timerEnd && current.controlActive && current.menuMode != 12)
		{
			vars.splitDelay = 3;
		}
	}
	//Chao World
	else if (((settings["chaoRace"]) && current.stageID == 90 && current.raceChao != 1 && old.raceChao == 1) || 
	(current.stageID == 90 && current.chaoID == 1 && current.inEmblem && !old.inEmblem))
	{
		vars.splitDelay = 3;
	}
	//180 Emblems
	else if (timer.Run.CategoryName == "180 Emblems" && current.currEmblems == 180 && old.currEmblems != 180)
	{
		vars.splitDelay = 3;
	}
	//171 Emblems
	else if (timer.Run.CategoryName == "171 Emblems" && current.currEmblems == 171 && old.currEmblems != 171)
	{
		vars.splitDelay = 3;
	}
	//Normal stages
	else if (current.levelEnd && !old.levelEnd)
	{
		vars.splitDelay = 3;
	}
}

start
{
	vars.totalTime = 0;
	vars.timestopFrames = 0;
	vars.splitDelay = 0;
	vars.countFrames = false;
	//Allow Any% and 2 Player Levels to start where other categories can't
	if ((timer.Run.CategoryName != "Any%" && timer.Run.CategoryName != "2 Player Levels" && 
	current.currMenuState != 4 && current.currMenuState != 5 && current.currMenuState != 7) || 
	current.inEmblem || current.inAMV)
	{
		return false;
	}
	//Only start timer when selecting 2p mode
	else if (timer.Run.CategoryName == "Any%")
	{
		if (current.mainMenu1 != 1 && current.mainMenu2 != 1 && current.stageSelect != 1 && current.twoplayerMenu == 1 &&
		!current.nowLoading && old.nowLoading)
		{
			return true;
		}
	}
	//Only start timer when starting a story or selecting chao garden
	else if (timer.Run.CategoryName == "Chao%")
	{
		if (current.mainMenu1 != 1 && current.mainMenu2 != 1 && current.stageSelect != 1 && (current.stageID == 90 || current.currMenu == 5) && 
		current.runStart && current.nowLoading && !old.nowLoading)
		{
			return true;
		}
	}
	//2p Levels
	else if (timer.Run.CategoryName == "2 Player Levels")
	{
		if (current.currMenu == 16 && ((current.menuMode == 1 && old.menuMode != 1) || 
		(!current.nowLoading && old.nowLoading)) && current.runStart)
		{
			return true;
		}
	}
	//Normal
	else if (current.mainMenu1 != 1 && current.mainMenu2 != 1 && current.stageSelect != 1 && (!settings["storyStart"] || current.currMenu == 5) && 
	((current.menuMode == 1 && old.menuMode != 1) || (!current.nowLoading && old.nowLoading)) && current.runStart)
	{
		return true;
	}
	//Start timer upon resetting a stage
	else if (settings["resetIL"])
	{
		if (!current.levelEnd && !current.controlActive && old.controlActive && current.timerEnd)
		{
			return true;
		}
	}
}

reset
{
	//Reset if a file is created or deleted
	if ((current.currMenu == 9 || current.currMenu == 24) && (current.currMenuState == 12 || current.currMenuState == 15))
	{
		return true;
	}
	//Reset if manually exiting a stage during stage select
	else if (settings["stageExit"])
	{
		if (current.menuMode == 0 && current.stageSelect == 1 && old.stageSelect != 1 && !current.timerEnd)
		{
			return true;
		}
	}
	//Reset if leaving a stage
	else if (settings["resetIL"])
	{
		if (!current.levelEnd && !current.controlActive && old.controlActive && current.timerEnd)
		{
			return true;
		}
	}
}

split
{
	return (vars.splitDelay == 1);
}

isLoading
{
	return true;
}

gameTime
{
	return TimeSpan.FromMilliseconds(vars.timestopFrames*1000.0/60.0 + vars.totalTime*10.0);
}
