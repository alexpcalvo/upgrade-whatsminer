local io     = require "io"
local string = require "string"
local table  = require "table"
local fs     = require "nixio.fs"

local tonumber, pcall, dofile, _G = tonumber, pcall, dofile, _G

module "luci.version"

if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
	if _G.DISTRIB_REVISION then
		distrevision = _G.DISTRIB_REVISION
		if not distversion:find(distrevision,1,true) then
			distversion = distversion .. " " .. distrevision
		end
	end
else
	distname    = "OpenWrt"
	distversion = "Development Snapshot"
end

if pcall(dofile, "/etc/microbt_release") then
	if _G.MINER_NAME and _G.MODEL_NAME then
		minermodel = _G.MINER_NAME .. " " .. _G.MODEL_NAME
	else
		minermodel = "unknown"
	end
	if _G.FIRMWARE_VERSION then
		firmwareversion = _G.FIRMWARE_VERSION
	else
		firmwareversion = "unknown"
	end
else
	minermodel    = "unknown"
	firmwareversion = "unknown"
end

cgminerversion = fs.readfile("/etc/cgminer_version") or "unknown"

-- Detect controll board type

controlboardtype = "CB-unknown"

local host_zynq = "Xilinx Zynq Platform"

local t = io.popen('cat /proc/cpuinfo')
local a = t:read("*all")
local h = string.match(a, host_zynq)

if h == host_zynq then
   	local result = {}

	t = io.popen('cat /proc/meminfo')
	a = t:read("*all")
   	for l in string.gmatch(a, "([^ ]+)") do
       	table.insert(result, l)
   	end

	if tonumber(result[2]) <= 262144 then
		controlboardtype = "CB12"
	else
		controlboardtype = "CB10"		
	end
end

-- Detect hash board type

hashboardtype = "HB-unknown"

local sensor_tmp421 = "tmp421"
local sensor_tmp423 = "tmp423"
local sensor_lm75 = "lm75"

local name0 = fs.readfile("/sys/class/hwmon/hwmon0/name") or ""
local name1 = fs.readfile("/sys/class/hwmon/hwmon1/name") or ""
local name2 = fs.readfile("/sys/class/hwmon/hwmon2/name") or ""

name0 = string.match(name0, sensor_tmp421)
name1 = string.match(name1, sensor_tmp421)
name2 = string.match(name2, sensor_tmp421)

if name0 == sensor_tmp421 or name1 == sensor_tmp421 or name2 == sensor_tmp421 then
	hashboardtype = "HB12"
else
	name0 = fs.readfile("/sys/class/hwmon/hwmon0/name") or ""
	name1 = fs.readfile("/sys/class/hwmon/hwmon2/name") or ""
	name2 = fs.readfile("/sys/class/hwmon/hwmon4/name") or ""

	name0 = string.match(name0, sensor_tmp423)
	name1 = string.match(name1, sensor_tmp423)
	name2 = string.match(name2, sensor_tmp423)

	if name0 == sensor_tmp423 or name1 == sensor_tmp423 or name2 == sensor_tmp423 then
		hashboardtype = "HB10"
    else
	    name0 = fs.readfile("/sys/class/hwmon/hwmon0/name") or ""
	    name1 = fs.readfile("/sys/class/hwmon/hwmon2/name") or ""
	    name2 = fs.readfile("/sys/class/hwmon/hwmon4/name") or ""

	    name0 = string.match(name0, sensor_lm75)
	    name1 = string.match(name1, sensor_lm75)
	    name2 = string.match(name2, sensor_lm75)

	    if name0 == sensor_lm75 or name1 == sensor_lm75 or name2 == sensor_lm75 then
		   hashboardtype = "LVB1"
	    end
	end
end

hardwareversion = _G.MODEL_NAME .. "." .. hashboardtype .. "." .. controlboardtype

luciname    = "LuCI Master"
luciversion = "git-16.336.70424-1fd43b4"
