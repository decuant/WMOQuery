--[[
*	dlgSample
*
*   Import a file of compiled dataset, create a list of city names
*	and ask the user to make a choice.
*
*	Returns a table of compiled data relative to one station only.
*
*	Reference to compile.lua [see compiled data format].
]]

local wx		= require("wx")
-- local trace 	= require("lib.trace")

-- ----------------------------------------------------------------------------
--
local function OnSelectCityDialog(inOwner, inFilename)
--	trace.line("OnSelectCityDialog")
	
	-- import table with multiple stations
	--
	local tSamples = dofile(inFilename)
	if not tSamples then return nil end

	-- as aid sort alphabetically by station name
	--
	table.sort(tSamples, function(x, y) return x[2] < y[2] end)
	
	-- make vector of strings for dialog
	--
	local tStrings = { }
	
	for i, v in next, tSamples do tStrings[i] = v[2] end

	-- get user input
	--
	local iIndex = wx.wxGetSingleChoiceIndex("Station name", "Choice of dataset", tStrings, inOwner)

	if -1 == iIndex then return nil end

	-- return master table sub-index
	--
	return tSamples[iIndex + 1]
end

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

local dlgSamples =
{
	SelectCity = OnSelectCityDialog
}

return dlgSamples

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
