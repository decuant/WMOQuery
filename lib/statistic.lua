--[[
*	statistic.lua
*
*   .
]]

-- ----------------------------------------------------------------------------
--
-- local trace 	= require("lib.trace")
local utility 	= require("lib.utility")

local _todate	= utility.StringToDate

local m_OneDay	= (60 * 60 * 24)	-- time_t value

-- ----------------------------------------------------------------------------
-- attach tracing to the container
--
-- local m_trace = trace.new("console")

-------------------------------------------------------------------------------
--
local Statistic		= { }
Statistic.__index	= Statistic

-- ----------------------------------------------------------------------------
-- if the required trace does not exist then allocate a new one
--
function Statistic.new()

	local t =
	{
		tSamples	= nil,		-- data
		
		-- statistic
		--
		iMinDate	= 0,		-- time_t for the very first date
		iMaxDate	= 0,
		iTotDays	= 0,		-- total number of days
		iPeriod		= 0,		-- longest forecast period
		
		tNormalMin 	= { },		-- normalized vector for minimun
		tNormalMax 	= { },		-- idem for maximum
		
		tErrorsMin	= { },		-- forecast errors for minimum
		tErrorsMax	= { },		-- idem for maximum
		
		tSpotList = 
		{
			["ExcursionLow"]	= {0, 0},
			["ExcursionHigh"]	= {0, 0},
			["TemperatureLow"]	= {0, 0},
			["TemperatureHigh"]	= {0, 0},
		},
	}

	return setmetatable(t, Statistic)
end

-- ----------------------------------------------------------------------------
-- 
function Statistic.SetSamples(self, inSamples)
--	m_trace:line("Statistic.SetSamples")
	
	self.tSamples = inSamples
	if not inSamples then return end
	
	local tSamples	= inSamples[3]		-- skip identification
	local tByDate
	local sMinDate
	local sMaxDate
	
	tByDate  = tSamples[1][2]
	sMinDate = tByDate[1][1]			-- first (it's a string)
	
	tByDate  = tSamples[#tSamples][2]
	sMaxDate = tByDate[#tByDate][1]		--  last
	
	-- -------------
	-- store results
	--
	self.iMinDate	= _todate(sMinDate)
	self.iMaxDate	= _todate(sMaxDate)
	self.iTotDays	= utility.DaysInInterval(self.iMinDate, self.iMaxDate) + 1
	
	self:GetNormals()
	self:GetErrors()
	self:GetSpotList()
end

-- ----------------------------------------------------------------------------
-- get the normalized vectors of min and max
--
function Statistic.GetSpotList(self)
--	m_trace:line("Statistic.GetSpotList")

	local tSamples	= self.tSamples
	if not tSamples then return end

	local tSpotList = self.tSpotList	
	local tByDate
	local iTempMin
	local iTempMax
	local iLowT		=   100
	local iHighT	= - 100
	local iTempExcr = 0
	local iMaxExcr	= 0

	tSamples = self.tSamples[3]			-- skip identification	

	-- assume first reading not being a forecast
	--
	for iList=1, #tSamples do
		
		tByDate = tSamples[iList]		-- shortcut
		tByDate = tByDate[2][1]			--
		
		-- min/max
		--
		iTempMin = tByDate[2]
		iTempMax = tByDate[3]
		
		if iTempMin < iLowT  then
			
			iLowT  = iTempMin
			tSpotList.TemperatureLow[1] = tByDate[1]
			tSpotList.TemperatureLow[2] = iTempMin
		end
		
		if iTempMax > iHighT then
			
			iHighT = iTempMax
			tSpotList.TemperatureHigh[1] = tByDate[1]
			tSpotList.TemperatureHigh[2] = iTempMax
		end
		
		-- excursion
		--
		iTempExcr = iTempMax - iTempMin
		if iMaxExcr < iTempExcr then 
			
			iMaxExcr	= iTempExcr 
			
			tSpotList.ExcursionLow[1] = tByDate[1]
			tSpotList.ExcursionLow[2] = iTempMin
			
			tSpotList.ExcursionHigh[1] = tByDate[1]
			tSpotList.ExcursionHigh[2] = iTempMax
		end
	end

	-- convert all dates from text to time_t
	--
	for _, row in next, tSpotList do row[1] = _todate(row[1]) end
end

-- ----------------------------------------------------------------------------
-- get the normalized vectors of min and max
--
function Statistic.GetNormals(self)
--	m_trace:line("Statistic.GetNormals")

	local tSamples	= self.tSamples
	if not tSamples then return end

	local tByDate
	local iDay
	local iPeriod	= 0
	local tNormMin	= { }
	local tNormMax	= { }

	tSamples = tSamples[3]				-- skip identification

	-- cycle all samples
	--
	for iList=1, #tSamples do
		
		tByDate = tSamples[iList]		-- shortcut it
		tByDate	= tByDate[2]			-- shortcut it
		
		-- get the forecast period
		--
		if iPeriod < #tByDate then iPeriod = #tByDate end
		
		-- get the first day of the current row
		--
		iDay = _todate(tByDate[1][1])
		iDay = (iDay - self.iMinDate) / m_OneDay
		
		local iMin = tByDate[1][2]
		
		if 0 < #tNormMin and iDay == tNormMin[#tNormMin][1] then
			
			tNormMin[#tNormMin][2] = ((tNormMin[#tNormMin][2] + iMin) / 2)
		else
			
			tNormMin[#tNormMin + 1] = {iDay, iMin}
		end
		
		local iMax = tByDate[1][3]
		
		if 0 < #tNormMax and iDay == tNormMax[#tNormMax][1] then
			
			tNormMax[#tNormMax][2] = ((tNormMax[#tNormMax][2] + iMax) / 2)
		else
			
			tNormMax[#tNormMax + 1] = {iDay, iMax}
		end	
	end

	-- update statistics
	--
	self.iPeriod  	= iPeriod
	self.tNormalMin = tNormMin
	self.tNormalMax = tNormMax
end

-- ----------------------------------------------------------------------------
-- make an array of readings for the minimum temperature or the maximum
-- the inIndex parameter switch min or max
-- the returned array looks like this
--
--                               **       **
-- [read Y] [fore 1] [fore 2] [fore n]
--          [read Y] [fore 1] [fore 2] [fore n]
--                   [read Y] [fore 1] [fore 2] [fore n]
--                            [read Y] [fore 1] [fore 2] [fore n]
--                                     [read Y] [fore 1] [fore 2] [fore n]
--
function Statistic._MakeArray(self, inIndex, inPeriod)
--	m_trace:line("Statistic._MakeArray")
	
	local tSamples	= self.tSamples
	if not tSamples then return nil end

	if 1 >= inPeriod then return nil end
	
	local tArray	= { }
	local tCurrent	= { }
	local tByDate
	local iLastDay	= -1
	local iCurrDay
	local iWriteIdx	= 1
	
	tSamples = tSamples[3]				-- skip identification

	-- cycle all samples
	--
	for iList=1, #tSamples do
		
		tByDate = tSamples[iList]		-- shortcut it
		tByDate	= tByDate[2]			-- shortcut it
		
		-- get the day
		--
		iCurrDay = _todate(tByDate[1][1])
		iCurrDay = (iCurrDay - self.iMinDate) / m_OneDay
		
		-- update duplicates
		--
		if iLastDay ~= iCurrDay then
			
			tCurrent  = { iCurrDay }
			iWriteIdx = iWriteIdx + 1
			
		else
			iWriteIdx = iWriteIdx + 0
		end
		
		-- these will get offset of 1 on each row
		--
		for i=1, inPeriod do
			
			-- if the period is shorter for this issue date
			-- then store the last good value, might propagate
			--
			if i <= #tByDate then
				
				tCurrent[iWriteIdx + i] = tByDate[i][inIndex]
			else
				
				tCurrent[iWriteIdx + i] = tCurrent[iList + i - 1]
			end
			
		end
		
		tArray[iWriteIdx] = tCurrent
		
		iLastDay = iCurrDay
	end

	return tArray
end

-- ----------------------------------------------------------------------------
--
function Statistic._ComputeErrors(self, inArray, inPeriod)
--	m_trace:line("Statistic._ComputeErrors")
	
	if not inArray then return nil end
	if 1 >= inPeriod then return nil end
	
	-- allocate percentage
	--
	local tPercent = { }
	
	for i=1, inPeriod do tPercent[i] = 0.1 / (i + 1)  end
--	m_trace:table(tPercent)

	local tErrors = { }
	
	-- go from maximum period on
	--
	for iRow = inPeriod, #inArray do
		
		local iDate = inArray[iRow][1]			-- day of column
		local dReal = inArray[iRow][iRow + 1]	-- this is the real reading
		local dSum  = 0.0						-- sum of forecasted values
		local dCurr = 0.0
		
		for i=1, inPeriod do
			
			dCurr = inArray[iRow - 1][iRow + 1]		-- up column
			
			if dCurr ~= dReal then
				
				dSum = dSum + dCurr * tPercent[i]	 -- with weight
			end
		end
		
		-- make the error value
		--
		local dError = (dReal - dSum)
		
		tErrors[#tErrors + 1] = {iDate, dError}
	end

	return tErrors
end

-- ----------------------------------------------------------------------------
--
function Statistic.GetErrors(self)
--	m_trace:line("Statistic.GetErrors")

	if not self.tSamples then return end

	local iPeriod = self.iPeriod
	local tArray

	tArray = self:_MakeArray(2, iPeriod) or { }
	self.tErrorsMin = self:_ComputeErrors(tArray, iPeriod) or { }
	
	tArray = self:_MakeArray(3, iPeriod) or { }
	self.tErrorsMax = self:_ComputeErrors(tArray, iPeriod) or { }
end

-- ----------------------------------------------------------------------------
--
return Statistic

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

