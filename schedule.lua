--[[
*	schedule.lua
*
*   Run Lua functions on a time basis.
*
*	Timer resolution is 1 second.
]]

local wx		= require("wx")
local utility	= require("lib.utility")
local trace 	= require("lib.trace")

local _date		= os.date
local _time		= os.time

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("schedule")

-- ----------------------------------------------------------------------------
--
local m_App = 
{
	-- private
	--
	sAppName 	= "schedule",
	sAppVer  	= "0.0.2",
	sRelDate 	= "2020/06/09",
	
	sConfigFile	= "config/automatic.lua",
	iCurDay		= -1,						-- launch day
	iIdleTime	= 3000,						-- idle time
	
	-- public, override in configuration file
	--
	bAutoReload	= true,		-- reload this file at each execution cycle	
	iTimeWindow	= 60,		-- valid time frame in seconds

	tTimesAt 	=			-- list of execution
	{
		{  "8:00:00" },
		{ "20:00:00" },
	},
}

-- ----------------------------------------------------------------------------
--[[ descrption of tTimesAt format at run-time

{
	{ time_description, callback, time_value } 
	...
}
 
  .1 at start each row might contain 1 or 2 fields, the textual time-out and a callback 
  .2 if no callback has been provided the program will insert a default (dummy) one
  .3 when a time-out fires then the numeric field will change to -1
  .4 everytime the time table is setup a double check will invalidate expired entries
  
]]
	
-- ----------------------------------------------------------------------------
-- fields in tTimesAt
--
local m_desc = 1
local m_call = 2
local m_time = 3

-- ----------------------------------------------------------------------------
-- show which is the next to come
--
local function TraceNextTime()
--	m_trace:line("TraceNextTime")

	local tTimesAt	= m_App.tTimesAt
	
	-- check for the first valid in list
	--
	for _, tTimed in next, tTimesAt do
		
		if (-1 ~= tTimed[m_time]) then
			
			m_trace:line("First scheduled [" .. tTimed[m_desc] .. "]")
			return
		end
	end
	
	m_trace:line("No action due until new day.")
end

-- ----------------------------------------------------------------------------
-- check if today's date has changed
--
local function DayChanged()
--	m_trace:line("DayChanged")

	local iToday	= tonumber(_date("%d", _time()))
	local bReturn	= false
	
	if iToday ~= m_App.iCurDay then
		
		-- when first time called don't return true, just set it
		--
		if -1 ~= m_App.iCurDay then bReturn = true end
		
		m_App.iCurDay = iToday
	end

	return bReturn
end

-- ----------------------------------------------------------------------------
-- check for expired entries at start time
--
local function InvalidateExpired()
--	m_trace:line("InvalidateExpired")

	local tTimesAt	= m_App.tTimesAt
	local iWindow	= m_App.iTimeWindow
	local tmNow 	= _time()
	local iDueTime	= tmNow - iWindow
	
	-- check for expired entries at start time
	--
	for _, tTimed in next, tTimesAt do
		
		if (-1 ~= tTimed[m_time]) and (iDueTime > tTimed[m_time]) then
			
			tTimed[m_time] = -1
		end
	end
end

-- ----------------------------------------------------------------------------
-- fallback function if function not provided by user
--
local function EmptyCallback()
	
	m_trace:line("Slot unallocated")
	
	return nil
end

-- ----------------------------------------------------------------------------
-- read time values as strings and transform to integer
-- mark expired entries with -1
-- correct 
--
local function SetupTimeTable()
--	m_trace:line("SetupTimeTable")

	local tTimesAt	= m_App.tTimesAt
	local sToday	= _date("%Y:%m:%d", _time())
	local sDueTime
	
	-- get the numeric value of each entry in the master table
	--
	for _, tTimed in next, tTimesAt do
		
		-- fix (somewhat senseless a timme row without action)
		--
		if m_call > #tTimed then table.insert(tTimed, m_call, EmptyCallback) end
		
		-- now is safe to add the working field
		--
		if m_time > #tTimed then table.insert(tTimed, m_time, -1) end
		
		-- here using the first field at hand, which is text
		--
		sDueTime = sToday .. " " .. tTimed[m_desc]
		
		-- set the numeric value
		--
		tTimed[m_time] = utility.StringToFullDate(sDueTime)
	end

	-- normalize table
	--
	table.sort(tTimesAt, function (a, b) return a[m_time] < b[m_time] end)
	
	-- check for expired entries at start time
	--
	InvalidateExpired()
	
	-- this is for debugging purpose
	--
	-- m_trace:table(tTimesAt)
end

-- ----------------------------------------------------------------------------
-- check if time has fired
-- table's rows must be in order
--
local function IsTimeDue()
--	m_trace:line("IsTimeDue")
	
	local tTimesAt	= m_App.tTimesAt
	local iWindow	= m_App.iTimeWindow
	local tmNow 	= _time()
	local iDiff

	for _, tTimed in next, tTimesAt do
		
		if -1 ~= tTimed[m_time] then
			
			iDiff = tmNow - tTimed[m_time]
			
			-- if within a window of x secs then fire
			--
			if 0 <= iDiff then
				
				if iWindow > iDiff then return tTimed else break end
			end
		end
	end
	
	return nil
end

-- ----------------------------------------------------------------------------
--
local function LoadConfig()
--	m_trace:line("LoadConfig")

	local sConfig	= m_App.sConfigFile
	
	-- try opening the application's associated configuration file
	--
	if not wx.wxFileName().Exists(sConfig) then return end

	m_trace:line("Loading configuration file [" .. sConfig .. "]")
	
	-- an execution abort here must be be due to a bad configuration syntax
	--
	local tOverride = dofile(sConfig)
	
	m_App.tTimesAt		= tOverride.tTimesAt
	m_App.bAutoReload	= tOverride.bAutoReload		-- reload this file at each execution cycle	
	m_App.iTimeWindow	= tOverride.iTimeWindow		-- valid time frame in seconds
end

-- ----------------------------------------------------------------------------
-- read configuration
-- when function ends the old time table will get garbage collected
--
local function RenewConfig(inTableRow)
--	m_trace:line("RenewConfig")

	LoadConfig()
	SetupTimeTable()

	-- after having performed an action
	-- mark the last executed
	--
	if inTableRow then
		
		local tTimesAt	= m_App.tTimesAt
		
		-- the numeric value can be -1 or not, use strings
		--
		for _, tTimed in next, tTimesAt do
		
			-- cleanup overlapping windows
			--
			tTimed[m_time] = -1
			
			if inTableRow[m_desc] == tTimed[m_desc] then break end
		end
	end
end

-- ----------------------------------------------------------------------------
-- store the last executed row
-- mark it as invalid
--
local function SetExecuted(inTableRow)
--	m_trace:line("SetExecuted")
	
	if not inTableRow then return end

	inTableRow[m_time] = -1
end

-- ----------------------------------------------------------------------------
-- execute the command line
--
local function Perform(inTableRow)
--	m_trace:line("Perform")
	
	local pCallbabk = inTableRow[m_call]

	if pCallbabk then
	
		if "function" == type(pCallbabk) then
			
			local anError
			
			m_trace:startwatch()
			
			anError = pcall(pCallbabk())
			
			if anError then m_trace:line("Execution error: " .. tostring(anError)) end
			
			m_trace:stopwatch("Action took")
		else
			
			m_trace:line("Execution error: not a function")
		end
		
	else
		
		m_trace:line("Nothing to execute")
	end
end

-- ----------------------------------------------------------------------------
--
local function RunApplication(...)
--	m_trace:line("RunApplication")
	
	local sAppTitle = m_App.sAppName .. " [" .. m_App.sAppVer .. "]"
	
	m_trace:time(sAppTitle .. " started")	

	assert(os.setlocale('us', 'all'))
	m_trace:line("Current locale is [" .. os.setlocale() .. "]")
	
	-- try opening the application's associated configuration file
	--
	RenewConfig()
	TraceNextTime()
	
	-- forever do
	--
	repeat
		
		local tTimed = IsTimeDue()
		
		if tTimed then
			
			m_trace:line("Time [" .. tTimed[m_desc] .. "] executing action")
			
			Perform(tTimed)			-- perform action
			SetExecuted(tTimed)		-- invalidate
			
			-- check renewal
			--
			if m_App.bAutoReload then RenewConfig(tTimed) end
			
			TraceNextTime()			-- show info
		end
		
		-- a fair delay
		--
		wx.wxMilliSleep(m_App.iIdleTime)
		
		-- check day changed
		--
		if DayChanged() then
			
			if m_App.bAutoReload then
				
				RenewConfig()
			else
				
				SetupTimeTable()
			end
			
			TraceNextTime()			-- show info
		end
		
	until nil


	m_trace:newline(sAppTitle .. " terminated ###")
end

-- ----------------------------------------------------------------------------
-- open logging
--
m_trace:open()
	
-- run
--
RunApplication(...)

-- end
--
m_trace:close()

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

