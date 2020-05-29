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
		clrGridLines	= palette.Wheat,
		clrOrigin		= palette.SlateGray,
		clrMinimum		= palette.Turquoise,
		clrMaximum		= palette.IndianRed,
		clrExcursion	= palette.Gray0,
		
		clrLegenda		= palette.RoyalBlue2,
		clrGridText		= palette.Firebrick2,
	},
	
	["Dark"] =
	{
		clrDirListBack	= palette.SteelBlue4,
		clrDirListFore	= palette.WhiteSmoke,
		
		clrBackground	= palette.Gray20,
		clrGridLines	= palette.Gray30,
		clrOrigin		= palette.Thistle1,
		clrMinimum		= palette.MediumPurple2,
		clrMaximum		= palette.PaleVioletRed3,
		clrExcursion	= palette.Azure2,
		
		clrLegenda		= palette.SeaGreen4,
		clrGridText		= palette.Azure2,
	},
}

-- ----------------------------------------------------------------------------
-- build a relative directory starting from "data/"
--
local function TodaysDir()

	return os.date("data/%Y/%m/%d", os.time())
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

	tColourScheme	= tColours.Light,	-- comment this line or set value = nil to use defaults
	iLineSize		= 20,				-- size of line when drawing
	iFontSize		= 7,				-- font size for the legenda
	sFontFace		= "Source Code Pro",
	
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
