--[[
*	functions.lua
*
*   .
]]

-- ----------------------------------------------------------------------------
--
local trace 	= require("lib.trace")

-- ----------------------------------------------------------------------------
-- attach tracing to the container
--
local m_trace = trace.new("console")

-- ----------------------------------------------------------------------------
--
local function HornerPolynomial(inArray, inValue)
	m_trace:line("HornerPolynomial")

	if not inArray then return 0 end
	if not inValue then return 0 end

	local iDegree = #inArray
	local result   = inArray[iDegree]

	for i=iDegree - 1, 1, -1 do
		
		result = result * inValue
		result = result + inArray[i]
	end

	return result
end

-- ----------------------------------------------------------------------------
--
local function Call_Horner()
	m_trace:line("functions.Call_Horner")

	local tPolynomial	= { 1, 2, 3, 4, 5 }
	local iValue		= 2

	local dResult = HornerPolynomial(tPolynomial, iValue)

	m_trace:line("functions.Call_Horner result: " .. tostring(dResult))
end


-- ----------------------------------------------------------------------------
-- arithmetic mean of Y value in a set of point
-- return a vactor of 2 points
--
local function _CalcMean(inNormal)
--	m_trace:line("functions._CalcMean")

	if not inNormal then return nil end

	local iDays	= #inNormal
	if 0 == iDays then return nil end

	local dSum	  = 0
	local dMean	  = 0

	for _, point in next, inNormal do
		
		dSum = dSum + point[2]
	end

	dMean = dSum / iDays

	-- note that can't use inDays
	-- might be less because of missing dates
	--
	local iDayStart = inNormal[1][1]
	local iDayEnd	= inNormal[#inNormal][1]
	local tVector 	= { }

	tVector[1] = {iDayStart, dMean}
	tVector[2] = {iDayEnd, 	 dMean}

	return tVector
end
-- ----------------------------------------------------------------------------
--
local function Draw_Mean(inStatistic)
--	m_trace:line("functions.Draw_Mean")

	if not inStatistic then return false end

	-- will register 2 new vectors in inStatistic
	-- 1 for minimum and 1 for maximum
	--
	local tVector

	tVector = _CalcMean(inStatistic.tNormalMin)
	if tVector then inStatistic.tFunctions[#inStatistic.tFunctions + 1] = tVector end

	tVector = _CalcMean(inStatistic.tNormalMax)
	if tVector then inStatistic.tFunctions[#inStatistic.tFunctions + 1] = tVector end

	-- ask for refresh
	--
	return true
end

-- ----------------------------------------------------------------------------
--
local functions =
{
	{Call_Horner, "Horner Polynomial", "Test the Horner Polynomial"},
	{Draw_Mean, "Draw Mean", "Performs the arithmetic mean on both normals"},
}

return functions

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
