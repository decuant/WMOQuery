--[[
*	view.lua
*
*   Display a WMO dataset in tabular format.
]]

local wx		= require("wx")
local trace 	= require("lib.trace")
local json		= require("lib.json")
local palette	= require("lib.wxX11Palette")

local _format	= string.format

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("view")

-- ----------------------------------------------------------------------------
-- window's private members
--
local m_App = 
{
	sAppName	= "WMO data view",
	sAppVer		= "0.0.1",
	sRelDate	= "24/04/2020",
	
	sFileInput	= "",
}

-- ----------------------------------------------------------------------------
--
local m_GridCities =
{
	--  title    active order [rows] [cols] [size row] [size col]
	--
	{ "Forecast",  true, 0,  10,  8,  -1,  -1 },
	{ "Climate",  false, 1,  16, 10,  -1,  -1 },
	{ "Details",  false, 2,  15,  1, 240, 340 },
	{ "Member",   false, 3,   7,  1, 240, 400 },
}

local m_GridRegions =
{
	{ "Africa",						 true, 0, 250,  4, 300, 400 },
	{ "Asia",						false, 1, 250,  4, 300, 400 },
	{ "South America",				false, 2, 250,  4, 300, 400 },
	{ "North and Central America",	false, 3, 250,  4, 300, 400 },
	{ "South-West Pacific",			false, 4, 250,  4, 300, 400 },
	{ "Europe",						false, 5, 250,  4, 300, 400 },
}

-- ----------------------------------------------------------------------------
--
local m_Frame =
{
	hWindow		= nil,	-- main frame
	hStatusBar	= nil,	-- the status bar
	
	notebook	= nil,
	gridSet		= nil,	-- which grid set is in use
}

-- ----------------------------------------------------------------------------
--
local m_GridAttrs =
{
	font 		= nil,
	attrOdd 	= nil,
	attrEven	= nil,
}

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
--
local function FillGridWithInfo(inGridIndex, inTable)
--	m_trace:line("FillGridWithInfo")

	local gridRow = m_GridCities[inGridIndex]
	local grid = gridRow[1]
	local iRow = 0
	
	for iRow=0, grid:GetNumberRows() - 1 do
		for iCol=0, grid:GetNumberCols() - 1 do
			grid:SetCellValue(iRow, iCol, "")
		end
	end
	
	grid:SetRowLabelSize(gridRow[7])
	grid:SetDefaultColSize(gridRow[8], false)
	
	grid:SetColLabelValue(0, "")
	
	if not inTable then
		m_trace:line("Empty table: " .. gridRow[2])
		return
	end
	
	iRow = 0
	
	for field, value in pairs(inTable) do
		
		grid:SetRowLabelValue(iRow, field)
		
		if "table" ~= type(value) then
			grid:SetCellValue(iRow, 0, tostring(value))
		else
			grid:SetCellValue(iRow, 0, "ref *")
		end
	
		iRow = iRow + 1
	end
end

-- ----------------------------------------------------------------------------
--
local function FillGridRowByCol(inGridIndex, inTable)
--	m_trace:line("FillGridRowByCol")

	local gridRow = m_GridCities[inGridIndex]
	local grid = gridRow[1]
	local iCol = 0
	
	for iRow=0, grid:GetNumberRows() - 1 do
		for iCol=0, grid:GetNumberCols() - 1 do
			grid:SetCellValue(iRow, iCol, "")
		end
	end
	
	if not inTable then
		m_trace:line("Empty table: " .. gridRow[2])
		return
	end

	-- set column's labels
	--
	local aMonth = inTable[1]

	if aMonth then
		
		iCol = 0
		
		for field, _ in pairs(aMonth) do
			grid:SetColLabelValue(iCol, tostring(field))
			
			iCol = iCol + 1
		end
		
		-- fill with values
		--
		local tMonth = inTable
		
		for iRow=1, #tMonth do
			
			aMonth	= tMonth[iRow]
			iCol	= 0
			
			for _, value in pairs(aMonth) do
				grid:SetCellValue(iRow - 1, iCol, tostring(value))
			
				iCol = iCol + 1
			end
		end
	end
end

-- ----------------------------------------------------------------------------
--
local function CreateGridAttributes()
--	m_trace:line("CreateGridAttributes")
	
	if not m_GridAttrs.font  then
		
		m_GridAttrs.font = wx.wxFont( 11, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
									  wx.wxFONTWEIGHT_LIGHT, false, "Lucida Sans Unicode", wx.wxFONTENCODING_SYSTEM)
								
		local fntCell = wx.wxFont(  10, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
									wx.wxFONTWEIGHT_LIGHT, false, "Segoe UI", wx.wxFONTENCODING_SYSTEM)
								  
		m_GridAttrs.attrOdd  = wx.wxGridCellAttr(palette.Gray0, palette.Ivory, fntCell, wx.wxALIGN_CENTRE, wx.wxALIGN_CENTRE)
		m_GridAttrs.attrEven = wx.wxGridCellAttr(palette.Gray0, palette.BlanchedAlmond, fntCell, wx.wxALIGN_CENTRE, wx.wxALIGN_CENTRE)
	end
end

-- ----------------------------------------------------------------------------
--
local function SetGridStyle(inGrid, inRows, inCols)
--	m_trace:line("SetGridStyle")
	
	CreateGridAttributes()
	
	inGrid:CreateGrid(inRows, inCols)
	inGrid:SetMargins(5, 5)
	inGrid:EnableEditing(false)
	inGrid:SetLabelTextColour(palette.Gray0)
	inGrid:SetGridLineColour(palette.SaddleBrown)
	inGrid:SetDefaultColSize(160, false)
	inGrid:SetLabelFont(m_GridAttrs.font)

	-- make alternating colors for all columns
	--
	for i=0, inCols, 2 do
		inGrid:SetColAttr(i, m_GridAttrs.attrOdd)
		inGrid:SetColAttr(i + 1, m_GridAttrs.attrEven)
	end	
end

-- ----------------------------------------------------------------------------
-- destroy previously created pages
--
local function CleanUp()
--	m_trace:line("CleanUp")

	local whichObj = m_Frame.gridSet
	
	if whichObj then
		
		-- remove all the GUI grids
		--
		for i=1, #whichObj do
			table.remove(whichObj[i], 1)
		end
		
		m_Frame.gridSet = nil
		m_Frame.notebook:DeleteAllPages()
	end
	
	m_Frame.hStatusBar:SetStatusText("No file selected", 0)
	m_Frame.hStatusBar:SetStatusText("", 1)	
end

-- ----------------------------------------------------------------------------
-- create all the grids
--
local function CreateNotebookPages()
--	m_trace:line("CreateNotebookPages")

	local whichObj = m_Frame.gridSet
	local notebook = m_Frame.notebook
	local nbPage
	local grNew
	local row

	for i=1, #whichObj do
		
		nbPage = wx.wxPanel(notebook, wx.wxID_ANY)
		grNew  = wx.wxGrid(nbPage, wx.wxID_ANY, wx.wxDefaultPosition, notebook:GetSize())
		
		-- insert the GUI grid in the current row of selected gridset
		--
		table.insert(whichObj[i], 1, grNew)
		
		-- add page and apply styles
		--
		row = whichObj[i]
		notebook:AddPage(nbPage, row[2], row[3], row[4])
		SetGridStyle(grNew, row[5], row[6])
	end
end

-- ----------------------------------------------------------------------------
--
local function ProcessFile()
--	m_trace:line("ProcessFile")
	
	local hFile			= io.open(m_App.sFileInput, "r")
	local sBuffer		= ""
	local tJSonObjs
	local tJSonCity		= nil
	local tJSonRegion	= nil

	-- issue a clean up of objects now
	-- file load might fail and leave garbage
	--
	CleanUp()
	
	-- read file
	--
	if hFile then 
		sBuffer = hFile:read("*a")
		hFile:close()
	end
	
	if 0 == #sBuffer then return end
	
	m_Frame.hStatusBar:SetStatusText(m_App.sFileInput, 0)
	
	-- use the decoder to get a Lua table
	--
	tJSonObjs = json.decode(sBuffer)

	-- sanity check
	--
	if not tJSonObjs then
		
		m_trace:line("ProcessFile: json.decode failed!")
		return
	end
	
	-- for debugging purpose
	--
	-- m_trace:table(tJSonObjs, false)
	
	-- test known fields 
	--
	tJSonCity = tJSonObjs.city
	
	if not tJSonCity then
		
		tJSonRegion = tJSonObjs.region
		
		if not tJSonRegion then
			
			m_trace:line("ProcessFile: format unknown!")
			return
		end
	end

	-- create necessary pages and fill with values
	--
	if tJSonCity then
		
		m_Frame.gridSet = m_GridCities
		CreateNotebookPages()
		
		m_Frame.hStatusBar:SetStatusText(tJSonCity.cityName, 1)		-- set city in statusbar
		
		-- fill with value
		--
		FillGridWithInfo(3, tJSonCity)								-- details
		FillGridWithInfo(4, tJSonCity.member)						-- member
		
		FillGridRowByCol(1, tJSonCity.forecast.forecastDay)			-- forecast
		FillGridRowByCol(2, tJSonCity.climate.climateMonth)			-- climate
		
	elseif tJSonRegion then
		
		m_Frame.gridSet = m_GridRegions
		CreateNotebookPages()
		
		m_Frame.hStatusBar:SetStatusText("All Regions", 1)			-- set common label in statusbar
		
--		FillGridRowByCol
		-- FillGridWithInfo(4, tJSonObjs.member)						-- member
	end
end

-- ----------------------------------------------------------------------------
-- Generate a unique new wxWindowID
--
local iRCEntry = wx.wxID_HIGHEST + 1

local function UniqueID()

	iRCEntry = iRCEntry + 1
	return iRCEntry
end

-- ----------------------------------------------------------------------------
-- open a file dialog to get a valid filename
--
local function OnOpenFile()
--	m_trace:line("OnOpenFile")

	local dlgOpen = wx.wxFileDialog(m_Frame.hWindow, 
									"Select JSon file", "", "", "*.json",
									wx.wxFD_OPEN | wx.wxFD_FILE_MUST_EXIST)

	if wx.wxID_OK ~= dlgOpen:ShowModal() then return end

	-- store full pathname
	--
	m_App.sFileInput = dlgOpen:GetPath()
	
	ProcessFile()
end

-- ----------------------------------------------------------------------------
--
local function OnSize()
--	m_trace:line("OnSize")

	local size = m_Frame.hWindow:GetClientSize()
	
	m_Frame.notebook:SetSize(size)
	
	-- need to resize all, doesn't cascade through
	--
	local gridSet = m_Frame.gridSet
	
	if gridSet then
		
		for i=1, #gridSet do gridSet[i][1]:SetSize(size) end
	end
end

-- ----------------------------------------------------------------------------
--
local function OnClose()
--	m_trace:line("OnClose")

	local m_Window = m_Frame.hWindow
	if not m_Window then return end

	-- finally destroy the window
	--
	m_Window.Destroy(m_Window)
	m_Frame.hWindow = nil
end

-------------------------------------------------------------------------------
--
local function CreateFrame()
--	m_trace:line("CreateFrame")

	-- create the frame
	--
	local frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, m_App.sAppName,
							 wx.wxPoint(800, 400), 
							 wx.wxSize(1900, 800))
						
	-- create the menu entries
	--
	local rcMnuOpenFile = UniqueID()
	
	local mnuFile = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuFile:Append(rcMnuOpenFile,"&Open file\tCtrl-O", "Select a json file")
	mnuFile:AppendSeparator()	
	mnuFile:Append(wx.wxID_EXIT, "E&xit\tCtrl-X", "Quit the application")

	local mnuHelp = wx.wxMenu("", wx.wxMENU_TEAROFF)
	mnuHelp:Append(wx.wxID_ABOUT, "&About " .. m_App.sAppName)

	-- attach the menu
	--
	local menuBar = wx.wxMenuBar()
	menuBar:Append(mnuFile, "&File")
	menuBar:Append(mnuHelp, "&Help")

	-- assign the menubar to this frame
	--
	frame:SetMenuBar(menuBar)

	-- create a statusbar
	-- first pane will autosize
	--	
	local stsBar = frame:CreateStatusBar(2, wx.wxST_SIZEGRIP)
	stsBar:SetFont(wx.wxFont(10, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL))
	stsBar:SetStatusWidths({-1, 175})

	-- assign event handlers for this frame
	--
	frame:Connect(rcMnuOpenFile, wx.wxEVT_COMMAND_MENU_SELECTED, OnOpenFile)
	frame:Connect(wx.wxID_EXIT,  wx.wxEVT_COMMAND_MENU_SELECTED, OnClose)
	frame:Connect(wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, OnAbout)
	
	frame:Connect(wx.wxEVT_SIZE,			OnSize)
	frame:Connect(wx.wxEVT_CLOSE_WINDOW,	OnClose)
	
	-- create a notebook style pane and apply styles
	--
	local notebook = wx.wxNotebook(frame, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(300, 200))
	local fntNote = wx.wxFont( 13, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
							   wx.wxFONTWEIGHT_BOLD, false, "Lucida Sans Unicode", 
							   wx.wxFONTENCODING_SYSTEM)

	notebook:SetBackgroundColour(palette.DarkSeaGreen)
	notebook:SetFont(wx.wxFont(fntNote))  

	-- assign an icon to frame
	--
	local icon = wx.wxIcon("lib/icons/view.ico", wx.wxBITMAP_TYPE_ICO)
	if icon then frame:SetIcon(icon) end
	
	-- store
	--
	m_Frame.hWindow		= frame
	m_Frame.hStatusBar	= stsBar
	m_Frame.notebook	= notebook
	
	-- assign text to the statusbar
	--
	CleanUp()

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

	for i, v in ipairs{...} do tArgs[i] = v	end	


	if CreateFrame() then
		
		m_Frame.hWindow:Show(true)
		
		-- store full pathname
		--
		if tArgs[1] then
			
			m_App.sFileInput = tArgs[1]
			ProcessFile()
		end
		
		wx.wxGetApp():MainLoop()
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

