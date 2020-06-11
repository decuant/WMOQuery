--[[
*	Configuration for <console.lua> script.
*
]]

local palette = require("lib.wxX11Palette")

-- ----------------------------------------------------------------------------
--
local tColours = 
{
	["pastel"] =
	{
		clrDirListBack	= palette.Cornsilk2,
		clrDirListFore	= palette.Firebrick4,
		
		clrBackground	= palette.WhiteSmoke,
		clrGridLines	= palette.Wheat,
		clrOrigin		= palette.SkyBlue4,
		clrStartDay		= palette.Gray20,
		clrMinimum		= palette.Turquoise,
		clrMaximum		= palette.IndianRed,
		clrExcursion	= palette.Gray0,
		clrNormals		= palette.LightGoldenrod4,
		clrError		= palette.Azure3,
		
		clrLegenda		= palette.Chartreuse4,
		clrGridText		= palette.SkyBlue3,
	},
	
	["blueprint"] =
	{
		clrDirListBack	= palette.Purple4,
		clrDirListFore	= palette.Orange1,
		
		clrBackground	= palette.RoyalBlue4,
		clrGridLines	= palette.SteelBlue4,
		clrOrigin		= palette.Brown,
		clrStartDay		= palette.Khaki3,
		clrMinimum		= palette.DodgerBlue2,
		clrMaximum		= palette.PaleVioletRed3,
		clrExcursion	= palette.Yellow1,
		clrNormals		= palette.Gray10,
		clrError		= palette.DarkOrchid,
		
		clrLegenda		= palette.Azure3,
		clrGridText		= palette.WhiteSmoke,
	},
	
	["blackboard"] =
	{
		clrDirListBack	= palette.Gray10,
		clrDirListFore	= palette.Aquamarine3,
		
		clrBackground	= palette.Gray0,
		clrGridLines	= palette.Gray10,
		clrOrigin		= palette.Orange,
		clrStartDay		= palette.Yellow1,
		clrMinimum		= palette.CadetBlue2,
		clrMaximum		= palette.IndianRed3,
		clrExcursion	= palette.DeepPink1,
		clrNormals		= palette.Aquamarine3,
		clrError		= palette.Gold2,
		
		clrLegenda		= palette.Cyan4,
		clrGridText		= palette.Sienna2,	
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
	sCfgVersion		= "0.0.6",
	
	sDefPath 		= "data/2020",		-- use today's date or might fail if no data available
	bShellSelect	= false,			-- on Shell Open File open file's folder
	
	iGridMinTemp	= -5,				-- minimum temperature shown in grid
	iGridMaxTemp	=  50,				-- maximum temperature shown in grid
	bAdaptiveTemp 	= false, 			-- adapt grid to samples' temperature values
	iDrawTemp		= 2,				-- 1 minimum, 2 maximum, 3 both
	iDrawOption		= 1,				-- 1 details, 2 normals, 3 both
	iDrawErrors		= 2,				-- 0 none, 1 minimum, 2 maximum, 3 both
	bRasterOp		= false,			-- use a raster inverse
	
	-- comment this line or set value = nil to use defaults
	--
	tColourScheme	= tColours.blueprint,
	iLineSize		= 2,				-- size of line when drawing
	iFontSize		= 7,				-- font size for the legenda
	sFontFace		= "Liberation Mono",
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
