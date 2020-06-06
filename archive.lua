--[[
*	archive.lua
*
*	Given a source folder and a target folder will create a number of subfolder in
*   target folder, using the current date and time for each name of subfolders.
*   Will then copy all files in source folder to the ultimate folder (the minutes).
*
]]

-- ----------------------------------------------------------------------------
--
local wx		= require("wx")
local utility	= require("lib.utility")
local trace		= require("lib.trace")

local _cat		= table.concat
local _sort		= table.sort
local _date		= os.date
local _time		= os.time
local _format	= string.format
local _gsub		= string.gsub
local _mkdir	= utility.CreateDirectory

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
	sAppVer  	= "0.0.4",
	sRelDate 	= "2020/06/06",
	
	sConfigFile	= "config/folders.lua",
	
	sDestPath	= "",					-- working target directory
	iTotFound	= 0,					-- total files to copy/move
	iTotCopies	= 0,					-- result of the operation
	
	-- public, override in configuration file
	--
	bUseMove	= false,			-- move files instead of copy
	bUseCurDay	= false,			-- use todays' date or modification time of 
									-- newest file in source directory
	sTargetFldr	= "data",
	sSourceFldr	= "data/update",
	sExtFilter	= "*.json",
}

-- ----------------------------------------------------------------------------
-- given a relative path builds a full path
-- take into account bot "/" and "\\"
--
local function BuildDirName(inRelPath)

	local sCwd	= inRelPath
	local sTest	= inRelPath:sub(1, 1)
	
	if "/" ~= sTest then
		
		sTest = inRelPath:sub(1, 2)
		
		if "\\\\" ~= sTest then
			
			sCwd = wx.wxFileName.GetCwd() .. "/" .. inRelPath
		end
	end

	return _gsub(sCwd, "\\", "/")		-- normalize
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
	m_trace:line("Building target folder name from today's date")

	local tmNow 	= _time()
	local tFolders	= { }
	
	tFolders[#tFolders + 1] = m_App.sTargetFldr
	tFolders[#tFolders + 1] = _date("%Y", tmNow)
	tFolders[#tFolders + 1] = _date("%m", tmNow)		
	tFolders[#tFolders + 1] = _date("%d", tmNow)
	tFolders[#tFolders + 1] = _date("%H-%M", tmNow)		
	
	local sTarget = _cat(tFolders, "/")
	
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
		
		fCurrent 	= wx.wxFileName(sPathnm .. "/" .. sFilename)
		
		tmValue		= fCurrent:GetModificationTime()
		sDateTime	= _date("%Y/%m/%d/%H-%M", tmValue:GetTicks())
		
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
	
	return (m_App.sTargetFldr .. "/" .. tResults[1])
end

-- ----------------------------------------------------------------------------
--
local function CopyFilesSimple()
--	m_trace:line("CopyFilesSimple")

	local dir		= wx.wxDir()
	local sSrcPath 	= m_App.sSourceFldr .. "/" 
	local sDstPath	= m_App.sDestPath .. "/" 
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
		
		if wx.wxCopyFile(sSrcName, sTgtName, true) then
			
			-- check for moving files
			--
			if m_App.bUseMove then wx.wxRemoveFile(sSrcName) end
			
			m_App.iTotCopies = m_App.iTotCopies + 1
		end
		
		_, sFilename = dir:GetNext()
	end
	
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
		
		-- create the target directory
		--
		m_trace:line("TARGET directory [" .. sTarget .. "]")
	
		if _mkdir(sTarget, false) then
			
			-- copy/move files
			--
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

	m_App.sTargetFldr	= BuildDirName(m_App.sTargetFldr)
	m_App.sSourceFldr	= BuildDirName(m_App.sSourceFldr)
	
	-- this is a test both for valid source directory
	-- and for number of files to copy
	--
	m_App.iTotFound = GetNumberOfFiles()
	
	m_trace:line("SOURCE directory [" .. m_App.sSourceFldr .. "] Files [" .. m_App.iTotFound .. "] Ext. [" .. m_App.sExtFilter .. "]")
	
	if 0 < m_App.iTotFound then
		
		DoProcess()
	else
		
		m_trace:line("Nothing to do")
	end
	
	-- give feedback
	--
	m_trace:summary("Copied files [" .. m_App.iTotCopies .. "] out of [" .. m_App.iTotFound .. "]")
	
	-- give feedback
	--
	local iTotal   = m_App.iTotFound 
	local iSuccess = m_App.iTotCopies
	local iFailed  = iTotal - iSuccess

	m_trace:summary("Downloaded [" .. iTotal .. "] Failed: [" .. iFailed .. "]")
	
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
