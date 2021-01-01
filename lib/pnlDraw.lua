--[[
*	pnlDraw.lua
*
*   .
]]

local wx		= require("wx")
local trace 	= require("lib.trace")
local utility 	= require("lib.utility")
local statistic	= require("lib.statistic")
local palette	= require("lib.wxX11Palette")

local _format	= string.format
local _floor	= math.floor
local _remove	= table.remove
local _todate	= utility.StringToDate

-- ----------------------------------------------------------------------------
-- attach tracing to the container
--
local m_trace = trace.new("console")

local tDefColours =
{
	clrBackground	= palette.Gray80,
	clrGridLines	= palette.Gray60,
	clrOrigin		= palette.Tan2,
	clrStartDay		= palette.Maroon1,
	clrMinimum		= palette.ForestGreen,
	clrMaximum		= palette.DarkOrchid3,
	clrExcursion	= palette.IndianRed3,
	clrNormals		= palette.Gray20,
	clrError		= palette.Orange1,
	clrFunction		= palette.SteelBlue,
	
	clrLegenda		= palette.Gray40,
	clrGridText		= palette.Tan4,
}

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
local m_BoxingX		= 40				-- deflate amount for window's client rect
local m_BoxingY		= 30				--	"		"		"		"		"	"
local m_OneDay		= (60 * 60 * 24)	-- time_t value
local m_ZoomStep	= 0.025				-- stepping for zoom
local m_ZoomMin		= 0.0075			-- minimum for zoom
local m_PenNull    = wx.wxPen(palette.Black, 1, wx.wxTRANSPARENT)
-- local m_BrushNull  = wx.wxBrush(palette.Black, wx.wxTRANSPARENT)
local m_defFont		= "Lucida Console"

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
		iScaleDays	= 7,		-- scaling for days
		iScaleTemp	= 5,		-- scaling factor for temperatures
		dZoomX		= 1.00,
		dZoomY		= 1.00,
		
		iGridMinT	= -10,		-- minimum temperature shown in grid
		iGridMaxT	=  50,		-- maximum temperature shown in grid
		bAdaptive 	= false,	-- adapt grid to samples' temperature values
		iDrawTemp	= 3,		-- 1 minimum, 2 maximum, 3 both
		iDrawOption = 0,		-- 0 draw both, 1 details, 2 normals
		iDrawErrors	= 0,		-- 0 none, 1 minimum, 2 maximum, 3 both
		bRasterOp	= false,	-- use a raster xor
		
		hBackDc		= nil,		-- background device context
		hForeDc		= nil,		-- device context for the window
		
		tColors		= tDefColours,		
		sFontFace	= m_defFont,
		iFntSize	= 11,		-- font size for legenda
		fntLegenda	= nil,		-- font for the legenda
		fntGridDate	= nil,		-- font for dates on grid		
		
		iLineSz 	= 3,		-- size of line drawn
		penGrid		= nil,		-- pen for the grid
		penOrigin	= nil,		-- pen for origin
		penStart	= nil,		-- pen for start day
		penMinT		= nil,		-- pen for MIN temperature
		penMinTS	= nil,
		penMaxT		= nil,		-- pen for MAX temperature
		penMaxTs	= nil,
		penNormals	= nil,
		penErrors	= nil,
		penFunction = nil,
		
		brushBack	= nil,		-- brush for background		
		brExcursion = nil,
		
		-- details
		--
		tSamples	= nil,		-- data
		sCity		= "",		-- shortcut for city's name
		sCityId		= "",		-- shortcut for city's id
		tStatistic	= statistic.new(),
		tLegenda	= { },
	}

	return setmetatable(t, pnlDraw)
end

-- ----------------------------------------------------------------------------
-- will return the wxWindow handle
--
function pnlDraw.GetHandle(self)
--	m_trace:line("pnlDraw.GetHandle")

	return self.hWindow
end

-- ----------------------------------------------------------------------------
-- check validity of samples in statistic module
--
function pnlDraw.IsValid(self)
--	m_trace:line("pnlDraw.IsValid")

	return (self.tSamples and 0 < self.tStatistic.iTotDays)
end

-- ----------------------------------------------------------------------------
-- restore defaults for scaling and zooming
--
function pnlDraw.ResetView(self)
--	m_trace:line("pnlDraw.ResetView")

	self.iScaleDays	= 7		-- scaling for days
	self.iScaleTemp	= 5		-- scaling factor for temperatures
	self.dZoomX		= 1.00
	self.dZoomY		= 1.00
	
	-- update units for drawing
	--
	self:UpdateUnits()
	
	-- this can result in a reset of the origin if a new dataset is loaded
	--
	self.iOriginX	= m_BoxingX / 2
	self.iOriginY	= m_BoxingY / 2 + self.iUnitY * self.iGridMaxT
	
	-- force a redraw
	--
	self:Redraw()
end

-- ----------------------------------------------------------------------------
-- get a table of strings describing forecast values
--
function pnlDraw.SetLegenda(self) 
--	m_trace:line("pnlDraw.SetLegenda")

	local tLegenda  = { }
	local tStats	= self.tStatistic
	local tSpotList = tStats.tSpotList
	
	tLegenda[#tLegenda + 1] =        ("City name:  " .. tStats.sReference)
	tLegenda[#tLegenda + 1] =        ("Station ID: " .. tStats.sIdentity)
	tLegenda[#tLegenda + 1] = _format("Lowest T:   %d C", tSpotList.TemperatureLow[2])
	tLegenda[#tLegenda + 1] = _format("Highest T:  %d C", tSpotList.TemperatureHigh[2])

	if 0 <= tSpotList.ExcursionLow[1] then
		
		local iExcursion = tSpotList.ExcursionHigh[2] - tSpotList.ExcursionLow[2]
		
		tLegenda[#tLegenda + 1] = _format("Excursion:  %d C", iExcursion)
		tLegenda[#tLegenda + 1] = os.date("         :  %A %B %d %Y", tSpotList.ExcursionLow[1])
	end

	tLegenda[#tLegenda + 1] = os.date("First day:  %A %B %d %Y", tStats.iMinDate)
	tLegenda[#tLegenda + 1] = os.date("Last day:   %A %B %d %Y", tStats.iMaxDate)
	tLegenda[#tLegenda + 1] = _format("Forecast:   %d days", tStats.iPeriod)
	tLegenda[#tLegenda + 1] = _format("Tot. days:  %d", tStats.iTotDays)

	-- store result
	--
	self.tLegenda = tLegenda
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
-- makes an array remapped to screen
--
function pnlDraw.RemapArray(self, inPointList)
--	m_trace:line("pnlDraw.RemapArray")

	local tDrawPoints	  = { }
	local xCoord, yCoord
	local xRemap, yRemap
	
	for iList=1, #inPointList do
		
		xCoord = inPointList[iList][1]
		yCoord = inPointList[iList][2]
		
		xRemap, yRemap = self:MapToOrigin(xCoord, yCoord)
		
		tDrawPoints[iList] = {xRemap, yRemap}		-- collect GUI points
	end
	
	return tDrawPoints
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.CreateGDIObjs(self)
--	m_trace:line("pnlDraw.CreateGDIObjs")

	local tColors = self.tColors
	
	-- when creating a pen wider than 2 wxWidgets will try to round it
	-- thus showing a little line at both ends when set at 3 pixels wide.
	-- with CAP_BUTT wxWidgets will square the end
	--
	self.penOrigin	= wx.wxPen(tColors.clrOrigin, 2, wx.wxSOLID)
	self.penOrigin:SetCap(wx.wxCAP_BUTT)

	self.penGrid	= wx.wxPen(tColors.clrGridLines, 1, wx.wxSOLID)
	self.penStart	= wx.wxPen(tColors.clrStartDay, self.iLineSz, wx.wxSOLID)
	self.penMinTS	= wx.wxPen(tColors.clrMinimum, self.iLineSz, wx.wxSOLID)
	self.penMaxTS	= wx.wxPen(tColors.clrMaximum, self.iLineSz, wx.wxSOLID)
	self.penMinTD	= wx.wxPen(tColors.clrMinimum, self.iLineSz, wx.wxDOT)
	self.penMaxTD	= wx.wxPen(tColors.clrMaximum, self.iLineSz, wx.wxDOT)
	self.penNormals = wx.wxPen(tColors.clrNormals, self.iLineSz + 2, wx.wxSOLID)
	self.penErrors	= wx.wxPen(tColors.clrError, self.iLineSz + 1, wx.wxSOLID)
	self.penFunction= wx.wxPen(tColors.clrFunction, self.iLineSz, wx.wxSOLID)

	self.brushBack	= wx.wxBrush(tColors.clrBackground, wx.wxSOLID)
	self.brExcursion= wx.wxBrush(tColors.clrExcursion, wx.wxBRUSHSTYLE_FDIAGONAL_HATCH)
	
	self.fntLegenda = wx.wxFont( self.iFntSize,
								 wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL,
								 wx.wxFONTWEIGHT_BOLD, 
								 false, self.sFontFace)

	self.fntGridDate= wx.wxFont( self.iFntSize - 1, 
								 wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL,
								 wx.wxFONTWEIGHT_LIGHT, 
								 false, self.sFontFace)

--	self.fntIssueDate= wx.wxFont(9, wx.wxFONTFAMILY_MODERN, wx.wxFONTSTYLE_NORMAL,
--								 wx.wxFONTWEIGHT_LIGHT, false, "DejaVu Sans Mono", 
--								 wx.wxFONTENCODING_SYSTEM)
end

-- ----------------------------------------------------------------------------
-- if no color table specified then use the defaults
--
function pnlDraw.SetDefaultColours(self, inTable)
--	m_trace:line("pnlDraw.SetDefaultColours")

	self.tColors = inTable or tDefColours

	self:CreateGDIObjs()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.SetDrawOpts(self, inLineSize, inFontSize, inFontFace, inDrawTemp, inDrawOption, inDrawErrors, inRaster)
--	m_trace:line("pnlDraw.SetDrawOpts")

	local iLineSize = inLineSize or 3
	local iFontSize = inFontSize or 11
	local sFontFace = inFontFace or m_defFont
	local iDrawTemp = inDrawTemp or 3
	local iDrawOpt  = inDrawOption or 1
	local iDrawErrors= inDrawErrors or 0
	local bRaster   = inRaster or false
	
	if 0 >= iLineSize then iLineSize = 1 end
	if 5 >= iFontSize then iFontSize = 6 end
	if 0 >= iDrawTemp then iDrawTemp = 3 end
	if 4 <= iDrawTemp then iDrawTemp = 3 end
	
	self.iLineSz	= iLineSize
	self.iFntSize	= iFontSize
	self.sFontFace	= sFontFace
	self.iDrawTemp	= iDrawTemp
	self.iDrawOption= iDrawOpt
	self.iDrawErrors= iDrawErrors
	self.bRasterOp	= bRaster
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
	if self:IsValid() then
		
		if inAdaptive then self:AdaptMinMaxTemp() else self:UpdateUnits() end
	end
end

-- ----------------------------------------------------------------------------
-- set the labels for dates and temperatures on the grid
--
function pnlDraw.DrawLabels(self, inDc)
--	m_trace:line("pnlDraw.DrawLabels")

	local iXPos, iXInc = self.iOriginX, self.iUnitX * self.dZoomX * self.iScaleDays
	local iYPos, iYInc = self.iOriginY, self.iUnitY * self.dZoomY * self.iScaleTemp

	local iRcLeft	= self.rcClip.left
	local iRcTop	= self.rcClip.top
	local iRcRight	= self.rcClip.right
	local iRcBottom	= self.rcClip.bottom
	local iExtX, iExtY

	-- switch font
	--
	inDc:SetFont(self.fntGridDate)
	inDc:SetTextForeground(self.tColors.clrGridText)

	iExtX, iExtY = inDc:GetTextExtent("00")

	-- columns/days
	--
	local iMinDate	= self.tStatistic.iMinDate
	local iDays		= self.iScaleDays * m_OneDay
	local iDayRef	= iMinDate - iDays
	local sDayRef
	
	for i = iXPos - (iExtX / 2), iRcRight, iXInc do
		
		iDayRef = iDayRef + iDays
		
		-- when scaling is 30 days then it gains
		-- a -1 error, so we correct it
		--
--		if (m_OneDay == (iDayRef + m_OneDay) % self.iMinDate) then 
--			iDayRef = iDayRef + m_OneDay
--		end
		
		sDayRef = os.date("%d", iDayRef)				-- %d here means 'day'
		
		inDc:DrawText(sDayRef, i, iRcBottom)
	end

	-- prepare for drawing temps
	--
	iExtX, iExtY = inDc:GetTextExtent("-00")
	
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
	inDc:SetTextForeground(self.tColors.clrLegenda)
	
	local tLegenda	= self.tLegenda
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

	local iXPos, iXInc = self.iOriginX, self.iUnitX * self.dZoomX * self.iScaleDays
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
-- draw a rectangle remapped
--
function pnlDraw.DrawSpot(self, inDc, inCenterX, inCenterY, inWidth, inLenght)
--	m_trace:line("pnlDraw.DrawSpot")
	
	local x1, y1 = self:MapToOrigin(inCenterX, inCenterY)
	
	inDc:DrawRectangle(x1 - (inWidth /2), y1 - (inLenght /2), inWidth, inLenght)
end

-- ----------------------------------------------------------------------------
-- draw a circle remapping center x,y
--
function pnlDraw.DrawCircle(self, inDc, inCenterX, inCenterY, inRadius)
--	m_trace:line("pnlDraw.DrawCircle")
	
	local x, y = self:MapToOrigin(inCenterX, inCenterY)

	inDc:DrawCircle(x, y, inRadius)
end

-- ----------------------------------------------------------------------------
-- draw all dates, detailed view
--
function pnlDraw.DrawDetails(self, inDc)
--	m_trace:line("pnlDraw.DrawDetails")
	
	if not self:IsValid() then return end
	
	local tSamples	= self.tSamples
	local iLineSz	= self.iLineSz
	local iDrawTemp	= self.iDrawTemp	-- which temp to draw
	local tByDate
	local iMinDate	= self.tStatistic.iMinDate
	local iStartDay
	local penMinT
	local penMaxT
	
	tSamples = tSamples[3]				-- skip identification
	inDc:SetBrush(self.brushBack)
	
	-- cycle all samples
	--
	for iList=1, #tSamples do
		
		tByDate = tSamples[iList]		-- shortcut it
		tByDate	= tByDate[2]			-- shortcut it
		
		-- toggle pens at each date (SOLID/DASH)
		-- better starting with the dash one
		--
		if 0 == iList % 2 then
			
			penMinT = self.penMinTS
			penMaxT = self.penMaxTS
		else
			
			penMinT = self.penMinTD
			penMaxT = self.penMaxTD
		end
		
		-- get the first day of the current row
		-- the other days are sequential
		--
		iStartDay = _todate(tByDate[1][1])
		iStartDay = (iStartDay - iMinDate) / m_OneDay
		
		-- one cycle for the min and another for the max
		--
		for iField=2, 3 do
			
			if 	(2 == iField and 2 ~= iDrawTemp) or
				(3 == iField and 1 ~= iDrawTemp) then
			
				local tDrawPoints 	= { }
				local iDayX 		= iStartDay - 1
				local iTempY
				
				for i, vForecast in next, tByDate do
					
					iDayX  = iDayX + 1
					iTempY = vForecast[iField]
					
					tDrawPoints[i] = {iDayX, iTempY}
				end
				
				-----------------
				-- draw
				--
				-- use different pen for min or max
				--
				if 2 == iField then inDc:SetPen(penMinT) else inDc:SetPen(penMaxT) end
				
				inDc:DrawLines(self:RemapArray(tDrawPoints))
				
				-- spot first date with a small circle
				--
				inDc:SetPen(self.penStart)
				
				self:DrawCircle(inDc, tDrawPoints[1][1], tDrawPoints[1][2], iLineSz + 1)
				
				-- spot last date with a small rectangle
				--
				-- self:DrawSpot(inDc, tDrawPoints[#tDrawPoints][1], tDrawPoints[#tDrawPoints][2], 6, 6)
			end
		end
	end
end

-- ----------------------------------------------------------------------------
-- draw spline of normalized vectors
--
function pnlDraw.DrawNormalized(self, inDc)
--	m_trace:line("pnlDraw.DrawNormalized")
	
	if not self:IsValid() then return end
	
	local tStats	= self.tStatistic
	local iDrawTemp	= self.iDrawTemp	-- which temp to draw
	
	-- check, a spline needs 4 points at least
	--
	if 4 > #tStats.tNormalMin then return end
	
	-- draw here
	--
	inDc:SetBrush(self.brushBack)
	inDc:SetPen(self.penNormals)

	if 2 ~= iDrawTemp then inDc:DrawSpline(self:RemapArray(tStats.tNormalMin)) end
	if 1 ~= iDrawTemp then inDc:DrawSpline(self:RemapArray(tStats.tNormalMax)) end
end

-- ----------------------------------------------------------------------------
-- draw spline of errors over normalized vectors
--
function pnlDraw.DrawErrors(self, inDc)
--	m_trace:line("pnlDraw.DrawNormalized")
	
	if not self:IsValid() then return end
	
	if 0 == self.iDrawErrors then return end

	local tStats = self.tStatistic
	local iOpt 	 = self.iDrawErrors
	
	-- check, a spline needs 4 points at least
	--	
	if 4 > #tStats.tErrorsMin then return end	

	-- draw here
	--
	inDc:SetBrush(self.brushBack)
	inDc:SetPen(self.penErrors)

	if 2 ~= iOpt then inDc:DrawSpline(self:RemapArray(tStats.tErrorsMin)) end
	if 1 ~= iOpt then inDc:DrawSpline(self:RemapArray(tStats.tErrorsMax)) end
end

-- ----------------------------------------------------------------------------
-- draw spline of functions
--
function pnlDraw.DrawFunctions(self, inDc)
--	m_trace:line("pnlDraw.DrawFunctions")

	if not self:IsValid() then return end

	-- draw here
	--
	inDc:SetBrush(self.brushBack)
	inDc:SetPen(self.penFunction)

	local tStats = self.tStatistic

	for _, vector in next, tStats.tFunctions do
		
		if 4 > #vector then
			
			inDc:DrawLines(self:RemapArray(vector))
		else
			
			inDc:DrawSpline(self:RemapArray(vector))
		end
	end
end

-- ----------------------------------------------------------------------------
-- draw the spot list
--
function pnlDraw.DrawSpotList(self, inDc)
--	m_trace:line("pnlDraw.DrawSpotList")

	if not self:IsValid() then return end

	inDc:SetBrush(self.brExcursion)
	inDc:SetPen(m_PenNull)
	
	local dHalfX  = 1.5 * (self.iUnitX * self.dZoomX)
	local dHalfY  = 2.5 * (self.iUnitY * self.dZoomY)
	
	local tSpotList = self.tStatistic.tSpotList
	local iMinDate	= self.tStatistic.iMinDate
	local iDrawTemp	= self.iDrawTemp	-- which temp to draw
	
	for tag, row in pairs(tSpotList) do
		
		if 	(2 ~= iDrawTemp and tag:find("Low")) or
			(1 ~= iDrawTemp and tag:find("High")) then
			
			local iDay = (row[1] - iMinDate) / m_OneDay
			
			self:DrawSpot(inDc, iDay, row[2], dHalfX, dHalfY)
		end
	end
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.NewMemDC(self)
--	m_trace:line("pnlDraw.NewMemDC")

	local iWidth  = self.iSizeX
	local iHeight = self.iSizeY

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

	-- quit if nothing to do
	--
	if not self:IsValid() then return memDC end

	-- draw the points
	--	
	local oldRaster	= memDC:GetLogicalFunction()
	local iOpt 		= self.iDrawOption

	if self.bRasterOp then memDC:SetLogicalFunction(wx.wxAND_REVERSE) end

	self:DrawSpotList(memDC)
	
	if 2 ~= iOpt then self:DrawDetails(memDC) end
	if 1 ~= iOpt then self:DrawNormalized(memDC) end
	
	self:DrawErrors(memDC)
	
	if self.bRasterOp then memDC:SetLogicalFunction(oldRaster) end
	
	self:DrawFunctions(memDC)

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
	if not self:IsValid() then
		
		-- draw a standard grid
		--
		local iXPos, iXInc = 0, (iWidth / 20)
		local iYPos, iYInc = 0, (iHeight /20)
		
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
	self:CreateGDIObjs()
	
	return true
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
	
	if not aSelf:IsValid() then return end			-- safety check
	
	-- filters with ALT and not CTRL because would mis-interpret gestures on touch screen
	--
	if event:AltDown() then
		
		-- change the X zoom only
		--
		if 0 > event:GetWheelRotation() then
			
			aSelf:NewZoomFromKey(wx.WXK_LEFT)
		else
			
			aSelf:NewZoomFromKey(wx.WXK_RIGHT)
		end
	else
		-- change the Y zoom only
		--
		if 0 > event:GetWheelRotation() then
			
			aSelf:NewZoomFromKey(wx.WXK_DOWN)
		else
			
			aSelf:NewZoomFromKey(wx.WXK_UP)
		end
	end

	-- Update display
	--
	aSelf:Refresh()
end

-- ----------------------------------------------------------------------------
-- handle drawing's options from keyboard
--
function pnlDraw.OnKeyUp(event)
--	m_trace:line("pnlDraw.OnKeyUp")

	local aSelf 	= RoutingTable_Get(event:GetId())
	local key		= event:GetKeyCode() - 48
	local bRefresh 	= false

	if not aSelf:IsValid() then return end			-- safety check
	
	-- necessary to mimic the keyboard's layout
	--
	if 0 == key then key = 10 end					
	
	-- select which option to change
	--
	if 1 <= key and 3 >= key then
		
		if key ~= aSelf.iDrawTemp then 
			
			aSelf.iDrawTemp = key
			bRefresh = true
		end
		
	elseif 4 <= key and 6 >= key then
		
		key = key - 3
		if key ~= aSelf.iDrawOption then 
			
			aSelf.iDrawOption = key
			bRefresh = true
		end
		
	elseif 7 <= key and 10 >= key then
		
		key = key - 7
		if key ~= aSelf.iDrawErrors then 
			
			aSelf.iDrawErrors = key
			bRefresh = true
		end
	end

	-- Update display
	--
	if bRefresh then aSelf:Refresh() end
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.NewOriginFromKey(self, inKey)
--	m_trace:line("pnlDraw.NewOriginFromKey")

	if wx.WXK_HOME == inKey then
		
		self.iOriginX	= (m_BoxingX / 2)
		self.iOriginY	= (m_BoxingY / 2) + (self.iUnitY * self.iGridMaxT)
		
	elseif wx.WXK_DOWN == inKey then
		
		self.iOriginY	= self.iOriginY - self.iUnitY
		
	elseif wx.WXK_UP == inKey then
		
		self.iOriginY	= self.iOriginY + self.iUnitY
		
	elseif wx.WXK_LEFT == inKey then
		
		self.iOriginX	= self.iOriginX + self.iUnitX
		
	elseif wx.WXK_RIGHT == inKey then
		
		self.iOriginX	= self.iOriginX - self.iUnitX
	end
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.NewZoomFromKey(self, inKey)
--	m_trace:line("pnlDraw.NewZoomFromKey")

	local zoomX = self.dZoomX
	local zoomY = self.dZoomY

	if wx.WXK_HOME == inKey then
		
		zoomX = 1.0
		zoomY = 1.0
		
	elseif wx.WXK_DOWN == inKey then
		
		zoomY = zoomY - m_ZoomStep
		
	elseif wx.WXK_UP == inKey then
		
		zoomY = zoomY + m_ZoomStep
		
	elseif wx.WXK_LEFT == inKey then
		
		zoomX = zoomX - m_ZoomStep
		
	elseif wx.WXK_RIGHT == inKey then
		
		zoomX = zoomX + m_ZoomStep
	end

	-- sanity check
	--
	if m_ZoomMin >= zoomX then zoomX = m_ZoomStep end
	if m_ZoomMin >= zoomY then zoomY = m_ZoomStep end

	-- store and update
	--
	self.dZoomX = zoomX
	self.dZoomY = zoomY
	
	self:UpdateScaling()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.OnKeyDown(event)
--	m_trace:line("pnlDraw.OnKeyDown")

	local aSelf = RoutingTable_Get(event:GetId())
	local key	= event:GetKeyCode()
	local bAlt	= event:AltDown()
	
	if not aSelf:IsValid() then return end			-- safety check

	if bAlt then aSelf:NewZoomFromKey(key)
	else 		 aSelf:NewOriginFromKey(key)
	end
	
	-- Update display
	--
	aSelf:Refresh()
end

-- ----------------------------------------------------------------------------
--
function pnlDraw.UpdateUnits(self)
--	m_trace:line("pnlDraw.UpdateUnits")

	if not self:IsValid() then return end

	local iDays		= self.tStatistic.iTotDays - 1					-- don't count origin
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

	local iScaleX
	local iScaleY
	local dZoomX = self.dZoomX
	local dZoomY = self.dZoomY
	
	-- Days
	--
	if     2.00 <= dZoomX then iScaleX =  1
	elseif 1.50 <= dZoomX then iScaleX =  2
	elseif 1.00 <= dZoomX then iScaleX =  7
	elseif 0.50 <= dZoomX then iScaleX = 14
	else		 			   iScaleX = 30
	end
	
	-- Temperatures
	--
	if     1.50 <= dZoomY then iScaleY =  1
	elseif 1.25 <= dZoomY then iScaleY =  2
	elseif 1.00 <= dZoomY then iScaleY =  5
	elseif 0.75 <= dZoomY then iScaleY = 10
	else		 			   iScaleY = 15
	end

	-- update
	--
	self.iScaleDays = iScaleX
	self.iScaleTemp = iScaleY
end

-- ----------------------------------------------------------------------------
-- set up the display of temperatures to match the lowest and highest
--
function pnlDraw.AdaptMinMaxTemp(self)
--	m_trace:line("pnlDraw.AdaptMinMaxTemp")

	if not self:IsValid() then
		
		self.iGridMinT = -10		-- minimum temperature shown in grid
		self.iGridMaxT =  50	
		
		self:Refresh()
		return 
	end
	
	local tSpotList = self.tStatistic.tSpotList
	
	self.iGridMinT = tSpotList.TemperatureLow[2]
	self.iGridMaxT = tSpotList.TemperatureHigh[2]

	self:UpdateUnits()
	self:Refresh()
end

-- ----------------------------------------------------------------------------
-- recreate statistics
--
function pnlDraw.SetSamples(self, inSamples)
--	m_trace:line("pnlDraw.SetSamples")

	-- recreate the statistics and forget old values
	--
	self.tStatistic = statistic.new()
	
	-- assign new samples
	--
	self.tSamples = inSamples

	-- make the statistics
	--
	self.tStatistic:ProcessAll(inSamples)

	-- will reset all values for zooming and pan/tilt
	-- update the units
	-- call a redraw
	--
	self:SetLegenda()
	self:ResetView()
end

-- ----------------------------------------------------------------------------
--
return pnlDraw

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
