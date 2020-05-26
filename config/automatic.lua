--[[
*	Configuration for <scheduler.lua> script.
*
*   Provides a time table to schedule actions.
*
*   The actions' implementation is left to the user.
]]

-- ----------------------------------------------------------------------------

local trace = require("lib.trace")

-- ----------------------------------------------------------------------------
-- here we attach to the same tracing object of the scheduler
--
local m_trace = trace.new("schedule")

-- ----------------------------------------------------------------------------
-- execute the command line
--
local function DownloadFavorites()
	m_trace:line("DownloadFavorites")
	
	local hFile, sError = io.popen("lua ./download.lua --favorites", "r")
	
	if sError and 0 < #sError then
		
		m_trace:line("On DownloadFavorites got an error: " .. sError)
		
		return sError
	end
	
	hFile:read("a")
	hFile:close()
	
	return nil
end

-- ----------------------------------------------------------------------------
-- execute the command line
--
local function ArchiveFavorites()
	m_trace:line("ArchiveFavorites")
	
	local hFile, sError = io.popen("lua ./archive.lua", "r")
	
	if sError and 0 < #sError then
		
		m_trace:line("On ArchiveFavorites got an error: " .. sError)
		
		return sError
	end
	
	hFile:read("a")
	hFile:close()	
	
	return nil
end

-- ----------------------------------------------------------------------------
-- execute the command line
--
local function OnSchedule()
	m_trace:line("OnSchedule")
	
	DownloadFavorites()
	ArchiveFavorites()
	
	return nil
end

-- ----------------------------------------------------------------------------
--
local tConfiguration = 
{
	sCfgVersion	= "0.0.1",
	
	bAutoReload	= false,	-- reload this file at each execution cycle	
	iTimeWindow	= 120,		-- valid time frame in seconds
	tTimesAt	=
	{
		{ "06:00:00", OnSchedule },
		{ "06:30:00", OnSchedule },
		{ "06:49:00", OnSchedule },
		{ "07:10:00", OnSchedule },
		{ "8:18:00",  OnSchedule },
		{ "10:35:00", OnSchedule },
		{ "12:24:00", OnSchedule },
		{ "14:57:00", OnSchedule },
		{ "16:00:30", OnSchedule },
		{ "17:47:00", OnSchedule },
		{ "21:20:00", OnSchedule },
		{ "21:42:15", OnSchedule },
		{ "22:00:00", OnSchedule },
		{ "23:45:00", OnSchedule },
	},
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

