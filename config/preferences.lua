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
		clrHighLight	= palette.Orange,
		
		clrLegenda		= palette.RoyalBlue2,
		clrGridText		= palette.Firebrick2,
	},
	
	["Dark"] =
	{
		clrDirListBack	= palette.SteelBlue4,
		clrDirListFore	= palette.WhiteSmoke,
		
		clrBackground	= palette.Gray30,
		clrGridLines	= palette.Gray40,
		clrOrigin		= palette.Thistle1,
		clrMinimum		= palette.MediumPurple2,
		clrMaximum		= palette.PaleVioletRed3,
		clrExcursion	= palette.Yellow1,
		clrHighLight	= palette.Gray20,
		
		clrLegenda		= palette.WhiteSmoke,
		clrGridText		= palette.Azure2,
	},
	
	["Black"] =
	{
		clrDirListBack	= palette.Gray20,
		clrDirListFore	= palette.LightSteelBlue1,
		
		clrBackground	= palette.Gray20,
		clrGridLines	= palette.Gray40,
		clrOrigin		= palette.Snow1,
		clrMinimum		= palette.Turquoise3,
		clrMaximum		= palette.Firebrick2,
		clrExcursion	= palette.Yellow1,
		clrHighLight	= palette.Gray80,
		
		clrLegenda		= palette.LightSteelBlue1,
		clrGridText		= palette.Gray40,	
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
	sCfgVersion		= "0.0.3",
	
	sDefPath 		= "data/2020",		-- use today's date or might fail if no data available
	
	iGridMinTemp	= -5,				-- minimum temperature shown in grid
	iGridMaxTemp	=  50,				-- maximum temperature shown in grid
	bAdaptiveTemp 	= false, 			-- adapt grid to samples' temperature values
	iDrawOption		= 3,				-- 1 details, 2 normals, 3 both
	
	tColourScheme	= tColours.Black,	-- comment this line or set value = nil to use defaults
	iLineSize		= 2,				-- size of line when drawing
	iFontSize		= 8,				-- font size for the legenda
	sFontFace		= "Dejavu Sans Mono",
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
