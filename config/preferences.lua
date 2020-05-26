--[[
*	Configuration for <console.lua> script.
*
]]

local palette = require("lib.wxX11Palette")

-- ----------------------------------------------------------------------------
--
local tColours = 
{
	["Light"] =
	{
		clrDirListBack	= palette.LightYellow1,
		clrDirListFore	= palette.Firebrick4,
		
		clrBackground	= palette.WhiteSmoke,
		clrGridLines	= palette.AntiqueWhite4,
		clrOrigin		= palette.SlateGray,
		clrMinimum		= palette.Turquoise,
		clrMaximum		= palette.IndianRed,
		
		clrLegenda		= palette.RoyalBlue2,
		clrGridText		= palette.Firebrick2,
		
	},
	
	["Dark"] =
	{
		clrDirListBack	= palette.SteelBlue4,
		clrDirListFore	= palette.WhiteSmoke,
		
		clrBackground	= palette.Gray20,
		clrGridLines	= palette.Gray30,
		clrOrigin		= palette.Thistle4,
		clrMinimum		= palette.MediumPurple2,
		clrMaximum		= palette.PaleVioletRed3,
		
		clrLegenda		= palette.SeaGreen4,
		clrGridText		= palette.Azure2,
	},
}

-- ----------------------------------------------------------------------------
--
local function TodaysDir()
	
	local sRootPath = "C:/USR_2/LUA/WMOQuery/data/"
	local sDataPath
	
	sDataPath = sRootPath .. os.date("%Y/%m/%d", os.time())
	
	return sDataPath
end

-- ----------------------------------------------------------------------------
--
local tConfiguration = 
{
	sCfgVersion	= "0.0.1",
	
	sDefPath 		= TodaysDir(),		-- use today's date or might fail if no data available
	
	iGridMinTemp	= -10,				-- minimum temperature shown in grid
	iGridMaxTemp	=  50,				-- maximum temperature shown in grid
	bAdaptiveTemp 	= false, 			-- adapt grid to samples' temperature values

	tColourScheme	= tColours.Dark,	-- comment this line or set value = nil to use defaults
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
