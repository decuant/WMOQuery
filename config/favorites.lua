--[[
*	Configuration for <download.lua> script.
*
]]

-- ---------------------------------
-- { remote filename, station name }
-- ---------------------------------

local tTestSetRegionOnly	= 
{
	{ "Region_en", "Region" },
}

local tTestSetWorldGeneric	= 
{
	{ "2078_en", "Vieste" },
	{ "538_en",  "Auckland" },
	{ "279_en",  "Ciudad de Mexico" },
	{ "270_en",  "Washington DC" },
	{ "242_en",  "Algiers" },
	{ "224_en",  "New Delhi (SFD)" },
	{ "206_en",  "Moscow" },
	{ "195_en",  "Madrid" },
	{ "194_en",  "Paris" },
	{ "177_en",  "Athens" },
	{ "59_en",   "Berlin" },
	{ "44_en",   "Tel Aviv" },
	{ "32_en",   "London" },
	{ "1_en",    "Hong Kong" },
}

local tTestSetItalyGeneric	= 
{
	{ "201_en",  "Roma" },
	{ "602_en",  "Firenze" },
	{ "603_en",  "Milano" },
	{ "605_en",  "Palermo" },
	{ "606_en",  "Venezia" },
	{ "1944_en", "Bologna" },
	{ "2078_en", "Vieste" },
}

local tTestSetVoid	= 
{

}

-- ----------------------------------------------------------------------------
--
local tConfiguration = 
{
	sVersion	= "0.0.1",
	
	sRemoteAddr	= "http://worldweather.wmo.int/en/json/",		-- remote address and directory
	sLocalStore	= "./data/update/",								-- local directory
	
	bUseNames	= true,											-- use Station names instead of IDs
	
	-- -----------------------
	-- sFavorites index
	--
	tFavorites	= tTestSetVoid,
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
