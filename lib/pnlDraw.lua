--[[
*	pnlDraw.lua
*
*   .
]]

local wx		= require("wx")
local trace 	= require("lib.trace")
local utility 	= require("lib.utility")
local palette	= require("lib.wxX11Palette")

local _format	= string.format
local _floor	= math.floor
local _ceil		= math.ceil
local _remove	= table.remove
local _todate	= utility.StringToDate

-- ----------------------------------------------------------------------------
-- attach tracing to the container
--
local m_trace = trace.new("console")

-------------------------------------------------------------------------------
--
local pnlDraw	= { }
pnlDraw.__index	= pnlDraw

-- ----------------------------------------------------------------------------
-- list of created panels, allows to match with self in Windows' events
-- tuple { win id, lua self }
-- a list might be an overside structure since this panel is only used once
-- at run-time in this application, but the idea...
--
local m_tPanels = { }

-- ----------------------------------------------------------------------------
-- get the 'self'
--
local function RoutingTable_Get(inWinId)

	for _, aSelf in next, m_tPanels do
		
		if aSelf[1] == inWinId then return aSelf[2] end
	end

	-- this is a serious error
	--
	return nil
end

-- ----------------------------------------------------------------------------
-- get the 'self'
--
local function RoutingTable_Add(inWinId, inSelf)

	if not RoutingTable_Get(inWinId) then
		
		m_tPanels[#m_tPanels + 1] = { inWinId, inSelf }
	end
end

-- ----------------------------------------------------------------------------
-- remove link
--
local function RoutingTable_Del(inWinId)

	for i, aSelf in next, m_tPanels do
		
		if aSelf[1] == inWinId then _remove(m_tPanels, i) return end
	end
end

-- ----------------------------------------------------------------------------
-- constants
--
local m_BoxingX	= 40				-- deflate amount for window's client rect
local m_BoxingY	= 30				--	"		"		"		"		"	"
local m_OneDay	= (60 * 60 * 24)	-- time_t value
local m_ZoomStep= 0.025				-- stepping for zoom
local m_ZoomMin = 0.0075			-- minimum for zoom

-- ----------------------------------------------------------------------------
-- objects factory
--
function pnlDraw.New()

	local t =
	{
		--	default values
		--	
		hWindow		= nil,		-- window's handle
		
		iSizeX		= 600,		-- width of the client area
		iSizeY		= 400,		-- height of the client area
		
								-- deflated coords of window's client rect
		
		rcClip		= { left   = 0,
						top    = 0,
						right  = 0,
						bottom = 0,
						},
		
		iOriginX	= 0,
		iOriginY	= 0,
		
		iUnitX		= 1,
		iUnitY		= 1,
		iScaleTemp	= 5,		-- scaling factor for temperatures
		
		dZoomX		= 1.00,
		dZoomY		= 1.00,
		
		iGridMinT	= -10,		-- minimum temperature shown in grid
		iGridMaxT	=  50,		-- maximum temperature shown in grid
		bAdaptive 	= false,	-- adapt grid to samples' temperature values

		hBackDc		= nil,		-- background device context
		hForeDc		= nil,		-- device context for the window
		
		clrOrigin	= nil,		-- 
		clrBack		= nil,		-- used only once!
		clrGrid		= nil,		-- used only once!
		clrMinimum	= nil,
		clrMaximum	= nil,

		clrLegenda	= nil,
		clrGridText	= nil,
		
		penGrid		= nil,		-- pen for the grid
		brushBack	= nil,		-- brush for background
		
		iLineSz 	= 3,		-- size of line drawn
		penOrigin	= nil,		-- pen for origin
		penMinT		= nil,		-- pen for MIN temperature
		penMinTS	= nil,
		penMaxT		= nil,		-- pen for MAX temperature
		penMaxTs	= nil,
		brBackT		= nil,		-- brush for back of temperature
		fntLegenda	= nil,		-- font for the legenda
		fntGridDate	= nil,		-- font for dates on grid
--		fntIssueDate= nil,		-- font for the issue date
		
		vSamples	= nil,		-- data
		sCity		= "",		-- shortcut for city's name
		sCityId		= "",		-- shortcut for city's id
		
		-- statistic
		--
		iLowestT	= 50,		-- minimum temperature read from samples
		iHighestT	= -50,		-- maximum	"	"	"	"	"	"	"
		iExcursion	= 0,		-- difference between min and max
		
		iMinDate	= 0,
		iMaxDate	= 0,
		iTotDays	= 0,
	}

	return setmetatable(t, pnlDraw)
end

-- ----------------------------------------------------------------------------
-- get a table of strings describing forecast values
--
function pnlDraw.GetLegenda(self) 
--	m_trace:line("pnlDraw.GetLegenda")

	local tLegenda = { }
	
	tLegenda[#tLegenda + 1] =        ("City name:  " .. self.sCity)
	tLegenda[#tLegenda + 1] =        ("Station ID: " .. self.sCityId)
	tLegenda[#tLegenda + 1] = _format("Lowest T:   %d", self.iLowestT)
	tLegenda[#tLegenda + 1] = _format("Highest T:  %d", self.iHighestT)
	tLegenda[#tLegenda + 1] = _format("Excursion:  %d", self.iExcursion)
	tLegenda[#tLegenda + 1] = os.date("First day:  %A %B %d %Y", self.iMinDate)
	tLegenda[#tLegenda + 1] = os.date("Last day:   %A %B %d %Y", self.iMaxDate)
	tLegenda[#tLegenda + 1] = _format("Tot. days:  %d", self.iTotDays)

	return tLegenda
end

-- ----------------------------------------------------------------------------
-- remap a point from absolute to client coords
--
function pnlDraw.MapToOrigin(self, inX, inY)
--	m_trace:line("pnlDraw.MapToOrigin")

	local _x = inX * self.iUnitX
	local _y = inY * self.iUnitY

	-- set zoom
	-- 
	_x = _x * self.dZoomX
	_y = _y * self.dZoomY

	-- offset origin
	--
	_x = _floor(self.iOriginX + _x)
	_y = _floor(self.iOriginY - _y)

	return _x, _y
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.CreateGDIObjs(self)
--	m_trace:line("pnlDraw.CreateGDIObjs")

	-- when creating a pen wider than 2 wxWidgets will try to round it
	-- thus showing a little line at both ends when set at 3 pixels wide.
	-- with CAP_BUTT wxWidgets will square the end
	--
	self.penOrigin	= wx.wxPen(self.clrOrigin, 3, wx.wxSOLID)
	self.penOrigin:SetCap(wx.wxCAP_BUTT)

	self.penGrid	= wx.wxPen(self.clrFore, 1, wx.wxSOLID)
	self.brushBack	= wx.wxBrush(self.clrBack, wx.wxSOLID)

	self.penMinT	= wx.wxPen(self.clrMinimum, self.iLineSz, wx.wxSOLID)
	self.penMaxT	= wx.wxPen(self.clrMaximum, self.iLineSz, wx.wxSOLID)
	self.penMinTS	= wx.wxPen(self.clrMinimum, self.iLineSz, wx.wxDOT)
	self.penMaxTS	= wx.wxPen(self.clrMaximum, self.iLineSz, wx.wxDOT)

	self.brBackT	= self.brushBack -- wx.wxBrush(palette.Black, wx.wxSOLID)

	self.fntLegenda = wx.wxFont(11, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
								 wx.wxFONTWEIGHT_BOLD, false, "DejaVu Sans Mono", 
								 wx.wxFONTENCODING_SYSTEM)

	self.fntGridDate= wx.wxFont(9, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
								 wx.wxFONTWEIGHT_LIGHT, false, "DejaVu Sans Mono", 
								 wx.wxFONTENCODING_SYSTEM)

--	self.fntIssueDate= wx.wxFont(9, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
--								 wx.wxFONTWEIGHT_LIGHT, false, "DejaVu Sans Mono", 
--								 wx.wxFONTENCODING_SYSTEM)
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.SetDefaultColours(self, inBackground, inGridLines, inOrigin, inMin, inMax,
										 inLegenda, inGridText)
--	m_trace:line("pnlDraw.SetDefaultColours")

	-- apply styles
	--
	self.clrBack	= inBackground
	self.clrFore	= inGridLines
	self.clrOrigin	= inOrigin
	self.clrMinimum	= inMin
	self.clrMaximum	= inMax

	self.clrLegenda	= inLegenda
	self.clrGridText= inGridText

	self:CreateGDIObjs()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.SetTempBoxing(self, inTempMin, inTempMax, inAdaptive)
--	m_trace:line("pnlDraw.SetTempBoxing")

	if inTempMax < inTempMin then inTempMax, inTempMin = inTempMin, inTempMax end

	self.iGridMinT	= inTempMin
	self.iGridMaxT	= inTempMax
	self.bAdaptive 	= inAdaptive

	-- refresh
	--
	if self.vSamples then
		
		if inAdaptive then self:AdaptMinMaxTemp() else self:UpdateUnits() end
	end
end

-- ----------------------------------------------------------------------------
-- set the issue dates' labels
--
--function pnlDraw.DrawIssueDates(self, inDc)
----	m_trace:line("pnlDraw.DrawIssueDates")
	
--	local tSamples	= self.vSamples
--	if not tSamples then return end	
	
--	inDc:SetFont(self.fntIssueDate)
--	inDc:SetTextForeground(palette.Black)
--end

-- ----------------------------------------------------------------------------
-- set the labels for dates and temperatures on the grid
--
function pnlDraw.DrawLabels(self, inDc)
--	m_trace:line("pnlDraw.DrawLabels")

	local iXPos, iXInc = self.iOriginX, self.iUnitX * self.dZoomX
	local iYPos, iYInc = self.iOriginY, self.iUnitY * self.dZoomY * self.iScaleTemp

	local iRcLeft	= self.rcClip.left
	local iRcTop	= self.rcClip.top
	local iRcRight	= self.rcClip.right
	local iRcBottom	= self.rcClip.bottom

	local iDayRef	= self.iMinDate - m_OneDay
	local sDayRef

	-- switch font
	--
	inDc:SetFont(self.fntGridDate)
	inDc:SetTextForeground(self.clrGridText)

	local iExtX, iExtY = inDc:GetTextExtent("00")

	-- columns/days
	--
	for i = iXPos - (iExtX / 2), iRcRight, iXInc do
		
		iDayRef = iDayRef + m_OneDay
		sDayRef = os.date("%d", iDayRef)				-- %d here means 'day'
		
		inDc:DrawText(sDayRef, i, iRcBottom)
	end

	-- prepare for drawing temps
	--
	local iOffsetX	= iRcLeft - iExtX
	local iTempRef	= self.iScaleTemp
	local sTempRef

	-- rows/temps (below origin, going down)
	--
	for i = iYPos - (iExtY / 2), iRcBottom, iYInc do
		
		iTempRef = iTempRef - self.iScaleTemp
		
		sTempRef = _format("%d", iTempRef)
		inDc:DrawText(sTempRef, iOffsetX, i)
	end
  
	-- rows/temps (above origin, going up)
	--
	iTempRef = - self.iScaleTemp
	
	for i = iYPos - (iExtY / 2), iRcTop, -iYInc do
		
		iTempRef = iTempRef + self.iScaleTemp
		
		sTempRef = _format("%02d", iTempRef)
		inDc:DrawText(sTempRef, iOffsetX, i)
	end

end

-- ----------------------------------------------------------------------------
-- draw a summary text for current dataset
--
function pnlDraw.DrawLegenda(self, inDc)
--	m_trace:line("pnlDraw.DrawLegenda")

	inDc:SetFont(self.fntLegenda)
	inDc:SetTextForeground(self.clrLegenda)
	
	local tLegenda	= self:GetLegenda()
	local _, iExt	= inDc:GetTextExtent(tLegenda[1])

	local iRcLeft	= self.rcClip.left + 5
	local iRcTop	= self.rcClip.top

	for i=1, #tLegenda do
		
		inDc:DrawText(tLegenda[i], iRcLeft, iRcTop)
		iRcTop = iRcTop + iExt + 5
	end
end

-- ----------------------------------------------------------------------------
-- draw a grid for dates and temperatures
--
function pnlDraw.DrawGrid(self, inDc)
--	m_trace:line("pnlDraw.DrawGrid")

	local iXPos, iXInc = self.iOriginX, self.iUnitX * self.dZoomX
	local iYPos, iYInc = self.iOriginY, self.iUnitY * self.dZoomY * self.iScaleTemp

	local iRcLeft  = self.rcClip.left
	local iRcTop   = self.rcClip.top
	local iRcRight = self.rcClip.right
	local iRcBottom= self.rcClip.bottom

	inDc:SetPen(self.penGrid)						-- prepare pen for grid with color
	inDc:SetBrush(self.brushBack)					-- check for back brush same colour as background

	-- columns/days
	--
	for i = iXPos + iXInc, iRcRight, iXInc do
		inDc:DrawLine(i, iRcTop, i, iRcBottom)
	end

	-- rows/temps (below origin, going down)
	--
	for i = iYPos + iYInc, iRcBottom, iYInc do
		inDc:DrawLine(iRcLeft, i, iRcRight, i)
	end

	-- rows/temps (above origin, going up)
	--
	for i = iYPos - iYInc, iRcTop, -iYInc do
		inDc:DrawLine(iRcLeft, i, iRcRight, i)
	end

	-- draw the origin
	--
	inDc:SetPen(self.penOrigin)

	inDc:DrawLine(self.iOriginX, iRcTop, self.iOriginX, iRcBottom)
	inDc:DrawLine(iRcLeft, self.iOriginY, iRcRight, self.iOriginY)
end

-- ----------------------------------------------------------------------------
-- draw all dates
--
function pnlDraw.DrawPoints(self, inDc)
--	m_trace:line("pnlDraw.DrawPoints")
	
	local tSamples	= self.vSamples
	if not tSamples then return end	
	
	local iLineSz	= self.iLineSz
	local sDateIssued
	local tByDate
	local xA, yA
	local iTempY
	local tDrawPoints
	local iStartDay
	local iDayX
	local penMinT
	local penMaxT
	local iOffsetY	
	
	
	tSamples = tSamples[3]				-- skip identification
	inDc:SetBrush(self.brBackT)
	
	-- cycle all samples
	--
	for iList=1, #tSamples do
		
		tByDate 	= tSamples[iList]		-- shortcut it
		sDateIssued = tByDate[1]
		tByDate		= tByDate[2]			-- shortcut it
		
		-- toggle pen at each date
		--
		if 0 ~= iList % 2 then
			
			penMinT  = self.penMinT
			penMaxT  = self.penMaxT
			iOffsetY = 0
		else
			
			penMinT  = self.penMinTS
			penMaxT  = self.penMaxTS
			iOffsetY = self.iLineSz
		end
		
		-- get the first day of the current row
		-- the other days are sequential
		--
		iStartDay = _todate(tByDate[1][1])
		iStartDay = (iStartDay - self.iMinDate) / m_OneDay
		
		-- one cycle for the min and another for the max
		--
		for iRel=2, 3 do
			
			--	move to the first
			--
			tDrawPoints = { }
			iDayX 		= iStartDay - 1

			for _, vForecast in next, tByDate do
				
				iDayX  = iDayX + 1
				iTempY = vForecast[iRel]
				
				xA, yA = self:MapToOrigin(iDayX, iTempY)
				
				tDrawPoints[#tDrawPoints + 1] = {xA, yA}		-- collect GUI points
			end
			
			-----------------
			-- draw
			--
			
			-- use different pen for min or max
			--
			if 2 == iRel then inDc:SetPen(penMinT) else inDc:SetPen(penMaxT) end
				
			for iPoint=1, #tDrawPoints - 1 do
				
				inDc:DrawLine(tDrawPoints[iPoint][1], tDrawPoints[iPoint][2] + iOffsetY, 
							  tDrawPoints[iPoint + 1][1], tDrawPoints[iPoint + 1][2] + iOffsetY)
			end
			
			-- spot first/last dates with a small circle
			--
			inDc:DrawCircle(tDrawPoints[1][1], tDrawPoints[1][2] + iOffsetY, iLineSz)
			inDc:DrawCircle(tDrawPoints[#tDrawPoints][1], tDrawPoints[#tDrawPoints][2] + iOffsetY, iLineSz)
		end
	end
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.NewMemDC(self)
--	m_trace:line("pnlDraw.NewMemDC")
	
	local iWidth	= self.iSizeX
	local iHeight	= self.iSizeY

	-- create a bitmap wide as the client area
	--
	local memDC = self.hForeDc

	if not memDC then

		local bitmap = wx.wxBitmap(iWidth, iHeight)
		
		memDC  = wx.wxMemoryDC()
		memDC:SelectObject(bitmap)
	end

	-- draw the background
	--
	if not self.hBackDc then return nil end
	
	memDC:Blit(0, 0, iWidth, iHeight, self.hBackDc, 0, 0, wx.wxCOPY)

	-- draw the points
	--
	self:DrawPoints(memDC)
--	self:DrawIssueDates(memDC)

	return memDC
end

-- ----------------------------------------------------------------------------
-- create a legenda and a grid
--
function pnlDraw.NewBackground(self)
--	m_trace:line("pnlDraw.NewBackground")
	
	local iWidth	= self.iSizeX
	local iHeight	= self.iSizeY
	
	-- check for valid arguments when creating the bitmap
	--
	if 0 >= iWidth or 0 >= iHeight then return nil end
	
	-- create a bitmap wide as the client area
	--
	local memDC  = wx.wxMemoryDC()
 	local bitmap = wx.wxBitmap(iWidth, iHeight)
	memDC:SelectObject(bitmap)
	
	-- set the back color
	-- (note that Clear uses the background brush for clearing)
	--
	memDC:SetBackground(self.brushBack)
	memDC:Clear()
	
	-- draw a grid
	--
	if 0 == self.iTotDays then
		
		-- draw a standard grid
		--
		local iXPos, iXInc = 0, 100
		local iYPos, iYInc = 0, 100
		
		memDC:SetPen(self.penGrid)						-- prepare pen for grid with color
		memDC:SetBrush(self.brushBack)					-- check for back brush same colour as background		
		
		for i = iXPos, iWidth, iXInc do
			memDC:DrawLine(i, iYPos, i, iHeight)
		end
		
		for i = iYPos, iHeight, iYInc do
			memDC:DrawLine(iXPos, i, iWidth, i)
		end
		
	else
		
		self:DrawGrid(memDC)
		self:DrawLabels(memDC)
		self:DrawLegenda(memDC)
	end

	return memDC
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.RefreshBackground(self)
--	m_trace:line("pnlDraw.RefreshBackground")
	
	if self.hBackDc then
		self.hBackDc:delete()
		self.hBackDc = nil
	end

	self.hBackDc = self:NewBackground()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.RefreshDrawing(self)
--	m_trace:line("pnlDraw.RefreshDrawing")

	if self.hForeDc then
		self.hForeDc:delete()
		self.hForeDc = nil
	end	

	self.hForeDc = self:NewMemDC()

	-- call Invalidate
	--
	local panel = self.hWindow

	if panel then panel:Refresh(false) end
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.CreatePanel(self, inOwner, inSizeX, inSizeY)
--	m_trace:line("pnlDraw.CreatePanel")

	self.iSizeX = inSizeX
	self.iSizeY = inSizeY
	
	-- create the panel, derived from wxWindow
	-- deriving from wxPanel raises problems on get focus
	-- if not using the wxWANTS_CHARS flag won't respond to
	-- the wxEVT_KEY_DOWN for the 4 cursor arrows, only the 
	-- wxEVT_KEY_UP instead, thus using wxWANTS_CHARS is imperative
	--
	local panel = wx.wxWindow(	inOwner, wx.wxID_ANY,
								wx.wxDefaultPosition, 
								wx.wxSize(inSizeX, inSizeY),
								wx.wxWANTS_CHARS)

	-- responds to events
	--
	panel:Connect(wx.wxEVT_SIZE,		pnlDraw.OnClose)
	panel:Connect(wx.wxEVT_PAINT,		pnlDraw.OnPaint)
	panel:Connect(wx.wxEVT_SIZE,		pnlDraw.OnSize)
	panel:Connect(wx.wxEVT_MOUSEWHEEL,	pnlDraw.OnMouseWheel)
	panel:Connect(wx.wxEVT_KEY_UP,		pnlDraw.OnKeyUp)
	panel:Connect(wx.wxEVT_KEY_DOWN,	pnlDraw.OnKeyDown)

	-- this is necessary to avoid flickering
	-- wxBG_STYLE_CUSTOM deprecated use wxBG_STYLE_PAINT
	--
	panel:SetBackgroundStyle(wx.wxBG_STYLE_PAINT)
	
	-- set not using wxBufferedDC anyway
	-- (shouldn't be needed though)
	--
	panel:SetDoubleBuffered(false)

	-- store interesting members
	--
	self.hWindow = panel

	-- add object window to list of objects
	--
	RoutingTable_Add(panel:GetId(), self)

	-- create the permanent GDI objects with some defaults
	--
	self:SetDefaultColours(	palette.Gray100,
							palette.Gray80, 
							palette.Gray20,
							palette.Firebrick1,
							palette.DeepSkyBlue2,
							palette.MidnightBlue,
							palette.DarkGreen)

	return true
end

-- ----------------------------------------------------------------------------
-- will return the wxWindow handle
--
function pnlDraw.GetHandle(self)
--	m_trace:line("pnlDraw.GetHandle")

	return self.hWindow
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.Refresh(self)
--	m_trace:line("pnlDraw.Refresh")
	
	self:RefreshBackground()
	self:RefreshDrawing()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.Redraw(self)
--	m_trace:line("pnlDraw.Redraw")
	
	if self.bAdaptive then self:AdaptMinMaxTemp() else self:UpdateUnits() end
	
	self:Refresh()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnClose(event)
--	m_trace:line("pnlDraw.OnClose")

	-- simply remove from windows' list
	--
	RoutingTable_Del(event:GetId())
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnPaint(event)
--	m_trace:line("pnlDraw.OnPaint")

	local aSelf = RoutingTable_Get(event:GetId())
	local winDc = wx.wxPaintDC(aSelf.hWindow)

	winDc:Blit(0, 0, aSelf.iSizeX, aSelf.iSizeY, aSelf.hForeDc, 0, 0, wx.wxCOPY)
	winDc:delete()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnSize(event)
--	m_trace:line("pnlDraw.OnSize")

	local size   = event:GetSize()
	local aSelf  = RoutingTable_Get(event:GetId())
	local rcClip = aSelf.rcClip
	
	aSelf.iSizeX = size:GetWidth()
	aSelf.iSizeY = size:GetHeight()
	
	rcClip.left  = m_BoxingX / 2
	rcClip.top   = m_BoxingY / 2
	rcClip.right = aSelf.iSizeX - m_BoxingX / 2
	rcClip.bottom= aSelf.iSizeY - m_BoxingY / 2
	
	aSelf.rcClip = rcClip

	aSelf:UpdateUnits()

	aSelf:Refresh()
end

-- ----------------------------------------------------------------------------
-- handle the mouse wheel, modify the zoom factor
-- if key press CTRL then handles the X otherwise the Y
--
function pnlDraw.OnMouseWheel(event)
--	m_trace:line("pnlDraw.OnMouseWheel")

	local aSelf = RoutingTable_Get(event:GetId())
	local zoomX = aSelf.dZoomX
	local zoomY = aSelf.dZoomY
	
	if not aSelf.vSamples then return end			-- safety check
	
	-- filters with ALT and not CTRL because would mis-interpret gestures on touch screen
	--
	if event:AltDown() then
		
		-- change the X zoom only
		--
		if 0 > event:GetWheelRotation() then
			zoomX = zoomX - m_ZoomStep
		else
			zoomX = zoomX + m_ZoomStep
		end
		
		if m_ZoomMin >= zoomX then zoomX = m_ZoomStep end
	else
		-- change the Y zoom only
		--
		if 0 > event:GetWheelRotation() then
			zoomY = zoomY - m_ZoomStep
		else
			zoomY = zoomY + m_ZoomStep
		end
		
		if m_ZoomMin >= zoomY then zoomY = m_ZoomStep end
	end

	-- store and invalidate
	--
	aSelf.dZoomX = zoomX
	aSelf.dZoomY = zoomY
	
	aSelf:UpdateScaling()

	aSelf:Refresh()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnKeyUp(event)
--	m_trace:line("pnlDraw.OnKeyUp")

	local aSelf = RoutingTable_Get(event:GetId())
	local key	= event:GetKeyCode()
	
	if not aSelf.vSamples then return end			-- safety check
	

end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnKeyDown(event)
--	m_trace:line("pnlDraw.OnKeyDown")

	local aSelf = RoutingTable_Get(event:GetId())
	local key	= event:GetKeyCode()
	
	if not aSelf.vSamples then return end			-- safety check

	if wx.WXK_HOME == key then
		
		aSelf.iOriginX	= m_BoxingX / 2
		aSelf.iOriginY	= aSelf.iUnitY * aSelf.iGridMaxT
		
	elseif wx.WXK_DOWN == key then
		
		aSelf.iOriginY	= aSelf.iOriginY + aSelf.iUnitY
		
	elseif wx.WXK_UP == key then
		
		aSelf.iOriginY	= aSelf.iOriginY - aSelf.iUnitY
		
	elseif wx.WXK_LEFT == key then
		
		aSelf.iOriginX	= aSelf.iOriginX - aSelf.iUnitX
		
	elseif wx.WXK_RIGHT == key then
		
		aSelf.iOriginX	= aSelf.iOriginX + aSelf.iUnitX
	end
	
	event:Skip()
	aSelf:Refresh()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.UpdateUnits(self)
--	m_trace:line("pnlDraw.UpdateUnits")

	local iDays		= self.iTotDays - 1					-- don't count origin
	local iTotDeg	= self.iGridMaxT - self.iGridMinT

	local iSizeX	= self.rcClip.right - self.rcClip.left
	local iSizeY	= self.rcClip.bottom - self.rcClip.top

	local iUnitX	= (iSizeX / iDays)
	local iUnitY	= (iSizeY / iTotDeg)

	-- effective units
	--
	self.iUnitX		= iUnitX
	self.iUnitY		= iUnitY
end

-- ----------------------------------------------------------------------------
-- scale the rows depending on zoom's factor
--
function pnlDraw.UpdateScaling(self)
--	m_trace:line("pnlDraw.UpdateScaling")
	
	if not self.vSamples then return end			-- safety check

	local dZoomY = self.dZoomY
	local iScale
	
	if     1.50 <= dZoomY then iScale =  1
	elseif 1.25 <= dZoomY then iScale =  2
	elseif 1.00 <= dZoomY then iScale =  5
	elseif 0.75 <= dZoomY then iScale = 10
	else		 			   iScale = 15
	end

	self.iScaleTemp = iScale
end

-- ----------------------------------------------------------------------------
-- set up the display of temperatures to match the lowest and highest
--
function pnlDraw.AdaptMinMaxTemp(self)
--	m_trace:line("pnlDraw.AdaptMinMaxTemp")

	if not self.vSamples then
		
		self.iGridMinT = -10		-- minimum temperature shown in grid
		self.iGridMaxT =  50	
		
		self:Refresh()
		return 
	end
	
	self.iGridMinT = self.iLowestT
	self.iGridMaxT = self.iHighestT

	self:UpdateUnits()

	self:Refresh()
end
-- ----------------------------------------------------------------------------
--
function pnlDraw.SetSamples(self, inSamples)
--	m_trace:line("pnlDraw.SetSamples")

	-- assign new samples
	--
	self.vSamples = inSamples
	if not inSamples then
		
		self:Refresh()
		return 
	end

	-- --------------------------
	-- get references for drawing
	--
	local tSamples	= self.vSamples[3]		-- skip identification
	local tByDate
	local iTempY
	local iLowT		=   100
	local iHighT	= - 100

	-- scan all readings for forecast temperatures
	--
	for iList=1, #tSamples do
		
		tByDate = tSamples[iList]
		
		for _, vForecast in next, tByDate[2] do
			
			-- minimum temp
			--
			iTempY = vForecast[2]
			if iTempY < iLowT  then iLowT  = iTempY end
			
			-- maximum temp
			--
			iTempY = vForecast[3]
			if iTempY > iHighT then iHighT = iTempY end
			
		end
	end
	
	-- from readings extract dates' interval
	--
	local iMinDate
	local iMaxDate
	
	tByDate  = tSamples[1][2]
	iMinDate = tByDate[1][1]			-- first
	
	tByDate  = tSamples[#tSamples][2]
	iMaxDate = tByDate[#tByDate][1]		--  last
	
	iMinDate = _todate(iMinDate)
	iMaxDate = _todate(iMaxDate)
	
	-- -------------
	-- store results
	--
	self.sCityId	= self.vSamples[1]
	self.sCity		= self.vSamples[2]

	self.iLowestT	= iLowT				-- minimum temperature read from samples
	self.iHighestT	= iHighT			-- maximum	"	"	"	"	"	"	"
	self.iExcursion	= iHighT - iLowT
	
	self.iMinDate	= iMinDate
	self.iMaxDate	= iMaxDate
	
	-- must include the starting date as well
	--
	self.iTotDays	= utility.DaysInInterval(iMinDate, iMaxDate) + 1
	
	-- this can result in a reset of the origin if a new dataset is loaded
	--
	self.iOriginX	= m_BoxingX / 2
	self.iOriginY	= m_BoxingY / 2 + self.iUnitY * self.iGridMaxT
	
	-- force a redraw
	--
	self:Redraw()
end

-- ----------------------------------------------------------------------------
--
return pnlDraw

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------