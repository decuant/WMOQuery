--[[
*	Configuration for <archive.lua> script.
*
]]

-- ----------------------------------------------------------------------------
--
local tConfiguration = 
{
	sCfgVersion	= "0.0.2",
	
	bUseMove	= false,				-- move files instead of copy
	bUseCurDay	= false,				-- use todays' date or modification time of 
										-- newest file in source directory
	sTargetFldr	= "data/years",
	sSourceFldr	= "data/update",
	sExtFilter	= "*.json",
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
