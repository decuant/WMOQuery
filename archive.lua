--[[
*	archive.lua
*
*	Given a source folder and a target folder will create a number of subfolder in
*   target folder, using the current date and time for each name of subfolders.
*   Will then copy all files in source folder to the ultimate folder (the minutes).
*
]]

local wx	= require("wx")
local trace = require("lib.trace")

local _cat	= table.concat
local _sort	= table.sort
local _date	= os.date
local _time	= os.time
local _gsub	= string.gsub

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("archive")

-- ----------------------------------------------------------------------------
--
local m_App = 
{
	-- private
	--
	sAppName 	= "archive",
	sAppVer  	= "0.0.1",
	sRelDate 	= "16/05/2020",
	
	sConfigFile	= "config/folders.lua",
	
	sDestPath	= "",					-- working target directory

	-- public, override in configuration file
	--
	bUseMove	= false,				-- move files instead of copy
	bUseCurDay	= false,				-- use todays' date or modification time of 
										-- newest file in source directory
	sTargetFldr	= "C:\\Temp",
	sSourceFldr	= "C:\\Usr_2\\Lua\\WMOQuery\\data\\update",
	sExtFilter	= "*.json",
}

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
	
	m_App.bUseMove		= tOverride.bUseMove
	m_App.bUseCurDay	= tOverride.bUseCurDay

	m_App.sTargetFldr	= tOverride.sTargetFldr
	m_App.sSourceFldr	= tOverride.sSourceFldr
	m_App.sExtFilter	= tOverride.sExtFilter	

end

-- ----------------------------------------------------------------------------
-- get the number of files in specified directory
--
local function GetNumberOfFiles()
--	m_trace:line("GetNumberOfFiles()")
	
	local dir 		= wx.wxDir()
	local sPathnm	= m_App.sSourceFldr
	local sFilter	= m_App.sExtFilter
	local iCount	= 0
	
	if not dir:Open(sPathnm) then
		
		m_trace:line("---> Cannot open directory [" .. sPathnm .. "]")
		return iCount
	end
	
	-- scan for the modified date and time for each file
	--
	local _, sFilename = dir:GetFirst(sFilter, wx.wxDIR_FILES)
	
	while sFilename and 0 < #sFilename do
		
		iCount = iCount + 1
		
		_, sFilename = dir:GetNext()
	end
	
	return iCount
end

-- ----------------------------------------------------------------------------
--
local function TargetDirFromCurDay()
	m_trace:line("Building target folder name from todays' date")

	local tmNow 	= _time()
	local tFolders	= { }
	
	tFolders[#tFolders + 1] = m_App.sTargetFldr
	tFolders[#tFolders + 1] = _date("%Y", tmNow)
	tFolders[#tFolders + 1] = _date("%m", tmNow)		
	tFolders[#tFolders + 1] = _date("%d", tmNow)
	tFolders[#tFolders + 1] = _date("%H-%M", tmNow)		
	
	local sTarget = _cat(tFolders, "\\")
	
	return sTarget
end

-- ----------------------------------------------------------------------------
-- recurse directories and inspect o.s. date and time of files
--
local function TargetDirFromFileAccess()
	m_trace:line("Building target folder name from newest file date")
	
	local dir		= wx.wxDir()
	local sPathnm 	= m_App.sSourceFldr
	local sFilter	= m_App.sExtFilter
	
	dir:Open(sPathnm)
	
	-- scan for the modified date and time for each file
	--
	local fCurrent
	local tmValue
	local sDateTime
	local tResults = { }
		
	local _, sFilename = dir:GetFirst(sFilter, wx.wxDIR_FILES)
	
	while sFilename and 0 < #sFilename do
		
		fCurrent 	= wx.wxFileName(sPathnm .. "\\" .. sFilename)
		
		tmValue		= fCurrent:GetModificationTime()
		sDateTime	= _date("%Y\\%m\\%d\\%H-%M", tmValue:GetTicks())
		
		-- add to list
		--
		tResults[#tResults + 1] = sDateTime
		
		_, sFilename = dir:GetNext()
	end
	
	-- eventually return an invalid value
	--
	if 0 == #tResults then return nil end
	
	-- find the most recent value
	--
	_sort(tResults, function (a, b) return a > b end)
	
	return (m_App.sTargetFldr .. "\\" .. tResults[1])
end

-- ----------------------------------------------------------------------------
--
local function CopyFilesSimple()
--	m_trace:line("CopyFilesSimple")

	local dir		= wx.wxDir()
	local sSrcPath 	= m_App.sSourceFldr .. "\\" 
	local sDstPath	= m_App.sDestPath .. "\\" 
	local sFilter	= m_App.sExtFilter
	
	-- at this stage everything should be ok
	--
	dir:Open(sSrcPath)
	
	-- for each file perform the copy operation
	--
	local sSrcName
	local sTgtName

	local _, sFilename = dir:GetFirst(sFilter, wx.wxDIR_FILES)
	
	while sFilename and 0 < #sFilename do
		
		sSrcName = sSrcPath .. sFilename
		sTgtName = sDstPath .. sFilename
		
		wx.wxCopyFile(sSrcName, sTgtName, true)
		
		_, sFilename = dir:GetNext()
	end
	
end

-- ----------------------------------------------------------------------------
-- given a full pathname makes all the required subdirectories
-- in DOS os.execute will create all the partials but this is
-- not the case when on Unix or using the wxWidgets' Make function
--
local function CreateDirectory(inPathname, isFilename)
--	m_trace:line("CreateDirectory")

	-- sanity check
	--
	if not inPathname or 0 == #inPathname then return false end
	
	inPathname = _gsub(inPathname, "\\", "/")		-- normalize
	
	-- to cycle through all partials add a terminator
	--
	if not isFilename and not inPathname:find("/", #inPathname, true) then
		
		inPathname = inPathname .. "/"
	end
	
	-- do make all directories in between "\\"
	--
	local dir = wx.wxDir()
	local x1  = 1
	
	while x1 < #inPathname do
		
		local i1 = inPathname:find("/", x1, true)
		
		if i1 then
			
			local sPartial = inPathname:sub(1, i1 - 1)
			
			if not dir.Exists(sPartial) then
				
				if not dir.Make(sPartial) then return false end
			end
			
			x1 = i1 + 1
		else
		
			break
		end
	end
	
	return true
end

-- ----------------------------------------------------------------------------
--
local function DoProcess()
--	m_trace:line("DoProcess")

	-- build the target directory name
	--
	local sTarget

	if m_App.bUseCurDay then
		
		sTarget = TargetDirFromCurDay()
	else
		
		sTarget = TargetDirFromFileAccess()
	end
	
	if sTarget  then
		
		m_trace:line("TARGET directory [" .. sTarget .. "]")
	
		if CreateDirectory(sTarget, false) then
			
			m_App.sDestPath = sTarget
			CopyFilesSimple()
		else
			
			m_trace:line("---> Failed to create [" .. sTarget .. "]")		
		end
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
	LoadConfig()
	
	-- this is a test both for valid source directory
	-- and for number of files to copy
	--
	if 0 < GetNumberOfFiles() then
		
		DoProcess()
	else
		
		m_trace:line("Nothing to do")
	end

	m_trace:newline(sAppTitle .. " terminated ###")
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
