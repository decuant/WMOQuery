--[[
*	Configuration for <archive.lua> script.
*
]]

-- ----------------------------------------------------------------------------
--
local tConfiguration = 
{
	sCfgVersion	= "0.0.1",
	
	bUseMove	= false,				-- move files instead of copy
	bUseCurDay	= false,				-- use todays' date or modification time of 
										-- newest file in source directory
	sTargetFldr	= "C:\\USR_2\\LUA\\WMOQuery\\data",
	sSourceFldr	= "C:\\USR_2\\Lua\\WMOQuery\\data\\update",
	sExtFilter	= "*.json",
}

return tConfiguration

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
