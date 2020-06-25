--[[
*	compile.lua
*
*   Recurse a directory for *.json files formatted as per the WMO's site.
*
*   Output a file containing only the forecast values.
*   All cities are collected, there's no way to specify compiling of 1 city only.
*
*   Specifying the '--purge' option will delete all invalid or duplicated files. 
]]

local wx		= require("wx")
local json 		= require("lib.json")
local serpent	= require("lib.serpent")
local trace 	= require("lib.trace")

local _format	= string.format
local _insert	= table.insert

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("compile")

-- ----------------------------------------------------------------------------
--
local m_App = 
{
	sAppName = "compile",
	sAppVer  = "0.0.3",
	sRelDate = "2020/06/25",
	
	sDefPath	= "D:\\USR_2\\LUA\\WMOQuery\\data\\update",		-- default path	
	bPurge		= false,									-- remove duplicated files
	iTotScan	= 0,										-- total files processed
	iFailed		= 0,										-- counter for any error
}

-- ----------------------------------------------------------------------------
--
local m_Samples =
{
--	{ id, city_name, {	{ issue_date, { {date, min, max}, {date, min, max}, ... } },
--						{ issue_date, { {date, min, max}, {date, min, max}, ... } },
--				...
--					 },
--	},
--	{ id, ...
}

-- ----------------------------------------------------------------------------
-- get the row associated with a city ID
-- parameter inCityName is not essential but descreptive later
--
local function FindCityIdTable(inCityId, inCityName, inCreateNew)
--	m_trace:line("FindCityIdTable")

	for _, tCity in ipairs(m_Samples) do
		
		if inCityId == tCity[1] then return tCity end
	end
	
	if inCreateNew then
		
		local tCityTbl = { inCityId, inCityName, { } }	-- create table for city
		
		_insert(m_Samples, tCityTbl)					-- add new row to master table
		
		return tCityTbl
	end
	
	return nil
end

-- ----------------------------------------------------------------------------
-- get the row associated with a issue_date
--
local function FindIssueDate(inCityTbl, inIssueDate, inCreateNew)
--	m_trace:line("FindIssueDate")

	for _, tIssueDate in ipairs(inCityTbl[3]) do
		
		if inIssueDate == tIssueDate[1] then return tIssueDate end
	end
	
	if inCreateNew then
		
		local tDateTbl = { inIssueDate, { } }	-- create table for issue_date
		
		_insert(inCityTbl[3], tDateTbl)			-- add new row to inCityTbl table
		
		return tDateTbl
	end
	
	return nil
end

-- ----------------------------------------------------------------------------
-- update data collector
--
local function Collect(inCityId, inCityName, inTimedAt, inForecast)
--	m_trace:line("Collect")
	
	m_trace:line("CityId [" .. inCityId .. "] TimedAt [" .. inTimedAt .. "]")
	
	if not inForecast or 0 == #inForecast then
		
		m_trace:line("---> Collect: no forecast dataset found, ignoring contents")
		return false
	end
	
	-- get the table for the city
	-- create if not existing
	--
	local tCityTbl = FindCityIdTable(inCityId, inCityName, true)
	
	-- get the date-time of forecast
	-- ask to fail if non-existent
	--
	local tIssueDate = FindIssueDate(tCityTbl, inTimedAt, false)
	
	-- this is not possible
	--
	if tIssueDate then
		
		m_trace:line("---> Collect: duplicate found, ignoring contents")
		return false
	end
	
	-- now it is safe to create the entry for selected date
	--
	tIssueDate = FindIssueDate(tCityTbl, inTimedAt, true)

	-- add expected values of forecast
	-- { date, min, max }
	--
	local tRow
	local sDate
	local sMinT
	local sMaxT
	local iWarning = 0

	for _, tExpect in ipairs(inForecast) do
		
		tRow = { }
		
		sDate = tExpect.forecastDate
		
		if sDate and 0 < #sDate then
			
			sMinT = tExpect.minTemp
			sMaxT = tExpect.maxTemp
			
			-- correct errors with impossible values
			--
			if not sMinT or 0 == #sMinT then
				
				sMinT = "100"
				iWarning = iWarning + 1
			end
			
			if not sMaxT or 0 == #sMaxT then
				
				sMaxT = "-100"
				iWarning = iWarning + 1
			end
			
			-- values for row
			--
			_insert(tRow, sDate)
			_insert(tRow, tonumber(sMinT))
			_insert(tRow, tonumber(sMaxT))
		
			-- add to table
			--
			_insert(tIssueDate[2], tRow)
		else
			
			m_trace:line("---> Invalid forecast day found, ignoring contents")
		end
	end

	if 0 < iWarning then
		
		m_trace:line("---> Warnings raised because of invalid readings, total: " .. iWarning)
	end

	return true
end

-- ----------------------------------------------------------------------------
-- get data out of the json file
--
local function ProcessFile(inFilename)
	m_trace:newline("ProcessFile [" .. inFilename .. "]")
	
	local hFile			= io.open(inFilename, "r")
	local sBuffer		= ""
	local tJSonObjs
	local tJSonCity
	
	-- read file
	--
	if hFile then 
		sBuffer = hFile:read("*a")
		hFile:close()
	end
	
	-- sanity check
	--	
	if 0 == #sBuffer then
		
		m_trace:line("---> ProcessFile: file read failed!")
		return false
	end
	
	-- use the decoder to get a Lua table
	--
	tJSonObjs = json.decode(sBuffer)

	-- sanity check
	--
	if not tJSonObjs then
		
		m_trace:line("---> ProcessFile: json.decode failed!")
		return false
	end
	
	-- test for the 'city' element
	--
	tJSonCity = tJSonObjs.city
	
	if not tJSonCity then
		
		m_trace:line("---> ProcessFile: format unknown!")
		return false
	end
	
	m_trace:line("Parsing forecast data for city: " .. tJSonCity.cityName .. " [" .. tJSonCity.forecast.issueDate .. "]")
	
	-- grab data
	--
	return Collect(tJSonCity.cityId, tJSonCity.cityName, tJSonCity.forecast.issueDate, tJSonCity.forecast.forecastDay)
end

-- ----------------------------------------------------------------------------
-- recurse directories and inspect pertinent files
--
local function ProcessDirectory(inPathname)
	m_trace:newline("* ProcessDirectory [" .. inPathname .. "]")
	
	local dir = wx.wxDir()
	
	if not dir:Open(inPathname) then
		
		m_trace:line("---> Cannot open directory [" .. inPathname .. "]")
		return
	end
	
	-- scan for matching files
	--
	local _, sFilename = dir:GetFirst("*.json", wx.wxDIR_FILES)
	local sFullpath
	
	while sFilename and 0 < #sFilename do
		
		m_App.iTotScan = m_App.iTotScan + 1
		
		sFullpath = inPathname .. "\\" .. sFilename
		
		if not ProcessFile(sFullpath) then
			
			m_App.iFailed = m_App.iFailed + 1
			
			-- delete the file
			--
			if m_App.bPurge then
				
				os.remove(sFullpath) 
			end
		end
		
		_, sFilename = dir:GetNext()
	end
	
	-- scan further down
	--
	local _, sDirectory = dir:GetFirst("*", wx.wxDIR_DIRS | wx.wxDIR_NO_FOLLOW)
	
	while sDirectory and 0 < #sDirectory do
		
		ProcessDirectory(inPathname .. "\\" .. sDirectory)
		
		_, sDirectory = dir:GetNext()
	end

	dir:Close()
end

-- ----------------------------------------------------------------------------
--
local function SaveCompiledTable(inRootDir)
--	m_trace:line("SaveCompiledTable")
	
	local sObjFile	= inRootDir .. "\\WMO Samples.dat"
	local hFile		= io.open(sObjFile, "w")
	local sBuffer	= serpent.dump(m_Samples)
	
	if hFile then
		
		hFile:write(sBuffer)
		hFile:close()
	else
		
		m_trace:line("---> Failed to save compiled datasets in [" .. sObjFile .. "]")
		return false
	end
	
	--[[ this is for internal testing
	
	m_Samples = dofile(sObjFile)
	trace.table(m_Samples)
	
	--]]	
	
	m_trace:newline("Output saved in [" .. sObjFile .. "]")
	
	return true
end

-- ----------------------------------------------------------------------------
--
local function RunApplication(...)
--	m_trace:line("RunApplication")

	local sAppTitle = m_App.sAppName .. " [" .. m_App.sAppVer .. "]"
	
	m_trace:time(sAppTitle .. " started")
	
	assert(os.setlocale('us', 'all'))
	m_trace:line("Current locale is [" .. os.setlocale() .. "]")
	
	-- get the arguments on the command line
	--
	local tArgs = { }

	for _, v in ipairs{...} do
		
		if "--purge" == v then
			
			m_App.bPurge = true
		else
			
			tArgs[#tArgs + 1] = v
		end
	end	
	
	-- get the root directory
	--
	local sRootDir = tArgs[1] or m_App.sDefPath
	
	if not sRootDir or 0 == #sRootDir then
		
		m_trace:line("---> No root directory was specified, aborting")
		return
	end
	
	-- try opening at least the root
	--
	if not wx.wxDir().Exists(sRootDir) then
		
		m_trace:line("---> Cannot open directory [" .. sRootDir .. "], aborting")
		return
	end

	-- work it
	--
	m_trace:startwatch()
	
	ProcessDirectory(sRootDir)			-- here start the inspection
	
	if 0 < #m_Samples then
		
		SaveCompiledTable(sRootDir)		-- save table to file
	end
	
	m_trace:stopwatch("Compile took")
	
	-- give feedback
	--
	local iTotal   = m_App.iTotScan 
	local iFailed  = m_App.iFailed
	local iSuccess = iTotal - iFailed
	
	m_trace:summary("Touched files [" .. iTotal .. "] Failed: [" .. iFailed .. "]")
	
	-- report to caller
	--
	io.stdout:write(_format("%d/%d\n", iSuccess, iTotal))
end

-- ----------------------------------------------------------------------------
-- redirect logging
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
