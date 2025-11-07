obs         = obslua
source_name = ""
-- These defaults will override the css with code that will cause the youtube 

local ffi = require("ffi")
local clip = ""

-- Since clipboard is OS-specific, we're only supporting Windows for now
ffi.cdef[[
unsigned long* strlen( const char *string );
char* __stdcall GlobalLock(void* hMem);
bool __stdcall GlobalUnlock(void* hMem);
bool __stdcall OpenClipboard(void* hWndNewOwner);
bool __stdcall CloseClipboard();
void* __stdcall GetClipboardData(unsigned int uFormat);
bool __stdcall IsClipboardFormatAvailable(unsigned int format);
]]

ffi.load("User32")
ffi.load("Kernel32")

-- Convenience wrappers for the Windows API functions
local strlen = ffi.C.strlen
local GlobalLock = ffi.C.GlobalLock
local GlobalUnlock = ffi.C.GlobalUnlock
local OpenClipboard = ffi.C.OpenClipboard
local CloseClipboard = ffi.C.CloseClipboard
local GetClipboardData = ffi.C.GetClipboardData
local IsClipboardFormatAvailable = ffi.C.IsClipboardFormatAvailable

-- Custom Functions for use by the script
function GetClipboardString()
	assert(OpenClipboard(nil))
	local lock = assert(GetClipboardData(1))
	local text = ""
	if (lock and IsClipboardFormatAvailable(1)) then
		local ctext = assert(GlobalLock(lock))
		text = ffi.string(ctext)
		assert(GlobalUnlock(lock))
	end
	CloseClipboard()
	return text
end

----------------------------------------------------------

function setFromClipboard(url)
	local source = obs.obs_get_source_by_name(source_name)
	if source then
		local settings = obs.obs_data_create()
		-- Set up a minimal embedded version of the video requested
		obs.obs_data_set_string(settings, "url", 
			"https://1all.giize.com/youtube/?watch?v="..url..
			"&volume=80&random=true&loop=true&w=1920&h=1080&quality=hd1080&forcequality=true&fade=true&debug=false&controls=true")
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

----------------------------------------------------------

function check_clipboard()
	local clipx = GetClipboardString()
	if (clipx and (clip ~= clipx)) then
		clip = clipx
		local ytlink = string.match(clip,
			'.*youtube%.com/watch%?v=([%w_-]+)&?.*')
		if ytlink then
			setFromClipboard(ytlink)
		else
			ytlink = string.match(clip,'.*youtu%.be/([%w_-]+)&?.*')
			if ytlink then
				setFromClipboard(ytlink)
			end
		end
	end
end

----------------------------------------------------------

-- OBS API Functions
function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source")
end

function script_description()
	return "When any youtube link is copied into the clipboard, it is then \z
	loaded and played as a minimal embed in a selected browser source."
end

function script_properties()
	props = obs.obs_properties_create()

	local p = obs.obs_properties_add_list(props, "source", "Browser Source", 
		obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "browser_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	return props
end

function script_load(settings)
	obs.timer_add(check_clipboard,1000)
end


