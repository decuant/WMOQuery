--[[
*	Acccesssory functions.
*
*   .
]]

local _format	= string.format
local _strrep	= string.rep
local _floor	= math.floor
local _date		= os.date
local _time		= os.time

-- ----------------------------------------------------------------------------
-- check for memory usage and call a collector walk
-- a megabyte measure is used instead of kilos to reduce
-- the trace messaging using a gross unit of measure
--
local function OnGarbageTest(inMaxLevel, inDoCollect)

	local iLimit = inMaxLevel or 5
	local iKilo  = collectgarbage("count")
	local iMega  = _floor(iKilo / 1024)

	if iMega > inMaxLevel  then	
		
		if inDoCollect then collectgarbage("collect") end
		
		return iMega, _format("Memory: [%3d Mb] %s", iMega, _strrep("•", iMega))
	end
	
	return iMega, nil
end

-- ----------------------------------------------------------------------------
-- convert a string to an integer date value
-- model string format is ISO 8601  yyyy-mm-dd
--
local function OnStringToDate(inString)

	if not inString then return 0 end
	
	local tParts = { }
	local iDate
	
	for sValue in inString:gmatch("%d+") do tParts[#tParts + 1] = sValue end
	
	if 2 < #tParts then
		
		iDate = _time({ year = tParts[1], month = tParts[2], day = tParts[3] })
		return iDate
	end
	
	return -1
end

-- ----------------------------------------------------------------------------
-- convert a string to an integer date value
-- model string format is ISO 8601  yyyy-mm-dd hh:mm:ss
--
local function OnStringToFullDate(inString)

	if not inString then return 0 end
	
	local tParts = { }
	local iDate
	
	for sValue in inString:gmatch("%d+") do tParts[#tParts + 1] = sValue end
	
	if 5 < #tParts then
		
		iDate = os.time({ year = tParts[1], month = tParts[2], day = tParts[3],
						  hour = tParts[4], min   = tParts[5], sec = tParts[6],
						  dst  = true })
		return iDate
	end

	return -1
end

-- ----------------------------------------------------------------------------
-- return the number of days in interval
--
local function OnDaysInInterval(inDateFrom, inDateTo)
	
	if not inDateFrom or not inDateTo then return 0 end
	
	if inDateTo < inDateFrom then inDateFrom, inDateTo = inDateTo, inDateFrom end
	
	local iDiff = inDateTo - inDateFrom
	
	if 0 >= iDiff then return 0 end
	
	iDiff = _floor(iDiff / (60 * 60 * 24))
	
	return iDiff
end

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

local utility =
{
	GarbageTest		= OnGarbageTest,
	StringToDate	= OnStringToDate,
	StringToFullDate= OnStringToFullDate,
	DaysInInterval	= OnDaysInInterval,
}

return utility

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

