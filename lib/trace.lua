--[[
*	trace.lua
*
*   Create a trace in the logging folder.
*
*   Trace's name will be used for both registering in the active traces list
*   and for the filename to use.
*
]]

-- ----------------------------------------------------------------------------
--
local _fmt	= string.format
local _rep	= string.rep
local _byte	= string.byte
local _cat	= table.concat
local _clk	= os.clock
local _date	= os.date
local _time	= os.time

-------------------------------------------------------------------------------
-- run-time list of available traces
--
local m_TList =
{
--	["view"] = 0xcc00ffdd88,		-- example
}

-------------------------------------------------------------------------------
--
local m_BaseDir = "log/"

-------------------------------------------------------------------------------
--
local Trace		= { }
Trace.__index	= Trace

-- ----------------------------------------------------------------------------
-- if the required trace does not exist then allocate a new one
--
function Trace.new(inName)

	if not m_TList[inName] then
		
		local t =
		{
			sName 		 = inName,
			bEnabled	 = true,
			hFile		 = nil,
			iLineCounter = 0,
			tmTickStart	 = 0,
			tmTickTimed	 = 0,
		}
		
		m_TList[inName] = setmetatable(t, Trace)
	end
	
	return m_TList[inName]
end

-- ----------------------------------------------------------------------------
--
function Trace.skip(self, inObject)
	
	if not self.bEnabled then return true end
	if not self.hFile then return true end
	if not inObject then return true end

	return false
end

-- ----------------------------------------------------------------------------
-- get the filename
--
function Trace.filename(self)
	
	return m_BaseDir .. self.sName .. ".log"
end

-- ----------------------------------------------------------------------------
-- open a trace file for writing only
-- returns the success of the operation
--
function Trace.open(self)
	
	-- check if already opened
	--
	self:close()
	
	-- open file here
	--
	self.hFile = io.open(self:filename(), "w")
	
	return (nil == self.hFile)
end

-- ----------------------------------------------------------------------------
--
function Trace.close(self)
	
	if self.hFile then
		
		self.hFile:close()
		self.hFile = nil
	end
end

-- ----------------------------------------------------------------------------
--
function Trace.enable(self, inEnable)
	
	self.bEnabled = inEnable
end

-- ----------------------------------------------------------------------------
--
function Trace.line(self, inMessage)
	
	if self:skip(inMessage) then return end
	
	self.iLineCounter = self.iLineCounter + 1	
	
	self.hFile:write(_fmt("%05d: %s\n", self.iLineCounter, inMessage))
	self.hFile:flush()
end

-- ----------------------------------------------------------------------------
--
function Trace.newline(self, inMessage)
	
	if self:skip(inMessage) then return end

	self:line("")
	self:line(inMessage)
end

-- ----------------------------------------------------------------------------
--
function Trace.summary(self, inMessage)
	
	if self:skip(inMessage) then return end
	
	self:line("")
	self:line(_rep("=", 80))
	self:line(inMessage)
end

-- ----------------------------------------------------------------------------
--
function Trace.time(self, inMessage)
	
	if self:skip(inMessage) then return end

	local sToday = _date("%Y/%m/%d %H:%M:%S", _time())
	
	self:line(sToday)
	self:line(inMessage)
end

-- ----------------------------------------------------------------------------
--
function Trace.startwatch(self)
	
	self.iTickStart = _clk()
end

-- ----------------------------------------------------------------------------
--
function Trace.stopwatch(self, inMessage)
	
	if self:skip(inMessage) then return end

	self.iTickTimed = _clk()

	local sText = _fmt("%s - %.03f secs", inMessage, (self.iTickTimed - self.iTickStart))
	
	-- this allows for intermediate stopwatch
	--
	self.iTickStart = self.iTickTimed

	self:line(sText)
end

-- ----------------------------------------------------------------------------
--
function Trace.vector(self, inTable, inLabel)
	
	if self:skip(inTable) then return end

	local tStrings = { inLabel or "" }

	for iIndex, aNumber in ipairs(inTable) do
		
		tStrings[iIndex + 1] = _fmt("%.04f", aNumber)
	end

	self:line(_cat(tStrings, " ")) 	
end

--------------------------------------------------------------------------------
-- dump a buffer
--
function Trace.dump(self, inTitle, inBuffer)
	
	if self:skip(inBuffer) then return end
  
	local blockText = "----- [ " .. inTitle .. " ] -----"  
	local hFile 	= self.hFile
	local chunk
	
	self:line(blockText)

	for iByte=1, #inBuffer, 16 do
	  
		chunk = inBuffer:sub(iByte, iByte + 15)
		
		hFile:write(_fmt('%08X  ', iByte - 1))
		
		chunk:gsub('.', function (c) hFile:write(_fmt('%02X ', _byte(c))) end)
	 
		hFile:write(_rep(' ', 3 * (16 - #chunk)))
		hFile:write(' ', chunk:gsub('%c', '.'), "\n") 
	end

	self:line(blockText)
end

-- ----------------------------------------------------------------------------
--  print a table in memory
--  the inFull parameter is an optional flag to skip printing pointers
--
function Trace.table(self, inTable, inFull)
	
	if self:skip(inTable) then return end  
   
	local print_r_cache = { }
  
	local function sub_print_r(inTable, indent)
		
		local sStrOfT = tostring(inTable)
		
		if print_r_cache[sStrOfT] then
			
			self:line(indent .. "*" .. sStrOfT)
		else
			
			print_r_cache[sStrOfT] = true
			
			if "table" == type(inTable) then
				
				for obj, val in pairs(inTable) do
					
					local sNameOfObj = tostring(obj)
					local sTypeOfVal = type(val)
					
					if "table" == sTypeOfVal then
						
						if inFull then
							self:line(indent .. "[" .. sNameOfObj .."] => " .. tostring(val) .. " {")
						else
							self:line(indent .. "[" .. sNameOfObj .."] {")
						end
						
						sub_print_r(val, indent .. _rep(" ", #sNameOfObj + 4))
						
						self:line(indent .. _rep(" ", #sNameOfObj + 2) .. " }")
						
					elseif "string" == sTypeOfVal then
						
						self:line(indent .. "[" .. sNameOfObj .. '] "'.. val .. '"')
					else
						
						self:line(indent .. "[".. sNameOfObj .. "] " .. tostring(val))
					end
				end
			else
				
				self:line(indent .. sStrOfT)
			end
		end
	end

	-- master processing
	--
	if "table" == type(inTable) then
		
		self:line(tostring(inTable) .. "  {")
		sub_print_r(inTable, "    ")
		self:line("}")
	else
		
		sub_print_r(inTable, "  ")
	end
end

-- ----------------------------------------------------------------------------
--
return Trace

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

