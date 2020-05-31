--[[
*	download.lua
*
*   Download dataset from the W.M.O. web site.
*
*	In global table m_Favorites a number of files of interest are specified.
*
*	Run:
*		pass switch on the command line:   --favorites		to download favorites from WMO
*
*	or on the command line:
*
*		http://worldweather.wmo.int/images/satellite_img/satellite_IRG_F2.txt ./data/SAT/satellite_IRG_F2.txt
*
*	Note: enclose filename in double quotes if the name contains spaces.
]]

-- ----------------------------------------------------------------------------
--
local wx		= require("wx")
local utility	= require("lib.utility")
local trace 	= require("lib.trace")	

local _format	= string.format
local _find		= string.find
local _sub		= string.sub
local _mkdir	= utility.CreateDirectory

-- ----------------------------------------------------------------------------
--
local m_trace = trace.new("download")

-- ----------------------------------------------------------------------------
--
local m_App = 
{
	sAppName	= "download",
	sAppVer 	= "0.0.2",
	sRelDate	= "30/05/2020",
	
	sConfigFile	= "config/favorites.lua",
	
	iTotRequest	= 0,			-- statistic of total downloads requested
	iTotFailed	= 0,			-- number of failures during download
}

-- ----------------------------------------------------------------------------
--
local m_HostAddr = "worldweather.wmo.int"
local m_HostPort = "80"

local sAgentString = "HTTP/1.1\r\nUser-Agent: Lua 5.3.5 wxWidgets-3.1.3 wxLua 3.0.0.8\r\nAccept-Language: en"
local sProtocolGet = "GET"
local sProtocolEnd = "\r\n\r\n"

-- ----------------------------------------------------------------------------
-- list of errors
--
local m_ErrProtocol = 
{
	"204 No Content",
	"205 Reset Content",
	"206 Partial Content",
	
	"301 Moved Permanently",
	
	"400 Bad Request",
	"401 Unauthorized",
	"402 Payment Required",
	"403 Forbidden",
	"404 Not Found",
	"405 Method Not Allowed",
	"406 Not Acceptable",
	"407 Proxy Authentication Required", 			--  (RFC 7235)
	"408 Request Timeout",
	"409 Conflict",
	"410 Gone",
	"411 Length Required",
	"412 Precondition Failed", 						--  (RFC 7232)
	"413 Payload Too Large", 						--  (RFC 7231)
	"414 URI Too Long",								--  (RFC 7231)
	"415 Unsupported Media Type",					--  (RFC 7231)
	"416 Range Not Satisfiable",					--  (RFC 7233)
	"417 Expectation Failed", 
	"418 I'm a teapot",								--  (RFC 2324, RFC 7168)
	"421 Misdirected Request", 						--  (RFC 7540)
	"422 Unprocessable Entity", 					--  (WebDAV; RFC 4918)
	"423 Locked", 									--  (WebDAV; RFC 4918)
	"424 Failed Dependency", 						--  (WebDAV; RFC 4918)
	"425 Too Early", 								--  (RFC 8470)
	"426 Upgrade Required",
	"428 Precondition Required", 					--  (RFC 6585)
	"429 Too Many Requests", 						--  (RFC 6585)
	"431 Request Header Fields Too Large", 			--  (RFC 6585)
	"451 Unavailable For Legal Reasons", 			--  (RFC 7725)
	
	"500 Internal Server Error",
	"501 Not Implemented",
	"502 Bad Gateway",
	"503 Service Unavailable",
	"504 Gateway Timeout",
	"505 HTTP Version Not Supported",
	"506 Variant Also Negotiates",
	"507 Insufficient Storage",
	"508 Loop Detected",							--	(WebDAV)
	"510 Not Extended",
	"511 Network Authentication Required",
}

-- ----------------------------------------------------------------------------
-- cities of interest
--
local m_FavRemote	= "http://worldweather.wmo.int/en/json/"		-- remote address and directory
local m_FavLocal	= "./data/update/"								-- local directory
	
local m_Favorites	= 
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
--	{ "Region_en", "Region" },
}

-- ----------------------------------------------------------------------------
-- substitute the defaul host addrees
--
local function GetHostFromDocName(inRemoteDoc)
--	m_trace:line("GetHostFromDocName")

	local iH, jH = _find(inRemoteDoc, "http://")

	if (iH and jH) and iH then
		
		local iH2, jH2 = _find(inRemoteDoc, "/", jH + 1)
		
		if (iH2 and jH2) and iH2 then
		
			m_HostAddr = _sub(inRemoteDoc, jH + 1, iH2 - 1)
			
			return true
		end
	end
	
	return false
end

-- ----------------------------------------------------------------------------
-- verify the remote connection was established
--
local function CheckWSAError(inClient)
--	m_trace:line("CheckWSAError")

	if inClient:Error() then
		
		-- check if fatal error
		--
		if inClient:WaitForLost(0, 250) then
			m_trace:line("---> Network unreachable or connection lost")
			
			return wx.wxSOCKET_IOERR 
		end		
		
		local iErrCode = inClient:LastError()
		
		if  wx.wxSOCKET_WOULDBLOCK ~= iErrCode then
			m_trace:line("---> Fatal error code [" .. iErrCode .. "]")
			
			return iErrCode
		end
	end

	return 0
end

-- ----------------------------------------------------------------------------
-- search in inBuffer for the lenght of the content
-- return bytes requested or -1 for error
-- a response of -1, -1 is a protocol error (like 404)
--
local function ParseHeader(inBuffer)
--	m_trace:line("ParseHeader")
	
	if 0 == #inBuffer then return -1, 0 end

	-- search for the header's termination
	--
	local iT, jT = _find(inBuffer, sProtocolEnd)
	local iC, jC
	
	if (iT and jT) and iT then
		
		m_trace:line("Ckeck protocol response")
		
		-- check for a protocol error response
		---
		for i=1, #m_ErrProtocol do
			
			iC, jC = _find(inBuffer, m_ErrProtocol[i])
			
			if (iC and jC) and jC then 
				
				m_trace:line("Error response [" ..  m_ErrProtocol[i] .. "]")			
				
				return -1, -1 
			end
		end
		
		-- check for the download size
		--
		iC, jC = _find(inBuffer, "Content%-Length%: ")
		
		if (iC and jC) and iC then
			
			local sSize = _sub(inBuffer, jC + 1, iT - 1)
			
			m_trace:line("Content Length [" .. sSize .. "]")
			
			return tonumber(sSize), jT + 1
		end
	end

	return -1, 0
end

-- ----------------------------------------------------------------------------
-- verify the remote connection was established
--
local function CheckConnect(inClient)
--	m_trace:line("CheckConnect")

	local iTimeOut	= 500
	local iLoops	= 10
	
	-- wait for the connection or quit
	--
	while not inClient:IsConnected() and 0 < iLoops do
		
--		m_trace:line("Waiting Connect ...")

		if 0 ~= CheckWSAError(inClient) then
			m_trace:line("---> Error connecting to server, aborting...")
			
			return false
		end
		
		-- give it another try
		--
		inClient:WaitOnConnect(0, iTimeOut)
		iLoops = iLoops - 1
	end

	return inClient:IsConnected()
end

-- ----------------------------------------------------------------------------
--
local function GetFileFromURL(inCurCmd)
--	m_trace:line("GetFileFromURL")
	
	local client = wx.wxSocketClient()
	local addr	 = wx.wxIPV4address()
	
	-- connect to host
	--
	addr:Hostname(m_HostAddr)
	addr:Service(m_HostPort)
	
	client:SetFlags(wx.wxSOCKET_NOWAIT)
	client:SetTimeout(5)
	
	client:Connect(addr, false)
	
	-- check if successfully connected
	-- and send the request
	--
	if CheckConnect(client) then
		
		client:Write(inCurCmd)
		
		if not client:WaitForWrite(2, 0) then
		
			CheckWSAError(client)
			m_trace:line("---> Error sending data to server, aborting...")
			
			client:Close()
			return false, nil
		end
		
		-- ------------------------------------
		-- parse response
		-- get the header to know the data size
		--
		local binaryMsg  = ""				-- container for incoming data
		local curFrame						-- current frame received
		local iBytesRead					-- actual bytes read from socket
		local iRecvSize, iHdrLen = ParseHeader(binaryMsg)		-- just fails if buffer empty
		
		while -1 == iRecvSize do
			
			curFrame   = client:Read(512)
			iBytesRead = client:LastCount()			
			
			if 0 < iBytesRead then
				
				-- append frame
				--
				binaryMsg = binaryMsg .. _sub(curFrame, 1, iBytesRead)
				
				iRecvSize, iHdrLen = ParseHeader(binaryMsg)
				
				if -1 == iRecvSize and -1 == iHdrLen then
					
					m_trace:line("---> Server replied with a protocol error, aborting...")
					
					client:Close()
					return false, nil
				end
				
			elseif 0 ~= CheckWSAError(client) then
				
				m_trace:line("---> No data received from server, aborting...")
				
				client:Close()
				return false, nil
			end
		end
		
		-- discard the header
		--
		binaryMsg  = _sub(binaryMsg, iHdrLen)
		iBytesRead = #binaryMsg
		
		-- get all data
		--
		while iBytesRead < iRecvSize do
			
			curFrame   = client:Read(512)
			iBytesRead = client:LastCount()
			
			if 0 < iBytesRead then
				
				-- be careful, strip garbage past the real number of bytes read
				--
				binaryMsg  = binaryMsg .. _sub(curFrame, 1, iBytesRead)
				iBytesRead = #binaryMsg
			
		elseif 0 ~= CheckWSAError(client) then
			
				m_trace:line("---> No data received from server, aborting...")
				
				client:Close()
				return false, nil
			end
		end
		
		-- all expected data was received
		--
		client:Close()
		return true, binaryMsg
	end
	
	return false, nil
end

-- ----------------------------------------------------------------------------
--
local function SaveFile(inFilename, inBuffer)
--	m_trace:line("SaveFile")

	_mkdir(inFilename, true)
	
	local hFile = io.open(inFilename, "w")
	if hFile then
		
		hFile:write(inBuffer)
		hFile:close()

		return true
	end

	return false
end

-- ----------------------------------------------------------------------------
-- download a file
--
-- ret: -1		socket/protocol error
--      -2		file save error
--      > 0		file size
--
local function DownloadFile(inRemoteName, inLocalName)
--	m_trace:line("DownloadFile")

	local sCurCmd = _format("%s %s %s%s", sProtocolGet, inRemoteName, sAgentString, sProtocolEnd)
	
	m_trace:newline("Downloading document [" .. inRemoteName .. "]")

	local bRet, binaryMsg = GetFileFromURL(sCurCmd)
	
	if bRet then
		
		if not SaveFile(inLocalName, binaryMsg) then 
			
			m_trace:line("---> Failed saving file [" .. inLocalName .. "]")
			return -2 
		end
		
		m_trace:line("Downloaded document saved in [" .. inLocalName .. "]")
		return #binaryMsg
	end
	
	m_trace:line("---> Failed download of document [" .. inRemoteName .. "]")
	return -1
end

-- ----------------------------------------------------------------------------
--
local function DownloadFavorites()
	m_trace:line("DownloadFavorites")

	local sFavorite
	local sFilename
	local iNameIdx	= 1		-- which name has to be used for local files
	local bRet
	local iFailed	= 0
	local sConfig	= m_App.sConfigFile
	local tOverride = nil
	
	-- try opening the application's associated configuration file
	--
	if wx.wxFileName().Exists(sConfig) then
		
		m_trace:line("Loading configuration file [" .. sConfig .. "]")
		
		-- an execution abort here must be be due to a bad configuration syntax
		--
		tOverride = dofile(sConfig)
	end

	-- check for favorites override
	--
	if tOverride then
		
		m_FavRemote = tOverride.sRemoteAddr
		m_FavLocal	= tOverride.sLocalStore
		m_Favorites = tOverride.tFavorites
		
		if tOverride.bUseNames then iNameIdx = 2 end
	end
	
	-- last check for objects' validity
	--
	if not m_Favorites or not m_FavRemote or not m_FavLocal then
		
		m_trace:line("---> Invalid data in configuration file, aborting...")
		return
	end
	
	-- retrieve all files in list
	--
	for iIndex=1, #m_Favorites do
		
		sFavorite = _format("%s%s.json", m_FavRemote, m_Favorites[iIndex][1])	
		sFilename = _format("%s%s.json", m_FavLocal,  m_Favorites[iIndex][iNameIdx])
		
		bRet = DownloadFile(sFavorite, sFilename)
		
		if 0 > bRet then iFailed = iFailed + 1 end
	end
	
	m_App.iTotRequest = #m_Favorites
	m_App.iTotFailed  = iFailed
end

-- ----------------------------------------------------------------------------
--
local function DownloadTarget(inRemote, inLocal)
	m_trace:line("DownloadTarget")

	m_App.iTotRequest = 1
	m_App.iTotFailed  = 1		-- assume failed by default

	if GetHostFromDocName(inRemote) then
		
		-- check for errors on returned value
		--
		if 0 < DownloadFile(inRemote, inLocal) then
			
			m_App.iTotFailed = 0
		end
	else
		m_trace:line("---> Invalid host address [" .. inRemote .. "]")
	end
end

-- ----------------------------------------------------------------------------
--
local function RunApplication(...)
--	m_trace:line("RunApplication")

	local sAppTitle = m_App.sAppName .. " [" .. m_App.sAppVer .. "]"
	
	m_trace:time(sAppTitle .. " started")
	
	assert(os.setlocale('us', 'all'))
	m_trace:line("Current locale is [" .. os.setlocale() .. "]")
	
	-- get the arguments on the command line
	--
	local tArgs = { }
	
	for i, v in ipairs{...} do tArgs[i] = v	end
	
	-- -------------------------------
	-- passing "a remote document name" + "a local file name"
	--
	if (tArgs[1] and tArgs[2]) and tArgs[1] then
		
		DownloadTarget(tArgs[1], tArgs[2])
		
	-- -------------------------------
	-- passing the switch for automatic download of favorites
	--
	elseif "--favorites" == tArgs[1] then
	
		DownloadFavorites()
		
	-- -------------------------------
	-- an invalid request
	--
	elseif 0 == #tArgs then
		
		m_trace:line("Nothing to download specified!")
	end

	m_trace:summary("Downloaded [" .. m_App.iTotRequest .. "] Failed: [" .. m_App.iTotFailed .. "]")
	
	-- report to any listener
	--
	local sReport = _format("%d/%d\n", m_App.iTotRequest - m_App.iTotFailed, m_App.iTotRequest)

	io.stdout:write(sReport)
end

-- ----------------------------------------------------------------------------
-- open logging
--
m_trace:open()
	
RunApplication(...)

-- end
--
m_trace:close()

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------

