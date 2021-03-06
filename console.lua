--[[
*	console.lua
*
*   Provides a GUI for scripts in set.
]]

local wx		= require("wx")
local utility 	= require("lib.utility")
local timers 	= require("lib.ticktimer")
local trace 	= require("lib.trace")
local panels	= require("lib.pnlDraw")
local dlgSamples= require("lib.dlgSamples")
local palette	= require("lib.wxX11Palette")

local _format	= string.format
local _gsub		= string.gsub

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("console")

-- ----------------------------------------------------------------------------
-- shell command to use, 1 of the 2
-- (this has to be modified to work under Unix)
--
local m_ShellExec = "explorer.exe /separate /select, "
local m_ShellOpen = "explorer.exe /select, "

-- ----------------------------------------------------------------------------
--
local m_App = 
{
	sAppName 	= "console",
	sAppVer  	= "0.0.16",
	sRelDate 	= "2021/01/01",
	sConfigFile	= "config/preferences.lua",

	sDefPath 	= "data",
	sShellCmd	= m_ShellExec,

	iMaxMem		= 5,	-- higher limit before forcing a collect call,
						-- set 0 or very low for continuos memory reclaim
}

-- ----------------------------------------------------------------------------
--
local m_Frame =
{
	hWindow		= nil,	-- main frame
	hStatusBar	= nil,	-- the status bar
	hSash		= nil,  -- splitter
	hPnlDraw	= nil,	-- container for drawing
	hDirSel		= nil,  -- dir/file selector
	hStatus		= nil,	-- statusbar

	iWidthWin	= 1000,	-- set the dir. list to a fixed size
	iWidthDir	= 250,	-- thus making it dominant when win resized

	hWindowsTmr	= nil,	-- Windows Timer object attached to the frame
	tmStatbar	= 0,	-- date for the statusbar
}

-- ----------------------------------------------------------------------------
-- colors for the dir list control
--
local tDefColours =
{
	clrDirListBack	= palette.Azure4,
	clrDirListFore	= palette.Gray5,
}

-- ----------------------------------------------------------------------------
-- file filter for dir list control
--
local m_FileFilter =
	[[WMO site datasets|*.json|
	Compiled datasets|*.dat|
	All files except hidden|*.*]]

-- ----------------------------------------------------------------------------
-- given a relative path builds a full path
--
local function BuildDirName(inRelPath)

	local sCwd = wx.wxFileName.GetCwd() .. "\\" .. inRelPath

	return _gsub(sCwd, "\\", "/")		-- normalize
end

-- ----------------------------------------------------------------------------
-- Simple interface to pop up a message
--
local function DlgMessage(message)

	wx.wxMessageBox(message, m_App.sAppName,
					wx.wxOK + wx.wxICON_INFORMATION, m_Frame.hWindow)
end

-- ----------------------------------------------------------------------------
--
local function OnAbout()

	DlgMessage(_format(	"%s [%s] Rel. date [%s]\n %s, %s, %s",
						m_App.sAppName, m_App.sAppVer, m_App.sRelDate,
						_VERSION, wxlua.wxLUA_VERSION_STRING, wx.wxVERSION_STRING))
end

-- ----------------------------------------------------------------------------
-- Generate a unique new wxWindowID
--
local m_iRCEntry = wx.wxID_HIGHEST + 1

local function UniqueID()

	m_iRCEntry = m_iRCEntry + 1

	return m_iRCEntry
end

-- ----------------------------------------------------------------------------
-- cell number starts at 1, using the Lua convention
-- using the first cell as default position
--
local function SetStatusText(inText, inCellNo)
--	m_trace:line("SetStatusText")

	inText	 = inText or ""
	inCellNo = inCellNo or 1

	inCellNo = inCellNo - 1
	if 0 > inCellNo or 2 < inCellNo then inCellNo = 1 end

	m_Frame.hStatus:SetStatusText(inText, inCellNo)

	-- start a one-shot timer
	--
	if 0 == inCellNo and 0 < #inText then
		
		local tTimers = timers.GetTimers()		
		
		tTimers.Display:Reset()
		tTimers.Display:Enable(true)
		
		m_trace:line(inText)			-- add line to log
	end
end

-- ----------------------------------------------------------------------------
-- check if the current date has changed
--
local function CheckDate()
--	m_trace:line("CheckDate")

	local tmNow = os.time()

	-- test how much time has elapsed and update if necessary
	--
	if (60 + m_Frame.tmStatbar) < tmNow then
		
		m_Frame.tmStatbar = tmNow
		SetStatusText(os.date("%A %B %d %Y", tmNow), 2)
	end
end

-- ----------------------------------------------------------------------------
-- one time initialization of tick timers and the frame's timer
-- the lower the frame's timer interval the more accurate the tick timers are
--
local function InstallTimers()
--	m_trace:line("InstallTimers")

	if not m_Frame.hWindow then return false end

	-- safe guard: check the Windows timer if already installed
	--
	if m_Frame.hWindowsTmr then return true end

	-- allocate the ticktimers
	--
	timers.new("Display")
	timers.new("Garbage")
	timers.new("Today")

	-- get the table of what we have installed
	--
	local tTimers = timers.GetTimers()

	-- setup each tick timer resolution and enable state
	-- values are in seconds
	--
	if not tTimers.Display:IsEnabled() then	tTimers.Display:Setup(5, false) end
	if not tTimers.Garbage:IsEnabled() then	tTimers.Garbage:Setup(30, true) end
	if not tTimers.Today:IsEnabled() then tTimers.Today:Setup(60, true) end

	-- create and start a Windows timer object
	-- with a fair resolution for this application
	--
	m_Frame.hWindowsTmr = wx.wxTimer(m_Frame.hWindow, wx.wxID_ANY)
	m_Frame.hWindowsTmr:Start(500, false)
end

-- ----------------------------------------------------------------------------
-- check each tick timer and fire an action if interval has elapsed
-- this is the call back of the frame (a real Windows timer)
--
local function OnTimer()
--	m_trace:line("OnTimer")

	local tTimers = timers.GetTimers()
	if not tTimers then return end

	-- this is to cleanup the statusbar message
	--
	if tTimers.Display:HasFired() then
		
		-- cleanup the status bar
		-- then disable the timer
		--
		SetStatusText(nil)
		tTimers.Display:Enable(false)
	end

	-- this is to release memory via the GC
	-- the false parameter in GarbageTest means not releasing memory
	--
	if tTimers.Garbage:HasFired() then
		
		local _, sTraceLine = utility.GarbageTest(m_App.iMaxMem, false)
		
		if sTraceLine then m_trace:line(sTraceLine) end
		
		tTimers.Garbage:Reset()
	end

	-- simply checks if today's date has changed
	--
	if tTimers.Today:HasFired() then
		
		CheckDate()
		
		tTimers.Today:Reset()
	end	
end

-- ----------------------------------------------------------------------------
--
local function SetupSplitter()
--	m_trace:line("SetupSplitter")

	local shWin		= m_Frame.hSash
	local iWidthWin = m_Frame.iWidthWin
	local iWidthDir = m_Frame.iWidthDir

	shWin:SetSashGravity(1.0)
	shWin:SplitVertically(m_Frame.hPnlDraw:GetHandle(), m_Frame.hDirSel, iWidthWin - iWidthDir)
	shWin:SetMinimumPaneSize(iWidthDir)
end

-- ----------------------------------------------------------------------------
--
local function OnToggleViewDirList()
--	m_trace:line("OnToggleViewDirList")

	local hWin = m_Frame.hSash

	if hWin:IsSplit(m_Frame.hDirSel) then
		
		hWin:Unsplit(m_Frame.hDirSel)
	else
		
		SetupSplitter()
	end
end

-- ----------------------------------------------------------------------------
--
local function OnSize()
--	m_trace:line("OnSize")

	local sizeWin = m_Frame.hWindow:GetClientRect()

	m_Frame.hSash:SetSize(sizeWin)

	m_Frame.iWidthWin = sizeWin:GetWidth()
end

-- ----------------------------------------------------------------------------
--
local function OnClose()
--	m_trace:line("OnClose")

	local m_Window = m_Frame.hWindow
	if not m_Window then return end

	-- cancel the frame's timer
	--
	wx.wxGetApp():Disconnect(wx.wxEVT_TIMER)

	-- finally destroy the window
	--
	m_Window.Destroy(m_Window)
	m_Frame.hWindow = nil
end

-- ----------------------------------------------------------------------------
-- wait for a process to complete, reads stdout from caller
-- gives result in statusbar
--
local function WaitForComplete(inHFile, inMessage)

	wx.wxBeginBusyCursor()
	
	if inHFile then
		
		local sStdOut = inHFile:read("l")
		inHFile:close()
		
		if sStdOut then	SetStatusText(inMessage .. ": " .. sStdOut) end
	end
	
	wx.wxEndBusyCursor()
end

-- ----------------------------------------------------------------------------
--
local function OnDownloadFavorites()
--	m_trace:line("OnDownloadFavorites")

	local hFile, sError = io.popen("lua ./download.lua --favorites", "r")

	if not hFile or (sError and 0 < #sError) then
		
		DlgMessage(_format("On downloading favorites got an error\n%s", sError))
		return
	end

	WaitForComplete(hFile, "Download Favorites")
end

-- ----------------------------------------------------------------------------
--
local function OnArchiveUpdates()
--	m_trace:line("OnArchiveUpdates")

	local hFile, sError = io.popen("lua ./archive.lua", "r")

	if not hFile or (sError and 0 < #sError) then
		
		DlgMessage(_format("On archiving updates got an error\n%s", sError))
		return
	end

	WaitForComplete(hFile, "Archive Updates")
end

-- ----------------------------------------------------------------------------
--
local function DoOpenView(inFilename)
--	m_trace:line("DoOpenView")

	local sError

	if inFilename:find(".json") then
		
		_, sError = io.popen("lua ./view.lua \"" .. inFilename .. "\"", "r")
	else
		
		_, sError = io.popen(m_App.sShellCmd .. "\"" .. inFilename .. "\"", "r")
	end
	
	if sError and 0 < #sError then
		
		DlgMessage(_format("Failed to open file\n%s", sError))
	end
end

-- ----------------------------------------------------------------------------
--
local function DoCompileDirectory(inDirectory)
--	m_trace:line("DoCompileDirectory")

	local hFile, sError = io.popen("lua ./compile.lua \"" .. inDirectory .. "\" --purge --import", "r")

	if not hFile or (sError and 0 < #sError) then
		
		DlgMessage(_format("Failed to open file\n%s", sError))
		return
	end
	
	WaitForComplete(hFile, "Compiled Datasets")
end

-- ----------------------------------------------------------------------------
--
local function OnDrawStation()
--	m_trace:line("OnDrawStation")

	local hWin  = m_Frame.hDirSel
	local item  = hWin:GetTreeCtrl():GetSelection()

	if not item then return end

	local sFile = hWin:GetFilePath(item)	-- see docs, return only files not dirs

	if 0 == #sFile then return end

	-- select station to display
	--
	local tSamples = dlgSamples.SelectCity(m_Frame.hWindow, sFile)
	local panel = m_Frame.hPnlDraw

	if not tSamples then return end

	SetStatusText("Open file: " .. sFile)

	panel:SetSamples(tSamples)
	panel:GetHandle():SetFocus(true)
end

-- ----------------------------------------------------------------------------
-- reset values for pan/tilt and zooms
--
local function OnResetView()
--	m_trace:line("OnResetView")

	local panel = m_Frame.hPnlDraw
	
	panel:ResetView()
end

-- ----------------------------------------------------------------------------
--
local function LoadConfig()
--	m_trace:line("LoadConfig")
	
	-- setting have meaning only for display
	--
	if not m_Frame then return end

	local sConfig	= m_App.sConfigFile

	-- try opening the application's associated configuration file
	--
	if not wx.wxFileName().Exists(sConfig) then return end

	m_trace:line("Loading configuration file [" .. sConfig .. "]")

	-- an execution abort here must be be due to a bad configuration syntax
	--
	local tOverride = dofile(sConfig)

	local hTree		= m_Frame.hDirSel:GetTreeCtrl()
	local hPanel	= m_Frame.hPnlDraw
	local tColours	= tOverride.tColourScheme
	
	-- set the choosen path
	--
	if tOverride.sDefPath and 0 < #tOverride.sDefPath then
		
		m_App.sDefPath = tOverride.sDefPath
		m_Frame.hDirSel:SetPath(BuildDirName(m_App.sDefPath))
	end
	
	-- which action on Shell Open command
	--
	if tOverride.bShellSelect then
		m_App.sShellCmd = m_ShellOpen
	else
		m_App.sShellCmd = m_ShellExec
	end

	-- options
	--
	hPanel:SetDrawOpts(	tOverride.iLineSize, tOverride.iFontSize, tOverride.sFontFace,
						tOverride.iDrawTemp, tOverride.iDrawOption, tOverride.iDrawErrors, 
						tOverride.bRasterOp)
	hPanel:SetTempBoxing(tOverride.iGridMinTemp, tOverride.iGridMaxTemp, 
						 tOverride.bAdaptiveTemp)
	
	-- color scheme
	--
	hPanel:SetDefaultColours(tColours)						-- this can be nil

	tColours = tOverride.tColourScheme or tDefColours		-- must have a valid value
	
	hTree:SetBackgroundColour(tColours.clrDirListBack)
	hTree:SetForegroundColour(tColours.clrDirListFore)
end

-- ----------------------------------------------------------------------------
--
local function OnReloadConfig()
--	m_trace:line("OnReloadConfig")
	
	LoadConfig()
	
	-- query for update of units
	--
	m_Frame.hPnlDraw:Redraw()
end

-- ----------------------------------------------------------------------------
-- will get called on either dblclick or keyb return
-- because of this handler it's imperative to mimic the dblclick on folders
--
local function OnDirListActivated(event)
--	m_trace:line("OnDirListActivated")
	
	local hWin  = m_Frame.hDirSel
	local item  = event:GetItem()	
	local sFile = hWin:GetFilePath(item)	-- see docs, return only files not dirs

	if 0 < #sFile then
		
		DoOpenView(sFile)
	else
		
		local hTree = hWin:GetTreeCtrl() 
		
		hTree:Toggle(item)
	end
end

-- ----------------------------------------------------------------------------
--
local function OnOpenFile()
--	m_trace:line("OnOpenFile")
	
	local hWin  = m_Frame.hDirSel
	local item  = hWin:GetTreeCtrl():GetSelection()
	
	if not item then return end
	
	local sFile = hWin:GetFilePath(item)	-- see docs, return only files not dirs
	
	if 0 < #sFile then DoOpenView(sFile) end
end

-- ----------------------------------------------------------------------------
--
local function OnCompileDirectory()
--	m_trace:line("OnCompileDirectory")

	local hWin  = m_Frame.hDirSel
	local item  = hWin:GetTreeCtrl():GetSelection()

	if not item then return end

	local sFile = hWin:GetFilePath(item)

	if 0 == #sFile then
		
		sFile = hWin:GetPath(item)
		DoCompileDirectory(sFile)
		return
	end
	
	DlgMessage("Compile valid only for directories")
end

-- ----------------------------------------------------------------------------
-- this is a context menu function that will pop up 
-- if the user right clicks on the dir list
--
local function OnDirListShowMenu(event)
--	m_trace:line("OnDirListShowMenu")

	local hWin  = m_Frame.hDirSel
	local hTree = hWin:GetTreeCtrl() 
	local item  = event:GetItem()

	-- select this item
	--
	hTree:SelectItem(item)

	-- now it is safe to query for text of item
	--
	local sFile = hWin:GetFilePath(item)	-- see docs, return only files not dirs

	-- create a menu
	--
	local mnuView	 = UniqueID()
	local mnuGraph	 = UniqueID()
	local mnuCompile = UniqueID()

	local mnuFile = wx.wxMenu("Choose action", wx.wxMENU_TEAROFF)

	mnuFile:Append(mnuView,		"Open Tabular View of File")
	mnuFile:Append(mnuGraph,	"Display Graphically a Dataset")	
	mnuFile:Append(mnuCompile,	"Compile Directory Recursively")

	-- disable un-applicable entries
	--
	if 0 < #sFile then
		
		if sFile:find(".json", 1, true) then
		
			mnuFile:Enable(mnuGraph, false)
			mnuFile:Enable(mnuCompile, false)
			
		elseif sFile:find(".dat", 1, true) then
		
			mnuFile:Enable(mnuView, false)
			mnuFile:Enable(mnuCompile, false)
		end
	else
		
		mnuFile:Enable(mnuView, false)
		mnuFile:Enable(mnuGraph, false)
	end

	-- finally show the menu to the user
	--
	local iSelected = hWin:GetPopupMenuSelectionFromUser(mnuFile)

	if     mnuView    == iSelected  then OnOpenFile()

	elseif mnuGraph   == iSelected  then OnDrawStation()

	elseif mnuCompile == iSelected  then OnCompileDirectory()

	end
end

-- ----------------------------------------------------------------------------
-- load functions from the module functions.lua
-- re-create the menu entries
--
local rcMnuLoadFxs	= UniqueID()
	
local function OnLoadFunctions()
--	m_trace:line("OnLoadFunctions")

	-- find the menu "Functions"
	--
	local menuBar = m_Frame.hWindow:GetMenuBar()
	local menuLoad, menuFxs = menuBar:FindItem(rcMnuLoadFxs)
	
	if not menuFxs then DlgMessage("Internal error!") return end

	-- remove the menus except the very first
	--
	local iCount = menuFxs:GetMenuItemCount()

	for i=1, iCount - 1 do
		menuFxs:Remove(menuFxs:FindItemByPosition(1))
	end

	-- compile and import functions
	--
	local functions	 = dofile("lib/functions.lua")
	
	-- create the menu entries
	--
	for _, item in next, functions do
		
		local id = UniqueID()
		
		-- protected function to execute
		--
		MenuItemCmd = function()
			
			-- interpreted code at run time
			-- locals are out of scope here at run time
			-- use full names to select objects
			--
			local bRet, bRedraw = pcall(item[1], m_Frame.hPnlDraw.tStatistic)
			
			if bRet and bRedraw then
				
				m_Frame.hPnlDraw:Refresh()
			end
			
			return bRet
		end
		
		menuFxs:Append(id, item[2], item[3])
		m_Frame.hWindow:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, MenuItemCmd)
	end

end
-- ----------------------------------------------------------------------------
--
local function CreateFrame(inAppTitle)
--	m_trace:line("CreateFrame")

	local iWidthWin = m_Frame.iWidthWin

	-- create the frame
	--
	local frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, inAppTitle,
							 wx.wxPoint(100, 100), 
							 wx.wxSize(iWidthWin, 600))

	-- creta the menu entries
	--
	local rcMnuOpenFile = UniqueID()
	local rcMnuViewDir  = UniqueID()
	local rcMnuViewData = UniqueID()
	local rcMnuViewReset= UniqueID()
	local rcMnuConfig   = UniqueID()	
	local rcMnuCompile  = UniqueID()	
	local rcMnuDownload = UniqueID()
	local rcMnuArchive	= UniqueID()
	
	local mnuFile = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuFile:Append(rcMnuOpenFile,"Open file\tCtrl-O", "Select a json file")
	mnuFile:AppendSeparator()	
	mnuFile:Append(wx.wxID_EXIT, "Exit\tCtrl-X", "Quit the application")

	local mnuTools = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuTools:Append(rcMnuCompile, "Compile Dataset\tCtrl-C", "Recurse directories to collect data")
	mnuTools:Append(rcMnuDownload,"Download favorites\tCtrl-D", "Launch download of favorites readings")
	mnuTools:Append(rcMnuArchive, "Archive Updates\tCtrl-A", "Copy data from updates to archive")

	local mnuView = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuView:Append(rcMnuViewData, "Graph Dataset\tCtrl-G", "Graph data for a station")
	mnuView:Append(rcMnuViewReset,"Re-set Graphics\tCtrl-Z", "Reset zoom and scaling")	
	mnuView:Append(rcMnuConfig,   "Refresh Config\tCtrl-R", "Reload the configuration file")
	mnuView:Append(rcMnuViewDir,  "Toggle view drives\tCtrl-V", "Show or hide the drives\' panel")

	local mnuHelp = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuHelp:Append(wx.wxID_ABOUT, "About " .. m_App.sAppName)

	local mnuFunc = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuFunc:Append(rcMnuLoadFxs, "Reload Functions\tCtrl-L", "Load functions.lua, create menu entries")
	
	-- attach the menu
	--
	local menuBar = wx.wxMenuBar()
	menuBar:Append(mnuFile,  "&File")
	menuBar:Append(mnuTools, "&Tools")	
	menuBar:Append(mnuView,  "&View")
	menuBar:Append(mnuFunc,  "F&unctions")
	menuBar:Append(mnuHelp,  "&Help")

	-- assign the menubar to this frame
	--
	frame:SetMenuBar(menuBar)

	-- create a statusbar
	-- (this will cause an additional WM_SIZE event)
	--
	local stsBar = frame:CreateStatusBar(2, wx.wxST_SIZEGRIP)
	stsBar:SetFont(wx.wxFont(8, wx.wxFONTFAMILY_SWISS, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL))
	stsBar:SetStatusWidths({-1, 275})

	-- controls
	--
	local shSash = wx.wxSplitterWindow( frame, wx.wxID_ANY,
										wx.wxDefaultPosition, wx.wxDefaultSize,
										wx.wxSW_3D | wx.wxSP_PERMIT_UNSPLIT)
	
	local lsDir = wx.wxGenericDirCtrl(shSash, wx.wxID_ANY, "File selector",
									  wx.wxDefaultPosition, wx.wxDefaultSize,
									  wx.wxDIRCTRL_3D_INTERNAL | wx.wxDIRCTRL_SHOW_FILTERS,
									  m_FileFilter)

	local pnlDraw = panels.New()
	pnlDraw:CreatePanel(shSash, 500, 600)

	-- set the choosen path from defaults
	--
	lsDir:SetPath(BuildDirName(m_App.sDefPath))

	-- apply styles
	--
	local hTree = lsDir:GetTreeCtrl()
	hTree:SetFont(wx.wxFont(8, wx. wxFONTFAMILY_SWISS, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL))

	-- assign event handlers for this frame
	--
	frame:Connect(rcMnuOpenFile, wx.wxEVT_COMMAND_MENU_SELECTED, OnOpenFile)
	frame:Connect(rcMnuViewData, wx.wxEVT_COMMAND_MENU_SELECTED, OnDrawStation)
	frame:Connect(rcMnuViewReset,wx.wxEVT_COMMAND_MENU_SELECTED, OnResetView)
	frame:Connect(rcMnuConfig,   wx.wxEVT_COMMAND_MENU_SELECTED, OnReloadConfig)	
	frame:Connect(rcMnuViewDir,  wx.wxEVT_COMMAND_MENU_SELECTED, OnToggleViewDirList)
	frame:Connect(rcMnuCompile,  wx.wxEVT_COMMAND_MENU_SELECTED, OnCompileDirectory)
	frame:Connect(rcMnuDownload, wx.wxEVT_COMMAND_MENU_SELECTED, OnDownloadFavorites)
	frame:Connect(rcMnuArchive,  wx.wxEVT_COMMAND_MENU_SELECTED, OnArchiveUpdates)
	frame:Connect(rcMnuLoadFxs,  wx.wxEVT_COMMAND_MENU_SELECTED, OnLoadFunctions)

	frame:Connect(wx.wxID_EXIT,  wx.wxEVT_COMMAND_MENU_SELECTED, OnClose)	
	frame:Connect(wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, OnAbout)

	frame:Connect(wx.wxEVT_TIMER,					OnTimer)
	frame:Connect(wx.wxEVT_SIZE,					OnSize)
	frame:Connect(wx.wxEVT_CLOSE_WINDOW,			OnClose)

	frame:Connect(wx.wxEVT_TREE_ITEM_ACTIVATED,		OnDirListActivated)
	frame:Connect(wx.wxEVT_TREE_ITEM_RIGHT_CLICK,	OnDirListShowMenu)

	-- assign an icon to frame
	--
	local icon = wx.wxIcon("lib/icons/console.ico", wx.wxBITMAP_TYPE_ICO)
	frame:SetIcon(icon)

	-- store interesting members
	--
	m_Frame.hWindow		= frame
	m_Frame.hStatusBar	= stsBar
	m_Frame.hSash		= shSash		-- need this if win' size changes
	m_Frame.hPnlDraw	= pnlDraw
	m_Frame.hDirSel		= lsDir
	m_Frame.hStatus		= stsBar

	-- ------------------
	--
	SetupSplitter()		-- shared setup, must call after store
	CheckDate()			-- display current date
	InstallTimers()		-- allocate the tick timers

	-- set up the frame
	--
	frame:SetMinSize(wx.wxSize(300, 125))
	frame:SetStatusBarPane(0)                   -- this is reserved for the menu	

	return true
end

-- ----------------------------------------------------------------------------
--
local function RunApplication()

	local sAppTitle = m_App.sAppName .. " [" .. m_App.sAppVer .. "]"
	
	m_trace:time(sAppTitle .. " started")
	
	assert(os.setlocale('us', 'all'))
	m_trace:line("Current locale is [" .. os.setlocale() .. "]")
	
	wx.wxGetApp():SetAppName(sAppTitle)
	
	if CreateFrame(sAppTitle) then
		
		LoadConfig()
		OnLoadFunctions()
		
		m_Frame.hWindow:Show(true)
		
		wx.wxGetApp():SetTopWindow(m_Frame.hWindow)
		wx.wxGetApp():MainLoop()
	end
	
	m_trace:newline(sAppTitle .. " terminated ###")
end

-- ----------------------------------------------------------------------------
-- open logging
--
m_trace:open()

-- run
--
RunApplication()

-- end
--
m_trace:close()

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

